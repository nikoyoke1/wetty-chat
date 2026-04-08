import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/models/group_info_api_models.dart';
import '../../../../core/network/dio_client.dart';

class GroupMetadataApiService {
  GroupMetadataApiService(this._dio);

  final Dio _dio;

  Future<GroupInfoResponseDto> fetchGroupMetadata(String chatId) async {
    final response = await _dio.get<Map<String, dynamic>>('/group/$chatId');
    return GroupInfoResponseDto.fromJson(response.data!);
  }

  Future<GroupInfoResponseDto> updateGroupMetadata(
    String chatId, {
    String? name,
    String? description,
    int? avatarImageId,
    String? visibility,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/group/$chatId',
      data: UpdateGroupRequestDto(
        name: name,
        description: description,
        avatarImageId: avatarImageId,
        visibility: visibility,
      ).toJson(),
    );
    return GroupInfoResponseDto.fromJson(response.data!);
  }
}

final groupMetadataApiServiceProvider = Provider<GroupMetadataApiService>((
  ref,
) {
  return GroupMetadataApiService(ref.watch(dioProvider));
});
