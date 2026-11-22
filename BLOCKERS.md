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
