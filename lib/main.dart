import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart'; // <-- Oluşturulan ayar dosyasını import ettik
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'app.dart';
import 'core/services/hybrid_notification_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase başlatma işlemini korumalı (guard) yapıyoruz.
  // Eğer config dosyaları eksikse uygulama çökmez, sadece bağlantı özellikleri çalışmaz.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform, // <-- Bu satır kritik: Platform ayarlarını otomatik seçer
    );
    await HybridNotificationManager().initialize();
  } catch (e, st) {
    debugPrint('Firebase init failed: $e\n$st');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const BebekMonitorApp(),
    ),
  );
}