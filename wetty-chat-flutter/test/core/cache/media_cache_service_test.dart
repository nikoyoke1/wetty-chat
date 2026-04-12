import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/core/cache/media_cache_service.dart';
import '../../test_utils/path_provider_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setUpPathProviderMock);
  tearDownAll(tearDownPathProviderMock);

  test('puts and restores waveform sidecars and reports usage', () async {
    const cacheNamespace = 'media-cache-sidecar-test';
    final service = MediaCacheService(
      cacheNamespace: cacheNamespace,
      cacheManager: CacheManager(
        Config(
          cacheNamespace,
          stalePeriod: const Duration(days: 1),
          maxNrOfCacheObjects: 20,
        ),
      ),
    );
    addTearDown(service.dispose);
    addTearDown(service.clearAll);

    const sidecarKey = 'audio-sidecar:waveform:test-audio';
    await service.putJsonSidecar(
      key: sidecarKey,
      json: <String, dynamic>{
        'durationMs': 1000,
        'samples': <int>[1, 2, 3],
      },
    );

    final restored = await service.getJsonSidecar(sidecarKey);
    final usage = await service.estimateUsage();

    expect(restored, isNotNull);
    expect(restored!['durationMs'], 1000);
    expect(usage.totalBytes, greaterThan(0));
  });

  test('clearAll removes cached artifacts and resets usage', () async {
    const cacheNamespace = 'media-cache-clear-test';
    final service = MediaCacheService(
      cacheNamespace: cacheNamespace,
      cacheManager: CacheManager(
        Config(
          cacheNamespace,
          stalePeriod: const Duration(days: 1),
          maxNrOfCacheObjects: 20,
        ),
      ),
    );
    addTearDown(service.dispose);
    addTearDown(service.clearAll);

    await service.putJsonSidecar(
      key: 'audio-sidecar:waveform:test-clear',
      json: <String, dynamic>{
        'durationMs': 2500,
        'samples': <int>[5, 6, 7],
      },
    );

    final before = await service.estimateUsage();
    expect(before.totalBytes, greaterThan(0));

    await service.clearAll();

    final after = await service.estimateUsage();
    expect(after.totalBytes, 0);
  });
}
