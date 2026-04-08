import '../../../../core/api/models/group_members_api_models.dart';
import 'group_member_models.dart';

extension GroupMemberDtoMapper on GroupMemberDto {
  GroupMember toDomain() => GroupMember(
    uid: uid,
    username: username,
    avatarUrl: avatarUrl,
    role: role,
    joinedAt: joinedAt,
  );
}
