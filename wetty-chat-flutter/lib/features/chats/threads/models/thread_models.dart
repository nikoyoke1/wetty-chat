import '../../models/message_models.dart';

class ThreadParticipant {
  const ThreadParticipant({required this.uid, this.name, this.avatarUrl});

  final int uid;
  final String? name;
  final String? avatarUrl;
}

class ThreadReplyPreview {
  const ThreadReplyPreview({
    this.messageId,
    this.clientGeneratedId,
    required this.sender,
    this.message,
    this.messageType = 'text',
    this.stickerEmoji,
    this.firstAttachmentKind,
    this.isDeleted = false,
    this.mentions = const <MentionInfo>[],
  });

  final int? messageId;
  final String? clientGeneratedId;
  final ThreadParticipant sender;
  final String? message;
  final String messageType;
  final String? stickerEmoji;
  final String? firstAttachmentKind;
  final bool isDeleted;
  final List<MentionInfo> mentions;

  ThreadReplyPreview copyWith({
    Object? messageId = _sentinel,
    Object? clientGeneratedId = _sentinel,
    ThreadParticipant? sender,
    Object? message = _sentinel,
    String? messageType,
    Object? stickerEmoji = _sentinel,
    Object? firstAttachmentKind = _sentinel,
    bool? isDeleted,
    List<MentionInfo>? mentions,
  }) {
    return ThreadReplyPreview(
      messageId: messageId == _sentinel ? this.messageId : messageId as int?,
      clientGeneratedId: clientGeneratedId == _sentinel
          ? this.clientGeneratedId
          : clientGeneratedId as String?,
      sender: sender ?? this.sender,
      message: message == _sentinel ? this.message : message as String?,
      messageType: messageType ?? this.messageType,
      stickerEmoji: stickerEmoji == _sentinel
          ? this.stickerEmoji
          : stickerEmoji as String?,
      firstAttachmentKind: firstAttachmentKind == _sentinel
          ? this.firstAttachmentKind
          : firstAttachmentKind as String?,
      isDeleted: isDeleted ?? this.isDeleted,
      mentions: mentions ?? this.mentions,
    );
  }
}

class ThreadListItem {
  const ThreadListItem({
    required this.chatId,
    required this.chatName,
    this.chatAvatar,
    required this.threadRootMessage,
    this.participants = const <ThreadParticipant>[],
    this.lastReply,
    this.replyCount = 0,
    this.lastReplyAt,
    this.unreadCount = 0,
    this.subscribedAt,
  });

  final String chatId;
  final String chatName;
  final String? chatAvatar;
  final MessageItem threadRootMessage;
  final List<ThreadParticipant> participants;
  final ThreadReplyPreview? lastReply;
  final int replyCount;
  final DateTime? lastReplyAt;
  final int unreadCount;
  final DateTime? subscribedAt;

  /// Thread root message ID used as the unique key for this thread.
  int get threadRootId => threadRootMessage.id;

  ThreadListItem copyWith({
    String? chatId,
    String? chatName,
    Object? chatAvatar = _sentinel,
    MessageItem? threadRootMessage,
    List<ThreadParticipant>? participants,
    Object? lastReply = _sentinel,
    int? replyCount,
    Object? lastReplyAt = _sentinel,
    int? unreadCount,
    Object? subscribedAt = _sentinel,
  }) {
    return ThreadListItem(
      chatId: chatId ?? this.chatId,
      chatName: chatName ?? this.chatName,
      chatAvatar: chatAvatar == _sentinel
          ? this.chatAvatar
          : chatAvatar as String?,
      threadRootMessage: threadRootMessage ?? this.threadRootMessage,
      participants: participants ?? this.participants,
      lastReply: lastReply == _sentinel
          ? this.lastReply
          : lastReply as ThreadReplyPreview?,
      replyCount: replyCount ?? this.replyCount,
      lastReplyAt: lastReplyAt == _sentinel
          ? this.lastReplyAt
          : lastReplyAt as DateTime?,
      unreadCount: unreadCount ?? this.unreadCount,
      subscribedAt: subscribedAt == _sentinel
          ? this.subscribedAt
          : subscribedAt as DateTime?,
    );
  }
}

const _sentinel = Object();
