use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    Json,
};
use chrono::{DateTime, Utc};
use diesel::prelude::*;
use serde::Serialize;

use crate::models::{GroupRole, NewGroupMembership};
use crate::schema::{self, group_membership};
use crate::utils::auth::CurrentUid;
use crate::{AppState, MAX_MEMBERS_LIMIT};

#[derive(serde::Deserialize)]
pub struct ChatIdPath {
    pub chat_id: i64,
}

#[derive(serde::Deserialize)]
pub struct MemberPath {
    chat_id: i64,
    uid: i32,
}

#[derive(serde::Deserialize)]
pub struct AddMemberBody {
    uid: i32,
    #[serde(default)]
    role: Option<GroupRole>,
}

#[derive(serde::Deserialize)]
pub struct UpdateMemberBody {
    role: GroupRole,
}

#[derive(Serialize)]
pub struct MemberResponse {
    uid: i32,
    role: GroupRole,
    joined_at: DateTime<Utc>,
    username: Option<String>,
}

#[derive(serde::Deserialize)]
struct ListMembersQuery {
    limit: Option<i64>,
    after: Option<i32>,
}

#[derive(Serialize)]
struct ListMembersResponse {
    members: Vec<MemberResponse>,
    next_cursor: Option<i32>,
    can_manage_members: bool,
}

/// Check if user is a member of the chat; return 403 if not.
pub(super) fn check_membership(
    conn: &mut diesel::r2d2::PooledConnection<
        diesel::r2d2::ConnectionManager<diesel::PgConnection>,
    >,
    chat_id: i64,
    uid: i32,
) -> Result<(), (StatusCode, &'static str)> {
    use crate::schema::group_membership::dsl;

    let exists = group_membership::table
        .filter(dsl::chat_id.eq(chat_id).and(dsl::uid.eq(uid)))
        .count()
        .get_result::<i64>(conn)
        .map_err(|e| {
            tracing::error!("check membership: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;

    if exists == 0 {
        return Err((StatusCode::FORBIDDEN, "Not a member of this chat"));
    }

    Ok(())
}

/// Check if user is an admin of the chat; return 403 if not a member or not admin.
fn check_admin_role(
    conn: &mut diesel::r2d2::PooledConnection<
        diesel::r2d2::ConnectionManager<diesel::PgConnection>,
    >,
    chat_id: i64,
    uid: i32,
) -> Result<(), (StatusCode, &'static str)> {
    use crate::schema::group_membership::dsl;

    let role: Option<GroupRole> = group_membership::table
        .filter(dsl::chat_id.eq(chat_id).and(dsl::uid.eq(uid)))
        .select(dsl::role)
        .first(conn)
        .optional()
        .map_err(|e| {
            tracing::error!("check admin role: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;

    match role {
        Some(GroupRole::Admin) => Ok(()),
        Some(_) => Err((StatusCode::FORBIDDEN, "Admin role required")),
        None => Err((StatusCode::FORBIDDEN, "Not a member of this chat")),
    }
}

/// GET /group/:chat_id/members — List members of a chat.
async fn get_members(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(ChatIdPath { chat_id }): Path<ChatIdPath>,
    Query(q): Query<ListMembersQuery>,
) -> Result<Json<ListMembersResponse>, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    // Require membership to see members list
    check_membership(conn, chat_id, uid)?;

    use crate::schema::group_membership::dsl as gm_dsl;

    let requester_is_admin = group_membership::table
        .filter(gm_dsl::chat_id.eq(chat_id).and(gm_dsl::uid.eq(uid)))
        .select(gm_dsl::role)
        .first::<GroupRole>(conn)
        .map(|role| role == GroupRole::Admin)
        .map_err(|e| {
            tracing::error!("get requester role: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to load requester role")
        })?;

    let limit = q
        .limit
        .map(|l| std::cmp::min(l, MAX_MEMBERS_LIMIT))
        .unwrap_or(MAX_MEMBERS_LIMIT)
        .max(1);

    use crate::schema::discuz::discuz::common_member::dsl as cm_dsl;

    let mut query = group_membership::table
        .left_join(cm_dsl::common_member.on(gm_dsl::uid.eq(cm_dsl::uid)))
        .filter(gm_dsl::chat_id.eq(chat_id))
        .into_boxed();

    if let Some(after) = q.after {
        query = query.filter(gm_dsl::uid.gt(after));
    }

    let rows: Vec<(i32, GroupRole, DateTime<Utc>, Option<String>)> = query
        .order_by(gm_dsl::uid.asc())
        .select((
            gm_dsl::uid,
            gm_dsl::role,
            gm_dsl::joined_at,
            cm_dsl::username.nullable(),
        ))
        .limit(limit + 1)
        .load(conn)
        .map_err(|e| {
            tracing::error!("list members: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to list members")
        })?;

    let has_more = rows.len() as i64 > limit;
    let members: Vec<MemberResponse> = rows
        .into_iter()
        .take(limit as usize)
        .map(|(uid, role, joined_at, username)| MemberResponse {
            uid,
            role,
            joined_at,
            username,
        })
        .collect();

    let next_cursor = has_more.then(|| members.last().map(|member| member.uid)).flatten();

    Ok(Json(ListMembersResponse {
        members,
        next_cursor,
        can_manage_members: requester_is_admin,
    }))
}

/// POST /group/:chat_id/members — Add a member to the chat (caller must be admin).
async fn post_add_member(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(ChatIdPath { chat_id }): Path<ChatIdPath>,
    Json(body): Json<AddMemberBody>,
) -> Result<(StatusCode, Json<MemberResponse>), (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    // Check if requester is admin
    check_admin_role(conn, chat_id, uid)?;

    use crate::schema::discuz::discuz::common_member::dsl as cm_dsl;

    let username = cm_dsl::common_member
        .filter(cm_dsl::uid.eq(body.uid))
        .select(cm_dsl::username)
        .first::<String>(conn)
        .optional()
        .map_err(|e| {
            tracing::error!("load target user: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;

    if username.is_none() {
        return Err((StatusCode::BAD_REQUEST, "User not found"));
    }

    // Check if already a member
    let already_member = {
        use crate::schema::group_membership::dsl as gm_dsl;
        schema::group_membership::table
            .filter(gm_dsl::chat_id.eq(chat_id).and(gm_dsl::uid.eq(body.uid)))
            .count()
            .get_result::<i64>(conn)
            .map_err(|e| {
                tracing::error!("check already member: {:?}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
            })?
    };

    if already_member > 0 {
        return Err((StatusCode::CONFLICT, "User is already a member"));
    }

    let role = body.role.unwrap_or(GroupRole::Member);

    let now = Utc::now();
    let new_membership = NewGroupMembership {
        chat_id,
        uid: body.uid,
        role: role.clone(),
        joined_at: now,
    };

    diesel::insert_into(group_membership::table)
        .values(&new_membership)
        .execute(conn)
        .map_err(|e| {
            tracing::error!("insert membership: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Failed to add member")
        })?;

    Ok((
        StatusCode::CREATED,
        Json(MemberResponse {
            uid: body.uid,
            role,
            joined_at: now,
            username,
        }),
    ))
}

/// DELETE /group/:chat_id/members/:uid — Remove a member from the chat (caller must be admin).
async fn delete_remove_member(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(MemberPath {
        chat_id,
        uid: target_uid,
    }): Path<MemberPath>,
) -> Result<StatusCode, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    // Allow if requester is admin OR removing themselves
    if uid != target_uid {
        check_admin_role(conn, chat_id, uid)?;
    } else {
        check_membership(conn, chat_id, uid)?;
    }

    // Check if target is a member
    use crate::schema::group_membership::dsl as gm_dsl;
    let is_member = group_membership::table
        .filter(gm_dsl::chat_id.eq(chat_id).and(gm_dsl::uid.eq(target_uid)))
        .count()
        .get_result::<i64>(conn)
        .map_err(|e| {
            tracing::error!("check member exists: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;

    if is_member == 0 {
        return Err((StatusCode::NOT_FOUND, "Member not found"));
    }

    diesel::delete(
        group_membership::table.filter(gm_dsl::chat_id.eq(chat_id).and(gm_dsl::uid.eq(target_uid))),
    )
    .execute(conn)
    .map_err(|e| {
        tracing::error!("delete membership: {:?}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, "Failed to remove member")
    })?;

    Ok(StatusCode::NO_CONTENT)
}

/// PATCH /group/:chat_id/members/:uid — Update member role (admin only).
async fn patch_member(
    CurrentUid(requester_uid): CurrentUid,
    State(state): State<AppState>,
    Path(MemberPath {
        chat_id,
        uid: target_uid,
    }): Path<MemberPath>,
    Json(body): Json<UpdateMemberBody>,
) -> Result<Json<MemberResponse>, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    // Check if requester is admin
    check_admin_role(conn, chat_id, requester_uid)?;

    // Check if target is a member
    use crate::schema::group_membership::dsl as gm_dsl;
    let is_member = group_membership::table
        .filter(gm_dsl::chat_id.eq(chat_id).and(gm_dsl::uid.eq(target_uid)))
        .count()
        .get_result::<i64>(conn)
        .map_err(|e| {
            tracing::error!("check member exists: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, "Database error")
        })?;

    if is_member == 0 {
        return Err((StatusCode::NOT_FOUND, "Member not found"));
    }

    // Update role
    diesel::update(
        group_membership::table.filter(gm_dsl::chat_id.eq(chat_id).and(gm_dsl::uid.eq(target_uid))),
    )
    .set(gm_dsl::role.eq(&body.role))
    .execute(conn)
    .map_err(|e| {
        tracing::error!("update member role: {:?}", e);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Failed to update member role",
        )
    })?;

    // Get updated member info
    use crate::schema::discuz::discuz::common_member::dsl as cm_dsl;

    let (role, joined_at, username): (GroupRole, DateTime<Utc>, Option<String>) =
        group_membership::table
            .left_join(cm_dsl::common_member.on(gm_dsl::uid.eq(cm_dsl::uid)))
            .filter(gm_dsl::chat_id.eq(chat_id).and(gm_dsl::uid.eq(target_uid)))
            .select((gm_dsl::role, gm_dsl::joined_at, cm_dsl::username.nullable()))
            .first(conn)
            .map_err(|e| {
                tracing::error!("get updated member: {:?}", e);
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "Failed to get updated member",
                )
            })?;

    Ok(Json(MemberResponse {
        uid: target_uid,
        role,
        joined_at,
        username,
    }))
}

pub fn router() -> axum::Router<crate::AppState> {
    axum::Router::new()
        .route("/", axum::routing::get(get_members).post(post_add_member))
        .route(
            "/{uid}",
            axum::routing::delete(delete_remove_member).patch(patch_member),
        )
}
