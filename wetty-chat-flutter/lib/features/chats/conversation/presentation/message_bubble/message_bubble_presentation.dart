import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../domain/conversation_message.dart';
import '../../../../../app/theme/style_config.dart';
import '../../../chat_timestamp_formatter.dart';
import '../../../models/message_models.dart';

class MessageBubblePresentation {
  static const double maxRowWidthFactor = 0.80;
  static const double rowHorizontalPadding = 24;
  static const double avatarSlotWidth = 36;
  static const double avatarGap = 8;
  static const double statusIconSize = 14;
  static const double statusIconGap = 4;
  static const double senderHeaderBadgeGap = 4;
  static const double senderHeaderBadgeSize = 11;
  static const double senderHeaderBodyGap = 4;
  static const double senderHeaderReservedHeight = 24;
  static const double threadIndicatorIconSize = 12;
  static const double threadIndicatorIconGap = 4;

  const MessageBubblePresentation({
    required this.senderName,
    required this.timeStr,
    required this.maxBubbleWidth,
    required this.bubbleColor,
    required this.textColor,
    required this.metaColor,
    required this.linkColor,
    required this.timeSpacerWidth,
    required this.minBubbleContentHeight,
  });

  factory MessageBubblePresentation.fromContext({
    required BuildContext context,
    required ConversationMessage message,
    required bool isMe,
    required double chatMessageFontSize,
    double? maxBubbleWidth,
  }) {
    final colors = context.appColors;
    final senderName = message.sender.name ?? 'User ${message.sender.uid}';
    final timeStr = formatChatMessageTime(context, message.createdAt);
    final screenWidth = MediaQuery.sizeOf(context).width;

    return MessageBubblePresentation(
      senderName: senderName,
      timeStr: timeStr,
      maxBubbleWidth:
          maxBubbleWidth ??
          math.max(
            0,
            (screenWidth * maxRowWidthFactor) -
                rowHorizontalPadding -
                avatarSlotWidth -
                avatarGap,
          ),
      bubbleColor: isMe ? colors.chatSentBubble : colors.chatReceivedBubble,
      textColor: isMe ? colors.textOnAccent : colors.textPrimary,
      metaColor: isMe ? colors.chatSentMeta : colors.chatReceivedMeta,
      linkColor: isMe ? colors.chatLinkOnSent : colors.chatLinkOnReceived,
      timeSpacerWidth:
          measureMetaWidth(context, message, timeStr, isMe: isMe) + 8,
      minBubbleContentHeight: chatMessageFontSize * 1.28,
    );
  }

  final String senderName;
  final String timeStr;
  final double maxBubbleWidth;
  final Color bubbleColor;
  final Color textColor;
  final Color metaColor;
  final Color linkColor;
  final double timeSpacerWidth;
  final double minBubbleContentHeight;

  // Measure the width of the metadata text so the message body
  // reserves space for the timestamp row in the bottom-right corner.
  static double measureMetaWidth(
    BuildContext context,
    ConversationMessage message,
    String timeStr, {
    required bool isMe,
  }) {
    final metaText = message.isEdited ? 'edited $timeStr' : timeStr;
    final metaPainter = TextPainter(
      text: TextSpan(
        text: metaText,
        style: appBubbleMetaTextStyle(
          context,
          fontSize: AppFontSizes.bubbleMeta,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);

    if (_showsDeliveryStatus(message, isMe: isMe)) {
      return metaPainter.width + statusIconGap + statusIconSize;
    }

    return metaPainter.width;
  }

  static bool _showsDeliveryStatus(
    ConversationMessage message, {
    required bool isMe,
  }) => isMe && !message.isFailed;

  static double measureSenderHeaderWidth(
    BuildContext context,
    String senderName, {
    required int gender,
  }) {
    final senderPainter = TextPainter(
      text: TextSpan(
        text: senderName,
        style: appBubbleTextStyle(
          context,
          fontWeight: FontWeight.w700,
          fontSize: AppFontSizes.body,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);

    var width = senderPainter.width;
    if (gender == 1 || gender == 2) {
      width += senderHeaderBadgeGap + senderHeaderBadgeSize;
    }
    return width;
  }

  static double measureThreadIndicatorWidth(
    BuildContext context,
    ThreadInfo threadInfo,
  ) {
    final label =
        '${threadInfo.replyCount} '
        'repl${threadInfo.replyCount == 1 ? 'y' : 'ies'}';
    final labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: appBubbleTextStyle(
          context,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);

    return threadIndicatorIconSize +
        threadIndicatorIconGap +
        labelPainter.width;
  }
}
