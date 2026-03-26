DROP INDEX IF EXISTS idx_groups_avatar_image_id;

ALTER TABLE groups
    DROP COLUMN avatar_image_id,
    ADD COLUMN avatar TEXT DEFAULT NULL;

DROP INDEX IF EXISTS idx_media_images_owner_group_id;

DROP TABLE media_images;
