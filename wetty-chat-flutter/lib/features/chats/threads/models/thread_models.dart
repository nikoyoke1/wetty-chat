import '../../models/message_models.dart';

class ThreadParticipant {
  const ThreadParticipant({required this.uid, this.name, this.avatarUrl});

  final int uid;
  final String? name;
  final String? avatarUrl;
}

class ThreadReplyPreview {
  const ThreadReplyPreview({
    required this.sender,
    this.message,
    this.messageType = 'text',
    this.stickerEmoji,
    this.firstAttachmentKind,
    this.isDeleted = false,
    this.mentions = const <MentionInfo>[],
  });

  final ThreadParticipant sender;
  final String? message;
  final String messageType;
  final String? stickerEmoji;
  final String? firstAttachmentKind;
  final bool isDeleted;
  final List<MentionInfo> mentions;
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
}
