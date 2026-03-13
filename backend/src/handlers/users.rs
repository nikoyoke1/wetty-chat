use axum::{extract::State, http::StatusCode, Json};
use serde::Serialize;

use crate::services;
use crate::utils::auth::CurrentUid;
use crate::AppState;

#[derive(Serialize)]
pub struct MeResponse {
    pub uid: i32,
    pub username: String,
    pub avatar_url: Option<String>,
}

/// GET /users/me — Get the current logged in user's information
async fn get_me(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
) -> Result<Json<MeResponse>, (StatusCode, &'static str)> {
    let mut names = services::user::lookup_users(&state, &[uid]).await;
    let username = names
        .remove(&uid)
        .flatten()
        .unwrap_or_else(|| "Unknown".to_string());

    let mut avatars = services::user::lookup_user_avatars(&state, &[uid]);
    let avatar_url = avatars.remove(&uid).flatten();

    Ok(Json(MeResponse {
        uid,
        username,
        avatar_url,
    }))
}

pub fn router() -> axum::Router<crate::AppState> {
    axum::Router::new().route("/me", axum::routing::get(get_me))
}
