import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wetty_chat_flutter/app/app.dart';
import 'package:wetty_chat_flutter/core/providers/http_client_provider.dart';
import 'package:wetty_chat_flutter/core/providers/shared_preferences_provider.dart';

void main() {
  testWidgets('WettyChatApp builds a CupertinoApp.router shell', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          httpClientProvider.overrideWithValue(
            MockClient((request) async => http.Response('unauthorized', 401)),
          ),
        ],
        child: const WettyChatApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoApp), findsOneWidget);
  });
}
