import '../domain/conversation_message.dart';
import '../../models/message_models.dart';

enum AttachmentViewerMediaKind { image, video }

class AttachmentViewerItem {
  const AttachmentViewerItem({
    required this.attachment,
    required this.heroTag,
    required this.mediaKind,
  });

  final AttachmentItem attachment;
  final String heroTag;
  final AttachmentViewerMediaKind mediaKind;

  bool get isImage => mediaKind == AttachmentViewerMediaKind.image;
}

class AttachmentViewerRequest {
  const AttachmentViewerRequest({
    required this.items,
    required this.initialIndex,
  }) : assert(items.length > 0),
       assert(initialIndex >= 0),
       assert(initialIndex < items.length);

  final List<AttachmentViewerItem> items;
  final int initialIndex;
}

class MessageAttachmentOpenRequest {
  const MessageAttachmentOpenRequest({
    required this.attachment,
    this.viewerRequest,
  });

  final AttachmentItem attachment;
  final AttachmentViewerRequest? viewerRequest;
}

String attachmentViewerHeroTag({
  required String messageStableKey,
  required AttachmentItem attachment,
}) {
  final attachmentKey = attachment.id.isNotEmpty
      ? attachment.id
      : attachment.url;
  return 'attachment-viewer:$messageStableKey:$attachmentKey';
}

AttachmentViewerRequest? buildImageAttachmentViewerRequest({
  required ConversationMessage message,
  required AttachmentItem tappedAttachment,
}) {
  final imageAttachments = message.attachments
      .where((attachment) => attachment.isImage && attachment.url.isNotEmpty)
      .toList(growable: false);
  if (imageAttachments.isEmpty) {
    return null;
  }

  final initialIndex = imageAttachments.indexWhere(
    (attachment) =>
        (attachment.id.isNotEmpty && attachment.id == tappedAttachment.id) ||
        attachment.url == tappedAttachment.url,
  );
  if (initialIndex < 0) {
    return null;
  }

  return AttachmentViewerRequest(
    items: imageAttachments
        .map(
          (attachment) => AttachmentViewerItem(
            attachment: attachment,
            heroTag: attachmentViewerHeroTag(
              messageStableKey: message.stableKey,
              attachment: attachment,
            ),
            mediaKind: AttachmentViewerMediaKind.image,
          ),
        )
        .toList(growable: false),
    initialIndex: initialIndex,
  );
}
