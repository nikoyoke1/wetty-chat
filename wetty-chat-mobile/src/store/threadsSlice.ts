import type { PayloadAction } from '@reduxjs/toolkit';
import { createSlice } from '@reduxjs/toolkit';
import type { RootState } from './index';
import type { StoredThreadListItem, ThreadListItem, ThreadReplyPreview } from '@/api/threads';

export interface ThreadUpdatePayload {
  threadRootId: string;
  chatId: string;
  lastReplyAt: string;
  replyCount: number;
}

function toStoredThread(item: ThreadListItem): StoredThreadListItem {
  const { lastReply, ...rest } = item;
  return { ...rest, cachedLastReply: lastReply };
}

interface ThreadsState {
  items: StoredThreadListItem[];
  nextCursor: string | null;
  totalUnreadCount: number;
  isLoaded: boolean;
  subscriptionByThreadId: Record<string, boolean>;
}

const initialState: ThreadsState = {
  items: [],
  nextCursor: null,
  totalUnreadCount: 0,
  isLoaded: false,
  subscriptionByThreadId: {},
};

const threadsSlice = createSlice({
  name: 'threads',
  initialState,
  reducers: {
    setThreadsList(state, action: PayloadAction<{ threads: ThreadListItem[]; nextCursor: string | null }>) {
      state.items = action.payload.threads.map(toStoredThread);
      state.nextCursor = action.payload.nextCursor;
      state.isLoaded = true;
      state.subscriptionByThreadId = Object.fromEntries(
        action.payload.threads.map((thread) => [thread.threadRootMessage.id, true]),
      );
      state.totalUnreadCount = state.items.reduce((sum, t) => sum + (t.unreadCount ?? 0), 0);
    },
    appendThreads(state, action: PayloadAction<{ threads: ThreadListItem[]; nextCursor: string | null }>) {
      const existingIds = new Set(state.items.map((t) => t.threadRootMessage.id));
      const newThreads = action.payload.threads
        .filter((t) => !existingIds.has(t.threadRootMessage.id))
        .map(toStoredThread);
      state.items.push(...newThreads);
      state.nextCursor = action.payload.nextCursor;
      for (const thread of action.payload.threads) {
        state.subscriptionByThreadId[thread.threadRootMessage.id] = true;
      }
      state.totalUnreadCount = state.items.reduce((sum, t) => sum + (t.unreadCount ?? 0), 0);
    },
    updateThreadFromWs(state, action: PayloadAction<ThreadUpdatePayload>) {
      const { threadRootId, lastReplyAt, replyCount } = action.payload;
      const idx = state.items.findIndex((t) => t.threadRootMessage.id === threadRootId);
      if (idx >= 0) {
        const thread = state.items[idx];
        thread.replyCount = replyCount;
        thread.lastReplyAt = lastReplyAt;
        // Move to top of list
        state.items.splice(idx, 1);
        state.items.unshift(thread);
      }
      state.totalUnreadCount = state.items.reduce((sum, t) => sum + (t.unreadCount ?? 0), 0);
    },
    /** Update the cached preview for threads whose messages aren't loaded in messagesSlice. */
    updateThreadCachedLastReply(
      state,
      action: PayloadAction<{ threadRootId: string; cachedLastReply: ThreadReplyPreview }>,
    ) {
      const thread = state.items.find((t) => t.threadRootMessage.id === action.payload.threadRootId);
      if (thread) {
        thread.cachedLastReply = action.payload.cachedLastReply;
      }
    },
    /** Partially patch the cached preview (e.g. mark as deleted when the thread window isn't loaded). */
    patchThreadCachedLastReply(
      state,
      action: PayloadAction<{ threadRootId: string; patch: Partial<ThreadReplyPreview> }>,
    ) {
      const thread = state.items.find((t) => t.threadRootMessage.id === action.payload.threadRootId);
      if (thread && thread.cachedLastReply) {
        Object.assign(thread.cachedLastReply, action.payload.patch);
      }
    },
    incrementThreadUnread(state, action: PayloadAction<{ threadRootId: string }>) {
      const thread = state.items.find((t) => t.threadRootMessage.id === action.payload.threadRootId);
      if (thread) {
        thread.unreadCount = (thread.unreadCount ?? 0) + 1;
      }
      state.totalUnreadCount = state.items.reduce((sum, t) => sum + (t.unreadCount ?? 0), 0);
    },
    markThreadRead(state, action: PayloadAction<{ threadRootId: string }>) {
      const thread = state.items.find((t) => t.threadRootMessage.id === action.payload.threadRootId);
      if (thread) {
        thread.unreadCount = 0;
      }
      state.totalUnreadCount = state.items.reduce((sum, t) => sum + (t.unreadCount ?? 0), 0);
    },
    setThreadSubscriptionStatus(state, action: PayloadAction<{ threadRootId: string; subscribed: boolean }>) {
      state.subscriptionByThreadId[action.payload.threadRootId] = action.payload.subscribed;
    },
    removeThread(state, action: PayloadAction<{ threadRootId: string }>) {
      state.items = state.items.filter((t) => t.threadRootMessage.id !== action.payload.threadRootId);
      state.subscriptionByThreadId[action.payload.threadRootId] = false;
      state.totalUnreadCount = state.items.reduce((sum, t) => sum + (t.unreadCount ?? 0), 0);
    },
    patchThreadRootMessage(
      state,
      action: PayloadAction<{ threadRootId: string; message: Partial<{ message: string | null; isDeleted: boolean }> }>,
    ) {
      const thread = state.items.find((t) => t.threadRootMessage.id === action.payload.threadRootId);
      if (thread) {
        Object.assign(thread.threadRootMessage, action.payload.message);
      }
    },
    clearThreads(state) {
      state.items = [];
      state.nextCursor = null;
      state.isLoaded = false;
      state.subscriptionByThreadId = {};
    },
  },
});

export const {
  setThreadsList,
  appendThreads,
  updateThreadFromWs,
  updateThreadCachedLastReply,
  patchThreadCachedLastReply,
  incrementThreadUnread,
  markThreadRead,
  setThreadSubscriptionStatus,
  removeThread,
  patchThreadRootMessage,
  clearThreads,
} = threadsSlice.actions;

export const selectThreads = (state: RootState) => state.threads.items;
export const selectThreadsLoaded = (state: RootState) => state.threads.isLoaded;
export const selectThreadsNextCursor = (state: RootState) => state.threads.nextCursor;
export const selectTotalUnreadThreadCount = (state: RootState) => state.threads.totalUnreadCount;
export const selectThreadSubscriptionStatus = (state: RootState, threadRootId: string) =>
  state.threads.subscriptionByThreadId[threadRootId] ?? null;
export const selectShouldShowThreadsRow = (state: RootState) =>
  state.threads.totalUnreadCount > 0 || (state.threads.isLoaded && state.threads.items.length > 0);

export default threadsSlice.reducer;
