import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/cache/app_cached_network_image.dart';
import '../../models/message_models.dart';

class AttachmentViewerPage extends StatelessWidget {
  const AttachmentViewerPage({super.key, required this.attachment});

  final AttachmentItem attachment;

  Future<void> _openExternally() async {
    if (attachment.url.isEmpty) {
      return;
    }
    await launchUrl(
      Uri.parse(attachment.url),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = attachment.fileName.isEmpty
        ? 'Attachment'
        : attachment.fileName;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _openExternally,
          child: const Icon(CupertinoIcons.arrow_up_right_square),
        ),
      ),
      backgroundColor: CupertinoColors.black,
      child: SafeArea(
        child: Center(
          child: attachment.isImage
              ? _ZoomableImageViewport(
                  imageWidth: attachment.width?.toDouble(),
                  imageHeight: attachment.height?.toDouble(),
                  child: AppCachedNetworkImage(
                    imageUrl: attachment.url,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    placeholder: (context, url) =>
                        const CupertinoActivityIndicator(),
                    errorWidget: (context, url, error) => _ErrorState(
                      title: 'Failed to load image',
                      onOpenExternally: _openExternally,
                    ),
                  ),
                )
              : _ErrorState(
                  title: 'Preview is not available',
                  onOpenExternally: _openExternally,
                ),
        ),
      ),
    );
  }
}

class _ZoomableImageViewport extends StatelessWidget {
  const _ZoomableImageViewport({
    required this.child,
    this.imageWidth,
    this.imageHeight,
  });

  final Widget child;
  final double? imageWidth;
  final double? imageHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final viewportHeight = constraints.maxHeight;
        final contentWidth = imageWidth ?? viewportWidth;
        final contentHeight = imageHeight ?? viewportHeight;

        return InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          boundaryMargin: const EdgeInsets.all(80),
          child: SizedBox(
            width: viewportWidth,
            height: viewportHeight,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: contentWidth,
                height: contentHeight,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.title, required this.onOpenExternally});

  final String title;
  final Future<void> Function() onOpenExternally;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            size: 36,
            color: CupertinoColors.white,
          ),
          const SizedBox(height: 12),
          const Text(
            'Unable to preview this attachment',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CupertinoColors.systemGrey2.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 16),
          CupertinoButton.filled(
            onPressed: onOpenExternally,
            child: const Text('Open externally'),
          ),
        ],
      ),
    );
  }
}
