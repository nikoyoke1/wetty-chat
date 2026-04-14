import 'dart:async';
import 'dart:typed_data';

import 'package:chahua/core/cache/image_cache_service.dart';
import 'package:chahua/core/cache/media_cache_service.dart';
import 'package:chahua/features/chats/conversation/data/video_thumbnail_service.dart';
import 'package:chahua/features/chats/conversation/presentation/attachment_viewer_page.dart';
import 'package:chahua/features/chats/conversation/presentation/attachment_viewer_request.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VideoPlayerPlatform originalVideoPlayerPlatform;

  setUp(() {
    originalVideoPlayerPlatform = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = _FakeVideoPlayerPlatform();
  });

  tearDown(() {
    VideoPlayerPlatform.instance = originalVideoPlayerPlatform;
  });

  testWidgets('image tap toggles fullscreen chrome visibility', (
    WidgetTester tester,
  ) async {
    await _pumpViewer(
      tester,
      request: AttachmentViewerRequest(
        items: [_imageViewerItem('image-0')],
        initialIndex: 0,
      ),
    );

    expect(
      find.byKey(const ValueKey('attachment-viewer-chrome')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('attachment-viewer-count')), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('attachment-viewer-media-0')));
    await _settleChromeToggle(tester);

    expect(
      find.byKey(const ValueKey('attachment-viewer-chrome')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('attachment-viewer-media-0')));
    await _settleChromeToggle(tester);

    expect(
      find.byKey(const ValueKey('attachment-viewer-chrome')),
      findsOneWidget,
    );
  });

  testWidgets('video rail stays centered on the active item after swipe', (
    WidgetTester tester,
  ) async {
    await _pumpViewer(
      tester,
      request: AttachmentViewerRequest(
        items: [
          _videoViewerItem('video-0'),
          _videoViewerItem('video-1'),
          _videoViewerItem('video-2'),
        ],
        initialIndex: 0,
      ),
    );

    expect(
      find.byKey(const ValueKey('video-thumbnail-image-video-0')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey('attachment-viewer-media-0')),
      const Offset(-420, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('2/3'), findsOneWidget);
    _expectThumbnailCentered(
      tester,
      railKey: const Key('attachment-viewer-thumbnails'),
      thumbnailKey: const ValueKey('attachment-viewer-thumbnail-1'),
    );

    await tester.tap(
      find.byKey(const ValueKey('attachment-viewer-thumbnail-2')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('3/3'), findsOneWidget);
    _expectThumbnailCentered(
      tester,
      railKey: const Key('attachment-viewer-thumbnails'),
      thumbnailKey: const ValueKey('attachment-viewer-thumbnail-2'),
    );
  });

  testWidgets(
    'dragging the rail changes media selection and keeps it centered',
    (WidgetTester tester) async {
      await _pumpViewer(
        tester,
        request: AttachmentViewerRequest(
          items: [
            _videoViewerItem('video-0'),
            _videoViewerItem('video-1'),
            _videoViewerItem('video-2'),
          ],
          initialIndex: 0,
        ),
      );

      await tester.drag(
        find.byKey(const Key('attachment-viewer-thumbnails')),
        const Offset(-420, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('2/3'), findsOneWidget);
      _expectThumbnailCentered(
        tester,
        railKey: const Key('attachment-viewer-thumbnails'),
        thumbnailKey: const ValueKey('attachment-viewer-thumbnail-1'),
      );

      await tester.drag(
        find.byKey(const Key('attachment-viewer-thumbnails')),
        const Offset(-420, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('3/3'), findsOneWidget);
      _expectThumbnailCentered(
        tester,
        railKey: const Key('attachment-viewer-thumbnails'),
        thumbnailKey: const ValueKey('attachment-viewer-thumbnail-2'),
      );
    },
  );
}

Future<void> _pumpViewer(
  WidgetTester tester, {
  required AttachmentViewerRequest request,
}) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        imageCacheServiceProvider.overrideWithValue(_FakeImageCacheService()),
        videoThumbnailServiceProvider.overrideWithValue(
          _FakeVideoThumbnailService(),
        ),
      ],
      child: CupertinoApp(home: AttachmentViewerPage(request: request)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _settleChromeToggle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 220));
}

void _expectThumbnailCentered(
  WidgetTester tester, {
  required Key railKey,
  required Key thumbnailKey,
}) {
  final railCenter = tester.getCenter(find.byKey(railKey));
  final thumbnailCenter = tester.getCenter(find.byKey(thumbnailKey));
  expect((thumbnailCenter.dx - railCenter.dx).abs(), lessThanOrEqualTo(2));
}

AttachmentViewerItem _imageViewerItem(String id) {
  return AttachmentViewerItem(
    attachment: AttachmentItem(
      id: id,
      url: 'memory://$id',
      kind: 'image/jpeg',
      size: 1024,
      fileName: '$id.jpg',
      width: 1200,
      height: 900,
    ),
    heroTag: 'hero-$id',
    mediaKind: AttachmentViewerMediaKind.image,
  );
}

AttachmentViewerItem _videoViewerItem(String id) {
  return AttachmentViewerItem(
    attachment: AttachmentItem(
      id: id,
      url: 'https://example.com/$id.mp4',
      kind: 'video/mp4',
      size: 1024,
      fileName: '$id.mp4',
      width: 1280,
      height: 720,
      durationMs: 4000,
    ),
    heroTag: 'hero-$id',
    mediaKind: AttachmentViewerMediaKind.video,
  );
}

class _FakeImageCacheService extends ImageCacheService {
  @override
  ImageProvider<Object> providerForUrl(String imageUrl) {
    return MemoryImage(Uint8List.fromList(_transparentImage));
  }
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final Map<int, StreamController<VideoEvent>> _eventControllers = {};
  final Map<int, Duration> _positions = {};
  var _nextPlayerId = 1;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    final playerId = _nextPlayerId++;
    _positions[playerId] = Duration.zero;
    late final StreamController<VideoEvent> controller;
    controller = StreamController<VideoEvent>.broadcast(
      onListen: () {
        controller.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(seconds: 4),
            size: const Size(1280, 720),
          ),
        );
      },
    );
    _eventControllers[playerId] = controller;
    return playerId;
  }

  @override
  Future<void> dispose(int playerId) async {
    _positions.remove(playerId);
    await _eventControllers.remove(playerId)?.close();
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    return _eventControllers[playerId]!.stream;
  }

  @override
  Future<void> pause(int playerId) async {
    _eventControllers[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> play(int playerId) async {
    _eventControllers[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    _positions[playerId] = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async {
    return _positions[playerId] ?? Duration.zero;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildView(int playerId) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Text('video-$playerId', textDirection: TextDirection.ltr),
      ),
    );
  }
}

class _FakeVideoThumbnailService extends VideoThumbnailService {
  _FakeVideoThumbnailService() : super(MediaCacheService(), Dio());

  @override
  Future<Uint8List?> getThumbnailBytes(AttachmentItem attachment) async {
    return Uint8List.fromList(_transparentImage);
  }
}

const List<int> _transparentImage = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
