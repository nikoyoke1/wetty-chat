import 'dart:async';

import '../../../../core/network/websocket_service.dart';
import '../data/message_repository.dart';

class MessageRealtimeController {
  MessageRealtimeController(this._repository);

  final MessageRepository _repository;
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
