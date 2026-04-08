class ChatMetadata {
  const ChatMetadata({
    required this.id,
    required this.name,
    this.description,
    this.avatarUrl,
    this.avatarImageId,
    this.visibility = 'public',
    this.createdAt,
    this.mutedUntil,
    this.myRole,
  });

  final String id;
  final String name;
  final String? description;
  final String? avatarUrl;
  final String? avatarImageId;
  final String visibility;
  final DateTime? createdAt;
  final DateTime? mutedUntil;
  final String? myRole;

  String get displayName {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'Chat $id' : trimmed;
  }

  ChatMetadata copyWith({
    String? id,
    String? name,
    Object? description = _sentinel,
    Object? avatarUrl = _sentinel,
    Object? avatarImageId = _sentinel,
    String? visibility,
    Object? createdAt = _sentinel,
    Object? mutedUntil = _sentinel,
    Object? myRole = _sentinel,
  }) {
    return ChatMetadata(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description == _sentinel
          ? this.description
          : description as String?,
      avatarUrl: avatarUrl == _sentinel ? this.avatarUrl : avatarUrl as String?,
      avatarImageId: avatarImageId == _sentinel
          ? this.avatarImageId
          : avatarImageId as String?,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt == _sentinel
          ? this.createdAt
          : createdAt as DateTime?,
      mutedUntil: mutedUntil == _sentinel
          ? this.mutedUntil
          : mutedUntil as DateTime?,
      myRole: myRole == _sentinel ? this.myRole : myRole as String?,
    );
  }
}

const _sentinel = Object();
