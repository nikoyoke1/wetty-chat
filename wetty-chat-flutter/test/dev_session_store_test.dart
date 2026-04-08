import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wetty_chat_flutter/core/providers/http_client_provider.dart';
import 'package:wetty_chat_flutter/core/providers/shared_preferences_provider.dart';
import 'package:wetty_chat_flutter/core/session/dev_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        httpClientProvider.overrideWithValue(
          MockClient((request) async => http.Response('unauthorized', 401)),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  test(
    'defaults to uid 1 while bootstrapping when no preference is stored',
    () {
      final session = container.read(authSessionProvider);
      expect(session.developerUserId, AuthSessionNotifier.defaultUserId);
      expect(session.currentUserId, AuthSessionNotifier.defaultUserId);
      expect(session.status, AuthBootstrapStatus.bootstrapping);
    },
  );

  test('persists the selected developer uid', () async {
    await container.read(authSessionProvider.notifier).setCurrentUserId(42);

    final session = container.read(authSessionProvider);
    expect(session.developerUserId, 42);
    expect(session.currentUserId, 42);
  });

  test('loginWithJwt stores jwt session and current user id', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/users/auth-token')) {
        expect(request.headers['authorization'], 'Bearer test-token');
        return http.Response('{"token":"server-token"}', 200);
      }
      if (request.url.path.endsWith('/users/me')) {
        expect(request.headers['authorization'], 'Bearer server-token');
        return http.Response('{"uid":7}', 200);
      }
      return http.Response('not found', 404);
    });
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        httpClientProvider.overrideWithValue(client),
      ],
    );

    await container
        .read(authSessionProvider.notifier)
        .loginWithJwt('test-token');

    final session = container.read(authSessionProvider);
    expect(session.mode, AuthSessionMode.jwt);
    expect(session.currentUserId, 7);
    expect(session.jwtToken, 'server-token');
  });

  test('bootstrap falls back to dev header mode when jwt is absent', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/users/auth-token')) {
        expect(request.headers['x-user-id'], '1');
        expect(request.headers['x-client-id'], '1');
        return http.Response('{"token":"dev-token"}', 200);
      }
      return http.Response('not found', 404);
    });
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        httpClientProvider.overrideWithValue(client),
      ],
    );

    await container.read(authSessionProvider.notifier).bootstrap();

    final session = container.read(authSessionProvider);
    expect(session.mode, AuthSessionMode.devHeader);
    expect(session.status, AuthBootstrapStatus.authenticated);
    expect(session.currentUserId, AuthSessionNotifier.defaultUserId);
    expect(session.jwtToken, isNull);
  });

  test('clearJwt re-runs bootstrap and becomes unauthenticated when dev probe fails', () async {
    SharedPreferences.setMockInitialValues({
      'auth_session_jwt_token': 'persisted-token',
    });
    final prefs = await SharedPreferences.getInstance();
    final requests = <Uri>[];
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        httpClientProvider.overrideWithValue(
          MockClient((request) async {
            requests.add(request.url);
            return http.Response('unauthorized', 401);
          }),
        ),
      ],
    );

    await container.read(authSessionProvider.notifier).clearJwt();

    final session = container.read(authSessionProvider);
    expect(session.status, AuthBootstrapStatus.unauthenticated);
    expect(session.mode, AuthSessionMode.none);
    expect(session.jwtToken, isNull);
    expect(requests.where((uri) => uri.path.endsWith('/users/auth-token')).length, 1);
  });

  test('bootstrap falls back to unauthenticated when request throws', () async {
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        httpClientProvider.overrideWithValue(
          MockClient((request) async {
            throw Exception('network failed');
          }),
        ),
      ],
    );

    await container.read(authSessionProvider.notifier).bootstrap();

    final session = container.read(authSessionProvider);
    expect(session.status, AuthBootstrapStatus.unauthenticated);
    expect(session.mode, AuthSessionMode.none);
  });

  test('bootstrap can run again after a previous bootstrap completed', () async {
    var devProbeCount = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/users/auth-token')) {
        devProbeCount++;
        return http.Response('unauthorized', 401);
      }
      return http.Response('not found', 404);
    });
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        httpClientProvider.overrideWithValue(client),
      ],
    );

    await container.read(authSessionProvider.notifier).bootstrap();
    await container.read(authSessionProvider.notifier).bootstrap();

    expect(devProbeCount, 2);
  });
}
