DROP INDEX IF EXISTS idx_push_subscriptions_client_id;

ALTER TABLE push_subscriptions
DROP COLUMN IF EXISTS client_id;

DROP INDEX IF EXISTS idx_clients_last_active;

DROP TABLE IF EXISTS clients;
