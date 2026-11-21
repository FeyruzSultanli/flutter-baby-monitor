// Smoke tests for UI pieces that do not need platform plugins
// (HomeScreen itself needs camera/Firebase/battery plugins and real devices).

import 'package:bebek_monitor_clean/l10n/app_localizations.dart';
import 'package:bebek_monitor_clean/providers/language_provider.dart';
import 'package:bebek_monitor_clean/providers/theme_provider.dart';
import 'package:bebek_monitor_clean/widgets/noise_level_bar.dart';
import 'package:bebek_monitor_clean/widgets/settings_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Same localization/provider setup as BebekMonitorApp, around [child].
Widget _host(Widget child, {LanguageProvider? language, ThemeProvider? theme}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => theme ?? ThemeProvider()),
      ChangeNotifierProvider(create: (_) => language ?? LanguageProvider()),
    ],
    child: Builder(
      builder: (context) => MaterialApp(
        locale: context.watch<LanguageProvider>().locale,
        themeMode: context.watch<ThemeProvider>().mode,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('tr')],
        home: Scaffold(body: child),
      ),
    ),
  );
}

String _tr(String key) => AppLocalizations.debugLocalizedValues['tr']![key]!;
String _en(String key) => AppLocalizations.debugLocalizedValues['en']![key]!;

void main() {
  testWidgets('SettingsSheet renders in Turkish by default and switches to English',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final language = LanguageProvider();
    await tester.pumpWidget(_host(
      SettingsSheet(
        noiseThreshold: 60,
        keepScreenOn: false,
        onNoiseThresholdChanged: (_) {},
        onKeepScreenOnChanged: (_) {},
        onOfflineModeChanged: (_) {},
        onVideoSettingsChanged: (_) {},
      ),
      language: language,
    ));
    await tester.pumpAndSettle();

    expect(find.text(_tr('settings')), findsOneWidget);
    expect(find.text(_tr('keepScreenOn')), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);

    language.setLocale(const Locale('en'));
    await tester.pumpAndSettle();
    expect(find.text(_en('settings')), findsOneWidget);
    expect(find.text(_en('keepScreenOn')), findsOneWidget);
  });

  testWidgets('SettingsSheet keep-screen-on switch reports the new value', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    bool? reported;
    await tester.pumpWidget(_host(
      SettingsSheet(
        noiseThreshold: 60,
        keepScreenOn: false,
        onNoiseThresholdChanged: (_) {},
        onKeepScreenOnChanged: (v) => reported = v,
      ),
    ));
    await tester.pumpAndSettle();

    final tile = find.widgetWithText(SwitchListTile, _tr('keepScreenOn'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(reported, isTrue);
  });

  testWidgets('NoiseLevelBar shows dB while listening and "passive" otherwise',
      (tester) async {
    await tester.pumpWidget(_host(
      const NoiseLevelBar(currentDb: 42.25, thresholdDb: 60, listening: true),
    ));
    await tester.pumpAndSettle();
    expect(find.text('42.3 dB'), findsOneWidget);

    await tester.pumpWidget(_host(
      const NoiseLevelBar(currentDb: 42.25, thresholdDb: 60, listening: false),
    ));
    await tester.pumpAndSettle();
    expect(find.text(_tr('passive')), findsOneWidget);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('SettingsSheet offline option on $platform', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await tester.pumpWidget(_host(
        SettingsSheet(
          noiseThreshold: 60,
          keepScreenOn: false,
          onNoiseThresholdChanged: (_) {},
          onKeepScreenOnChanged: (_) {},
          onOfflineModeChanged: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      final isAndroid = platform == TargetPlatform.android;
      // Android: a real switch. iOS: an explanation, no switch (Nearby is Android only).
      expect(find.widgetWithText(SwitchListTile, _tr('offlineMode')),
          isAndroid ? findsOneWidget : findsNothing);
      expect(find.byKey(const Key('offlineUnavailableTile')),
          isAndroid ? findsNothing : findsOneWidget);
      expect(find.text(_tr('offlineAndroidOnly')), isAndroid ? findsNothing : findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
