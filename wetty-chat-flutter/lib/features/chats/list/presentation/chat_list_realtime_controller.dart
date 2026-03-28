import 'dart:async';

import '../../../../core/network/websocket_service.dart';
import '../data/chat_repository.dart';

class ChatListRealtimeController {
  ChatListRealtimeController(this._repository);

  final ChatRepository _repository;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  void start() {
    _subscription ??= WebSocketService.instance.events.listen(
      _repository.applyRealtimeEvent,
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
