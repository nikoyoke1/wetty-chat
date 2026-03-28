import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/network/api_config.dart';

class GroupMember {
  const GroupMember({
    required this.uid,
    this.username,
    required this.role,
    required this.joinedAt,
  });

  final int uid;
  final String? username;
  final String role;
  final String joinedAt;

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      uid: json['uid'] as int? ?? 0,
      username: json['username'] as String?,
      role: json['role'] as String? ?? 'member',
      joinedAt: json['joined_at'] as String? ?? '',
    );
  }
}

class GroupMemberService {
  Future<List<GroupMember>> fetchMembers(String chatId) async {
    final uri = Uri.parse('$apiBaseUrl/group/$chatId/members');
    final response = await http.get(uri, headers: apiHeaders);
    if (response.statusCode != 200) {
      throw Exception('Failed to load members: ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    final list = body is List ? body : (body['members'] as List<dynamic>? ?? []);
    return list
        .map((entry) => GroupMember.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
  }
}
