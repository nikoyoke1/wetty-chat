import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../core/network/api_config.dart';
import '../core/session/dev_session_store.dart';
import '../core/settings/app_settings_store.dart';
import 'routing/app_router.dart';
import 'theme/style_config.dart';

class WettyChatApp extends ConsumerWidget {
  const WettyChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final locale = settings.language.toLocale();
    final router = ref.watch(appRouterProvider);
    final session = ref.watch(authSessionProvider);

    // Keep ApiSession bridge in sync for deep presentation-layer code.
    ApiSession.updateSession(
      userId: session.currentUserId,
      authHeaders: session.authHeaders,
    );

    return CupertinoApp.router(
      theme: appCupertinoTheme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
