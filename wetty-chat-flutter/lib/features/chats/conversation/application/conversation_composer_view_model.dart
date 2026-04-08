import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/session/dev_session_store.dart';
import '../../models/message_models.dart';
import '../data/attachment_picker_service.dart';
import '../data/attachment_service.dart';
import '../data/conversation_repository.dart';
import '../domain/conversation_message.dart';
import '../domain/conversation_scope.dart';
import 'conversation_draft_store.dart';

const int composerMaxAttachments =
    ConversationComposerState.maxAttachmentsPerMessage;

enum ComposerAttachmentUploadStatus { queued, uploading, uploaded, failed }

class ComposerAttachment {
  const ComposerAttachment({
    required this.localId,
    required this.file,
    required this.name,
    required this.mimeType,
    required this.kind,
    required this.sizeBytes,
    required this.status,
    this.previewBytes,
    this.width,
    this.height,
    this.attachmentId,
    this.errorMessage,
  });

  final String localId;
  final PlatformFile file;
  final String name;
  final String mimeType;
  final ComposerAttachmentKind kind;
  final int sizeBytes;
  final Uint8List? previewBytes;
  final int? width;
  final int? height;
  final ComposerAttachmentUploadStatus status;
  final String? attachmentId;
  final String? errorMessage;

  bool get isImageLike =>
      kind == ComposerAttachmentKind.image ||
      kind == ComposerAttachmentKind.gif;
  bool get isVideo => kind == ComposerAttachmentKind.video;
  bool get isUploaded => status == ComposerAttachmentUploadStatus.uploaded;
  bool get isUploading =>
      status == ComposerAttachmentUploadStatus.queued ||
      status == ComposerAttachmentUploadStatus.uploading;
  bool get hasFailed => status == ComposerAttachmentUploadStatus.failed;
  bool get isFailed => hasFailed;

  ComposerAttachment copyWith({
    String? localId,
    PlatformFile? file,
    String? name,
    String? mimeType,
    ComposerAttachmentKind? kind,
    int? sizeBytes,
    Uint8List? previewBytes,
    int? width,
    int? height,
    ComposerAttachmentUploadStatus? status,
    String? attachmentId,
    String? errorMessage,
    bool clearAttachmentId = false,
    bool clearErrorMessage = false,
  }) {
    return ComposerAttachment(
      localId: localId ?? this.localId,
      file: file ?? this.file,
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      kind: kind ?? this.kind,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      previewBytes: previewBytes ?? this.previewBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      status: status ?? this.status,
      attachmentId: clearAttachmentId
          ? null
          : (attachmentId ?? this.attachmentId),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  AttachmentItem toAttachmentItem() => AttachmentItem(
    id: attachmentId ?? localId,
    url: '',
    kind: mimeType,
    size: sizeBytes,
    fileName: name,
    width: width,
    height: height,
  );
}

sealed class ConversationComposerMode {
  const ConversationComposerMode();
}

class ComposerIdle extends ConversationComposerMode {
  const ComposerIdle();
}

class ComposerReplying extends ConversationComposerMode {
  const ComposerReplying(this.message);

  final ConversationMessage message;
}

class ComposerEditing extends ConversationComposerMode {
  const ComposerEditing(this.message);

  final ConversationMessage message;
}

class ConversationComposerState {
  const ConversationComposerState({
    required this.draft,
    required this.mode,
    required this.attachments,
  });

  static const int maxAttachmentsPerMessage = 10;

  final String draft;
  final ConversationComposerMode mode;
  final List<ComposerAttachment> attachments;

  bool get isEditing => mode is ComposerEditing;
  bool get hasUploadingAttachments =>
      attachments.any((item) => item.isUploading);
  bool get hasFailedAttachments => attachments.any((item) => item.hasFailed);
  bool get hasUploadedAttachments => attachments.any((item) => item.isUploaded);
  bool get hasAttachmentCapacity =>
      attachments.length < maxAttachmentsPerMessage;
  bool get canSend =>
      !hasUploadingAttachments &&
      !hasFailedAttachments &&
      (draft.trim().isNotEmpty || hasUploadedAttachments);
  int get remainingAttachmentSlots =>
      maxAttachmentsPerMessage - attachments.length;
  List<String> get uploadedAttachmentIds => attachments
      .where((item) => item.isUploaded && item.attachmentId != null)
      .map((item) => item.attachmentId!)
      .toList(growable: false);

  ConversationComposerState copyWith({
    String? draft,
    ConversationComposerMode? mode,
    List<ComposerAttachment>? attachments,
  }) {
    return ConversationComposerState(
      draft: draft ?? this.draft,
      mode: mode ?? this.mode,
      attachments: attachments ?? this.attachments,
    );
  }
}

class ConversationComposerViewModel
    extends FamilyNotifier<ConversationComposerState, ConversationScope> {
  late final ConversationRepository _repository;
  late final ConversationDraftStore _draftStore;
  late final AttachmentService _attachmentService;
  late final AttachmentPickerService _pickerService;
  late final ConversationScope _scope;

  @override
  ConversationComposerState build(ConversationScope arg) {
    _scope = arg;
    _repository = ref.read(conversationRepositoryProvider(arg));
    _draftStore = ref.read(conversationDraftProvider);
    _attachmentService = ref.read(attachmentServiceProvider);
    _pickerService = ref.read(attachmentPickerServiceProvider);
    final draft = _draftStore.getDraft(arg) ?? '';
    return ConversationComposerState(
      draft: draft,
      mode: const ComposerIdle(),
      attachments: const <ComposerAttachment>[],
    );
  }

  Future<void> updateDraft(String value) async {
    state = state.copyWith(draft: value);
    await _draftStore.setDraft(_scope, value);
  }

  void beginReply(ConversationMessage message) {
    state = state.copyWith(
      mode: ComposerReplying(message),
      attachments: const <ComposerAttachment>[],
    );
  }

  void beginEdit(ConversationMessage message) {
    state = state.copyWith(
      mode: ComposerEditing(message),
      draft: message.message ?? '',
      attachments: const <ComposerAttachment>[],
    );
  }

  void clearMode() {
    state = state.copyWith(mode: const ComposerIdle());
  }

  Future<String?> pickAttachments(ComposerAttachmentSource source) async {
    if (state.isEditing) {
      throw Exception('Editing messages does not support attachments');
    }

    final remaining = state.remainingAttachmentSlots;
    if (remaining <= 0) {
      return 'You can attach up to '
          '${ConversationComposerState.maxAttachmentsPerMessage} files.';
    }

    final picked = await _pickerService.pick(source);
    if (picked.isEmpty) {
      return null;
    }

    final accepted = picked.take(remaining).map(_toComposerAttachment).toList();
    state = state.copyWith(attachments: [...state.attachments, ...accepted]);

    for (final attachment in accepted) {
      unawaited(_uploadAttachment(attachment.localId));
    }

    final skippedCount = picked.length - accepted.length;
    if (skippedCount > 0) {
      return 'You can attach up to '
          '${ConversationComposerState.maxAttachmentsPerMessage} files.';
    }
    return null;
  }

  void removeAttachment(String localId) {
    state = state.copyWith(
      attachments: state.attachments
          .where((item) => item.localId != localId)
          .toList(growable: false),
    );
  }

  void clearAttachments() {
    if (state.attachments.isEmpty) {
      return;
    }
    state = state.copyWith(attachments: const <ComposerAttachment>[]);
  }

  Future<void> retryAttachment(String localId) {
    final attachment = _attachmentByLocalId(localId);
    if (attachment == null) {
      return Future<void>.value();
    }
    return _uploadAttachment(localId, forceRestart: true);
  }

  Future<void> send({required String text}) async {
    final trimmed = text.trim();
    final attachmentIds = state.uploadedAttachmentIds;
    final mode = state.mode;

    if (state.hasUploadingAttachments) {
      throw Exception('Please wait for attachments to finish uploading.');
    }
    if (state.hasFailedAttachments) {
      throw Exception('Retry or remove failed attachments before sending.');
    }
    if (trimmed.isEmpty && attachmentIds.isEmpty) {
      return;
    }

    if (mode is ComposerEditing) {
      if (attachmentIds.isNotEmpty) {
        throw Exception('Editing messages does not support attachments');
      }
      _repository.beginOptimisticEdit(mode.message.serverMessageId!);
      try {
        await _repository.commitEdit(mode.message.serverMessageId!, trimmed);
        state = const ConversationComposerState(
          draft: '',
          mode: ComposerIdle(),
          attachments: <ComposerAttachment>[],
        );
        await _draftStore.clearDraft(_scope);
      } catch (_) {
        _repository.rollbackEdit(mode.message.serverMessageId!);
        rethrow;
      }
      return;
    }

    final optimisticAttachments = state.attachments
        .where((item) => item.isUploaded)
        .map((item) => item.toAttachmentItem())
        .toList(growable: false);

    final currentUserId = ref.read(authSessionProvider).currentUserId;
    final clientGeneratedId =
        '${DateTime.now().microsecondsSinceEpoch}-$currentUserId-${_scope.storageKey}';
    _repository.insertOptimisticSend(
      sender: Sender(uid: currentUserId, name: 'You'),
      text: trimmed,
      attachments: optimisticAttachments,
      clientGeneratedId: clientGeneratedId,
      replyToId: mode is ComposerReplying ? mode.message.serverMessageId : null,
    );

    try {
      await _repository.commitSend(
        clientGeneratedId: clientGeneratedId,
        text: trimmed,
        attachmentIds: attachmentIds,
        replyToId: mode is ComposerReplying
            ? mode.message.serverMessageId
            : null,
      );
      state = const ConversationComposerState(
        draft: '',
        mode: ComposerIdle(),
        attachments: <ComposerAttachment>[],
      );
      await _draftStore.clearDraft(_scope);
    } catch (_) {
      _repository.markSendFailed(clientGeneratedId);
      rethrow;
    }
  }

  Future<void> _uploadAttachment(
    String localId, {
    bool forceRestart = false,
  }) async {
    final attachment = _attachmentByLocalId(localId);
    if (attachment == null) {
      return;
    }
    if (!forceRestart &&
        (attachment.isUploading ||
            attachment.status == ComposerAttachmentUploadStatus.uploaded)) {
      return;
    }

    _updateAttachment(
      localId,
      (current) => current.copyWith(
        status: ComposerAttachmentUploadStatus.uploading,
        clearAttachmentId: true,
        clearErrorMessage: true,
      ),
    );

    final current = _attachmentByLocalId(localId);
    if (current == null) {
      return;
    }

    try {
      final uploadInfo = await _attachmentService.requestUploadUrl(
        filename: current.name,
        contentType: current.mimeType,
        size: current.sizeBytes,
        width: current.width,
        height: current.height,
      );
      await _attachmentService.uploadFileToS3(
        uploadUrl: uploadInfo.uploadUrl,
        file: current.file,
        uploadHeaders: uploadInfo.uploadHeaders,
      );
      _updateAttachment(
        localId,
        (latest) => latest.copyWith(
          status: ComposerAttachmentUploadStatus.uploaded,
          attachmentId: uploadInfo.attachmentId,
          clearErrorMessage: true,
        ),
      );
    } catch (_) {
      _updateAttachment(
        localId,
        (latest) => latest.copyWith(
          status: ComposerAttachmentUploadStatus.failed,
          errorMessage: 'Upload failed',
          clearAttachmentId: true,
        ),
      );
    }
  }

  ComposerAttachment? _attachmentByLocalId(String localId) {
    for (final attachment in state.attachments) {
      if (attachment.localId == localId) {
        return attachment;
      }
    }
    return null;
  }

  void _updateAttachment(
    String localId,
    ComposerAttachment Function(ComposerAttachment current) update,
  ) {
    var found = false;
    final next = state.attachments
        .map((attachment) {
          if (attachment.localId != localId) {
            return attachment;
          }
          found = true;
          return update(attachment);
        })
        .toList(growable: false);
    if (!found) {
      return;
    }
    state = state.copyWith(attachments: next);
  }

  ComposerAttachment _toComposerAttachment(PickedComposerAttachment item) {
    return ComposerAttachment(
      localId: item.localId,
      file: item.file,
      name: item.name,
      mimeType: item.mimeType,
      kind: item.kind,
      sizeBytes: item.sizeBytes,
      previewBytes: item.previewBytes,
      width: item.width,
      height: item.height,
      status: ComposerAttachmentUploadStatus.queued,
    );
  }

  Future<void> delete(ConversationMessage message) async {
    final messageId = message.serverMessageId;
    if (messageId == null) {
      _repository.discardFailedMessage(message);
      return;
    }
    _repository.beginOptimisticDelete(messageId);
    try {
      await _repository.commitDelete(messageId);
    } catch (_) {
      _repository.rollbackDelete(messageId);
      rethrow;
    }
  }

  Future<void> retryFailedMessage(ConversationMessage message) async {
    await _repository.retryFailedSend(message);
  }

  Future<void> discardFailedMessage(ConversationMessage message) async {
    _repository.discardFailedMessage(message);
  }
}

final attachmentServiceProvider = Provider<AttachmentService>((ref) {
  return AttachmentService(ref.watch(dioProvider));
});

final attachmentPickerServiceProvider = Provider<AttachmentPickerService>((
  ref,
) {
  return AttachmentPickerService();
});

final conversationComposerViewModelProvider =
    NotifierProvider.family<
      ConversationComposerViewModel,
      ConversationComposerState,
      ConversationScope
    >(ConversationComposerViewModel.new);
