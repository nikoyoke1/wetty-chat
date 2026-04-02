---
name: frontend-bug-triage
description: >
  Triage frontend bugs in the wetty-chat application. Use this skill whenever the user reports a bug,
  describes unexpected UI behavior, mentions something broken or not working, or asks to investigate
  a frontend issue. This includes visual glitches, state management problems, WebSocket/real-time
  issues, API errors surfacing in the UI, broken navigation, notification bugs, and performance
  regressions. Even if the root cause might be in the backend, start here if the symptom is
  observed in the frontend.
---

# Frontend Bug Triage

You are triaging a bug in wetty-chat, a React/Ionic PWA chat application (~20k users).
Your goal is to systematically analyze the reported bug, locate the likely source, suggest
reproduction steps, add diagnostic logging where it helps, and produce a root cause analysis
with a proposed fix.

## Project context

- **Frontend**: `wetty-chat-mobile/` — React 19 + Ionic 8, Redux Toolkit, Axios, Vite
- **Backend**: `backend/` — Rust + Axum + Diesel/PostgreSQL
- **Real-time**: WebSocket via `src/api/ws.ts`, events dispatched as Redux actions
- **State**: Redux slices in `src/store/` — messages use windowed pagination (up to 5 windows per chat)
- **API client**: Axios with interceptors in `src/api/client.ts` (auth, version headers)
- **Routing**: Ionic React Router (React Router v5), mobile tabs + desktop split layout
- **i18n**: Lingui (`t`/`<Trans>`)
- **Storage**: IndexedDB (`src/utils/db.ts`) for JWT, settings, notification high-water marks

## Triage process

### 1. Understand the bug

Start by making sure you understand the reported symptom clearly. If the description is vague,
ask clarifying questions:
- What did the user expect vs. what happened?
- Is it reproducible or intermittent?
- Does it affect specific platforms (mobile/desktop/PWA)?
- Any recent changes that might have introduced it? (check `git log`)

### 2. Locate the problem area

Explore the codebase to narrow down where the bug lives. Use this mental map:

| Symptom | Start looking at |
|---------|-----------------|
| Message not appearing / wrong order | `messagesSlice.ts`, `messageEvents.ts`, `messageProjection.ts` |
| Unread counts wrong | `chatsSlice.ts` projections, `sync.ts`, listener middleware in `store/index.ts` |
| Chat list stale or missing | `chatsSlice.ts`, `api/chats.ts`, `sync.ts` |
| Thread issues | `threadsSlice.ts`, `api/threads.ts` |
| WebSocket disconnects / missed events | `api/ws.ts` (reconnection, backoff, event dispatch) |
| Compose / input issues | `components/chat/compose/` |
| Scroll / virtualization bugs | `components/chat/virtualScroll/`, `ChatVirtualScroll.tsx` |
| Reactions / pins not updating | `messageEvents.ts` (reactionsUpdated), `pinsSlice.ts` |
| Navigation / routing broken | `App.tsx`, `layouts/`, `hooks/useChatRoutes.ts` |
| Auth / 401 errors | `api/client.ts` interceptors, `utils/jwtToken.ts` |
| Push notifications | `hooks/usePushNotifications.ts`, `utils/notificationNavigation.ts` |
| Sticker / media rendering | `components/chat/messages/`, sticker-related components |
| Settings not persisting | `settingsSlice.ts`, `utils/db.ts` (IndexedDB) |
| App not loading / white screen | `bootstrapRecovery.ts`, `main.tsx`, service worker |
| Performance / jank | Virtual scroll config, Redux selectors (missing memoization), re-render cascades |

When the symptom could originate from the backend (wrong data shape, missing fields, race
conditions in API responses), also look at:
- The corresponding backend handler in `backend/src/handlers/`
- The service layer in `backend/src/services/`
- Database queries and migrations in `backend/`

Read the actual code — don't guess from filenames alone. Trace the data flow from the user
action (click, type, navigate) through the component, to the Redux dispatch or API call, and
back through the state update to the re-render.

### 3. Suggest reproduction steps

Write concrete steps another developer could follow to reproduce the bug. Include:
- Starting state (e.g., "open a chat with 100+ messages")
- Actions to perform (be specific: "scroll to top, wait for older messages to load, then send a new message")
- What to observe and where (browser console, network tab, specific UI element)
- Any timing or race-condition aspects ("quickly switch chats while messages are still loading")

### 4. Add diagnostic logging

If the bug is hard to reproduce or the root cause isn't immediately clear from reading the
code, add targeted logging to help narrow it down.

**Ephemeral logs** (for quick one-off debugging):
```ts
console.log("descriptive message", relevantData);
```

**Persistent debug logs** (for issues likely to recur, or where future visibility helps):
```ts
console.debug("[area:component] what happened", { relevantData });
```
Use a bracketed prefix so these can be filtered in DevTools (e.g., `[ws:reconnect]`,
`[messages:reconcile]`, `[sync:chats]`). This makes them easy to find without cluttering
normal console output.

Place logs at decision points — where the code branches, where data transforms, where async
boundaries cross (API response handlers, WebSocket event handlers, Redux middleware). A few
well-placed logs at boundaries are more useful than logging every line.

### 5. Root cause analysis

Summarize what you found:
- **What's happening**: the technical explanation of the bug
- **Why**: the underlying cause (missing null check, race condition, stale selector, wrong
  assumption about data shape, etc.)
- **Impact**: who's affected and under what conditions
- **Confidence**: how sure you are — distinguish between "confirmed by reading the code" vs.
  "likely based on the pattern but needs verification"

### 6. Propose a fix

After identifying the root cause, suggest a concrete fix:
- Show the specific code changes needed
- Explain why the fix addresses the root cause without introducing new issues
- Call out any edge cases the fix needs to handle
- If the fix touches state management, think about whether existing listeners/projections
  need updates too
- If the fix involves the backend, note both frontend and backend changes needed

After implementing the fix, run `npm run verify` from `wetty-chat-mobile/` to ensure lint and
type checks pass. For backend changes, run `cargo build` and `cargo clippy` from `backend/`.

## Things to watch for

These are common patterns that cause bugs in this codebase:

- **Optimistic message IDs**: Messages get a `cg_` prefixed client ID on send, replaced with
  the server ID on confirmation. Bugs happen when code compares IDs without accounting for this.
- **Message window eviction**: Only 5 windows per chat are kept. Loading new message ranges can
  evict old ones, causing "messages disappeared" bugs.
- **WebSocket reconnection races**: After reconnect, `syncApp()` runs with a 20s debounce.
  Events that arrive during the gap between reconnect and sync completion can get lost or
  duplicated.
- **BigInt message ordering**: `messageProjection.ts` uses BigInt for ID comparison. Mixing
  string and number comparisons will break ordering silently.
- **Stale closures in hooks**: WebSocket event handlers and lifecycle callbacks can capture
  stale Redux state if not properly wired to the store.
- **IndexedDB async timing**: JWT token and settings reads are async. Code that assumes
  synchronous availability will fail on cold start.
