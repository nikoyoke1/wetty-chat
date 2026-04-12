import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/core/cache/media_cache_service.dart';
import 'package:chahua/features/chats/conversation/application/voice_message_presentation_provider.dart';
import 'package:chahua/features/chats/conversation/data/audio_duration_probe_service.dart';
import 'package:chahua/features/chats/conversation/data/audio_source_resolver_service.dart';
import 'package:chahua/features/chats/conversation/data/audio_waveform_cache_service.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import '../../../../test_utils/path_provider_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setUpPathProviderMock);
  tearDownAll(tearDownPathProviderMock);

  test('preloads duration and waveform data before playback starts', () async {
    const cacheNamespace = 'voice-message-presentation-test';
    final mediaCacheService = MediaCacheService(
      cacheNamespace: cacheNamespace,
      cacheManager: CacheManager(
        Config(
          cacheNamespace,
          stalePeriod: const Duration(days: 1),
          maxNrOfCacheObjects: 20,
        ),
      ),
    );
    addTearDown(mediaCacheService.dispose);
    addTearDown(mediaCacheService.clearAll);

    final waveformService = FakeAudioWaveformCacheService(mediaCacheService);
    final container = ProviderContainer(
      overrides: [
        audioSourceResolverServiceProvider.overrideWithValue(
          FakeAudioSourceResolverService(mediaCacheService),
        ),
        audioDurationProbeServiceProvider.overrideWithValue(
          FakeAudioDurationProbeService(mediaCacheService),
        ),
        audioWaveformCacheServiceProvider.overrideWithValue(waveformService),
      ],
    );
    addTearDown(container.dispose);

    final attachment = AttachmentItem(
      id: 'audio-1',
      url: 'https://example.com/audio-1.m4a',
      kind: 'audio/m4a',
      size: 1024,
      fileName: 'audio-1.m4a',
    );

    final presentation = await container.read(
      voiceMessagePresentationProvider(attachment).future,
    );

    expect(presentation.canPlay, isTrue);
    expect(presentation.duration, const Duration(seconds: 9));
    expect(presentation.waveform, isNotNull);
    expect(presentation.waveform!.duration, const Duration(seconds: 9));
    expect(waveformService.lastPreferredDuration, const Duration(seconds: 9));
    expect(waveformService.lastWaveformInputPath, '/tmp/audio-1-waveform.m4a');
  });
}

class FakeAudioSourceResolverService extends AudioSourceResolverService {
  FakeAudioSourceResolverService(super.mediaCacheService);

  @override
  Future<AudioPlaybackSource?> resolvePlaybackSource(
    AttachmentItem attachment,
  ) async {
    return AudioPlaybackSource.file(
      filePath: '/tmp/${attachment.id}.m4a',
      localWaveformPath: '/tmp/${attachment.id}-waveform.m4a',
    );
  }
}

class FakeAudioDurationProbeService extends AudioDurationProbeService {
  FakeAudioDurationProbeService(super.mediaCacheService);

  @override
  Future<Duration?> resolveForAttachment(
    AttachmentItem attachment, {
    AudioPlaybackSource? source,
  }) async {
    return const Duration(seconds: 9);
  }
}

class FakeAudioWaveformCacheService extends AudioWaveformCacheService {
  FakeAudioWaveformCacheService(MediaCacheService mediaCacheService)
    : super(mediaCacheService, AudioSourceResolverService(mediaCacheService));

  Duration? lastPreferredDuration;
  String? lastWaveformInputPath;

  @override
  Future<AudioWaveformSnapshot?> resolveForAttachment(
    AttachmentItem attachment, {
    Duration? preferredDuration,
    String? waveformInputPath,
  }) async {
    lastPreferredDuration = preferredDuration;
    lastWaveformInputPath = waveformInputPath;
    return AudioWaveformSnapshot(
      duration: preferredDuration,
      samples: List<int>.filled(AudioWaveformCacheService.targetBarCount, 80),
    );
  }
}
