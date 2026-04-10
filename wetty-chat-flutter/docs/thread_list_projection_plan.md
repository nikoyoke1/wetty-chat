# Thread List Projection Plan

## Summary
Make Flutter thread-list updates symmetric with chat-list updates by treating thread rows as projections of message-domain events instead of a REST list that gets refreshed on websocket activity.

The backend remains the source of truth. If Flutter receives an update for a message it cannot resolve from currently loaded row state, it should drop that update and let a later fetch reconcile the row. This avoids reconstructing history locally.

The mixed `All` tab should remain a pure merged view over two already-correct stores:

- chat list store
- thread list store

Pull-to-refresh should continue to refresh both chats and threads as a safety net, even after surgical projection is implemented.

## Current Problem
The current Flutter thread store still relies on websocket-triggered refreshes for ordinary thread activity. That creates asymmetry:

- chat rows are patched locally from realtime events
- thread rows are often updated by refetching the list

This has three downsides:

- row correctness depends on fetch timing
- websocket updates are less immediate than chat updates
- mixed-list behavior is harder to reason about because one side is projection-driven and the other side is refresh-driven

## Design Principles

### 1. Message events are canonical
Both chat rows and thread rows should derive from the same event stream:

- message created
- message confirmed
- message updated
- message deleted
- read synced

### 2. Thread rows own only summary fields
Thread list state should not try to own or reconstruct full thread windows. It should own only row-level summary data:

- `threadRootMessage`
- `lastReply`
- `lastReplyAt`
- `replyCount`
- `unreadCount`
- ordering in the list

### 3. Unknown updates are dropped
If an event cannot be resolved from current row state, ignore it locally. Do not refetch just to make that one event fit. The backend remains authoritative, and future fetches or thread-window loads will reconcile.

### 4. Refresh remains fallback, not primary realtime behavior
Keep brute-force refresh for:

- pull-to-refresh
- explicit manual reload
- rare unknown-thread appearance if product wants it

Do not use list refetch as the normal path for known thread-row updates.

## PWA Reference
The PWA already follows the intended model:

- message events are canonical and projected into both chat and thread list reducers:
  [index.ts](/Users/codetector/projects/wetty-chat/wetty-chat-mobile/src/store/index.ts#L21)
- thread rows are patched surgically for reply/root/unread/remove cases:
  [threadsSlice.ts](/Users/codetector/projects/wetty-chat/wetty-chat-mobile/src/store/threadsSlice.ts#L29)
- websocket-triggered refetch only happens when the event refers to a thread the store cannot already represent:
  [ws.ts](/Users/codetector/projects/wetty-chat/wetty-chat-mobile/src/api/ws.ts#L425)
- mixed-list refresh refreshes both chats and threads together:
  [ChatList.tsx](/Users/codetector/projects/wetty-chat/wetty-chat-mobile/src/components/chat/ChatList.tsx#L170)

Flutter should copy the projection model, not Redux itself.

## Target Flutter Store Shape
`ThreadListNotifier` should become a projection store with explicit row operations rather than a fetch-first store with a websocket refresh hook.

Required row-level operations:

- `applyReplyCreated`
- `applyReplyConfirmed`
- `applyReplyPatched`
- `applyRootPatched`
- `removeThread`
- `incrementUnread`
- `markThreadRead`

These operations should mutate only thread-row summary state.

## Event Matrix

| Event | Preconditions | Local Mutation | Reorder | Unread Change | Ignore Conditions | Fallback Refresh |
| --- | --- | --- | --- | --- | --- | --- |
| Reply created from another user | Row for `replyRootId` exists | Set `lastReply` from payload, set `lastReplyAt`, increment `replyCount` | Move row to top | `+1` | Ignore if thread row does not exist | Optional only if product wants newly-known subscribed threads to appear immediately |
| Reply created from current user via websocket | Row exists | Same as reply created | Move row to top | None | Ignore if row missing | No |
| Reply confirmed for optimistic local send | Row exists and optimistic send already succeeded in timeline | Patch `lastReply`, `lastReplyAt`, increment `replyCount` if not already reflected | Move row to top | None | Ignore if row missing | No |
| Reply updated and it matches current `lastReply` | Row exists and `lastReply.id == payload.id` | Patch `lastReply` preview fields in place | No | None | Ignore if row missing or payload is not current `lastReply` | No |
| Reply deleted and it matches current `lastReply` | Row exists and `lastReply.id == payload.id` | Patch current `lastReply` as deleted; do not try to discover prior reply | No | None | Ignore if row missing or payload is not current `lastReply` | No |
| Reply updated/deleted but not current `lastReply` | Row exists but payload is not current row preview | None | No | None | Always ignore | No |
| Root message updated | Row exists and `threadRootId == payload.id` | Patch `threadRootMessage` preview fields | No | None | Ignore if row missing | No |
| Root message deleted | Row exists and `threadRootId == payload.id` | Remove thread row | Remove row | Decrease total unread by row unread count | Ignore if row missing | No |
| Thread read synced from thread detail | Row exists | Set `unreadCount = 0` | No | Clear unread | Ignore if row missing | No |
| Reply created for thread not in list | No existing row | None | No | None | Always ignore locally | Allowed only if we decide unknown subscribed-thread appearance must be realtime |
| Reply updated/deleted for unknown message | Payload not represented by current row state | None | No | None | Always ignore locally | No |

## Explicit Policy For The Hard Case
If Flutter receives an update or delete for a thread message that it does not have in any loaded row summary, it should drop the event.

This includes:

- non-latest reply edits/deletes
- latest-reply edits/deletes when the row cannot be identified from current preview state
- messages for threads not currently represented in the thread list

Reasoning:

- backend is authoritative
- future fetches and thread-window loads will reconcile state
- local reconstruction logic is not worth the complexity for these edge cases

## Suggested Projection Rules

### Reply created
- Requires `replyRootId`
- Update:
  - `lastReply`
  - `lastReplyAt`
  - `replyCount += 1`
- Move row to top
- Increment unread only when sender is not the current user

### Reply confirmed
- Same row patch as created
- Never increments unread
- Used for optimistic-send reconciliation so the row stays correct even before a later fetch

### Reply updated
- Only patch if the payload matches the row's current `lastReply`
- Never scan or reconstruct previous replies

### Reply deleted
- Only patch if the payload matches the row's current `lastReply`
- Mark preview as deleted instead of trying to discover the previous latest reply

### Root updated
- Patch root preview fields in place

### Root deleted
- Remove the thread row entirely

### Read synced
- Clear row unread immediately after successful mark-read
- Treat backend success as confirmation, not as the only source of truth

## Implementation Plan

### Phase 1: Formalize projection API
Update `ThreadListNotifier` so it exposes explicit row-summary operations instead of only `load`, `refresh`, and websocket refresh behavior.

Expected methods:

- `applyReplyCreated(MessageItemDto payload, {required bool incrementUnread})`
- `applyReplyPatched(MessageItemDto payload, {required bool deleted})`
- `applyRootPatched(MessageItemDto payload, {required bool deleted})`
- `markThreadRead({required int threadRootId, required int messageId})`
- `recordOutgoingReply(ConversationMessage message)`

Goal:

- make thread mutations understandable as business operations
- isolate row semantics from websocket transport logic

### Phase 2: Replace ordinary realtime refresh with local projection
In `thread_repository.dart`, replace the current websocket path that calls `_refreshForRealtimeActivity()` for known thread events.

New behavior:

- classify message payload as root event vs reply event
- if matching row exists, apply local row mutation
- if row does not exist, ignore by default

Keep `_refreshForRealtimeActivity()` temporarily behind rare fallback paths only.

### Phase 3: Align outgoing send flow with projection model
Keep optimistic sends in conversation detail, but ensure thread-list projection is updated through row-summary methods rather than detail-screen refresh logic.

Expected result:

- sending inside a thread updates the thread row immediately
- no dependency on navigating back
- no dependency on list refetch

### Phase 4: Narrow refresh fallback
After local projection covers common reply/root/unread cases, reduce refresh fallback to:

- manual pull-to-refresh
- initial load
- explicit product decision for unknown thread appearance

At this point, websocket-driven list refresh should no longer be the default path for known thread activity.

### Phase 5: Optional projection coordinator
If chat and thread event handling remain duplicated, introduce a thin projection coordinator used by both stores.

Responsibilities:

- inspect canonical message event
- route to chat-row projection
- route to thread-row projection

Do not introduce this before the row operations are settled. Start with explicit repository methods first.

## Proposed File-Level Changes

### `lib/features/chats/threads/data/thread_repository.dart`
- Replace generic websocket refresh logic with row-level projection methods
- Retain explicit fetch methods for initial load / pagination / manual refresh

### `lib/features/chats/threads/application/thread_list_view_model.dart`
- Keep as a thin wrapper over repository state
- Expose row-level methods only if the presentation layer needs them

### `lib/features/chats/conversation/application/conversation_composer_view_model.dart`
- Continue to project outgoing thread replies into the thread list store after successful send
- Route through the new row-level projection methods

### `lib/features/chats/conversation/presentation/thread_detail_view.dart`
- Keep local mark-read flow
- Avoid relying on detail-screen-triggered refresh for correctness

### `lib/features/chats/list/presentation/chat_list_page.dart`
- Keep refreshing both chats and threads on pull-to-refresh
- Keep merged list as a pure view over store state

## Risks

### Double-application risk
If optimistic send confirmation and websocket echo both apply the same thread-row increment, `replyCount` can drift.

Mitigation:

- define one reconciliation rule for optimistic confirmation vs websocket-created event
- prefer idempotent patching where possible

### Missing-row risk
If the store drops unknown-thread events, newly relevant threads may not appear until refresh.

Mitigation:

- decide explicitly whether this is acceptable product behavior
- if not acceptable, keep one narrow refresh path for unknown thread appearance only

### Preview drift risk
If the latest reply is deleted and we mark it deleted instead of finding an earlier reply, the row may stay slightly stale until a later fetch.

Mitigation:

- accept this as deliberate behavior under the "backend is source of truth" rule
- reconcile on future fetch or thread open

## Success Criteria

- Thread rows update immediately for new replies without list refresh
- Thread unread counts clear immediately after successful mark-read
- Root edits/deletes are reflected locally for known rows
- Mixed `All` list remains correct because both stores are independently correct
- Pull-to-refresh still refreshes both lists as a safety net
- Unknown message updates are safely ignored and eventually corrected by fetch
