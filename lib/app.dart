import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_keys.dart';
import 'l10n/app_localizations.dart';
import 'providers/language_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/v2/monitor_shell.dart';
import 'theme/app_theme.dart';

class BebekMonitorApp extends StatelessWidget {
  const BebekMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();

    return MaterialApp(
      title: 'Ninni',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootMessengerKey,
      themeMode: themeProvider.mode,
      theme: NinniTheme.light,
      darkTheme: NinniTheme.night,
      locale: languageProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // Parent alarms (cry, connection lost) cover every route.
      builder: (context, child) => MonitorOverlays(child: child ?? const SizedBox.shrink()),
      home: const AppRoot(),
    );
  }
}
