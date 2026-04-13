import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/core/session/dev_session_store.dart';
import 'package:chahua/features/chats/conversation/application/conversation_composer_view_model.dart';
import 'package:chahua/features/chats/conversation/data/audio_recorder_service.dart';
import 'package:chahua/features/chats/conversation/data/audio_waveform_cache_service.dart';
import 'package:chahua/features/chats/conversation/data/conversation_repository.dart';
import 'package:chahua/features/chats/conversation/data/message_api_service.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_message.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_scope.dart';
import 'package:chahua/features/chats/conversation/presentation/compose/conversation_composer_bar.dart';
import 'package:chahua/features/chats/message_domain/domain/message_domain.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:chahua/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('edit cancel restores the draft shown in the input', (
    WidgetTester tester,
  ) async {
    final scope = ConversationScope.chat(chatId: 'widget-edit-cancel');
    final repository = _FakeConversationRepository(scope);
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(_AuthenticatedSessionNotifier.new),
        audioRecorderServiceProvider.overrideWithValue(
          _FakeAudioRecorderService(),
        ),
        audioWaveformCacheServiceProvider.overrideWithValue(
          _FakeAudioWaveformCacheService(),
        ),
        conversationRepositoryProvider(scope).overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CupertinoPageScaffold(
            child: SafeArea(child: ConversationComposerBar(scope: scope)),
          ),
        ),
      ),
    );

    final notifier = container.read(
      conversationComposerViewModelProvider(scope).notifier,
    );
    await notifier.updateDraft('draft before edit');
    await tester.pumpAndSettle();

    notifier.beginEdit(_message(scope, id: 77, text: 'message being edited'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
    await tester.pumpAndSettle();

    final textField = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    expect(textField.controller!.text, 'draft before edit');
  });
}

ConversationMessage _message(
  ConversationScope scope, {
  required int id,
  required String text,
}) {
  return ConversationMessage(
    scope: scope,
    serverMessageId: id,
    clientGeneratedId: 'client-$id',
    sender: const Sender(uid: 1, name: 'You'),
    message: text,
  );
}

class _AuthenticatedSessionNotifier extends AuthSessionNotifier {
  @override
  AuthSessionState build() {
    return const AuthSessionState(
      status: AuthBootstrapStatus.authenticated,
      mode: AuthSessionMode.devHeader,
      developerUserId: 1,
      currentUserId: 1,
    );
  }
}

class _FakeConversationRepository extends ConversationRepository {
  _FakeConversationRepository(ConversationScope scope)
    : super(
        scope: scope,
        service: _FakeMessageApiService(),
        store: MessageDomainStore(),
      );
}

class _FakeMessageApiService extends MessageApiService {
  _FakeMessageApiService() : super(Dio(), 1);
}

class _FakeAudioRecorderService implements AudioRecorderService {
  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> isRecording() async => false;

  @override
  Future<void> start() async {}

  @override
  Future<RecordedAudioFile?> stop({required Duration duration}) async => null;
}

class _FakeAudioWaveformCacheService implements AudioWaveformCacheService {
  @override
  void clearMemory() {}

  @override
  Future<AudioWaveformSnapshot?> primeFromAttachmentMetadata({
    required String attachmentId,
    required Duration duration,
    required List<int> samples,
  }) async => null;

  @override
  Future<AudioWaveformSnapshot?> primeFromLocalRecording({
    required String attachmentId,
    required String audioFilePath,
    required Duration duration,
  }) async => null;

  @override
  Future<AudioWaveformSnapshot?> resolveForAttachment(
    AttachmentItem attachment, {
    Duration? preferredDuration,
    String? waveformInputPath,
  }) async => null;
}
