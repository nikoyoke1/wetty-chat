import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chahua/features/chats/conversation/data/audio_source_resolver_service.dart';
import 'package:chahua/features/chats/conversation/data/audio_waveform_cache_service.dart';
import 'package:chahua/features/chats/models/message_models.dart';

void main() {
  test(
    'primeFromAttachmentMetadata stores waveform under the uploaded id',
    () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      final service = AudioWaveformCacheService(
        preferences,
        AudioSourceResolverService(Dio(), preferences),
      );

      service.primeFromAttachmentMetadata(
        attachmentId: 'uploaded-audio',
        duration: const Duration(seconds: 6),
        samples: const <int>[3, 9, 18, 27],
      );

      final snapshot = await service.resolveForAttachment(
        const AttachmentItem(
          id: 'uploaded-audio',
          url: '',
          kind: 'audio/ogg',
          size: 2048,
          fileName: 'voice.ogg',
        ),
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.duration, const Duration(seconds: 6));
      expect(
        snapshot.samples,
        hasLength(AudioWaveformCacheService.targetBarCount),
      );
    },
  );
}
