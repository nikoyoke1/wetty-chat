-- Your SQL goes here
CREATE INDEX idx_sticker_pack_stickers_pack_id_added_at
    ON sticker_pack_stickers(pack_id, added_at, sticker_id);
