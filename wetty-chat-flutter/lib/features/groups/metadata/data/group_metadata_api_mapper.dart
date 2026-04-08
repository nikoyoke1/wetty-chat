import '../../../../core/api/models/group_info_api_models.dart';
import 'group_metadata_models.dart';

extension GroupInfoResponseDtoMapper on GroupInfoResponseDto {
  ChatMetadata toDomain() => ChatMetadata(
    id: id.toString(),
    name: name,
    description: description,
    avatarUrl: avatar,
    avatarImageId: avatarImageId?.toString(),
    visibility: visibility,
    createdAt: createdAt,
    mutedUntil: mutedUntil,
    myRole: myRole,
  );
}
