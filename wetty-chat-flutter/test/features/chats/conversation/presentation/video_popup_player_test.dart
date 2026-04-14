import 'dart:typed_data';

import 'package:chahua/core/cache/media_cache_service.dart';
import 'package:chahua/features/chats/conversation/data/video_thumbnail_service.dart';
import 'package:chahua/features/chats/conversation/presentation/video_popup_player.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('video preview shows thumbnail and hides filename', (
    WidgetTester tester,
  ) async {
    final attachment = _videoAttachment(
      id: 'video-0',
      fileName: 'holiday.mp4',
      width: 720,
      height: 1280,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoThumbnailServiceProvider.overrideWithValue(
            _FakeVideoThumbnailService(),
          ),
        ],
        child: CupertinoApp(
          home: Center(
            child: VideoAttachmentPreview(
              attachment: attachment,
              maxWidth: 240,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('video-thumbnail-image-video-0')),
      findsOneWidget,
    );
    expect(find.text('holiday.mp4'), findsNothing);
    expect(find.text('0:04'), findsOneWidget);
  });

  testWidgets('video preview keeps real aspect ratio within caps', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoThumbnailServiceProvider.overrideWithValue(
            _FakeVideoThumbnailService(),
          ),
        ],
        child: CupertinoApp(
          home: Column(
            children: [
              VideoAttachmentPreview(
                key: const ValueKey('tall-preview'),
                attachment: _videoAttachment(
                  id: 'tall-video',
                  fileName: 'tall.mp4',
                  width: 720,
                  height: 1280,
                ),
                maxWidth: 240,
                onTap: () {},
              ),
              VideoAttachmentPreview(
                key: const ValueKey('wide-preview'),
                attachment: _videoAttachment(
                  id: 'wide-video',
                  fileName: 'wide.mp4',
                  width: 1920,
                  height: 1080,
                ),
                maxWidth: 240,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final tallSize = tester.getSize(find.byKey(const ValueKey('tall-preview')));
    final wideSize = tester.getSize(find.byKey(const ValueKey('wide-preview')));

    expect(tallSize.height, greaterThan(tallSize.width));
    expect(wideSize.width, greaterThan(wideSize.height));
  });
}

AttachmentItem _videoAttachment({
  required String id,
  required String fileName,
  required int width,
  required int height,
}) {
  return AttachmentItem(
    id: id,
    url: 'https://example.com/$fileName',
    kind: 'video/mp4',
    size: 1024,
    fileName: fileName,
    width: width,
    height: height,
    durationMs: 4000,
  );
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
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0x00,
  0x00,
  0x03,
  0x01,
  0x01,
  0x00,
  0x18,
  0xDD,
  0x8D,
  0xB1,
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
