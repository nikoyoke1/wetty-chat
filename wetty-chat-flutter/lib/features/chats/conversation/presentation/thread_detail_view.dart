import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/style_config.dart';
import '../../../../core/session/dev_session_store.dart';
import '../../../../core/settings/app_settings_store.dart';
import '../../../../shared/presentation/app_divider.dart';
import '../../../groups/metadata/application/group_metadata_view_model.dart';
import '../application/conversation_composer_view_model.dart';
import '../application/conversation_timeline_view_model.dart';
import '../domain/conversation_message.dart';
import '../domain/conversation_scope.dart';
import '../domain/launch_request.dart';
import '../domain/timeline_entry.dart';
import '../domain/viewport_placement.dart';
import '../../threads/data/thread_api_service.dart';
import '../../threads/data/thread_subscription_provider.dart';
import 'anchored_timeline_view.dart';
import 'chat_detail_view.dart' show shouldShowJumpToLatestFab;
import 'conversation_composer_bar.dart';
import 'message_overlay.dart';
import 'message_row.dart';

class ThreadDetailPage extends ConsumerStatefulWidget {
  const ThreadDetailPage({
    super.key,
    required this.chatId,
    required this.threadRootId,
  });

  final String chatId;
  final String threadRootId;

  @override
  ConsumerState<ThreadDetailPage> createState() => _ThreadDetailPageState();
}

class _ThreadDetailPageState extends ConsumerState<ThreadDetailPage>
    with WidgetsBindingObserver {
  static const double _liveEdgeScrollThreshold = 50;
  static const double _timelineEndPadding = 12;
  static const Duration _overlayAnimationDuration = Duration(milliseconds: 150);
  static const Duration _markReadCooldown = Duration(milliseconds: 500);

  final ScrollController _timelineScrollController = ScrollController();

  bool _isAtLiveEdge = true;
  bool _isOverlayVisible = false;
  int _viewportGeneration = 0;
  Key _timelineViewportKey = const ValueKey<int>(0);
  _ActiveMessageOverlay? _activeOverlay;
  Timer? _overlayDismissTimer;

  int? _maxSeenMessageId;
  Timer? _markReadTimer;

  static const List<String> _quickReactionEmojis = <String>[
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '🎉',
  ];

  ConversationScope get scope =>
      ConversationScope.thread(widget.chatId, widget.threadRootId);

  ConversationTimelineArgs get _timelineArgs =>
      (scope: scope, launchRequest: const LaunchRequest.latest());

  @override
  void initState() {
    super.initState();
    developer.log(
      'initState: chatId=${widget.chatId}, '
      'threadRootId=${widget.threadRootId}, '
      'identity=${identityHashCode(this)}',
      name: 'ThreadDetailView',
    );
    _timelineScrollController.addListener(_onTimelineScroll);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    developer.log(
      'dispose: identity=${identityHashCode(this)}',
      name: 'ThreadDetailView',
    );
    _markReadTimer?.cancel();
    try {
      unawaited(_flushMarkAsRead());
    } catch (_) {}
    WidgetsBinding.instance.removeObserver(this);
    _timelineScrollController.removeListener(_onTimelineScroll);
    _timelineScrollController.dispose();
    _overlayDismissTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      try {
        unawaited(
          ref
              .read(
                conversationTimelineViewModelProvider(_timelineArgs).notifier,
              )
              .flushReadStatus(),
        );
        unawaited(_flushMarkAsRead());
      } catch (_) {}
    }
  }

  void _openMessageOverlay(MessageLongPressDetails details) {
    if (details.message.isDeleted) return;
    FocusScope.of(context).unfocus();
    _overlayDismissTimer?.cancel();
    setState(() {
      _activeOverlay = _ActiveMessageOverlay(details);
      _isOverlayVisible = true;
    });
  }

  void _dismissMessageOverlay() {
    if (_activeOverlay == null) return;
    _overlayDismissTimer?.cancel();
    setState(() {
      _isOverlayVisible = false;
    });
    _overlayDismissTimer = Timer(_overlayAnimationDuration, () {
      if (!mounted) return;
      setState(() {
        if (!_isOverlayVisible) {
          _activeOverlay = null;
        }
      });
    });
  }

  Future<void> _toggleReaction(
    ConversationMessage message,
    String emoji,
  ) async {
    try {
      await ref
          .read(conversationTimelineViewModelProvider(_timelineArgs).notifier)
          .toggleReaction(message, emoji);
    } catch (error) {
      if (!mounted) return;
      _showErrorDialog('$error');
    }
  }

  List<MessageOverlayAction> _overlayActions(ConversationMessage message) {
    final currentUserId = ref.read(authSessionProvider).currentUserId;
    final isOwn = message.sender.uid == currentUserId;
    final composerNotifier = ref.read(
      conversationComposerViewModelProvider(scope).notifier,
    );

    return <MessageOverlayAction>[
      MessageOverlayAction(
        label: 'Reply',
        icon: CupertinoIcons.reply,
        onPressed: () {
          _dismissMessageOverlay();
          composerNotifier.beginReply(message);
        },
      ),
      if (isOwn)
        MessageOverlayAction(
          label: 'Edit',
          icon: CupertinoIcons.pencil,
          onPressed: () {
            _dismissMessageOverlay();
            composerNotifier.clearAttachments();
            composerNotifier.beginEdit(message);
          },
        ),
      if (isOwn)
        MessageOverlayAction(
          label: 'Delete',
          icon: CupertinoIcons.delete,
          isDestructive: true,
          onPressed: () {
            _dismissMessageOverlay();
            _confirmDelete(message);
          },
        ),
    ];
  }

  void _confirmDelete(ConversationMessage message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref
                    .read(conversationComposerViewModelProvider(scope).notifier)
                    .delete(message);
              } catch (error) {
                if (mounted) _showErrorDialog('$error');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _onTimelineScroll() {
    if (!mounted || !_timelineScrollController.hasClients) return;
    final viewState = ref
        .read(conversationTimelineViewModelProvider(_timelineArgs))
        .valueOrNull;
    if (viewState == null) return;

    final position = _timelineScrollController.position;
    final isAtLiveEdge =
        !viewState.canLoadNewer &&
        (position.maxScrollExtent - position.pixels) < _liveEdgeScrollThreshold;
    if (_isAtLiveEdge != isAtLiveEdge) {
      setState(() {
        _isAtLiveEdge = isAtLiveEdge;
      });
    }

    _reportVisibleMessages(viewState);
  }

  void _onNearOlderEdge() {
    final viewState = ref
        .read(conversationTimelineViewModelProvider(_timelineArgs))
        .valueOrNull;
    if (viewState == null ||
        !viewState.canLoadOlder ||
        viewState.isLoadingOlder) {
      return;
    }
    unawaited(
      ref
          .read(conversationTimelineViewModelProvider(_timelineArgs).notifier)
          .loadOlder(),
    );
  }

  void _onNearNewerEdge() {
    final viewState = ref
        .read(conversationTimelineViewModelProvider(_timelineArgs))
        .valueOrNull;
    if (viewState == null ||
        !viewState.canLoadNewer ||
        viewState.isLoadingNewer) {
      return;
    }
    unawaited(
      ref
          .read(conversationTimelineViewModelProvider(_timelineArgs).notifier)
          .loadNewer(),
    );
  }

  void _reportVisibleMessages(ConversationTimelineState viewState) {
    final notifier = ref.read(
      conversationTimelineViewModelProvider(_timelineArgs).notifier,
    );
    for (final entry in viewState.entries) {
      if (entry is TimelineMessageEntry) {
        notifier.onMessageVisible(entry.message);

        // Track max seen message for thread read status
        final id = entry.message.serverMessageId;
        if (id != null &&
            (_maxSeenMessageId == null || id > _maxSeenMessageId!)) {
          _maxSeenMessageId = id;
        }
      }
    }
    _scheduleMarkAsRead();
  }

  void _scheduleMarkAsRead() {
    _markReadTimer?.cancel();
    _markReadTimer = Timer(_markReadCooldown, _flushMarkAsRead);
  }

  Future<void> _flushMarkAsRead() async {
    final messageId = _maxSeenMessageId;
    if (messageId == null) return;
    try {
      await ref
          .read(threadApiServiceProvider)
          .markThreadAsRead(int.parse(widget.threadRootId), messageId);
    } catch (_) {}
  }

  Future<void> _scrollToLatest() async {
    await ref
        .read(conversationTimelineViewModelProvider(_timelineArgs).notifier)
        .jumpToLatest();
  }

  Future<void> _jumpToMessage(int messageId) async {
    await ref
        .read(conversationTimelineViewModelProvider(_timelineArgs).notifier)
        .jumpToMessage(messageId);
  }

  void _resetViewportSession(int sessionId) {
    _timelineViewportKey = ValueKey<int>(sessionId);
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  ThreadSubscriptionArgs get _subscriptionArgs =>
      (chatId: widget.chatId, threadRootId: int.parse(widget.threadRootId));

  Widget _buildSubscriptionButton() {
    final subscriptionAsync = ref.watch(
      threadSubscriptionProvider(_subscriptionArgs),
    );
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: subscriptionAsync.isLoading
          ? null
          : () {
              ref
                  .read(threadSubscriptionProvider(_subscriptionArgs).notifier)
                  .toggle();
            },
      child: subscriptionAsync.when(
        loading: () => const CupertinoActivityIndicator(),
        error: (_, _) => const Icon(CupertinoIcons.bell),
        data: (subscribed) =>
            Icon(subscribed ? CupertinoIcons.bell_fill : CupertinoIcons.bell),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final metadataAsync = ref.watch(
      groupMetadataViewModelProvider(widget.chatId),
    );
    final timelineAsync = ref.watch(
      conversationTimelineViewModelProvider(_timelineArgs),
    );
    final settings = ref.watch(appSettingsProvider);

    timelineAsync.whenData((state) {
      final locatePlan = state.locatePlan;
      if (locatePlan != null) {
        _viewportGeneration += 1;
        _isAtLiveEdge =
            state.viewportPlacement == ConversationViewportPlacement.liveEdge &&
            !state.canLoadNewer;
        _resetViewportSession(_viewportGeneration);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref
              .read(
                conversationTimelineViewModelProvider(_timelineArgs).notifier,
              )
              .consumeLocatePlan();
        });
      }
      if (state.infoMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showErrorDialog(state.infoMessage!);
          ref
              .read(
                conversationTimelineViewModelProvider(_timelineArgs).notifier,
              )
              .clearInfoMessage();
        });
      }
    });

    final chatName = metadataAsync.valueOrNull?.name ?? 'Chat ${widget.chatId}';

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          unawaited(
            ref
                .read(
                  conversationTimelineViewModelProvider(_timelineArgs).notifier,
                )
                .flushReadStatus(),
          );
          unawaited(_flushMarkAsRead());
        }
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Thread',
                style: appTitleTextStyle(
                  context,
                  fontSize: AppFontSizes.appTitle,
                ),
              ),
              Text(
                chatName,
                style: appSecondaryTextStyle(
                  context,
                  fontSize: AppFontSizes.meta,
                ),
              ),
            ],
          ),
          trailing: _buildSubscriptionButton(),
        ),
        child: SafeArea(
          bottom: false,
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    color: colors.chatBackground,
                    child: Stack(
                      children: [
                        timelineAsync.when(
                          loading: () =>
                              const Center(child: CupertinoActivityIndicator()),
                          error: (error, _) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('$error', textAlign: TextAlign.center),
                                  const SizedBox(height: 16),
                                  CupertinoButton.filled(
                                    onPressed: () => ref.invalidate(
                                      conversationTimelineViewModelProvider(
                                        _timelineArgs,
                                      ),
                                    ),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          data: (viewState) =>
                              _buildTimeline(viewState, settings.fontSize),
                        ),
                        if (_activeOverlay case final overlay?)
                          MessageOverlay(
                            details: overlay.details,
                            visible: _isOverlayVisible,
                            chatMessageFontSize: settings.fontSize,
                            actions: _overlayActions(overlay.details.message),
                            quickReactionEmojis: _quickReactionEmojis,
                            onDismiss: _dismissMessageOverlay,
                            onToggleReaction: (emoji) {
                              _dismissMessageOverlay();
                              unawaited(
                                _toggleReaction(overlay.details.message, emoji),
                              );
                            },
                          ),
                        if (timelineAsync.valueOrNull case final viewState?
                            when shouldShowJumpToLatestFab(
                              state: viewState,
                              isAtLiveEdge: _isAtLiveEdge,
                            ))
                          Positioned(
                            right: 16,
                            bottom: 16,
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: _scrollToLatest,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemGrey5
                                      .resolveFrom(context),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(CupertinoIcons.chevron_down),
                                    if ((timelineAsync
                                                .valueOrNull
                                                ?.pendingLiveCount ??
                                            0) >
                                        0)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: Text(
                                          '${timelineAsync.valueOrNull!.pendingLiveCount}',
                                          style: appTextStyle(
                                            context,
                                            fontSize: AppFontSizes.meta,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                ColoredBox(
                  color: colors.backgroundSecondary,
                  child: SafeArea(
                    top: false,
                    child: ConversationComposerBar(
                      scope: scope,
                      onMessageSent: _scrollToLatest,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(
    ConversationTimelineState viewState,
    double chatMessageFontSize,
  ) {
    return AnchoredTimelineView(
      key: _timelineViewportKey,
      entries: viewState.entries,
      anchorIndex: viewState.anchorEntryIndex,
      viewportPlacement: viewState.viewportPlacement,
      scrollController: _timelineScrollController,
      onNearOlderEdge: _onNearOlderEdge,
      onNearNewerEdge: _onNearNewerEdge,
      topPadding: 8,
      bottomPadding: _timelineEndPadding,
      entryBuilder: (context, entry, index) {
        return switch (entry) {
          TimelineMessageEntry(:final message) => MessageRow(
            key: ValueKey(message.stableKey),
            message: message,
            chatMessageFontSize: chatMessageFontSize,
            isHighlighted:
                viewState.highlightedMessageId == message.serverMessageId,
            onLongPress: _openMessageOverlay,
            onReply: () => ref
                .read(conversationComposerViewModelProvider(scope).notifier)
                .beginReply(message),
            onTapReply: message.replyToMessage != null
                ? () => _jumpToMessage(message.replyToMessage!.id)
                : null,
            // No nested threads — don't pass onOpenThread
            onToggleReaction: message.messageType == 'sticker'
                ? null
                : (emoji) => unawaited(_toggleReaction(message, emoji)),
          ),
          TimelineDateSeparatorEntry(:final day) => _buildDateSeparator(day),
          TimelineUnreadMarkerEntry() => _buildUnreadDivider(),
          TimelineHistoryGapOlderEntry() => _buildGapLabel(
            'Pull to load older messages',
          ),
          TimelineHistoryGapNewerEntry() => _buildGapLabel(
            'Scroll down to newer messages',
          ),
          TimelineLoadingOlderEntry() => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          ),
          TimelineLoadingNewerEntry() => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          ),
        };
      },
    );
  }

  Widget _buildDateSeparator(DateTime day) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey4.resolveFrom(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
            style: appOnDarkTextStyle(context, fontSize: AppFontSizes.meta),
          ),
        ),
      ),
    );
  }

  Widget _buildUnreadDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: AppDivider(color: CupertinoColors.systemGrey4)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey4.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Unread Messages',
              style: appOnDarkTextStyle(
                context,
                fontSize: AppFontSizes.meta,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Expanded(child: AppDivider(color: CupertinoColors.systemGrey4)),
        ],
      ),
    );
  }

  Widget _buildGapLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          text,
          style: appSecondaryTextStyle(context, fontSize: AppFontSizes.meta),
        ),
      ),
    );
  }
}

class _ActiveMessageOverlay {
  const _ActiveMessageOverlay(this.details);
  final MessageLongPressDetails details;
}
