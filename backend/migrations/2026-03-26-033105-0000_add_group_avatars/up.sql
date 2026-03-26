CREATE TABLE media_images (
    id BIGINT PRIMARY KEY,
    owner_group_id BIGINT NOT NULL REFERENCES groups(id),
    content_type VARCHAR(255) NOT NULL,
    storage_key TEXT NOT NULL,
    size BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    deleted_at TIMESTAMPTZ,
    file_name VARCHAR(255) NOT NULL DEFAULT '',
    width INTEGER,
    height INTEGER
);

CREATE INDEX idx_media_images_owner_group_id
    ON media_images(owner_group_id)
    WHERE deleted_at IS NULL;

ALTER TABLE groups
    DROP COLUMN avatar,
    ADD COLUMN avatar_image_id BIGINT REFERENCES media_images(id);

CREATE INDEX idx_groups_avatar_image_id
    ON groups(avatar_image_id)
    WHERE avatar_image_id IS NOT NULL;
