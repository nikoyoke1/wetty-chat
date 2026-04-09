-- Your SQL goes here
CREATE INDEX IF NOT EXISTS idx_attachments_message_id_order_id
ON attachments(message_id, "order", id);
