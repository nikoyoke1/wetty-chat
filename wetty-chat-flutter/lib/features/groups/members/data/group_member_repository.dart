import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'group_member_api_mapper.dart';
import 'group_member_api_service.dart';
import 'group_member_models.dart';

class GroupMemberRepository {
  GroupMemberRepository(this._apiService);

  final GroupMemberApiService _apiService;

  Future<GroupMembersPage> fetchMembers(
    String chatId, {
    int limit = 50,
    int? after,
    String? query,
    GroupMemberSearchMode? searchMode,
  }) async {
    final response = await _apiService.fetchMembers(
      chatId,
      limit: limit,
      after: after,
      query: query,
      searchMode: searchMode?.wireValue,
    );
    return GroupMembersPage(
      members: response.members.map((member) => member.toDomain()).toList(),
      canManageMembers: response.canManageMembers,
      nextCursor: response.nextCursor,
    );
  }

  Future<void> addMember(String chatId, {required int userId}) async {
    await _apiService.addMember(chatId, userId: userId);
  }

  Future<void> removeMember(String chatId, {required int userId}) async {
    await _apiService.removeMember(chatId, userId: userId);
  }

  Future<void> updateMemberRole(
    String chatId, {
    required int userId,
    required String role,
  }) async {
    await _apiService.updateMemberRole(chatId, userId: userId, role: role);
  }
}

final groupMemberRepositoryProvider = Provider<GroupMemberRepository>((ref) {
  return GroupMemberRepository(ref.watch(groupMemberApiServiceProvider));
});
