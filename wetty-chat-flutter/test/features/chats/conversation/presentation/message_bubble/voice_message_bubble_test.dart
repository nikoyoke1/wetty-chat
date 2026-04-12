import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/features/chats/conversation/domain/conversation_message.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_scope.dart';
import 'package:chahua/features/chats/conversation/presentation/message_bubble/message_bubble_presentation.dart';
import 'package:chahua/features/chats/conversation/presentation/message_bubble/voice_message_bubble.dart';
import 'package:chahua/features/chats/models/message_models.dart';

void main() {
  group('resolveVoiceMessageDuration', () {
    test('prefers a positive playback duration over zero metadata', () {
      final duration = resolveVoiceMessageDuration(
        attachmentDuration: Duration.zero,
        playbackDuration: const Duration(seconds: 18),
        resolvedDuration: null,
        waveformDuration: Duration.zero,
      );

      expect(duration, const Duration(seconds: 18));
    });

    test('falls back to waveform duration when metadata is unavailable', () {
      final duration = resolveVoiceMessageDuration(
        attachmentDuration: null,
        playbackDuration: null,
        resolvedDuration: null,
        waveformDuration: const Duration(seconds: 7),
      );

      expect(duration, const Duration(seconds: 7));
    });

    test('uses preloaded duration before playback starts', () {
      final duration = resolveVoiceMessageDuration(
        attachmentDuration: null,
        playbackDuration: null,
        resolvedDuration: const Duration(seconds: 11),
        waveformDuration: null,
      );

      expect(duration, const Duration(seconds: 11));
    });
  });

  group('voiceMessageBubbleWidthFor', () {
    test('uses metadata row width when it is wider than the waveform row', () {
      final width = voiceMessageBubbleWidthFor(
        waveformWidth: voiceMessageWaveformWidthForBarCount(16),
        statusTextWidth: 120,
        metaWidth: 56,
      );

      expect(width, 200);
    });

    testWidgets(
      'waveform width dominates when metadata width stays below the waveform row',
      (tester) async {
        late double incomingWidth;
        late double outgoingWidth;

        await _pumpMeasurementApp(
          tester: tester,
          builder: (context) {
            final incomingMessage = _buildMessage(isMe: false);
            final outgoingMessage = _buildMessage(isMe: true);
            final waveformWidth = voiceMessageWaveformWidthForBarCount(16);

            final incomingPresentation = MessageBubblePresentation.fromContext(
              context: context,
              message: incomingMessage,
              isMe: false,
              chatMessageFontSize: 16,
            );
            final outgoingPresentation = MessageBubblePresentation.fromContext(
              context: context,
              message: outgoingMessage,
              isMe: true,
              chatMessageFontSize: 16,
            );

            incomingWidth = voiceMessageBubbleWidthFor(
              waveformWidth: waveformWidth,
              statusTextWidth: 40,
              metaWidth: incomingPresentation.timeSpacerWidth,
            );
            outgoingWidth = voiceMessageBubbleWidthFor(
              waveformWidth: waveformWidth,
              statusTextWidth: 40,
              metaWidth: outgoingPresentation.timeSpacerWidth,
            );

            return const SizedBox.shrink();
          },
        );

        expect(incomingWidth, closeTo(154, 0.5));
        expect(outgoingWidth, greaterThanOrEqualTo(incomingWidth));
      },
    );
  });
}

Future<void> _pumpMeasurementApp({
  required WidgetTester tester,
  required WidgetBuilder builder,
}) {
  return tester.pumpWidget(
    CupertinoApp(
      home: CupertinoPageScaffold(
        child: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(builder: builder),
        ),
      ),
    ),
  );
}

ConversationMessage _buildMessage({required bool isMe}) {
  return ConversationMessage(
    scope: const ConversationScope.chat(chatId: 'chat-1'),
    serverMessageId: isMe ? 42 : 7,
    localMessageId: null,
    clientGeneratedId: 'client-id',
    sender: Sender(uid: isMe ? 1 : 2, name: isMe ? 'Me' : 'Other'),
    message: null,
    messageType: 'audio',
    sticker: null,
    createdAt: DateTime(2026, 4, 10, 9, 30),
    isEdited: false,
    isDeleted: false,
    replyRootId: null,
    hasAttachments: true,
    replyToMessage: null,
    attachments: const <AttachmentItem>[
      AttachmentItem(
        id: 'audio-1',
        url: 'https://example.com/audio.m4a',
        kind: 'audio/m4a',
        size: 1024,
        fileName: 'audio.m4a',
        durationMs: 4000,
        waveformSamples: <int>[8, 12, 20, 32],
      ),
    ],
    reactions: const <ReactionSummary>[],
    mentions: const <MentionInfo>[],
    threadInfo: null,
  );
}
