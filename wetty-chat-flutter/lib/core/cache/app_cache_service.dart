import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'image_cache_service.dart';
import 'media_cache_service.dart';

class AppCacheUsageSummary {
  const AppCacheUsageSummary({
    required this.totalBytes,
    required this.mediaBytes,
    required this.imageBytes,
  });

  final int totalBytes;
  final int mediaBytes;
  final int imageBytes;
}

class AppCacheService {
  const AppCacheService(this._mediaCacheService, this._imageCacheService);

  final MediaCacheService _mediaCacheService;
  final ImageCacheService _imageCacheService;

  Future<AppCacheUsageSummary> estimateUsage() async {
    final mediaUsage = await _mediaCacheService.estimateUsage();
    final imageBytes = await _imageCacheService.estimateUsageBytes();
    return AppCacheUsageSummary(
      mediaBytes: mediaUsage.totalBytes,
      imageBytes: imageBytes,
      totalBytes: mediaUsage.totalBytes + imageBytes,
    );
  }

  Future<void> clearAll() async {
    await _mediaCacheService.clearAll();
    await _imageCacheService.clearAll();
  }
}

final appCacheServiceProvider = Provider<AppCacheService>((ref) {
  return AppCacheService(
    ref.watch(mediaCacheServiceProvider),
    ref.watch(imageCacheServiceProvider),
  );
});
