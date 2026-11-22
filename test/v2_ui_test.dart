import 'package:bebek_monitor_clean/features/monitor/monitor_controller.dart';
import 'package:bebek_monitor_clean/l10n/app_localizations.dart';
import 'package:bebek_monitor_clean/providers/language_provider.dart';
import 'package:bebek_monitor_clean/providers/theme_provider.dart';
import 'package:bebek_monitor_clean/screens/v2/baby_night_view.dart';
import 'package:bebek_monitor_clean/screens/v2/settings_screen.dart';
import 'package:bebek_monitor_clean/theme/app_theme.dart';
import 'package:bebek_monitor_clean/theme/components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/plugin_mocks.dart';

String _tr(String key) => AppLocalizations.debugLocalizedValues['tr']![key]!;
String _en(String key) => AppLocalizations.debugLocalizedValues['en']![key]!;

Widget _app(Widget home, {Locale locale = const Locale('tr'), ThemeData? theme}) => MaterialApp(
      locale: locale,
      theme: theme ?? NinniTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockMonitorPlugins();
  });

  group('BabyNightView', () {
    testWidgets('shows the broadcast state and exits on double tap', (tester) async {
      var exits = 0;
      await tester.pumpWidget(_app(Scaffold(
        body: BabyNightView(parentConnected: true, onExit: () => exits++),
      )));
      await tester.pump();
      await tester.pump();
      expect(find.text(_tr('nightStatusConnected')), findsOneWidget);
      expect(find.text(_tr('nightExitHint')), findsOneWidget);
      final overlay = find.byKey(const Key('nightModeOverlay'));
      await tester.tap(overlay);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(overlay);
      await tester.pump(const Duration(milliseconds: 400));
      expect(exits, 1);
    });

    testWidgets('back exits night mode instead of popping', (tester) async {
      var exits = 0;
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => Scaffold(body: BabyNightView(parentConnected: false, onExit: () => exits++)),
              )),
              child: const Text('open'),
            ),
          ),
        ),
      )));
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(_tr('nightStatusWaiting')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(exits, 1);
      expect(find.byType(BabyNightView), findsOneWidget);
    });
  });

  group('CodeBoxes', () {
    testWidgets('upper-cases input, drops look-alikes and stops at 8', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_app(Scaffold(
        body: Center(child: CodeBoxes.input(controller: controller, fieldKey: const Key('field'))),
      )));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('field')), 'k7mq-0t2h9zz');
      await tester.pump();
      expect(controller.text, 'K7MQT2H9');
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('display mode shows the formatted code to screen readers', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: Center(child: CodeBoxes.display(code: 'K7MQT2H9')))));
      await tester.pump();
      expect(find.text('K'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('K 7 M Q - T 2 H 9')), findsOneWidget);
    });

    testWidgets('fits a 320 pt wide screen (iPhone SE) without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = TextEditingController(text: 'K7MQT2H9');
      await tester.pumpWidget(_app(Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [CodeBoxes.input(controller: controller), const CodeBoxes.display(code: 'K7MQT2H9')]),
        ),
      )));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('NinniButton calls back and is disabled without a handler', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(Scaffold(
      body: Column(children: [
        NinniButton(label: 'Bağlan', onPressed: () => taps++),
        const NinniButton(label: 'Kapalı', onPressed: null),
      ]),
    )));
    await tester.pump();
    await tester.tap(find.text('Bağlan'));
    await tester.tap(find.text('Kapalı'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(taps, 1);
  });

  testWidgets('SettingsScreen renders in Turkish and switches to English', (tester) async {
    final controller = MonitorController(locale: () => const Locale('tr'));
    final language = LanguageProvider();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: language),
        ChangeNotifierProvider.value(value: controller),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, lang, _) => _app(const SettingsScreen(), locale: lang.locale),
      ),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text(_tr('sensitivity')), findsOneWidget);
    expect(find.byKey(const Key('thresholdSlider')), findsOneWidget);
    await tester.dragUntilVisible(
        find.byKey(const Key('languageRow')), find.byType(ListView), const Offset(0, -200));
    await tester.tap(find.byKey(const Key('languageRow')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text(_en('language')), findsOneWidget);
    expect(find.text(_en('sectionApp').toUpperCase()), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
