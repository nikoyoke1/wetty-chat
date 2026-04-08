import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_config.dart';
import '../providers/http_client_provider.dart';
import '../providers/shared_preferences_provider.dart';

enum AuthBootstrapStatus { bootstrapping, authenticated, unauthenticated }

enum AuthSessionMode { none, devHeader, jwt }

class AuthSessionState {
  const AuthSessionState({
    required this.status,
    required this.mode,
    required this.developerUserId,
    required this.currentUserId,
    this.jwtToken,
  });

  final AuthBootstrapStatus status;
  final AuthSessionMode mode;
  final int developerUserId;
  final int currentUserId;
  final String? jwtToken;

  bool get isBootstrapping => status == AuthBootstrapStatus.bootstrapping;
  bool get isAuthenticated => status == AuthBootstrapStatus.authenticated;
  bool get hasJwtToken => jwtToken != null && jwtToken!.isNotEmpty;

  Map<String, String> get authHeaders {
    return switch (mode) {
      AuthSessionMode.devHeader => legacyApiAuthHeadersForUser(currentUserId),
      AuthSessionMode.jwt when hasJwtToken => <String, String>{
        'Authorization': 'Bearer $jwtToken',
      },
      _ => const <String, String>{},
    };
  }

  AuthSessionState copyWith({
    AuthBootstrapStatus? status,
    AuthSessionMode? mode,
    int? developerUserId,
    int? currentUserId,
    String? jwtToken,
    bool clearJwtToken = false,
  }) {
    return AuthSessionState(
      status: status ?? this.status,
      mode: mode ?? this.mode,
      developerUserId: developerUserId ?? this.developerUserId,
      currentUserId: currentUserId ?? this.currentUserId,
      jwtToken: clearJwtToken ? null : (jwtToken ?? this.jwtToken),
    );
  }
}

class AuthSessionNotifier extends Notifier<AuthSessionState> {
  static const int defaultUserId = 1;
  static const String _userIdStorageKey = 'dev_session_user_id';
  static const String _jwtTokenStorageKey = 'auth_session_jwt_token';

  late SharedPreferences _prefs;
  late http.Client _client;
  Future<void>? _bootstrapFuture;

  @override
  AuthSessionState build() {
    _prefs = ref.read(sharedPreferencesProvider);
    _client = ref.read(httpClientProvider);
    final developerUserId = _prefs.getInt(_userIdStorageKey) ?? defaultUserId;
    final jwtToken = _prefs.getString(_jwtTokenStorageKey);
    return AuthSessionState(
      status: AuthBootstrapStatus.bootstrapping,
      mode: AuthSessionMode.none,
      developerUserId: developerUserId,
      currentUserId: developerUserId,
      jwtToken: jwtToken,
    );
  }

  Future<void> bootstrap() {
    final pending = _bootstrapFuture;
    if (pending != null) {
      return pending;
    }

    final future = _runBootstrap();
    late final Future<void> trackedFuture;
    trackedFuture = future.whenComplete(() {
      if (identical(_bootstrapFuture, trackedFuture)) {
        _bootstrapFuture = null;
      }
    });
    _bootstrapFuture = trackedFuture;
    return trackedFuture;
  }

  Future<void> _runBootstrap() async {
    state = state.copyWith(status: AuthBootstrapStatus.bootstrapping);

    final developerUserId = _prefs.getInt(_userIdStorageKey) ?? defaultUserId;

    try {
      final persistedToken = _prefs.getString(_jwtTokenStorageKey);
      if (persistedToken != null && persistedToken.trim().isNotEmpty) {
        final normalizedToken = await _validateJwtToken(persistedToken);
        if (normalizedToken != null) {
          final me = await _fetchMe(<String, String>{
            'Authorization': 'Bearer $normalizedToken',
          });
          if (me != null) {
            await _prefs.setString(_jwtTokenStorageKey, normalizedToken);
            state = AuthSessionState(
              status: AuthBootstrapStatus.authenticated,
              mode: AuthSessionMode.jwt,
              developerUserId: developerUserId,
              currentUserId: me.uid,
              jwtToken: normalizedToken,
            );
            return;
          }
        }
        await _prefs.remove(_jwtTokenStorageKey);
      }

      final devHeaders = legacyApiAuthHeadersForUser(developerUserId);
      final devToken = await _fetchAuthToken(devHeaders);
      if (devToken != null) {
        state = AuthSessionState(
          status: AuthBootstrapStatus.authenticated,
          mode: AuthSessionMode.devHeader,
          developerUserId: developerUserId,
          currentUserId: developerUserId,
          jwtToken: null,
        );
        return;
      }
    } catch (error, stackTrace) {
      debugPrint('[auth:bootstrap] exception during bootstrap: $error');
      debugPrintStack(
        label: '[auth:bootstrap] stack',
        stackTrace: stackTrace,
      );
      await _prefs.remove(_jwtTokenStorageKey);
    }

    state = AuthSessionState(
      status: AuthBootstrapStatus.unauthenticated,
      mode: AuthSessionMode.none,
      developerUserId: developerUserId,
      currentUserId: developerUserId,
      jwtToken: null,
    );
  }

  Future<void> loginWithJwt(String token) async {
    final normalizedInput = token.trim();
    if (normalizedInput.isEmpty) {
      throw Exception('Enter a JWT token.');
    }

    final normalizedToken = await _validateJwtToken(normalizedInput);
    if (normalizedToken == null) {
      throw Exception('Invalid JWT token.');
    }

    final me = await _fetchMe(<String, String>{
      'Authorization': 'Bearer $normalizedToken',
    });
    if (me == null) {
      throw Exception('Failed to load the authenticated user.');
    }

    await _prefs.setString(_jwtTokenStorageKey, normalizedToken);
    state = AuthSessionState(
      status: AuthBootstrapStatus.authenticated,
      mode: AuthSessionMode.jwt,
      developerUserId: state.developerUserId,
      currentUserId: me.uid,
      jwtToken: normalizedToken,
    );
  }

  Future<void> setCurrentUserId(int userId) async {
    await _prefs.setInt(_userIdStorageKey, userId);
    if (state.developerUserId == userId && state.mode == AuthSessionMode.jwt) {
      return;
    }

    if (state.mode == AuthSessionMode.jwt) {
      state = state.copyWith(developerUserId: userId);
      return;
    }

    state = state.copyWith(developerUserId: userId, currentUserId: userId);
  }

  Future<void> clearJwt() async {
    debugPrint('[auth:clear-jwt] clearing stored jwt and re-running bootstrap');
    await _prefs.remove(_jwtTokenStorageKey);
    state = AuthSessionState(
      status: AuthBootstrapStatus.bootstrapping,
      mode: AuthSessionMode.none,
      developerUserId: state.developerUserId,
      currentUserId: state.developerUserId,
      jwtToken: null,
    );
    await bootstrap();
    debugPrint(
      '[auth:clear-jwt] completed with status=${state.status} mode=${state.mode}',
    );
  }

  Future<void> resetToDefault() async {
    await _prefs.remove(_userIdStorageKey);
    await setCurrentUserId(defaultUserId);
  }

  Future<String?> _validateJwtToken(String token) async {
    return _fetchAuthToken(<String, String>{'Authorization': 'Bearer $token'});
  }

  Future<String?> _fetchAuthToken(Map<String, String> authHeaders) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/users/auth-token'),
      headers: apiJsonHeaders(authHeaders),
    );
    if (response.statusCode != 200) {
      return null;
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      return null;
    }

    final token = payload['token'];
    if (token is! String || token.trim().isEmpty) {
      return null;
    }

    return token.trim();
  }

  Future<_MeResponse?> _fetchMe(Map<String, String> authHeaders) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/users/me'),
      headers: apiJsonHeaders(authHeaders),
    );
    if (response.statusCode != 200) {
      return null;
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      return null;
    }

    final uid = payload['uid'];
    if (uid is! int || uid <= 0) {
      return null;
    }

    return _MeResponse(uid);
  }
}

class _MeResponse {
  const _MeResponse(this.uid);

  final int uid;
}

final authSessionProvider =
    NotifierProvider<AuthSessionNotifier, AuthSessionState>(
      AuthSessionNotifier.new,
    );

final devSessionProvider = Provider<int>((ref) {
  return ref.watch(authSessionProvider).currentUserId;
});

final authHeadersProvider = Provider<Map<String, String>>((ref) {
  final session = ref.watch(authSessionProvider);
  return apiJsonHeaders(session.authHeaders);
});
