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

## Oturum: Ninni v2 (otonom)

### A18 — Foreground service: eklenti yerine kendi küçük servisimiz
- **Seçenekler:** (a) `flutter_foreground_task` 11.0.3 (MIT), (b) kendi Kotlin servisimiz (`MonitorService.kt`, ~200 satır) + `ninni/monitor_service` kanalı.
- **Seçim:** (b).
- **Neden:** Eklentinin Android tarafı, geri çağırma verilmese bile servis başlarken **ikinci bir `FlutterEngine`** oluşturuyor; bu motor tüm eklentileri (flutter_webrtc, camera, firebase…) yeniden kaydediyor. Kamera/mikrofon/WebRTC'nin aynı süreçte iki kez kaydı cihazda öngörülemeyen sorunlara yol açabilir. Bizim ihtiyacımız yalnızca bildirim + süreç önceliği + wake/Wi-Fi kilidi; iş zaten uygulamanın kendi motorunda.
- **Ayrıntılar:** Tür, verilmiş izinlere göre seçilir (Android 14+ izinsiz `camera`/`microphone` türünü reddeder): bebek `camera|microphone` (+ offline `connectedDevice`), ebeveyn `mediaPlayback`. `stopWithTask=true`: uygulama görev listesinden atılırsa servis de durur (Flutter motoru aktiviteyle birlikte ölüyor). Sistem servisi kendisi yeniden başlatırsa bildirim göstermeden durur. "Durdur" düğmesi yok; bildirime dokununca uygulama açılır.
- **Geri alma:** `MonitorForegroundService` çağrılarını kaldırmak yeterli.

### A19 — `environment.sdk` alt sınırı değişmedi
- PLAN_NEXT §5'teki `^3.12.0` yükseltmesi yalnızca `flutter_foreground_task` içindi; A18 ile gerek kalmadı. Dil sürümü değişmesin diye `^3.6.2` kaldı.

### A20 — Bağlantı koptu alarmının eşikleri (V2 5.6)
- Plan: "disconnected/failed ya da 20 sn kare/ses gelmezse".
- **Seçim:** `failed` → hemen; WebRTC `disconnected` (bizde CONNECTING) / Nearby kopması → 5 sn sonra; bağlıyken 20 sn hiç medya (inbound RTP bayt sayısı artmıyor / offline kare-ses yok) → alarm. Hiç bağlanmamış oturumda alarm yok (o durumda eşleşme hatası gösteriliyor).
- **Neden:** Wi-Fi'daki 1–2 sn'lik takılmalar her seferinde alarm çaldırmasın; 5 sn yine de "hemen" sayılır. Bağlı görünüp medya gelmiyorsa (takılı peer) otomatik yeniden katılma da başlatılıyor.
- Ses: `assets/audio/alarm_connection.wav` (kendi sentezimiz), alarm akışında (Android `USAGE_ALARM`), ses odağı istenmeden; titreşim 3 sn'de bir. "Alarmı sustur" sesi/titreşimi keser, ekran bağlantı dönene kadar kalır. Ekranda ayrıca "Bağlantıyı kes" var (taslakta yok): bebek telefonu tamamen gittiyse ekrandan çıkılabilsin.

### A21 — Firestore kurallarına v2 alanları tek seferde
- `battery` (5.7) şimdi kullanılıyor; `roomName`, `soothe`, `nightLight` (Faz 3) şimdiden eklendi; `alerts`'e `type` (`cry`/`battery`) ve `level`.
- **Neden:** Cavid kuralları bir kez yayınlasın. Yeni alanlar ayrı `update()` ile yazılıyor; kurallar yayınlanmadan önce reddedilseler de ağlama alarmı ve eşleşme etkilenmez.

### A22 — Impeller opt-out
- Depoda ve git geçmişinde `EnableImpeller` / `io.flutter.embedding.android.EnableImpeller` yok. Android zaten Impeller ile çalışıyor; kaldırılacak bir şey yok.

### A23 — iOS'ta uygulamanın kendi sesleri
- `audioplayers` (MIT) iOS'ta tek bir ses oturumu kullanır ve çalma bitince oturumu kapatmayı dener. Global bağlam `playAndRecord` + `mixWithOthers` + `defaultToSpeaker` (WebRTC ile aynı kategori). iOS, çalışan bir ses birimi (WebRTC) varken oturumun kapatılmasını reddeder; yine de alarm/ninni sonrası WebRTC sesinin sürdüğü gerçek iPhone'da doğrulanmalı (TEST_PLAN V2).

### A24 — Sayfa geçişleri: iOS'ta yerel geçiş
- Plan: `animations` ile SharedAxis/FadeThrough. Android'de ve aşamalar arası (rol → kod → canlı) SharedAxis, karşılama → uygulama FadeThrough.
- **iOS'ta itilen sayfalar** (Ayarlar, Geçmiş, Galeri) için Cupertino geçişi kaldı: kaydırarak geri dönme hareketini o taşıyor; SharedAxis bunu kaldırırdı.

### A25 — Karşılama 3: isteğe bağlı izin düğmesi
- Taslakta "Yakındaki cihazlar" satırında yalnızca "Sonra" yazan çerçeveli bir düğme var; plan ise her satırda "İzin ver"/"Verildi" istiyor ve izin penceresi yalnızca kullanıcı "İzin ver"e basınca açılmalı.
- **Seçim:** İsteğe bağlı satırda çerçeveli (ikincil) "İzin ver"; zorunlu satırlarda dolu "İzin ver". Reddedilen izinde "Ayarları aç". Hiçbir izin karşılamayı engellemez ("Hazırım" her zaman açık).
- Dokunma alanı 44 pt (taslaktaki 36 px yerine; plan §2 ≥44).

### A26 — Eski çoklu kamera ekranı
- `multi_camera_screen.dart` + `multi_peer_service.dart` `kMultiCameraEnabled = false` ile zaten kapalıydı ve v2 planında yok. Dosyalar silinmedi (özellik kararı Cavid'in), yeni arayüzden bağlantı yok.

### A27 — HomeScreen'in parçalanması
- PLAN_NEXT.md'de "refactor planı adım 2–6" diye bir bölüm yok (PLAN_NEXT'teki adımlar D1–D3 işleri). Kendi planım:
  1. Tüm mantık `MonitorController`'a (ChangeNotifier) taşındı; kod satır satır korunarak (`setState`/`mounted` küçük ara katmanlarla), böylece B08/B70/D3 davranışı değişmedi.
  2. `BuildContext` gerektiren yerler: snackbar ve diyaloglar uygulama genelindeki `rootMessengerKey`/`rootNavigatorKey` ile.
  3. Ekranlar yalnızca controller'ı okur; aşama (rol seç → bebek kod → bebek canlı / ebeveyn kod → canlı) controller durumundan türetilir (`stageOf`), yönlendirme yok.
  4. Ebeveyn alarmları (ağlama, bağlantı koptu) `MaterialApp.builder` içinde tüm sayfaların üstünde.
- Davranış farkları (bilinçli): bebek rolü seçilince oda hemen kurulur (eskiden menüden); online bebekte kamera önizlemesi yalnızca WebRTC ile (camera eklentisi yalnızca offline); ebeveynin başarısız ilk katılımı kod ekranına döner.

### A28 — Ağlama alarmı ekranı (ebeveyn)
- Yeni bir ağlama başlayınca tam ekran alarm açılır, ses (`alarm_cry.wav`, döngü) + titreşim çalar. Ağlama bitince ses durur ama ekran ebeveyn bir şey seçene kadar kalır ("6 saniyedir" yerine "durdu"). "5 dk sessize al" 5 dk boyunca ekran ve ses açmaz; geçmiş ve bildirimler sürer.
- Bildirim sesi zaten çalıyor; uygulama içi ses yalnızca uygulama açıkken (arka planda bildirim + push).

### A29 — Ninni çalarken ağlama algılama (V2 5.4)
- **Sorun:** Bebek telefonunun çaldığı ses kendi mikrofonuna giriyor; sabit eşikle ninni alarm tetikleyebilir. Ses çıkarma (yankı giderme) bizim ses yolumuz için yok: `audioplayers` WebRTC'nin çalma yolunda değil.
- **Seçenekler:** (a) çalarken algılamayı kapatmak — alarm kaçar, kabul edilemez; (b) eşiği çalan sesin ölçülen seviyesine göre yükseltmek; (c) ses düzeyini sınırlamak.
- **Seçim:** (b) + (c). Ses başlayınca/düzeyi değişince 4 sn ölçülür (alarm sırasındaki örnekler sayılmaz), medyan + 8 dB yeni eşik olur; **en fazla +12 dB**, kullanıcının eşiğinin altına hiç inmez. Ölçüm süresince temkinli olarak +12 dB. Ninni sesi en fazla %70 (`SoothePlayer.maxVolume`).
- **Neden:** Telefonun yanında ağlayan bebek, kısık bir ninniden belirgin biçimde yüksek; +12 dB sınırı alarmın tamamen kaybolmasını önler. 2 sn kuralı ve 60 sn bildirim aralığı aynen geçerli.
- **Test:** `test/soothe_test.dart`; gerçek cihazda TEST_PLAN V3.6–V3.8.

### A30 — QR yalnızca uygulama içinden
- İçerik planlandığı gibi `ninni://join?code=ABCD-EF23`. Ebeveyn "QR kodu okut" ile uygulama içinde okur. Sistem kamerasının bağlantıyı açması için URL şeması kaydı (Android intent filtresi / iOS `CFBundleURLTypes`) **eklenmedi**: ek yapılandırma ve doğrulanmamış bağlantıların uygulamayı açması gerekmiyor. Gerekirse sonra eklenebilir.
- `mobile_scanner` Android'de Google ML Kit (Play Services, ücretsiz) kullanır; paket BSD-3.

### A31 — Bas-konuş (V2 5.3)
- Ebeveyn, bebeğin teklifine cevap vermeden önce ses alıcı-vericisini `sendrecv` yapar (yeniden müzakere yok); düğmeye basınca mikrofon parçası `replaceTrack` ile bağlanır, bırakınca `null` ve mikrofon kapanır (gizlilik göstergesi sürekli yanmasın).
- Bebek tarafında: çağrı kurulunca hoparlör açılır (`Helper.setSpeakerphoneOn(true)`), aksi halde ses kulaklıktan gelirdi. Gelen sesin seviyesi (inbound-rtp `audioLevel` ≥ 0,02) duyulduğu sürece ve 3 sn sonrasına kadar ağlama algılama durur.
- Yalnızca online. Offline (Nearby) tek yönlü PCM akışı olduğu için düğme gizli.
- Ekran okuyucuda basılı tutulamadığı için çift dokunuş konuşmayı açıp kapatır.

### A32 — Gece lambası
- Ebeveyn lambayı açınca bebek telefonu gece moduna geçer (ışık yalnızca orada görünür); parlaklık %25, renk yumuşak radyal dolgu. Kapatınca gece modu sürer, parlaklık en düşüğe iner.

### A33 — Azerbaycanca
- 320 mevcut metin bir alt ajanla çevrildi, yeni metinler elle eklendi; l10n testi üç dilde anahtar ve yer tutucu eşitliğini denetler. "Ayarlar" karşılığı "Parametrlər", "Tamam" karşılığı "Oldu" (Android'in Azerbaycanca karşılıkları). Function push metinleri de AZ.
- Anadili Azerbaycanca olan biri metinleri gözden geçirmeli (BLOCKERS).

### A34 — Kontrast için iki renk tonu
- Plan §6/Faz 4: metin kontrastı ≥ 4,5:1. Açık zemindeki `mintText` (#12936B → **#0B7A57**, 3,7 → 5,0) ve `apricotText` (#C2531F → **#A8461B**, 3,9 → 5,1) koyulaştırıldı. Diğer tüm belirteç çiftleri zaten uygun (`test/contrast_test.dart`). Gece modu saati bilerek sönük: 64 px ince yazı, "büyük metin" sınırı 3:1'i geçiyor.
- Dokunma alanı: plan ≥44; Android yönergesi 48 dp. Simge düğmeleri görünüşte 40–44 kalıp 48'lik dokunma alanı aldı.

### A35 — Performans (bebek cihazı)
- Ses seviyesi saniyede 4–10 kez değişiyor; artık yalnızca ölçeri yeniden çiziyor (`MonitorController.level`), ekranın tamamını değil. Gece modunda bebek telefonu yalnızca gece görünümünü çizer (video önizlemesi ve ölçer yok). Animasyonlar `disableAnimations` ile durur; bebek tarafında sürekli animasyon yalnızca kod ekranındaki nabız noktası.
- Ebeveyn ses çubukları ~10 Hz gelen ses seviyesiyle (WebRTC inbound `audioLevel`), oda alanı (5 sn'de bir) yalnızca yedek.
- Gerçek CPU/ısı ölçümü emülatörde yapılamaz → TEST_PLAN V4.4.

### A36 — v2 lisans taraması
- `pubspec.lock` 180 paket (A16'da 165): GPL/LGPL/AGPL yok. v2'de eklenenler: `audioplayers` + alt paketleri (MIT), `shared_preferences` (BSD-3), `animations` (BSD-3), `qr_flutter` + `qr` (BSD-3), `mobile_scanner` (BSD-3; Android'de Google ML Kit), `flutter_native_splash` (MIT, yalnızca geliştirme). Yazı tipi Plus Jakarta Sans: SIL OFL 1.1 (`assets/fonts/OFL.txt`). Sesler kendi sentezimiz (`assets/audio/LICENSES.md`).

## Cavid'in kararı bekleniyor

- **D4 TURN:** Telefondaki farklı ağ testinin (TEST_PLAN AI-11/AI-12, G2) sonucuna göre karar verilecek.
- **7. adım (D1-b foreground service):** Telefon test sonuçlarından sonra.

## Karara bağlananlar

- **`sound_stream` GPL-3.0:** Değiştir (A15).
- **Android ↔ iOS offline:** Şimdilik yok. PLAN_NEXT.md §6'da "sonra" olarak duruyor.
- **Function bölgesi:** Firestore `eur3` → `europe-west1`. Blaze, Anonymous giriş ve APNs anahtarı tamam (Cavid, 22.11). Firestore kuralları telefon testinden sonra yayınlanacak.
