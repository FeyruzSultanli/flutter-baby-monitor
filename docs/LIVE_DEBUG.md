# Canlı hata ayıklama oturumu — V2.1 §1 (ağlama alarmı) ve §2 (bas-konuş)

İki telefon USB'de, Claude `flutter run` loglarını okuyor, Cavid ses çıkarıyor / düğmeye basıyor. Süre: ~40 dk.

Telefonlar: **iPhone** (iOS 27) ve **Huawei RNE-L01** (Android 8). İkisi de aynı Wi-Fi'de (sonra bir tur mobil veriyle). Kod: `dev` (V2.1).

## 0. Hazırlık (5 dk)

1. İki telefon USB'de, kilitsiz; iPhone'da "Bu bilgisayara güven". Kontrol:

   ```bash
   flutter devices
   ```

2. İki ayrı terminalde (Claude çalıştırır, loglar dosyaya da yazılır):

   ```bash
   cd /Users/feyruz/Desktop/baby_monitor_app && flutter run -d <iphone-id> 2>&1 | tee iphone_run.log
   ```

   ```bash
   cd /Users/feyruz/Desktop/baby_monitor_app && flutter run -d <android-id> 2>&1 | tee android_run.log
   ```

3. Claude bu satırları izler (saniyede bir gelir, oturum açıkken):

   ```bash
   grep -E "CRYDIAG|TALKDIAG|NETDIAG|WebRTC error|write failed" iphone_run.log | tail -20
   ```

4. Her iki telefonda **Ayarlar → sürüm satırına 5 kez dokun → Tanı ekranı** açılabiliyor mu? (Değerler canlı; sağ üstteki "Kopyala" tüm değerleri panoya alır.)

5. iPhone'da sessiz tuşu ve ses düzeyi: ses düzeyi yarının üstünde. Huawei'de medya ve arama sesi yarının üstünde (tanı ekranında `route.voiceCallVolume` / `route.musicVolume`).

## A. Ağlama alarmı: iPhone bebek → Android ebeveyn (§1, B75) — 15 dk

**A1. Bekleme (ebeveyn yok).** iPhone: Ana ekran → "Bebek telefonu". Kod ekranı açıkken:
- iPhone logu: `CRYDIAG role=baby src=record … db=…` — sessizken 25–45, konuşunca yükselmeli.
- Cavid 3 sn yüksek sesle "aaaa" der → `over=` 2000'i geçer, `alarm=true`. (Ebeveyn bağlı değilken alarm push'a gider; burada yalnızca ölçümü görüyoruz.)

**A2. Görüşme.** Huawei: "Yeni oda" → kodu gir (ya da QR). Bağlanınca:
- iPhone logu `src=webrtc`'ye geçmeli. Sessizken `raw=` ve `rms=` değerlerine bak.
- Cavid 3–4 sn bağırır. Beklenen sıra (iPhone):
  `db=` ≥ `thr=` → `over=` artar → 2 sn sonra `alarm=true` → `write=ok(…ms)`, `ok=` sayısı artar.
- Huawei logu: `CRYDIAG role=parent cryAlert=true … fresh=true alarm=true`, ekranda tam ekran ağlama alarmı.

**Karar tablosu (A2)** — ilk uymayan satırda dur:

| Gözlem (iPhone `CRYDIAG`) | Anlamı | Ne yaparız |
|---|---|---|
| `src=record` kalıyor | Bebek görüşmeye geçmemiş | `TALKDIAG`/`WebRTC error` satırlarına bak; bağlantı kurulmuş mu |
| `src=webrtc-none` | WebRTC istatistiklerinde ses seviyesi hiç yok | Tanı ekranında "audio bytes sent" artıyor mu? Artıyorsa istatistik anahtarları farklı: `getStats` ham çıktısını loglayan geçici satır ekle |
| `raw=` 0/çok düşük ama `rms=` yüksek | Gerçek iPhone'da `audioLevel` güvenilmez | Düzeltme zaten devrede (ikisinin büyüğü, A38); `db=` eşiği geçiyorsa sorun değil |
| İkisi de düşük (bağırınca bile `db` < 60) | Ses işleme (AGC) seviyeyi bastırıyor | Ayarlar → **Mikrofonu test et** ile ölç; `db` farkını not al → ölçeğe sabit düzeltme (A38) ya da eşiği düşür |
| `alarm=true` ama `write=err:permission-denied` | Firestore kuralları alanı reddediyor | Konsolda yayınlı kuralları kontrol et (Cavid deploy) |
| `write=err:unavailable` / `ok` artmıyor | Ağ yok | NETDIAG / internet şeridi |
| `write=ok` | Bebek tarafı tamam → Huawei'ye bak | ↓ |

| Gözlem (Huawei `CRYDIAG role=parent`) | Anlamı | Ne yaparız |
|---|---|---|
| `cryAlert=false` kalıyor | Oda güncellemesi gelmiyor | Huawei'de internet; Firestore dinleyici hatası (`Room listener error`) |
| `cryAlert=true fresh=false` | Saat farkı ya da eski durum | `age=` değerini not al (ms; telefon saati − sunucu saati). B75 düzeltmesiyle ilk güncellemeden sonra `fresh=true` olmalı |
| `alarm=true` ama ekran yok | Sessize alma (5 dk) açık olabilir | Alarm ekranında "Tamam" ile kapat, tekrar dene |

**A3. Mikrofon testi.** iPhone (bebek, yayında): Ayarlar → Mikrofonu test et. Sessiz oda / normal konuşma / bağırma değerlerini not al. Eşiği odaya göre ayarla; Huawei'de eşik değeri aynı olmalı (senkron).

**A4. Ninni çalarken (A23).** Huawei'den ninni başlat → iPhone'da çalıyor mu, `CRYDIAG` `thr=` yükseliyor mu (en fazla +12), bağırınca yine alarm geliyor mu? Ninniyi durdur → WebRTC sesi sürüyor mu.

## B. Bas-konuş: Android ebeveyn → iPhone bebek (§2, B76) — 10 dk

1. Huawei canlı ekranda ortadaki mor düğmeye **basılı tut**, 3 sn konuş, bırak.
   - İlk seferde mikrofon izni sorulur. Reddedilirse "Ayarları aç" çıkmalı.
2. Huawei logu (`TALKDIAG role=parent`), beklenen:
   `permission=granted` → `start replace=ok via=track|mid answer=sendrecv` → basılıyken her saniye `flowing=true bytesOut=` artıyor, `level=` konuşunca yükseliyor.
   Ekranda: "Bebek sizi duyuyor" + mor dalga sesinizle oynuyor.
3. iPhone logu (`TALKDIAG role=baby`): `hearing=true bytesIn=` artıyor, `level=` yükseliyor; bir kez `parent audio arriving, speaker on`. Tanı ekranında `route.outputs` = **Speaker** (Receiver değil), `route.mode` = `VideoChat`.

**Karar tablosu (B):**

| Gözlem | Anlamı | Ne yaparız |
|---|---|---|
| `canTalk=false` / düğme soluk | Konuşma kanalı kurulmamış | `TALKDIAG role=parent transceivers=… via=none` satırı: transceiver listesi; `answer=` değeri |
| `answer=recvonly` | Cevap SDP'si ses göndermiyor | Konuşma kapalı kalır (loglanıyor); `_prepareTalkChannel` düzeltilir |
| `replace=error…` / `mic=error…` | Mikrofon izni/cihazı | Hata metni loga düşer |
| `flowing=false`, `bytesOut` artmıyor | Ses paketleri çıkmıyor | Android ses modu (`route.mode`), başka uygulama mikrofonu tutuyor mu |
| Ebeveynde `bytesOut` artıyor, bebekte `bytesIn` artmıyor | Ağ/SDP yön sorunu | Bebek `answer=` / `offer=` değerleri |
| `bytesIn` artıyor, `level>0`, ses duyulmuyor | iOS ses yolu | `route.outputs` Receiver ise hoparlör geçişi tutmamış; ses düzeyi; sessiz mod |

## C. Ters yön: iPhone ebeveyn → Android bebek — 5 dk

Rolleri değiştir (iPhone: Yeni oda, Huawei: Bebek telefonu). A2 (Huawei bağırır → iPhone alarm) ve B (iPhone basılı tut → Huawei hoparlöründen ses) tekrarlanır. iPhone ebeveynde bebeğin sesi hoparlörden mi geliyor (`route.outputs` Speaker)?

## D. İnternet yok (§3) — 5 dk

1. Huawei ebeveyn bağlıyken uçak modu → üstte amber "İnternet yok" şeridi, bağlantı koptu alarmı (beklenen). Ham Firebase hata metni **görünmemeli**.
2. Uçak modunu kapat → şerit kaybolur, birkaç saniyede yeniden bağlanır (`NETDIAG online=true`, ardından CONNECTED).
3. Uygulama kapalıyken internetsiz aç → Ana ekranda şerit; "Yeni oda"da kod girince "İnternet bağlantısı yok…" + "Tekrar dene".

## Toplanacaklar

- `iphone_run.log`, `android_run.log` (repo kökünde; git dışı bırakılır).
- Her senaryonun sonunda iki telefonda tanı ekranı → "Kopyala" → bir nota yapıştır (Claude'a ver).
- A3 ölçümleri: sessiz / konuşma / bağırma dB (iPhone ve Huawei ayrı).
- Gözlenen her hata: saat (log satırıyla eşlemek için), hangi telefon, ne yapıldı.
