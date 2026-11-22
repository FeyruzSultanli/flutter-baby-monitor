# Bebek Monitor (flutter-baby-monitor)

Flutter ile yazılmış gerçek zamanlı bebek monitörü. Bir cihaz **bebek** (kamera + mikrofon yayını, ağlama algılama), diğeri **ebeveyn** (izleme, bildirim alma) rolünde çalışır. İki bağlantı modu var:

- **Online:** WebRTC (görüntü/ses) + Firestore signaling (`rooms` koleksiyonu, oda kodu ile eşleşme) + FCM / yerel bildirimler.
- **Offline:** Google Nearby Connections (`Strategy.P2P_STAR`) üzerinden internet olmadan; WebRTC kullanılmaz, kamera kareleri JPEG olarak, ses ham PCM olarak byte payload ile gönderilir.

Paket adı: `bebek_monitor_clean` (import'lar `package:bebek_monitor_clean/...`). Android applicationId: `com.example.bebek_monitor_clean`.

## Mimari

```
lib/
  main.dart                 Firebase init (try/catch ile korumalı) + HybridNotificationManager + MultiProvider
                            (Theme/Language/MonitorController); --dart-define=NINNI_DEMO=<sahne> demo durumu
  app.dart                  MaterialApp: Ninni temaları (lib/theme), tr/en/az, app_keys (snackbar/diyalog),
                            builder: MonitorOverlays (ağlama alarmı, bağlantı koptu tüm sayfaların üstünde)
  app_keys.dart             rootNavigatorKey / rootMessengerKey
  firebase_options.dart     FlutterFire tarafından üretildi — DEĞİŞTİRME
  features/monitor/
    monitor_controller.dart Uygulamanın asıl mantığı (eski HomeScreen'den taşındı, ChangeNotifier): rol, online/offline,
                            Nearby, kamera, ses, ağlama algılama, kayıt, bekçi, pil, ninni, gece lambası, bas-konuş,
                            demo sahneleri (debugDemo). Ekranlar yalnızca bunu okur.
  screens/v2/               Ninni ekranları: onboarding, role_select, baby_screens (kod + yayında), baby_night_view,
                            parent_screens (kod gir + canlı + tam ekran), alarm_views (ağlama + bağlantı koptu),
                            alert_history_v2, settings, lullaby_sheet, qr_scan, monitor_shell (aşama = stageOf(controller))
  screens/                  video_gallery_screen, video_player_screen, multi_camera_screen (kapalı, A26)
  theme/                    tokens.dart (renk/yazı/ölçü), app_theme.dart (açık + gece, NinniPalette), components/
  core/
    webrtc/                 signaling_interface, firestore_signaling, webrtc_service (tek peer, bas-konuş kanalı),
                            signaling_messages, reconnect_backoff, multi_peer_service
    pairing/                PairingService, PairingState, RoomCode (QR bağlantısı), RecentRoomStore
    monitor/                ConnectionWatchdog (bağlantı koptu), LowBatteryAlert / BabyBattery
    audio/                  audio_level, cry_detector, pcm_microphone, offline_audio, app_audio (alarm sesi),
                            soothe (ninni çalar, eşik düzeltmesi, TalkGate)
    alerts/night_summary.dart  Gecelik özet
    services/               NotificationService, HybridNotificationManager, MonitorForegroundService (Android, MonitorService.kt)
    auth/, firebase/emulator_config.dart, debug/debug_hooks.dart, recording/, offline/offline_payload.dart,
    alert_history_service.dart, enums/
  models/                    AlertModel, VideoSettings, AppRole (= DeviceRole typedef)
  providers/                 ThemeProvider, LanguageProvider (provider paketi, ChangeNotifier)
  l10n/app_localizations.dart  Elle yazılmış tr/en/az sözlük (gen-l10n/ARB KULLANILMIYOR); yeni metinler üç dilde
                             eklenir (`python3 tool/l10n_add.py strings.json`)
```

Offline Nearby payload formatı (`OfflinePayload`): ilk byte tip, kalanı veri — `1` JPEG kare, `2` ayarlar/durum JSON (v2: `SOOTHE`, `NIGHT_LIGHT` dahil), `3` PCM ses, `4` pil JSON.

## Önemli dosyalar

- `pubspec.yaml` — Dart SDK `^3.6.2`. `permission_handler` için `dependency_overrides` var.
- `android/app/build.gradle.kts` — Java/Kotlin hedefi 17, core library desugaring açık, sdk sürümleri `flutter.*`'dan.
- `android/settings.gradle.kts` — AGP 8.11.1, Kotlin 2.2.20, google-services 4.3.10; Gradle 8.14.
- `android/app/src/main/AndroidManifest.xml` — ağ, konum, Nearby Wi-Fi, Bluetooth izinleri. Kamera/mikrofon/bildirim izinleri eklentilerin manifest'lerinden merge ediliyor.
- Firebase config: `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `lib/firebase_options.dart`, `firebase.json` — **bunları ve Firebase proje ayarlarını değiştirme.**

## Çalıştırma

```bash
flutter pub get
flutter analyze
flutter run                 # fiziksel cihaz bağlıyken
flutter build apk --debug
```

- **Fiziksel cihaz gerekir.** Gerçek test için **2 cihaz**: biri bebek rolünde (yayın), diğeri ebeveyn rolünde (izleme). Online modda ikisi de internette olmalı; offline modda yakın mesafede, Bluetooth + Wi-Fi + konum açık olmalı.
- `flutter test`: saf mantık unit testleri (payload, dB, modeller, l10n TR/EN/AZ eşitliği, alarm geçmişi) + v2 widget, erişilebilirlik (dokunma alanı/etiket) ve kontrast testleri. l10n'a yeni anahtar eklerken üç dile de ekleyin (test kontrol eder).
- Android derlemesi Android Studio'nun JBR'ını (JDK 21) kullanır; sistemde ayrı `java` PATH'te yok, gerek de yok.

## Bilinen kısıtlar

- Offline mod (Nearby Connections: Bluetooth + Wi-Fi) **sadece Android**'de çalışır; iOS'ta arayüzde gizli. Offline modda `WebRTCService` oluşturulmaz. Mikrofon PCM'i `record` paketiyle (`lib/core/audio/pcm_microphone.dart`, 16 kHz mono PCM16): offline yayında ve online bebekte ebeveyn bağlı değilken ağlama algılamada (WebRTC beklemede mikrofonu açmaz, B70). Görüşmede WebRTC `audioLevel` kullanılır; ikisi aynı anda mikrofonu tutmaz (`WebRTCService.beforeBabyCall`/`onBabyStandby`). Offline oynatıcı: `OfflineAudio.kt` (AudioTrack). iOS push: `Runner.entitlements` + `PushRegistration` (B69).
- Nearby, gerçek ses/kamera kalitesi, arka plan ve push **emülatörde test edilemez**; gerçek cihazda test et.
- Uçtan uca emülatör testleri: `scripts/firebase_emulators.sh` (Auth + Firestore + Functions, `firebase.emulators.json`) açıkken `python3 scripts/run_e2e.py --platform android|ios|mixed`. Testler `integration_test/`, sonuçlar `test-results/` (git dışı). iOS simülatörü için `flutter build ios --simulator` yerine `flutter test -d <udid>` kullanılır (DECISIONS A12).
- `monitor_controller.dart` büyük (eski HomeScreen mantığı); değişiklik yaparken ilgili bölümü dikkatle bul, istenmeden büyük refactor yapma. Tasarım: `design/mockups/`, plan: `docs/V2_PLAN.md`, ilerleme: `docs/V2_PROGRESS.md`.
- Ekran görüntüleri (tasarım kontrolü, mağaza): `flutter test tool/screenshots_test.dart` → `build/screens/`. Sesler: `python3 tool/gen_sounds.py`; simgeler: `flutter test tool/gen_icons_test.dart`.
- `flutter analyze`: 0 error / 0 warning; kalan info'lar enum isimlendirme (`BABY`, `CONNECTED`…; Firestore'daki durum metinleriyle ilişkili) ve `use_build_context_synchronously` — bilinçli olarak bırakıldı.
- Bilinen hatalar, karar bekleyen konular ve cihaz test planı: `BUGS.md`, `REPORT.md`, `TEST_PLAN.md`, `DECISIONS.md`, `BLOCKERS.md`, `PLAN_NEXT.md`.

## Çalışma kuralları

- Geliştirme `dev` branch'inde; `main`'e doğrudan commit yok. `git push` öncesi kullanıcıya sor.
- Küçük, mantıklı commit'ler.
