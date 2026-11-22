import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart'; // <-- Oluşturulan ayar dosyasını import ettik
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'app.dart';
import 'core/services/hybrid_notification_manager.dart';
import 'core/auth/auth_service.dart';
import 'core/firebase/emulator_config.dart';
import 'features/monitor/monitor_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase başlatma işlemini korumalı (guard) yapıyoruz.
  // Eğer config dosyaları eksikse uygulama çökmez, sadece bağlantı özellikleri çalışmaz.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform, // <-- Bu satır kritik: Platform ayarlarını otomatik seçer
    );
    // Debug + --dart-define=USE_FIREBASE_EMULATOR=true only: local emulators.
    await connectToFirebaseEmulatorIfRequested();
    // Sign in early (anonymous, D3) so the first room create/join is fast.
    // Failures are retried when a room is created or joined.
    unawaited(AuthService.instance.ensureSignedIn().then<void>((_) {}, onError: (Object e) {
      debugPrint('Anonymous sign-in failed: $e');
    }));
  } catch (e, st) {
    debugPrint('Firebase init failed: $e\n$st');
  }

  // Local notifications work even if Firebase failed to start (B43).
  try {
    await HybridNotificationManager().initialize();
  } catch (e) {
    debugPrint('Notification init failed: $e');
  }

  final language = LanguageProvider();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: language),
        // All monitoring logic (V2: moved out of the old HomeScreen).
        ChangeNotifierProvider(create: (_) {
          final controller = MonitorController(locale: () => language.locale);
          // Store screenshots: --dart-define=NINNI_DEMO=<scene> (V2 phase 4).
          final demo = DemoScene.fromDefine();
          // ignore: invalid_use_of_visible_for_testing_member
          if (demo != null) controller.debugDemo(demo);
          return controller;
        }),
      ],
      child: const BebekMonitorApp(),
    ),
  );
}