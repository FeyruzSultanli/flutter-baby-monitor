# Bebek Monitor (flutter-baby-monitor)

Flutter ile yazılmış gerçek zamanlı bebek monitörü. Bir cihaz **bebek** (kamera + mikrofon yayını, ağlama algılama), diğeri **ebeveyn** (izleme, bildirim alma) rolünde çalışır. İki bağlantı modu var:

- **Online:** WebRTC (görüntü/ses) + Firestore signaling (`rooms` koleksiyonu, oda kodu ile eşleşme) + FCM / yerel bildirimler.
- **Offline:** Google Nearby Connections (`Strategy.P2P_STAR`) üzerinden internet olmadan; WebRTC kullanılmaz, kamera kareleri JPEG olarak, ses ham PCM olarak byte payload ile gönderilir.

Paket adı: `bebek_monitor_clean` (import'lar `package:bebek_monitor_clean/...`). Android applicationId: `com.example.bebek_monitor_clean`.

## Mimari

```
lib/
  main.dart                 Firebase init (try/catch ile korumalı) + HybridNotificationManager + MultiProvider
  app.dart                  MaterialApp, tema (light/dark), tr/en lokalizasyon
  firebase_options.dart     FlutterFire tarafından üretildi — DEĞİŞTİRME
  screens/
    home_screen.dart        ~2900 satır; uygulamanın asıl mantığı burada (rol değişimi, online/offline,
                            Nearby advertise/discover, kamera image stream, ses, ağlama algılama, kayıt, UI)
    multi_camera_screen.dart  Birden çok bebek kamerasını izleme (MultiPeerService + FirestoreSignaling)
    alert_history_screen.dart, video_gallery_screen.dart, video_player_screen.dart
  core/
    webrtc/
      signaling_interface.dart       Ortak arayüz (offer/answer/candidate/alert stream'leri)
      firestore_signaling.dart       Online signaling (rooms/{id}, callerCandidates/calleeCandidates, alerts)
      webrtc_service.dart            Tek peer bağlantı, renderer'lar, STUN: stun.l.google.com
      multi_peer_service.dart        Çoklu peer yönetimi
      signaling_messages.dart, reconnect_backoff.dart  Oturum etiketli mesajlar, yeniden katılma gecikmesi
    pairing/                 PairingService (Firestore oda oluşturma/katılma/silme), PairingState, RoomCode
    auth/                    Anonim Firebase Auth (oda sahipliği; firestore.rules buna dayanır)
    firebase/emulator_config.dart  Yalnızca debug + --dart-define=USE_FIREBASE_EMULATOR=true ile Emulator Suite
    debug/debug_hooks.dart   Yalnızca debug: E2E için sahte ses seviyesi kancası
    services/                NotificationService (FCM + flutter_local_notifications), HybridNotificationManager (singleton)
    recording/               VideoRecorderService (camera kayıt → gal ile galeriye)
    offline/offline_payload.dart  Nearby byte payload kodlama/çözme (OfflinePayload, OfflinePayloadType)
    audio/audio_level.dart        PCM16→dB (offline) ve WebRTC audioLevel→dB (online)
    alert_history_service.dart
    enums/                   DeviceRole { BABY, PARENT }, ConnectionStatus
  models/                    AlertModel, VideoSettings, AppRole (= DeviceRole typedef)
  providers/                 ThemeProvider, LanguageProvider (provider paketi, ChangeNotifier)
  l10n/app_localizations.dart  Elle yazılmış tr/en sözlük (gen-l10n/ARB KULLANILMIYOR); yeni metinler buraya iki dilde eklenir
  widgets/                   camera_preview_card, fullscreen_view, noise_level_bar, settings_sheet, status_chips_row
```

Offline Nearby payload formatı (`OfflinePayload`): ilk byte tip, kalanı veri — `1` JPEG kare, `2` ayarlar/durum JSON, `3` PCM ses, `4` pil JSON.

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
- `flutter test`: saf mantık unit testleri (payload, dB, modeller, l10n TR/EN eşitliği, alarm geçmişi) + SettingsSheet/NoiseLevelBar smoke testleri. HomeScreen eklenti gerektirdiği için widget testinde yok. l10n'a yeni anahtar eklerken iki dile de ekleyin (test kontrol eder).
- Android derlemesi Android Studio'nun JBR'ını (JDK 21) kullanır; sistemde ayrı `java` PATH'te yok, gerek de yok.

## Bilinen kısıtlar

- Offline mod (Nearby Connections: Bluetooth + Wi-Fi) **sadece Android**'de çalışır; iOS'ta arayüzde gizli. Offline modda `WebRTCService` oluşturulmaz. Offline ses (PCM) kendi Android platform kanalımızla: `android/.../OfflineAudio.kt` + `lib/core/audio/offline_audio.dart` (16 kHz mono PCM16; GPL'li `sound_stream` yerine, B68).
- Nearby, gerçek ses/kamera kalitesi, arka plan ve push **emülatörde test edilemez**; gerçek cihazda test et.
- Uçtan uca emülatör testleri: `scripts/firebase_emulators.sh` (Auth + Firestore + Functions, `firebase.emulators.json`) açıkken `python3 scripts/run_e2e.py --platform android|ios|mixed`. Testler `integration_test/`, sonuçlar `test-results/` (git dışı). iOS simülatörü için `flutter build ios --simulator` yerine `flutter test -d <udid>` kullanılır (DECISIONS A12).
- `home_screen.dart` çok büyük; değişiklik yaparken ilgili bölümü dikkatle bul, istenmeden büyük refactor yapma.
- `flutter analyze`: 0 error / 0 warning; kalan info'lar enum isimlendirme (`BABY`, `CONNECTED`…; Firestore'daki durum metinleriyle ilişkili) ve `use_build_context_synchronously` — bilinçli olarak bırakıldı.
- Bilinen hatalar, karar bekleyen konular ve cihaz test planı: `BUGS.md`, `REPORT.md`, `TEST_PLAN.md`, `DECISIONS.md`, `BLOCKERS.md`, `PLAN_NEXT.md`.

## Çalışma kuralları

- Geliştirme `dev` branch'inde; `main`'e doğrudan commit yok. `git push` öncesi kullanıcıya sor.
- Küçük, mantıklı commit'ler.
