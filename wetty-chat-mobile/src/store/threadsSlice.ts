import type { PayloadAction } from '@reduxjs/toolkit';
import { createSlice } from '@reduxjs/toolkit';
import type { RootState } from './index';
import type { ThreadListItem, ThreadReplyPreview } from '@/api/threads';

export interface ThreadUpdatePayload {
  threadRootId: string;
  chatId: string;
  lastReplyAt: string;
  replyCount: number;
}

interface ThreadsState {
  items: ThreadListItem[];
  nextCursor: string | null;
  totalUnreadCount: number;
  isLoaded: boolean;
}

const initialState: ThreadsState = {
  items: [],
  nextCursor: null,
  totalUnreadCount: 0,
  isLoaded: false,
};

const threadsSlice = createSlice({
  name: 'threads',
  initialState,
  reducers: {
    setThreadsList(state, action: PayloadAction<{ threads: ThreadListItem[]; nextCursor: string | null }>) {
      state.items = action.payload.threads;
      state.nextCursor = action.payload.nextCursor;
      state.isLoaded = true;
      state.totalUnreadCount = state.items.reduce((sum, t) => sum + (t.unreadCount ?? 0), 0);
    },
    appendThreads(state, action: PayloadAction<{ threads: ThreadListItem[]; nextCursor: string | null }>) {
      const existingIds = new Set(state.items.map((t) => t.threadRootMessage.id));
      const newThreads = action.payload.threads.filter((t) => !existingIds.has(t.threadRootMessage.id));
      state.items.push(...newThreads);
      state.nextCursor = action.payload.nextCursor;
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
    updateThreadLastReply(state, action: PayloadAction<{ threadRootId: string; lastReply: ThreadReplyPreview }>) {
      const idx = state.items.findIndex((t) => t.threadRootMessage.id === action.payload.threadRootId);
      if (idx >= 0) {
        const thread = state.items[idx];
        thread.lastReply = action.payload.lastReply;
        // Move to top so the list order reflects the newest reply
        if (idx > 0) {
          state.items.splice(idx, 1);
          state.items.unshift(thread);
        }
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
    removeThread(state, action: PayloadAction<{ threadRootId: string }>) {
      state.items = state.items.filter((t) => t.threadRootMessage.id !== action.payload.threadRootId);
      state.totalUnreadCount = state.items.reduce((sum, t) => sum + (t.unreadCount ?? 0), 0);
    },
    patchThreadLastReply(
      state,
      action: PayloadAction<{ threadRootId: string; patch: Partial<ThreadReplyPreview> }>,
    ) {
      const thread = state.items.find((t) => t.threadRootMessage.id === action.payload.threadRootId);
      if (thread && thread.lastReply) {
        Object.assign(thread.lastReply, action.payload.patch);
      }
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
    },
  },
});

export const {
  setThreadsList,
  appendThreads,
  updateThreadFromWs,
  updateThreadLastReply,
  incrementThreadUnread,
  markThreadRead,
  removeThread,
  patchThreadLastReply,
  patchThreadRootMessage,
  clearThreads,
} = threadsSlice.actions;

export const selectThreads = (state: RootState) => state.threads.items;
export const selectThreadsLoaded = (state: RootState) => state.threads.isLoaded;
export const selectThreadsNextCursor = (state: RootState) => state.threads.nextCursor;
export const selectTotalUnreadThreadCount = (state: RootState) => state.threads.totalUnreadCount;
export const selectShouldShowThreadsRow = (state: RootState) =>
  state.threads.totalUnreadCount > 0 || (state.threads.isLoaded && state.threads.items.length > 0);

export default threadsSlice.reducer;
