# BUGS.md — Bulgular ve ilerleme

> Bu dosya, oturum kesilirse kaldığımız yerden devam edebilmek için tutuluyor. Branch: `dev`. Push yapılmadı.
> Satır numaraları, maddenin yazıldığı andaki koda (`cd3af29`) göre verildi. Sonraki düzeltmeler satırları kaydırmış olabilir; fonksiyon adları her zaman doğrudur.

## İlerleme

- [x] ADIM 1: Onaylanan temizlik. Commit'ler: 3A `474ef31`, 3B `6f72d30`, WifiDirect kaldırma `9cc1419`, ölü kod `a4b75e3`. Analyze 0 error, 0 warning; build ✅
- [x] ADIM 2: Derin kod incelemesi (bu dosya)
- [x] ADIM 3: Otomatik testler. Commit'ler: `451e421`, `cd3af29`. 36 test ✅
- [ ] ADIM 4: Güvenli düzeltmeler (devam ediyor; sıradaki: B12, B13, B14, sonra Orta maddeler)
- [ ] ADIM 5: TEST_PLAN.md
- [ ] ADIM 6: REPORT.md

## Karar günlüğü

Kullanıcı yokken alınan kararlar:

- **K1:** README İngilizce olduğu için "Wi-Fi Direct" ifadesi İngilizce karşılığıyla değiştirildi: "offline mode (Nearby Connections: Bluetooth + Wi-Fi)".
- **K2:** `noise_meter` paketi artık hiçbir yerde import edilmiyor. Pubspec'ten yine de **kaldırılmadı**, çünkü bağımlılık kaldırmak bu turun kapsamı dışında (bkz. B50).
- **K3:** Mod değişiminde eski `WebRTCService`, UI artık onu kullanmıyorken çizilen bir kareden sonra (`endOfFrame`) dispose ediliyor. Amaç, dispose edilmiş renderer'ın ekranda kalmasını önlemek.
- **K4:** WifiDirect kaldırıldıktan sonra derlenmiş manifest karşılaştırıldı. İzin ve bileşen listesi **birebir aynı**: flutter_p2p_connection manifest'e hiç izin eklemiyormuş; Nearby/Wi-Fi/Bluetooth izinleri uygulamanın kendi manifest'inde. APK içinde p2p sınıfı kalmadı.
- **K5:** Test için saf fonksiyonlar ayrıldı: `lib/core/offline/offline_payload.dart` ve `lib/core/audio/audio_level.dart`. Davranış değişmedi. l10n tablosu testlerde `@visibleForTesting debugLocalizedValues` ile okunuyor.
- **K6:** Eski şablon `test/widget_test.dart` zaten kırıktı (provider ve Firebase'siz HomeScreen kuruyordu). Yerine SettingsSheet ve NoiseLevelBar smoke testleri yazıldı. HomeScreen, kamera/pil/Firebase eklentileri gerektirdiği için widget testine alınmadı.

## Önem ve durum anahtarı

- **Önem:**
  - **Kritik:** çoğu kullanıcıda çekirdek özellik bozuk, ya da güvenlik/gizlilik sorunu.
  - **Yüksek:** yaygın bir senaryoda özellik bozuk.
  - **Orta:** belirli koşullarda hata, kaynak sızıntısı ya da kötü deneyim.
  - **Düşük:** kozmetik ya da gizli risk.
- **Durum:** Açık · Düzeltildi (commit) · Cihazda doğrulanmalı · Karar bekliyor

---

## Kritik

### B01 — Bebek cihazında foreground service yok; ekran kapanınca ya da uygulama arka plana geçince yayın duruyor
- **Dosya:** `android/app/src/main/AndroidManifest.xml` (tamamı), `MainActivity.kt:5`. Derlenmiş manifest'te ne `FOREGROUND_SERVICE` iznine ne de `<service foregroundServiceType>` tanımına rastlanmıyor.
- **Sorun:** Tek koruma `WakelockPlus.enable()` (`home_screen.dart` içinde `_createRoomCode` ve `_startAdvertising`). Bu sadece uygulama ön plandayken işe yarıyor:
  - Android 9+ arka plandaki uygulamaların kamera ve mikrofon erişimini kesiyor.
  - Android 14 ise `foregroundServiceType="camera|microphone"` ile `FOREGROUND_SERVICE_CAMERA` ve `FOREGROUND_SERVICE_MICROPHONE` izinlerini istiyor.
- **Nasıl ortaya çıkar:** Bebek telefonunda güç tuşuna basılırsa, Home'a dönülürse ya da arama gelirse ebeveyn tarafında görüntü donar veya kararır, ses kesilir. Ağlama algılama da durur. Kullanıcıya hiçbir uyarı gösterilmez.
- **Öneri:** Bkz. "Karar bekleyen konular – D1".
- **Risk:** Yüksek (yaşam döngüsü ve kamera sahipliği değişiyor).
- **Durum:** Karar bekliyor

### B02 — FCM hiç gönderilmiyor; uygulama kapalı ya da dondurulmuşken ebeveyne bildirim gelmiyor
- **Dosya:**
  - `notification_service.dart:109`: `getFCMToken()` hiçbir yerden çağrılmıyor.
  - `firestore_signaling.dart` `sendAlert`: alarm sadece bir Firestore dokümanı olarak yazılıyor.
  - Repoda `functions/` klasörü yok.
- **Sorun:** Alarmlar ebeveyne yalnızca uygulama içindeki Firestore dinleyicisi üzerinden, yerel bildirim olarak ulaşıyor. `onMessage` ve `onBackgroundMessage` hiçbir zaman tetiklenmiyor. Offline modda da aynı durum var: Nearby payload'u için uygulama sürecinin canlı olması gerekiyor.
- **Nasıl ortaya çıkar:**
  - Ebeveyn uygulamayı kapatmışsa hiç bildirim gelmez.
  - Ekran kilitliyse bildirimler yalnızca Android süreci dondurana kadar gelir (Doze). Bunun ne kadar sürdüğü cihazda doğrulanmalı.
- **Öneri:** Bkz. D2.
- **Risk:** Orta (Blaze planı ve backend deploy gerektiriyor).
- **Durum:** Karar bekliyor

### B03 — Kimlik doğrulama yok, 6 haneli oda kodu tahmin edilebilir, Firestore kuralları repoda yok
- **Dosya:** `pairing_service.dart:31` (kod 100000–999999 arasında). `firebase_auth` bağımlılığı yok. Repoda `firestore.rules` dosyası yok.
- **Sorun:** Oda kodunu bilen ya da tahmin eden herkes `rooms/{kod}` dokümanını okuyabilir ve answer yazarak bebek kamerasının görüntüsünü ve sesini alabilir. Kurallar Firebase konsolunda kontrol edilmeli. Kimlik doğrulama olmadığı için kurallar da kimin kim olduğunu ayırt edemez.
- **Nasıl ortaya çıkar:** Odalar toplu olarak listelenebilir ya da kaba kuvvetle denenebilir (900 bin olasılık).
- **Öneri:** Bkz. D3.
- **Risk:** Orta.
- **Durum:** Karar bekliyor. Konsoldaki kurallar doğrulanmalı.

## Yüksek

### B04 — Bebek cihazı kendi ağlama alarmının bildirimini (sesli) alıyor
- **Dosya:**
  - `home_screen.dart:533`: `setSignalingService` her iki rol için de çağrılıyor.
  - `firestore_signaling.dart:76-81`: eklenen her alert dokümanı yayınlanıyor. Firestore yerel yazımı anında "added" olarak bildiriyor.
- **Nasıl ortaya çıkar:** Bebek ağlayınca bebeğin yanındaki telefon da yüksek öncelikli, sesli bir bildirim çalar.
- **Öneri:** Alert dinleyicisinde `hasPendingWrites` olan yerel yazımları atlamak.
- **Risk:** Düşük.
- **Durum:** Düzeltildi (`fb29391`) — yerel (hasPendingWrites) alert yazımları atlanıyor. Cihazda doğrulanmalı.

### B05 — Ağlama sürdükçe 2 saniyede bir alert dokümanı ve bildirim gönderiliyor
- **Dosya:** `home_screen.dart:1508-1525` (`_processNoiseLevel`): `statusChanged || timeToUpdate` doğruysa `if (alert) sendAlert(...)` çalışıyor.
- **Nasıl ortaya çıkar:** Ebeveyn bir dakikada yaklaşık 30 sesli bildirim alır. Firestore'a da her 2 saniyede bir doküman yazılır.
- **Öneri:** Alarmı sadece sessiz→ağlıyor geçişinde göndermek, araya en az 60 sn bekleme koymak. Oda dokümanındaki `cryAlert`/`cryDb` güncellemesi (gösterge çubuğu için) olduğu gibi kalır.
- **Risk:** Düşük. Davranış daralır, genişlemez.
- **Durum:** Düzeltildi (`56a2919`) — 60 sn cooldown; offline ebeveyndeki aynı spam (overlay her 2 sn sıfırlanınca yeni sistem bildirimi) de bu commit'le sınırlandı. Overlay/titreşim/ses çubuğu değişmedi. Cihazda doğrulanmalı.

### B06 — Bebek kendi offer'ını görünce `_isCaller=false` oluyor; sonraki ICE adayları yanlış koleksiyona yazılıyor
- **Dosya:** `firestore_signaling.dart:59-64` (`connect` içinde offer alınınca `_isCaller = false`).
- **Sorun:**
  - Bebek `sendOffer` ile offer'ı yazınca kendi dinleyicisi aynı offer'ı görüyor ve kendini callee sanıyor.
  - Bu andan sonra üretilen adaylar (genelde STUN'dan gelen srflx adayları) `calleeCandidates` koleksiyonuna yazılıyor. Bu koleksiyonu bebeğin kendisi dinliyor.
  - Sonuç: ebeveyn bebeğin geç gelen adaylarını hiç almıyor, bebek de kendi adaylarını "uzak aday" olarak ekliyor.
- **Nasıl ortaya çıkar:** Aynı Wi-Fi'da çoğunlukla yine bağlanır (peer-reflexive adaylar sayesinde). Farklı ağlarda bağlantı kurulamama ihtimali artar.
- **Öneri:** Gelen offer'da rolü sadece kendimiz offer göndermemişsek değiştirmek.
- **Risk:** Düşük.
- **Durum:** Düzeltildi (`31778e4`) — `_sentOffer` bayrağı. Cihazda doğrulanmalı (farklı ağlarda bağlantı başarısı).

### B07 — Sadece STUN var, TURN yok
- **Dosya:** `webrtc_service.dart:73-78`, `multi_peer_service.dart:43`.
- **Sorun:** Simetrik NAT, CGNAT (mobil operatörler) ya da kurumsal ağlarda doğrudan P2P kurulamaz.
- **Nasıl ortaya çıkar:** Ebeveyn mobil veride, bebek ev Wi-Fi'ındayken bağlantı "bekleniyor" durumunda kalır ya da ICE failed hatası verir.
- **Öneri:** Bkz. D4.
- **Durum:** Karar bekliyor

### B08 — Ebeveyn aynı odaya yeniden katılınca bağlantı kurulmuyor
- **Dosya:**
  - `webrtc_service.dart` `startAsParent`: odadaki eski offer'a cevap veriyor.
  - `startAsBaby` → `_answerSub`: `existingRemote != null` ise yeni answer'ı yok sayıyor.
  - `pairing_service.dart` `setPaired(false)`: offer ve answer alanlarını temizlemiyor.
- **Sorun:** Ebeveyn bağlantıyı kesip aynı kodla tekrar katılırsa bebek hâlâ eski peer connection'ı tutuyor ve yeni answer'ı kabul etmiyor. Bebek yeni bir offer üretmediği için bağlantı kurulamıyor.
- **Nasıl ortaya çıkar:** Bağlantı koptuğunda (Wi-Fi değişimi, uygulamanın yeniden açılması) ebeveynin yeniden bağlanabilmesi için bebek tarafında oda yeniden oluşturulmalı.
- **Öneri:** Bebek, `isPaired` false olduğunda ya da peer bağlantısı `failed/disconnected` durumuna geçtiğinde aynı odada yeni bir offer üretsin (ICE restart veya yeni peer connection). Eski answer ve adaylar temizlensin. Bu sinyal protokolünü değiştiren orta büyüklükte bir iş olduğu için bu turda yapılmadı.
- **Risk:** Orta.
- **Durum:** Açık (güvenli yerel düzeltme değil)

### B09 — ~~Nearby BYTES payload sınırı (32 KB) HIGH kalitede aşılabilir~~ → **geçersiz**
- **Dosya:** `home_screen.dart` `_processAndSendImage`.
- **Sorun (ilk tahmin):** 32 KB sınırı. **Doğrulama:** projede kullanılan `play-services-nearby 19.2.0` içinde `ConnectionsClient.MAX_BYTES_DATA_SIZE = 1047552` (~1 MB; `javap` ile sabit okundu). HIGH kalite JPEG (~40-60 KB) bu sınırın çok altında.
- **Kalan not:** 15 fps × ~50 KB ≈ 750 KB/s; Nearby Bluetooth'a düşerse bant genişliği yetmeyebilir (gecikme/kare kaybı) → TEST_PLAN'da ölçülecek.
- **Durum:** Kapatıldı (sorun değil, kod değişmedi)

### B10 — Her kamera karesi için yeni bir `compute` isolate'ı açılıyor, eşzamanlılık sınırı yok
- **Dosya:** `home_screen.dart:975` (`await compute(_processImageInIsolate, ...)`), `_startImageStream`.
- **Sorun:** Dönüştürme FPS aralığından uzun sürerse isolate'lar üst üste biner. CPU, bellek ve ısı artar, gecikme birikir, kareler sırasız gelebilir.
- **Öneri:** Önceki kare bitene kadar yenisini atlamak (in-flight bayrağı).
- **Risk:** Düşük.
- **Durum:** Düzeltildi (`d0ac84f`) — `_frameInFlight` bayrağı; işlem sürerken gelen kareler atlanıyor. Cihazda doğrulanmalı (FPS/gecikme).

### B11 — Sessiz, boş ya da tek sayıda bayt içeren PCM parçasında dB = -Infinity/NaN veya RangeError
- **Dosya:** `lib/core/audio/audio_level.dart` `pcm16ChunkToDb` (eskiden `home_screen.dart` `_calculateAndSendDb`).
- **Sorun:**
  - `rms=0` ise `log(0)` = -Infinity olur.
  - Boş parçada 0/0 = NaN olur.
  - Tek sayıda bayt varsa `Int16List.view` RangeError atar.
  - `jsonEncode(-Infinity/NaN)` da hata atıyor. Bu hatalar ses dinleyicisinde yakalanmıyor.
- **Nasıl ortaya çıkar:** Mikrofon tamamen sessizse ya da sürücü sıfır döndürüyorsa STATUS mesajı gönderilemez ve ebeveyn tarafında ses çubuğu donar. Loglarda yakalanmamış hata görülür.
- **Öneri:** rms ≤ 0 ise 0 döndürmek, son tek baytı atmak.
- **Risk:** Düşük.
- **Durum:** Düzeltildi (`ffeab24`) + unit test.

### B12 — Offline bebek modunda mikrofon izni istenmiyor; açılışta izin istekleri çakışıyor
- **Dosya:**
  - `home_screen.dart:756-800` (`_checkP2PPermissions`): kamera ekleniyor ama `Permission.microphone` eklenmiyor.
  - `home_screen.dart:145-148`: `_initAudioServices()` (sound_stream `initialize` RECORD_AUDIO istiyor) ile `_setup()` (kamera CAMERA istiyor) paralel çalışıyor.
- **Sorun:** Android aynı anda gelen ikinci izin isteğini düşürüp boş sonuç dönebiliyor.
- **Nasıl ortaya çıkar:** İlk açılışta kamera hata verebilir, ya da offline bebek sessiz yayın yapar ve ağlama algılama çalışmaz. Hata gösterilmez.
- **Öneri:** Offline listeye mikrofon eklemek. Kamera kurulumu bitince ses servislerini başlatmak (sıralı).
- **Risk:** Düşük.
- **Durum:** Açık. Cihazda doğrulanmalı.

### B13 — Kayıt başlatılırken ya da durdurulurken hata olursa uygulama "kayıtta" durumunda takılıyor
- **Dosya:** `video_recorder_service.dart:35-44, 53-54`.
- **Sorun:** `_mediaRecorder = MediaRecorder()`, `start()` çağrılmadan önce atanıyor. `start` hata atarsa (iOS'ta, video track yoksa `.first` StateError verirse, native hata olursa) `isRecording` kalıcı olarak true kalıyor.
- **Nasıl ortaya çıkar:** Kayıt butonu uygulama yeniden başlatılana kadar kilitlenir.
- **Öneri:** Hata olursa `_mediaRecorder = null`, stop için `finally`.
- **Risk:** Düşük.
- **Durum:** Açık

### B14 — Kayıt; bağlantı kesilince, mod değişince ya da dispose'da durdurulmuyor
- **Dosya:** `home_screen.dart` `_toggleRecording` (durdurma yalnızca burada) ve `_resetPairing`. Durdurma dalı, kayıt başladığı andaki modu değil o anki `_isOfflineMode` değerini kullanıyor.
- **Nasıl ortaya çıkar:** mp4 düzgün kapanmaz ve oynatılamaz, kaydedici takılı kalır.
- **Öneri:** Kayıt türünü servis içinde saklamak (`stopAny()`), `_resetPairing` ve dispose içinde çağırmak.
- **Risk:** Düşük.
- **Durum:** Açık

### B15 — Çoklu kamera (multi-camera) normal eşleşme akışıyla uyumsuz; yeniden anlaşma döngüsü
- **Dosya:** `multi_peer_service.dart:71-88`, `firestore_signaling.dart:54-65`, `webrtc_service.dart` `_answerSub`.
- **Sorun:**
  - Bebek yalnızca ilk answer'ı kabul ediyor. Ebeveyn zaten bağlıysa multi-camera "bağlanıyor" durumunda kalıyor.
  - Multi-camera önce cevap verirse normal ebeveyn akışını bozuyor.
  - MultiPeer, her oda snapshot'ında tekrar answer üretiyor (guard yok). Bu bir yazma → snapshot → yazma döngüsü oluşturuyor.
  - Tüm kameraların sesi aynı anda çalıyor.
  - Alarm desteği yok.
- **Öneri:** Bkz. D6. En az düzeltme olarak MultiPeer'e remote description guard'ı eklenebilir.
- **Durum:** Karar bekliyor

### B16 — WebRTC kayıtlarında ses yok
- **Dosya:** `video_recorder_service.dart:38-44`: `_mediaRecorder!.start(filePath, videoTrack: ...)` çağrısında `audioChannel` verilmiyor.
- **Sorun:** flutter_webrtc Android'de `audioChannel: RecorderAudioChannel.OUTPUT` parametresini destekliyor. Koddaki "ses desteklenmiyor" yorumu yanlış.
- **Nasıl ortaya çıkar:** Ebeveynin kaydettiği video sessiz.
- **Öneri:** `audioChannel: RecorderAudioChannel.OUTPUT` eklemek. Yeni davranış eklediği için cihazda denenmeden yapılmadı.
- **Risk:** Düşük.
- **Durum:** Açık. Cihazda doğrulanmalı.

### B17 — iOS'ta WebRTC kaydı hiç çalışmıyor
- **Dosya:** `video_recorder_service.dart:41`. flutter_webrtc 0.12.12, `startRecordToFile`'ı yalnızca Android'de uyguluyor.
- **Nasıl ortaya çıkar:** iOS'ta "MissingPluginException" hata mesajı görülür.
- **Öneri:** iOS'ta kayıt butonunu gizlemek ya da başka bir kaydedici kullanmak (ürün kararı).
- **Durum:** Karar bekliyor

## Orta

### B18 — Mod değişiminde eski `WebRTCService` dispose edilmiyordu (renderer sızıntısı)
- **Dosya:** `home_screen.dart` `_initCoreServices`.
- **Durum:** Düzeltildi (`9cc1419`). Offline modda artık `WebRTCService` oluşturulmuyor.

### B19 — Pil aboneliği saklanmıyor ve iptal edilmiyor; timer ve listener `mounted` kontrolü yapmadan `setState` çağırıyor
- **Dosya:** `home_screen.dart:152-178` (`_initBatteryMonitoring`). `_batteryStateSubscription` tanımlı ama hiç atanmıyor.
- **Nasıl ortaya çıkar:** Ekran dispose olduktan sonra "setState() called after dispose" hatası; abonelik sızıntısı. `batteryLevel` platform hatasında yakalanmamış istisna atıyor.
- **Öneri:** Aboneliği saklamak, `mounted` kontrolü, try/catch.
- **Risk:** Düşük.
- **Durum:** Açık

### B20 — Offline bebek modunda her ses parçasında `setState` çağrılıyor
- **Dosya:** `home_screen.dart:915-935` (`_calculateAndSendDb`).
- **Sorun:** sound_stream saniyede onlarca parça gönderiyor ve her parça tüm HomeScreen'i yeniden çiziyor.
- **Nasıl ortaya çıkar:** Bebek cihazında gereksiz CPU kullanımı, pil tüketimi ve ısınma.
- **Öneri:** UI güncellemesini mesaj gönderimiyle aynı 200 ms aralığına bağlamak; alarm durumu değişince hemen güncellemek.
- **Risk:** Düşük.
- **Durum:** Açık

### B21 — Firestore dinleyicisi `offer: null`/`answer: null` yüzünden her snapshot'ta hata atıyor
- **Dosya:** `pairing_service.dart:44-45` (`'offer': null, 'answer': null` yazılıyor), `firestore_signaling.dart:59, 68` (`containsKey` kontrolü true döndükten sonra `offerMap['sdp']` null üzerinde çağrılıyor).
- **Sorun:** Offer ya da answer gelene kadar her oda güncellemesinde (cryAlert her 2 saniyede bir) NoSuchMethodError oluşuyor. Offer gelince de answer null olduğu için hata devam ediyor.
- **Öneri:** `if (data['offer'] is Map)`.
- **Risk:** Düşük.
- **Durum:** Düzeltildi (`a1b3e4b`).

### B22 — Ebeveyn bağlanınca eski alarmlar yeniden bildirim olarak geliyor; `closeRoom` alarmları silmiyor
- **Dosya:** `firestore_signaling.dart:76-81` (ilk snapshot mevcut tüm dokümanları "added" olarak getiriyor), `pairing_service.dart:57-68`.
- **Nasıl ortaya çıkar:** Ebeveyn odaya bağlandığı ya da yeniden bağlandığı anda "bebek ağlıyor" bildirimleri gelir.
- **Öneri:** İlk snapshot'ı atlamak. `closeRoom` içinde `alerts` alt koleksiyonunu da silmek.
- **Risk:** Düşük.
- **Durum:** Düzeltildi (`199bb77`) — ilk snapshot + bağlantıdan 30 sn önceki alarmlar atlanıyor; `closeRoom` alerts'i de siliyor. Cihazda doğrulanmalı.

### B23 — `FirestoreSignaling.connect` eski abonelikleri iptal etmiyor; dinleyicilerde `onError` yok
- **Dosya:** `firestore_signaling.dart:54, 76`, `pairing_service.dart` `watchRoom`, `home_screen.dart:1602`.
- **Nasıl ortaya çıkar:** `connect` ikinci kez çağrılırsa alarm ve offer olayları çift gelir. Firestore izin hatası, yakalanmamış istisnaya dönüşür.
- **Öneri:** `connect` içinde önce iptal etmek, `onError` ile loglamak ve UI'a hata göstermek.
- **Risk:** Düşük.
- **Durum:** Düzeltildi (`7687a9b`).

### B24 — Yayın kapanınca wakelock açık kalıyor
- **Dosya:** `home_screen.dart:597, 850` (enable), `_resetPairing` (disable yok).
- **Nasıl ortaya çıkar:** Bağlantı kesildikten sonra da ekran kapanmaz ve pil tükenir.
- **Öneri:** `_resetPairing` içinde, "Ekranı açık tut" ayarı kapalıysa wakelock'u kapatmak.
- **Risk:** Düşük.
- **Durum:** Açık

### B25 — `HomeScreen.dispose` bazı kaynakları kapatmıyor
- **Dosya:** `home_screen.dart:320`.
- **Sorun:** `_noisePollTimer`, `_audioSub`, recorder/player, `_currentImageBytesNotifier` kapatılmıyor; Nearby durdurulmuyor.
- **Öneri:** Hepsini dispose içinde kapatmak.
- **Risk:** Düşük.
- **Durum:** Açık

### B26 — `_onDisconnected` içinde `stopImageStream` await edilmiyor ve try/catch yok
- **Dosya:** `home_screen.dart:1164`.
- **Sorun:** Stream çalışmıyorsa CameraException fırlatıyor ve bu yakalanmıyor.
- **Öneri:** Yalnızca stream çalışıyorsa durdurmak, try/catch eklemek.
- **Risk:** Düşük.
- **Durum:** Açık

### B27 — Alarm, eşiği tek bir ölçümün aşmasıyla tetikleniyor (süre şartı yok)
- **Dosya:** `home_screen.dart:1488-1500` (`_processNoiseLevel`), `_calculateAndSendDb`. `_noiseAboveSince` hesaplanıyor ama hiç kullanılmıyor.
- **Nasıl ortaya çıkar:** Kapı çarpması, öksürük ya da tek bir gürültü yanlış alarm üretir.
- **Öneri:** Bkz. D5.
- **Durum:** Karar bekliyor

### B28 — Online ve offline dB ölçekleri yaklaşık 10 dB farklı
- **Dosya:** `audio_level.dart`.
- **Sorun:**
  - Online: `20·log10(level)+100`, PCM'e göre yaklaşık `20·log10(rms)+9.7`.
  - Offline: `20·log10(rms)`.
  - Aynı eşik (varsayılan 60) offline modda daha az hassas.
- **Öneri:** Bkz. D5. Ölçeklerin cihazda kalibre edilmesi gerekiyor.
- **Durum:** Karar bekliyor

### B29 — Alarm geçmişi: sınırsız büyüme, atomik olmayan yazım, tek bozuk kayıt tüm geçmişi siliyor
- **Dosya:** `alert_history_service.dart:24-58`, `home_screen.dart:1472` (`_recordAlertIfNeeded` ağlama sürdükçe her 5 sn'de bir kayıt ekliyor).
- **Sorun:**
  - Bir saatte yaklaşık 720 kayıt birikebiliyor.
  - Her eklemede dosyanın tamamı yeniden yazılıyor.
  - Yazım sırasında uygulama ölürse ya da tek bir kayıt bozuksa `loadAlerts` boş liste ile devam ediyor; sonraki ekleme tüm geçmişi siliyor.
- **Öneri:**
  - En fazla 500 kayıt tutmak.
  - Kayıtları tek tek, hata toleranslı ayrıştırmak.
  - Önce geçici dosyaya yazıp sonra adını değiştirmek.
  - Yazımları sıraya koymak.
  - Geçmişe kayıt aralığını alarm bekleme süresiyle aynı yapmak (60 sn).
- **Risk:** Düşük.
- **Durum:** Açık

### B30 — `VideoPlayerScreen`: `late` controller dispose'da çöküyor; `mounted` kontrolü yok
- **Dosya:** `video_player_screen.dart:17, 43-52, 83, 97`.
- **Nasıl ortaya çıkar:** Galerideki boş ya da eksik bir dosya açılınca LateInitializationError oluşur. 5 sn içinde geri çıkılırsa dispose sonrası `setState` çağrılır.
- **Öneri:** Nullable controller, `mounted` kontrolü.
- **Risk:** Düşük.
- **Durum:** Açık

### B31 — Galeri: thumbnail future'ları her build'de yeniden oluşturuluyor
- **Dosya:** `video_gallery_screen.dart:201-202, 253-254`.
- **Nasıl ortaya çıkar:** Her `setState` ya da kaydırmada tüm thumbnail'lar yeniden çıkarılır. Galeri yavaşlar ve temp klasör dolar.
- **Öneri:** Future'ları dosya yoluna göre önbelleğe almak.
- **Risk:** Düşük.
- **Durum:** Açık

### B32 — Offline "kayıt" aslında yaklaşık 15 sn'lik 320 px bir GIF
- **Dosya:** `video_recorder_service.dart:161-197`.
- **Sorun:**
  - Çıktı mp4 değil GIF; en fazla 201 kare (`count > 200`), oynatma 10 fps sabit, ses yok.
  - Sınır aşıldıktan sonra da kareler diske yazılmaya devam ediyor.
- **Öneri:** Bkz. D7.
- **Durum:** Karar bekliyor

### B33 — `addOfflineFrame` await edilmiyor; durdurma ile yarış koşulu var
- **Dosya:** `home_screen.dart` (`_processAndSendImage`, `_onPayloadReceived`), `video_recorder_service.dart:94-110`.
- **Sorun:** Paralel yazımlar aynı kare indeksini kullanabiliyor. Stop sırasında yazım sürüyorsa PathNotFoundException fırlıyor.
- **Öneri:** Sayacı await'ten önce artırmak, bekleyen yazımları stop'ta beklemek.
- **Risk:** Düşük.
- **Durum:** Açık

### B34 — Kayıt hataları yutuluyor ve kullanıcıya "başarılı" mesajı gösteriliyor
- **Dosya:** `video_recorder_service.dart:64-69, 133-135, 154-156`, `home_screen.dart` `_toggleRecording`. Başarı mesajı `videoGallery + recordings` metinlerinin birleştirilmesinden oluşuyor ve anlamsız.
- **Durum:** Açık

### B35 — Dil ve tema seçimi kaydedilmiyor; cihaz dili yok sayılıyor
- **Dosya:** `language_provider.dart:4` (her zaman `tr`), `theme_provider.dart`.
- **Öneri:** `shared_preferences` ile kalıcı hale getirmek; varsayılanı cihaz dili yapmak. Yeni bağımlılık eklediği için bu turda yapılmadı.
- **Durum:** Açık

### B36 — `RTCPeerConnectionStateDisconnected` anında FAILED olarak gösteriliyor
- **Dosya:** `webrtc_service.dart:156, 215`.
- **Sorun:** Disconnected durumu çoğunlukla geçici ve kendiliğinden düzeliyor. Kullanıcı yine de hata görüyor.
- **Öneri:** Disconnected'ı CONNECTING olarak göstermek, ancak `failed` gelirse FAILED yapmak. UI davranışını değiştirdiği için B08 ile birlikte ele alınmalı.
- **Durum:** Açık

### B37 — Online modda video ayarları (fps/kalite) WebRTC'ye uygulanmıyor
- **Dosya:** `home_screen.dart:1304-1335`.
- **Sorun:** Ayarlar yalnızca offline JPEG akışını etkiliyor. Online modda Firestore'a yazılıyor ama hiçbir yerde kullanılmıyor.
- **Durum:** Açık (yarım özellik)

### B38 — Firestore'da terk edilmiş odalar ve adaylar silinmiyor
- **Sorun:** Uygulama çökerse ya da öldürülürse `closeRoom` hiç çalışmıyor. TTL ve temizlik görevi yok. Oda dokümanı her 2 sn'de bir yazılıyor; bu da maliyet demek.
- **Öneri:** Bkz. D8.
- **Durum:** Karar bekliyor

### B39 — Offline bağlantı kopunca otomatik yeniden bağlanma yok
- **Dosya:** `home_screen.dart:1157` (`_onDisconnected`).
- **Sorun:** Bebek reklam yapmayı (advertise) sürdürüyor, ama ebeveyn cihazı yeniden aramak ve elle seçmek zorunda.
- **Durum:** Açık (yeni özellik gerektiriyor)

## Düşük

### B40 — Sabit kodlu, l10n dışı metinler
- **Dosya:**
  - `home_screen.dart`: 'Video settings updated…' (1314), 'Baby crying / Noise detected' (1480), 'Bağlantı: ', 'Kamera Kapalı', 'Bağlantı Bekleniyor', 'BEBEK AĞLIYOR!'.
  - `multi_camera_screen.dart`: 'Tap the + button…', 'Add Camera'.
  - `webrtc_service.dart` ve `pairing_service.dart`: Türkçe hata mesajları (servislerde context yok).
- **Durum:** Açık

### B41 — UI'da "Offline Mode (Wi-Fi Direct)" yazıyor
- **Dosya:** `app_localizations.dart` (`offlineMode`, `locationPermissionRequired`).
- **Sorun:** Wi-Fi Direct kaldırıldı, bu metinler artık yanlış.
- **Durum:** Açık

### B42 — Bildirim izni açılışta açıklamasız isteniyor; reddedilirse uyarı yok
- **Dosya:** `main.dart:19`, `notification_service.dart:50-60`.
- **Durum:** Açık

### B43 — Firebase başlatılamazsa yerel bildirimler de çalışmıyor
- **Dosya:** `main.dart:15-22`, `notification_service.dart:18`.
- **Sorun:** `FirebaseMessaging.instance` alan başlatıcısında çağrılıyor.
- **Durum:** Açık (pratikte olası değil)

### B44 — Kayıt izni akışı anlamsız
- **Dosya:** `home_screen.dart:2022-2026`.
- **Sorun:** `manageExternalStorage`, `storage` ve `photos` isteniyor; sonuç kullanılmıyor. `manageExternalStorage` manifest'te tanımlı değil ve Play politikası açısından riskli.
- **Öneri:** `Gal.requestAccess()`.
- **Durum:** Açık

### B45 — Yayın (release) ayarları
- **Sorun:** `applicationId = com.example.bebek_monitor_clean` (Play kabul etmez), release debug anahtarıyla imzalanıyor, google-services eklentisi 4.3.10.
- **Öneri:** Bkz. D9.
- **Durum:** Karar bekliyor

### B46 — Offline mod iOS'ta çöküyor
- **Dosya:** `home_screen.dart:764, 822, 1026, 1116`.
- **Sorun:** `DeviceInfoPlugin().androidInfo` çağrısının önünde platform kontrolü yok. nearby_connections da yalnızca Android'i destekliyor.
- **Öneri:** iOS'ta offline başlatmayı engelleyip mesaj göstermek.
- **Durum:** Açık

### B47 — Bildirim küçük ikonu `@mipmap/ic_launcher`
- **Sorun:** Android'de beyaz kare olarak görünür.
- **Durum:** Açık

### B48 — Alarm geçmişinde gece aralığı filtresi çalışmıyor
- **Dosya:** `alert_history_screen.dart:112-120`.
- **Sorun:** 22:00–06:00 gibi gece yarısını geçen bir aralık boş sonuç veriyor. Filtre her şeyi elediğinde "sonuç yok" metni de gösterilmiyor.
- **Durum:** Açık

### B49 — Galeride silme onaysız
- **Dosya:** `video_gallery_screen.dart`.
- **Sorun:** Tek dokunuş kaydı kalıcı olarak siliyor. `confirmDelete` çeviri anahtarı tanımlı ama kullanılmıyor.
- **Durum:** Açık

### B50 — Kullanılmayan kod ve bağımlılıklar
- **Sorun:** `lib/core/webrtc/signaling_service.dart` hiçbir yerde kullanılmıyor. `noise_meter` bağımlılığı artık import edilmiyor (K2).
- **Öneri:** İkisini de kaldırmak (onayınızla).
- **Durum:** Açık

### B51 — l10n getter'ları `!` kullanıyor; eksik anahtar build sırasında çöker
- **Sorun:** Şu an eksik anahtar yok; TR ve EN'de aynı 143 anahtar var.
- **Durum:** `cd3af29` ile testle korunuyor.

### B52 — iOS: arka plan modları, push entitlement'ı ve Local Network açıklaması eksik
- **Sorun:** `UIBackgroundModes`, `aps-environment` ve `NSLocalNetworkUsageDescription` yok.
- **Durum:** Karar bekliyor (iOS kapsamı)

### B53 — `FullscreenView` görüntü oranı hatalı olabilir
- **Dosya:** `fullscreen_view.dart:46-53`.
- **Sorun:** CameraPreview iki kez `AspectRatio` ile sarılıyor; offline görüntü sabit 9/16 oranında.
- **Durum:** Cihazda doğrulanmalı

### B54 — Ayarlardaki FPS ve kalite dropdown'ları beklenmeyen değerde assert veriyor
- **Dosya:** `settings_sheet.dart`.
- **Sorun:** Uzaktan gelen bir değer 15/30/60 ya da LOW/MEDIUM/HIGH dışındaysa dropdown assert hatası verir.
- **Durum:** Açık

---

## Hiç çalışmayan veya yarım kalmış özellikler

1. **Arka planda izleme:** İki cihazda da yok (B01, B02).
2. **FCM:** Token, `onMessage` ve arka plan handler'ı hiçbir zaman tetiklenmiyor (B02). Bildirime dokunmak sadece `debugPrint` çağırıyor, hiçbir ekranı açmıyor.
3. **Online pil senkronu:** Sadece yorum satırı olarak var (`_sendBatteryUpdate`). Karşı cihazın pili yalnızca offline modda görünüyor.
4. **Online video ayarları:** WebRTC'ye uygulanmıyor (B37).
5. **Kayıt:**
   - iOS'ta WebRTC kaydı yok (B17).
   - Hiçbir kayıtta ses yok (B16).
   - Offline kayıt yaklaşık 15 sn'lik bir GIF (B32).
6. **Multi-camera:** Normal eşleşmeyle çakışıyor, alarm yok, "yeni kameraya geç" kısmı TODO olarak bırakılmış (B15).
7. **Dil ve tema kalıcılığı:** Yok (B35).
8. **Offline'da otomatik yeniden bağlanma:** Yok (B39). Online'da yeniden katılma çalışmıyor (B08).
9. **`WifiDirectSignalingService`:** Hiç bağlanmamıştı. Kaldırıldı (`9cc1419`).

## Karar bekleyen konular (öneriler REPORT.md'de de özetlendi)

- **D1 – Foreground service (B01):**
  - (a) `flutter_foreground_task` ya da kendi Kotlin servisimiz ile `camera|microphone` türünde, kalıcı bildirimli bir servis. Bebek yayını başlayınca açılır.
  - (b) Servis olmadan, "ekran açık kalmalı" uyarısı ve kilitleme. **Öneri: (a).** Önce (b)'deki uyarı eklenebilir.
- **D2 – Arka plan bildirimi (B02):**
  - (a) Ebeveynin FCM token'ı odaya yazılır; Cloud Function `alerts` onCreate olunca yüksek öncelikli FCM gönderir. Blaze planı gerekir.
  - (b) Ebeveyn cihazında da foreground service ile dinlemeye devam etmek. **Öneri: online için (a), offline için (b).**
- **D3 – Güvenlik (B03):**
  - Anonymous Auth eklemek. Odaya `ownerUid`/`viewerUid` yazmak.
  - Firestore kurallarında yalnızca bu uid'lere okuma/yazma izni vermek.
  - Kodu 8+ karakterli (harf+rakam) yapmak, ya da QR ile eşleşmek. **Öneri: Anonymous Auth + kurallar + QR/uzun kod.**
- **D4 – TURN (B07):**
  - (a) Yönetilen TURN servisi (Twilio NTS, Cloudflare Calls, Metered). Kısa ömürlü kimlik bilgileri bir Cloud Function ile üretilir.
  - (b) Kendi coturn sunucumuz. **Öneri: (a).** Kimlik bilgileri istemciye gömülmemeli.
- **D5 – Ağlama algılama (B27, B28):**
  - Ses en az 2–3 sn eşik üstünde kalırsa alarm vermek.
  - Online ve offline ölçeklerini tek formülde birleştirmek (offline'a +9.7 dB eklenerek).
  - Cihazda kalibrasyon yapmak. **Öneri: 2 sn süre şartı + tek ölçek.**
- **D6 – Multi-camera (B15):** Her izleyici için ayrı alt oturum (`rooms/{id}/sessions/{viewerId}`), ya da özelliği şimdilik gizlemek. **Öneri: şimdilik gizlemek.**
- **D7 – Offline kayıt (B32):** ffmpeg_kit veya MediaCodec ile mp4 üretmek, ya da açık bir süre sınırı koymak. **Öneri: kısa vadede süre sınırı ve uyarı.**
- **D8 – Firestore temizliği (B38):** Firestore TTL politikası (`expireAt` alanı) ya da zamanlanmış bir Cloud Function. Oda güncellemesini 2 sn'den 5 sn'ye çıkarmak.
- **D9 – Yayın (B45):** Yeni bir applicationId için Firebase'de yeni bir Android uygulaması ve yeni bir google-services.json gerekir (Firebase ayarlarına dokunmadım). Ayrıca release keystore oluşturulmalı.
