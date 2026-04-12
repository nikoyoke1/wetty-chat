import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'image_cache_service.dart';

class AppCachedNetworkImage extends ConsumerWidget {
  const AppCachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.memCacheWidth,
    this.placeholder,
    this.errorWidget,
    this.filterQuality,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final int? memCacheWidth;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;
  final FilterQuality? filterQuality;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheManager = ref.watch(imageCacheServiceProvider).cacheManager;
    return CachedNetworkImage(
      cacheManager: cacheManager,
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      placeholder: placeholder,
      errorWidget: errorWidget,
      filterQuality: filterQuality ?? FilterQuality.low,
    );
  }
}
