# TEST_PLAN.md — telefonla manuel test

## G-AI — 1 Android + 1 iPhone kısa listesi (önce bunu yapın, ≈ 2 saat)

**Kısaltmalar:** A = Android telefon, I = iPhone. "A→I" = A bebek, I ebeveyn; "I→A" = I bebek, A ebeveyn.

### Hazırlık (bir kez)

1. **Kurulum (iki telefon da USB ile Mac'e bağlı).** Cihaz kimliklerini öğrenin:

   ```bash
   flutter devices
   ```

   ```bash
   cd /Users/feyruz/Desktop/baby_monitor_app && flutter run -d <ANDROID_ID> 2>&1 | tee android_run.log
   ```

   ```bash
   cd /Users/feyruz/Desktop/baby_monitor_app && flutter run --profile -d <IPHONE_ID> 2>&1 | tee iphone_run.log
   ```

   - iPhone'da `--profile` kullanın: debug derlemesi iOS'ta kablo çıkınca ya da ana ekrandan açılınca çalışmaz.
   - İlk kurulumda iPhone'da Ayarlar → Genel → VPN ve Cihaz Yönetimi → geliştirici sertifikasına güvenin.
   - Geliştirici Modu açık olmalı.
2. **Log toplama.** Her testte açık tutun.
   - Android'de filtreli canlı log için, `<ANDROID_ID>` `adb devices`'taki seri numarası:

     ```bash
     adb -s <ANDROID_ID> logcat -v time | grep -iE "flutter|webrtc|OfflineAudio|record|nearby|FirebaseMessaging|Push:|FATAL|AndroidRuntime"
     ```

   - Android'de tam log (sonradan arama için):

     ```bash
     adb -s <ANDROID_ID> logcat -v time > android_logcat.txt
     ```

   - iPhone: `flutter run` çıktısı `iphone_run.log`'a yazılıyor (Dart logları, `Push:` satırları). Yerel loglar için **Xcode → Window → Devices and Simulators → iPhone → Open Console** açın, sağ üstteki aramaya `Runner` yazın ve **Start** deyin. Çökme olursa aynı pencerede **View Device Logs**.
   - Önemli satırlar:
     - `Push: FCM token stored in room` / `Push: no FCM token`
     - `APNs token not available ... (registration: ...)`
     - `Standby noise meter`
     - `Offline microphone error`
     - `Unhandled Exception`
3. **Push için ön koşul:** Function deploy edilmiş ve APNs anahtarı Firebase'e yüklenmiş olmalı (REPORT.md). Deploy yoksa P1–P3'ü atlayın, diğerlerini yapın.

### Testler

| # | Ağ | Yön | Adımlar | Beklenen | Sonuç |
|---|---|---|---|---|---|
| AI-1 | Aynı Wi-Fi | A→I | A: Bebek modu → Oda kodu oluştur. I: Ebeveyn modu → kodu gir. | 10 sn içinde I'da görüntü + ses; iki tarafta "Bağlı". I'da bildirim izni sorulur → İzin ver. | ✅/❌ + süre: |
| AI-2 | Aynı Wi-Fi | A→I | I ön planda; A'nın yanında 5 sn ağlama sesi çalın. Sonra 1 sn'lik tek bir ses (el çırpma). | Ağlamada ~2 sn sonra I'da alarm ekranı ve titreşim; el çırpmada alarm **yok**. I'da alarm geçmişinde kayıt var. | ✅/❌ + gecikme: |
| AI-3 | Aynı Wi-Fi | A→I | I'da Ayarlar → eşik 60 → 75. A'da ayarları açın. | A'da eşik 75. 65 dB civarı ses artık alarm vermez. | ✅/❌ |
| AI-4 | Aynı Wi-Fi | A→I | A'da gece modu (ay simgesi); iki kez dokunup çıkın. | Ekran siyah, yayın I'da sürüyor; çift dokunuşla çıkılıyor. | ✅/❌ |
| AI-5 | Aynı Wi-Fi | A→I | I: Bağlantıyı kes → aynı kodla tekrar katıl. Sonra I'da Wi-Fi'ı 20 sn kapatıp açın. | Yeniden katılınca görüntü geri gelir. Wi-Fi dönünce ≤ 30 sn içinde kendiliğinden bağlanır. | ✅/❌ + süre: |
| AI-6 | Aynı Wi-Fi | A→I | I'da 20 sn kayıt → galeri → oynat → Fotoğraflar'a kaydet / paylaş. | Video oynuyor; Fotoğraflar izni sorulur, kayıt Fotoğraflar'da. | ✅/❌ |
| AI-7 | Aynı Wi-Fi | I→A | I: Bebek modu → Oda kodu oluştur ("gece modunu kullanın" uyarısı görünür). A: Ebeveyn → kodu gir. | A'da I'nın arka kamerası + ses. | ✅/❌ + süre: |
| AI-8 | Aynı Wi-Fi | I→A | **Ebeveyn bağlanmadan önce** I'nın yanında 5 sn ağlama sesi (A'yı henüz bağlamayın); sonra A'yı bağlayıp tekrar 5 sn ağlama. | İki durumda da I'nın ses çubuğu hareket eder. Bağlıyken A'da ~2 sn sonra alarm. (Bağlı değilken alarm, push deploy edildiyse A'ya bildirim olarak gelir.) | Bağlı değil ✅/❌ Bağlı ✅/❌ |
| AI-9 | Aynı Wi-Fi | I→A | I'da gece modu; 10 dk bırakın. A'dan izleyin. | Yayın kesilmez; I'nın ekranı kapanmaz. | ✅/❌ |
| AI-10 | Aynı Wi-Fi | I→A | A: Bağlantıyı kes → aynı kodla katıl. A'nın Wi-Fi'ını 20 sn kapatıp açın. Sonra A'da uygulamayı son uygulamalardan kapatıp I'nın yanında 5 sn ağlama sesi çalın. | Yeniden katılma ve otomatik dönüş AI-5 gibi. A kapalıyken I'nın ses çubuğu ~30 sn içinde yine hareket eder (iPhone ağlamayı algılamaya devam eder). | ✅/❌ |
| AI-11 | **Farklı ağ** (A Wi-Fi, I mobil veri) | A→I | AI-1, AI-2. | Bağlanırsa ✅. Bağlanmazsa bekleme süresini ve hatayı yazın (TURN yok, D4 kararı buna bağlı). | ✅/❌ + süre: |
| AI-12 | **Farklı ağ** (I Wi-Fi, A mobil veri) | I→A | AI-7, AI-8. | AI-11 ile aynı. | ✅/❌ + süre: |
| P1 | Herhangi | A→I | Push (deploy sonrası): I **ön planda**, A'da 5 sn ağlama. | I'da tek bir uyarı (uygulama içi alarm); çift bildirim yok. | ✅/❌ |
| P2 | Herhangi | A→I | I'da uygulamayı **arka plana** alın (Home), ekranı kilitleyin; A'da 5 sn ağlama. | Birkaç saniye içinde I'ya "Bebek ağlıyor" push'u. | ✅/❌ + gecikme: |
| P3 | Herhangi | A→I ve I→A | Ebeveyn uygulamasını **tamamen kapatın** (son uygulamalardan kaydırın); bebekte 5 sn ağlama. Yönü çevirip tekrarlayın. | İki yönde de ebeveyne push gelir. I→A'da bu, iPhone bebeğin ebeveyn yokken de ağlamayı algıladığını gösterir. | A→I ✅/❌ I→A ✅/❌ |
| OFF | — | — | Offline mod (Nearby). | **2. Android gerekli.** iPhone'da offline seçeneği yok (yalnızca Android). 2. Android bulunca bölüm 3 + 3.11. | atlandı |

**Bir şey ❌ çıkarsa:** İki log dosyasını (`android_logcat.txt`, `iphone_run.log`) ve Xcode Console'dan ilgili satırları saklayın. Notunuza testin numarasını ve saatini yazın.

---

## ★ Önce bunu okuyun: emülatörde ne test edildi, telefonda ne kaldı

Otonom oturumda (22.11.2026) iki Android emülatöründe ve iki iOS simülatöründe otomatik uçtan uca testler çalıştırıldı (`scripts/run_e2e.py`, Firebase Emulator Suite; sonuçlar `test-results/`). Her madde için:

- **Emülatör:** ✅ otomatik testte geçti · ❌ başarısız · — emülatörde test edilmedi ya da edilemez (Nearby, gerçek ses, arka plan, sistem diyalogları).
- **Gerçek cihaz:** **Evet** = telefonda mutlaka bakılmalı (aşağıdaki kısa listede) · Hayır = emülatör sonucu yeterli, vaktiniz olursa bakın.

### Telefonda yapılacak en kısa liste (≈ 1,5 saat, 2 Android + varsa 1 iPhone)

| # | Test | Kapsadığı maddeler | Neden emülatör yetmiyor |
|---|---|---|---|
| G1 | Temiz kurulum: izin diyalogları, pil optimizasyonu, ebeveynde bildirim izni | 1.1, 1.6, 12.36 | Testlerde izinler `adb pm grant` ile verildi; diyaloglar hiç görünmedi. |
| G2 | Bebek Wi-Fi, ebeveyn **mobil veri**: bağlan, 5 dk izle | 2B.1, 2B.3 | İki emülatör aynı makinede, NAT/TURN sorunu oluşmuyor (B07). |
| G3 | Offline: yayın, arama, bağlan, ses, sessizlik, uzaklaşma, 20 sn kayıt; yeni offline ses (3.11) | 3.1–3.3, 3.7, 3.9, 3.11, 12.3 | Nearby Connections emülatörde çalışmıyor. |
| G4 | Function deploy edildikten sonra: ebeveyn arka planda / kilitli / kapalı → push | 12.39–12.42, 5.3–5.5 | Emülatörde Function çalıştı ama gerçek FCM gönderilmedi (DECISIONS A3). |
| G5 | Gerçek ağlama sesiyle eşik ayarı ve online/offline dB farkı | 12.13, 12.17, 5.9 | Testlerde ses seviyesi `DebugHooks.fakeNoiseDb` ile taklit edildi. |
| G6 | Gecikme ve ses kalitesi | 4.1, 4.3 | Emülatörde kamera/mikrofon sanal. |
| G7 | 30 dk gece modunda yayın, bebek ekranı kapalıyken davranış | 10.1, 12.11, 5.10 | Pil, ısı, Doze ve ekran kapanması emülatörde gerçekçi değil. |
| G8 | Kaydı oynatma, paylaşma, sistem galerisinde görme | 7.1, 7.6, 7.8 | Testte yalnızca başlat/durdur ve galeri açılışı doğrulandı. |
| G9 | iPhone (varsa): açılış, kamera görüntüsü, ses, bildirim | Bölüm 13 | Simülatörde kamera yok, push için APNs gerekiyor. |

### Madde madde emülatör sonucu

| Madde | Emülatör | Gerçek cihaz | Not |
|---|---|---|---|
| 1.1 | — | **Evet** (G1) | İzinler komutla verildi |
| 1.2 | ✅ | Hayır | Sanal kamera ile yayın yapıldı |
| 1.3–1.5 | — | **Evet** (G3) | Offline izinleri |
| 1.6 | — | **Evet** (G1) | Testte pil optimizasyonu listesine komutla eklendi |
| 2A.1, 2A.2 | ✅ | Hayır | Kod oluşturma, katılma, "Bağlı" durumu |
| 2A.3 | — | Hayır | Kamera değiştirme test edilmedi |
| 2A.4 | ✅ | Hayır | Bebek kesince oda siliniyor |
| 2B.1–2B.3 | — | **Evet** (G2) | |
| 3.1–3.10 | — | **Evet** (G3: 3.1–3.3, 3.7, 3.9) | Nearby emülatörde yok |
| 3.11 | Kısmen: yeni ses kanalının mikrofon ve oynatıcısı emülatörde ✅ (smoke test); Nearby üzerinden — | **Evet** (G3) | B68: `sound_stream` yerine `record` + kendi oynatıcımız |
| 4.1–4.4 | — | **Evet** (G6: 4.1, 4.3) | |
| 5.1 | ✅ | Hayır | Sahte ağlama: 70 sn'de 2 alarm (60 sn sınırı) |
| 5.2 | — | Hayır | |
| 5.3–5.5 | — | **Evet** (G4) | |
| 5.6 | — | Hayır | |
| 5.7 | — | Hayır (G3 ile birlikte bakılabilir) | Offline |
| 5.8 | ✅ | Hayır | 1 sn'lik ses alarm vermedi |
| 5.9 | — | **Evet** (G5) | |
| 5.10 | — | **Evet** (G7) | |
| 6.1 | — | Hayır | Bebek tarafında ağ kesintisi test edilmedi |
| 6.2 | ✅ | Hayır | Ebeveynde uçak modu → kendiliğinden yeniden bağlandı |
| 6.3 | — | Hayır | |
| 6.4 | ✅ | Hayır | Çıkıp aynı kodla tekrar katılma |
| 6.5, 6.6 | — | Hayır | |
| 7.1 | ✅ | **Evet** (G8) | Başlat/durdur çökmüyor; dosyanın oynatılması doğrulanmadı |
| 7.2–7.5 | — | Hayır | |
| 7.6 | — | **Evet** (G8) | |
| 7.7 | — | Hayır | |
| 7.8 | — | **Evet** (G8) | |
| 8.1 | ✅ | Hayır | Geçmişte 2 kayıt, uygulama dilinde |
| 8.2, 8.3 | — | Hayır | |
| 9.1, 9.2 | — | Hayır | |
| 9.3 | ✅ | Hayır | Koyu tema |
| 9.4 | ✅ | Hayır | TR → EN → TR geçişi |
| 9.5 | — | Hayır | |
| 10.1–10.3 | — | **Evet** (G7: 10.1) | |
| 11.x | Yukarıdaki maddelere bağlı | | |
| 12.1 | — | Hayır | |
| 12.2–12.5 | — | **Evet** (G3: 12.3) | Offline kayıt |
| 12.6 | — | Hayır (G1 ile birlikte) | |
| 12.7, 12.8 | ✅ | Hayır | Gece modu katmanı, çift dokunuşla çıkış |
| 12.9, 12.10 | — | Hayır | |
| 12.11 | — | **Evet** (G7) | |
| 12.12 | — | Hayır | |
| 12.13 | — | **Evet** (G5) | |
| 12.14, 12.15 | ✅ | Hayır | Alarm gecikmesi ~2,5–2,7 sn |
| 12.16 | ✅ | Hayır | Eşik 80 ebeveynden bebeğe geçti |
| 12.17 | — | **Evet** (G5) | |
| 12.18 | — | Hayır | Offline |
| 12.19 | ✅ | Hayır | |
| 12.20, 12.21 | — | Hayır | |
| 12.22 | ✅ | Hayır | |
| 12.23 | — | Hayır | |
| 12.24 | ✅ (kısmen) | Hayır | Oda siliniyor; ebeveynin "odayı kapattı" mesajı ayrıca test edilmedi |
| 12.25 | — | Hayır | |
| 12.26–12.28 | ✅ | Hayır | Biçim, küçük harf, yanlış kod |
| 12.29 | — | Hayır | |
| 12.30 | ✅ | Hayır | Süre artık **12 sa** (B58) |
| 12.31–12.34 | ✅ | Hayır | Kurallar emülatörde yüklüydü; süresi geçmiş kod ve üçüncü cihaz reddedildi |
| 12.35 | — | Hayır | |
| 12.36 | — | **Evet** (G1) | |
| 12.37 | — | Hayır (G4 ile birlikte) | |
| 12.38 | ✅ | Hayır | Token ve dil odaya yazıldı |
| 12.39–12.42 | ✅ Function / — push | **Evet** (G4) | Function emülatörde çalıştı, başlık/gövde doğru; gerçek push gönderilmedi |
| 12.43 | ✅ | Hayır | 60 sn sınırı |

---

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
| 3.11 | **Güncel `dev` sürümü iki Android'e kurulu** (B68: `record` + kendi oynatıcımız), offline bağlı | 1) E'de B'nin yanındaki konuşmayı 1 dk dinleyin. 2) B'nin mikrofonunu kapatın (sessizlik). 3) Ağlama sesi çalın. 4) E'de bağlantıyı kesip yeniden bağlanın; B'de offline ↔ online modu bir kez değiştirip geri gelin. | 1) Ses anlaşılır, cızırtı ve takılma yok; eski sürümle (`sound_stream`) aynı kalitede. 2) Ses çubuğu ~0'a iner. 3) dB değerleri online moddakiyle aynı aralıkta; ~2 sn sonra alarm. 4) Ses yeniden gelir; logda `Offline microphone error` / `AudioTrack` hatası yok. İlk açılışta kamera izninden sonra mikrofon izni sorulur. | ✅/❌ + not: |

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
| 12.7 | D1-a gece modu (`cb3b3e8`) | B bebek modunda yayındayken video kartının sol üstündeki ay simgesine dokunun. | Ekran tamamen siyah olur, parlaklık en düşüğe iner, "Çıkmak için iki kez dokunun" yazısı birkaç sn görünüp kaybolur, sağ üstte sönük bir bağlantı noktası var. Yayın E'de sürüyor. | ✅/❌ |
| 12.8 | D1-a | Gece modunda tek dokunun; sonra iki kez dokunun. | Tek dokunuş ipucunu tekrar gösterir; çift dokunuş gece modundan çıkar, parlaklık eski haline döner. | ✅/❌ |
| 12.9 | D1-a | Gece modunda geri tuşuna basın. | Uygulama kapanmaz, gece modundan çıkılır. | ✅/❌ |
| 12.10 | D1-a | Ayarlar → "Bağlanınca gece moduna geç" açık; online ve offline'da E bağlansın. | Bağlantı kurulunca B otomatik gece moduna geçer. | Online ✅/❌ Offline ✅/❌ |
| 12.11 | D1-a | Gece modunda 30 dk bırakın (B şarjda değil). | Ekran kapanmaz, yayın kesilmez; pil düşüşü ve ısı notu. | Pil ___→___% / ısı: |
| 12.12 | D1-a | Gece modundayken "Bağlantıyı kes" (önce çıkıp) veya E'den bağlantı kesilsin; sonra ekranı kendi haline bırakın. | Yayın bitince parlaklık normal, ekran normal sürede kapanır ("Ekranı açık tut" kapalıysa). | ✅/❌ |
| 12.13 | D5 tek dB ölçeği (`9a0c363`) | Online ve offline'da aynı ağlama sesini aynı mesafeden çalın; E'deki dB'yi okuyun. | İki modda değerler birbirine yakın (±3 dB). Önceden offline ~10 dB düşüktü. | Online ___ / Offline ___ dB |
| 12.14 | D5 2 sn şartı (`bfc5f26`) | B'nin yanında tek bir el çırpma / kapı çarpması. | Alarm **çalmaz** (ses çubuğu zıplar ama overlay/bildirim yok). | ✅/❌ |
| 12.15 | D5 | Ağlama sesini 1 sn çalıp durdurun; sonra 3 sn çalın. | 1 sn'lik ses alarm vermez; 3 sn'lik ses ~2. saniyede alarm verir. | ✅/❌ + gecikme: |
| 12.16 | D5 eşik senkronu (`04ce566`) | Online bağlıyken E'de Ayarlar → eşiği 60'tan 75'e çekin. 2 sn bekleyin. B'de Ayarlar'ı açın. | B'nin eşiği de 75 görünür; ses çubuğundaki "Eşik" yazısı iki cihazda 75. | ✅/❌ |
| 12.17 | D5 | 12.16'dan sonra 60–70 dB civarı bir sesle test edin. | 75 eşiğinde alarm çalmaz; eşiği 60'a indirince çalar. Kalibrasyon için uygun eşiği not edin. | Uygun eşik: ___ dB |
| 12.18 | D5 | Aynı testleri offline'da yapın (E'de eşik değişimi → B). | Offline'da da eşik B'ye geçer. | ✅/❌ |
| 12.19 | B08 yeniden katılma (`dd72f41`) | **İki telefona da yeni sürümü kurun** (eski sürümle eşleşmez). Online bağlanın; E'de "Bağlantıyı kes"; aynı kodla tekrar katılın. | 10 sn içinde görüntü tekrar gelir. B'nin kamerası bu sırada kapanmaz. | ✅/❌ + süre: |
| 12.20 | B08 | Bağlıyken E uygulamasını son uygulamalardan kapatın, açın, aynı kodu girin. | Bağlanır. | ✅/❌ |
| 12.21 | B08 | Bağlıyken E'den 5 kez çık-gir yapın. | Her seferinde bağlanır; B'de kamera önizlemesi hiç kesilmez; Firebase konsolunda `callerCandidates`/`calleeCandidates` yalnızca son oturumun adaylarını içerir. | ✅/❌ |
| 12.22 | B08 otomatik yeniden katılma | Bağlıyken E'nin Wi-Fi'ını 30 sn kapatıp açın. | E önce "bağlanıyor" gösterir; Wi-Fi gelince en geç ~30 sn içinde kendiliğinden yeniden bağlanır (logda `Rejoin attempt`). | ✅/❌ + süre: |
| 12.23 | B36 | Bağlıyken B'nin Wi-Fi'ını 5 sn kapatıp açın. | E'de kısa süre "bağlanıyor", sonra görüntü geri gelir; hata mesajı çıkmaz. | ✅/❌ |
| 12.24 | B08 | Bağlıyken B'de "Bağlantıyı kes" (oda silinir). | E bir süre yeniden dener, sonra "Bebek cihazı odayı kapattı" mesajıyla durur. | ✅/❌ |
| 12.25 | B08 | B yayın yapıyor, E henüz bağlanmadı: B'nin yanında ağlama sesi. | B'nin ses çubuğu hareket eder (bekleme peer'ı ses seviyesini ölçüyor). | ✅/❌ |

### 12B. D3 + D8 (güvenlik, yeni oda kodu)

> **Sıra önemli:** (1) Firebase konsolunda Anonymous girişi açın, (2) iki telefona yeni sürümü kurun, (3) 12.26–12.31'i mevcut kurallarla test edin, (4) kuralları yayınlayın, (5) 12.32–12.35'i test edin.

| # | Değişiklik | Adımlar | Beklenen | Sonuç |
|---|---|---|---|---|
| 12.26 | D3 kod (`0d37d40`) | B: "Oda kodu oluştur". | Kod `ABCD-EF23` biçiminde, 8 karakter; altında "10 dakika içinde girin" ipucu. | ✅/❌ |
| 12.27 | D3 | E: kodu küçük harfle ve tiresiz girin (ör. `abcdef23`). | Bağlanır (büyük harfe çevrilir, tire yok sayılır). | ✅/❌ |
| 12.28 | D3 | E: yanlış bir kod girin. | "Kod hatalı, süresi dolmuş veya başka bir cihazla eşleşmiş" mesajı; otomatik yeniden deneme yok. | ✅/❌ |
| 12.29 | D3 | Anonymous giriş kapalıyken (ilk kurulumda, konsolda açmadan) kod oluşturmayı deneyin. | "Bu uygulama için giriş açık değil (Firebase: Anonim giriş)" mesajı. *(İsteğe bağlı)* | ✅/❌ |
| 12.30 | D8 | Yayın sırasında Firebase konsolunda odayı açın. | `expiresAt` ≈ şimdi + 12 sa (B58); adaylar ve alarmlarda da `expiresAt` var; `cryUpdated` ~5 sn'de bir değişiyor. | ✅/❌ |
| 12.31 | D3 | Konsolda odanın `ownerUid` ve (E bağlanınca) `viewerUid` alanları dolu. | İki farklı uid. | ✅/❌ |
| 12.32 | D3 kurallar yayınlandıktan sonra | 12.26 + 12.27'yi tekrarlayın, sonra 10 dk bekleyen bir kodla katılmayı deneyin. | Normal akış çalışır; 10 dk'dan eski, kullanılmamış kod "geçersiz/süresi dolmuş" verir. | ✅/❌ |
| 12.33 | D3 | Üçüncü bir telefonla (veya E'de uygulama verisini silip) aynı kodla katılmayı deneyin. | Reddedilir; B ile E'nin bağlantısı etkilenmez. | ✅/❌ |
| 12.34 | D3 + B08 | E çıkıp aynı kodla tekrar katılsın (12.19). | Kurallar varken de çalışır (aynı uid). | ✅/❌ |
| 12.35 | D3 | Uygulama logunda `PERMISSION_DENIED` / `permission-denied` arayın (normal akışta). | Yok (yalnızca 12.28/12.32/12.33'te beklenir). | ✅/❌ |

### 12C. D2 (FCM) — uygulama tarafı şimdi, push deploy sonrası

| # | Değişiklik | Adımlar | Beklenen | Sonuç |
|---|---|---|---|---|
| 12.36 | B42 (`1f5a398`) | Temiz kurulum: uygulamayı açın (bebek modu). | Açılışta bildirim izni **sorulmaz**. Ebeveyn moduna geçince sorulur; reddedilirse "Bildirim izni gerekli" + Ayarlar uyarısı. | ✅/❌ |
| 12.37 | B47 | Ebeveynde bir ağlama bildirimi alın. | Durum çubuğunda beyaz kare değil, zil ikonu görünür. | ✅/❌ |
| 12.38 | D2 token | E bağlandıktan sonra Firebase konsolunda odaya bakın. | `viewerFcmToken` (uzun metin) ve `viewerLocale` (`tr`/`en`) dolu. | ✅/❌ |
| 12.39 | D2 (Function **deploy edildikten sonra**) | E bağlı; E'de uygulamayı arka plana alın (Home), B'de 3 sn ağlama sesi. | E'ye birkaç saniye içinde "Bebek ağlıyor — Ses seviyesi: XX dB" bildirimi gelir. | ✅/❌ + gecikme: |
| 12.40 | D2 | E ekranı kilitli, 10 dk bekleyin, sonra 12.39. | Bildirim gelir (Doze'a rağmen). | ✅/❌ + gecikme: |
| 12.41 | D2 | E uygulamasını son uygulamalardan kapatın (zorla durdurmayın), 12.39. | Bildirim gelir. | ✅/❌ |
| 12.42 | D2 | E ön planda, 12.39. | **Tek** bildirim görünür (Firestore + FCM aynı etiketle birleşir); iki kez ses çalarsa not edin. | ✅/❌ + not: |
| 12.43 | D2 | 2 dk sürekli ağlama. | En fazla ~2–3 push (60 sn bekleme). | Push sayısı: ___ |

## 13. iPhone (G9)

> Kurulum adımları: REPORT.md → "iOS: sizin yapmanız gerekenler". Simülatörde kamera yok (BLOCKERS 1) ve push için APNs anahtarı gerekiyor; bu yüzden aşağıdakiler yalnızca gerçek iPhone'da doğrulanabilir.

| # | Adımlar | Beklenen | Emülatör | Sonuç |
|---|---|---|---|---|
| 13.1 | Uygulamayı ilk kez açın. | Çökmeden açılır (B63). Kamera/mikrofon izin metinleri telefon dilinde (TR/EN). | ✅ simülatörde açılıyor | ✅/❌ |
| 13.2 | iPhone bebek, Android ebeveyn: online bağlanın. | Android'de iPhone kamerasının görüntüsü ve sesi gelir. | ✅ yalnızca ses (simülatörde kamera yok) | ✅/❌ |
| 13.3 | Android bebek, iPhone ebeveyn. | iPhone'da görüntü ve ses gelir. | Karma test: REPORT.md | ✅/❌ |
| 13.4 | iPhone bebekken oda oluşturun. | "iPhone'da kamera arka planda çalışmaz, gece modunu kullanın" uyarısı ve "Gece modu" düğmesi. | — | ✅/❌ |
| 13.5 | iPhone bebek yayındayken ekranı kilitleyin veya uygulamadan çıkın. | Görüntü durur (iOS kısıtı); ses arka plan moduyla bir süre sürebilir. Ne olduğunu not edin. | — | not: |
| 13.6 | Ayarlar → Offline. | Anahtar yok; "Offline mod yalnızca Android'de" açıklaması var (A7). | ✅ | ✅/❌ |
| 13.7 | APNs anahtarı yüklendikten ve Function deploy edildikten sonra: iPhone ebeveyn arka planda, Android bebekte ağlama. | iPhone'a push gelir. | — (simülatörde FCM token yok) | ✅/❌ + gecikme: |
| 13.8 | Ebeveynde kayıt başlatıp durdurun, galeriyi açın, Fotoğraflar'a kaydedin. | Fotoğraf izni sorulur, kayıt Fotoğraflar'da görünür. | — | ✅/❌ |

## 14. Ninni v2 — Faz 1 (güvenilirlik)

> B = bebek telefonu, E = ebeveyn telefonu. Logcat'te `Monitor service`, `Connection watchdog` satırlarını arayın.

| # | Özellik | Adımlar | Beklenen | Sonuç |
|---|---|---|---|---|
| V1.1 | 5.12 servis (Android B, online) | B'de oda oluşturun, E bağlansın. B'de ekranı kapatın (güç tuşu), 10 dk bekleyin. | Bildirim çubuğunda "Ninni yayında". E'de görüntü ve ses **kesilmeden** sürer; ağlama alarmı ve push çalışır. | ✅/❌ + kaç dk: |
| V1.2 | 5.12 servis | V1.1'de B'de Home'a basıp başka bir uygulama açın, 5 dk. | Görüntü/ses sürer. (Kamera duruyorsa logcat'i gönderin: en büyük risk budur.) | ✅/❌ |
| V1.3 | 5.12 servis (offline) | Offline modda V1.1. | Nearby görüntü + ses sürer. | ✅/❌ |
| V1.4 | 5.12 servis | B'de "Bağlantıyı Kes". B'yi son uygulamalardan kaydırıp kapatın (ayrı denemede). | İki durumda da "Ninni yayında" bildirimi kaybolur. | ✅/❌ |
| V1.5 | 5.12 Android 14+ | B'de kamera iznini reddedip oda oluşturmayı deneyin. | Uygulama çökmez (servis yalnızca izinli türlerle başlar). | ✅/❌ |
| V1.6 | 5.10 arka planda dinleme (Android E) | E bağlı; E'yi kilitleyin, B'nin yanında konuşun. | E'de ses duyulur; bildirimde "Ninni dinliyor". | ✅/❌ |
| V1.7 | 5.10 (iPhone E) | iPhone E bağlı; kilitleyin, B'nin yanında konuşun. | Ses duyulmaya devam eder (iOS `audio` arka plan modu). | ✅/❌ |
| V1.8 | 5.10 kapalı | E Ayarlar → "Arka planda dinle" kapalı; E'yi kilitleyin. | Ses kesilir (Android: bildirim yok). Açınca ses geri gelir. Ağlama bildirimleri yine gelir. | ✅/❌ |
| V1.9 | 5.6 bağlantı koptu | Bağlıyken B'de Wi-Fi'ı kapatın. | E'de ~5–20 sn içinde tam ekran amber "Bebek telefonuyla bağlantı koptu", alarm sesi + titreşim, bildirim. | ✅/❌ + sn: |
| V1.10 | 5.6 | V1.9'da "Alarmı sustur". | Ses/titreşim durur, ekran kalır. | ✅/❌ |
| V1.11 | 5.6 | B'de Wi-Fi'ı açın. | Bağlantı dönünce ekran ve bildirim kendiliğinden kapanır. | ✅/❌ + sn: |
| V1.12 | 5.6 | B uygulamasını zorla kapatın. | E'de alarm; "Tekrar dene" çalışır (B açılınca yeni oda gerekiyorsa "oda kapandı" görünür ve alarm durur). | ✅/❌ |
| V1.13 | 5.6 | E ekranı kilitliyken V1.9. | Alarm sesi kilit ekranında da çalar, bildirim görünür. | ✅/❌ |
| V1.14 | 5.7 pil | B'nin pili %15'in altındayken şarjdan çıkarın (ya da `adb shell dumpsys battery set level 12; adb shell dumpsys battery unplug`). | E'de **bir kez** amber "Bebek telefonunun pili azaldı" kartı; E arka plandaysa bildirim. B şarja takılınca kart kapanır. | ✅/❌ |
| V1.15 | 5.7 push (kurallar + Function deploy sonrası) | E uygulaması kapalı, V1.14. | E'ye "Bebek telefonunun pili azaldı — Pil %12…" push'u gelir; ağlama bildirimini **değiştirmez** (ayrı bildirim). | ✅/❌ |
| V1.16 | Uzun test | B ve E 2 saat açık, B'nin ekranı kapalı. | Isınma ve pil tüketimini not edin; yayın kesilmez. | Pil %/saat: |

## 15. Ninni v2 — Faz 2 (yeni tasarım)

> Referans: `design/mockups/*.dc.html`. Yazı tipi uygulamaya gömülü (internetsiz de Plus Jakarta Sans görünmeli).

| # | Ekran | Adımlar | Beklenen | Sonuç |
|---|---|---|---|---|
| V2.1 | Simge, ad | Kurulumdan sonra ana ekrana bakın (Android ve iPhone). | "Ninni" adı; koyu zeminde krem hilal + kayısı nokta. Android 13+ "temalı simge" kapalıyken de düzgün. Bildirim çubuğunda beyaz hilal. | ✅/❌ |
| V2.2 | Açılış | Uygulamayı soğuk başlatın. | Koyu (#12142B) zemin + ortada simge; beyaz flaş yok. | ✅/❌ |
| V2.3 | Karşılama 1–3 | Temiz kurulumda açın. | Yıldızlar yanıp söner, ay "nefes alır". "Geç" 3. sayfaya atlar. İzin pencereleri **yalnızca** "İzin ver"e basınca açılır; verilenlerde "Verildi". Reddedince "Ayarları aç". İkinci açılışta karşılama yok. | ✅/❌ |
| V2.4 | Karşılama | Ayarlar → "Tanıtımı tekrar göster". | Karşılama açılır, "Hazırım" ile ayarlara döner. | ✅/❌ |
| V2.5 | Rol seçimi | Sistem temasını açık/koyu yapın. | Rol ekranı temaya uyar; "Bebeğin yanında" kartı her zaman koyu. iPhone'da "İnternetsiz mod" satırı yok. | ✅/❌ |
| V2.6 | Bebek: kod | "Bebeğin yanında". | Kamera/mikrofon izni (gerekirse), 8 kutulu kod, 10:00'dan geri sayım, Paylaş (sistem paylaşım menüsü) ve Kopyala ("Kod kopyalandı"). Nabız noktası. | ✅/❌ |
| V2.7 | Bebek: kod süresi | 10 dk bekleyin. | "Kodun süresi doldu" + "Yeni kod". | ✅/❌ |
| V2.8 | Ebeveyn: kod | Kodu yazın, sonra yapıştırın (`abcd-ef23` biçiminde de). | Harfler büyük harfe döner; 0/O/1/I yazınca kutular sallanır; 8. harfte küçük zıplama; "Bağlan" ancak 8 harfle açılır. Yanlış kodda kırmızı/kayısı hata metni. | ✅/❌ |
| V2.9 | Bebek: yayında | Ebeveyn bağlanınca. | Bebek ekranı yayın ekranına geçer: "Ebeveyn bağlı" (nane), pil, oda kodu, CANLI, ses seviyesi kartı (eşik işareti), "Gece moduna geç", "Yayını bitir" (onay sorar). | ✅/❌ |
| V2.10 | Gece modu | "Gece moduna geç". | Siyah, sönük saat, "Yayın sürüyor · ebeveyn bağlı"; iki dokunuşla ve geri tuşuyla çıkış. Animasyon yok. | ✅/❌ |
| V2.11 | Ebeveyn: canlı | Bağlıyken. | Üstte görüntü (oda adı, kod, CANLI, "Bağlantı iyi", bebek pili, tam ekran), ses çubukları gerçek sesle oynar (~10 Hz), "Bebek sakin" · dB · son alarm, Geçmiş. Kaydet / Çevir / Ayarlar. | ✅/❌ |
| V2.12 | Ağlama alarmı | B'de 3 sn ağlama sesi. | E'de tam ekran kayısı alarm, halkalar, ses + titreşim; "Görüntüyü aç" canlı ekrana döner; "5 dk sessize al" 5 dk boyunca alarmı açmaz; "Tamam" kapatır. Ağlama bitince ses durur, ekranda "durdu". | ✅/❌ |
| V2.13 | Alarm geçmişi | Birkaç alarmdan sonra Geçmiş. | Gece özeti: alarm sayısı, toplam ağlama, en uzun sessiz dönem; Bu gece / Dün / 7 gün; boş durumda "Sakin bir gece!". | ✅/❌ |
| V2.14 | Ayarlar | Hassasiyet, kalite, dil, tema. | Kaydırıcı 40–80 dB; Tasarruf/Dengeli/Net görüntüyü değiştirir; dil ve tema uygulama yeniden açılınca korunur. | ✅/❌ |
| V2.15 | Erişilebilirlik (ön kontrol) | TalkBack / VoiceOver açık, ekranları gezin. | Düğmeler ve durumlar anlamlı okunur (ayrıntılı kontrol Faz 4). | ✅/❌ |
| V2.16 | Küçük ekran | iPhone SE / küçük Android. | Taşma yok; uzun ekranlar kayar. | ✅/❌ |

## 16. Ninni v2 — Faz 3 (yeni özellikler)

| # | Özellik | Adımlar | Beklenen | Sonuç |
|---|---|---|---|---|
| V3.1 | 5.1 QR | B'de kod ekranı; E'de "QR kodu okut" ile QR'ı okutun. | E otomatik bağlanır. Ninni dışı bir QR'da "Bu bir Ninni oda kodu değil". | ✅/❌ |
| V3.2 | 5.1 QR izin yok | E'de kamera iznini reddedip "QR kodu okut". | "Kamera izni yok… kodu elle girin" + "Ayarları aç"; elle giriş çalışır. | ✅/❌ |
| V3.3 | 5.2 Oda adı | B'de kod kartında "Oda adı"na dokunup "Bebek odası 2" yazın; E bağlansın. | E'de canlı ekranda ve son odalar kartında bu ad. Ad, B'de sonraki odalarda da korunur. | ✅/❌ |
| V3.4 | 5.2 Son oda | E bağlantıyı kessin; kod ekranında "Son bağlandığınız" kartına dokunun. | Tek dokunuşla aynı odaya yeniden bağlanır. Oda kapandıysa hata ve kart kaybolur. | ✅/❌ |
| V3.5 | 5.3 Bas-konuş | E'de "Basılı tutun, bebeğe konuşun"u basılı tutup konuşun (ilk seferde mikrofon izni). | B'nin **hoparlöründen** ses gelir (~0,5 sn gecikme), bırakınca kesilir. Yankı rahatsız edici mi? Not edin. | ✅/❌ + not: |
| V3.6 | 5.3 Alarm yok | E konuşurken B'nin yanında yüksek sesle konuşulsun. | Konuşma boyunca ve 3 sn sonrasına kadar ağlama alarmı **gelmez**; sonra normal. | ✅/❌ |
| V3.7 | 5.4 Ninni | E'de Ninni → her ses, ses düzeyi, 15/30/60/Sürekli. | B'de ses çalar, kesintisiz döngü; zamanlayıcı bitince durur ve E'de "Çalıyor" kalkar. iPhone B'de WebRTC sesi bozulmaz. | ✅/❌ |
| V3.8 | 5.4 Alarm kaçmasın | Beyaz gürültü %70'te çalarken B'nin yanında 3 sn ağlama sesi. | Alarm gelir (eşik en fazla +12 dB yükselir). Ninni tek başına (ağlama yokken) 2 dk boyunca alarm üretmez. | ✅/❌ |
| V3.9 | 5.4 "Dandini" | Dandini dandini'yi dinleyin. | Melodi tanınıyor mu? (BLOCKERS 9) | not: |
| V3.10 | 5.5 Gece lambası | E'de gece lambasını açın, renkleri değiştirin. | B gece moduna geçer, ekran seçilen renkte yumuşak yanar (%25 parlaklık); kapatınca kararır. | ✅/❌ |
| V3.11 | 5.8 Sessize al | Alarm ekranında "5 dk sessize al", 1 dk sonra yeniden ağlama. | 5 dk boyunca alarm ekranı/sesi yok; geçmişe yine yazılır. 5 dk sonra normal. | ✅/❌ |
| V3.12 | 5.9 Gecelik özet | Birkaç alarmlı bir geceden sonra Geçmiş. | Alarm sayısı, toplam ağlama süresi (her olayın süresi), en uzun sessiz dönem mantıklı. | ✅/❌ |
| V3.13 | 5.11 AZ | Ayarlar → Dil → Azərbaycanca; tüm ekranları gezin. | Tüm metinler Azerbaycanca, taşma yok. E arka plandayken push AZ (Function deploy sonrası). | ✅/❌ |
| V3.14 | Offline | İnternetsiz modda ninni ve gece lambası. | Nearby üzerinden çalışır (bas-konuş offline'da yok). | ✅/❌ |

## 17. Ninni v2 — Faz 4 (cila)

| # | Konu | Adımlar | Beklenen | Sonuç |
|---|---|---|---|---|
| V4.1 | Ekran okuyucu | TalkBack (Android) / VoiceOver (iPhone) açık; karşılama → rol → kod → canlı → alarm → ayarlar. | Her düğme anlamlı okunur ("Geri", "Kamerayı çevir", "Bebeğe konuşun…"); oda kodu harf harf okunur; alarm ekranı açılınca duyurulur. Bas-konuş çift dokunuşla açılıp kapanır. | ✅/❌ |
| V4.2 | Büyük yazı | Sistem yazı boyutu en büyük + kalın yazı. | Hiçbir ekranda kesilen/taşan metin yok; uzun ekranlar kayar. | ✅/❌ |
| V4.3 | Küçük/büyük ekran | iPhone SE (2./3. nesil) ve bir tablet (iPad / Android tablet). | SE'de taşma yok; tablette içerik ortada, en fazla ~560 pt genişlikte. | ✅/❌ |
| V4.4 | Bebek cihazı ısı/pil | B 1 saat yayında: 30 dk normal ekran, 30 dk gece modu. | Pil tüketimi ve ısınmayı not edin; gece modunda belirgin şekilde daha az olmalı. | %/saat: |
| V4.5 | Hareket azaltma | Sistemde "Animasyonları kaldır"/"Hareketi azalt" açık. | Yıldızlar, ay, halkalar, nabız durur; sayfa geçişleri anlık. | ✅/❌ |
| V4.6 | Mağaza görüntüleri | `flutter run --dart-define=NINNI_DEMO=parentLive` (diğer sahneler: roleSelect, babyPairing, babyLive, babyNight, parentJoin, cryAlert, connectionLost). | Uygulama doğrudan o temiz sahnede açılır; ekran görüntüsü alınabilir. | ✅/❌ |
