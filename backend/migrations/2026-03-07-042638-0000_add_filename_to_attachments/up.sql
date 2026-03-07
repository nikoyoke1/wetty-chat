ALTER TABLE attachments ADD COLUMN file_name VARCHAR(255) NOT NULL DEFAULT '';
UPDATE attachments SET file_name = split_part(external_reference, '/', 2) WHERE external_reference LIKE '%/%';
