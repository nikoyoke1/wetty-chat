CREATE TABLE clients (
    client_id VARCHAR(64) PRIMARY KEY,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    last_active TIMESTAMP NOT NULL DEFAULT NOW(),
    last_active_uid INTEGER NOT NULL
);

CREATE INDEX idx_clients_last_active ON clients(last_active);

ALTER TABLE push_subscriptions
ADD COLUMN client_id VARCHAR(64);

CREATE INDEX idx_push_subscriptions_client_id ON push_subscriptions(client_id);
