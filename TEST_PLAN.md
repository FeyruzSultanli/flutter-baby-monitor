# TEST_PLAN.md — 2 Android telefonla manuel test

İki cihaz kullanılıyor:
- **B (Bebek):** kamera ve mikrofonu yayınlayan telefon.
- **E (Ebeveyn):** izleyen telefon.

Her testin altındaki **Sonuç** satırını doldurun. Bir şey ❌ çıkarsa önce logları toplayın (aşağıda nasıl yapılacağı yazıyor), sonra nota hangi log dosyasına baktığınızı ekleyin.

---

## 0. Hazırlık ve log toplama

### 0.1 Kurulum

```bash
flutter devices
```

```bash
flutter run -d <BEBEK_SERIAL> 2>&1 | tee bebek_run.log
```

```bash
flutter run -d <EBEVEYN_SERIAL> 2>&1 | tee ebeveyn_run.log
```

- İki komutu iki ayrı terminalde çalıştırın. Serial numaralarını `adb devices` ile öğrenebilirsiniz.
- İlk testten önce iki cihazda da uygulamayı silip tekrar kurun ki izin diyalogları baştan gelsin:

```bash
adb -s <SERIAL> uninstall com.example.bebek_monitor_clean
```

### 0.2 adb logcat (native hatalar, WebRTC, Nearby, kamera)

Önce eski logları temizleyin:

```bash
adb -s <SERIAL> logcat -c
```

Sonra tam logu filtresiz kaydedin; sonradan aranabilir:

```bash
adb -s <SERIAL> logcat -v time > logcat_<cihaz>.txt
```

Canlı izlemek için filtreli bir görünüm:

```bash
adb -s <SERIAL> logcat -v time | grep -iE "flutter|webrtc|nearby|camera|AudioRecord|FATAL|AndroidRuntime|Firestore|FirebaseMessaging"
```

Sadece uygulamanın sürecini izlemek için (uygulama açıkken çalıştırın):

```bash
adb -s <SERIAL> logcat -v time --pid=$(adb -s <SERIAL> shell pidof -s com.example.bebek_monitor_clean)
```

**Logda aranacak anahtar kelimeler:**
- `Room signaling listener error`
- `Alerts listener error`
- `Candidates listener error`
- `Room listener error`
- `Error sending frame`
- `Status payload send error`
- `Battery`
- `Stopping recording`
- `WebRTC error`
- `Unhandled Exception`

---

## 1. İzinler

| # | Ön koşul | Adımlar | Beklenen | Sonuç |
|---|---|---|---|---|
| 1.1 | Temiz kurulum (B) | Uygulamayı ilk kez açın. | Kamera ve mikrofon izin diyalogları **ayrı ayrı, sırayla** gelir (çakışmaz). Bildirim izni sorulur (Android 13+). | ✅/❌ + not: |
| 1.2 | 1.1'de izinler verildi | Bebek modunda kamera önizlemesine bakın. | Önizleme görünür, "kamera hatası" mesajı çıkmaz. | ✅/❌ + not: |
| 1.3 | Temiz kurulum (B), offline mod | Ayarlar → Offline mod → menü → "Yayını başlat (offline)". | Konum, Yakındaki cihazlar/Bluetooth (sürüme göre), **Kamera ve Mikrofon** istenir. | ✅/❌ + not: |
| 1.4 | 1.3'te mikrofon reddedildi | Yayını başlatmayı tekrar deneyin. | "İzin reddedildi" snackbar'ı ve "Ayarlar" butonu çıkar; uygulama çökmez. | ✅/❌ + not: |
| 1.5 | Temiz kurulum (E), offline | Ebeveyn modu → "Cihaz ara (offline)". | Konum ve Bluetooth/Yakındaki cihazlar istenir; kamera ve mikrofon **istenmez**. | ✅/❌ + not: |
| 1.6 | B | Bebek moduna geçin. | Pil optimizasyonu diyaloğu çıkar. "Evet" denince sistem ekranı açılır. | ✅/❌ + not: |

## 2. Online mod

### 2A. Aynı Wi-Fi

| # | Ön koşul | Adımlar | Beklenen | Sonuç |
|---|---|---|---|---|
| 2A.1 | B ve E aynı Wi-Fi'da, online mod | B: Bebek modu → "Oda kodu oluştur". | 6 haneli kod görünür. | ✅/❌ + not: |
| 2A.2 | 2A.1 | E: Ebeveyn modu → kodu girin → Bağlan. | 10 sn içinde E'de canlı görüntü ve ses gelir, durum "Bağlı" olur. | ✅/❌ + süre: |
| 2A.3 | 2A.2 | E'den kamerayı değiştirin (ön/arka). | B'nin kamerası değişir, görüntü kesilmeden devam eder. | ✅/❌ + not: |
| 2A.4 | 2A.2 | B'den "Bağlantıyı kes". | E'de bağlantı düştü/hata durumu görünür, uygulama çökmez. | ✅/❌ + not: |

### 2B. Farklı ağlar (öncelikli; TURN yok)

| # | Ön koşul | Adımlar | Beklenen | Sonuç |
|---|---|---|---|---|
| 2B.1 | B ev Wi-Fi'ında, E **mobil veride** (Wi-Fi kapalı) | 2A.1 ve 2A.2'yi tekrarlayın. | Bağlanırsa ✅. Bağlanmazsa ne kadar beklediğinizi ve E'deki hatayı not edin (B07: TURN yok, bu beklenen bir kısıt olabilir). | ✅/❌ + süre: |
| 2B.2 | İki farklı Wi-Fi (ör. ev ve komşu/ofis) | Aynı adımlar. | 2B.1 ile aynı. | ✅/❌ + not: |
| 2B.3 | 2B.1 bağlandıysa | 5 dk izleyin. | Görüntü donmaz. | ✅/❌ + not: |

## 3. Offline mod (internet kapalı) — ÖNCELİKLİ

Ön koşul: iki cihazda da internet **kapalı** (mobil veri kapalı, Wi-Fi açık ama hiçbir ağa bağlı değil), Bluetooth ve Konum **açık**, iki cihaz da offline modda.

| # | Ön koşul | Adımlar | Beklenen | Sonuç |
|---|---|---|---|---|
| 3.1 | B | Menü → "Yayını başlat (offline)". | "Bağlantı bekleniyor" snackbar'ı çıkar; ekran açık kalır. | ✅/❌ + not: |
| 3.2 | E | Menü → "Cihaz ara (offline)". | Liste diyaloğunda B'nin marka/model adı görünür. | ✅/❌ + kaç sn: |
| 3.3 | 3.2 | B'yi seçin. | Bağlantı kurulur; E'de görüntü ve **ses** gelir; ses çubuğu hareket eder. | ✅/❌ + not: |
| 3.4 | 3.3 | Ayarlar → Video: kaliteyi LOW, MEDIUM ve HIGH yapın (her birinde 1 dk). | Üçünde de görüntü akar. HIGH'da donma ya da gecikme olursa not edin (B09 notu: Bluetooth bant genişliği). | LOW ✅/❌ MED ✅/❌ HIGH ✅/❌ |
| 3.5 | 3.3 | FPS'i 15 → 30 → 60 yapın. | Görüntü akmaya devam eder; B ısınıyorsa not edin (B10). | ✅/❌ + not: |
| 3.6 | 3.3 | E'den kamerayı değiştirin. | B'de kamera değişir, akış devam eder. | ✅/❌ + not: |
| 3.7 | 3.3 | B'nin mikrofonunu parmakla tamamen kapatın (sessizlik). | Ses çubuğu ~0'a iner ve **donmaz**. Logda `Unhandled Exception`/`Infinity` olmamalı (B11). | ✅/❌ + not: |
| 3.8 | 3.3 | E'de pil göstergesine bakın. | B'nin pil yüzdesi görünür; B şarja takılınca "şarj oluyor" olur (1 dk içinde). | ✅/❌ + not: |
| 3.9 | Bağlıyken | İki cihazı 15–20 m uzaklaştırın, sonra geri getirin. | Bağlantı koparsa E'de "bağlı değil" durumu görünür. Geri getirince **otomatik bağlanmaz**; E'den yeniden arama gerekir (B39, bilinen eksik). | ✅/❌ + not: |
| 3.10 | Bağlıyken | B'de Bluetooth'u kapatıp açın. | Uygulama çökmez; yeniden arama ile tekrar bağlanılabilir. | ✅/❌ + not: |

## 4. Görüntü/ses kalitesi ve gecikme

| # | Ön koşul | Adımlar | Beklenen | Sonuç |
|---|---|---|---|---|
| 4.1 | Online bağlı | B'nin önünde kronometre çalıştırın; E ekranıyla B ekranını aynı karede fotoğraflayın. | Gecikme < 1 sn. | ___ ms |
| 4.2 | Offline bağlı | Aynı ölçüm. | Gecikmeyi not edin. | ___ ms |
| 4.3 | Online ve offline | B'nin yanında konuşun, E'de dinleyin. | Ses anlaşılır; cızırtı veya kesilme varsa not edin. | Online ✅/❌ Offline ✅/❌ |
| 4.4 | Online | Karanlık oda + gece modu. | Görüntü değerlendirmesi (not). | not: |

## 5. Ağlama alarmı ve bildirim

Ön koşul: ayarlardaki eşik varsayılan (60). Ağlama sesi için telefondan "bebek ağlama sesi" videosu çalın.

| # | Durum | Adımlar | Beklenen | Sonuç |
|---|---|---|---|---|
| 5.1 | Online, E uygulama **ön planda** | B'nin yanında ağlama sesini 2 dk çalın. | E'de overlay ve titreşim görünür. **Sistem bildirimi en fazla dakikada 1 kez** gelir (B05). | Bildirim sayısı: ___ |
| 5.2 | 5.1 sırasında | B'nin ekranına bakın. | B'de **bildirim çıkmaz**, ses çalmaz (B04). | ✅/❌ + not: |
| 5.3 | Online, E **arka planda** (Home tuşu) | 5.1'i tekrarlayın. | Bildirim gelirse ✅. Kaç dakika sonra gelmeyi bıraktığını not edin (B02: FCM yok). | ✅/❌ + süre: |
| 5.4 | Online, E **ekranı kapalı** | 5.1'i tekrarlayın. | Not edin (B02; büyük ihtimalle bir süre sonra kesilir). | ✅/❌ + süre: |
| 5.5 | Online, E **uygulamayı kapatmış** (son uygulamalardan kaydırmış) | 5.1'i tekrarlayın. | Bildirim **gelmez**; bu bilinen bir kısıt (B02). | ✅/❌ |
| 5.6 | Online | E bağlantıyı kesip **aynı odaya** tekrar katılsın. | Eski alarmlar için bildirim **gelmez** (B22). (Bağlantının kurulamaması B08'den kaynaklanır, onu ayrıca not edin.) | ✅/❌ + not: |
| 5.7 | Offline, E ön planda | 5.1'i tekrarlayın. | Overlay görünür. Sistem bildirimi en fazla dakikada 1 kez gelir (B05). | Bildirim sayısı: ___ |
| 5.8 | Online/offline | Tek bir kapı çarpması ya da el çırpma. | Yanlış alarm çıkıyorsa not edin (B27: süre şartı yok, karar bekliyor). | not: |
| 5.9 | Online ve offline | Aynı ağlama sesini aynı mesafeden çalın; E'deki dB'yi okuyun. | İki mod arasındaki dB farkını not edin (B28). | Online ___ dB / Offline ___ dB |
| 5.10 | B ekranı **kapalı** (güç tuşu) | Online ve offline'da yayını izleyin. | Görüntü/ses kesilirse not edin. Beklenen kısıt: B01, foreground service yok. | Online ✅/❌ Offline ✅/❌ |

## 6. Bağlantı kopması ve geri gelmesi

| # | Ön koşul | Adımlar | Beklenen | Sonuç |
|---|---|---|---|---|
| 6.1 | Online bağlı | B'nin Wi-Fi'ını 10 sn kapatıp açın. | E'de durum hata/koptu olur. Geri geliyorsa ✅, gelmiyorsa ❌ (B08 / B36). | ✅/❌ + not: |
| 6.2 | Online bağlı | E'nin Wi-Fi'ını 10 sn kapatıp açın. | Aynı. | ✅/❌ + not: |
| 6.3 | 6.1 başarısızsa | B'de "Bağlantıyı kes" → yeni oda kodu; E yeni kodla bağlanır. | Bağlantı kurulur (geçici çözüm). | ✅/❌ |
| 6.4 | Online bağlı | E uygulamasını kapatıp açın; aynı kodla katılın. | B08: muhtemelen bağlanmaz. Sonucu not edin. | ✅/❌ |
| 6.5 | Herhangi biri | Online ↔ offline modu 5 kez hızlıca değiştirin. | Çökme olmaz. Siyah ekranda kalmaz (B18). | ✅/❌ + not: |
| 6.6 | Herhangi biri | Bebek ↔ ebeveyn rolünü 5 kez değiştirin. | Çökme olmaz; B rolüne dönünce kamera gelir. | ✅/❌ + not: |

## 7. Kayıt, galeri, paylaşım

| # | Ön koşul | Adımlar | Beklenen | Sonuç |
|---|---|---|---|---|
| 7.1 | Online, E izliyor | E'de kaydı başlatın; 30 sn sonra durdurun. | Galeride mp4 oluşur ve oynatılabilir. Sesin olmaması bilinen bir eksik (B16). | ✅/❌ + not: |
| 7.2 | Offline, E izliyor | Kaydı başlatın; 30 sn sonra durdurun. | Galeride GIF oluşur (B32: ~15 sn, 320 px, sessiz — bilinen kısıt). | ✅/❌ + süre: |
| 7.3 | 7.1 kaydı sürerken | B'den bağlantıyı kesin. | Kayıt otomatik durur, dosya **oynatılabilir**; kayıt butonu "Kaydı başlat"a döner (B14). | ✅/❌ + not: |
| 7.4 | Kayıt sürerken | Online/offline modunu değiştirin. | Kayıt durur, kaydedici takılı kalmaz (B14). | ✅/❌ + not: |
| 7.5 | Galeri | Videoya dokunun; oynarken 1 sn içinde geri çıkın. | Çökme olmaz (B30). | ✅/❌ |
| 7.6 | Galeri | Paylaş → WhatsApp/Drive. | Paylaşım ekranı açılır, dosya gider (3B: SharePlus API'si değişti). | ✅/❌ |
| 7.7 | Galeri, 5+ kayıt | Birini silin, listeyi kaydırın. | Thumbnail'lar tekrar tekrar yüklenmez, liste akıcıdır (B31). Silme onaysız olur (B49, bilinen). | ✅/❌ + not: |
| 7.8 | Sistem galerisi | Kayıtlar telefonun Galeri/Fotoğraflar uygulamasında da var mı? | Evet. | ✅/❌ |

## 8. Alarm geçmişi

| # | Ön koşul | Adımlar | Beklenen | Sonuç |
|---|---|---|---|---|
| 8.1 | 5.1'den sonra | E: Alarm geçmişi ekranı. | 2 dk ağlama için ~2–3 kayıt görünür (artık 5 sn'de bir değil, B29). Başlık uygulama dilinde (B40). | Kayıt sayısı: ___ |
| 8.2 | 8.1 | Uygulamayı kapatıp açın, geçmişe tekrar bakın. | Kayıtlar korunmuş. | ✅/❌ |
| 8.3 | 8.1 | "Geçmişi temizle". | Liste boşalır; uygulama yeniden açılınca da boş kalır. | ✅/❌ |

## 9. Pil, tema, dil

| # | Ön koşul | Adımlar | Beklenen | Sonuç |
|---|---|---|---|---|
| 9.1 | Online yayın kapalı | Yayını başlatıp durdurun ("Ekranı açık tut" kapalı). | Durdurduktan sonra ekran normal süresinde kapanır (B24). | ✅/❌ |
| 9.2 | "Ekranı açık tut" açık | 9.1'i tekrarlayın. | Ekran açık kalır. | ✅/❌ |
| 9.3 | Ayarlar | Tema: Açık / Koyu / Sistem. | Tüm ekranlar okunaklı. | ✅/❌ + not: |
| 9.4 | Ayarlar | Dil: English ↔ Türkçe. Ana ekranı, ayarları, offline cihaz listesini, galeriyi, alarm geçmişini ve multi-camera boş ekranını gezin. | Karışık dil yok. "Wi-Fi Direct" ifadesi hiçbir yerde geçmiyor (B40, B41). | ✅/❌ + gördüğünüz sabit metin: |
| 9.5 | 9.4 | Uygulamayı kapatıp açın. | Dil ve tema **sıfırlanır** (B35, bilinen). | ✅/❌ |

## 10. Uzun test (30+ dk)

| # | Ön koşul | Adımlar | Beklenen | Sonuç |
|---|---|---|---|---|
| 10.1 | Online, aynı Wi-Fi, B şarjda **değil**, B ekranı açık | 30–60 dk izleyin. Her 10 dk'da bir not alın. | Akış kesilmez, gecikme artmaz, uygulama çökmez. | Başlangıç pili B ___% E ___% / Bitiş B ___% E ___% / B ısısı: ___ |
| 10.2 | Offline, B ekranı açık | 30 dk aynı test. | Aynı. Görüntü yavaş yavaş gecikmeye başlıyorsa not edin (B10). | Pil B ___→___% / ısı: ___ |
| 10.3 | 10.1/10.2 sonunda | `adb shell dumpsys meminfo com.example.bebek_monitor_clean` | Başlangıç değeriyle karşılaştırın (bellek sızıntısı). | Başta ___ MB / sonda ___ MB |

## 11. Bu oturumda düzeltilen bug'lar için tekrar testleri

| Bug | Ne test edilecek | Nasıl | Sonuç |
|---|---|---|---|
| B04 | Bebek kendi alarm bildirimini almıyor | 5.2 | ✅/❌ |
| B05 | Ağlama sürerken en fazla dakikada 1 bildirim (online ve offline) | 5.1, 5.7 | ✅/❌ |
| B06 | Bebeğin ICE adayları doğru koleksiyonda | 2B.1. Ayrıca Firebase konsolunda `rooms/{kod}/callerCandidates` içinde bebeğin srflx adayları (`typ srflx`) görünmeli; `calleeCandidates` içinde sadece ebeveyninkiler olmalı. | ✅/❌ |
| B10 | Offline'da gecikme birikmiyor | 3.5, 10.2 | ✅/❌ |
| B11 | Sessizlikte ses çubuğu donmuyor | 3.7 | ✅/❌ |
| B12 | Offline bebek mikrofon izni; açılışta izinler sırayla | 1.1, 1.3 | ✅/❌ |
| B13 | Kayıt hatasından sonra buton takılmıyor | Online bağlıyken kaydı 5 kez hızlıca başlatıp durdurun; sonra bir hata mesajı çıkarsa bir kez daha deneyin. Buton "kayıtta" durumunda takılı kalmamalı. Hata durumu doğal olarak zor tetiklenir, o yüzden asıl kontrol: buton her zaman çalışıyor. | ✅/❌ |
| B14 | Kesinti veya mod değişiminde kayıt kapanıyor | 7.3, 7.4 | ✅/❌ |
| B15 | Multi-camera döngüye girmiyor | Menü → Çoklu kamera → B'nin oda kodunu ekleyin (E **bağlı değilken**). Firebase konsolunda `answer` alanı sürekli değişmemeli. | ✅/❌ |
| B18 | Mod değişimi sızıntısız | 6.5 | ✅/❌ |
| B19 | Pil göstergesi, çökme yok | 3.8. Ekranlar arası gidip gelirken logda `setState() called after dispose` olmamalı. | ✅/❌ |
| B20 | Offline bebek tarafında ses çubuğu akıcı | 3.3. Çubuk akıcıysa ✅ | ✅/❌ |
| B21 | Odada `offer: null` iken hata yok | 2A.1'den sonra logda `NoSuchMethodError` / `Room signaling listener error` olmamalı | ✅/❌ |
| B22 | Eski alarmlar tekrar gelmiyor | 5.6 | ✅/❌ |
| B23 | Dinleyici hataları yakalanıyor | Online bağlıyken B'de uçak modu → logda yakalanmamış istisna yok | ✅/❌ |
| B24 | Wakelock bırakılıyor | 9.1 | ✅/❌ |
| B25, B26 | Offline kopmada ve uygulama kapanışında çökme yok | 3.9 ve uygulamayı geri tuşuyla kapatın; logda `CameraException` yok | ✅/❌ |
| B29 | Alarm geçmişi seyrek ve kalıcı | 8.1, 8.2 | ✅/❌ |
| B30 | Oynatıcı hızlı çıkışta çökmüyor | 7.5 | ✅/❌ |
| B31 | Galeri thumbnail'ları önbellekte | 7.7 | ✅/❌ |
| B33 | Offline kayıt dosyası bozuk değil | 7.2'yi 3 kez arka arkaya yapın; hepsi açılıyor | ✅/❌ |
| B40, B41 | Metinler çevrili, "Wi-Fi Direct" yok | 9.4 | ✅/❌ |
| B46 | (iOS) offline mod çökmüyor | iOS cihaz varsa: Offline → Yayını başlat → "yalnızca Android" mesajı. Android-only testte atlayın. | ✅/❌/atlandı |
| WifiDirect kaldırma (9cc1419) | Offline mod hâlâ çalışıyor | Bölüm 3'ün tamamı | ✅/❌ |
| 3B (6f72d30) | withValues / surfaceContainerHighest renkleri | Eşleşme sayfası ve kontrol kartlarında renkler önceki sürümle aynı görünüyor mu (açık ve koyu tema) | ✅/❌ |

## 12. İkinci tur değişiklikleri (PLAN_NEXT)

| # | Değişiklik | Adımlar | Beklenen | Sonuç |
|---|---|---|---|---|
| 12.1 | D6 (`fe862a2`) | Üç nokta menüsünü açın. | "Çoklu kamera" seçeneği **görünmez**. Bebek/ebeveyn modu ve oda seçenekleri durur. | ✅/❌ |
| 12.2 | D7 (`0de98f1`) | Offline bağlıyken E'de kaydı başlatın. | "Offline kayıtlar sessiz, düşük çözünürlüklü GIF… En fazla süre: 20 s" mesajı görünür. | ✅/❌ |
| 12.3 | D7 | Kaydı **durdurmayın**, 25 sn bekleyin. | ~20. saniyede kayıt kendiliğinden durur, "süre sınırına ulaştı ve kaydedildi" mesajı çıkar, kayıt butonu normale döner. | ✅/❌ + kaç sn: |
| 12.4 | D7 | 12.3'teki GIF'i galeride oynatın, kronometreyle süresini ölçün. | Oynatma süresi ≈ kayıt süresi (≈20 sn; önceden hızlı/yavaş oynuyordu). | ___ sn |
| 12.5 | D7 | Offline kaydı 5 sn sonra elle durdurun. | ~5 sn'lik GIF kaydedilir. | ✅/❌ |
| 12.6 | D11 (`a982754`) | İlk kurulumdan sonra bebek modunda online ve offline yayın başlatın. | Mikrofon izni hâlâ isteniyor ve ses geliyor (noise_meter kaldırıldı, izinler değişmemeli). | ✅/❌ |
