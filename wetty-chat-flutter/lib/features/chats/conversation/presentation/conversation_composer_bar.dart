import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/style_config.dart';
import '../../../../shared/presentation/app_divider.dart';
import '../../models/message_preview_formatter.dart';
import '../application/conversation_composer_view_model.dart';
import '../data/attachment_picker_service.dart';
import '../domain/conversation_scope.dart';

class ConversationComposerBar extends ConsumerStatefulWidget {
  const ConversationComposerBar({
    super.key,
    required this.scope,
    this.onMessageSent,
  });

  final ConversationScope scope;
  final Future<void> Function()? onMessageSent;

  @override
  ConsumerState<ConversationComposerBar> createState() =>
      _ConversationComposerBarState();
}

class _ConversationComposerBarState
    extends ConsumerState<ConversationComposerBar> {
  final ScrollController _inputScrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();

  ProviderSubscription<ConversationComposerState>? _composerSubscription;

  @override
  void initState() {
    super.initState();
    _composerSubscription = ref.listenManual<ConversationComposerState>(
      conversationComposerViewModelProvider(widget.scope),
      (_, next) => _syncControllerText(next.draft),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _composerSubscription?.close();
    _inputScrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _syncControllerText(String draft) {
    if (_textController.text == draft) {
      return;
    }
    _textController.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }

  Future<void> _sendMessage() async {
    final composer = ref.read(
      conversationComposerViewModelProvider(widget.scope),
    );
    final composerNotifier = ref.read(
      conversationComposerViewModelProvider(widget.scope).notifier,
    );
    if (composer.isEditing && composer.attachments.isNotEmpty) {
      _showErrorDialog('Editing does not support attachments yet.');
      return;
    }
    if (_textController.text.trim().isEmpty &&
        !composer.hasUploadedAttachments) {
      return;
    }
    try {
      await composerNotifier.send(text: _textController.text);
      _textController.clear();
      await widget.onMessageSent?.call();
    } catch (error) {
      if (mounted) {
        _showErrorDialog('$error');
      }
    }
  }

  Future<void> _pickAttachments(ComposerAttachmentSource source) async {
    try {
      final message = await ref
          .read(conversationComposerViewModelProvider(widget.scope).notifier)
          .pickAndQueueAttachments(source);
      if (!mounted || message == null) {
        return;
      }
      _showErrorDialog(message);
    } catch (error) {
      if (mounted) {
        _showErrorDialog('$error');
      }
    }
  }

  Future<void> _showAttachmentSourcePicker() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: const Text('Add Attachment'),
        actions: [
          _sourceAction(
            popupContext,
            label: 'Photos',
            source: ComposerAttachmentSource.photos,
          ),
          _sourceAction(
            popupContext,
            label: 'GIFs',
            source: ComposerAttachmentSource.gifs,
          ),
          _sourceAction(
            popupContext,
            label: 'Videos',
            source: ComposerAttachmentSource.videos,
          ),
          _sourceAction(
            popupContext,
            label: 'Files',
            source: ComposerAttachmentSource.files,
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(popupContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  CupertinoActionSheetAction _sourceAction(
    BuildContext popupContext, {
    required String label,
    required ComposerAttachmentSource source,
  }) {
    return CupertinoActionSheetAction(
      onPressed: () {
        Navigator.of(popupContext).pop();
        unawaited(_pickAttachments(source));
      },
      child: Text(label),
    );
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

  @override
  Widget build(BuildContext context) {
    final composer = ref.watch(
      conversationComposerViewModelProvider(widget.scope),
    );
    final colors = context.appColors;
    final canAttach = !composer.isEditing;

    return ColoredBox(
      color: colors.backgroundSecondary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(36, 36),
                    onPressed: canAttach ? _showAttachmentSourcePicker : null,
                    child: Icon(
                      CupertinoIcons.add_circled,
                      color: canAttach
                          ? CupertinoColors.activeBlue.resolveFrom(context)
                          : CupertinoColors.systemGrey2.resolveFrom(context),
                      size: 28,
                    ),
                  ),
                ),
                if (composer.hasPendingAttachmentUploads)
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 2),
                    child: CupertinoActivityIndicator(radius: 8),
                  ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.inputBorder),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(19),
                      child: ColoredBox(
                        color: colors.backgroundSecondary,
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
                                            widget.scope,
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
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 48,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(36, 36),
                      onPressed: composer.canSend ? _sendMessage : null,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: composer.canSend
                              ? CupertinoColors.activeBlue.resolveFrom(context)
                              : CupertinoColors.systemGrey3.resolveFrom(
                                  context,
                                ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.paperplane_fill,
                          size: 20,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposerPreview(ConversationComposerState composer) {
    final mode = composer.mode;
    return switch (mode) {
      ComposerReplying(:final message) => _previewBar(
        title:
            'Replying to ${message.sender.name ?? 'User ${message.sender.uid}'}',
        body: formatMessagePreview(
          message: message.message,
          messageType: message.messageType,
          sticker: message.sticker,
          attachments: message.attachments,
          firstAttachmentKind: message.attachments.isNotEmpty
              ? message.attachments.first.kind
              : null,
          isDeleted: message.isDeleted,
          mentions: message.mentions,
        ),
      ),
      ComposerEditing(:final message) => _previewBar(
        title: 'Edit message',
        body: formatMessagePreview(
          message: message.message,
          messageType: message.messageType,
          sticker: message.sticker,
          attachments: message.attachments,
          firstAttachmentKind: message.attachments.isNotEmpty
              ? message.attachments.first.kind
              : null,
          isDeleted: message.isDeleted,
          mentions: message.mentions,
        ),
      ),
      ComposerIdle() => const SizedBox.shrink(),
    };
  }

  Widget _previewBar({required String title, required String body}) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 4),
      decoration: BoxDecoration(
        color: colors.composerReplyPreviewSurface,
        border: Border(
          bottom: BorderSide(color: colors.composerReplyPreviewDivider),
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
                    fontSize: AppFontSizes.meta,
                    color: colors.composerReplyPreviewTitle,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appSecondaryTextStyle(
                    context,
                    fontSize: AppFontSizes.meta,
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
                  .read(
                    conversationComposerViewModelProvider(
                      widget.scope,
                    ).notifier,
                  )
                  .clearMode();
            },
            child: Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 18,
              color: colors.inactive,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview(ConversationComposerState composer) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${composer.attachments.length}/$composerMaxAttachments attachments',
              style: appSecondaryTextStyle(
                context,
                fontSize: AppFontSizes.meta,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final attachment in composer.attachments)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _attachmentCard(attachment),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachmentCard(ComposerAttachment attachment) {
    final borderColor = CupertinoColors.systemGrey4.resolveFrom(context);
    final background = CupertinoColors.systemGrey5.resolveFrom(context);
    return Container(
      width: 136,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _attachmentPreviewThumb(attachment),
          const SizedBox(height: 8),
          Text(
            attachment.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: appTextStyle(context, fontSize: AppFontSizes.meta),
          ),
          const SizedBox(height: 4),
          Text(
            _attachmentStatusLabel(attachment),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: appSecondaryTextStyle(context, fontSize: AppFontSizes.meta),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (attachment.isFailed)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(24, 24),
                  onPressed: () {
                    unawaited(
                      ref
                          .read(
                            conversationComposerViewModelProvider(
                              widget.scope,
                            ).notifier,
                          )
                          .retryAttachment(attachment.localId),
                    );
                  },
                  child: Text(
                    'Retry',
                    style: appTextStyle(
                      context,
                      fontSize: AppFontSizes.meta,
                      color: CupertinoColors.activeBlue.resolveFrom(context),
                    ),
                  ),
                )
              else
                const SizedBox(width: 24),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(24, 24),
                onPressed: () {
                  ref
                      .read(
                        conversationComposerViewModelProvider(
                          widget.scope,
                        ).notifier,
                      )
                      .removeAttachment(attachment.localId);
                },
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 18,
                  color: CupertinoColors.systemGrey2.resolveFrom(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attachmentPreviewThumb(ComposerAttachment attachment) {
    final background = CupertinoColors.systemGrey4.resolveFrom(context);
    final icon = switch (attachment.kind) {
      ComposerAttachmentKind.video => CupertinoIcons.play_rectangle_fill,
      ComposerAttachmentKind.file => CupertinoIcons.doc_fill,
      _ => CupertinoIcons.photo_fill,
    };
    if (attachment.isImageLike) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          attachment.previewBytes!,
          width: 120,
          height: 88,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: 120,
      height: 88,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 34,
        color: CupertinoColors.activeBlue.resolveFrom(context),
      ),
    );
  }

  String _attachmentStatusLabel(ComposerAttachment attachment) {
    return switch (attachment.status) {
      ComposerAttachmentUploadStatus.queued => 'Queued',
      ComposerAttachmentUploadStatus.uploading => 'Uploading...',
      ComposerAttachmentUploadStatus.uploaded => 'Ready',
      ComposerAttachmentUploadStatus.failed =>
        attachment.errorMessage ?? 'Upload failed',
    };
  }
}
