WITH ranked_apns AS (
    SELECT
        id,
        ROW_NUMBER() OVER (
            PARTITION BY device_token, apns_environment
            ORDER BY created_at DESC, id DESC
        ) AS row_num
    FROM push_subscriptions
    WHERE provider = 'apns'
)
DELETE FROM push_subscriptions
WHERE id IN (
    SELECT id
    FROM ranked_apns
    WHERE row_num > 1
);

DROP INDEX IF EXISTS idx_push_subscriptions_apns_user_token_environment;

CREATE UNIQUE INDEX idx_push_subscriptions_apns_provider_token_environment
    ON push_subscriptions(provider, device_token, apns_environment);
