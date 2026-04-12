import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../../../../app/theme/style_config.dart';
import '../../../../core/network/api_config.dart';
import '../../models/message_models.dart';
import 'message_attachment_previews.dart';
import 'message_bubble/message_bubble.dart';
import 'message_bubble/message_bubble_presentation.dart';
import 'message_bubble/message_render_spec.dart';
import 'message_bubble/voice_message_bubble.dart';
import 'message_overlay_preview.dart';
import 'message_row.dart';

class MessageOverlayAction {
  const MessageOverlayAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isDestructive;
}

class _OverlayPlacement {
  const _OverlayPlacement({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.contentOffset = Offset.zero,
    this.allowsActionOverlap = false,
    this.useCompactPreview = false,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final Offset contentOffset;
  final bool allowsActionOverlap;
  final bool useCompactPreview;
}

class _OverlayLayout {
  const _OverlayLayout({
    required this.preview,
    required this.actionTop,
    required this.actionWidth,
    required this.reactionTop,
    required this.actionsPinnedToBottom,
  });

  final _OverlayPlacement preview;
  final double actionTop;
  final double actionWidth;
  final double? reactionTop;
  final bool actionsPinnedToBottom;
}

class MessageOverlay extends StatelessWidget {
  const MessageOverlay({
    super.key,
    required this.details,
    required this.visible,
    required this.chatMessageFontSize,
    required this.actions,
    required this.quickReactionEmojis,
    required this.onDismiss,
    required this.onToggleReaction,
  });

  static const double _screenPadding = 16;
  static const double _clusterGap = 10;
  static const double _reactionBarHeight = 52;
  static const double _actionRowHeight = 52;
  static const double _actionSheetMinWidth = 148;
  static const double _actionSheetMaxWidth = 240;
  static const double _actionRowHorizontalPadding = 14;
  static const double _actionIconSize = 20;
  static const double _actionIconGap = 10;
  static const double _minTallPreviewLines = 4;
  static const double _bubbleVerticalPadding = 16;
  static const double _bubbleHorizontalPadding = 24;
  static const double _fullBubbleHeightSafetyMargin = 2;
  static const double _attachmentSectionLeadingGap = 8;
  static const double _multiImageHeightSafetyMargin = 10;
  static const double _tallImageAspectRatioThreshold = 3.0;
  static const double _overlayReactionBarWidth = 236;

  final MessageLongPressDetails details;
  final bool visible;
  final double chatMessageFontSize;
  final List<MessageOverlayAction> actions;
  final List<String> quickReactionEmojis;
  final VoidCallback onDismiss;
  final ValueChanged<String> onToggleReaction;

  bool get _showReactionBar => details.message.messageType != 'sticker';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final colors = context.appColors;
        final mediaQuery = MediaQuery.of(context);
        final viewportWidth = constraints.maxWidth;
        final viewportHeight = constraints.maxHeight;
        final safeTop = mediaQuery.padding.top + _screenPadding;
        final safeBottom = mediaQuery.padding.bottom + _screenPadding;
        final bottomLimit = viewportHeight - safeBottom;
        final maxPanelWidth = math.max(
          220.0,
          viewportWidth - (_screenPadding * 2),
        );
        final bubbleRect = Rect.fromLTWH(
          details.bubbleRect.left.clamp(0.0, viewportWidth).toDouble(),
          details.bubbleRect.top.clamp(0.0, viewportHeight).toDouble(),
          details.bubbleRect.width.clamp(0.0, viewportWidth).toDouble(),
          details.bubbleRect.height.clamp(0.0, viewportHeight).toDouble(),
        );
        final contentMinWidth = _measureOverlayMinimumBubbleWidth(context);
        final actionWidth = _measureActionWidth(
          context,
          maxWidth: viewportWidth - (_screenPadding * 2),
        );
        final overlayLayout = _resolveOverlayLayout(
          bubbleRect: bubbleRect,
          safeTop: safeTop,
          safeBottom: bottomLimit,
          viewportWidth: viewportWidth,
          actionWidth: actionWidth,
          contentMinWidth: contentMinWidth,
        );
        final previewPlacement = overlayLayout.preview;
        final reactionWidth = math.min(_overlayReactionBarWidth, maxPanelWidth);
        final panelAnchorRect = Rect.fromLTWH(
          previewPlacement.left,
          previewPlacement.top,
          previewPlacement.width,
          previewPlacement.height,
        );
        final reactionLeft = _alignedPanelLeft(
          bubbleRect: panelAnchorRect,
          panelWidth: reactionWidth,
          viewportWidth: viewportWidth,
        );
        final actionLeft = _alignedPanelLeft(
          bubbleRect: panelAnchorRect,
          panelWidth: actionWidth,
          viewportWidth: viewportWidth,
        );
        final reactionTop = overlayLayout.reactionTop;
        final actionTop = overlayLayout.actionTop;

        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !visible,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: visible ? 1 : 0),
                  duration: const Duration(milliseconds: 120),
                  curve: const Cubic(0.16, 1, 0.3, 1),
                  builder: (context, value, child) {
                    return Opacity(opacity: value, child: child);
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDismiss,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: ColoredBox(
                        color: CupertinoColors.black.withAlpha(72),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_showReactionBar && reactionTop != null)
              _buildPositionedOverlayItem(
                left: reactionLeft,
                top: reactionTop,
                width: reactionWidth,
                alignment: details.isMe
                    ? Alignment.bottomRight
                    : Alignment.bottomLeft,
                child: _buildReactionBar(context, colors, reactionWidth),
              ),
            _buildPositionedOverlayItem(
              left: previewPlacement.left,
              top: previewPlacement.top,
              width: previewPlacement.width,
              height: previewPlacement.height,
              alignment: details.isMe
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: _buildBubblePreview(
                context,
                previewPlacement: previewPlacement,
              ),
            ),
            _buildPositionedOverlayItem(
              left: actionLeft,
              top: actionTop,
              width: actionWidth,
              alignment: details.isMe ? Alignment.topRight : Alignment.topLeft,
              child: _buildActionList(context, colors, actionWidth),
            ),
          ],
        );
      },
    );
  }

  double _actionListHeight(int count) {
    if (count <= 0) {
      return 0;
    }
    return (count * _actionRowHeight) + math.max(0, count - 1);
  }

  double _measureActionWidth(BuildContext context, {required double maxWidth}) {
    var widestRowWidth = 0.0;

    for (final action in actions) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: action.label,
          style: appTextStyle(context, fontWeight: FontWeight.w500),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: double.infinity);

      var rowWidth = _actionRowHorizontalPadding * 2;
      if (action.icon != null) {
        rowWidth += _actionIconSize + _actionIconGap;
      }
      rowWidth += textPainter.width;
      widestRowWidth = math.max(widestRowWidth, rowWidth);
    }

    return widestRowWidth
        .clamp(_actionSheetMinWidth, math.min(_actionSheetMaxWidth, maxWidth))
        .toDouble();
  }

  _OverlayLayout _resolveOverlayLayout({
    required Rect bubbleRect,
    required double safeTop,
    required double safeBottom,
    required double viewportWidth,
    required double actionWidth,
    required double contentMinWidth,
  }) {
    final forceCompactPreview = _shouldForceCompactPreviewForImageOverlay(
      bubbleRect: bubbleRect,
    );
    final prefersClippedFullBubble = _prefersClippedFullBubbleOverlay();
    final actionHeight = _actionListHeight(actions.length);
    final reservedTop = _showReactionBar
        ? _reactionBarHeight + _clusterGap
        : 0.0;
    final actionTop = math.max(safeTop, safeBottom - actionHeight);
    final previewMinTop = safeTop + reservedTop;
    final previewMaxBottomWithoutOverlap = actionTop - _clusterGap;
    final previewWidth = math.min(
      math.max(bubbleRect.width, contentMinWidth),
      math.max(0.0, viewportWidth - (_screenPadding * 2)),
    );
    final targetPreviewHeight = _targetPreviewHeight(bubbleRect: bubbleRect);
    final availableHeightWithoutOverlap = math.max(
      0.0,
      previewMaxBottomWithoutOverlap - previewMinTop,
    );
    final maxAllowedPreviewBottom = actionTop + actionHeight;
    final availableHeightWithOverlap = math.max(
      0.0,
      maxAllowedPreviewBottom - previewMinTop,
    );
    final minVisiblePreviewHeight = _minimumVisiblePreviewHeight();
    final horizontalClipOffset = 0.0;

    final previewLeft = _alignedPanelLeft(
      bubbleRect: Rect.fromLTWH(
        bubbleRect.left,
        bubbleRect.top,
        previewWidth,
        bubbleRect.height,
      ),
      panelWidth: previewWidth,
      viewportWidth: viewportWidth,
    );

    late final _OverlayPlacement preview;
    if (!forceCompactPreview &&
        targetPreviewHeight <= availableHeightWithoutOverlap) {
      final previewTop = bubbleRect.top
          .clamp(
            previewMinTop,
            math.max(
              previewMinTop,
              previewMaxBottomWithoutOverlap - targetPreviewHeight,
            ),
          )
          .toDouble();
      preview = _OverlayPlacement(
        left: previewLeft,
        top: previewTop,
        width: previewWidth,
        height: targetPreviewHeight,
        contentOffset: Offset(horizontalClipOffset, 0),
      );

      return _OverlayLayout(
        preview: preview,
        actionTop: preview.top + preview.height + _clusterGap,
        actionWidth: actionWidth,
        reactionTop: _showReactionBar
            ? preview.top - _clusterGap - _reactionBarHeight
            : null,
        actionsPinnedToBottom: false,
      );
    } else {
      final previewHeight = math.min(
        targetPreviewHeight,
        availableHeightWithOverlap,
      );
      final resolvedPreviewHeight = math.max(
        math.min(previewHeight, targetPreviewHeight),
        math.min(minVisiblePreviewHeight, previewHeight),
      );
      final previewTop = bubbleRect.top
          .clamp(
            previewMinTop,
            math.max(
              previewMinTop,
              maxAllowedPreviewBottom - resolvedPreviewHeight,
            ),
          )
          .toDouble();

      preview = _OverlayPlacement(
        left: previewLeft,
        top: previewTop,
        width: previewWidth,
        height: resolvedPreviewHeight,
        contentOffset: Offset(horizontalClipOffset, 0),
        allowsActionOverlap: true,
        useCompactPreview: !prefersClippedFullBubble || forceCompactPreview,
      );

      return _OverlayLayout(
        preview: preview,
        actionTop: actionTop,
        actionWidth: actionWidth,
        reactionTop: _showReactionBar
            ? preview.top - _clusterGap - _reactionBarHeight
            : null,
        actionsPinnedToBottom: true,
      );
    }
  }

  double _targetPreviewHeight({required Rect bubbleRect}) {
    final injectedHeaderHeight = _overlayInjectedSenderHeaderHeight();
    final multiImageDelta = _imageAttachments.length > 1
        ? _multiImageHeightSafetyMargin
        : 0.0;
    if (_usesPreservedImageOverlay()) {
      return bubbleRect.height + injectedHeaderHeight + multiImageDelta;
    }
    return bubbleRect.height + injectedHeaderHeight + multiImageDelta;
  }

  double _minimumVisiblePreviewHeight() {
    final lineHeight = chatMessageFontSize * 1.28;
    final compactOverlaySpec = MessageRenderSpec.overlay(
      message: details.message,
      sourceShowsSenderName: details.sourceShowsSenderName,
      compact: true,
    );
    final senderHeaderAllowance = compactOverlaySpec.showSenderName
        ? MessageBubblePresentation.senderHeaderReservedHeight
        : 0.0;
    return _bubbleVerticalPadding +
        senderHeaderAllowance +
        (lineHeight * _minTallPreviewLines);
  }

  double _overlayInjectedSenderHeaderHeight() {
    final overlaySpec = MessageRenderSpec.overlay(
      message: details.message,
      sourceShowsSenderName: details.sourceShowsSenderName,
      compact: false,
    );
    if (!overlaySpec.injectsSenderHeader) {
      return 0.0;
    }
    final attachmentSectionDelta = overlaySpec.showAttachments
        ? _attachmentSectionLeadingGap
        : 0.0;
    return MessageBubblePresentation.senderHeaderReservedHeight +
        attachmentSectionDelta +
        _fullBubbleHeightSafetyMargin;
  }

  bool _usesPreservedImageOverlay() {
    final renderSpec = MessageRenderSpec.overlay(
      message: details.message,
      sourceShowsSenderName: details.sourceShowsSenderName,
      compact: false,
    );
    return renderSpec.showAttachments && _imageAttachments.isNotEmpty;
  }

  bool _prefersClippedFullBubbleOverlay() {
    return _usesPreservedImageOverlay() && _imageAttachments.length > 1;
  }

  bool _shouldForceCompactPreviewForImageOverlay({required Rect bubbleRect}) {
    if (_imageAttachments.isEmpty) {
      return false;
    }

    if (_imageAttachments.length > 1) {
      return false;
    }

    final sourceMaxAttachmentWidth = _sourceAttachmentMaxWidth(
      bubbleWidth: bubbleRect.width,
    );
    for (final attachment in _imageAttachments) {
      final layout = computeAttachmentPreviewLayout(
        attachment,
        maxWidth: sourceMaxAttachmentWidth,
      );
      final width = attachment.width?.toDouble();
      final height = attachment.height?.toDouble();
      final aspectRatio = (width != null && height != null && width > 0)
          ? height / width
          : 0.0;
      if (layout != null && aspectRatio >= _tallImageAspectRatioThreshold) {
        return true;
      }
    }

    return false;
  }

  List<AttachmentItem> get _imageAttachments => details.message.attachments
      .where((attachment) => attachment.isImage && attachment.url.isNotEmpty)
      .toList(growable: false);

  double _sourceAttachmentMaxWidth({required double bubbleWidth}) {
    return math.max(0.0, bubbleWidth - _bubbleHorizontalPadding);
  }

  double _measureOverlayMinimumBubbleWidth(BuildContext context) {
    final senderName =
        details.message.sender.name ?? 'User ${details.message.sender.uid}';
    final headerContentWidth =
        MessageBubblePresentation.measureSenderHeaderWidth(
          context,
          senderName,
          gender: details.message.sender.gender,
        );
    var requiredContentWidth = headerContentWidth;
    final threadInfo = details.message.threadInfo;
    if (threadInfo != null && threadInfo.replyCount > 0) {
      requiredContentWidth = math.max(
        requiredContentWidth,
        MessageBubblePresentation.measureThreadIndicatorWidth(
          context,
          threadInfo,
        ),
      );
    }
    return requiredContentWidth + 24;
  }

  double _alignedPanelLeft({
    required Rect bubbleRect,
    required double panelWidth,
    required double viewportWidth,
  }) {
    final preferredLeft = details.isMe
        ? bubbleRect.right - panelWidth
        : bubbleRect.left;
    final maxLeft = math.max(
      _screenPadding,
      viewportWidth - panelWidth - _screenPadding,
    );
    return preferredLeft.clamp(_screenPadding, maxLeft).toDouble();
  }

  Widget _buildPositionedOverlayItem({
    required double left,
    required double top,
    required double width,
    double? height,
    required Alignment alignment,
    required Widget child,
  }) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: IgnorePointer(
        ignoring: !visible,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: visible ? 1 : 0),
          duration: const Duration(milliseconds: 150),
          curve: const Cubic(0.16, 1, 0.3, 1),
          builder: (context, value, _) {
            return Opacity(
              opacity: value,
              child: Transform.scale(
                scale: 0.92 + (0.08 * value),
                alignment: alignment,
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBubblePreview(
    BuildContext context, {
    required _OverlayPlacement previewPlacement,
  }) {
    final message = details.message;
    final renderSpec = MessageRenderSpec.overlay(
      message: message,
      sourceShowsSenderName: details.sourceShowsSenderName,
      compact: previewPlacement.useCompactPreview,
    );
    final presentation = MessageBubblePresentation.fromContext(
      context: context,
      message: message,
      isMe: details.isMe,
      chatMessageFontSize: chatMessageFontSize,
      maxBubbleWidth: previewPlacement.width,
    );

    if (previewPlacement.useCompactPreview) {
      return MessageOverlayPreview(
        message: message,
        presentation: presentation,
        chatMessageFontSize: chatMessageFontSize,
        isMe: details.isMe,
        renderSpec: renderSpec,
        maxHeight: previewPlacement.height,
      );
    }

    final isPureAudio =
        message.messageType == 'audio' &&
        message.attachments.length == 1 &&
        message.attachments.first.isAudio;
    final attachmentMaxWidthOverride = _usesPreservedImageOverlay()
        ? _sourceAttachmentMaxWidth(bubbleWidth: details.bubbleRect.width)
        : null;

    final bubble = isPureAudio
        ? VoiceMessageBubble(
            attachment: message.attachments.first,
            isMe: details.isMe,
            renderSpec: renderSpec,
            message: message,
            presentation: presentation,
          )
        : MessageBubble(
            message: message,
            presentation: presentation,
            chatMessageFontSize: chatMessageFontSize,
            isMe: details.isMe,
            renderSpec: renderSpec,
            currentUserId: ApiSession.currentUserId,
            attachmentMaxWidthOverride: attachmentMaxWidthOverride,
          );

    final bubbleContent = Transform.translate(
      offset: -previewPlacement.contentOffset,
      child: SizedBox(width: previewPlacement.width, child: bubble),
    );

    if (previewPlacement.allowsActionOverlap &&
        !previewPlacement.useCompactPreview) {
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minWidth: previewPlacement.width,
          maxWidth: previewPlacement.width,
          minHeight: 0,
          maxHeight: double.infinity,
          child: bubbleContent,
        ),
      );
    }

    return ClipRect(child: bubbleContent);
  }

  Widget _buildReactionBar(
    BuildContext context,
    AppColors colors,
    double width,
  ) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceCard.withAlpha(245),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withAlpha(40),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: quickReactionEmojis
              .map((emoji) {
                final reactedByMe = details.message.reactions.any(
                  (reaction) =>
                      reaction.emoji == emoji && reaction.reactedByMe == true,
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 40),
                    onPressed: () => onToggleReaction(emoji),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: reactedByMe
                            ? CupertinoColors.activeBlue.withAlpha(18)
                            : const Color(0x00000000),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildActionList(
    BuildContext context,
    AppColors colors,
    double width,
  ) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colors.surfaceCard.withAlpha(248),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            _buildActionRow(context, actions[i]),
            if (i < actions.length - 1)
              Container(height: 1, color: colors.separator.withAlpha(90)),
          ],
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, MessageOverlayAction action) {
    final textColor = action.isDestructive
        ? CupertinoColors.systemRed.resolveFrom(context)
        : context.appColors.textPrimary;

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      minimumSize: Size.fromHeight(_actionRowHeight),
      borderRadius: BorderRadius.zero,
      onPressed: action.onPressed,
      child: Row(
        children: [
          if (action.icon != null) ...[
            Icon(action.icon, color: textColor, size: 20),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              action.label,
              style: appTextStyle(
                context,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
