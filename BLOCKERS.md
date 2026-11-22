# BLOCKERS.md — Çözülemeyen ya da sizden bir şey gereken engeller

> Her biri için: ne denendi, hata, sizden ne lazım.

## 1. iOS simülatöründe gerçek bir "sahte video" kaynağı yok
- **İstenen:** Simülatörde kamera olmadığı için, yalnızca debug'da sahte bir video kaynağı.
- **Denenenler:**
  1. `flutter_webrtc`'nin Dart API'sinde sentetik video kaynağı aranması: yok (`getUserMedia` / `getDisplayMedia` dışında kaynak yok; ekran yakalama iOS'ta broadcast extension gerektiriyor).
  2. Simülatörün kamera desteği: iOS simülatöründe kamera aygıtı yok (`AVCaptureDevice` boş).
  3. Yerel bir yedek: yalnızca debug + iOS simülatöründe kamera açılamazsa **sadece sesli** akışa düşmek (`2cc32a5`). Bu, signaling, peer bağlantısı ve ses yolunu test etmeyi sağlıyor, ama görüntü yok.
- **Kalan:** Gerçek bir sahte video için native tarafta bir `RTCVideoCapturer` (ör. sabit kare üreten) yazmak gerekir. Bu, `flutter_webrtc` iOS koduna müdahale veya ayrı bir eklenti demek; kapsam dışı bıraktım.
- **Sizden:** Gerek yok. iOS görüntüsü gerçek iPhone'da test edilmeli (TEST_PLAN "Gerçek cihaz" listesi).

## 2. iOS simülatöründe uygulama açılışta çöküyordu — ÇÖZÜLDÜ
- **Hata:** `sound_stream` → `AVAudioEngine.mainMixerNode` → `AURemoteIO::Initialize` → `_ReportRPCTimeout` → `abort` (SIGABRT).
- **Denenenler:**
  1. İki simülatör yerine tek simülatör: yine çöküyor.
  2. iOS 27.0 simülatörü: bir denemede açıldı, sonra yine çöktü (şanstı).
  3. Eklentiyi kopyalayıp yalnızca Android'e kısıtlamak: GPL-3.0 kodu repoya girmesin diye yapılmadı.
  4. **Çözüm:** iOS'ta eklenti kaydı `AppDelegate`'te boş bir işlemle değiştirildi (DECISIONS A11).
- **Sizden:** Gerçek iPhone'da açılışı ve ses akışını doğrulayın (TEST_PLAN).

## 3. `flutter build ios --simulator` hatası (Flutter 3.44)
- **Hata:** "Flutter.framework does not contain architectures arm64 x86_64".
- **Durum:** Simülatör için `flutter run`/`flutter test -d <udid>` kullanın (DECISIONS A12). Gerçek cihaz derlemesi etkilenmez.

## 4. iOS simülatöründe ara sıra CoreAudio zaman aşımı (WebRTC)
- **Hata:** Koşu 6'da bebek simülatörü bağlandıktan sonra çöktü. Neden: `WebRTC` → `AudioUnitInitialize` → `AURemoteIO::Initialize` → `_ReportRPCTimeout` → `abort`. Bu, B63'teki CoreAudio zaman aşımıyla aynı; bu kez WebRTC'nin kendi ses birimi tetikledi.
- **Denenenler:**
  1. Tekrar koşmak: koşu 5'te bu adım geçmişti.
  2. Makinede açık kalan üçüncü simülatörü (`baby-ios`, iOS 26.5) kapatıp tekrar koşmak: koşu 7'de iki taraf da sorunsuz bitti.
  3. Uygulama kodu: değişiklik gerekmiyor. Bu, aynı Mac'te birden çok simülatörün ses sunucusunu paylaşmasından kaynaklanan bir simülatör sorunu; gerçek iPhone'da AURemoteIO yerel çalışır.
- **Sizden:** Gerek yok. iOS E2E'yi çalıştırırken yalnızca iki simülatör açık olsun.

## 5. B67 sonrası iOS ↔ iOS tekrar koşusu tamamlanamadı
- **Durum:** Tamamen geçen son iOS ↔ iOS koşusu koşu 7 (`test-results/20261122-025845-ios`). Bu koşu B67 düzeltmesinden önceydi; tek eksik, "Bağlantıyı kes" düğmesine snackbar yüzünden dokunulamamasıydı (B67'yi bu koşu buldu).
- **Denenenler:**
  1. Koşu 8: bebek tarafında oda 40 sn içinde oluşmadı. Makine çok yüklüydü; uygulama kurulumu 4 dk sürdü.
  2. Koşu 9: menü seçimi loglandı ("Oda Kodu Oluştur/Yenile" tıklandı). Koşu bitmeden, süre sınırı ve kullanıcı talimatı nedeniyle durduruldu.
  3. Aynı test kodu Android ↔ Android'de (API 35) ve karma koşuda geçti.
- **Sizden:** Gerek yok. İsterseniz emülatörleri başlatıp `python3 scripts/run_e2e.py --platform ios` ile tekrar koşun (yalnızca iki simülatör açıkken, ~6 dk). Koşu 8'deki gecikme yeniden görülürse yeni bir bug olarak ele alınmalı.

## 6. iOS push zinciri simülatörde doğrulanamıyor
- **Durum:** APNs kayıt isteği gidiyor (`registration=pending`), ama simülatör 15 sn içinde ne token ne hata döndürüyor. Bu yüzden APNs → FCM → oda zinciri (B69) ancak gerçek iPhone'da doğrulanabilir.
- **Denenenler:**
  1. `aps-environment` entitlement'ı eklendi; simülatör derlemesine gömüldüğü doğrulandı.
  2. Eklentinin kendi kaydı ve uygulamanın kayıt çağrısı ayrı ayrı denendi; ikisinde de token gelmedi.
  3. AppDelegate'e kayıt sonucunu döndüren bir tanı kanalı eklendi: sonuç "pending" kaldı.
- **Sizden:** TEST_PLAN G-AI P1–P3 sırasında `iphone_run.log`'da `Push: FCM token stored in room` satırını arayın. Yoksa `APNs token not available ... (registration: ...)` satırını bana gönderin.

## 7. iOS simülatöründe ses testinin bir koşusu açılışta takıldı
- **Durum:** `webrtc_audio_level_test` 4 koşudan 1'inde ilk adımdan önce takıldı; çökme raporu yok. Diğer 3 koşu geçti.
- **Önlem:** Mikrofon başlatma 5 sn, durdurma 3 sn ile sınırlandı; görüşme öncesi bekleme 8 sn. Yanıt vermeyen bir mikrofon görüşmeyi kilitleyemez.
- **Sizden:** Gerek yok. iPhone'da AI-7/AI-8'de görüntü 10 sn içinde gelmezse logu gönderin.

## 8. B70 sonrası Android E2E regresyon koşusu yarıda durduruldu
- **Durum:** Bebeğin bağlantı kopunca beklemeye dönmesi (B70) değiştiği için Android ↔ Android E2E tekrar koşuldu. Koşu, kullanıcı talimatıyla bitmeden durduruldu.
- **O ana kadar sonuç: 43 kontrolün hiçbiri başarısız değil.**
  - Eşleşme, WebRTC, yanlış/süresi geçmiş kod, üçüncü cihaz: ✅
  - Ağlama alarmı (2,4 sn; 10 sn'de 1, 50 sn'de 1, 70 sn'de 2 alarm), alarm geçmişi, Function önizlemesi: ✅
  - Eşik senkronu, çıkıp yeniden katılma, **uçak modundan otomatik dönüş**: ✅ (B70'in değiştirdiği yol)
  - Dil ve tema: ✅
- **Koşulamayanlar:** kayıt, galeri, gece modu, ebeveynin son ayrılışı, bebeğin odayı silmesi. Bunlar B68–B70'te değişmedi; önceki tam koşuda (`test-results/20261122-133651-android`) geçmişti.
- **Sizden:** Gerek yok. İsterseniz `scripts/firebase_emulators.sh` açıkken `python3 scripts/run_e2e.py` ile tamamlayın (~7 dk).

## 9. Ninni v2: kulakla / anadilde kontrol gereken içerik
- **"Dandini dandini" melodisi** (`assets/audio/soothe_dandini.wav`): geleneksel melodinin nota aktarımını kendim yaptım (`tool/gen_sounds.py`, `DANDINI`). Doğrulayacak kaynağım yoktu. Telefonda dinleyip yanlışsa notaları düzeltin (dosyada açık liste) ya da CC0 bir kayıtla değiştirin.
- **Azerbaycanca metinler:** çeviri anadili Azerbaycanca olan biri tarafından gözden geçirilmeli (özellikle kısa düğme metinleri).
- **Sizden:** Dinleyip/okuyup not düşmeniz yeterli.
