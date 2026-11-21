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
      signaling_service.dart         Eski/ek Firestore signaling yardımcıları
    pairing/                 PairingService (Firestore oda oluşturma/katılma/silme), PairingState
    services/                NotificationService (FCM + flutter_local_notifications), HybridNotificationManager (singleton)
    recording/               VideoRecorderService (camera kayıt → gal ile galeriye)
    alert_history_service.dart
    enums/                   DeviceRole { BABY, PARENT }, ConnectionStatus
  models/                    AlertModel, VideoSettings, AppRole (= DeviceRole typedef)
  providers/                 ThemeProvider, LanguageProvider (provider paketi, ChangeNotifier)
  l10n/app_localizations.dart  Elle yazılmış tr/en sözlük (gen-l10n/ARB KULLANILMIYOR); yeni metinler buraya iki dilde eklenir
  widgets/                   camera_preview_card, fullscreen_view, noise_level_bar, settings_sheet, status_chips_row
```

Offline Nearby payload formatı: ilk byte tip, kalanı veri — `1` JPEG kare, `2` ayarlar/durum JSON, `3` PCM ses, `4` pil JSON.

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
- `flutter test`: `test/widget_test.dart` tek bir duman testi içerir; Firebase/kamera eklentileri test ortamında olmadığı için kırılgandır.
- Android derlemesi Android Studio'nun JBR'ını (JDK 21) kullanır; sistemde ayrı `java` PATH'te yok, gerek de yok.

## Bilinen kısıtlar

- Offline mod (Nearby Connections: Bluetooth + Wi-Fi) **sadece Android**'de çalışır. Offline modda `WebRTCService` oluşturulmaz.
- Kamera, mikrofon, WebRTC ve P2P **emülatörde/simülatörde güvenilir çalışmaz**; gerçek cihazda test et.
- `pubspec.lock` repoda yoktu (`.gitignore`'da `*.lock`), paket sürümleri zamanla kayabilir.
- `home_screen.dart` çok büyük; değişiklik yaparken ilgili bölümü dikkatle bul, istenmeden büyük refactor yapma.
- `flutter analyze` 0 hata verir, ancak ~23 warning (kullanılmayan alan/metot/değişken, gereksiz `!`/null kontrolü) ve ~41 info (`withOpacity`, `surfaceVariant`, `Share` deprecations; `use_build_context_synchronously`; enum isimlendirme) vardır.

## Çalışma kuralları

- Geliştirme `dev` branch'inde; `main`'e doğrudan commit yok. `git push` öncesi kullanıcıya sor.
- Küçük, mantıklı commit'ler.
