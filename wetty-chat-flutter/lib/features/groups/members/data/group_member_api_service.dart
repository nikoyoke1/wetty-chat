import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/models/group_members_api_models.dart';
import '../../../../core/network/dio_client.dart';

class GroupMemberApiService {
  final Dio _dio;

  GroupMemberApiService(this._dio);

  Future<GroupMembersResponseDto> fetchMembers(
    String chatId, {
    int limit = 50,
    int? after,
    String? query,
    String? searchMode,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/group/$chatId/members',
      queryParameters: {
        'limit': limit,
        ...?after == null ? null : {'after': after},
        ...?query == null || query.isEmpty ? null : {'q': query},
        ...?searchMode == null || searchMode.isEmpty
            ? null
            : {'mode': searchMode},
      },
    );
    return GroupMembersResponseDto.fromJson(response.data!);
  }

  Future<GroupMemberDto> addMember(String chatId, {required int userId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/group/$chatId/members',
      data: {'uid': userId},
    );
    return GroupMemberDto.fromJson(response.data!);
  }

  Future<void> removeMember(String chatId, {required int userId}) async {
    await _dio.delete<void>('/group/$chatId/members/$userId');
  }

  Future<GroupMemberDto> updateMemberRole(
    String chatId, {
    required int userId,
    required String role,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/group/$chatId/members/$userId',
      data: {'role': role},
    );
    return GroupMemberDto.fromJson(response.data!);
  }
}

final groupMemberApiServiceProvider = Provider<GroupMemberApiService>((ref) {
  return GroupMemberApiService(ref.watch(dioProvider));
});
