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

## Faz 1 — Özet (tamamlandı)

Commit'ler: `339ddea` (servis), `a28e284` (kurallar + Function), `6faf617` (bekçi, pil, arka planda dinleme), `42ce83c` (pil push'u için sunucu sınırı), `3a17624` (B71).

- **5.12 Foreground service (Android):** kendi `MonitorService.kt`'miz (DECISIONS A18). Bebek yayını başlayınca (online oda / offline yayın) "Ninni yayında" bildirimiyle başlar; yayın bitince, rol değişince ya da uygulama görevden atılınca durur. Wake lock + Wi-Fi kilidi tutar. Tür izinlere göre (`camera|microphone` [+ `connectedDevice`]).
- **5.10 Arka planda dinleme:** ebeveynde ayar (varsayılan açık). Android: `mediaPlayback` servisi; iOS: `audio` arka plan modu (zaten vardı). Kapalıyken uygulama görünmezse bebek sesi kısılır.
- **5.6 Bağlantı koptu:** `ConnectionWatchdog` (saf mantık, testli): `failed` → hemen, kopuk 5 sn, bağlıyken 20 sn medya yok → tam ekran amber uyarı + döngüsel alarm sesi + titreşim + bildirim; bağlantı dönünce kendiliğinden kapanır. "Tekrar dene", "Alarmı sustur", "Bağlantıyı kes".
- **5.7 Bebek pili:** online pil senkronu yoktu, eklendi (`battery` alanı). Ebeveynde %15 altı ve şarjda değilse **bir kez** amber kart (arka plandaysa yerel bildirim). Uygulama kapalıyken: bebek `alerts`'e `type: battery` belgesi yazar, Function ayrı etiketle push eder (sunucuda 30 dk sınır).
- **Impeller:** opt-out yoktu (A22).
- **B71 (yeni hata, E2E buldu):** ebeveyn aynı teklife iki kez cevap verebiliyordu; düzeltildi.
- **Testler:** `flutter analyze` 0 error/0 warning; `flutter test` 106/106 (Faz 1 sonu); Firestore kuralları 29/29; Function 11/11.
- **Android ↔ Android E2E** (`test-results/20261122-181807-android`, Faz 1 kodu, `3a17624`): iki taraf da geçti, 54 kontrolün 53'ü doğru. Yeni: `connection_lost_alarm_shown` ve `..._cleared_after_reconnect` ✅ (uçak modu). Ekran görüntüsünde online pil senkronu görünüyor (%100, şarjda). Tek ❌ `gallery_opens`: eski arayüzde kayıt durduktan sonra galeri ikonuna dokunuş karşılanmadı; eski arayüz Faz 2'de kaldırıldığı için ayrıca düzeltilmedi (yeni arayüzde galeri Ayarlar'da).
- İlk iki koşu: biri ebeveyn emülatörünün ağı olmadığı için (emülatör yeniden başlatıldı), biri B71 yüzünden düştü.
- `dev`'e push: `3a17624`.

### Faz 1 — Gerçek cihazda test edilecekler
TEST_PLAN.md §14 (V1.1–V1.16). En önemlileri: **V1.1/V1.2** (ekran kapalıyken / başka uygulamadayken kamera-mikrofon sürüyor mu — en büyük risk), V1.6–V1.8 (kilitliyken dinleme, Android ve iPhone), V1.9–V1.13 (bağlantı koptu alarmı), V1.14–V1.15 (pil).

## Faz 2 — Özet (tamamlandı, `dev` @ `a563e82`)

- **Tasarım sistemi** (`lib/theme/`): belirteçler (renk, yazı ölçeği, yarıçap, boşluk), açık (krem) ve gece temaları (`NinniPalette`), bileşenler: NinniButton, StatusPill, CodeBoxes, SectionCard, SettingsRow, SegmentedControl, NinniSwitch, LevelMeter, SoundBars, IconTile, BottomSheetFrame, AppIcon, Starfield, PulseDot, AlarmRings, BassinetIcon. Plus Jakarta Sans gömülü (OFL).
- **home_screen.dart parçalandı:** 3700 satırlık ekran silindi; tüm mantık `lib/features/monitor/monitor_controller.dart`'ta (davranış korunarak taşındı, A27). Ekranlar `lib/screens/v2/`: karşılama 1–3, rol seçimi, bebek kod, bebek yayında, gece modu, ebeveyn kod, canlı izleme, tam ekran, ağlama alarmı, bağlantı koptu, alarm geçmişi (gecelik özetle), ayarlar.
- **Marka:** "Ninni" adı, simge (AppIconPainter'dan üretildi), Android adaptive simge, beyaz hilal bildirim simgesi, #12142B açılış ekranı (Android + iOS).
- **Animasyon:** SharedAxis/FadeThrough (iOS'ta itilen sayfalarda yerel geçiş, A24), yıldızlar, nefes alan ay, nabız, alarm halkaları, %97 basma; hepsi "hareketi azalt"ta durur.
- **E2E'nin bulduğu hatalar:** B72 (görüntü gelmeden kayıt durdurulunca çökme — önlem), B73 (Android 10+ kayıt galeriye eklenmiyordu). Kod kutuları + `IntrinsicHeight` çakışması ekran görüntüsü aracıyla bulundu ve düzeltildi.
- **Testler:** analyze 0 error/0 warning; birim/widget testleri; Android ↔ Android E2E `test-results/20261122-185818-android`: ebeveyn 26/26; bebekte tek ❌ gece modundan çift dokunuşla çıkış — test zamanlaması (iki dokunuş 40 ms'den yakın), test düzeltildi ve Faz 3 koşusunda ✅. iOS derlemesi (`flutter build ios --no-codesign`) ✅.
- Gerçek cihaz maddeleri: TEST_PLAN §15 (V2.1–V2.16).

## Faz 3 — Özet (tamamlandı, `dev` @ `7facda8`)

- **5.1 QR:** bebek kod kartında QR (`ninni://join?code=…`), ebeveynde "QR kodu okut" (mobile_scanner); izin yoksa açıklama + elle giriş. URL şeması kaydı yok (A30).
- **5.2 Son oda / oda adı:** ebeveyn son 3 odayı hatırlar, "Tekrar bağlan" tek dokunuş; bebek odaya ad verir (sonraki odalarda da kalır).
- **5.3 Bas-konuş:** ses kanalı baştan `sendrecv`, mikrofon yalnızca basılıyken; bebekte hoparlör; konuşma sürerken ve 3 sn sonrasına kadar ağlama algılama durur (A31).
- **5.4 Ninni / beyaz gürültü:** 4 ses kendi sentezimiz (`tool/gen_sounds.py`, `assets/audio/LICENSES.md`); ebeveyn uzaktan çalar/durdurur, ses düzeyi, 15/30/60/sürekli. Çalarken eşik ölçülen ses seviyesine göre en fazla +12 dB (A29).
- **5.5 Gece lambası:** 4 renk, bebek telefonu gece moduna geçip yumuşak ışık verir (A32).
- **5.8 5 dk sessize al**, **5.9 gecelik özet** (Faz 2'de ekranla birlikte geldi; süreler alarm geçmişine yazılıyor).
- **5.11 Azerbaycanca:** tüm metinler (A33), Function push metinleri de.
- **Testler:** Android ↔ Android E2E `test-results/20261122-190615-android`: iki taraf da geçti; yeni kontroller (son oda, bas-konuş düğmesi, ninni/gece lambası odaya yazıldı ve durdu) ✅. iOS derlemesi ✅.
- Gerçek cihaz maddeleri: TEST_PLAN §16 (V3.1–V3.14). Kulakla/anadilde kontrol: BLOCKERS 9.

## Faz 4 — Özet (tamamlandı, `dev` @ son commit)

- **Erişilebilirlik:** simge düğmelerinde 48 dp dokunma alanı (görünüm aynı), her denetimde anlamlı etiket, canlı bölgeler (alarm, bağlantı, hata metinleri), kod kutuları ekran okuyucuda harf harf; Flutter'ın dokunma alanı/etiket yönergeleri 9 ekranda test ediliyor (`test/a11y_test.dart`). Tüm renk çiftleri WCAG ≥4,5:1 (`test/contrast_test.dart`, iki ton koyulaştırıldı, A34).
- **Büyük yazı / küçük ekran / tablet:** ×1,3, ×2, 320×568 ve 820×1180'de tüm ekranlar taşmasız (ekran görüntüsü aracıyla denetlendi; düzeltmeler: ninni kutuları, durum hapları, kelime işareti).
- **Performans:** canlı ses seviyesi yalnızca ölçeri yeniden çiziyor; ebeveyn ses çubukları ~10 Hz gerçek sesle; gece modunda bebek telefonu yalnızca gece görünümünü çiziyor (A35).
- **Mağaza görüntüleri:** `--dart-define=NINNI_DEMO=<sahne>` ile uygulama temiz demo durumunda açılır (video yerine çizim). Toplu üretim:

  ```bash
  flutter test tool/screenshots_test.dart --dart-define=SHOT_W=430 --dart-define=SHOT_H=932 --dart-define=SHOT_RATIO=3
  ```

  Çıktı `build/screens/tr_430/*.png` (1290×2796, App Store 6,7"). `--dart-define=SHOT_LOCALE=en` / `az` ile diğer diller.
- Gerçek cihaz maddeleri: TEST_PLAN §17 (V4.1–V4.6).
- **Testler (Faz 4 sonu):** `flutter analyze` 0 error / 0 warning (7 info: bilinçli bırakılan enum adları ve `use_build_context_synchronously`); `flutter test` 161/161; kurallar 29/29; Function 11/11; lisans taraması temiz (A36).
- **E2E:**
  - Android ↔ Android `test-results/20261122-193020-android`: iki taraf da geçti (0 hata).
  - Android bebek ↔ iOS ebeveyn `test-results/20261122-193757-mixed`: iki taraf da geçti (0 hata). Önceki koşuda (`…191353-mixed`) tek hata testin kendisindeydi (ebeveynin gece lambası bebeği gece moduna almıştı); test düzeltildi.
  - Ağ kesintisi adımı karma koşuda atlanır (iOS simülatöründe uçak modu yok, A14).
- iOS derlemesi (`flutter build ios --no-codesign`) ✅, Android debug APK ✅.

## Açık konular

- **Gerçek cihaz testleri** (emülatörde doğrulanamayanlar): foreground service ile ekran kapalıyken kamera/mikrofon (V1.1–V1.3, en büyük risk), arka planda dinleme (V1.6–V1.8), bas-konuşta yankı ve hoparlör (V3.5), iPhone'da ninni çalarken WebRTC sesi (A23, V3.7), push zinciri (Function deploy sonrası), ısı/pil (V4.4).
- **Kulak/anadil kontrolü:** "Dandini dandini" melodisi ve Azerbaycanca metinler (BLOCKERS 9).
- **Bilinen eklenti hataları:** flutter_webrtc kayıt (B72 önlem, B73 çözüldü) — yukarı akışa bildirilmeli.
- **Kapsam dışı bırakılanlar:** `ninni://` URL şeması kaydı (A30), offline bas-konuş (A31), çoklu kamera ekranı (A26).

## Kullanıcıdan beklenenler (Cavid)

1. Aşağıdaki "Cavid yapacak" adımları (kurallar + Function deploy).
2. İki gerçek telefonla TEST_PLAN §14–§17 (V1–V4). Öncelik: V1.1/V1.2, V1.9–V1.13, V2.12, V3.5–V3.8.
3. Melodi ve AZ metin kontrolü (BLOCKERS 9).
4. Mağaza hazırlığı: Play Console foreground service beyanı; ekran görüntüleri `tool/screenshots_test.dart` ile (Faz 4).


## Cavid yapacak

Firebase tarafı (kod hazır, deploy edilmedi):

1. **Firestore kuralları** (v2 alanları: `battery`, `roomName`, `soothe`, `nightLight`, alarm türü). Telefon testinden sonra:

   ```bash
   cd /Users/feyruz/Desktop/baby_monitor_app && npx firebase-tools@latest deploy --only firestore:rules --project bebekmonitor-282fd
   ```

   Kurallar yayınlanmadan da uygulama çalışır; yalnızca pil/oda adı/ninni/gece lambası alanları sunucuda reddedilir (ağlama alarmı ve eşleşme etkilenmez).

2. **Function** (pil push'u, Azerbaycanca metinler):

   ```bash
   npm --prefix functions ci && npm --prefix functions test
   ```

   ```bash
   npx firebase-tools@latest deploy --only functions --project bebekmonitor-282fd
   ```

3. **Google Play** (yayın öncesi): Play Console → "Foreground service types" beyanı (kamera, mikrofon, connectedDevice, mediaPlayback) ve kısa bir kullanım videosu.
