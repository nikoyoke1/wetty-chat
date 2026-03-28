import '../../features/auth/application/auth_store.dart';

const String apiBaseUrl = 'http://10.42.3.100:3000';

class ApiSession {
  const ApiSession._();

  static int? get currentUserId => AuthStore.instance.currentUserId;
  static String? get token => AuthStore.instance.token;
}

Map<String, String> get apiHeaders {
  final headers = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  final token = ApiSession.token;
  if (token != null) {
    headers['Authorization'] = 'Bearer $token';
  }

  final uid = ApiSession.currentUserId;
  if (uid != null) {
    headers['X-User-Id'] = uid.toString();
  }

  return headers;
}
