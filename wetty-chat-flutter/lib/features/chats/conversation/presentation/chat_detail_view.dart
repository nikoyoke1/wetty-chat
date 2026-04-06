import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routing/route_names.dart';
import '../../../../app/theme/style_config.dart';
import '../../../../core/session/dev_session_store.dart';
import '../../../../core/settings/app_settings_store.dart';
import '../../../../shared/presentation/app_divider.dart';
import '../application/conversation_composer_view_model.dart';
import '../application/conversation_timeline_view_model.dart';
import '../data/attachment_service.dart';
import '../domain/conversation_message.dart';
import '../domain/conversation_scope.dart';
import '../domain/launch_request.dart';
import '../domain/timeline_entry.dart';
import 'anchored_timeline_view.dart';
import 'message_row.dart';

class ChatDetailPage extends ConsumerStatefulWidget {
  const ChatDetailPage({
    super.key,
    required this.chatId,
    required this.chatName,
    this.launchRequest = const LaunchRequest.latest(),
  });

  final String chatId;
  final String chatName;
  final LaunchRequest launchRequest;

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage>
    with WidgetsBindingObserver {
  static const double _liveEdgeScrollThreshold = 50;
  static const double _timelineEndPadding = 12;

  final ScrollController _inputScrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _timelineScrollController = ScrollController();

  late final AttachmentService _attachmentService;
  bool _isUploadingAttachment = false;
  bool _isPopping = false;
  bool _isAtLiveEdge = true;
  int _lastAppliedLocateRevision = 0;
  int _currentViewportSessionId = 0;
  Key _timelineViewportKey = const ValueKey<int>(0);

  ConversationScope get scope => ConversationScope.chat(widget.chatId);

  ConversationTimelineArgs get _timelineArgs =>
      (scope: scope, launchRequest: widget.launchRequest);

  @override
  void initState() {
    super.initState();
    _attachmentService = AttachmentService(ref.read(devSessionProvider));
    _timelineScrollController.addListener(_onTimelineScroll);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final composer = ref.read(conversationComposerViewModelProvider(scope));
      _textController.text = composer.draft;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timelineScrollController.removeListener(_onTimelineScroll);
    _timelineScrollController.dispose();
    _inputScrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Best-effort flush — provider may already be disposed if the
      // app is being terminated, so guard with try/catch.
      try {
        unawaited(
          ref
              .read(
                conversationTimelineViewModelProvider(_timelineArgs).notifier,
              )
              .flushReadStatus(),
        );
      } catch (_) {}
    }
  }

  Future<void> _popWithResult() async {
    if (_isPopping) {
      return;
    }
    _isPopping = true;
    final notifier = ref.read(
      conversationTimelineViewModelProvider(_timelineArgs).notifier,
    );
    final didSync = await notifier.flushReadStatus();
    if (!mounted) {
      return;
    }
    context.pop(
      didSync ||
          ref
                  .read(conversationTimelineViewModelProvider(_timelineArgs))
                  .valueOrNull
                  ?.shouldRefreshChats ==
              true,
    );
  }

  Future<void> _sendMessage() async {
    final composer = ref.read(conversationComposerViewModelProvider(scope));
    final composerNotifier = ref.read(
      conversationComposerViewModelProvider(scope).notifier,
    );
    if (_isUploadingAttachment) {
      _showErrorDialog('File upload is still in progress.');
      return;
    }
    if (composer.isEditing && composer.attachments.isNotEmpty) {
      _showErrorDialog('Editing does not support attachments yet.');
      return;
    }
    if (_textController.text.trim().isEmpty && composer.attachments.isEmpty) {
      return;
    }
    try {
      await composerNotifier.send(text: _textController.text);
      _textController.clear();
      await _scrollToLatest();
    } catch (error) {
      if (mounted) {
        _showErrorDialog('$error');
      }
    }
  }

  void _showMessageActions(ConversationMessage message) {
    if (message.isDeleted) {
      return;
    }
    final currentUserId = ref.read(devSessionProvider);
    final isOwn = message.sender.uid == currentUserId;
    final composerNotifier = ref.read(
      conversationComposerViewModelProvider(scope).notifier,
    );

    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              composerNotifier.beginReply(message);
            },
            child: const Text('Reply'),
          ),
          if (isOwn)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                composerNotifier.clearAttachments();
                composerNotifier.beginEdit(message);
                _textController.text = message.message ?? '';
              },
              child: const Text('Edit'),
            ),
          if (isOwn)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                _confirmDelete(message);
              },
              child: const Text('Delete'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
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
                if (mounted) {
                  _showErrorDialog('$error');
                }
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

    // Live edge detection: in liveLatest mode, offset 0 = at anchor (bottom).
    // Small positive offsets mean content was appended below.
    final position = _timelineScrollController.position;
    final isAtLiveEdge = !viewState.canLoadNewer &&
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
    // No position preservation needed — the center key keeps the anchor stable.
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

  /// Report visible messages for read-status tracking.
  /// In the center-key model we don't have precise per-item visibility,
  /// so we report all messages in the current window. This is safe because
  /// [onMessageVisible] only tracks the max seen message ID and debounces.
  void _reportVisibleMessages(ConversationTimelineState viewState) {
    final notifier = ref.read(
      conversationTimelineViewModelProvider(_timelineArgs).notifier,
    );
    for (final entry in viewState.entries) {
      if (entry is TimelineMessageEntry) {
        notifier.onMessageVisible(entry.message);
      }
    }
  }

  Future<void> _scrollToLatest() async {
    await ref
        .read(conversationTimelineViewModelProvider(_timelineArgs).notifier)
        .jumpToLatest();
  }

  Future<void> _jumpToMessage(int messageId) async {
    final notifier = ref.read(
      conversationTimelineViewModelProvider(_timelineArgs).notifier,
    );
    await notifier.jumpToMessage(messageId);
  }

  void _resetViewportSession(int sessionId) {
    _timelineViewportKey = ValueKey<int>(sessionId);
  }

  Future<(int?, int?)> _decodeImageSize(Uint8List bytes) async {
    try {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, completer.complete);
      final image = await completer.future.timeout(const Duration(seconds: 2));
      final size = (image.width, image.height);
      image.dispose();
      return size;
    } catch (_) {
      return (null, null);
    }
  }

  String _guessContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.zip')) return 'application/zip';
    return 'application/octet-stream';
  }

  Future<void> _pickAttachment() async {
    if (kIsWeb || !Platform.isWindows) {
      _showErrorDialog(
        'Attachment upload is currently only implemented on Windows.',
      );
      return;
    }
    if (_isUploadingAttachment) {
      return;
    }
    final file = await openFile();
    if (file == null) {
      return;
    }
    setState(() {
      _isUploadingAttachment = true;
    });
    try {
      final filename = file.name;
      final contentType = _guessContentType(filename);
      final size = await file.length();
      Uint8List? previewBytes;
      int? width;
      int? height;
      if (contentType.startsWith('image/') && size <= 8 * 1024 * 1024) {
        previewBytes = await file.readAsBytes();
        final dimensions = await _decodeImageSize(previewBytes);
        width = dimensions.$1;
        height = dimensions.$2;
      }

      final uploadInfo = await _attachmentService.requestUploadUrl(
        filename: filename,
        contentType: contentType,
        size: size,
        width: width,
        height: height,
      );
      await _attachmentService.uploadFileToS3(
        uploadUrl: uploadInfo.uploadUrl,
        file: File(file.path),
        contentType: contentType,
      );
      if (!mounted) {
        return;
      }
      ref
          .read(conversationComposerViewModelProvider(scope).notifier)
          .addUploadedAttachment(
            ComposerAttachment(
              id: uploadInfo.attachmentId,
              name: filename,
              mimeType: contentType,
              previewBytes: previewBytes,
            ),
          );
    } catch (error) {
      if (mounted) {
        _showErrorDialog('Upload failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAttachment = false;
        });
      }
    }
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

  Widget _buildNavigationBarTitle(BuildContext context) {
    return Text(
      widget.chatName.isEmpty ? 'Chat ${widget.chatId}' : widget.chatName,
      style: appTitleTextStyle(context, fontSize: AppFontSizes.appTitle),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildNavigationBarTrailing() {
    return SizedBox(
      width: 72,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () => context.push(AppRoutes.chatMembers(widget.chatId)),
            child: const Icon(CupertinoIcons.person_2_fill, size: 22),
          ),
          const SizedBox(width: 12),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () => context.push(
              AppRoutes.chatSettings(widget.chatId),
              extra: {'currentName': widget.chatName},
            ),
            child: const Icon(
              CupertinoIcons.gear_solid,
              size: IconSizes.iconSize,
            ),
          ),
        ],
      ),
    );
  }

  EdgeInsets _timelinePadding(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return EdgeInsets.only(top: 8, bottom: bottomInset + _timelineEndPadding);
  }

  @override
  Widget build(BuildContext context) {
    final timelineAsync = ref.watch(
      conversationTimelineViewModelProvider(_timelineArgs),
    );
    final composer = ref.watch(conversationComposerViewModelProvider(scope));
    final settings = ref.watch(appSettingsProvider);

    timelineAsync.whenData((state) {
      final locatePlan = state.locatePlan;
      if (locatePlan != null) {
        // Re-key the timeline view to force the CustomScrollView to
        // rebuild with the new anchor position.
        if (locatePlan.viewportSessionId != _currentViewportSessionId) {
          _currentViewportSessionId = locatePlan.viewportSessionId;
          _lastAppliedLocateRevision = locatePlan.revision;
          _isAtLiveEdge =
              locatePlan.placement == ConversationLocatePlacement.liveEdge;
          _resetViewportSession(locatePlan.viewportSessionId);
        }
        if (locatePlan.revision > _lastAppliedLocateRevision) {
          _lastAppliedLocateRevision = locatePlan.revision;
          _currentViewportSessionId += 1;
          _isAtLiveEdge =
              locatePlan.placement == ConversationLocatePlacement.liveEdge;
          _resetViewportSession(_currentViewportSessionId);
        }
      }
      if (state.infoMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _showErrorDialog(state.infoMessage!);
          ref
              .read(
                conversationTimelineViewModelProvider(_timelineArgs).notifier,
              )
              .clearInfoMessage();
        });
      }
    });

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
        }
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: _buildNavigationBarTitle(context),
          leading: CupertinoNavigationBarBackButton(onPressed: _popWithResult),
          trailing: _buildNavigationBarTrailing(),
        ),
        child: Container(
          color: const Color(0xFFECE5DD),
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        timelineAsync.when(
                          loading: () => const Center(
                            child: CupertinoActivityIndicator(),
                          ),
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
                          data: (viewState) => _buildTimeline(
                            viewState,
                            settings.fontSize,
                            _timelinePadding(context),
                          ),
                        ),
                        if (timelineAsync.valueOrNull case final viewState?
                            when _shouldShowJumpToLatest(viewState))
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
                                  color:
                                      CupertinoColors.systemGrey5.resolveFrom(
                                    context,
                                  ),
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
                                        padding:
                                            const EdgeInsets.only(left: 6),
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
                  SafeArea(top: false, child: _buildComposer(composer)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _shouldShowJumpToLatest(ConversationTimelineState state) {
    if (state.windowMode != ConversationWindowMode.liveLatest) {
      return true;
    }
    if (state.canLoadNewer) {
      return true;
    }
    return !_isAtLiveEdge;
  }

  Widget _buildTimeline(
    ConversationTimelineState viewState,
    double chatMessageFontSize,
    EdgeInsets contentPadding,
  ) {
    if (viewState.entries.isEmpty) {
      return const Center(child: Text('No messages yet'));
    }
    return AnchoredTimelineView(
      key: _timelineViewportKey,
      entries: viewState.entries,
      anchorIndex: viewState.anchorEntryIndex,
      anchorAlignment: viewState.anchorAlignment,
      scrollController: _timelineScrollController,
      onNearOlderEdge: _onNearOlderEdge,
      onNearNewerEdge: _onNearNewerEdge,
      topPadding: contentPadding.top,
      bottomPadding: contentPadding.bottom,
      entryBuilder: (context, entry, index) {
        return switch (entry) {
          TimelineMessageEntry(:final message) => MessageRow(
            key: ValueKey(message.stableKey),
            message: message,
            chatMessageFontSize: chatMessageFontSize,
            isHighlighted:
                viewState.highlightedMessageId == message.serverMessageId,
            onLongPress: () => _showMessageActions(message),
            onReply: () => ref
                .read(conversationComposerViewModelProvider(scope).notifier)
                .beginReply(message),
            onTapReply: message.replyToMessage != null
                ? () => _jumpToMessage(message.replyToMessage!.id)
                : null,
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

  Widget _buildComposer(ConversationComposerState composer) {
    final isEditing = composer.isEditing;
    final canAttach = !isEditing && !_isUploadingAttachment;
    return Column(
      children: [
        const AppDivider(height: 0.5, color: CupertinoColors.separator),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: canAttach ? _pickAttachment : null,
                    child: Icon(
                      CupertinoIcons.add_circled,
                      color: canAttach
                          ? CupertinoColors.activeBlue.resolveFrom(context)
                          : CupertinoColors.systemGrey2.resolveFrom(context),
                      size: 28,
                    ),
                  ),
                  if (_isUploadingAttachment)
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 2),
                      child: CupertinoActivityIndicator(radius: 8),
                    ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBackground.resolveFrom(
                          context,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: CupertinoColors.systemGrey4.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildComposerPreview(composer),
                          if (composer.attachments.isNotEmpty)
                            _buildAttachmentPreview(composer),
                          CupertinoScrollbar(
                            controller: _inputScrollController,
                            child: CupertinoTextField(
                              controller: _textController,
                              scrollController: _inputScrollController,
                              onChanged: (value) {
                                unawaited(
                                  ref
                                      .read(
                                        conversationComposerViewModelProvider(
                                          scope,
                                        ).notifier,
                                      )
                                      .updateDraft(value),
                                );
                              },
                              placeholder: 'Message',
                              maxLines: 5,
                              minLines: 1,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: CupertinoColors.activeBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.paperplane_fill,
                        size: 20,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComposerPreview(ConversationComposerState composer) {
    final mode = composer.mode;
    return switch (mode) {
      ComposerReplying(:final message) => _previewBar(
        title:
            'Replying to ${message.sender.name ?? 'User ${message.sender.uid}'}',
        body: message.message ?? '',
      ),
      ComposerEditing(:final message) => _previewBar(
        title: 'Edit Message',
        body: message.message ?? '',
      ),
      ComposerIdle() => const SizedBox.shrink(),
    };
  }

  Widget _previewBar({required String title, required String body}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        border: const Border(
          left: BorderSide(color: CupertinoColors.activeBlue, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appTextStyle(
                    context,
                    fontWeight: FontWeight.w600,
                    fontSize: AppFontSizes.bodySmall,
                    color: CupertinoColors.activeBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appSecondaryTextStyle(
                    context,
                    fontSize: AppFontSizes.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: () {
              ref
                  .read(conversationComposerViewModelProvider(scope).notifier)
                  .clearMode();
            },
            child: Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 20,
              color: CupertinoColors.systemGrey3.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview(ConversationComposerState composer) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (int index = 0; index < composer.attachments.length; index++)
            _attachmentChip(composer.attachments[index], index),
        ],
      ),
    );
  }

  Widget _attachmentChip(ComposerAttachment attachment, int index) {
    final borderColor = CupertinoColors.systemGrey4.resolveFrom(context);
    final background = CupertinoColors.systemGrey5.resolveFrom(context);
    final thumb = attachment.isImage
        ? ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              attachment.previewBytes!,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          )
        : Icon(
            CupertinoIcons.doc,
            size: 28,
            color: CupertinoColors.activeBlue.resolveFrom(context),
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          thumb,
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              attachment.name,
              overflow: TextOverflow.ellipsis,
              style: appTextStyle(context, fontSize: AppFontSizes.meta),
            ),
          ),
          const SizedBox(width: 6),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(20, 20),
            onPressed: () {
              ref
                  .read(conversationComposerViewModelProvider(scope).notifier)
                  .removeAttachmentAt(index);
            },
            child: Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 18,
              color: CupertinoColors.systemGrey2.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}
