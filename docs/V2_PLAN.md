# Ninni v2 — Ürün ve tasarım planı

Bu belge bebek monitörü uygulamasının ikinci sürümü için ana plandır. Hedef: App Store / Play Store kalitesinde, profesyonel ve "mükemmel" bir bebek monitörü. Tasarım taslakları `design/mockups/*.dc.html` dosyalarındadır (HTML; tarayıcıda açılabilir, renk/ölçü/metin için birebir referans). Bu belgedeki değerler taslaklarla çelişirse bu belge geçerlidir.

## 0. Çalışma kuralları
- `dev` branch'inde çalış. `main`'e push/merge yok. Firebase config dosyalarına dokunma.
- Fazlar sırayla. Her faz: küçük, anlamlı commit'ler → `flutter analyze` (0 error/warning) → `flutter test` → Android + iOS build → emülatör/simülatör E2E testlerini güncelle ve çalıştır → `dev`'e push → `docs/V2_PROGRESS.md`'yi güncelle.
- Her yeni paket için lisansı kontrol et: yalnızca MIT/BSD/Apache/OFL/zlib. GPL/LGPL/AGPL yok.
- `home_screen.dart` (≈3400 satır) parçalanacak: PLAN_NEXT.md'deki refactor planı (adım 2–6) bu yeniden tasarımın parçası olarak yapılır. Yeni UI eski dev dosyaya eklenmez.
- Mevcut davranış bozulmaz: eşleşme, WebRTC, Nearby offline, ağlama algılama, bildirimler, kayıt. Her fazdan sonra mevcut E2E testleri geçmeli.
- Bir karar ürün kararıysa `DECISIONS.md`'ye seçenekleri yaz, en güvenli olanla devam et.

## 1. Marka
- Uygulama adı: **Ninni** (ekranda görünen ad; alt satırda "Bebek Monitörü" / "Baby Monitor"). `applicationId` / bundle ID şimdilik DEĞİŞMEZ (Firebase'e bağlı; D9).
- Simge: koyu gece zemininde krem hilal + hilalin içinde kayısı rengi nokta. SVG geometrisi (160×160): zemin `rect rx=40 #12142B`; hilal = `circle(76,84,r46) #FBF8F3` eksi `circle(100,62,r40)` maskesi; nokta `circle(104,74,r11) #FF8A5B`. Bundan 1024 px PNG üret, `flutter_launcher_icons` ile iOS/Android simgeleri (Android adaptive: ön plan hilal+nokta, arka plan #12142B). Android bildirim simgesi: tek renk beyaz hilal+nokta.
- Splash: `flutter_native_splash` ile #12142B zemin + ortada simge.

## 2. Tasarım sistemi (lib/theme/)
`tokens.dart` + `app_theme.dart` + `components/` olarak kur; ekranlar sabit renk/ölçü kullanmaz, token kullanır.

Renkler
| Token | Değer | Kullanım |
|---|---|---|
| night900 | #12142B | koyu zemin (bebek tarafı, canlı izleme, karşılama) |
| night800 | #1C1F3D | koyu kart/yüzey |
| night700 | #2A2E55 | koyu kart içi öğe, sayı kutusu |
| nightLine | #2E3260 | koyu ince çizgi / ikincil buton kenarı |
| cream50 | #FBF8F3 | açık zemin |
| cream100 | #F1ECE3 | açık ikincil yüzey (geri butonu, bilgi kutusu) |
| creamLine | #ECE6DB | açık kart kenarı |
| white | #FFFFFF | açık kart |
| ink | #191B33 | açık zeminde metin |
| inkMuted | #5E6283 | açık zeminde ikincil metin |
| onNight | #FFFFFF | koyu zeminde metin |
| onNightMuted | #A9ADCF | koyu zeminde ikincil metin |
| primary | #5B5BF0 | ana buton (beyaz metin) |
| primarySoft | #ECECFE / koyu: #B9B9FF metin | seçili/ikincil vurgu |
| apricot | #FF8A5B | YALNIZCA ağlama alarmı ve CANLI etiketi (üstündeki metin #2A1206) |
| apricotSoft | #FFE9DF / #FFB494 | alarm ikincil |
| mint | #3DD6A3 (koyu zeminde metin #7CEBC6, açıkta #12936B) | bağlı / sorunsuz |
| amber | #FFC46B (metin #2A1D06) | bağlantı koptu / pil uyarısı |

Yazı: **Plus Jakarta Sans** (OFL; `assets/fonts` içine gömülü, internetsiz çalışsın). Ölçek: display 34/800 (-1), h1 30/800 (-0.8), h2 24/800 (-0.5), title 17/800, body 16/500, bodySm 15/500, label 13/700 (büyük harf, +0.4), caption 12/600. Rakamlar `tabular` (FontFeature.tabularFigures).

Biçim: köşe yarıçapları 12 / 14 / 18 / 20 / 24 / 28; ana buton yüksekliği 60 (r20), ikincil 52–56 (r18); kart iç boşluk 16–22; ekran yatay boşluk 20; dokunma alanı ≥44. Gölge yok; ayrım renk ve ince kenarla.

Tema: Bebek tarafı, canlı izleme, alarmlar ve karşılama HER ZAMAN koyu. Ebeveyn menü ekranları (kod girme, geçmiş, ayarlar) sistem temasına göre açık/koyu; ikisi de token'lardan.

Bileşenler (`lib/theme/components/`): NinniButton (primary/secondary/ghost/danger), StatusPill (mint/apricot/amber/neutral), CodeBoxes (8 kutu, 4+4, ortada çizgi; giriş ve gösterim modu), SectionCard, SettingsRow, SegmentedControl, NinniSwitch, LevelMeter (dB çubuğu + eşik işareti), SoundBars (canlı ses çubukları), IconTile (ikon + etiketli kare buton), BottomSheetFrame, AppIcon (CustomPainter ile simge), Starfield (animasyonlu arka plan).

## 3. Ekranlar (taslak dosya → ekran)
1. Karşılama 1–3 (`Onboard1/2/3`) — yalnızca ilk açılışta (shared_preferences). K1: yıldızlı gece + nefes alan ay, "Başlayalım". K2: iki telefon animasyonu + 3 adım, "Geç". K3: izinlerin NEDEN gerektiği; her satırda "İzin ver"/"Verildi"; işletim sisteminin izin penceresi ancak kullanıcı "İzin ver"e basınca açılır. Gizlilik notu. Ayarlardan "Tanıtımı tekrar göster".
2. Rol seçimi (`RoleSelect`) — iki büyük kart: "Bebeğin yanında" (koyu) / "Benim yanımda" (açık). Altta "İnternetsiz mod (yalnızca Android)" satırı (iOS'ta gizli). Sağ üstte ayarlar.
3. Bebek: oda kodu (`BabyPairing`) — 8 kutuluk kod, QR kod, geri sayım (10 dk), Paylaş/Kopyala, "Ebeveyn telefonu bekleniyor" (nabız animasyonu).
4. Bebek: yayında (`BabyLive`) — durum hapları (ebeveyn bağlı, pil, oda kodu), kamera önizleme + CANLI etiketi + kamera çevir, ses seviyesi kartı (dB, eşik işareti), "Gece moduna geç", "Yayını bitir" (onaylı).
5. Bebek: gece modu (`BabyNight`) — siyah, sönük saat, "Yayın sürüyor · ebeveyn bağlı", çift dokunuşla çıkış. Gece lambası açıksa ekran seçilen renkte yumuşak ışık verir (bkz. 5.5).
6. Ebeveyn: kod gir (`ParentJoin`) — 8 kutu (yapıştırmayı destekle, otomatik büyük harf, karışabilen karakterleri reddet), "QR kodu okut", "Son bağlandığınız" kartı, "Bağlan".
7. Ebeveyn: canlı izleme (`ParentLive`) — üstte tam genişlik görüntü (oda adı, CANLI, bağlantı kalitesi, bebek pili, tam ekran), altta ses durumu kartı (canlı çubuklar, "Bebek sakin", son alarm, "Geçmiş"), "Basılı tutun, bebeğe konuşun", 4'lü ızgara: Ninni / Kaydet / Çevir / Ayarlar, "Bağlantıyı kes".
8. Ağlama alarmı (`CryAlert`) — tam ekran kayısı, dışa yayılan halkalar, "Bebek ağlıyor", saat · dB · süre, "Görüntüyü aç", "5 dk sessize al", "Tamam". Titreşim + ses.
9. Alarm geçmişi (`AlertHistory`) — gecelik özet kartı (alarm sayısı, toplam ağlama, en uzun sessiz dönem), filtre çipleri (Bu gece/Dün/7 gün), olay listesi.
10. Ayarlar (`Settings`) — Alarm (hassasiyet dB kaydırıcısı, alarm süresi, bildirim aralığı), Görüntü (Tasarruf/Dengeli/Net, bağlanınca gece modu), Uygulama (dil, tema, tanıtım), Hakkında.
11. Ninni ve gece lambası (`Lullaby`) — alt sayfa: 4 ses, ses düzeyi, zamanlayıcı (15/30/60/sürekli), gece lambası aç/kapa + 4 renk.
12. Bağlantı koptu (`ConnectionLost`) — amber uyarı, "Yeniden bağlanmaya çalışıyoruz", bebek telefonunda kontrol listesi (son bilinen pil vb.), "Tekrar dene", "Alarmı sustur".
Ayrıca: boş durumlar, hata durumları (izin reddedildi → "Ayarları aç"), yükleme iskeletleri — hepsi aynı dille.

## 4. Animasyon ve his
- Ekran geçişleri: `animations` paketiyle SharedAxis (yatay) / FadeThrough; alt sayfalar yaylı.
- Starfield: CustomPainter, 20–30 yıldız, rastgele faz ile 3 sn'lik opaklık döngüsü; ay %4 "nefes" (4 sn). `MediaQuery.disableAnimations` açıksa hepsi durur.
- Bekleme: noktadan yayılan halka (1.6 sn).
- Ses çubukları: gerçek dB'den, 60 fps'e kilitlenmeden, ~10 Hz güncelleme + implicit animasyon.
- Alarm: 3 halka dışa yayılır; `HapticFeedback` + titreşim deseni.
- Butonlar: basınca %97 ölçek + hafif haptik. Kod kutuları: dolunca küçük zıplama; hatalıysa yatay sarsıntı.
- Pil/performans: bebek cihazında animasyonlar minimum (gece modunda hiç yok).

## 5. Yeni özellikler
5.1 **QR ile eşleştirme** — bebek ekranında `qr_flutter`, ebeveynde `mobile_scanner`. İçerik: `ninni://join?code=ABCD-EF23`. Kamera izni yoksa elle giriş.
5.2 **Son oda / hızlı tekrar bağlanma** — ebeveyn son odayı (kod + takma ad + zaman) saklar; oda hâlâ geçerliyse tek dokunuşla yeniden katılır (mevcut oturum protokolü). Bebek tarafında odaya ad verilebilir ("Bebek odası").
5.3 **Bebeğe konuşma (bas-konuş)** — ebeveyn mikrofonu WebRTC ile bebeğe gider; bebek hoparlörden çalar. Ses kanalı baştan sendrecv müzakere edilir, parça yalnızca basılıyken etkin (yeniden müzakere yok). Konuşma sürerken ve 3 sn sonrasına kadar bebek tarafında ağlama algılama devre dışı (kendi sesimizle alarm olmasın). İlk kullanımda ebeveynden mikrofon izni.
5.4 **Ninni / beyaz gürültü** — bebek cihazında çalar, ebeveyn uzaktan yönetir (oda alanı `soothe: {track, volume, endsAt}`; offline'da Nearby mesaj türü). Sesler: beyaz gürültü, yağmur, kalp atışı (kod içinde sentezlenebilir), "Dandini dandini" (geleneksel, kamu malı melodi; kutu müziği tınısıyla sentezle ya da CC0 kayıt kullan, lisansı `assets/audio/LICENSES.md`'ye yaz). Çalarken ağlama eşiği otomatik olarak çalan sesin seviyesine göre düzeltilir ya da ses düzeyi çıkarılır; alarm kaçırılmamalı — yaklaşımı DECISIONS.md'ye yaz ve test et.
5.5 **Gece lambası** — bebek ekranı seçilen renkte (kehribar/pembe/mor/mavi) düşük parlaklıkta yanar; ebeveynden aç/kapa/renk (oda alanı `nightLight`).
5.6 **Bağlantı koptu alarmı** — ebeveyn tarafı: WebRTC "disconnected/failed" ya da 20 sn boyunca kare/ses gelmezse yerel alarm (ConnectionLost ekranı + bildirim + ses). Yeniden bağlanınca kendiliğinden kapanır.
5.7 **Bebek pili düşük** — %15 altı ve şarjda değilse ebeveyne tek seferlik uyarı (ön planda kart, arka planda bildirim; Function'a yeni tür eklenebilir).
5.8 **5 dk sessize al** — alarm ekranından; süre bitince normal.
5.9 **Gecelik özet** — alarm geçmişinden hesaplanır (yerel): alarm sayısı, toplam ağlama süresi, en uzun sessiz dönem.
5.10 **Arka planda dinleme (ebeveyn)** — ebeveyn telefonu kilitliyken bebek sesi duyulmaya devam eder (iOS `audio` arka plan modu; Android foreground service). Ayarlardan açılıp kapatılabilir.
5.11 **Azerbaycan dili** — TR, EN'e ek olarak AZ. Tüm metinler l10n'den.
5.12 Foreground service (PLAN_NEXT 7. adım) — bebek Android'de ekran kapalıyken yayın sürsün; iOS'ta mümkün değil, bebek modunda gece modu önerilir/zorunlu.

## 6. Fazlar
**Faz 1 — Güvenilirlik** (UI'dan önce; bebek monitöründe önce güven): 5.12, 5.6, 5.7, 5.10, Impeller opt-out'un kaldırılması (Android'de görüntü sorunu yoksa).
**Faz 2 — Tasarım sistemi ve tüm ekranlar**: §2, §3, §4; marka/simge/splash; home_screen'in parçalanması; karşılama akışı.
**Faz 3 — Yeni özellikler**: 5.1, 5.2, 5.3, 5.4, 5.5, 5.8, 5.9, 5.11.
**Faz 4 — Cila**: erişilebilirlik (Semantics, büyük yazı boyutunda taşma yok, 4.5:1 kontrast), küçük ekran (iPhone SE) ve tablet düzenleri, performans (bebek cihazında CPU/ısı), tüm E2E testleri, mağaza ekran görüntüleri için temiz demo durumları.

## 7. Bitti sayılma ölçütü (her faz)
- analyze 0 error/0 warning, testler yeşil, Android ve iOS derleniyor.
- E2E: Android↔Android ve Android↔iOS akışları geçiyor.
- TEST_PLAN.md'de o fazın gerçek cihaz maddeleri eklendi.
- `docs/V2_PROGRESS.md`: yapılanlar, açık konular, kullanıcıdan beklenenler.
