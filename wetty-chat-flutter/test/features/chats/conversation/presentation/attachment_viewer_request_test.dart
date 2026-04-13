import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/features/chats/conversation/domain/conversation_message.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_scope.dart';
import 'package:chahua/features/chats/conversation/presentation/attachment_viewer_request.dart';
import 'package:chahua/features/chats/models/message_models.dart';

void main() {
  test('buildImageAttachmentViewerRequest keeps only message images', () {
    const imageOne = AttachmentItem(
      id: 'image-1',
      url: 'https://example.com/image-1.png',
      kind: 'image/png',
      size: 100,
      fileName: 'image-1.png',
    );
    const document = AttachmentItem(
      id: 'doc-1',
      url: 'https://example.com/file.pdf',
      kind: 'application/pdf',
      size: 200,
      fileName: 'file.pdf',
    );
    const imageTwo = AttachmentItem(
      id: 'image-2',
      url: 'https://example.com/image-2.png',
      kind: 'image/png',
      size: 100,
      fileName: 'image-2.png',
    );
    const message = ConversationMessage(
      scope: ConversationScope.chat(chatId: 'chat-1'),
      clientGeneratedId: 'client-1',
      sender: Sender(uid: 7, name: 'Alex'),
      attachments: <AttachmentItem>[imageOne, document, imageTwo],
    );

    final request = buildImageAttachmentViewerRequest(
      message: message,
      tappedAttachment: imageTwo,
    );

    expect(request, isNotNull);
    expect(request!.items.map((item) => item.attachment.id), <String>[
      'image-1',
      'image-2',
    ]);
    expect(request.initialIndex, 1);
    expect(
      request.items[1].heroTag,
      attachmentViewerHeroTag(
        messageStableKey: message.stableKey,
        attachment: imageTwo,
      ),
    );
  });

  test('buildImageAttachmentViewerRequest falls back to url matching', () {
    const tapped = AttachmentItem(
      id: '',
      url: 'https://example.com/untagged.png',
      kind: 'image/png',
      size: 100,
      fileName: 'untagged.png',
    );
    const message = ConversationMessage(
      scope: ConversationScope.chat(chatId: 'chat-1'),
      clientGeneratedId: 'client-1',
      sender: Sender(uid: 9, name: 'Sam'),
      attachments: <AttachmentItem>[tapped],
    );

    final request = buildImageAttachmentViewerRequest(
      message: message,
      tappedAttachment: tapped,
    );

    expect(request, isNotNull);
    expect(request!.initialIndex, 0);
    expect(request.items.single.isImage, isTrue);
  });
}
