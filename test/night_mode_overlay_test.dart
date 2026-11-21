import 'package:bebek_monitor_clean/core/enums/connection_status.dart';
import 'package:bebek_monitor_clean/l10n/app_localizations.dart';
import 'package:bebek_monitor_clean/widgets/night_mode_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

String _tr(String key) => AppLocalizations.debugLocalizedValues['tr']![key]!;

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('tr')],
      home: home,
    );

void main() {
  testWidgets('shows the exit hint, then fades it out', (tester) async {
    await tester.pumpWidget(_app(Scaffold(
      body: NightModeOverlay(status: ConnectionStatus.CONNECTED, onExit: () {}),
    )));
    await tester.pump(); // load localizations
    expect(find.text(_tr('nightModeExitHint')), findsOneWidget);
    AnimatedOpacity hint() => tester.widget(find.byType(AnimatedOpacity));
    expect(hint().opacity, greaterThan(0));

    await tester.pump(const Duration(seconds: 5));
    expect(hint().opacity, 0);

    // A single tap brings the hint back
    await tester.tap(find.byKey(const Key('nightModeOverlay')));
    await tester.pump(const Duration(milliseconds: 400)); // past the double-tap window
    expect(hint().opacity, greaterThan(0));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('double tap exits', (tester) async {
    var exits = 0;
    await tester.pumpWidget(_app(Scaffold(
      body: NightModeOverlay(status: ConnectionStatus.CONNECTING, onExit: () => exits++),
    )));
    await tester.pump(); // load localizations
    final overlay = find.byKey(const Key('nightModeOverlay'));
    await tester.tap(overlay);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(overlay);
    await tester.pumpAndSettle();
    expect(exits, 1);
  });

  testWidgets('back button exits night mode instead of popping the route', (tester) async {
    var exits = 0;
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: NightModeOverlay(
                  status: ConnectionStatus.CONNECTED,
                  onExit: () => exits++,
                ),
              ),
            )),
            child: const Text('open'),
          ),
        ),
      ),
    )));
    await tester.pump(); // load localizations
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled, isTrue);
    expect(exits, 1);
    expect(find.byType(NightModeOverlay), findsOneWidget); // route not popped
    await tester.pump(const Duration(seconds: 5));
  });
}
