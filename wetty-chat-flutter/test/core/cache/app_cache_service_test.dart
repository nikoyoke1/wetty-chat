import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/core/cache/app_cache_service.dart';
import 'package:chahua/core/cache/image_cache_service.dart';
import 'package:chahua/core/cache/media_cache_service.dart';
import '../../test_utils/path_provider_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setUpPathProviderMock);
  tearDownAll(tearDownPathProviderMock);

  test('aggregates media and image cache usage and clears both', () async {
    const mediaNamespace = 'app-cache-media-test';
    const imageNamespace = 'app-cache-image-test';
    final mediaService = MediaCacheService(
      cacheNamespace: mediaNamespace,
      cacheManager: CacheManager(
        Config(
          mediaNamespace,
          stalePeriod: const Duration(days: 1),
          maxNrOfCacheObjects: 20,
        ),
      ),
    );
    final imageManager = CacheManager(
      Config(
        imageNamespace,
        stalePeriod: const Duration(days: 1),
        maxNrOfCacheObjects: 20,
      ),
    );
    final imageService = ImageCacheService(
      cacheNamespace: imageNamespace,
      cacheManager: imageManager,
    );
    final appCacheService = AppCacheService(mediaService, imageService);
    addTearDown(mediaService.dispose);
    addTearDown(imageService.dispose);
    addTearDown(appCacheService.clearAll);

    await mediaService.putJsonSidecar(
      key: 'audio-sidecar:waveform:test-audio',
      json: <String, dynamic>{
        'durationMs': 1200,
        'samples': <int>[1, 2, 3],
      },
    );
    await imageManager.putFile(
      'https://example.com/test.png',
      Uint8List.fromList(List<int>.filled(64, 7)),
      fileExtension: 'png',
    );

    final usage = await appCacheService.estimateUsage();

    expect(usage.mediaBytes, greaterThan(0));
    expect(usage.imageBytes, greaterThan(0));
    expect(usage.totalBytes, usage.mediaBytes + usage.imageBytes);

    await appCacheService.clearAll();

    final clearedUsage = await appCacheService.estimateUsage();
    expect(clearedUsage.totalBytes, 0);
    expect(clearedUsage.mediaBytes, 0);
    expect(clearedUsage.imageBytes, 0);
  });
}
