import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/thread_repository.dart';
import '../models/thread_models.dart';

typedef ThreadListViewState = ({
  List<ThreadListItem> threads,
  bool hasMore,
  bool isLoadingMore,
  bool isRefreshing,
  String? errorMessage,
});

class ThreadListViewModel extends AsyncNotifier<ThreadListViewState> {
  @override
  Future<ThreadListViewState> build() async {
    // Watch the underlying thread list state for realtime updates.
    ref.listen<ThreadListState>(threadListStateProvider, (_, _) {
      _rebuildFromRepository();
    });
    return _loadInitial();
  }

  Future<ThreadListViewState> _loadInitial() async {
    final notifier = ref.read(threadListStateProvider.notifier);
    await notifier.loadThreads();
    final repoState = ref.read(threadListStateProvider);
    return (
      threads: repoState.threads,
      hasMore: repoState.hasMore,
      isLoadingMore: false,
      isRefreshing: false,
      errorMessage: null,
    );
  }

  void _rebuildFromRepository() {
    final current = state.valueOrNull;
    if (current == null) return;
    final repoState = ref.read(threadListStateProvider);
    state = AsyncData((
      threads: repoState.threads,
      hasMore: repoState.hasMore,
      isLoadingMore: current.isLoadingMore,
      isRefreshing: current.isRefreshing,
      errorMessage: current.errorMessage,
    ));
  }

  Future<void> loadMoreThreads() async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (!current.hasMore || current.isLoadingMore || current.threads.isEmpty) {
      return;
    }
    state = AsyncData((
      threads: current.threads,
      hasMore: current.hasMore,
      isLoadingMore: true,
      isRefreshing: current.isRefreshing,
      errorMessage: current.errorMessage,
    ));
    try {
      await ref.read(threadListStateProvider.notifier).loadMoreThreads();
    } catch (_) {
      // Silently fail pagination.
    } finally {
      final repoState = ref.read(threadListStateProvider);
      final latest = state.valueOrNull;
      if (latest != null) {
        state = AsyncData((
          threads: repoState.threads,
          hasMore: repoState.hasMore,
          isLoadingMore: false,
          isRefreshing: latest.isRefreshing,
          errorMessage: latest.errorMessage,
        ));
      }
    }
  }

  Future<void> refreshThreads({bool userInitiated = false}) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.isLoadingMore || current.isRefreshing) return;

    debugPrint("refreshing threads");
    state = AsyncData((
      threads: current.threads,
      hasMore: current.hasMore,
      isLoadingMore: current.isLoadingMore,
      isRefreshing: true,
      errorMessage: current.errorMessage,
    ));
    try {
      await ref.read(threadListStateProvider.notifier).refreshThreads();
      final repoState = ref.read(threadListStateProvider);
      state = AsyncData((
        threads: repoState.threads,
        hasMore: repoState.hasMore,
        isLoadingMore: false,
        isRefreshing: false,
        errorMessage: null,
      ));
    } catch (e) {
      final latest = state.valueOrNull;
      if (latest != null) {
        state = AsyncData((
          threads: latest.threads,
          hasMore: latest.hasMore,
          isLoadingMore: false,
          isRefreshing: false,
          errorMessage: e.toString(),
        ));
      }
    }
  }
}

final threadListViewModelProvider =
    AsyncNotifierProvider<ThreadListViewModel, ThreadListViewState>(
      ThreadListViewModel.new,
    );
