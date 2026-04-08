class GroupMember {
  const GroupMember({
    required this.uid,
    this.username,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
  });

  final int uid;
  final String? username;
  final String? avatarUrl;
  final String role;
  final DateTime? joinedAt;
}

enum GroupMemberSearchMode { autocomplete, submitted }

extension GroupMemberSearchModeWireValue on GroupMemberSearchMode {
  String get wireValue => switch (this) {
    GroupMemberSearchMode.autocomplete => 'autocomplete',
    GroupMemberSearchMode.submitted => 'submitted',
  };
}

class GroupMembersPage {
  const GroupMembersPage({
    required this.members,
    required this.canManageMembers,
    this.nextCursor,
  });

  final List<GroupMember> members;
  final bool canManageMembers;
  final int? nextCursor;
}
