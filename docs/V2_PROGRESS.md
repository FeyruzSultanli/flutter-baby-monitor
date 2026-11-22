# Ninni v2 — İlerleme

> Ana plan: `docs/V2_PLAN.md`. Taslaklar: `design/mockups/*.dc.html`.
> Taban: `dev` @ `50ce7db`. Başlangıçta `flutter analyze` 0 error / 0 warning (13 info), `flutter test` 96/96.

## Uygulama planı (kodlamadan önce)

### Faz 1 — Güvenilirlik

| İş | Değişecek / eklenecek dosyalar |
|---|---|
| 5.12 Bebek foreground service (Android) | `pubspec.yaml` (`flutter_foreground_task`), `AndroidManifest.xml` (`FOREGROUND_SERVICE`, `_CAMERA`, `_MICROPHONE`, `_MEDIA_PLAYBACK`, `_CONNECTED_DEVICE`, `POST_NOTIFICATIONS`, `WAKE_LOCK`; servis tanımı `camera\|microphone\|connectedDevice`), yeni `lib/core/services/monitor_foreground_service.dart`, `home_screen.dart` (yayın başlayınca başlat, `_resetPairing`/dispose'da durdur), l10n |
| 5.10 Ebeveyn arka planda dinleme | Aynı servis, ebeveyn için `mediaPlayback` türüyle; ayar anahtarı (`shared_preferences`); iOS'ta `audio` arka plan modu zaten var, oturum kategorisi WebRTC'de `playAndRecord` |
| 5.6 Bağlantı koptu alarmı | Yeni `lib/core/monitor/connection_watchdog.dart` (saf mantık + test): WebRTC `FAILED`/`disconnected`, ya da 20 sn kare/ses yok → alarm; yeniden bağlanınca kapanır. Ebeveyn: geçici tam ekran uyarı (Faz 2'de tasarımlı `ConnectionLost` ekranı), yerel bildirim, titreşim + ses |
| 5.7 Bebek pili düşük | Online pil senkronu yoktu: odaya `battery: {level, charging, at}` (yeni sahip alanı). `lib/core/monitor/battery_alert.dart` (tek seferlik, %15 altı ve şarjda değil; test). Ebeveyn: kart + yerel bildirim. Function: `alerts` belgesine `type: 'battery'` → pil mesajı. `firestore.rules` (yeni alanlar), `firestore-tests`, `functions/src` |
| Impeller opt-out | Depoda `EnableImpeller` / opt-out yok (git geçmişinde de yok). Yapılacak bir şey yok; not düşülür |

Paketler: `flutter_foreground_task` 11.0.3 (MIT), `audioplayers` 6.8.x (MIT; alarm sesi, Faz 3'te ninni), `shared_preferences` 2.5.x (BSD-3).
Riskler:
- Kamera/mikrofon ekran kapalıyken eklenti katmanında durabilir (PLAN_NEXT §5 spike). Emülatörde doğrulanamaz → gerçek cihaz maddesi.
- Android 14+: servis yalnızca ön plandayken başlatılabilir; yayın her zaman kullanıcı dokunuşuyla başladığı için sağlanıyor.
- Yeni oda alanları (`battery`) kurallar yayınlanana kadar reddedilir → ayrı `update()` çağrısıyla yazılır, hata yutulur (ağlama alarmı etkilenmez). Kural deploy'u "Cavid yapacak"a.
- `flutter_foreground_task` Dart ≥ 3.12 istiyor: ortam 3.12.2; `sdk` alt sınırı yükseltilir.

### Faz 2 — Tasarım sistemi ve tüm ekranlar

| İş | Dosyalar |
|---|---|
| Tasarım sistemi | `lib/theme/tokens.dart`, `app_theme.dart`, `components/` (NinniButton, StatusPill, CodeBoxes, SectionCard, SettingsRow, SegmentedControl, NinniSwitch, LevelMeter, SoundBars, IconTile, BottomSheetFrame, AppIcon, Starfield) |
| Yazı | `assets/fonts/PlusJakartaSans-*.ttf` + `OFL.txt` (Google Fonts deposundan; internetsiz) |
| Marka | Simge: `AppIcon` CustomPainter'dan `tool/` altındaki bir Flutter testiyle 1024 px PNG üretimi → `flutter_launcher_icons` (adaptive: ön plan hilal+nokta, arka plan #12142B), beyaz tek renk bildirim simgesi (`ic_stat_notification`), `flutter_native_splash` (#12142B). Görünen ad "Ninni" (Android `android:label`, iOS `CFBundleDisplayName`); applicationId/bundle ID değişmez |
| home_screen parçalanması | Mantık `lib/features/monitor/monitor_controller.dart` (ChangeNotifier) ve parçalarına (bebek/ebeveyn/offline/ses/pil) taşınır; `BuildContext` yerine olay akışı (snackbar/uyarı) kullanılır. Ekranlar `lib/screens/v2/...`: karşılama 1–3, rol seçimi, bebek kod, bebek yayında, gece modu, ebeveyn kod gir, canlı izleme, ağlama alarmı, alarm geçmişi, ayarlar, bağlantı koptu. Eski `home_screen.dart` silinir |
| Animasyon | `animations` (SharedAxis/FadeThrough), Starfield, nabız halkası, ses çubukları ~10 Hz, alarm halkaları, buton %97 ölçek; `disableAnimations` ve gece modunda kapalı |
| E2E | `integration_test/*` yeni ekranlara (anahtarlar) göre güncellenir |

Paketler: `animations` 3.0.0 (BSD-3), `flutter_native_splash` 2.4.x (MIT, dev), `flutter_launcher_icons` (MIT, mevcut).
Riskler: refactor sırasında davranış kaybı (eşleşme, B08 oturumları, offline) → mantık birebir taşınır, ekranlar yalnızca controller'ı okur; her adımda analyze + test + E2E. Taslaklar 390×844'e göre; küçük ekranlarda kaydırma.

### Faz 3 — Yeni özellikler

| İş | Dosyalar |
|---|---|
| 5.1 QR | `qr_flutter` 4.1.0 (BSD-3) bebekte, `mobile_scanner` 7.5.x (BSD-3; Android'de ML Kit, iOS'ta Vision) ebeveynde. İçerik `ninni://join?code=ABCD-EF23`; ayrıştırma `RoomCode`'da (test). Kamera izni yoksa elle giriş |
| 5.2 Son oda | `lib/core/pairing/recent_room_store.dart` (shared_preferences; kod + ad + zaman), oda adı alanı `roomName` |
| 5.3 Bas-konuş | `webrtc_service.dart`: ebeveyn yanıtta ses transceiver'ını `sendrecv` yapar, basılıyken `replaceTrack(mic)`, bırakınca `null`. Bebek gelen sesi hoparlörden çalar; gelen ses seviyesi (inbound-rtp) eşik üstündeyken ve 3 sn sonrasına kadar ağlama algılama durur. Yalnızca online |
| 5.4 Ninni / beyaz gürültü | `tool/gen_sounds.py` (yalnızca stdlib) ile sentezlenmiş döngüler `assets/audio/*.wav` + `LICENSES.md`; `audioplayers` ile bebekte; oda `soothe: {track, volume, endsAt}`, offline'da Nearby kontrol mesajı. Ağlama eşiği düzeltmesi DECISIONS'a |
| 5.5 Gece lambası | Oda `nightLight: {on, color}`; bebek gece modunda renkli düşük parlaklık |
| 5.8 5 dk sessize al, 5.9 gecelik özet | `AlertModel`'e süre/tür; `lib/core/alerts/night_summary.dart` (test) |
| 5.11 AZ | `app_localizations.dart` üçüncü dil; l10n testi üç dili karşılaştırır |

Riskler: iOS'ta `audioplayers` ses oturumu WebRTC'yi bozabilir → `AudioContext` `playAndRecord` + `mixWithOthers`; bas-konuşta yankı (bebek AEC'si). "Dandini dandini" melodisi geleneksel; nota aktarımı bizim, kulakla kontrol edilmeli. Kurallar yeni alanlar için tekrar yayınlanmalı (Cavid).

### Faz 4 — Cila
Semantics etiketleri, büyük yazı (textScaler 1.3–2.0) taşma testleri, kontrast kontrolü (token çiftleri için birim test), iPhone SE (320×568 pt) ve tablet düzenleri (en fazla 560 pt içerik genişliği), bebek cihazında yeniden çizim sıklığı (RepaintBoundary, ~10 Hz), E2E'nin tamamı, mağaza görüntüleri için `--dart-define=NINNI_DEMO=true` demo durumları.
Riskler: emülatörde gerçek CPU/ısı ölçülemez → gerçek cihaz maddesi.

## Cavid yapacak
_(Firebase deploy ve konsol adımları fazlar ilerledikçe buraya eklenir.)_
