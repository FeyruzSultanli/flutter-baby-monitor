# REPORT.md — Otonom oturum raporu (21–22.11.2026)

## Sabah özeti

1. **Yapıldı:** D2/D3 uygulama değişiklikleri bağımsız olarak incelendi; 6 bulgu düzeltildi (B55–B60). Android ve iOS için emülatörde çalışan uçtan uca testler yazıldı. Bu testler 7 hata daha buldu ve hepsi düzeltildi (B61–B67).
2. **Android ↔ Android (API 35 Google Play emülatörleri):** 44/44 kontrol ✅. Kapsam: oda kodu, WebRTC, yanlış/süresi geçmiş kod, üçüncü cihazın reddi, ağlama alarmı (2 sn kuralı, 60 sn sınırı), alarm geçmişi, eşik senkronu, yeniden katılma, uçak modundan dönüş, gece modu, kayıt, galeri, dil, tema.
3. **Android bebek ↔ iOS ebeveyn:** ✅ iki test de geçti, bağlantı kuruluyor. **iOS ↔ iOS:** koşu 7'de her şey geçti; tek sorun B67'ydi. B67 düzeltildikten sonraki tekrar koşusu bitirilemedi (BLOCKERS 5).
4. **iOS uyumluluğu:** İzin metinleri TR/EN, minimum iOS 15, arka plan modları. Offline seçeneği iOS'ta gizli. iPhone bebekse gece modu öneriliyor. Simülatörde açılış çökmesi giderildi (B63).
5. **Emülatörde test edilemeyenler:** offline (Nearby), farklı ağlar (TURN yok), gerçek push, gerçek ses kalibrasyonu, ekran kapalıyken yayın (7. adım bekliyor), iPhone kamerası.
6. **Kararınız bekleniyor (DECISIONS.md):** `sound_stream` GPL-3.0 lisanslı (önerim: değiştirmek). Android ↔ iOS offline gerekli mi? TURN (D4)?
7. **Sizin ilk 3 işiniz:**
8. ① Firebase konsolu: Anonymous girişi açın, kuralları yayınlayın, TTL politikasını tanımlayın; Blaze kararından sonra Function'ı deploy edin (PLAN_NEXT.md, "D3 + D8 için konsol adımları" ve "D2 deploy adımları").
9. ② İki Android telefonla TEST_PLAN.md'nin başındaki **G1–G8** kısa listesini yapın (~1,5 saat).
10. ③ iPhone için Apple Developer hesabı ve APNs anahtarı (aşağıda "iOS: sizin yapmanız gerekenler"). Her şey `dev`'de ve push edildi; `main`'e dokunulmadı.

## Durum

| Kontrol | Sonuç |
|---|---|
| `flutter analyze` | 0 error, 0 warning, 13 info (bilerek bırakılan enum adları ve `use_build_context_synchronously`) |
| `flutter test` | 87/87 ✅ |
| Android debug derlemesi | ✅ (E2E derlemeleri) |
| E2E Android ↔ Android | ✅ 44/44 (`test-results/20261122-133651-android`) |
| E2E Android ↔ iOS | ✅ (`test-results/20261122-030630-mixed`) |
| E2E iOS ↔ iOS | Koşu 7'de ✅. Tek hata B67'ydi, düzeltildi. Sonraki tekrar koşusu yarım kaldı (BLOCKERS 5). |
| Gerçek cihaz testi | Yapılmadı: TEST_PLAN.md G1–G9 |
| Branch | `dev`, `main`'in 103 commit önünde, push edildi. `main`'e push/merge yok. Firebase config dosyalarına ve gerçek projeye dokunulmadı. |

## Bu oturumda yapılanlar

1. **Güvenlik kuralları:** `.claude/settings.local.json` içinde `main`'e push, force push, merge, `reset --hard`, Firebase login ve deploy yasak (git dışı).
2. **Bağımsız inceleme (D2/D3):** pairing_service, auth_service, notification_service ve home_screen ayrı bir ajana okutuldu. Bulgular B55–B60 olarak ayrı commit'lerle düzeltildi.
3. **Firebase Emulator Suite:**
   - Auth, Firestore (bizim `firestore.rules`) ve Functions yerelde çalışıyor (`scripts/firebase_emulators.sh`, `firebase.emulators.json`).
   - Uygulama emülatöre yalnızca debug derlemede ve `--dart-define=USE_FIREBASE_EMULATOR=true` ile bağlanıyor (Android 10.0.2.2, iOS localhost). Release her zaman gerçek Firebase'e bağlanır.
   - Function emülatörde gerçek FCM'e gitmiyor; bildirimin içeriğini odaya `lastPushPreview` olarak yazıyor.
4. **Uçtan uca testler:**
   - Testler `integration_test/baby_test.dart` ve `parent_test.dart`. İki cihaz Firestore emülatörü üzerinden koordine oluyor.
   - Runner `scripts/run_e2e.py --platform android|ios|mixed`: izinleri `adb pm grant` / `simctl privacy` ile veriyor, ekran görüntüsü ve log topluyor, `test-results/` altına `summary.md` yazıyor.
   - Sahte ağlama yalnızca debug'da çalışıyor (`DebugHooks.fakeNoiseDb`).
5. **Android emülatörleri:** API 35 Google Play image indirildi; "baby" ve "parent" AVD'leri oluşturuldu.
6. **iOS (Xcode 27):** Ayrıntılar aşağıda, "iOS".
7. **Belgeler:**
   - TEST_PLAN.md: her maddede emülatör sonucu ve gerçek cihaz gerekip gerekmediği; en kısa telefon listesi (G1–G9); iPhone bölümü (13).
   - DECISIONS.md (A1–A14), BLOCKERS.md (1–5), BUGS.md (B55–B67) ve CLAUDE.md güncellendi.

## Bu oturumda bulunan ve düzeltilen hatalar

| ID | Önem | Ne | Commit |
|---|---|---|---|
| B55 | Orta | İnternet yokken eşleşme sonsuz dönüyordu → 15 sn zaman aşımı ve "sunucu yanıt vermiyor" mesajı | `9b004f9` |
| B56 | Orta | Ebeveyn ayrıldıktan sonra da push gidebiliyordu → ayrılırken token siliniyor | `9b004f9` |
| B57 | Orta | Silinmiş odada izin hatası "oda kapandı" sayılmıyordu; eski oda dinleyicisi açık kalıyordu | `a2cfafd` |
| B58 | Düşük | Oda ömrü 24 sa → 12 sa | `9b004f9` |
| B59 | Orta | FCM izni alınamazsa bildirim izni hiç istenmiyordu | `34bb9e0` |
| B60 | Düşük | Yakalanmayan future'lar; Anonymous giriş kapalıyken sonsuz yeniden katılma | `66d3ab0` |
| B61 | Orta | Kapanmış eşleşme sayfasında `setState` | `0a4932c` |
| B62 | Orta | Ana ekran kapanırken `setState` | `771e3bc` |
| B63 | Yüksek (iOS) | `sound_stream` iOS'ta açılışta uygulamayı çöktürüyordu | `4a28326`, `41e43eb` |
| B64 | Yüksek | Answer'dan önce gelen ICE adayları kayboluyordu (farklı ağlarda bağlantıyı zorlaştırır) | `0f50f77` |
| B65 | Orta (iOS) | Rol değişiminde iOS'ta Nearby'ye dokunuluyordu | `f080481` |
| B66 | Orta | Bildirim izni yokken yerel bildirim hatası yakalanmıyordu | `609f427` |
| B67 | Orta | Eylem düğmeli uyarılar hiç kapanmıyor, alttaki düğmeleri örtüyordu | `9e10308` |

## E2E sonuçları

| Koşu | Cihazlar | Sonuç |
|---|---|---|
| Android ↔ Android | AVD "baby" + "parent", API 35 Google Play | ✅ 44/44, iki test de geçti (6,8 dk) |
| Android bebek ↔ iOS ebeveyn | API 35 + iOS 27 simülatörü | ✅ İki test de geçti; WebRTC iki tarafta "Bağlı", yeniden katılma çalıştı. iOS ekran görüntülerini sistemin bildirim izni diyaloğu kapladığı için görüntü iOS'ta görsel olarak doğrulanamadı (TEST_PLAN 13.3). |
| iOS ↔ iOS | iki iOS 27 simülatörü | Koşu 7 ✅ (yalnızca ses; simülatörde kamera yok). Tek hata B67'ydi. |

**Ölçülenler (Android):**
- Alarm ağlamadan ~2,4 sn sonra çalıyor. 1 sn'lik ses alarm vermiyor.
- Sürekli ağlamada alarmlar: 10. sn'de 1, 50. sn'de 1, 70. sn'de 2.
- Alarm geçmişinde 2 kayıt var, uygulama dilinde.
- Function'ın hazırladığı bildirim: "Bebek ağlıyor | Ses seviyesi: 85.0 dB".
- Eşik ebeveynden bebeğe geçiyor.
- Ayrılınca oturum ve push token'ı siliniyor.
- Bebek bağlantıyı kesince oda siliniyor.

**iOS'ta beklenen farklar:** FCM token yok (APNs gerekiyor), uçak modu adımı atlandı, görüntü yerine yalnızca ses.

**Test altyapısı sorunları** (uygulama hatası değil):
- Yavaş emülatörde menü ve açılır listeler için sabit bekleme yetmiyordu; düzeltildi.
- Mac uykuya geçince emülatör koptu; koşular artık `caffeinate` ile.
- Aynı anda fazla simülatör açıkken CoreAudio zaman aşımı oluyor (BLOCKERS 4).

## iOS

- **Yapılanlar:**
  - Kamera, mikrofon, yerel ağ ve fotoğraf kaydetme izin metinleri TR/EN (`InfoPlist.strings`).
  - Minimum iOS 15 (Podfile + proje).
  - Arka plan modları: `audio`, `remote-notification`.
  - Podfile'da `permission_handler` makroları.
  - Flutter'ın UIScene ve SPM geçişleri yapıldı.
- **Davranış:**
  - Offline seçeneği iOS'ta gizli; yerine "yalnızca Android" açıklaması var.
  - iPhone'da oda açılınca, kamera arka planda çalışmadığı için gece modu öneriliyor.
  - Simülatörde yalnızca debug'da sesli yedek akış var (BLOCKERS 1).
  - `nearby_connections` ve `sound_stream` yalnızca Android'de çağrılıyor. `sound_stream` iOS'ta hiç kaydedilmiyor (DECISIONS A11).
- **Paket desteği:** firebase_*, flutter_webrtc, camera, permission_handler, flutter_local_notifications, wakelock_plus, screen_brightness, gal, video_player ve share_plus iOS'u destekliyor.
- **Bilinen:** `flutter build ios --simulator` Flutter 3.44'te hata veriyor; `flutter run` / `flutter test -d <udid>` çalışıyor (DECISIONS A12). Gerçek cihaz derlemesi etkilenmiyor.
- **Android ↔ iOS offline:** Kod yazılmadı. Seçenekler PLAN_NEXT.md §6'da.

### iOS: sizin yapmanız gerekenler

1. **Apple Developer hesabı:** Ücretsiz Apple ID ile kendi iPhone'unuza 7 günlük kurulum yapabilirsiniz. Push için ücretli Apple Developer Program (yıllık 99 USD) gerekir.
2. **İmzalama:**
   - `ios/Runner.xcworkspace`'i Xcode'da açın.
   - Runner → Signing & Capabilities → Team'i seçin.
   - Bundle ID `com.feyruz.bebekmonitorclean` kalabilir. Değiştirirseniz Firebase'de yeni bir iOS uygulaması ve yeni bir `GoogleService-Info.plist` gerekir.
3. **Capability ekleyin:** "+ Capability" → **Push Notifications** ve **Background Modes** (Audio ile Remote notifications işaretli; Info.plist'te hazır).
4. **APNs anahtarı:**
   - developer.apple.com → Certificates, IDs & Profiles → Keys → "+" → Apple Push Notifications service (APNs) → `.p8` dosyasını indirin. Key ID ve Team ID'yi not edin.
   - Firebase konsolu → Proje ayarları → Cloud Messaging → Apple uygulaması → APNs Authentication Key → `.p8`'i, Key ID'yi ve Team ID'yi yükleyin.
5. **iPhone'a kurulum:**
   - iPhone'u kabloyla bağlayın, Ayarlar → Gizlilik ve Güvenlik → Geliştirici Modu'nu açın.
   - `flutter run -d <iphone>` (ya da Xcode'da ▶).
   - İlk açılışta Ayarlar → Genel → VPN ve Cihaz Yönetimi → geliştirici sertifikasına güvenin.
6. **Test:** TEST_PLAN.md bölüm 13.

## Genel durum: D kararları ve açık konular

| Konu | Durum |
|---|---|
| D1-a gece modu | ✅ Kodda. D1-b foreground service (7. adım) **bekletiliyor**: ekran kapanınca Android'de yayın hâlâ duruyor (B01). |
| D2 push (B02) | ✅ Uygulama ve Function kodu hazır, emülatörde doğrulandı. **Deploy edilmedi** (Blaze kararı sizde). |
| D3 güvenlik + D8 TTL (B03, B38) | ✅ Kod ve kurallar hazır, emülatörde doğrulandı. **Konsol adımları sizde.** |
| D5 alarm eşiği, D6 multi-camera gizli, D7 offline kayıt sınırı, D11 | ✅ |
| B08 yeniden katılma, B36 | ✅ Emülatörde doğrulandı |
| D4 TURN (B07) | Karar bekliyor. Farklı ağlarda bağlantı G2 testine bağlı. |
| D9 yayın hazırlığı (B45), D10 iOS kapsamı (B17, B52) | Karar bekliyor (iOS'un temel uyumluluğu bu oturumda yapıldı) |
| `sound_stream` GPL-3.0 | Karar bekliyor (DECISIONS.md) |
| Açık hatalar | B16 (WebRTC kayıtlarında ses yok), B35 (dil/tema kalıcı değil), B37 (online video ayarları), B39 (offline otomatik yeniden bağlanma) ve düşük öncelikliler. Hepsi BUGS.md'de. |

## Nerede ne var

- [BUGS.md](BUGS.md): tüm bulgular (B01–B67) ve durumları.
- [TEST_PLAN.md](TEST_PLAN.md): telefon testleri. En üstte emülatör sonuçları ve kısa liste.
- [DECISIONS.md](DECISIONS.md): bu oturumdaki kararlar ve sizin kararınızı bekleyenler.
- [BLOCKERS.md](BLOCKERS.md): çözülemeyenler.
- [PLAN_NEXT.md](PLAN_NEXT.md): D adımları, konsol ve deploy komutları, Android ↔ iOS offline seçenekleri.
- Commit geçmişi: `git log --oneline main..dev`.
