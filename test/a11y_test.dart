// V2 phase 4: accessibility guidelines on the main screens (tap target
// sizes, labelled buttons, text contrast) with demo states.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:bebek_monitor_clean/app_keys.dart';
import 'package:bebek_monitor_clean/features/monitor/monitor_controller.dart';
import 'package:bebek_monitor_clean/l10n/app_localizations.dart';
import 'package:bebek_monitor_clean/providers/language_provider.dart';
import 'package:bebek_monitor_clean/providers/theme_provider.dart';
import 'package:bebek_monitor_clean/screens/v2/monitor_shell.dart';
import 'package:bebek_monitor_clean/screens/v2/settings_screen.dart';
import 'package:bebek_monitor_clean/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/plugin_mocks.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'onboardingDone': true});
    mockMonitorPlugins();
  });

  Future<MonitorController> pumpScene(WidgetTester tester, Widget home, DemoScene scene) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final controller = MonitorController(locale: () => const Locale('tr'))..debugDemo(scene);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider.value(value: controller),
      ],
      child: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844), devicePixelRatio: 3, disableAnimations: true),
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          scaffoldMessengerKey: rootMessengerKey,
          theme: NinniTheme.light,
          darkTheme: NinniTheme.night,
          locale: const Locale('tr'),
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
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return controller;
  }

  final scenes = <(String, Widget, DemoScene)>[
    ('role select', const MonitorShell(), DemoScene.roleSelect),
    ('baby pairing', const MonitorShell(), DemoScene.babyPairing),
    ('baby live', const MonitorShell(), DemoScene.babyLive),
    ('baby night', const MonitorShell(), DemoScene.babyNight),
    ('parent join', const MonitorShell(), DemoScene.parentJoin),
    ('parent live', const MonitorShell(), DemoScene.parentLive),
    ('cry alarm', const MonitorShell(), DemoScene.cryAlert),
    ('connection lost', const MonitorShell(), DemoScene.connectionLost),
    ('settings', const SettingsScreen(), DemoScene.parentLive),
  ];

  for (final (name, home, scene) in scenes) {
    testWidgets('$name meets tap target and label guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = await pumpScene(tester, home, scene);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
}
