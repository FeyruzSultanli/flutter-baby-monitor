# DECISIONS.md — Otonom çalışma kararları

> Kullanıcı yokken alınan kararlar. Her biri: konu, seçenekler, seçim, neden.
> Daha önceki kararlar (K1–K7, D1–D11) BUGS.md ve PLAN_NEXT.md'de.

## Oturum: otonom mod (emülatör testleri, iOS)

### A1 — Güvenlik kuralları nereye
- **Seçenekler:** `.claude/settings.json` (repoya girer) / `.claude/settings.local.json` (yerel).
- **Seçim:** `.claude/settings.local.json`, `.gitignore`'da.
- **Neden:** Kullanıcı açıkça bunu istedi; makineye özel izinler repoya girmemeli.

### A2 — Firebase Emulator Suite yapılandırması
- **Seçenekler:** (a) `firebase.json`'a `emulators` bölümü eklemek, (b) yalnızca emülatörler için ayrı `firebase.emulators.json` + `--config`.
- **Seçim:** (b). `scripts/firebase_emulators.sh` bu dosyayla Auth + Firestore (bizim `firestore.rules`) + Functions başlatır.
- **Neden:** Gerçek deploy'da kullanılan `firebase.json` değişmesin; emülatör ayarı ayrı ve geri alınabilir.
- **Proje kimliği:** Emülatör `--project bebekmonitor-282fd` ile çalışır, çünkü uygulamanın Firebase ayarları bu kimliği kullanır (ad alanları eşleşmeli). Emülatör tamamen yereldir, giriş yapılmaz, gerçek projeye veri yazılmaz.

### A3 — Function emülatörde FCM'e gitmesin
- **Seçim:** `FUNCTIONS_EMULATOR === 'true'` iken gönderim yapılmaz; gönderilecek başlık/gövde odaya `lastPushPreview` olarak yazılır (yalnızca emülatörde).
- **Neden:** Emülatör uyarısı, emüle edilmeyen servislere yapılan çağrıların gerçek projeyi etkileyeceğini söylüyor. Testler gerçek FCM'e hiç istek atmamalı.

### A4 — Uygulama emülatöre nasıl bağlanır
- **Seçim:** Yalnızca debug derlemede ve `--dart-define=USE_FIREBASE_EMULATOR=true` verilirse (`kDebugMode` derleme zamanı sabiti). Android'de host adresi `10.0.2.2`, iOS simülatöründe `localhost`. Düz HTTP izni yalnızca `src/debug` manifestinde bu adresler için var.
- **Neden:** Release her zaman gerçek Firebase'e bağlanmalı; emülatör kodu release'e girmemeli.

### A5 — iOS minimum sürüm
- **Seçenekler:** 13 (Flutter varsayılanı) / 15 / 16.
- **Seçim:** iOS 15 (Podfile + Runner hedefi).
- **Neden:** Firebase, WebRTC ve kamera eklentileri ≥13 istiyor; 15 ileride çıkacak eklenti sürümleri için pay bırakıyor ve iPhone 6s/SE (1. nesil) ve sonrasını kapsıyor.

### A6 — iOS izin metinleri ve Xcode projesi
- **Seçim:** Temel metinler İngilizce `Info.plist`'te; Türkçe ve İngilizce `tr.lproj`/`en.lproj` `InfoPlist.strings` dosyalarında.
- **Nasıl:** Dosyaları projeye CocoaPods'un `xcodeproj` gem'i ile ekledim. `project.pbxproj`'u elle ya da regex'le düzenlemek yerine projenin kendi API'si kullanıldı; bu güvenli ve yapısal bir yöntem.
- **Neden:** iOS, izin metnini cihaz diline göre seçer.

### A7 — iOS'ta offline
- **Seçim:** Ayarlarda anahtarın yerine "Offline mod yalnızca Android'de kullanılabilir" açıklaması gösteriliyor; kontrol kartı gizli. Android aynen kalıyor.
- **Neden:** Kullanıcının istediği bu; kod silinmedi.

### A8 — Android E2E: önce API 36, sonra API 35 Google Play
- **Durum:** API 35 Google Play image'ın indirmesi takıldı (849 MB'ta durdu); ikinci denemede tamamlandı.
- **Seçim:** Beklememek için testleri, makinede kurulu olan API 36 `google_apis` image'ı (Google Play servisleri var, Play Store yok) ile oluşturulan "baby"/"parent" AVD'leriyle geliştirdim ve hataları ayıkladım. Son koşu, aynı adlarla API 35 Google Play image üzerine yeniden kurulan AVD'lerde.
- **Neden:** Kullanıcının istediği Play'li image; iki koşu arasında test kodu aynı.

### A9 — E2E'de WebRTC bağlantısı nasıl ölçülür
- **Seçim:** Ana ekrandaki bağlantı durumu metni ("Bağlı"). Odadaki `isPaired` alanı yeterli değil, çünkü ebeveyn cevap verirken bu alanı `true` yapıyor (ilk koşularda yanıltıcı sonuç verdi).

### A10 — iOS simülatörü: iOS 27 çalışma zamanı
- **Durum:** iOS 26.5 simülatöründe uygulama açılışta çöküyor. Neden: `sound_stream` eklentisi kayıt sırasında `AVAudioEngine` başlatıyor, CoreAudio `AURemoteIO` RPC zaman aşımına uğrayıp `abort` ediyor. Aynı derleme iOS 27.0 simülatöründe sorunsuz açılıyor.
- **Seçim:** E2E iOS 27 simülatörlerinde (`baby-ios27`, `parent-ios27`). Kodda değişiklik yok.
- **Not:** Eski `baby-ios` / `parent-ios` (iOS 26.5) simülatörleri ve `try-ios27` kapatıldı ama silinmedi (proje dışında dosya silmeme kuralı). İsterseniz Xcode → Devices and Simulators'tan silebilirsiniz.

### A11 — iOS'ta `sound_stream` eklentisi kaydedilmiyor
- **Durum:** `sound_stream`, iOS'ta eklenti kaydı sırasında `AVAudioEngine` başlatıyor. Bu, iOS 26.5 **ve** 27.0 simülatörlerinde açılışta `abort` ile sonuçlanıyor (CoreAudio RPC zaman aşımı); ilk iOS 27 denemesindeki sorunsuz açılış şanstı. Gerçek cihazda da kullanılmadığı halde ses donanımını açılışta alıyor.
- **Seçenekler:**
  - (a) Paketi kopyalayıp `platforms: android` yapmak: GPL kodu repoya girer.
  - (b) `AppDelegate`'te eklenti kaydından önce `+[SoundStreamPlugin registerWithRegistrar:]` metodunu Objective-C runtime ile boş bir işlemle değiştirmek.
  - (c) iOS testlerinden vazgeçmek.
- **Seçim:** (b). Dart tarafında `sound_stream` çağrıları yalnızca Android'de yapılıyor (`_initAudioServices`, `_stopAudioStream`). Offline mod iOS'ta zaten kapalı.
- **Geri alma:** `AppDelegate.swift`'teki `skipSoundStreamPluginOnIOS()` çağrısını silmek yeterli. Paket değiştirilirse (GPL kararı) bu kod da kalkar.

### A12 — `flutter build ios --simulator` çalışmıyor, `flutter test`/`run` çalışıyor
- **Durum:** Flutter 3.44, `flutter build ios --simulator` ile arm64 + x86_64 istiyor, ama Flutter.framework'ün simülatör sürümü yalnızca arm64 ("does not contain architectures arm64 x86_64").
- **Seçim:** Belirli bir simülatöre yapılan derlemeler (`flutter test -d <udid>`, `flutter run`) ya da tek bir simülatör hedefiyle `xcodebuild` kullanılıyor; ikisi de sorunsuz. Gerçek cihaz derlemesi bundan etkilenmez.

### A13 — Eylem düğmeli uyarılar 8 sn sonra kapanıyor (B67)
- **Seçenekler:** (a) Flutter'ın yeni varsayılanı: kullanıcı kaydırana kadar kalır; (b) eski davranış: belirli bir süre sonra kapanır.
- **Seçim:** (b), 8 sn. Uyarıyı okuyup "Ayarlar"a dokunmaya yetecek kadar uzun.
- **Neden:** Kod bu varsayılan değişmeden önce yazılmıştı ve iOS ipucuna açıkça `duration: 8 s` verilmişti, yani amaç kendiliğinden kapanmasıydı. Kalıcı uyarı alttaki kontrolleri örtüyor. Geri almak için `persist: false` satırlarını silmek yeterli.

### A14 — Karma test (Android bebek ↔ iOS ebeveyn) ağ kesintisini atlıyor
- **Seçim:** `--platform mixed` iki tarafa da `E2E_SKIP_NETWORK_DROP=true` veriyor.
- **Neden:** Ağ kesintisi adımı iki cihazın eş zamanlı ilerlemesine bağlı. iOS simülatöründe uçak modu yok (simülatör Mac'in ağını kullanıyor). Bu adım Android ↔ Android koşusunda test ediliyor.

### A15 — `sound_stream` (GPL-3.0) yerine `record` (BSD-3) + kendi küçük oynatıcımız
- **Karar (Cavid):** Değiştir; MIT/BSD/Apache lisanslı bir paket, Android ve iOS'ta çalışsın, iPhone bebek modunda da ağlama algılansın. `fix/audio-license`'taki ilk sürüm (yalnızca Android platform kanalı) cherry-pick ile `dev`'e alındı ve bu karara göre genişletildi.
- **Mikrofon:** `record` 7.2.0 (BSD-3-Clause, alt paketleri de BSD-3).
  - Biçim: 16 kHz, mono, PCM16 little-endian (`PcmMicrophone`).
  - Android: kaynak `MIC`, Bluetooth SCO kapalı (eski davranış).
  - iOS: eklenti kaydında ses motoru açmıyor (B63 riski yok); durdurunca ses oturumunu kapatmıyor (WebRTC'yi bozmuyor).
- **Oynatıcı (offline ebeveyn, yalnızca Android):**
  - Kendi kısa `AudioTrack` kanalımız (`OfflineAudio.kt`): medya akışı, `MODE_NORMAL`, yazmalar ayrı thread'de.
  - Lisanslı bir PCM oynatıcı paketi yerine bu seçildi. Offline yalnızca Android'de; `flutter_sound` ise MPL-2.0.
- **iPhone (ve Android) bebekte ağlama algılama:** Ölçüm sonucu (iOS simülatörü, `integration_test/webrtc_audio_level_test.dart`): WebRTC, ebeveyn bağlı değilken mikrofonu hiç açmıyor; ses seviyesi tam 0. Bağlıyken gerçek değerler geliyor. Bu yüzden:
  - **Ebeveyn yokken (bekleme):** `record` ile ölçülüyor; her 250 ms'de bir son parçaların en yüksek dB'i, aynı dB ölçeği.
  - **Görüşmede:** WebRTC'nin `audioLevel`'ı (eskisi gibi).
  - **Geçiş:** İkisi asla aynı anda mikrofonu tutmuyor. `WebRTCService.beforeBabyCall`, görüşme kurulmadan önce `record`'u durduruyor; `onBabyStandby`, bekleme peer'ı kurulunca başlatıyor. iOS'ta geçiş simülatörde doğrulandı: `record` durduktan sonra WebRTC yine ses yakalıyor.
  - **Bağlantı koparsa** (ebeveyn uygulamayı kapattı, ICE failed): Bebek bozuk peer'ı kapatıp beklemeye geçiyor, mikrofon `record`'a dönüyor. Bu sayede ağlama algılanmaya ve push gönderilmeye devam ediyor. Eskiden bozuk peer açık kalıyordu; ICE restart olmadığı için zaten kurtarılamıyordu. Ebeveyn yeni bir oturumla geri gelince yeni offer gidiyor (B08 protokolü aynı).
  - **Zaman sınırları:** Mikrofonun başlatılması 5 sn, durdurulması 3 sn ile sınırlı; görüşme öncesi bekleme 8 sn. Yanıt vermeyen bir mikrofon görüşmeyi kilitleyemez.
  - **Simülatör:** iOS simülatöründe (debug) bekleme ölçeri kapalı, çünkü iki simülatörlü E2E'de CoreAudio riski var (BLOCKERS 4). E2E sahte ses kancası kullanıyor.
- **Doğrulama:**
  - Unit testler.
  - Android emülatörü ve iOS simülatöründe `integration_test/audio_smoke_test.dart`.
  - iOS simülatöründe `webrtc_audio_level_test.dart`.
  - Telefon: TEST_PLAN G-AI (AI-8, AI-10, P3) ve offline için 3.11 (2. Android gerekli).

### A16 — Lisans taraması (`pubspec.lock`, 165 paket)
- **Sonuç:** BSD-3-Clause 110 (+8 Flutter SDK paketi), MIT 37, Apache-2.0 4, BSD-2-Clause 4, MPL-2.0 2. **GPL/LGPL/AGPL lisanslı paket yok.**
- **Kaldırılan:** `sound_stream` 0.4.2 (GPL-3.0).
- **Eklenen:** `record` 7.2.0 ve `record_*` alt paketleri, hepsi BSD-3-Clause.
- **MPL-2.0 olanlar:** `dbus` 0.7.15 ve `upower` 0.7.0. `battery_plus`'ın Linux tarafı için dolaylı bağımlılık; Android/iOS'ta kullanılmıyorlar. Tarayıcı bunları "GPL" diye işaretledi, çünkü MPL metni GPL'den "ikincil lisans" olarak bahsediyor. Değiştirilmeden kullanıldıkça sorun yok.
- **Kapsam dışı:** Yerel SDK'lar (Google Play Services / Nearby, Firebase, libwebrtc) Dart paketi değil, taranmadı. Hiçbiri GPL değil.

### A17 — iOS imzalama, push entitlement'ı ve APNs kaydı
- **İmzalama:** Runner hedefinde Debug/Release/Profile için `CODE_SIGN_STYLE = Automatic`. Team'i Cavid Xcode'da seçecek.
- **Entitlements:**
  - `ios/Runner/Runner.entitlements` içinde `aps-environment = development`, üç yapılandırmada da `CODE_SIGN_ENTITLEMENTS`.
  - Tek dosya kullanılıyor. Otomatik imzalamada Xcode, App Store/TestFlight için arşivlerken bunu `production`'a çeviriyor.
  - Ayrı bir "Release = production" dosyası, Xcode'dan geliştirme profiliyle release çalıştırmayı bozardı.
  - Background Modes (`audio`, `remote-notification`) Info.plist'te; tüm yapılandırmalar için geçerli.
- **Bundle ID:** Xcode'da ve `GoogleService-Info.plist`'te ikisi de `com.feyruz.bebekmonitorclean`. Plist'e dokunulmadı.
- **APNs kaydı (B69):**
  - firebase_messaging, uygulamanın "açılış bitti" bildiriminde APNs'e kaydoluyor. UIScene geçişinden sonra eklentiler bu bildirimden sonra kaydediliyor; bu yüzden kayıt büyük olasılıkla hiç yapılmıyor.
  - Çözüm: Dart, FCM token istemeden önce `PushRegistration.ensureApnsToken()` ile kaydı kendisi istiyor (AppDelegate'teki `bebek_monitor/push` kanalı) ve APNs token'ını 10 sn'ye kadar bekliyor. Token'ı Firebase'in app delegate proxy'si alıyor.
  - Eklenti token'ı zaten almışsa bu adım atlanıyor.
  - Simülatör APNs'e yanıt vermediği için bu zincir yalnızca gerçek iPhone'da doğrulanabilir (TEST_PLAN P1–P3). Loglar: `Push: FCM token stored in room` ya da `APNs token not available ... (registration: ...)`.

## Cavid'in kararı bekleniyor

- **D4 TURN:** Telefondaki farklı ağ testinin (TEST_PLAN AI-11/AI-12, G2) sonucuna göre karar verilecek.
- **7. adım (D1-b foreground service):** Telefon test sonuçlarından sonra.

## Karara bağlananlar

- **`sound_stream` GPL-3.0:** Değiştir (A15).
- **Android ↔ iOS offline:** Şimdilik yok. PLAN_NEXT.md §6'da "sonra" olarak duruyor.
- **Function bölgesi:** Firestore `eur3` → `europe-west1`. Blaze, Anonymous giriş ve APNs anahtarı tamam (Cavid, 22.11). Firestore kuralları telefon testinden sonra yayınlanacak.
