ALTER TYPE message_type ADD VALUE IF NOT EXISTS 'sticker';

ALTER TABLE messages
    ADD COLUMN sticker_id BIGINT REFERENCES stickers(id);

CREATE INDEX idx_messages_sticker_id
    ON messages(sticker_id)
    WHERE sticker_id IS NOT NULL;
