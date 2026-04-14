-- Your SQL goes here
CREATE TYPE policy_subject_type AS ENUM ('user', 'discuz_group');

CREATE TYPE permission_resource_type AS ENUM ('global', 'chat');

CREATE TABLE policies (
    id BIGINT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE policy_permissions (
    id BIGINT PRIMARY KEY,
    policy_id BIGINT NOT NULL REFERENCES policies(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    resource_type permission_resource_type NOT NULL,
    resource_id BIGINT,
    created_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT policy_permissions_scope_chk CHECK (
        (resource_type = 'global' AND resource_id IS NULL)
        OR (resource_type = 'chat' AND resource_id IS NOT NULL)
    )
);

CREATE TABLE policy_assignments (
    id BIGINT PRIMARY KEY,
    subject_type policy_subject_type NOT NULL,
    subject_id BIGINT NOT NULL,
    policy_id BIGINT NOT NULL REFERENCES policies(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_policy_assignments_subject
ON policy_assignments(subject_type, subject_id, policy_id);

CREATE INDEX idx_policy_assignments_policy_id
ON policy_assignments(policy_id);

CREATE INDEX idx_policy_permissions_policy_id
ON policy_permissions(policy_id);

CREATE INDEX idx_policy_permissions_action_scope
ON policy_permissions(action, resource_type, resource_id, policy_id);

CREATE UNIQUE INDEX idx_policy_permissions_unique_global
ON policy_permissions(policy_id, action, resource_type)
WHERE resource_type = 'global';

CREATE UNIQUE INDEX idx_policy_permissions_unique_scoped
ON policy_permissions(policy_id, action, resource_type, resource_id)
WHERE resource_type <> 'global';

INSERT INTO policies (id, name, metadata, created_at, updated_at)
VALUES
    (
        1,
        'permission_admin',
        jsonb_build_object(
            'reserved', true,
            'description', 'Reserved unassigned policy for permission-management APIs'
        ),
        NOW(),
        NOW()
    );

INSERT INTO policy_permissions (id, policy_id, action, resource_type, resource_id, created_at)
VALUES
    (1, 1, 'permission.all', 'global', NULL, NOW());
