# Ninni v2.1 — Gerçek cihaz hataları + daha zengin arayüz

Cavid'in gerçek telefon testinden (Huawei RNE-L01 Android 8 + iPhone, iOS 27) çıkanlar ve arayüz cilası. Yeni taslaklar: `design/mockups/Home21.dc.html`, `BabyLive21.dc.html`, `ParentLive21.dc.html` (v2 taslaklarının yerine geçer; diğer ekranlar v2 taslaklarında kalır ama aşağıdaki §4 ilkeleri hepsine uygulanır).

Çalışma kuralları V2_PLAN §0 ile aynı (dev, main yok, Firebase config yok, deploy yok → "Cavid yapacak", lisans kontrolü, her adımda analyze + test + build + E2E, V21_PROGRESS.md).

## 1. HATA — iPhone bebek, Android ebeveyn: ağlama alarmı hiç gelmiyor (KRİTİK)
Gözlem: iPhone bebek modunda, ebeveyn (Android) bağlıyken çok yüksek sesle (≈100 dB hissi) bağırıldı; ebeveyne hiçbir alarm gelmedi.
Bilinen: A15'e göre görüşme sırasında dB, WebRTC `audioLevel`'dan geliyor; bu yalnızca iOS SİMÜLATÖRÜNDE doğrulandı.
Şüpheler (hepsini kontrol et, kanıtla):
- Gerçek iPhone'da `media-source`/`outbound-rtp` `audioLevel` hiç gelmiyor, 0 kalıyor ya da ses işleme (AGC/voice processing) yüzünden çok düşük → dB eşiği hiç aşmıyor. Daha güvenilir olan `totalAudioEnergy` + `totalSamplesDuration` farkından RMS hesaplamayı ekle (A/B karşılaştırmalı logla).
- `audioplayers`'ın `AudioContext` ayarı (A23) iOS ses oturumunu değiştirip WebRTC mikrofonunu etkiliyor olabilir.
- Bebek alarmı hesaplıyor ama Firestore'a yazamıyor (kural reddi) ya da Android ebeveyn tepki vermiyor. Yazma hatalarını logla.
- Bekleme ölçeri (`record`) ile WebRTC arasındaki geçiş gerçek iPhone'da takılıyor olabilir.
Yapılacak:
- Bebek tarafında saniyede bir tek satır teşhis logu: `CRYDIAG role=baby src=<webrtc|record> raw=<…> db=<…> thr=<…> over=<ms> alarm=<bool> write=<ok|err>`; ebeveynde: `CRYDIAG role=parent cryAlert=<…> cryDb=<…> age=<ms>`.
- Gizli tanı ekranı: Ayarlar'da sürüm satırına 5 kez dokununca açılır; canlı dB kaynağı, ham değer, eşik, WebRTC gelen/giden ses byte'ları, ses yönlendirmesi (hoparlör/kulaklık), son Firestore yazma sonucu. Gerçek cihaz hatalarını bulmak için.
- Hata nedenini bul ve düzelt; iOS'ta gerçek cihazda güvenilir bir ses ölçümü sağla. Gerekirse ölçeği gerçek cihaz değerlerine göre kalibre et.
- Ayarlar'a "Mikrofonu test et" (canlı dB çubuğu + eşik) ekle: kullanıcı eşiği kendi odasına göre ayarlayabilsin.

## 2. HATA — Bas-konuş hiç çalışmadı (KRİTİK)
Gözlem: Android ebeveyn → iPhone bebek; basılı tutup konuşunca bebekten ses gelmedi.
Kontrol: ebeveynde mikrofon izni isteniyor mu / reddedildi mi; `replaceTrack` sonucu; ebeveyn `outbound-rtp` ses byte'ları artıyor mu; bebek `inbound-rtp` ses byte'ları ve `audioLevel`; iOS'ta çıkış hoparlöre yönleniyor mu (iOS'ta `setSpeakerphoneOn` yerine AVAudioSession override / `Helper.setSpeakerphoneOn` iOS davranışı); `sendrecv` transceiver gerçekten müzakere edilmiş mi (SDP'de `a=sendrecv`). Ters yönü de (iPhone ebeveyn → Android bebek) test et.
Düzelt; basılıyken ebeveyn ekranında "Bebek sizi duyuyor" + canlı giden ses dalgası göster (gerçek giden seviyeden). İzin yoksa açık bir mesaj + "Ayarları aç".
Tanı ekranına (§1) bas-konuş istatistiklerini ekle.

## 3. HATA — Ham Firebase hata metni kullanıcıya gösteriliyor
Gözlem: Android'de "Firebase auth network request failed … timeout, interrupted connection or unreachable host".
- Kullanıcıya ASLA ham exception metni gösterme (yalnızca logla). Tek bir `UserFacingError` eşlemesi yaz: ağ hataları (`network-request-failed`, `unavailable`, `deadline-exceeded`, SocketException, TimeoutException) → "İnternet bağlantısı yok. Wi-Fi veya mobil veriyi kontrol edin." + "Tekrar dene"; izin hataları, oda kapalı, kod süresi doldu vb. için kendi metinleri; bilinmeyen → "Bir şeyler ters gitti. Tekrar deneyin." (TR/EN/AZ).
- `connectivity_plus` (BSD-3) ile çevrimdışı şerit: "İnternet yok — internetsiz mod için Android'de …" ; bağlantı gelince otomatik tekrar dene (Anonymous giriş dahil).
- Tüm snackbar/uyarıları gözden geçir.

## 4. ARAYÜZ — "boş" görünüm yerine dolu, canlı, premium
İlkeler (TÜM ekranlara):
1. Boş alan bırakma: her ekranda "şu an ne oluyor" bilgisi olsun (süre, son 1 saat, durumlar). Alanı doldurmak için süs değil, işe yarar bilgi.
2. Durum etiketleri ikon önce, kısa metin ("Bağlı", "%100"), ASLA "…" ile kesilmez. Gerekirse ikon tek başına + Semantics etiketi.
3. Koyu ekranlarda gece gökyüzü zemini: üstte #1A1D45 → #12142B dikey geçiş + çok sönük yıldızlar (bebek tarafında daha da sönük; gece modunda hiç yok).
4. Kartlar: #1C1F3D zemin + 1 px #262A52 kenar; ana sayılar büyük ve sayaç animasyonuyla değişir.
5. Canlı his: ses çubukları/dalga gerçek veriden; basılı konuş düğmesinde dışa yayılan halkalar; bağlanırken nabız.
6. Tutarlı boşluk ritmi (8'in katları), ekranın altı hiçbir zaman 300 px boş kalmaz.
7. Android 1080×2400 ve iPhone'da kesilme/taşma yok (Huawei RNE-L01 = 1080×2160, 18:9; özellikle kontrol et).

Ekran ekran:
- **Ana ekran (`Home21`)**: üstte gece illüstrasyonu (ay simgesi, yıldızlar, yavaş kayan bulutlar, beşik). "İyi geceler/Günaydın" saate göre. Son oda varsa büyük mor "Bebek odasını izle" kartı (tek dokunuş). Altında iki kart: "Bebek telefonu" / "Yeni oda". Altta ipucu kartı (dönen 5–6 gerçek ipucu). Rol seçimi ekranının yerine geçer; ilk açılışta karşılamadan sonra buraya gelinir.
- **Bebek: yayında (`BabyLive21`)**: başlık (oda adı + "Yayında · süre", sağda Bağlı + pil hapları), kamera kartı (alt kenarda gradyan + "Arka kamera · Dengeli", CANLI, çevir), ses kartı (solda halka gösterge: dB + eşik çentiği; sağda "Son 1 saat" çubuk grafiği: dakikalık en yüksek dB, eşik kesikli çizgi, alarm dakikaları kayısı), 3 durum kutusu (Ebeveyn/Ninni/Işık), "Gece moduna geç", metin düğmesi "Yayını bitir". Son 60 dakikanın dakikalık maksimum dB'i bellekte tutulur (bebek), ebeveyne de oda alanıyla (dakikada bir, küçük dizi) gönderilebilir.
- **Ebeveyn: canlı (`ParentLive21`)**: görüntü üstte tam genişlik, üst/alt gradyan; üstte oda adı + "x sa y dk'dır izleniyor" + CANLI; altta bağlantı kalitesi (İyi/Orta/Zayıf, gerçek RTT/kayıptan) + bebek pili + tam ekran. Ses kartı: "Bebek sakin/huzursuz/ağlıyor", dB, canlı dalga (36 çubuk), "Bu gece N alarm · son hh:mm", "Geçmiş ›". Ortada çağrı ekranı gibi 3 yuvarlak kontrol: Ninni (60) — **Basılı tut, konuş (84, halkalar)** — Işık (60, durumla renklenir). Altta 4 küçük düğme: Kaydet/Çevir/Kayıtlar/Ayarlar. "Bağlantıyı kes" ayarlar/üst menüye taşınabilir (yanlışlıkla basılmasın).
- **Alarm geçmişi**: gecelik özetin altına saatlik çubuk grafik (21:00–07:00), boş durumda küçük ay illüstrasyonu + "Sakin bir gece!".
- **Ayarlar**: her satırda solda renkli küçük ikon kutusu; en üstte oda kartı (ad, kod, bağlı cihaz); "Mikrofonu test et" (§1); sürüm satırı (§1 tanı ekranı).
- **Kod ekranları, karşılama, alarm, ninni sayfası**: §4 ilkelerine göre gözden geçir (zemin, kartlar, kesilmeyen etiketler, sayaç animasyonları).
- Ekran görüntüsü aracınla tüm ekranları (TR + AZ, koyu + açık, 1080×2160 ve iPhone) PNG olarak `design/screens_v21/` altına üret; taslaklarla karşılaştır, farkları düzelt.

## 5. Sıra
1. §3 (hızlı, risksiz) → 2. §1 ve §2 teşhis altyapısı (loglar + tanı ekranı) ve bulabildiğin olası düzeltmeler → 3. §4 arayüz → 4. Tüm testler + E2E + ekran görüntüleri → 5. V21_PROGRESS.md'ye: ne düzeldi, gerçek cihazda Cavid'in neyi nasıl test edeceği (adım adım, hangi logları toplayacağı).
§1 ve §2'nin gerçek cihaz doğrulaması Cavid ile canlı yapılacak: iki telefon USB'de, sen `flutter run` loglarını okuyacaksın, o ses çıkaracak / düğmeye basacak. O oturum için `docs/LIVE_DEBUG.md`'ye kısa bir senaryo yaz.
