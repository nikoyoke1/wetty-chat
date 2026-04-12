import '../../domain/conversation_message.dart';

enum MessageRenderSurface { timeline, overlayFull, overlayCompact }

class MessageRenderSpec {
  const MessageRenderSpec({
    required this.surface,
    required this.showSenderName,
    required this.sourceShowsSenderName,
    required this.showReplyQuote,
    required this.showAttachments,
    required this.showAttachmentSummary,
    required this.showBody,
    required this.showMeta,
    required this.showThreadIndicator,
    required this.showReactions,
    required this.isInteractive,
  });

  factory MessageRenderSpec.timeline({
    required ConversationMessage message,
    required bool showSenderName,
    required bool showThreadIndicator,
    required bool isInteractive,
  }) {
    return MessageRenderSpec(
      surface: MessageRenderSurface.timeline,
      showSenderName: showSenderName,
      sourceShowsSenderName: showSenderName,
      showReplyQuote: message.replyToMessage != null,
      showAttachments: message.attachments.isNotEmpty,
      showAttachmentSummary: false,
      showBody: !_isMessageBodyEmpty(message),
      showMeta: !message.isDeleted,
      showThreadIndicator:
          message.threadInfo != null &&
          message.threadInfo!.replyCount > 0 &&
          showThreadIndicator,
      showReactions: message.reactions.isNotEmpty,
      isInteractive: isInteractive,
    );
  }

  factory MessageRenderSpec.overlay({
    required ConversationMessage message,
    required bool sourceShowsSenderName,
    required bool compact,
  }) {
    final hasThreadInfo =
        message.threadInfo != null && message.threadInfo!.replyCount > 0;
    final hasAttachments = message.attachments.isNotEmpty;
    final hasBody = !_isMessageBodyEmpty(message);
    return MessageRenderSpec(
      surface: compact
          ? MessageRenderSurface.overlayCompact
          : MessageRenderSurface.overlayFull,
      showSenderName: true,
      sourceShowsSenderName: sourceShowsSenderName,
      showReplyQuote: message.replyToMessage != null,
      showAttachments: !compact && hasAttachments,
      showAttachmentSummary: compact && hasAttachments && !hasBody,
      showBody: hasBody || (compact && !hasAttachments),
      showMeta: !compact && !message.isDeleted,
      showThreadIndicator: hasThreadInfo,
      showReactions: !compact && message.reactions.isNotEmpty,
      isInteractive: false,
    );
  }

  final MessageRenderSurface surface;
  final bool showSenderName;
  final bool sourceShowsSenderName;
  final bool showReplyQuote;
  final bool showAttachments;
  final bool showAttachmentSummary;
  final bool showBody;
  final bool showMeta;
  final bool showThreadIndicator;
  final bool showReactions;
  final bool isInteractive;

  bool get injectsSenderHeader => showSenderName && !sourceShowsSenderName;

  static bool _isMessageBodyEmpty(ConversationMessage message) =>
      message.message?.trim().isEmpty ?? true;
}
