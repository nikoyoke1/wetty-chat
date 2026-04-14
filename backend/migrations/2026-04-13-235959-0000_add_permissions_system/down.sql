-- This file should undo anything in `up.sql`
DROP TABLE IF EXISTS policy_assignments;
DROP TABLE IF EXISTS policy_permissions;
DROP TABLE IF EXISTS policies;

DROP TYPE IF EXISTS permission_resource_type;
DROP TYPE IF EXISTS policy_subject_type;
