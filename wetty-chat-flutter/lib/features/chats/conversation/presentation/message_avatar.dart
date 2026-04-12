import 'package:flutter/cupertino.dart';

import '../../../../core/cache/app_cached_network_image.dart';

class MessageAvatar extends StatelessWidget {
  const MessageAvatar({
    super.key,
    required this.avatarUrl,
    required this.fallbackBuilder,
  });

  static const double avatarSize = 36;

  final String avatarUrl;
  final Widget Function() fallbackBuilder;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: AppCachedNetworkImage(
        imageUrl: avatarUrl,
        width: avatarSize,
        height: avatarSize,
        memCacheWidth: 96,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => fallbackBuilder(),
      ),
    );
  }
}
