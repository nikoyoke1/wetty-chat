# Backend Permission System Requirements

## Purpose

This document captures the product and backend requirements for a new permission
system. It is intentionally high level. It describes what the system must do,
what constraints it must respect, and what design properties are expected before
implementation begins.

## Problem Statement

The current backend authorization model is too coarse. In practice it relies on:

- chat membership checks
- a small set of hardcoded elevated roles such as chat `admin`
- endpoint-specific authorization logic embedded in handlers

This is sufficient for simple chat access control, but it does not support
granular capabilities such as:

- allowing a user to update one specific chat but not others
- allowing invite management without full admin authority
- granting moderation privileges through reusable policy bundles
- attaching permissions to both individual users and external Discuz groups

The new system should make authorization more granular, more composable, and
more centralized.

## Goals

The permission system must support the following:

- Granular permissions represented as atomic capabilities.
- Reusable policies that bundle multiple permission rules together.
- Policy attachment to individual users.
- Policy attachment to Discuz groups using `discuz.common_member.groupid` /
  `discuz.common_usergroup.groupid`.
- Effective permissions computed as the union of all applicable grants.
- Resource-scoped authorization, especially for chat-specific actions.
- A central authorization evaluation path so handlers can ask whether a user can
  perform an action on a resource.
- A caching strategy that avoids expensive permission recomputation on hot paths.

## Core Requirement Model

The system should conceptually evaluate requests using:

- `subject`
  The actor receiving permissions, initially:
  - user
  - Discuz `groupid`
- `action`
  The requested capability, for example:
  - `chat.update`
  - `member.invite`
  - `message.delete.any`
- `resource`
  The object the action applies to, for example:
  - global scope
  - one specific chat
- `rule`
  An allow grant pairing an action with a resource selector
- `policy`
  A reusable named bag of allow rules

Authorization should answer questions of the form:

- Can `uid=42` perform `chat.update` on `chat=123`?

## Policy Attachment Requirements

The system must allow policies to be attached to:

- a specific user
- a specific Discuz `groupid`

Policy attachments themselves do not carry resource scope in the initial model.
Instead, a policy contains one or more rules, and each rule defines the action
and resource selector it applies to.

The initial resource selectors should support:

- global scope
- one specific chat

Examples:

- a staff policy assigned to Discuz `groupid=7` may contain `chat.create` on
  global scope
- a moderation policy assigned to user `uid=42` may contain `chat.update` and
  `member.invite` for `chat_id=123`
- a global moderation policy assigned to Discuz `groupid=9` may contain
  `chat.update` on global scope, meaning it applies across all chats

## Permission Evaluation Semantics

Effective permissions should be computed as a union of all applicable grants.

Applicable grants include:

- direct user-attached policy rules
- Discuz-group-attached policy rules
- any compatibility or baseline grants required during migration from the
  current `group_membership` / `GroupRole` model

The intended default is:

- no applicable permission means deny
- any applicable allow means allow

Explicit deny rules are not required in the initial version and should be
treated as out of scope unless a later requirement justifies them.

## Resource Scoping Requirements

Permissions must be resource-aware.

This is especially important for chat operations. For example:

- `chat.update` should be grantable for chat `123` without granting it for all
  chats
- `member.invite` should be grantable for one chat without implying global
  authority
- `pin.manage` and `invite.manage` should support chat-level scoping

The resource selector should be attached to each rule rather than to the policy
assignment as a whole. This allows one policy to contain rules for different
resource kinds or scopes when needed.

The design should keep the action and resource separate. The resource identity
should not be encoded into the permission string itself.

## Discuz Integration Requirements

The permission system must integrate with the existing Discuz user-group model.

The first-class external grouping source is:

- `discuz.common_member.groupid`
- `discuz.common_usergroup`

The initial system may rely only on the primary `groupid`. Supplemental Discuz
groups such as `extgroupids` may be deferred to a later phase if they add too
much complexity.

The system should tolerate the fact that Discuz group membership is external to
this backend and may change outside this service.

## Backend Integration Requirements

The design should move authorization toward a central evaluation API. Handler
code should eventually rely on checks shaped like:

- `has_permission(uid, action, resource)`
- `require_permission(uid, action, resource)`

This should replace or subsume endpoint-specific patterns such as:

- hardcoded `admin` checks
- raw membership checks used directly as authorization decisions

The migration may still preserve the current `group_membership.role` model for a
period of compatibility, but the long-term direction is a policy-based
authorization layer.

## Caching Requirements

The permission system must include a caching strategy. The purpose of the cache
is to keep authorization checks cheap, especially on chat-scoped request paths.

The cache should support entries keyed by something equivalent to:

- user identity
- resource type
- resource id

The cache must be invalidatable when relevant authorization inputs change.

Relevant changes include:

- direct user policy attachment changes
- Discuz-group policy attachment changes
- policy rule changes, including chat-scoped rule changes
- compatibility-affecting membership or role changes
- Discuz `groupid` changes for a user

The system should prefer correctness over aggressive caching. A short-lived stale
permission result is worse than a cache miss if it causes incorrect access
decisions.

## Invalidation Requirements

The invalidation model should be explicit, not ad hoc.

At a high level, the system should support invalidation driven by changes to:

- user-auth state
- Discuz-group-auth state
- chat-scoped-auth state

The design should work even if the backend runs on multiple instances.

It should be possible to start with database-backed versioning and local caches.
Redis may be introduced later if shared cache or pub/sub invalidation becomes
necessary, but Redis is not itself the requirement. The requirement is reliable
cache invalidation.

## Non-Goals For Initial Version

The initial version does not need to include:

- explicit deny semantics
- quotas or non-binary configuration values such as upload size tiers
- a fully general relationship-based authorization engine
- nested policy inheritance between arbitrary policy objects
- field-level or column-level permissions
- every possible Discuz grouping feature

The initial version should optimize for a clean, extensible permission model
rather than maximum theoretical flexibility.

## Design Expectations

The implementation design should aim for:

- a normalized and maintainable policy model
- reusable named policies that can act as rule bags when needed
- low-friction integration with the current backend handler structure
- clear separation between identity, authorization data, and request-time
  permission checks
- chat-scoped permissions as a first-class concept
- compatibility with future evolution toward broader resource types if needed

## Summary

The new backend permission system should provide granular, resource-scoped
authorization by attaching reusable policies to users and Discuz groups, where
each policy contains allow rules combining an action with a resource selector.
The system should union all matching rules during evaluation, support chat-level
authority boundaries, centralize authorization checks, and include a reliable
caching and invalidation story suitable for production backend use.
