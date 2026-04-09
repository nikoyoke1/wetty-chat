import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/thread_api_mapper.dart';
import '../models/thread_models.dart';
import 'thread_api_service.dart';

typedef ThreadListState = ({
  List<ThreadListItem> threads,
  String? nextCursor,
  bool hasMore,
  int totalUnreadCount,
});

/// Source of truth for thread list data.
/// Manages pagination and unread count.
class ThreadListNotifier extends Notifier<ThreadListState> {
  @override
  ThreadListState build() {
    return (
      threads: const [],
      nextCursor: null,
      hasMore: false,
      totalUnreadCount: 0,
    );
  }

  ThreadApiService get _service => ref.read(threadApiServiceProvider);

  /// Load the first page of threads.
  Future<void> loadThreads({int limit = 20}) async {
    final res = await _service.fetchThreads(limit: limit);
    final threads = res.threads.map((thread) => thread.toDomain()).toList();

    // Also fetch unread count alongside the initial load.
    final unreadRes = await _service.fetchUnreadThreadCount();

    state = (
      threads: threads,
      nextCursor: res.nextCursor,
      hasMore: res.nextCursor != null && res.nextCursor!.isNotEmpty,
      totalUnreadCount: unreadRes.unreadThreadCount,
    );
  }

  /// Load more threads (next page) using cursor-based pagination.
  Future<void> loadMoreThreads({int limit = 20}) async {
    if (!state.hasMore || state.nextCursor == null) return;
    final res = await _service.fetchThreads(
      limit: limit,
      before: state.nextCursor,
    );
    final existingIds = state.threads.map((t) => t.threadRootId).toSet();
    final newThreads = res.threads
        .map((thread) => thread.toDomain())
        .where((t) => !existingIds.contains(t.threadRootId))
        .toList();
    state = (
      threads: [...state.threads, ...newThreads],
      nextCursor: res.nextCursor,
      hasMore: res.nextCursor != null && res.nextCursor!.isNotEmpty,
      totalUnreadCount: state.totalUnreadCount,
    );
  }

  /// Reload threads from scratch.
  Future<void> refreshThreads() async {
    await loadThreads();
  }
}

final threadListStateProvider =
    NotifierProvider<ThreadListNotifier, ThreadListState>(
      ThreadListNotifier.new,
    );
