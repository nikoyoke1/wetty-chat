import 'dart:developer';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:voice_message/voice_message.dart';

import '../../../../core/cache/media_cache_service.dart';
import '../../models/message_models.dart';

class AudioPlaybackSource {
  const AudioPlaybackSource._({
    required this.filePath,
    required this.url,
    required this.localWaveformPath,
  });

  const AudioPlaybackSource.file({
    required String filePath,
    required String localWaveformPath,
  }) : this._(
         filePath: filePath,
         url: null,
         localWaveformPath: localWaveformPath,
       );

  const AudioPlaybackSource.url({
    required String url,
    String? localWaveformPath,
  }) : this._(filePath: null, url: url, localWaveformPath: localWaveformPath);

  final String? filePath;
  final String? url;
  final String? localWaveformPath;

  bool get isFile => filePath != null;
}

class AudioSourceResolverService {
  AudioSourceResolverService(this._mediaCacheService);

  final MediaCacheService _mediaCacheService;

  Future<AudioPlaybackSource?> resolvePlaybackSource(
    AttachmentItem attachment,
  ) async {
    if (attachment.url.isEmpty) {
      return null;
    }

    final playbackFile = _requiresTranscode(attachment)
        ? await _resolvePreparedLocalFile(attachment)
        : await _mediaCacheService.getOrFetchOriginal(attachment);
    if (playbackFile == null) {
      return null;
    }
    return AudioPlaybackSource.file(
      filePath: playbackFile.path,
      localWaveformPath: playbackFile.path,
    );
  }

  Future<String?> resolveWaveformInputPath(AttachmentItem attachment) async {
    final source = await resolvePlaybackSource(attachment);
    return source?.localWaveformPath;
  }

  bool _requiresTranscode(AttachmentItem attachment) {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return false;
    }
    if (!attachment.isAudio || attachment.url.isEmpty) {
      return false;
    }

    final descriptor = _audioDescriptorForAttachment(attachment);
    return descriptor.contains('webm') ||
        descriptor.contains('ogg') ||
        descriptor.contains('opus');
  }

  Future<File?> _resolvePreparedLocalFile(AttachmentItem attachment) async {
    try {
      return await _mediaCacheService.getOrCreateDerived(
        attachment: attachment,
        variant: 'm4a',
        fileExtension: 'm4a',
        createDerivedFile: (originalFile) async {
          final tempDirectory = await getTemporaryDirectory();
          final cacheKey = _mediaCacheService.cacheKeyForAttachment(attachment);
          final outputFile = File('${tempDirectory.path}/$cacheKey.m4a');
          await VoiceMessage.convertOggToM4a(
            srcPath: originalFile.path,
            destPath: outputFile.path,
          );
          if (!await outputFile.exists()) {
            return null;
          }
          return outputFile;
        },
      );
    } catch (error, stackTrace) {
      log(
        'Audio transcode threw for ${attachment.id} (${attachment.kind})',
        name: 'AudioSourceResolverService',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  String _audioDescriptorForAttachment(AttachmentItem attachment) {
    final uriPath = Uri.tryParse(attachment.url)?.path.toLowerCase() ?? '';
    return '${attachment.kind.toLowerCase()}|${attachment.fileName.toLowerCase()}|$uriPath';
  }
}

final audioSourceResolverServiceProvider = Provider<AudioSourceResolverService>(
  (ref) {
    return AudioSourceResolverService(ref.watch(mediaCacheServiceProvider));
  },
);
