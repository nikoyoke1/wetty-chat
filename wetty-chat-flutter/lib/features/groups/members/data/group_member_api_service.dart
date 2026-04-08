import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/models/group_members_api_models.dart';
import '../../../../core/network/dio_client.dart';

class GroupMemberApiService {
  final Dio _dio;

  GroupMemberApiService(this._dio);

  Future<GroupMembersResponseDto> fetchMembers(String chatId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/group/$chatId/members',
    );
    return GroupMembersResponseDto.fromJson(response.data!);
  }
}

final groupMemberApiServiceProvider = Provider<GroupMemberApiService>((ref) {
  return GroupMemberApiService(ref.watch(dioProvider));
});
