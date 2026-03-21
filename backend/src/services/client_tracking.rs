use std::sync::Arc;
use std::time::{Duration, Instant};

use axum::{
    extract::State,
    http::{Request, StatusCode},
    middleware::Next,
    response::{IntoResponse, Response},
};
use chrono::{Days, Utc};
use dashmap::DashMap;
use diesel::prelude::*;
use diesel::r2d2::{ConnectionManager, Pool};
use diesel::PgConnection;
use tracing::{error, info, warn};

use crate::models::NewClientRecord;
use crate::schema::{clients, push_subscriptions};
use crate::utils::auth::{extract_current_uid, optional_client_id};

const ACTIVITY_WRITE_THROTTLE: Duration = Duration::from_secs(5 * 60);
const PURGE_INTERVAL: Duration = Duration::from_secs(6 * 60 * 60);
const PURGE_RESTART_DELAY: Duration = Duration::from_secs(1);
const STALE_CLIENT_RETENTION_DAYS: u64 = 45;
const LEGACY_SUBSCRIPTION_GRACE_DAYS: u64 = 90;

#[derive(Clone, Copy)]
struct CachedActivity {
    last_written_at: Instant,
    uid: i32,
}

pub struct ClientTrackingService {
    db: Pool<ConnectionManager<PgConnection>>,
    recent_writes: DashMap<String, CachedActivity>,
}

impl ClientTrackingService {
    pub fn start(db: Pool<ConnectionManager<PgConnection>>) -> Arc<Self> {
        let service = Arc::new(Self {
            db,
            recent_writes: DashMap::new(),
        });

        let worker_service = service.clone();
        tokio::spawn(async move {
            super::push::supervise_worker(
                "client activity purge worker",
                PURGE_RESTART_DELAY,
                move || {
                    let worker_service = worker_service.clone();
                    async move {
                        worker_service.run_purge_worker().await;
                    }
                },
            )
            .await;
        });

        service
    }

    pub fn record_activity(
        &self,
        uid: i32,
        client_id: &str,
    ) -> Result<(), (StatusCode, &'static str)> {
        if let Some(entry) = self.recent_writes.get(client_id) {
            if entry.uid == uid && entry.last_written_at.elapsed() < ACTIVITY_WRITE_THROTTLE {
                return Ok(());
            }
        }

        let now = Utc::now().naive_utc();
        let conn = &mut self.db.get().map_err(|e| {
            error!("client tracking: failed to get DB connection: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Database connection failed",
            )
        })?;

        conn.transaction::<(), diesel::result::Error, _>(|conn| {
            let existing_uid = clients::table
                .find(client_id)
                .select(clients::last_active_uid)
                .first::<i32>(conn)
                .optional()?;

            if existing_uid.is_some_and(|previous_uid| previous_uid != uid) {
                diesel::update(
                    push_subscriptions::table
                        .filter(push_subscriptions::client_id.eq(Some(client_id.to_string()))),
                )
                .set(push_subscriptions::user_id.eq(uid))
                .execute(conn)?;
            }

            let new_client = NewClientRecord {
                client_id: client_id.to_string(),
                created_at: now,
                last_active: now,
                last_active_uid: uid,
            };

            diesel::insert_into(clients::table)
                .values(&new_client)
                .on_conflict(clients::client_id)
                .do_update()
                .set((
                    clients::last_active.eq(now),
                    clients::last_active_uid.eq(uid),
                ))
                .execute(conn)?;

            Ok(())
        })
        .map_err(|e| {
            error!("client tracking: failed to record activity: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to record client activity",
            )
        })?;

        self.recent_writes.insert(
            client_id.to_string(),
            CachedActivity {
                last_written_at: Instant::now(),
                uid,
            },
        );

        Ok(())
    }

    async fn run_purge_worker(self: Arc<Self>) {
        let mut interval = tokio::time::interval(PURGE_INTERVAL);
        loop {
            interval.tick().await;
            if let Err(error) = self.purge_stale_subscriptions() {
                warn!("client tracking purge failed: {}", error);
            }
        }
    }

    fn purge_stale_subscriptions(&self) -> Result<(), String> {
        let stale_cutoff = Utc::now()
            .naive_utc()
            .checked_sub_days(Days::new(STALE_CLIENT_RETENTION_DAYS))
            .ok_or_else(|| "failed to compute stale client cutoff".to_string())?;
        let legacy_cutoff = Utc::now()
            .naive_utc()
            .checked_sub_days(Days::new(LEGACY_SUBSCRIPTION_GRACE_DAYS))
            .ok_or_else(|| "failed to compute legacy subscription cutoff".to_string())?;

        let conn = &mut self
            .db
            .get()
            .map_err(|e| format!("failed to get DB connection: {:?}", e))?;

        let stale_client_ids: Vec<String> = clients::table
            .filter(clients::last_active.lt(stale_cutoff))
            .select(clients::client_id)
            .load(conn)
            .map_err(|e| format!("failed to load stale client ids: {:?}", e))?;

        let mut deleted_subscriptions = 0;
        let mut deleted_clients = 0;

        if !stale_client_ids.is_empty() {
            deleted_subscriptions += diesel::delete(
                push_subscriptions::table
                    .filter(push_subscriptions::client_id.eq_any(&stale_client_ids)),
            )
            .execute(conn)
            .map_err(|e| format!("failed to delete stale subscriptions: {:?}", e))?;

            deleted_clients =
                diesel::delete(clients::table.filter(clients::client_id.eq_any(&stale_client_ids)))
                    .execute(conn)
                    .map_err(|e| format!("failed to delete stale clients: {:?}", e))?;

            for client_id in &stale_client_ids {
                self.recent_writes.remove(client_id);
            }
        }

        let deleted_legacy = diesel::delete(
            push_subscriptions::table
                .filter(push_subscriptions::client_id.is_null())
                .filter(push_subscriptions::created_at.lt(legacy_cutoff)),
        )
        .execute(conn)
        .map_err(|e| format!("failed to delete legacy subscriptions: {:?}", e))?;

        deleted_subscriptions += deleted_legacy;

        if deleted_subscriptions > 0 || deleted_clients > 0 {
            info!(
                "client tracking purge removed {} push subscriptions and {} clients",
                deleted_subscriptions, deleted_clients
            );
        }

        Ok(())
    }
}

pub async fn track_client_activity(
    State(state): State<crate::AppState>,
    request: Request<axum::body::Body>,
    next: Next,
) -> Response {
    let uid = extract_current_uid(request.headers(), &state).ok();
    let client_id = optional_client_id(request.headers()).ok().flatten();

    if let (Some(uid), Some(client_id)) = (uid, client_id) {
        if let Err((status, message)) = state.client_tracking.record_activity(uid, &client_id) {
            return (status, message).into_response();
        }
    }

    next.run(request).await
}
