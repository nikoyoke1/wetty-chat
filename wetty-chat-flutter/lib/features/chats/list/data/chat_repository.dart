import 'package:flutter/foundation.dart';
import 'dart:convert';

import '../../../../core/network/api_config.dart';
import '../../shared/models/chat_models.dart';
import '../../shared/models/message_models.dart';
import 'chat_service.dart';

/// Source of truth for chat list data.
/// Manages pagination and caching.
class ChatRepository extends ChangeNotifier {
  final ChatService _service;

  ChatRepository({ChatService? service}) : _service = service ?? ChatService();

  List<ChatListItem> _chats = [];
  String? _nextCursor;

  List<ChatListItem> get chats => _chats;
  String? get nextCursor => _nextCursor;
  bool get hasMore => _nextCursor != null && _nextCursor!.isNotEmpty;

  /// Load the first page of chats.
  Future<void> loadChats({int limit = 11}) async {
    final res = await _service.fetchChats(limit: limit);
    _chats = res.chats;
    _nextCursor = res.nextCursor;
    notifyListeners();
  }

  /// Load more chats (next page).
  Future<void> loadMoreChats({int limit = 11}) async {
    if (!hasMore || _chats.isEmpty) return;
    final lastId = _chats.last.id;
    final res = await _service.fetchChats(limit: limit, after: lastId);
    final existingIds = _chats.map((c) => c.id).toSet();
    final newChats =
        res.chats.where((c) => !existingIds.contains(c.id)).toList();
    _chats = [..._chats, ...newChats];
    _nextCursor = res.nextCursor;
    notifyListeners();
  }

  /// Insert a newly created chat at the top.
  void insertChat(ChatListItem chat) {
    _chats.insert(0, chat);
    notifyListeners();
  }

  /// Create a new chat via the service.
  /// Returns the new ChatListItem on success, null on failure.
  Future<ChatListItem?> createChat({String? name}) async {
    final response = await _service.createChat(name: name);
    if (response.statusCode == 201) {
      final body =
          jsonDecode(response.body) as Map<String, dynamic>;
      final id = body['id']?.toString() ?? '';
      final createdName = body['name'] as String?;
      return ChatListItem(id: id, name: createdName);
    }
    throw Exception('Server error: ${response.body}');
  }

  void applyRealtimeEvent(Map<String, dynamic> event) {
    final type = event['type'];
    final payload = event['payload'];
    if (payload is! Map<String, dynamic>) return;

    final chatId = payload['chat_id']?.toString() ?? '';
    final index = _chats.indexWhere((chat) => chat.id == chatId);
    if (index < 0) return;

    final previous = _chats[index];
    final message = MessageItem.fromJson(payload);
    if (type == 'message') {
      final senderUid = payload['sender']?['uid'] as int?;
      final createdAt = payload['created_at'] as String?;
      final updated = previous.copyWith(
        lastMessage: message,
        lastMessageAt: createdAt,
        unreadCount: senderUid != ApiSession.currentUserId
            ? previous.unreadCount + 1
            : previous.unreadCount,
      );
      _chats
        ..removeAt(index)
        ..insert(0, updated);
      notifyListeners();
      return;
    }

    if (type == 'message_updated' || type == 'message_deleted') {
      if (previous.lastMessage?.id != message.id) return;
      _chats[index] = previous.copyWith(lastMessage: message);
      notifyListeners();
    }
  }
}
