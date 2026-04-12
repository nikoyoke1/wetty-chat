import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chahua/core/cache/media_cache_service.dart';
import 'package:chahua/core/providers/shared_preferences_provider.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_message.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_scope.dart';
import 'package:chahua/features/chats/conversation/data/audio_playback_driver.dart';
import 'package:chahua/features/chats/conversation/data/audio_source_resolver_service.dart';
import 'package:chahua/features/chats/conversation/presentation/message_overlay.dart';
import 'package:chahua/features/chats/conversation/presentation/message_bubble/message_bubble_presentation.dart';
import 'package:chahua/features/chats/conversation/presentation/message_bubble/message_render_spec.dart';
import 'package:chahua/features/chats/conversation/presentation/message_bubble/voice_message_bubble.dart';
import 'package:chahua/features/chats/conversation/presentation/message_row.dart';
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

    testWidgets('renders the sender header when enabled', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final message = _buildMessage(isMe: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            audioPlaybackDriverProvider.overrideWithValue(
              _FakeAudioPlaybackDriver(),
            ),
            audioSourceResolverServiceProvider.overrideWithValue(
              _FakeAudioSourceResolverService(
                MediaCacheService(cacheNamespace: 'voice-message-bubble-test'),
              ),
            ),
          ],
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: MediaQuery(
                data: const MediaQueryData(size: Size(390, 844)),
                child: Builder(
                  builder: (context) {
                    final presentation = MessageBubblePresentation.fromContext(
                      context: context,
                      message: message,
                      isMe: false,
                      chatMessageFontSize: 16,
                    );

                    return Center(
                      child: VoiceMessageBubble(
                        attachment: message.attachments.first,
                        isMe: false,
                        renderSpec: MessageRenderSpec.timeline(
                          message: message,
                          showSenderName: true,
                          showThreadIndicator: false,
                          isInteractive: true,
                        ),
                        message: message,
                        presentation: presentation,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Other'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('audio overlay expands for long sender names', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final message = _buildMessage(
        isMe: false,
        senderName: 'Very Long Sender Name For Audio Overlay',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            audioPlaybackDriverProvider.overrideWithValue(
              _FakeAudioPlaybackDriver(),
            ),
            audioSourceResolverServiceProvider.overrideWithValue(
              _FakeAudioSourceResolverService(
                MediaCacheService(cacheNamespace: 'voice-message-bubble-test'),
              ),
            ),
          ],
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: MediaQuery(
                data: const MediaQueryData(size: Size(390, 844)),
                child: Builder(
                  builder: (context) {
                    final presentation = MessageBubblePresentation.fromContext(
                      context: context,
                      message: message,
                      isMe: false,
                      chatMessageFontSize: 16,
                    );

                    return Center(
                      child: VoiceMessageBubble(
                        attachment: message.attachments.first,
                        isMe: false,
                        renderSpec: MessageRenderSpec.timeline(
                          message: message,
                          showSenderName: false,
                          showThreadIndicator: false,
                          isInteractive: true,
                        ),
                        message: message,
                        presentation: presentation,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final originalSize = tester.getSize(find.byType(VoiceMessageBubble));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            audioPlaybackDriverProvider.overrideWithValue(
              _FakeAudioPlaybackDriver(),
            ),
            audioSourceResolverServiceProvider.overrideWithValue(
              _FakeAudioSourceResolverService(
                MediaCacheService(cacheNamespace: 'voice-message-bubble-test'),
              ),
            ),
          ],
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: MediaQuery(
                data: const MediaQueryData(size: Size(390, 844)),
                child: SizedBox.expand(
                  child: MessageOverlay(
                    details: MessageLongPressDetails(
                      message: message,
                      bubbleRect: Rect.fromLTWH(
                        40,
                        120,
                        originalSize.width,
                        originalSize.height,
                      ),
                      isMe: false,
                      sourceShowsSenderName: false,
                    ),
                    visible: true,
                    chatMessageFontSize: 16,
                    actions: [
                      MessageOverlayAction(label: 'Reply', onPressed: () {}),
                    ],
                    quickReactionEmojis: const <String>['👍'],
                    onDismiss: () {},
                    onToggleReaction: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final overlayWidth = tester
          .getSize(find.byType(VoiceMessageBubble))
          .width;
      expect(overlayWidth, greaterThanOrEqualTo(originalSize.width));
      expect(tester.takeException(), isNull);
    });

    testWidgets('audio overlay shows thread info', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final message = _buildMessage(
        isMe: false,
        threadInfo: const ThreadInfo(replyCount: 4),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            audioPlaybackDriverProvider.overrideWithValue(
              _FakeAudioPlaybackDriver(),
            ),
            audioSourceResolverServiceProvider.overrideWithValue(
              _FakeAudioSourceResolverService(
                MediaCacheService(cacheNamespace: 'voice-message-bubble-test'),
              ),
            ),
          ],
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: MediaQuery(
                data: const MediaQueryData(size: Size(390, 844)),
                child: Builder(
                  builder: (context) {
                    final presentation = MessageBubblePresentation.fromContext(
                      context: context,
                      message: message,
                      isMe: false,
                      chatMessageFontSize: 16,
                    );

                    return Center(
                      child: VoiceMessageBubble(
                        attachment: message.attachments.first,
                        isMe: false,
                        renderSpec: MessageRenderSpec.timeline(
                          message: message,
                          showSenderName: false,
                          showThreadIndicator: true,
                          isInteractive: true,
                        ),
                        message: message,
                        presentation: presentation,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('4 replies'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
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

ConversationMessage _buildMessage({
  required bool isMe,
  String? senderName,
  ThreadInfo? threadInfo,
}) {
  return ConversationMessage(
    scope: const ConversationScope.chat(chatId: 'chat-1'),
    serverMessageId: isMe ? 42 : 7,
    localMessageId: null,
    clientGeneratedId: 'client-id',
    sender: Sender(
      uid: isMe ? 1 : 2,
      name: senderName ?? (isMe ? 'Me' : 'Other'),
    ),
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
    threadInfo: threadInfo,
  );
}

class _FakeAudioPlaybackDriver implements AudioPlaybackDriver {
  final StreamController<AudioPlaybackStatus> _statusController =
      StreamController<AudioPlaybackStatus>.broadcast();

  @override
  Stream<AudioPlaybackStatus> get statusStream => _statusController.stream;

  @override
  AudioPlaybackStatus get currentStatus => const AudioPlaybackStatus(
    phase: AudioPlaybackDriverPhase.idle,
    isPlaying: false,
    position: Duration.zero,
    bufferedPosition: Duration.zero,
  );

  @override
  Future<void> dispose() => _statusController.close();

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<Duration?> setSourceFilePath(String path) async => Duration.zero;

  @override
  Future<Duration?> setSourceUrl(String url) async => Duration.zero;

  @override
  Future<void> stop() async {}
}

class _FakeAudioSourceResolverService extends AudioSourceResolverService {
  _FakeAudioSourceResolverService(super.mediaCacheService);

  @override
  Future<AudioPlaybackSource?> resolvePlaybackSource(
    AttachmentItem attachment,
  ) async {
    return AudioPlaybackSource.file(
      filePath: '/tmp/${attachment.id}.m4a',
      localWaveformPath: '/tmp/${attachment.id}.m4a',
    );
  }
}
