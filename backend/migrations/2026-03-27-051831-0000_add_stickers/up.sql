CREATE TABLE sticker_packs (
    id BIGINT PRIMARY KEY,
    owner_uid INTEGER NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sticker_packs_owner_uid_created_at
    ON sticker_packs(owner_uid, created_at DESC);

CREATE TABLE stickers (
    id BIGINT PRIMARY KEY,
    media_id BIGINT NOT NULL REFERENCES media(id),
    emoji VARCHAR(32) NOT NULL,
    name VARCHAR(255),
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_stickers_media_id
    ON stickers(media_id);

CREATE TABLE sticker_pack_stickers (
    pack_id BIGINT NOT NULL REFERENCES sticker_packs(id),
    sticker_id BIGINT NOT NULL REFERENCES stickers(id),
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (pack_id, sticker_id)
);

CREATE INDEX idx_sticker_pack_stickers_sticker_pack
    ON sticker_pack_stickers(sticker_id, pack_id);

CREATE TABLE user_sticker_pack_subscriptions (
    uid INTEGER NOT NULL,
    pack_id BIGINT NOT NULL REFERENCES sticker_packs(id),
    subscribed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (uid, pack_id)
);

CREATE INDEX idx_user_sticker_pack_subscriptions_uid_subscribed_at
    ON user_sticker_pack_subscriptions(uid, subscribed_at DESC);

CREATE TABLE user_favorite_stickers (
    uid INTEGER NOT NULL,
    sticker_id BIGINT NOT NULL REFERENCES stickers(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (uid, sticker_id)
);

CREATE INDEX idx_user_favorite_stickers_uid_created_at
    ON user_favorite_stickers(uid, created_at DESC);
