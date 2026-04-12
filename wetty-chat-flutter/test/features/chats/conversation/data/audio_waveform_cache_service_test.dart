import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/core/cache/media_cache_service.dart';
import 'package:chahua/features/chats/conversation/data/audio_source_resolver_service.dart';
import 'package:chahua/features/chats/conversation/data/audio_waveform_cache_service.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import '../../../../test_utils/path_provider_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setUpPathProviderMock);
  tearDownAll(tearDownPathProviderMock);

  test(
    'primeFromAttachmentMetadata stores waveform under the uploaded id',
    () async {
      const cacheNamespace = 'audio-waveform-cache-test';
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
      final service = AudioWaveformCacheService(
        mediaCacheService,
        AudioSourceResolverService(mediaCacheService),
      );

      await service.primeFromAttachmentMetadata(
        attachmentId: 'uploaded-audio',
        duration: const Duration(seconds: 6),
        samples: const <int>[3, 9, 18, 27],
      );

      final snapshot = await service.resolveForAttachment(
        const AttachmentItem(
          id: 'uploaded-audio',
          url: '',
          kind: 'audio/ogg',
          size: 2048,
          fileName: 'voice.ogg',
        ),
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.duration, const Duration(seconds: 6));
      expect(
        snapshot.samples,
        hasLength(AudioWaveformCacheService.targetBarCount),
      );
    },
  );
}
