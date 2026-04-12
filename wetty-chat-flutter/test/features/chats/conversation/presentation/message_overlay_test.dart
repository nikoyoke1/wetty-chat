import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/features/chats/conversation/domain/conversation_message.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_scope.dart';
import 'package:chahua/features/chats/conversation/presentation/message_bubble/message_bubble.dart';
import 'package:chahua/features/chats/conversation/presentation/message_bubble/message_bubble_presentation.dart';
import 'package:chahua/features/chats/conversation/presentation/message_bubble/message_render_spec.dart';
import 'package:chahua/features/chats/conversation/presentation/message_attachment_previews.dart';
import 'package:chahua/features/chats/conversation/presentation/message_overlay.dart';
import 'package:chahua/features/chats/conversation/presentation/message_overlay_preview.dart';
import 'package:chahua/features/chats/conversation/presentation/message_row.dart';
import 'package:chahua/features/chats/models/message_models.dart';

void main() {
  group('Message bubbles and overlay sender header', () {
    testWidgets('text bubble with sender header does not overflow', (
      tester,
    ) async {
      final message = _buildTextMessage(
        isMe: false,
        senderName: 'Long Sender Name For Overflow Check',
      );

      await _pumpTextBubble(
        tester: tester,
        message: message,
        isMe: false,
        showSenderName: true,
      );

      expect(find.text('Long Sender Name For Overflow Check'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the sender header for my first message bubble preview', (
      tester,
    ) async {
      final message = _buildTextMessage(isMe: true);
      final bubbleSize = await _measureTextBubble(
        tester: tester,
        message: message,
        isMe: true,
        showSenderName: true,
      );

      await _pumpOverlay(
        tester: tester,
        size: const Size(390, 844),
        details: MessageLongPressDetails(
          message: message,
          bubbleRect: Rect.fromLTWH(
            170,
            260,
            bubbleSize.width,
            bubbleSize.height,
          ),
          isMe: true,
          sourceShowsSenderName: true,
        ),
      );

      expect(find.text('Me'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('injects the sender header into compact sent-side previews', (
      tester,
    ) async {
      final message = _buildTextMessage(isMe: true);
      final bubbleSize = await _measureTextBubble(
        tester: tester,
        message: message,
        isMe: true,
        showSenderName: false,
      );

      await _pumpOverlay(
        tester: tester,
        size: const Size(390, 260),
        details: MessageLongPressDetails(
          message: message,
          bubbleRect: Rect.fromLTWH(
            170,
            80,
            bubbleSize.width,
            bubbleSize.height,
          ),
          isMe: true,
          sourceShowsSenderName: false,
        ),
      );

      expect(find.text('Me'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('overlay expands for long sender names in text previews', (
      tester,
    ) async {
      final message = _buildTextMessage(
        isMe: false,
        senderName: 'Very Long Sender Name That Exceeds The Text',
        text: 'Hi',
      );
      final bubbleSize = await _measureTextBubble(
        tester: tester,
        message: message,
        isMe: false,
        showSenderName: false,
        showThreadIndicator: true,
      );

      await _pumpOverlay(
        tester: tester,
        size: const Size(390, 260),
        details: MessageLongPressDetails(
          message: message,
          bubbleRect: Rect.fromLTWH(
            40,
            80,
            bubbleSize.width,
            bubbleSize.height,
          ),
          isMe: false,
          sourceShowsSenderName: false,
        ),
      );

      final previewWidth = tester.getSize(find.byType(MessageBubble)).width;
      expect(previewWidth, greaterThan(bubbleSize.width));
      expect(tester.takeException(), isNull);
    });

    testWidgets('overlay shows thread info in the full bubble path', (
      tester,
    ) async {
      final message = _buildTextMessage(
        isMe: false,
        threadInfo: const ThreadInfo(replyCount: 3),
      );
      final bubbleSize = await _measureTextBubble(
        tester: tester,
        message: message,
        isMe: false,
        showSenderName: false,
        showThreadIndicator: true,
      );

      await _pumpOverlay(
        tester: tester,
        size: const Size(390, 844),
        details: MessageLongPressDetails(
          message: message,
          bubbleRect: Rect.fromLTWH(
            40,
            160,
            bubbleSize.width,
            bubbleSize.height,
          ),
          isMe: false,
          sourceShowsSenderName: false,
        ),
      );

      expect(find.text('3 replies'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'image overlay preserves source image size when sender name widens preview',
      (tester) async {
        final message = _buildImageMessage(
          isMe: false,
          senderName: 'Very Long Sender Name For An Image Message',
        );
        final bubbleSize = await _measureTextBubble(
          tester: tester,
          message: message,
          isMe: false,
          showSenderName: false,
        );
        final sourceImageSize = tester.getSize(
          find.byType(MessageImageAttachmentPreview),
        );

        await _pumpOverlay(
          tester: tester,
          size: const Size(390, 844),
          details: MessageLongPressDetails(
            message: message,
            bubbleRect: Rect.fromLTWH(
              40,
              180,
              bubbleSize.width,
              bubbleSize.height,
            ),
            isMe: false,
            sourceShowsSenderName: false,
          ),
        );

        final previewSize = tester.getSize(find.byType(MessageBubble));
        final overlayImageSize = tester.getSize(
          find.byType(MessageImageAttachmentPreview),
        );
        expect(previewSize.width, greaterThan(bubbleSize.width));
        expect(overlayImageSize, equals(sourceImageSize));
        expect(previewSize.height, greaterThanOrEqualTo(bubbleSize.height));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('image overlay handles wider thread labels without overflow', (
      tester,
    ) async {
      final message = _buildImageMessage(
        isMe: false,
        threadInfo: const ThreadInfo(replyCount: 123),
      );
      final bubbleSize = await _measureTextBubble(
        tester: tester,
        message: message,
        isMe: false,
        showSenderName: false,
        showThreadIndicator: true,
      );
      final sourceImageSize = tester.getSize(
        find.byType(MessageImageAttachmentPreview),
      );

      await _pumpOverlay(
        tester: tester,
        size: const Size(390, 844),
        details: MessageLongPressDetails(
          message: message,
          bubbleRect: Rect.fromLTWH(
            40,
            180,
            bubbleSize.width,
            bubbleSize.height,
          ),
          isMe: false,
          sourceShowsSenderName: false,
        ),
      );

      final overlayImageSize = tester.getSize(
        find.byType(MessageImageAttachmentPreview),
      );
      expect(find.text('123 replies'), findsOneWidget);
      expect(overlayImageSize, equals(sourceImageSize));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'image overlay with caption and injected sender header does not overflow',
      (tester) async {
        final message = _buildImageMessage(
          isMe: true,
          senderName: 'Me With A Longer Name',
          text: 'Short caption',
        );
        final bubbleSize = await _measureTextBubble(
          tester: tester,
          message: message,
          isMe: true,
          showSenderName: false,
        );
        final sourceImageSize = tester.getSize(
          find.byType(MessageImageAttachmentPreview),
        );

        await _pumpOverlay(
          tester: tester,
          size: const Size(390, 844),
          details: MessageLongPressDetails(
            message: message,
            bubbleRect: Rect.fromLTWH(
              180,
              180,
              bubbleSize.width,
              bubbleSize.height,
            ),
            isMe: true,
            sourceShowsSenderName: false,
          ),
        );

        final previewSize = tester.getSize(find.byType(MessageBubble));
        final overlayImageSize = tester.getSize(
          find.byType(MessageImageAttachmentPreview),
        );
        expect(find.text('Me With A Longer Name'), findsOneWidget);
        expect(overlayImageSize, equals(sourceImageSize));
        expect(previewSize.height, greaterThanOrEqualTo(bubbleSize.height));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('multiple image overlays keep full bubble preview path', (
      tester,
    ) async {
      final message = _buildImageMessage(
        isMe: false,
        attachments: const <AttachmentItem>[
          AttachmentItem(
            id: 'image-1',
            url: 'https://example.com/image-1.jpg',
            kind: 'image/jpeg',
            size: 1024,
            fileName: 'image-1.jpg',
            width: 400,
            height: 400,
          ),
          AttachmentItem(
            id: 'image-2',
            url: 'https://example.com/image-2.jpg',
            kind: 'image/jpeg',
            size: 1024,
            fileName: 'image-2.jpg',
            width: 400,
            height: 400,
          ),
        ],
      );
      final bubbleSize = await _measureTextBubble(
        tester: tester,
        message: message,
        isMe: false,
        showSenderName: false,
      );

      await _pumpOverlay(
        tester: tester,
        size: const Size(390, 844),
        details: MessageLongPressDetails(
          message: message,
          bubbleRect: Rect.fromLTWH(
            40,
            180,
            bubbleSize.width,
            bubbleSize.height,
          ),
          isMe: false,
          sourceShowsSenderName: false,
        ),
      );

      expect(find.byType(MessageOverlayPreview), findsNothing);
      expect(find.byType(MessageBubble), findsOneWidget);
      expect(find.byType(MessageImageAttachmentPreview), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'multiple image overlays clip full bubble when height is tight',
      (tester) async {
        final message = _buildImageMessage(
          isMe: false,
          attachments: const <AttachmentItem>[
            AttachmentItem(
              id: 'image-1',
              url: 'https://example.com/image-1.jpg',
              kind: 'image/jpeg',
              size: 1024,
              fileName: 'image-1.jpg',
              width: 400,
              height: 400,
            ),
            AttachmentItem(
              id: 'image-2',
              url: 'https://example.com/image-2.jpg',
              kind: 'image/jpeg',
              size: 1024,
              fileName: 'image-2.jpg',
              width: 400,
              height: 400,
            ),
          ],
        );
        final bubbleSize = await _measureTextBubble(
          tester: tester,
          message: message,
          isMe: false,
          showSenderName: false,
        );

        await _pumpOverlay(
          tester: tester,
          size: const Size(390, 420),
          details: MessageLongPressDetails(
            message: message,
            bubbleRect: Rect.fromLTWH(
              40,
              120,
              bubbleSize.width,
              bubbleSize.height,
            ),
            isMe: false,
            sourceShowsSenderName: false,
          ),
        );

        expect(find.byType(MessageOverlayPreview), findsNothing);
        expect(find.byType(MessageBubble), findsOneWidget);
        expect(find.byType(MessageImageAttachmentPreview), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('tall image overlays use compact preview path', (tester) async {
      final message = _buildImageMessage(
        isMe: false,
        attachments: const <AttachmentItem>[
          AttachmentItem(
            id: 'image-tall',
            url: 'https://example.com/image-tall.jpg',
            kind: 'image/jpeg',
            size: 1024,
            fileName: 'image-tall.jpg',
            width: 400,
            height: 2000,
          ),
        ],
      );
      final bubbleSize = await _measureTextBubble(
        tester: tester,
        message: message,
        isMe: false,
        showSenderName: false,
      );

      await _pumpOverlay(
        tester: tester,
        size: const Size(390, 844),
        details: MessageLongPressDetails(
          message: message,
          bubbleRect: Rect.fromLTWH(
            40,
            180,
            bubbleSize.width,
            bubbleSize.height,
          ),
          isMe: false,
          sourceShowsSenderName: false,
        ),
      );

      expect(find.byType(MessageOverlayPreview), findsOneWidget);
      expect(find.byType(MessageImageAttachmentPreview), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('image overlay keeps my confirm badge in full preview', (
      tester,
    ) async {
      final message = _buildImageMessage(isMe: true, text: 'Caption');
      final bubbleSize = await _measureTextBubble(
        tester: tester,
        message: message,
        isMe: true,
        showSenderName: false,
      );

      await _pumpOverlay(
        tester: tester,
        size: const Size(390, 844),
        details: MessageLongPressDetails(
          message: message,
          bubbleRect: Rect.fromLTWH(
            180,
            180,
            bubbleSize.width,
            bubbleSize.height,
          ),
          isMe: true,
          sourceShowsSenderName: false,
        ),
      );

      expect(
        find.byIcon(CupertinoIcons.checkmark_alt_circle_fill),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'overlay preview shows thread info in the compact preview path',
      (tester) async {
        final message = _buildTextMessage(
          isMe: false,
          text: 'Hi',
          threadInfo: const ThreadInfo(replyCount: 12),
        );
        await tester.pumpWidget(
          CupertinoApp(
            home: CupertinoPageScaffold(
              child: MediaQuery(
                data: const MediaQueryData(size: Size(390, 260)),
                child: Builder(
                  builder: (context) {
                    final presentation = MessageBubblePresentation.fromContext(
                      context: context,
                      message: message,
                      isMe: false,
                      chatMessageFontSize: 16,
                      maxBubbleWidth: 240,
                    );

                    return Center(
                      child: SizedBox(
                        width: 240,
                        child: MessageOverlayPreview(
                          message: message,
                          presentation: presentation,
                          chatMessageFontSize: 16,
                          isMe: false,
                          renderSpec: MessageRenderSpec.overlay(
                            message: message,
                            sourceShowsSenderName: false,
                            compact: true,
                          ),
                          maxHeight: 120,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('12 replies'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

Future<void> _pumpOverlay({
  required WidgetTester tester,
  required Size size,
  required MessageLongPressDetails details,
}) async {
  await tester.pumpWidget(
    CupertinoApp(
      home: CupertinoPageScaffold(
        child: MediaQuery(
          data: MediaQueryData(size: size),
          child: SizedBox.expand(
            child: MessageOverlay(
              details: details,
              visible: true,
              chatMessageFontSize: 16,
              actions: [MessageOverlayAction(label: 'Reply', onPressed: () {})],
              quickReactionEmojis: const <String>['👍'],
              onDismiss: () {},
              onToggleReaction: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

Future<Size> _measureTextBubble({
  required WidgetTester tester,
  required ConversationMessage message,
  required bool isMe,
  required bool showSenderName,
  bool showThreadIndicator = false,
}) async {
  await _pumpTextBubble(
    tester: tester,
    message: message,
    isMe: isMe,
    showSenderName: showSenderName,
    showThreadIndicator: showThreadIndicator,
  );

  return tester.getSize(find.byType(MessageBubble));
}

Future<void> _pumpTextBubble({
  required WidgetTester tester,
  required ConversationMessage message,
  required bool isMe,
  required bool showSenderName,
  bool showThreadIndicator = false,
}) async {
  await tester.pumpWidget(
    CupertinoApp(
      home: CupertinoPageScaffold(
        child: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(
            builder: (context) {
              final presentation = MessageBubblePresentation.fromContext(
                context: context,
                message: message,
                isMe: isMe,
                chatMessageFontSize: 16,
              );

              return Center(
                child: MessageBubble(
                  message: message,
                  presentation: presentation,
                  chatMessageFontSize: 16,
                  isMe: isMe,
                  renderSpec: MessageRenderSpec.timeline(
                    message: message,
                    showSenderName: showSenderName,
                    showThreadIndicator: showThreadIndicator,
                    isInteractive: true,
                  ),
                  currentUserId: 1,
                  onOpenThread: showThreadIndicator ? () {} : null,
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

ConversationMessage _buildTextMessage({
  required bool isMe,
  String? senderName,
  String text = 'Overlay sender header test message',
  ThreadInfo? threadInfo,
}) {
  return ConversationMessage(
    scope: const ConversationScope.chat(chatId: 'chat-1'),
    serverMessageId: isMe ? 42 : 7,
    clientGeneratedId: 'client-id',
    sender: Sender(
      uid: isMe ? 1 : 2,
      name: senderName ?? (isMe ? 'Me' : 'Other'),
    ),
    message: text,
    messageType: 'text',
    createdAt: DateTime(2026, 4, 10, 9, 30),
    threadInfo: threadInfo,
  );
}

ConversationMessage _buildImageMessage({
  required bool isMe,
  String? senderName,
  String? text,
  ThreadInfo? threadInfo,
  List<AttachmentItem>? attachments,
}) {
  return ConversationMessage(
    scope: const ConversationScope.chat(chatId: 'chat-1'),
    serverMessageId: isMe ? 99 : 77,
    clientGeneratedId: 'image-client-id',
    sender: Sender(
      uid: isMe ? 1 : 2,
      name: senderName ?? (isMe ? 'Me' : 'Other'),
    ),
    message: text,
    messageType: 'text',
    createdAt: DateTime(2026, 4, 10, 9, 30),
    hasAttachments: true,
    attachments:
        attachments ??
        const <AttachmentItem>[
          AttachmentItem(
            id: 'image-1',
            url: 'https://example.com/image.jpg',
            kind: 'image/jpeg',
            size: 1024,
            fileName: 'image.jpg',
            width: 400,
            height: 800,
          ),
        ],
    threadInfo: threadInfo,
  );
}
