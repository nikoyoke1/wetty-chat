-- This will fail if there are rows where message_id is null!
DELETE FROM attachments WHERE message_id IS NULL;
ALTER TABLE attachments ALTER COLUMN message_id SET NOT NULL;
