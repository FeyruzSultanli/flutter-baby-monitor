# Ninni v2.1 — İlerleme

Plan: `docs/V21_PLAN.md`. Taslaklar: `design/mockups/Home21|BabyLive21|ParentLive21.dc.html`. Branch: `dev` (main'e dokunulmadı, deploy yok).

## Özet

| § | Konu | Durum |
|---|---|---|
| §3 | Ham Firebase hata metni (B74) | ✅ Düzeltildi |
| §1 | iPhone bebek → Android ebeveyn ağlama alarmı (B75) | 🔧 Olası nedenler düzeltildi + teşhis altyapısı; **gerçek cihazda doğrulanacak** (`docs/LIVE_DEBUG.md`) |
| §2 | Bas-konuş (B76) | 🔧 Olası nedenler düzeltildi + teşhis altyapısı; **gerçek cihazda doğrulanacak** |
| §4 | Arayüz (Home21, BabyLive21, ParentLive21, geçmiş, ayarlar, ilkeler) | ✅ |
| §5.4 | Testler, E2E, ekran görüntüleri | ✅ Android↔Android E2E 53/53; karma E2E ortam sorunu (BLOCKERS 10) |

## §3 — Hata mesajları (B74) — `3ecabd7`

- **Tek eşleme:** `lib/core/errors/user_facing_error.dart`. Kapsadığı hatalar:
  - ağ: `network-request-failed`, `unavailable`, `deadline-exceeded`, SocketException, TimeoutException → "İnternet bağlantısı yok. Wi-Fi veya mobil veriyi kontrol edin."
  - oda kapalı / kod hatalı-süresi dolmuş, giriş kapalı, izin, kamera
  - bilinmeyen → "Bir şeyler ters gitti. Tekrar deneyin."
  - TR/EN/AZ. Ham metin yalnızca `debugPrint`'e gider.
- **"Tekrar dene":** ağ ve bilinmeyen hatalarda snackbar'da (oda oluşturma, koda katılma).
- **İnternet yok şeridi:** üstte amber; Android'de İnternetsiz moda yönlendirme. İnternet gelince:
  - anonim giriş yeniden denenir;
  - bekleyen ebeveyn kalan beklemeyi atlayıp hemen yeniden bağlanır.
- **`connectivity_plus` kullanılmadı:** Linux için MPL-2.0 lisanslı `nm` paketini çekiyor (lisans kuralı). Yerine küçük yerel kanal yazıldı: `ninni/network` (Android ConnectivityManager, iOS NWPathMonitor), DECISIONS A37.
- Gözden geçirilen diğer yerler: kamera hataları, WebRTC `onError`, oda dinleyicisi, galeri paylaşımı, video oynatıcı.

## §1 — Ağlama alarmı (B75) — `87b2c5a`

Kodda bulunan ve düzeltilen olası nedenler:

1. **Ebeveynin saati.** Ebeveyn, `cryUpdated` (sunucu saati) ile kendi saatini karşılaştırıyordu. Ebeveyn telefonunun saati sunucudan 20 sn'den fazla ileriyse alarm **hiç** açılmıyordu.
   - Artık ilk değerden sonra yerel değişim zamanı kullanılıyor (`CryFreshness`).
   - Test: saat 2 dk ileriyken alarm yine geliyor.
2. **Görüşmede ölçüm.** Yalnızca `audioLevel` okunuyordu; gelmezse hiç dB yoktu.
   - Artık `totalAudioEnergy`/`totalSamplesDuration` farkından RMS de hesaplanıyor; ikisinin büyüğü kullanılıyor (A38).
   - Android'de davranış aynı.
3. **Firestore yazma hataları sessizdi.** Artık sonuç, süre ve ok/hata sayıları görünüyor.
4. **iOS ses oturumu.** `record` → WebRTC geçişinde oturum açıkça yeniden kuruluyor (§2 ile ortak).

Teşhis:

- Saniyede bir `CRYDIAG` satırı:
  - bebek: `src raw rms db thr over alarm write …`
  - ebeveyn: `cryAlert cryDb age fresh alarm …`
- Gizli **Tanı ekranı:** Ayarlar → sürüm satırına 5 dokunuş. Canlı değerler, ses baytları, SDP yönleri, yerel ses yolu (iOS kategori/mod/çıkış, Android mod/hoparlör/ses düzeyi). "Kopyala" düğmesi var.
- **Mikrofonu test et:** Ayarlar'da. Canlı dB + eşik çizgisi + eşik kaydırıcısı.
  - Bebek yayındayken algılamanın kullandığı seviyeyi gösterir.
  - Ebeveyn bağlıyken bebekten gelen sesi gösterir.
  - Başka durumda telefonun kendi mikrofonunu açar.

Gerçek iPhone'da ölçeğin kalibrasyonu, canlı oturumdaki değerlere göre yapılacak (A38).

## §2 — Bas-konuş (B76) — `87b2c5a`, arayüz `f932513`

Kodda bulunan ve düzeltilen olası nedenler:

1. **iPhone'da ahize.** WebRTC'nin iOS varsayılanı `voiceChat` modu: ses kulağa tutulan ahizeden, kısık çıkar. Hoparlör, görüşme sesi başlamadan önce açılıyordu; WebRTC oturumu sonradan kendi ayarıyla kuruyordu.
   - Artık iki telefonda da iOS oturumu `playAndRecord` + `videoChat` + `defaultToSpeaker`.
   - Bu ayar WebRTC'nin kendi varsayılanına yazılıyor.
   - Hoparlör bağlantı kurulunca ve ebeveyn sesi ilk geldiğinde yeniden açılıyor.
2. **Konuşma kanalı.** Ses transceiver'ı artık teklifteki `a=mid` ile de bulunuyor. Cevap SDP'sinde ses `sendrecv` değilse konuşma kapatılıp loglanıyor.
3. **İzin.** Kalıcı reddedilmişse "Bebeğe konuşmak için mikrofon izni gerekiyor" + "Ayarları aç". Mikrofon açılamazsa "Mikrofon açılamadı".

Ekranda:

- Basılıyken ses kartı konuşma kartına dönüşür.
- "Bebek sizi duyuyor" yalnızca giden ses baytları gerçekten artıyorsa yazar.
- 2,5 sn içinde bayt artmazsa "Ses bebeğe ulaşmıyor" yazar.
- Dalga gerçek giden seviyeden çizilir; düğmenin çevresinde dışa yayılan halkalar var.
- `TALKDIAG` satırları ve tanı ekranında bas-konuş istatistikleri.

## §4 — Arayüz — `f932513`, `a7f9b9d`, `c1cd2f2`, `ce78e47`, `22f46fd`

- **Ana ekran (Home21):** Rol seçiminin yerine geçti; karşılamadan sonra buraya gelinir.
  - Gece illüstrasyonu: yıldızlar, nefes alan ay, kayan bulutlar, beşik.
  - Saate göre selam.
  - Son oda varsa mor "Bebek odasını izle" kartı: tek dokunuşla bağlanır.
  - "Bebek telefonu" / "Yeni oda" kartları.
  - Android'de İnternetsiz mod satırı.
  - 8 sn'de bir değişen 6 gerçek ipucu.
- **Bebek yayında (BabyLive21):**
  - Başlık: oda adı (dokununca yeniden adlandır) + "Yayında · süre", sağda "Bağlı" ve "%76" hapları.
  - Kamera kartı: alt gradyan, "Arka kamera · Dengeli", CANLI, çevir düğmesi.
  - Ses kartı: halka gösterge (eşik çentiği) ve "Son 1 saat" grafiği. Grafikte dakikalık en yüksek dB, kesikli eşik çizgisi, alarm dakikaları kayısı.
  - Ebeveyn/Ninni/Işık kutuları, "Gece moduna geç", "Yayını bitir".
  - Son 60 dk yalnızca bebekte, bellekte tutuluyor. Ebeveyne gönderilmedi; yeni bir oda alanı kurallar deploy'u gerektirir.
- **Ebeveyn canlı (ParentLive21):**
  - Tam genişlik görüntü, üst/alt gradyan.
  - "3 sa 08 dk'dır izleniyor", CANLI.
  - Bağlantı kalitesi İyi/Orta/Zayıf: gerçek RTT ve paket kaybından.
  - Bebek pili, tam ekran.
  - Ses kartı: Bebek sakin/huzursuz/ağlıyor, dB sayacı, gerçek sesten 36 çubuklu dalga, "Bu gece N alarm · son hh:mm", "Geçmiş ›".
  - Çağrı ekranı düzeni: Ninni (60) — Basılı tut, konuş (84, halkalar) — Işık (60, durumla renklenir).
  - Alt sıra: Kaydet / Çevir / Kayıtlar / Ayarlar.
  - **"Bağlantıyı kes" sağ üst menüde.**
- **Alarm geçmişi:** Gecelik özetin altında saatlik çubuk grafik (21:00–07:00). Boş durumda ay + "Sakin bir gece!".
- **Ayarlar:** Her satırda renkli ikon kutusu. En üstte oda kartı: ad, kod, bağlı cihaz. "Mikrofonu test et", sürüm satırı (tanı ekranı).
- **Tüm ekranlara uygulanan ilkeler:**
  - Gece gökyüzü zemini: bebek tarafında daha sönük, gece modunda yok; koyu temadaki menü ekranlarında da var.
  - Gece kartları `#1C1F3D` + 1 px `#262A52`.
  - Sayaç animasyonları.
  - Hiçbir etiket "…" ile kesilmiyor: hap ve segmentlerde küçültme, diğerlerinde satır kaydırma.
  - Hareketi azalt açıksa tüm animasyonlar duruyor.
- **Ekran görüntüleri:** `design/screens_v21/<dil>_<cihaz>_<tema>/`.
  - Diller TR ve AZ; temalar açık ve koyu (koyu/açık yalnızca menü ekranlarını etkiler).
  - Cihazlar: `1080x2160` (Huawei RNE-L01, 18:9) ve `iphone` (1179×2556).
  - Yeniden üretmek: `./tool/screens_v21.sh`.

## Testler

- **`flutter analyze`:** 0 error / 0 warning. Kalan 7 info bilinçli bırakılanlar (enum adları, `use_build_context_synchronously`).
- **`flutter test`:** 180/180. V2.1 ile 19 yeni test:
  - `test/user_facing_error_test.dart`: hata eşlemesi; ham metin hiçbir dilde görünmüyor.
  - `test/rtc_diag_test.dart`: stats ayrıştırma, enerji-RMS, bayt akışı, bağlantı kalitesi, SDP yönü, saat farkına dayanıklı taze kontrolü.
  - `night_summary_test`: saatlik sayım.
  - `v2_ui_test`: 5 dokunuşla tanı ekranı, mikrofon testi, tema değişince ayar listesinin kaydırma konumu.
  - Erişilebilirlik ve kontrast testleri yeni ekranlarla da geçiyor.
- **E2E Android ↔ Android** (`test-results/20261123-041748-android`): iki taraf da geçti, 53/53.
  - Bebek tarafı:
    - ağlama alarmı 2,5 sn içinde;
    - push önizlemesi;
    - eşik senkronu;
    - gece modu;
    - oda silme.
  - Ebeveyn tarafı:
    - yeniden katılma;
    - bas-konuş düğmesi;
    - ninni ve ışık;
    - uçak modu → bağlantı koptu alarmı → otomatik yeniden bağlanma;
    - dil ve tema;
    - kayıt ve galeri;
    - menüden bağlantıyı kesme.
  - Koşular sırasında bulunan ve düzeltilen sorunlar:
    - **Tema değişince Ayarlar listesi başa sarıyordu** (`22f46fd`, gerçek arayüz hatası).
    - Test zamanlamaları: menü animasyonu ve kayıt snackbar'ı.
  - İlk koşulardan biri test aracının kendi HTTP isteği emülatör ağında koptuğu için düştü (ortam).
- **E2E kanıtı (B75):** Android ebeveyn emülatörünün saati sunucudan 78 sn ilerideydi (`age=78017`).
  - Eski kontrolle bu cihazda alarm hiç gelmezdi; yeni kontrolle geldi.
  - Gerçek telefonda saat farkı en güçlü aday.
- **E2E karma (Android bebek ↔ iOS ebeveyn):** iOS'ta yanlış kod adımında durdu.
  - iOS Firestore SDK'sı emülatörün "belge yok" yanıtında `WriteStream … internal error` veriyor.
  - V2.1 öncesi commit'te de aynı şekilde düştü, yani ortam kaynaklı (BLOCKERS 10).
  - iOS uygulaması V2.1 koduyla derlenip simülatörde açıldı.
- **Derlemeler:** Android debug APK ✅, `flutter build ios --no-codesign` ✅ (yerel Swift/Kotlin kanalları dahil).
- **Ekran görüntüleri:** `design/screens_v21/` altında 8 set × 20 ekran.
  - Huawei 360 dp'de AZ ile taşma bulundu ve düzeltildi: bebek başlığı, "Yayımı bitir".
  - Son sette taşma uyarısı yok.

## Cavid için: gerçek cihazda ne, nasıl test edilecek

1. **Canlı oturum (yarın, birlikte):** `docs/LIVE_DEBUG.md`.
   - A: iPhone bebek → Huawei ebeveyn ağlama alarmı.
   - B: Huawei → iPhone bas-konuş.
   - C: ters yön.
   - D: internet yok.
   - Her adımda hangi log satırının beklendiği ve uymazsa ne anlama geldiği tabloda yazıyor.
   - Toplanacaklar: `iphone_run.log`, `android_run.log`, iki telefondan tanı ekranı → "Kopyala" çıktısı, Mikrofonu test et ölçümleri (sessiz / konuşma / bağırma dB).
2. **Tek başına:** TEST_PLAN §18 (V5.1–V5.12).
3. **Firebase:** Kurallar ve Function deploy'u V2_PROGRESS "Cavid yapacak" ile aynı; V2.1 yeni alan eklemedi.
   - Kurallar hâlâ yayınlanmadıysa CRYDIAG'daki `write=` değerine bakın.
   - `write=err:permission-denied` görülürse önce kuralları yayınlayın.
