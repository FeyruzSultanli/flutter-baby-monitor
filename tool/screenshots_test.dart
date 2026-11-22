// ignore_for_file: invalid_use_of_visible_for_testing_member
// Renders every v2 screen with the real font into build/screens/*.png for
// design checks against design/mockups (and store screenshots, phase 4):
//
//   flutter test tool/screenshots_test.dart [--dart-define=SHOT_LOCALE=en]
//
// Uses MonitorController.debugDemo (no camera, no network).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bebek_monitor_clean/app_keys.dart';
import 'package:bebek_monitor_clean/core/alert_history_service.dart';
import 'package:bebek_monitor_clean/models/alert_model.dart';
import 'package:bebek_monitor_clean/features/monitor/monitor_controller.dart';
import 'package:bebek_monitor_clean/l10n/app_localizations.dart';
import 'package:bebek_monitor_clean/providers/language_provider.dart';
import 'package:bebek_monitor_clean/providers/theme_provider.dart';
import 'package:bebek_monitor_clean/screens/v2/alert_history_v2_screen.dart';
import 'package:bebek_monitor_clean/screens/v2/lullaby_sheet.dart';
import 'package:bebek_monitor_clean/theme/components/layout.dart';
import 'package:bebek_monitor_clean/theme/tokens.dart';
import 'package:bebek_monitor_clean/screens/v2/monitor_shell.dart';
import 'package:bebek_monitor_clean/screens/v2/onboarding_screen.dart';
import 'package:bebek_monitor_clean/screens/v2/settings_screen.dart';
import 'package:bebek_monitor_clean/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/plugin_mocks.dart';

const String _locale = String.fromEnvironment('SHOT_LOCALE', defaultValue: 'tr');
final double _w = double.tryParse(const String.fromEnvironment('SHOT_W')) ?? 390;
final double _h = double.tryParse(const String.fromEnvironment('SHOT_H')) ?? 844;
final double _textScale = double.tryParse(const String.fromEnvironment('SHOT_TEXT')) ?? 1.0;
// 3 with 430x932 gives App Store 6.7" (1290x2796).
final double _ratio = double.tryParse(const String.fromEnvironment('SHOT_RATIO')) ?? 2.0;

Future<void> _loadFonts() async {
  final family = FontLoader('PlusJakartaSans');
  for (final w in ['Light', 'Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    family.addFont(File('assets/fonts/PlusJakartaSans-$w.ttf').readAsBytes().then((b) => b.buffer.asByteData()));
  }
  await family.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter';
  final icons = FontLoader('MaterialIcons')
    ..addFont(File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
        .readAsBytes()
        .then((b) => b.buffer.asByteData()));
  await icons.load();
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 600));
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shotBoundary')));
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _ratio);
    return image.toByteData(format: ui.ImageByteFormat.png);
  });
  final suffix = _textScale != 1.0 ? '_x$_textScale' : '';
  final file = File('build/screens/${_locale}_${_w.toInt()}$suffix/$name.png')..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('screens', (tester) async {
    SharedPreferences.setMockInitialValues({'onboardingDone': true});
    mockMonitorPlugins();
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = Size(_w, _h);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = MonitorController(locale: () => const Locale(_locale));
    final language = LanguageProvider()..setLocale(const Locale(_locale));
    Widget app(Widget home, {ThemeMode mode = ThemeMode.light}) => MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider.value(value: language),
            ChangeNotifierProvider.value(value: controller),
          ],
          child: RepaintBoundary(
            key: const Key('shotBoundary'),
            child: MediaQuery(
              data: MediaQueryData(
                size: Size(_w, _h),
                padding: const EdgeInsets.only(top: 47, bottom: 34),
                viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
                textScaler: TextScaler.linear(_textScale),
                disableAnimations: true,
              ),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                navigatorKey: rootNavigatorKey,
                scaffoldMessengerKey: rootMessengerKey,
                themeMode: mode,
                theme: NinniTheme.light,
                darkTheme: NinniTheme.night,
                locale: const Locale(_locale),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MonitorOverlays(child: child!),
                home: home,
              ),
            ),
          ),
        );

    Future<void> scene(DemoScene s, String name) async {
      controller.debugDemo(s);
      await tester.pumpWidget(app(const MonitorShell()));
      await tester.pump();
      await _shot(tester, name);
    }

    await tester.pumpWidget(app(OnboardingScreen(onDone: () {})));
    await tester.pump();
    await _shot(tester, '01_onboard1');
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pump(const Duration(seconds: 1));
    await _shot(tester, '02_onboard2');
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pump(const Duration(seconds: 1));
    await _shot(tester, '03_onboard3');

    await scene(DemoScene.roleSelect, '04_role_select');
    await scene(DemoScene.babyPairing, '05_baby_pairing');
    await scene(DemoScene.babyLive, '06_baby_live');
    await scene(DemoScene.babyNight, '07_baby_night');
    await scene(DemoScene.parentJoin, '08_parent_join');
    await scene(DemoScene.parentLive, '09_parent_live');
    await scene(DemoScene.cryAlert, '10_cry_alert');
    await scene(DemoScene.connectionLost, '11_connection_lost');

    controller.debugDemo(DemoScene.parentLive);
    await tester.pumpWidget(app(Scaffold(
      backgroundColor: const Color(0xFF0B0C1C),
      body: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: NinniColors.night800,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          child: const NightTheme(child: LullabySheet()),
        ),
      ),
    )));
    await tester.pump();
    await _shot(tester, '15_lullaby');

    final history = await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('ninni_shots');
      final service = AlertHistoryService.withDirectory(() async => dir);
      final now = DateTime.now();
      final night = now.hour >= 18 ? DateTime(now.year, now.month, now.day) : DateTime(now.year, now.month, now.day - 1);
      for (final (h, m, db, s) in [(23, 48, 66.0, 2), (25, 12, 69.0, 200), (26, 14, 74.0, 6)]) {
        await service.addAlert(AlertModel(
          timestamp: night.add(Duration(hours: h, minutes: m)),
          message: 'cry',
          decibel: db,
          durationSeconds: s,
        ));
      }
      return service;
    });
    await tester.pumpWidget(app(AlertHistoryV2Screen(service: history)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await _shot(tester, '12_history');
    await tester.pumpWidget(app(const SettingsScreen()));
    await tester.pump();
    await _shot(tester, '13_settings');
    await tester.pumpWidget(app(const SettingsScreen(), mode: ThemeMode.dark));
    await tester.pump();
    await _shot(tester, '14_settings_dark');

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
