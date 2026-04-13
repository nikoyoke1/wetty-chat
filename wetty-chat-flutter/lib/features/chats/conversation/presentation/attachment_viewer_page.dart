import 'dart:math' as math;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/app_cached_network_image.dart';
import '../../../../core/cache/image_cache_service.dart';
import 'attachment_viewer_request.dart';

class AttachmentViewerPage extends ConsumerStatefulWidget {
  const AttachmentViewerPage({super.key, required this.request});

  final AttachmentViewerRequest request;

  @override
  ConsumerState<AttachmentViewerPage> createState() =>
      _AttachmentViewerPageState();
}

class _AttachmentViewerPageState extends ConsumerState<AttachmentViewerPage> {
  static const double _thumbnailExtent = 56;
  static const double _thumbnailRailHeight = 92;
  static const double _dismissBaseScaleTolerance = 0.02;
  static const double _dismissDistanceFraction = 0.18;
  static const double _dismissMinVelocity = 900;

  late final ExtendedPageController _pageController;
  late final List<GlobalKey<ExtendedImageGestureState>> _gestureKeys;
  late final List<bool> _isItemAtBaseScale;
  var _currentIndex = 0;
  var _isSlidingPage = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.request.initialIndex;
    _pageController = ExtendedPageController(initialPage: _currentIndex);
    _gestureKeys = widget.request.items
        .map((_) => GlobalKey<ExtendedImageGestureState>())
        .toList(growable: false);
    _isItemAtBaseScale = List<bool>.filled(widget.request.items.length, true);
  }

  bool get _hasMultipleItems => widget.request.items.length > 1;

  bool get _isCurrentImageAtBaseScale => _isItemAtBaseScale[_currentIndex];

  Future<void> _selectIndex(int index) async {
    if (index == _currentIndex) {
      return;
    }
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _handlePageChanged(int index) {
    if (_currentIndex == index) {
      return;
    }
    setState(() {
      _currentIndex = index;
    });
    _precacheAdjacentImages(index);
  }

  void _handleGestureDetailsChanged(int index, GestureDetails? details) {
    final totalScale = details?.totalScale ?? 1.0;
    final isAtBaseScale =
        (totalScale - 1.0).abs() <= _dismissBaseScaleTolerance;
    if (_isItemAtBaseScale[index] == isAtBaseScale) {
      return;
    }
    setState(() {
      _isItemAtBaseScale[index] = isAtBaseScale;
    });
  }

  void _handleDoubleTap(ExtendedImageGestureState state) {
    final currentScale = state.gestureDetails?.totalScale ?? 1.0;
    final nextScale = currentScale > 1.2 ? 1.0 : 2.5;
    state.handleDoubleTap(
      scale: nextScale,
      doubleTapPosition: state.pointerDownPosition,
    );
  }

  void _precacheAdjacentImages(int index) {
    final cacheService = ref.read(imageCacheServiceProvider);
    for (final candidateIndex in <int>[index - 1, index + 1]) {
      if (candidateIndex < 0 || candidateIndex >= widget.request.items.length) {
        continue;
      }
      precacheImage(
        cacheService.providerForUrl(
          widget.request.items[candidateIndex].attachment.url,
        ),
        context,
      );
    }
  }

  Widget _buildViewerChrome(BuildContext context) {
    final title = '${_currentIndex + 1}/${widget.request.items.length}';
    return IgnorePointer(
      ignoring: _isSlidingPage,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(36, 36),
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Icon(
                      CupertinoIcons.back,
                      color: CupertinoColors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.black.withAlpha(110),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (_hasMultipleItems)
                _ThumbnailRail(
                  items: widget.request.items,
                  selectedIndex: _currentIndex,
                  onTap: _selectIndex,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePage(
    BuildContext context,
    AttachmentViewerItem item,
    int index,
  ) {
    final cacheService = ref.watch(imageCacheServiceProvider);
    final provider = cacheService.providerForUrl(item.attachment.url);

    return SizedBox.expand(
      child: Hero(
        tag: item.heroTag,
        child: ExtendedImage(
          image: provider,
          fit: BoxFit.contain,
          mode: ExtendedImageMode.gesture,
          enableLoadState: true,
          enableSlideOutPage: true,
          extendedImageGestureKey: _gestureKeys[index],
          initGestureConfigHandler: (state) => GestureConfig(
            minScale: 1.0,
            maxScale: 4.0,
            animationMinScale: 0.95,
            animationMaxScale: 4.5,
            speed: 1.0,
            inertialSpeed: 100.0,
            initialScale: 1.0,
            inPageView: true,
            initialAlignment: InitialAlignment.center,
            gestureDetailsIsChanged: (details) =>
                _handleGestureDetailsChanged(index, details),
          ),
          onDoubleTap: _handleDoubleTap,
          loadStateChanged: (state) {
            switch (state.extendedImageLoadState) {
              case LoadState.loading:
                return const Center(child: CupertinoActivityIndicator());
              case LoadState.completed:
                return null;
              case LoadState.failed:
                return _ImageLoadError(onRetry: state.reLoadImage);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: ExtendedImageSlidePage(
        slideAxis: SlideAxis.vertical,
        slideType: SlideType.wholePage,
        slidePageBackgroundHandler: (offset, pageSize) {
          final progress = (offset.dy.abs() / math.max(pageSize.height, 1))
              .clamp(0.0, 1.0);
          return CupertinoColors.black.withValues(alpha: 1 - (progress * 0.6));
        },
        slideEndHandler:
            (
              offset, {
              ExtendedImageSlidePageState? state,
              ScaleEndDetails? details,
            }) {
              if (!_isCurrentImageAtBaseScale || state == null) {
                return false;
              }

              final dismissDistance =
                  state.pageSize.height * _dismissDistanceFraction;
              final velocityY = details?.velocity.pixelsPerSecond.dy ?? 0;
              final movedFarEnough = offset.dy >= dismissDistance;
              final flungDown = velocityY >= _dismissMinVelocity;

              return movedFarEnough || flungDown;
            },
        onSlidingPage: (state) {
          final nextIsSlidingPage = state.isSliding;
          if (_isSlidingPage == nextIsSlidingPage) {
            return;
          }
          setState(() {
            _isSlidingPage = nextIsSlidingPage;
          });
        },
        child: Stack(
          children: [
            ExtendedImageGesturePageView.builder(
              controller: _pageController,
              itemCount: widget.request.items.length,
              canScrollPage: (_) => _isCurrentImageAtBaseScale,
              onPageChanged: _handlePageChanged,
              itemBuilder: (context, index) =>
                  _buildImagePage(context, widget.request.items[index], index),
            ),
            _buildViewerChrome(context),
          ],
        ),
      ),
    );
  }
}

class _ThumbnailRail extends StatelessWidget {
  const _ThumbnailRail({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<AttachmentViewerItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _AttachmentViewerPageState._thumbnailRailHeight,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ListView.separated(
          key: const Key('attachment-viewer-thumbnails'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            final isSelected = index == selectedIndex;

            return GestureDetector(
              onTap: () => onTap(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: _AttachmentViewerPageState._thumbnailExtent,
                height: _AttachmentViewerPageState._thumbnailExtent,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? CupertinoColors.white
                        : CupertinoColors.white.withAlpha(64),
                    width: isSelected ? 2 : 1,
                  ),
                  color: CupertinoColors.black.withAlpha(80),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: AppCachedNetworkImage(
                    imageUrl: item.attachment.url,
                    width: _AttachmentViewerPageState._thumbnailExtent,
                    height: _AttachmentViewerPageState._thumbnailExtent,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const ColoredBox(color: CupertinoColors.systemGrey),
                    errorWidget: (context, url, error) => const ColoredBox(
                      color: CupertinoColors.systemGrey,
                      child: Icon(
                        CupertinoIcons.exclamationmark_triangle,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ImageLoadError extends StatelessWidget {
  const _ImageLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
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
              'Failed to load image',
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
