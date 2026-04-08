import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/dev_session_store.dart';
import 'api_config.dart';

/// Interceptor that attaches auth headers from the current session state.
///
/// Reads auth headers from the [Ref] on every request so it always
/// reflects the latest session (JWT or legacy dev-header).
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._ref);

  final Ref _ref;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final session = _ref.read(authSessionProvider);
    options.headers.addAll(session.authHeaders);
    handler.next(options);
  }
}

/// Interceptor that logs requests and responses in debug mode.
class DebugLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[dio] → ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('[dio] ← ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '[dio] ✗ ${err.response?.statusCode ?? 'NO_RESPONSE'} '
      '${err.requestOptions.uri} – ${err.message}',
    );
    handler.next(err);
  }
}

/// Provides a configured [Dio] instance with auth and logging interceptors.
///
/// All API services should use this instead of raw `http.Client`.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(ref),
    if (kDebugMode) DebugLogInterceptor(),
  ]);

  ref.onDispose(dio.close);
  return dio;
});
