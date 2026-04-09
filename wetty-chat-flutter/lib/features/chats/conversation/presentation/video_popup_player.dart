import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;

import '../../../../app/theme/style_config.dart';
import '../../models/message_models.dart';

Future<void> showVideoPlayerPopup(
  BuildContext context,
  AttachmentItem attachment,
) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Video player',
    barrierColor: CupertinoColors.black.withAlpha(190),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, animation, secondaryAnimation) =>
        _VideoPopupPlayerDialog(attachment: attachment),
    transitionBuilder: (_, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.98,
            end: 1,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      );
    },
  );
}

class VideoAttachmentPreview extends StatelessWidget {
  const VideoAttachmentPreview({
    super.key,
    required this.attachment,
    required this.onTap,
  });

  final AttachmentItem attachment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = _preferredAspectRatio(attachment);
    final width = ratio >= 1 ? 220.0 : 168.0;
    final height = width / ratio;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _VideoPlaceholder(attachment: attachment),
              Container(color: CupertinoColors.black.withAlpha(36)),
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: CupertinoColors.black.withAlpha(110),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: CupertinoColors.white.withAlpha(70),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    CupertinoIcons.play_fill,
                    color: CupertinoColors.white,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoPopupPlayerDialog extends StatefulWidget {
  const _VideoPopupPlayerDialog({required this.attachment});

  final AttachmentItem attachment;

  @override
  State<_VideoPopupPlayerDialog> createState() =>
      _VideoPopupPlayerDialogState();
}

class _VideoPopupPlayerDialogState extends State<_VideoPopupPlayerDialog> {
  @override
  Widget build(BuildContext context) {
    final title = widget.attachment.fileName.isEmpty
        ? 'Video'
        : widget.attachment.fileName;
    final size = MediaQuery.sizeOf(context);
    final aspectRatio = _preferredAspectRatio(widget.attachment);

    final dialogWidth = size.width * 0.82;
    final dialogHeight = size.height * 0.82;

    return material.Material(
      type: material.MaterialType.transparency,
      child: Center(
        child: Container(
          width: dialogWidth.clamp(520.0, 1120.0),
          height: dialogHeight.clamp(320.0, 820.0),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.black.withAlpha(70),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appOnDarkTextStyle(
                          context,
                          fontSize: AppFontSizes.body + 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Icon(
                        CupertinoIcons.clear,
                        color: CupertinoColors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: material.Material(
                  color: material.Colors.black,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: aspectRatio,
                      child: const _VideoPlaybackUnavailable(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({required this.attachment});

  final AttachmentItem attachment;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF272727), Color(0xFF151515)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Text(
              attachment.fileName.isEmpty ? 'Video' : attachment.fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: appOnDarkTextStyle(
                context,
                fontSize: AppFontSizes.meta,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPlaybackUnavailable extends StatelessWidget {
  const _VideoPlaybackUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.play_rectangle,
              color: CupertinoColors.white,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'Video playback is temporarily disabled.',
              textAlign: TextAlign.center,
              style: appOnDarkTextStyle(
                context,
                fontSize: AppFontSizes.sectionTitle,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'TODO: replace media_kit with a simpler video playback approach.',
              textAlign: TextAlign.center,
              style: appOnDarkTextStyle(
                context,
                color: CupertinoColors.systemGrey,
                fontSize: AppFontSizes.meta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _preferredAspectRatio(AttachmentItem attachment) {
  final width = attachment.width;
  final height = attachment.height;
  if (width != null && height != null && width > 0 && height > 0) {
    return width / height;
  }
  return 16 / 9;
}
