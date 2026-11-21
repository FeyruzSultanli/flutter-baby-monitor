# REPORT.md — Oturum özeti

**Branch:** `dev`, `main`'in üzerine 43 commit. **Push yapılmadı.** `main`'e dokunulmadı, merge edilmedi.

Firebase config dosyalarına ve Firebase proje ayarlarına dokunulmadı.

Ayrıntılar başka dosyalarda:
- [BUGS.md](BUGS.md): tüm bulgular, karar günlüğü ve her maddenin durumu.
- [TEST_PLAN.md](TEST_PLAN.md): cihaz testleri.

## Kısaca

- Temizlik, WifiDirect'in kaldırılması ve ölü kodun silinmesi istediğiniz gibi yapıldı.
- Derin incelemede **54 madde** çıktı:
  - 24'ü düzeltildi, 1'i kısmen düzeltildi.
  - 1'i doğrulama sonucu hata olmadığı anlaşıldı (B09).
  - 12'si sizden **karar bekliyor**.
  - Kalanlar açık (düşük öncelikli ya da güvenli bir yerel düzeltmesi yok).
- **En kritik 3 konu** kodla çözülemez, altyapı ve ürün kararı gerektiriyor:
  1. Bebek telefonunda ekran kapanınca yayın duruyor (foreground service yok).
  2. Uygulama kapalıyken ebeveyne bildirim gitmiyor (FCM'i gönderen bir sunucu yok).
  3. Kimlik doğrulama yok ve oda kodu tahmin edilebilir (gizlilik riski).

## Durum

| Kontrol | Sonuç |
|---|---|
| `flutter analyze` | **0 error, 0 warning**, 13 info. Bunların hepsi dokunmamamı istediğiniz 3C kapsamında: 6 `constant_identifier_names`, 7 `use_build_context_synchronously`. Başlangıçta 64 sorun vardı. |
| `flutter test` | **49/49 ✅**. Başta tek test vardı ve o da kırıktı. |
| `flutter build apk --debug` | ✅ (son commit'te) |
| Cihaz testi | **Yapılmadı.** Gerçek cihaz gerekiyor; TEST_PLAN.md hazır. |

## Yapılanlar

1. **Temizlik (ADIM 1):**
   - 3A: kullanılmayan import ve değişkenler, etkisiz `!` işaretleri ve null kontrolleri, stil uyarıları.
   - 3B: `withValues`, `surfaceContainerHighest`, `SharePlus`.
   - WifiDirect servisi ve `flutter_p2p_connection` kaldırıldı. Derlenmiş manifest'te izin farkı **çıkmadı**. Offline modda artık WebRTCService oluşturulmuyor; mod değiştirilince eski servis dispose ediliyor.
   - README güncellendi.
   - home_screen'deki ölü kod silindi.
2. **İnceleme (ADIM 2):** `lib/` ve Android tarafı tarandı; bulgular BUGS.md'de. Bir bulgu (B09, Nearby'nin 32 KB sınırı) kütüphanenin içine bakılarak çürütüldü: projedeki sürümde sınır yaklaşık 1 MB.
3. **Testler (ADIM 3):**
   - Testlenebilsin diye offline mesaj kodlama/çözme ve PCM→dB hesabı ayrı dosyalara çıkarıldı.
   - Unit testler: payload, dB hesabı, VideoSettings, AlertModel, PairingState, TR/EN anahtar eşitliği ve alarm geçmişi servisi.
   - Kırık şablon test, gerçek bir smoke testle değiştirildi (SettingsSheet ve NoiseLevelBar, iki dilde).
4. **Düzeltmeler (ADIM 4):** Sadece koddan açıkça görülen, yerel ve davranışı genişletmeyen hatalar düzeltildi. Her biri ayrı commit, mesajında bug ID'si var.
   - Düzeltmeler bitince diff'i bağımsız bir inceleme ajanına okuttum. Bulduğu 5 sorunun hepsi benim düzeltmelerimden çıkmıştı; hepsi follow-up commit'leriyle giderildi (BUGS.md → K7).
5. **TEST_PLAN.md ve bu rapor** (ADIM 5–6).

## Düzeltilen hatalar

| ID | Önem | Ne düzeltildi |
|---|---|---|
| B04 | Yüksek | Bebek telefonu kendi ağlama bildirimini (sesli) alıyordu. |
| B05 | Yüksek | Ağlama sürdükçe 2 sn'de bir bildirim geliyordu; artık en fazla 60 sn'de bir. Offline ebeveyndeki aynı spam da düzeldi. |
| B06 | Yüksek | Bebek kendi offer'ını görünce rol değiştiriyordu; ICE adayları yanlış koleksiyona yazılıyordu. Bu, farklı ağlarda bağlanmayı zorlaştırıyordu. |
| B10 | Yüksek | Offline modda her kare için yeni bir isolate açılıyordu (ısınma, artan gecikme); artık aynı anda tek kare işleniyor. |
| B11 | Yüksek | Sessizlikte dB = −∞/NaN çıkıyordu; JSON hatası yüzünden ses çubuğu donuyordu. |
| B12 | Yüksek | Offline bebek modunda mikrofon izni istenmiyordu; açılışta izin istekleri çakışıyordu. |
| B13 | Yüksek | Kayıt hata verince buton "kayıtta" durumunda takılı kalıyordu. |
| B14 | Yüksek | Bağlantı kesilince veya mod değişince kayıt durmuyordu; mp4 oynatılamaz kalıyordu. |
| B15 | Yüksek (kısmi) | Multi-camera'daki sonsuz yeniden-cevap döngüsü. Asıl uyumsuzluk karar bekliyor. |
| B18 | Orta | Mod değişiminde WebRTCService sızıyordu. |
| B19 | Orta | Pil aboneliği iptal edilmiyordu; dispose sonrası `setState` çağrılıyordu. |
| B20 | Orta | Offline bebek modunda her ses parçası tüm ekranı yeniden çiziyordu. |
| B21 | Orta | Firestore'daki `offer: null` alanı her güncellemede hata attırıyordu. |
| B22 | Orta | Ebeveyn bağlanınca eski alarmlar yeniden bildirim olarak geliyordu; `closeRoom` alarmları silmiyordu. |
| B23 | Orta | Firestore dinleyicileri üst üste biniyordu; dinleyici hataları yakalanmıyordu. |
| B24 | Orta | Yayın bittikten sonra ekran hiç kapanmıyordu (wakelock). |
| B25 | Orta | Dispose'da timer, ses akışı, Nearby ve notifier kapatılmıyordu. |
| B26 | Orta | Offline bağlantı kopunca yakalanmamış CameraException oluşuyordu. |
| B29 | Orta | Alarm geçmişi sınırsız büyüyordu; tek bir bozuk kayıt tüm geçmişi siliyordu; 5 sn'de bir kayıt ekleniyordu. |
| B30 | Orta | Video oynatıcı boş dosyada ya da hızlı çıkışta çöküyordu. |
| B31 | Orta | Galeri her yeniden çizimde tüm thumbnail'ları baştan çıkarıyordu. |
| B33 | Orta | Offline kayıtta kare yazımı ile durdurma arasında yarış vardı. |
| B40, B41 | Düşük | Sabit metinler çevrildi; arayüzdeki "Wi-Fi Direct" yazıları kaldırıldı. |
| B46 | Düşük | iOS'ta offline mod çökmek yerine "yalnızca Android" mesajı gösteriyor. |

Bu düzeltmelerin çoğu **cihazda doğrulanmalı**. Hangi testle doğrulanacakları TEST_PLAN.md Bölüm 11'de.

## Açık kalan önemli hatalar (kod düzeltmesi yapılmadı)

- **B08 (Yüksek):** Ebeveyn aynı odaya yeniden katılınca bağlantı kurulmuyor. Şimdilik bebekte oda yeniden oluşturulmalı. Çözüm sinyal protokolünü değiştiriyor (yeni offer veya ICE restart), o yüzden yerel bir düzeltme değil.
- **B16:** WebRTC kayıtlarında ses yok. Tek satırlık bir düzeltme, ama yeni davranış eklediği için cihazda denenmeden yapmadım.
- **B36:** Geçici kopmalar hemen "hata" olarak gösteriliyor.
- **B37:** Online modda video ayarları uygulanmıyor.
- **B39:** Offline'da otomatik yeniden bağlanma yok.
- **B35:** Dil ve tema kalıcı değil. `shared_preferences` bağımlılığı gerekiyor.
- **Düşük:** B34, B42–B44, B47–B50, B53, B54.

## Sizden karar bekleyen konular

| # | Konu | Seçenekler | Önerim |
|---|---|---|---|
| D1 | **Bebek telefonu ekran kapalıyken yayın (B01, Kritik)** | (a) `camera\|microphone` türünde, kalıcı bildirimli foreground service (`flutter_foreground_task` ya da kendi Kotlin servisimiz). (b) Servis olmadan, "ekranı açık bırakın" uyarısı ve kilit. | **(a).** İlk adım olarak (b)'deki uyarı hemen eklenebilir. |
| D2 | **Uygulama kapalıyken bildirim (B02, Kritik)** | (a) Ebeveynin FCM token'ı odaya yazılır, Cloud Function `alerts` onCreate olunca FCM gönderir (Blaze planı). (b) Ebeveyn cihazında da foreground service. | Online için **(a)**, offline için **(b)**. |
| D3 | **Güvenlik (B03, Kritik)** | Anonymous Auth + Firestore kuralları (oda sahibi ve izleyicinin uid'i) + uzun kod veya QR ile eşleşme. | Üçü birlikte. Önce **konsoldaki mevcut kurallara bakın.** |
| D4 | **TURN (B07)** | (a) Yönetilen TURN (Cloudflare, Twilio, Metered); kısa ömürlü kimlik bilgileri bir Cloud Function'dan gelir. (b) Kendi coturn sunucumuz. | **(a).** Kimlik bilgileri uygulamaya gömülmemeli. |
| D5 | **Yanlış alarm ve eşik (B27, B28)** | Alarm için 2–3 sn sürekli eşik üstü şartı; online ve offline dB ölçeğini birleştirmek (offline'a +9.7 dB). | **2 sn şartı + tek ölçek.** Cihazda kalibrasyon gerekir. |
| D6 | **Multi-camera (B15)** | İzleyici başına ayrı oturum, ya da özelliği şimdilik gizlemek. | **Şimdilik gizle.** |
| D7 | **Offline kayıt (B32: ~15 sn GIF)** | ffmpeg_kit/MediaCodec ile mp4, ya da açık bir süre sınırı. | Kısa vadede **süre sınırı + uyarı**. |
| D8 | **Firestore temizliği (B38)** | TTL politikası (`expireAt`) ya da zamanlanmış bir Function; oda güncellemesini 2 sn → 5 sn yapmak. | **TTL.** |
| D9 | **Yayın hazırlığı (B45)** | Yeni applicationId (Firebase'de yeni Android uygulaması ve yeni google-services.json gerektirir), release keystore, google-services 4.4.x. | Mağaza yayını planlanınca. |
| D10 | **iOS kapsamı (B17, B52)** | iOS'ta kayıt yok, arka plan modları ve push entitlement'ı yok. | iOS hedefleniyorsa ayrı bir tur. |
| D11 | **Kullanılmayan kod (B50)** | `signaling_service.dart` ve `noise_meter` bağımlılığı silinsin mi? | Silinsin. |

## Sizin şimdi yapmanız gerekenler

1. **Android lisanslarını kabul edin** (etkileşimli bir komut):

   ```bash
   flutter doctor --android-licenses
   ```

2. **Firebase konsolu → Firestore → Rules** bölümüne bakın: `rooms` herkese açık mı? (B03)
3. **İki Android telefonla TEST_PLAN.md'yi uygulayın.** Öncelik sırası:
   - Bölüm 3 (offline)
   - Bölüm 5 (alarm ve bildirim)
   - Bölüm 2B (farklı ağlar)
   - Bölüm 11 (düzeltilen hataların tekrar testleri)

   Logları TEST_PLAN Bölüm 0'daki komutlarla toplayın.
4. **D1–D11 için karar verin.** D1, D2 ve D3 en kritikleri.
5. **Push için onay verin**, ya da önce commit'leri gözden geçirin:

   ```bash
   git log --oneline main..dev
   ```

## Commit listesi (`main..dev`, eskiden yeniye)

| Hash | Mesaj |
|---|---|
| `015c34f` | docs: add CLAUDE.md with architecture, run instructions and known limits |
| `7248cd1` | build(android): keep Flutter migrator gradle flags (builtInKotlin/newDsl=false) |
| `72ddd26` | chore: remove stray notebook and .DS_Store files, ignore .DS_Store |
| `c0e0cd0` | chore: track pubspec.lock to pin dependency versions |
| `474ef31` | chore(lint): remove unused imports/locals, redundant ! and null checks |
| `6f72d30` | chore(lint): migrate deprecated withOpacity, surfaceVariant and Share APIs |
| `9cc1419` | refactor: remove unused WifiDirectSignalingService and flutter_p2p_connection |
| `a4b75e3` | refactor(home): remove dead code from home_screen |
| `451e421` | refactor: extract offline payload codec and audio dB helpers |
| `cd3af29` | test: add unit tests for payload codec, dB math, models, l10n parity |
| `06ae4ac` | docs: add BUGS.md with deep review findings and progress log |
| `fb29391` | fix(B04): don't notify the baby device about its own cry alerts |
| `56a2919` | fix(B05): rate-limit cry notifications to one per 60 s |
| `31778e4` | fix(B06): keep the baby as caller after its own offer echoes back |
| `a1b3e4b` | fix(B21): ignore null offer/answer fields in the room snapshot |
| `199bb77` | fix(B22): don't replay stored alerts when joining a room |
| `7687a9b` | fix(B23): cancel stale Firestore listeners and handle listener errors |
| `ffeab24` | fix(B11): never produce -Infinity/NaN dB from offline PCM chunks |
| `d0ac84f` | fix(B10): process at most one offline camera frame at a time |
| `b9968be` | docs(BUGS): update status for B04-B06, B09-B11, B21-B23 |
| `bd5bda7` | fix(B12): request microphone for offline baby mode, serialize startup prompts |
| `404525a` | fix(B13): don't get stuck in recording state when start/stop fails |
| `afba4ad` | fix(B14): stop recordings on reset/dispose and regardless of mode |
| `0e880a1` | fix(B19): store/cancel the battery subscription and guard setState |
| `0bae805` | fix(B20): rebuild the baby UI at most every 200 ms in offline audio mode |
| `5a244dc` | fix(B26): handle stopImageStream errors when the offline peer disconnects |
| `13b506f` | fix(B24): release the wakelock when pairing/streaming is reset |
| `9af8135` | fix(B25): release timers, audio streams, Nearby and notifier on dispose |
| `bbb5562` | fix(B29): make alert history bounded, crash-safe and tolerant |
| `d9d238c` | fix(B30): don't crash VideoPlayerScreen on missing/empty files or early exit |
| `865f0d6` | fix(B31): cache gallery thumbnail futures, guard setState after await |
| `da8efa9` | fix(B33): serialize offline frame writes and wait for them on stop |
| `e94e406` | fix(B40,B41): localize hard-coded UI strings, drop Wi-Fi Direct wording |
| `1ddeeb1` | fix(B46): show a message instead of crashing when offline mode is used on iOS |
| `ac1e136` | fix(B15): answer each multi-camera offer only once |
| `1897b85` | docs(BUGS): update statuses after step 4 fixes |
| `71d2d89` | docs: add TEST_PLAN.md for two-device manual testing |
| `23380b4` | chore(lint): drop now-unnecessary dart:typed_data import in home_screen |
| `0de6bb6` | fix(B22): don't filter alerts by device clock; make alert cleanup best effort |
| `718049c` | fix(B29): don't treat I/O errors as corruption in alert history |
| `0e44646` | fix(B25): ignore Nearby payloads that arrive after dispose |
| `c99e4ed` | fix(B14): let stopAny() stop a WebRTC recording that is still starting |
| (son) | docs: add REPORT.md, update BUGS.md statuses |
