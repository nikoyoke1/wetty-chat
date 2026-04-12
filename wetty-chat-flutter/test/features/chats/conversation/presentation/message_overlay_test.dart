import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/features/chats/conversation/domain/conversation_message.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_scope.dart';
import 'package:chahua/features/chats/conversation/presentation/message_bubble/message_bubble.dart';
import 'package:chahua/features/chats/conversation/presentation/message_bubble/message_bubble_presentation.dart';
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
                          showSenderName: true,
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
  await tester.pumpAndSettle();
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
                  showSenderName: showSenderName,
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
  await tester.pumpAndSettle();
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
