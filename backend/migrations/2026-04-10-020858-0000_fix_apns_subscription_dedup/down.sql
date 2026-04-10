DROP INDEX IF EXISTS idx_push_subscriptions_apns_provider_token_environment;

CREATE UNIQUE INDEX idx_push_subscriptions_apns_user_token_environment
    ON push_subscriptions(user_id, device_token, apns_environment)
    WHERE provider = 'apns';
