import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/core/cache/image_cache_service.dart';
import '../../test_utils/path_provider_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setUpPathProviderMock);
  tearDownAll(tearDownPathProviderMock);

  test('providerForUrl reuses the configured cache manager', () async {
    const cacheNamespace = 'image-cache-provider-test';
    final cacheManager = CacheManager(
      Config(
        cacheNamespace,
        stalePeriod: const Duration(days: 1),
        maxNrOfCacheObjects: 20,
      ),
    );
    final service = ImageCacheService(
      cacheNamespace: cacheNamespace,
      cacheManager: cacheManager,
    );
    addTearDown(service.dispose);
    addTearDown(service.clearAll);

    final provider = service.providerForUrl('https://example.com/test.png');

    expect(provider, isA<CachedNetworkImageProvider>());
    expect(
      (provider as CachedNetworkImageProvider).cacheManager,
      same(cacheManager),
    );
  });
}
