import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wetty_chat_flutter/core/api/models/group_info_api_models.dart';
import 'package:wetty_chat_flutter/core/network/websocket_service.dart';
import 'package:wetty_chat_flutter/features/chats/models/chat_models.dart';
import 'package:wetty_chat_flutter/features/chats/list/data/chat_repository.dart';
import 'package:wetty_chat_flutter/features/groups/metadata/application/group_metadata_view_model.dart';
import 'package:wetty_chat_flutter/features/groups/metadata/data/group_metadata_api_service.dart';
import 'package:wetty_chat_flutter/features/groups/metadata/data/group_metadata_repository.dart';

void main() {
  test(
    'updateMetadata stores backend result and syncs chat list metadata',
    () async {
      final service = _FakeGroupMetadataApiService(
        const GroupInfoResponseDto(id: 42, name: 'Original Name'),
      );
      final container = ProviderContainer(
        overrides: [
          groupMetadataRepositoryProvider.overrideWithValue(
            GroupMetadataRepository(service),
          ),
          wsEventsProvider.overrideWith((ref) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(chatListStateProvider.notifier)
          .insertChat(ChatListItem(id: '42', name: 'Stale Name'));

      final provider = groupMetadataViewModelProvider('42');
      final initial = await container.read(provider.future);
      expect(initial.name, 'Original Name');

      service.nextResponse = const GroupInfoResponseDto(
        id: 42,
        name: 'Updated Name',
      );

      final updated = await container
          .read(provider.notifier)
          .updateMetadata(name: 'Updated Name');

      expect(updated.name, 'Updated Name');
      expect(container.read(provider).valueOrNull?.name, 'Updated Name');
      expect(
        container.read(chatListStateProvider).chats.first.name,
        'Updated Name',
      );
    },
  );
}

class _FakeGroupMetadataApiService extends GroupMetadataApiService {
  _FakeGroupMetadataApiService(this.nextResponse) : super(Dio());

  GroupInfoResponseDto nextResponse;

  @override
  Future<GroupInfoResponseDto> fetchGroupMetadata(String chatId) async {
    return nextResponse;
  }

  @override
  Future<GroupInfoResponseDto> updateGroupMetadata(
    String chatId, {
    String? name,
    String? description,
    int? avatarImageId,
    String? visibility,
  }) async {
    return nextResponse;
  }
}
