import 'package:flutter/foundation.dart';

import '../data/group_member_service.dart';

class GroupMembersViewModel extends ChangeNotifier {
  GroupMembersViewModel({
    required this.chatId,
    GroupMemberService? service,
  }) : _service = service ?? GroupMemberService();

  final String chatId;
  final GroupMemberService _service;

  List<GroupMember> _members = const [];
  List<GroupMember> get members => _members;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadMembers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _members = await _service.fetchMembers(chatId);
      _error = null;
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
