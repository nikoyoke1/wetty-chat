# Backend Permission Architecture

## Purpose

This document translates the high-level requirements in
`backend/docs/permissions-requirements.md` into a concrete architecture
direction for the first implementation phase.

It is not a migration plan and it is not final implementation detail. Its job
is to define the core data model, the evaluation model, and the main tradeoffs
so that schema work and backend integration can proceed from a shared design.

## Problem

The current backend authorization model is centered around:

- chat membership checks
- the `group_membership.role` enum, especially chat `admin`
- endpoint-specific logic embedded in handlers

This is too limited for the intended future state. The backend needs to support:

- global capabilities such as `chat.create`
- chat-scoped capabilities such as `chat.update`, `member.invite`, and
  `message.delete.any`
- grants attached to either individual users or Discuz groups
- centralized evaluation rather than scattered per-handler authorization logic

## Chosen Model

The first architecture direction treats policies as reusable named rule bags.

In practice this means:

- a `policy` is a named container
- a `permission` is the atomic stored allow entry inside a policy
- a `policy_assignment` attaches a policy to a subject

Each permission carries:

- an `action`
- a `resource selector`

This model was chosen over a pure role-plus-external-scope model because it is
more flexible when one policy needs to contain permissions targeting different
resource kinds or scopes.

The initial version is intentionally limited:

- allow-only semantics
- binary permissions only
- no quotas or configuration values
- no deny rules
- no condition language

This is intentionally much simpler than AWS IAM. The design borrows the idea of
per-permission resource selectors, but not IAM's broader complexity.

## Core Concepts

### Subject

The actor receiving a policy assignment.

Initial subject kinds:

- `user`
- `discuz_group`

### Policy

A reusable named object that groups permissions together.

Policies are allowed to act as rule bags. This means one policy may contain:

- `chat.create` on `global`
- `chat.update` on `chat:123`
- `member.invite` on `chat:123`

This is less role-pure than an assignment-scoped design, but it better fits the
current requirements and future flexibility concerns.

### Permission

A permission is an allow entry inside a policy.

Each permission consists of:

- `action`
- `resource_type`
- `resource_id`

Examples:

- `chat.create` on `global`
- `chat.update` on `chat:123`
- `member.invite` on `chat:123`

The resource identity must remain separate from the action string. The system
must not encode resource identifiers into the permission name itself.

### Policy Assignment

A policy assignment attaches a policy to a subject.

Examples:

- user `uid=42` is assigned policy `staff_basic`
- Discuz `groupid=7` is assigned policy `chat_moderator_123`

Assignments do not carry resource scope in this design. Scope lives in the
permissions contained by the policy.

## First-Pass Resource Model

The initial resource selector model should support:

- `global`
- `chat(chat_id)`

This should be treated as the first implemented resource set, not a permanent
limit on the architecture.

The architecture should still preserve the general shape:

- `resource_type`
- `resource_id`

so that later resource types can be added without redesigning the policy model.

## First-Pass Schema

The first schema pass should use three core tables and two enum-like types.

### Types

```sql
create type policy_subject_type as enum (
    'user',
    'discuz_group'
);

create type permission_resource_type as enum (
    'global',
    'chat'
);
```

### Policies

```sql
create table policies (
    id bigint primary key,
    name text not null,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null,
    updated_at timestamptz not null,
    constraint policies_name_unique unique (name)
);
```

Notes:

- `name` is the stable identifier used by the backend and admin tooling
- `metadata` is optional descriptive data, not part of the evaluation decision
- permission membership does not live inside `metadata`

### Policy Permissions

```sql
create table policy_permissions (
    id bigint primary key,
    policy_id bigint not null references policies(id) on delete cascade,
    action text not null,
    resource_type permission_resource_type not null,
    resource_id bigint null,
    created_at timestamptz not null,
    constraint policy_permissions_scope_chk
        check (
            (resource_type = 'global' and resource_id is null)
            or
            (resource_type = 'chat' and resource_id is not null)
        )
);
```

Notes:

- `action` is stored as a backend-defined string such as `chat.create`
- there is no `permission_definitions` table in the first pass
- `id` exists primarily because Diesel expects a primary key for normal table
  mapping; logical deduplication still comes from the partial unique indexes
- the backend should validate `action` values against a known set in code
- `global` means `resource_id` must be `null`
- `chat` means `resource_id` must be present
- uniqueness should be enforced with partial unique indexes so `global` rows do
  not bypass deduplication because of `null` semantics

### Policy Assignments

```sql
create table policy_assignments (
    id bigint primary key,
    subject_type policy_subject_type not null,
    subject_id bigint not null,
    policy_id bigint not null references policies(id) on delete cascade,
    created_at timestamptz not null,
    updated_at timestamptz not null
);
```

Notes:

- `subject_id` stores either `uid` or Discuz `groupid` depending on
  `subject_type`
- assignments do not encode scope
- a subject may receive multiple policies

## Indexing Direction

The expected hot path is:

1. determine the request subject set
2. load all policies assigned to that subject set
3. test whether any permission across those policies matches the requested
   `action + resource`

The initial indexing direction should be:

```sql
create index idx_policy_assignments_subject
on policy_assignments (subject_type, subject_id, policy_id);

create index idx_policy_assignments_policy_id
on policy_assignments (policy_id);

create index idx_policy_permissions_policy_id
on policy_permissions (policy_id);

create index idx_policy_permissions_action_scope
on policy_permissions (action, resource_type, resource_id, policy_id);

create unique index idx_policy_permissions_unique_global
on policy_permissions (policy_id, action, resource_type)
where resource_type = 'global';

create unique index idx_policy_permissions_unique_scoped
on policy_permissions (policy_id, action, resource_type, resource_id)
where resource_type <> 'global';
```

This should support the first-pass evaluation query shape without prematurely
optimizing around a more complex cache design.

## Evaluation Semantics

Authorization should eventually flow through a central backend API, shaped like:

- `has_permission(uid, action, resource)`
- `require_permission(uid, action, resource)`

The evaluation model for the policy system should be:

1. resolve the subject set for the caller
2. load all policy assignments for those subjects
3. load all matching permissions from those policies
4. return allow if any permission matches the requested action and resource
5. otherwise deny

Initial subject resolution should include:

- direct user subject: `user(uid)`
- Discuz subject from `discuz.common_member.groupid`

Initial resource matching semantics should be:

- requested `global` matches only permissions stored as `global`
- requested `chat(chat_id)` matches only permissions stored as that exact chat

The architecture intentionally avoids broader wildcard behavior in the first
pass beyond the explicit `global` resource selector.

The first application permission to be enforced should be:

- `chat.create` on `global`

The first reserved administrative permission should be:

- `permission.all` on `global`

## Compatibility Layer

The backend will likely need a compatibility period where current
`group_membership.role` behavior still participates in authorization.

That compatibility logic should not change the policy schema. Instead, it should
live in the evaluator as an additional source of effective permissions.

Examples:

- current chat `admin` may temporarily imply `chat.update` for that chat
- current chat membership may temporarily imply baseline chat-member actions

The long-term direction remains the policy-based system, but the evaluator can
support both during migration.

## Example Data

Example policies:

- `staff_basic`
- `chat_admin_123`
- `chat_moderator_123`

Example permissions:

- `staff_basic` contains `chat.create` on `global`
- `chat_admin_123` contains `chat.update` on `chat:123`
- `chat_admin_123` contains `member.invite` on `chat:123`
- `chat_admin_123` contains `message.delete.any` on `chat:123`

Example assignments:

- user `42` assigned `chat_admin_123`
- Discuz group `7` assigned `staff_basic`

## Tradeoffs

This architecture has clear benefits:

- supports policies with mixed resource scopes
- keeps the model flexible as new resource kinds are introduced
- keeps evaluation data normalized
- stays simpler than a full IAM-style condition engine

It also has real costs:

- policies are less purely reusable than assignment-scoped roles
- chat-specific policies may need duplication, cloning, or UI assistance
- policy management UX becomes important sooner

This tradeoff is intentional. The current design favors flexibility and clear
resource-local permissions over minimal policy count.

## Out Of Scope For This Phase

This architecture intentionally does not include:

- explicit deny rules
- quotas or upload-size tiers
- arbitrary conditions
- nested policy inheritance
- every Discuz grouping feature such as `extgroupids`

## Next Design Steps

The next design steps after this document are:

1. define the initial backend-owned action catalog
2. sketch the first evaluation query in Diesel/PostgreSQL terms
3. define the compatibility mapping from `group_membership.role` to effective
   permissions during migration
4. design the cache and invalidation model around this schema
