DROP INDEX IF EXISTS idx_user_favorite_stickers_uid_created_at;
DROP TABLE IF EXISTS user_favorite_stickers;

DROP INDEX IF EXISTS idx_user_sticker_pack_subscriptions_uid_subscribed_at;
DROP TABLE IF EXISTS user_sticker_pack_subscriptions;

DROP INDEX IF EXISTS idx_sticker_pack_stickers_sticker_pack;
DROP TABLE IF EXISTS sticker_pack_stickers;

DROP INDEX IF EXISTS idx_stickers_media_id;
DROP TABLE IF EXISTS stickers;

DROP INDEX IF EXISTS idx_sticker_packs_owner_uid_created_at;
DROP TABLE IF EXISTS sticker_packs;
