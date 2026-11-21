# PLAN_NEXT.md — Sonraki tur için uygulama planı

> Kapsam: D1 (iki aşama), D2, D3 ve "ebeveyn aynı odaya yeniden katılamıyor" hatası (B08).
> Bu dosya yalnızca plan; bu turda kod yazılmadı.
> Taban commit: `dev` @ `5a28776`. Kararlarınız: D1 iki aşamalı, D2 Cloud Function + FCM (Blaze kararı sizde), D3 Anonymous Auth + kurallar + uzun/süreli kod, B08 düzeltilecek.

## İlerleme (kullanıcının onayladığı sıra)

| # | İş | Durum |
|---|---|---|
| 1 | D11 + D6 + D7 | ✅ `a982754` (D11), `fe862a2` (D6), `0de98f1` (D7) |
| 2 | D1-a gece modu | ✅ `cb3b3e8` (paket: `screen_brightness ^2.1.11`) |
| 3 | D5 alarm eşiği (≥2 sn + tek dB formülü + ayarlanabilir eşik) | ✅ `9a0c363` (tek ölçek), `bfc5f26` (2 sn), `04ce566` (eşik senkronu) |
| 4 | B08 yeniden katılma | ⏳ |
| 5 | D3 + D8 (auth, kurallar, süreli kod, TTL) | ⏳ |
| 6 | D2 FCM (uygulama tarafı + Function kodu; deploy Blaze kararından sonra) | ⏳ |
| 7 | D1-b foreground service | ⏸ Başlamadan önce kullanıcıya sorulacak (yarım günlük cihaz denemesi) |

Kararlar (kullanıcı):
- D4 bekliyor: önce farklı ağ testi, sonra Blaze kararıyla birlikte değerlendirilecek.
- D5, D6, D7, D8, D11 kabul edildi.
- D9 ve D10 sonraya kaldı.
- `firebase.json`'a yalnızca `firestore` ve `functions` bölümlerinin eklenmesi onaylandı.
- Emülatör için Android Studio JDK'sı (`JAVA_HOME` yalnızca oturumda) onaylandı.

## Önerilen uygulama sırası (özet)

| Sıra | İş | Büyüklük | Neden bu sırada |
|---|---|---|---|
| 1 | **D1-a Gece modu** | S (~0,5 gün) | Bağımsız ve en hızlı kazanım. Foreground service gelene kadar "ekran kapanınca yayın durur" sorununu pratikte giderir. |
| 2 | **B08 Yeniden katılma (oturum tabanlı yeniden anlaşma)** | M (~1–1,5 gün) | Sinyal protokolünü değiştiriyor. Konsolda bir şey gerektirmiyor, mevcut kurallarla test edilebilir. D3'teki şema ve kurallar bu protokolün **son haline** göre yazılmalı, o yüzden D3'ten önce. |
| 3 | **D3 Auth + kurallar + yeni oda kodu** | M–L (~2 gün) | 2'deki alanlar (session vb.) dahil tek seferde nihai şema. D2'deki token alanını da kurallara dahil eder. |
| 4 | **D2 Cloud Function + FCM** | M (~1–1,5 gün) | Token'ın odada saklanması D3 kurallarına bağlı. İstemci kısmı Blaze olmadan da zararsız; Function'ı Blaze kararınızdan sonra deploy edersiniz. |
| 5 | **D1-b Foreground service** | L (~2–3 gün + cihaz denemesi) | En riskli iş: kamera/mikrofonun arka planda çalışmaya devam ettiği cihazda kanıtlanmalı. Önce yarım günlük bir **deneme (spike)**, sonra asıl uygulama. 1 numara sayesinde bu sürede kullanıcı korunuyor. |

Her iş ayrı bir branch/commit grubu olarak `dev` üzerinde yapılır. Her birinden sonra analyze, test ve build, ardından TEST_PLAN'a ilgili maddeler eklenir.

> **Not (Firebase dosyaları):** D2 ve D3 için Firebase CLI'ın `firebase.json` içinde `firestore` ve `functions` bölümlerine ve bir `.firebaserc` dosyasına ihtiyacı var. Şu anki `firebase.json` yalnızca FlutterFire ayarlarını içeriyor. Bu dosyaya **sadece yeni anahtar eklenecek**; mevcut `flutter` bölümüne dokunulmayacak, uygulama derlemesi etkilenmez. `google-services.json`, `GoogleService-Info.plist` ve `firebase_options.dart` değişmez. Uygulamaya başlamadan önce `firebase.json`'a anahtar eklemek için onayınızı isteyeceğim.

---

## 1. D1-a — Gece modu (ekran açık, siyah, en düşük parlaklık, wakelock)

**Hedef:** Bebek cihazı yayın yaparken ekran hiç kapanmaz ama kararır. Pil tüketimi ve ışık en aza iner, sistem uygulamayı arka plana itmez.

**Mevcut durum:**
- `home_screen.dart`'ta `_nightMode` var (`_toggleNightMode`, siyah arka plan ve %80 karartma katmanı).
- Parlaklık değişmiyor.
- Wakelock yalnızca yayın başlayınca açılıyor.
- Ekrana dokunulunca ne olacağı tanımlı değil.

**Değişecek dosyalar:**
- `lib/screens/home_screen.dart`:
  - `_toggleNightMode` gece moduna girince: wakelock açık, parlaklık en düşük (uygulamaya özel), tam ekran siyah katman.
  - Çıkışta parlaklık eski haline döner.
  - Yayın kapanınca (`_resetPairing`) ya da rol değişince otomatik çıkılır.
- Yeni `lib/widgets/night_mode_overlay.dart`:
  - Tam siyah katman ve küçük bir "çıkmak için iki kez dokun" ipucu (birkaç saniye sonra kaybolur).
  - Durum göstergesi: kırmızı/yeşil nokta, çok düşük opaklık.
  - Overlay `PopScope` ile sarılır; yanlışlıkla geri tuşuna basmak gece modundan çıkarır, uygulamadan değil.
- `lib/l10n/app_localizations.dart`: `nightModeExitHint` ve `nightModeActive` anahtarları (TR/EN).
- Yayın başlayınca otomatik gece modu (isteğe bağlı): "Yayın başlayınca gece moduna geç" ayarı `settings_sheet.dart`'a eklenir. Ayar bu turda kalıcı olmaz (B35 ile birlikte kalıcı yapılabilir).

**Paketler:** `screen_brightness` (güncel 2.1.x). Sistem ayarını değiştirmeden **yalnızca uygulama penceresinin** parlaklığını değiştirir, ek izin gerekmez. `wakelock_plus` zaten var.

**İzinler:** Yok. (`WRITE_SETTINGS` gerekmiyor; sistem parlaklığına dokunulmayacak.)

**Firebase konsolu:** Yok.

**Riskler:**
- Bazı OEM'ler (Xiaomi, Huawei) ekran açıkken bile pil tasarrufu modunda arka plan ağını kısabiliyor. Bu durumda pil optimizasyonu muafiyeti (zaten isteniyor) önemli.
- OLED ekranlarda siyah piksel pratikte enerji harcamaz; LCD'de arka ışık en düşük parlaklıkta da yanar (az ama sıfır değil).
- Ekran saatlerce açık kalınca ısınma olabilir. 30+ dk testinde (TEST_PLAN Bölüm 10) ölçülecek.
- Bu aşama **arka plana geçişi engellemez**: Home tuşu, gelen arama ya da güç tuşu yayını yine durdurur. Kullanıcıya bir uyarı metni gösterilir.

**Büyüklük:** S, yaklaşık 150–200 satır.

**Test:**
- Gece modunda 30 dk boyunca ekranın açık kalması, parlaklığın düşmesi ve yayının sürmesi.
- Çift dokunuşla çıkış.
- Yayın kapanınca otomatik çıkış.

---

## 2. B08 — Ebeveynin aynı odaya yeniden katılması

**Kök neden:**
- Bebek tek bir peer connection kuruyor ve yalnızca **ilk** answer'ı kabul ediyor.
- Ebeveyn ayrılıp geri gelince odadaki **eski** offer'a cevap veriyor. Bebek bu answer'ı yok sayıyor ve yeni bir offer üretmiyor.
- Eski ICE adayları da koleksiyonlarda duruyor ve yeniden oynatılıyor.

**Tasarım: her katılım yeni bir "oturum"**
1. Ebeveyn katılırken odaya `viewerSession: <rastgele id>` ve `viewerJoinedAt` yazar.
2. Bebek oda dokümanını zaten dinliyor. `viewerSession` değişince:
   - Mevcut peer connection'ı kapatır. **Kamera ve mikrofon akışı (local stream) kapanmaz**; görüntü kesilmez.
   - Eski aday dokümanlarını siler.
   - Yeni bir peer connection kurar ve `offer: {sdp, type, session}` yazar.
3. Ebeveyn yalnızca `offer.session == kendi session'ı` olan offer'a cevap verir. Answer da `session` alanı taşır.
4. Adaylar `session` alanıyla yazılır, okuyan taraf diğer oturumların adaylarını atar.
5. Bağlantı kopması (B36 ile birlikte):
   - `disconnected` durumu "yeniden bağlanıyor" olarak gösterilir. 10–15 sn içinde düzelmezse ya da `failed` gelirse ebeveyn otomatik olarak yeni bir oturumla tekrar katılır (üstel bekleme: 2 sn, 4 sn, 8 sn…, en fazla 30 sn).
   - Bebek tarafı pasif kalır; her yeni oturuma cevap verir.
6. Ebeveyn "Bağlantıyı kes" deyince `viewerSession` null olur. Bebek peer'ı kapatır ve bekler; oda silinmez.

**Değişecek dosyalar:**
- `lib/core/webrtc/webrtc_service.dart`:
  - `_ensurePeerClosed` ikiye ayrılır: biri sadece peer'ı, diğeri local stream'i kapatır.
  - Bebek için `renegotiateForSession(session)` eklenir.
  - Ebeveyn için `startAsParent(room, session)` olur ve `disconnected` için zamanlayıcı eklenir.
- `lib/core/webrtc/firestore_signaling.dart`:
  - Offer, answer ve adaylara `session` alanı eklenir, dinlerken bu alana göre filtrelenir.
  - Eski adayları silen bir `clearCandidates()` eklenir.
  - `connect(room, {session})` imzası değişir.
- `lib/core/webrtc/signaling_interface.dart`: imzalar buna göre güncellenir.
- `lib/core/pairing/pairing_service.dart`:
  - `joinRoom` session yazar.
  - `leaveRoom` session'ı null yapar; `setPaired(false)` yerine kullanılır.
  - `PairingState`'e `viewerSession` alanı eklenir.
- `lib/screens/home_screen.dart`:
  - Bebek tarafında `_listenRoomUpdates` içinde session değişimine tepki.
  - Ebeveyn tarafında otomatik yeniden katılma ve "yeniden bağlanıyor" durumu.
- `lib/core/webrtc/multi_peer_service.dart`: session'a uyum sağlar, ya da D6 kararına göre multi-camera gizlenir.
- `test/`: session filtreleme ve yeniden bağlanma zamanlayıcısı için saf mantık testleri. Signaling, sahte bir `SignalingInterface` ile test edilebilir.

**Paketler ve izinler:** Yok.

**Firebase konsolu:** Yok. Kurallar D3 ile birlikte yazılacak.

**Riskler:**
- Protokol değiştiği için **eski sürüm ve yeni sürüm birbiriyle konuşamaz**. İki telefona aynı sürüm kurulmalı.
- Yeniden anlaşma sırasında 1–3 sn görüntü kesintisi olabilir (ICE yeniden toplanıyor).
- Bebek tarafında eski peer kapanırken track'ler yanlışlıkla dispose edilirse kamera kapanır. Bu yüzden ayırma dikkatle yapılmalı ve cihazda test edilmeli.
- Aynı anda iki ebeveyn katılmaya çalışırsa son yazan kazanır. D3'teki `viewerUid` kuralı bunu tek bir ebeveynle sınırlayacak.

**Büyüklük:** M, yaklaşık 300–450 satır değişiklik.

**Test (TEST_PLAN'a eklenecek):**
- Ebeveyn çıkıp aynı kodla tekrar katılıyor.
- Ebeveyn uygulamasını öldürüp yeniden açıyor.
- Wi-Fi 10 sn kapatılıp açılıyor (her iki tarafta).
- Bebek yayını sürerken ebeveyn 5 kez çıkıp giriyor; her seferinde görüntü geliyor ve bebek kamerası kapanmıyor.

---

## 3. D3 — Anonymous Auth, eşleşmiş iki cihaza özel kurallar, uzun ve süreli oda kodu

**Hedef:**
- Odayı yalnızca onu oluşturan bebek cihazı ile onu ilk talep eden ebeveyn cihazı okuyup yazabilsin.
- Kod tahmin edilemesin ve talep edilmeden belli bir süre geçerse geçersiz olsun.

**Yeni oda şeması** (`rooms/{code}`; B08 alanları dahil):

| Alan | Yazan | Not |
|---|---|---|
| `ownerUid` | bebek (create) | Değiştirilemez. |
| `viewerUid` | ebeveyn (talep) | Önce `null`. Yalnızca null iken ya da zaten kendisiyse yazılabilir. |
| `createdAt`, `claimDeadline` | bebek | `claimDeadline` = oluşturma + **10 dk**. Talep bu süre içinde yapılmalı. |
| `expiresAt` | bebek | TTL alanı: oluşturma + 24 saat. Bebek yayın sürdükçe saatte bir uzatır. |
| `viewerSession`, `offer`, `answer` | B08 | `offer` bebekten, `answer` ve `viewerSession` ebeveynden gelir. |
| `isPaired`, `facingMode`, `videoSettings` | her iki taraf | Mevcut alanlar. |
| `cryAlert`, `cryDb`, `cryUpdated` | bebek | Mevcut alanlar. |
| `viewerFcmToken`, `viewerLocale` | ebeveyn | D2 için. |

Alt koleksiyonlar `callerCandidates`, `calleeCandidates` ve `alerts`: yalnızca `ownerUid` ya da `viewerUid` okuyup yazabilir.

**Oda kodu:**
- 8 karakter, karışmayan 32 harfli bir alfabeden: `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (0/O ve 1/I yok).
- Olasılık sayısı 32⁸ ≈ 1,1×10¹²; şu anki 6 haneli koddan yaklaşık 1,2 milyon kat fazla.
- `ABCD-EFGH` biçiminde gösterilir. Giriş alanı büyük harfe çevirir ve tireyi yok sayar.
- QR ile eşleşme isteğe bağlı bir sonraki adım (paket: `qr_flutter` + `mobile_scanner`). Bu planın kapsamında değil.

**Eşleşme akışı:**
1. Uygulama açılınca, yalnızca online modda, `FirebaseAuth.instance.signInAnonymously()` çağrılır. Uid cihazda saklanır; uygulama verisi silinmedikçe aynı kalır.
2. Bebek kodu üretir ve `rooms/{code}` dokümanını **create** ile yazar.
   - Kurallar yalnızca doküman yoksa izin verir. Kod çakışırsa `permission-denied` gelir; yeni kodla tekrar denenir.
   - Böylece başkasının odasını okumaya gerek kalmaz.
3. Ebeveyn kodu girer ve **okumadan** sadece `update({viewerUid: uid, viewerSession, ...})` yapar.
   - Kurallar şunları kontrol eder: `viewerUid == null` (ya da zaten kendisi), `request.time < claimDeadline` ve yalnızca izin verilen alanların değiştiği.
   - Doküman yoksa ya da talep edilmişse hata döner ve kullanıcıya "kod geçersiz veya süresi dolmuş" gösterilir.
4. Bundan sonra iki taraf da odayı okuyabilir. `list` (oda listeleme) **hiç kimseye açık değil**.

**Kural taslağı** (son hali uygulama sırasında `firestore.rules` dosyasında olacak):

```
match /rooms/{code} {
  function isOwner()  { return request.auth != null && resource.data.ownerUid == request.auth.uid; }
  function isViewer() { return request.auth != null && resource.data.viewerUid == request.auth.uid; }
  allow list: if false;
  allow get: if isOwner() || isViewer();
  allow create: if request.auth != null
    && request.resource.data.ownerUid == request.auth.uid
    && request.resource.data.viewerUid == null
    && code.size() == 8;
  allow update: if isOwner() && !changed(['ownerUid','viewerUid'])
    || isViewer() && onlyChanged([...ebeveyn alanları...])
    || claim();   // viewerUid null → kendi uid'i, claimDeadline geçmemiş
  allow delete: if isOwner();
  match /{sub}/{doc} {   // callerCandidates, calleeCandidates, alerts
    allow read, write: if memberOf(get(/databases/$(database)/documents/rooms/$(code)));
  }
}
```

**Değişecek / eklenecek dosyalar:**
- `pubspec.yaml`: `firebase_auth: ^5.7.0`. Bu, mevcut `firebase_core 3.15.x` ile uyumlu son sürüm; firebase_auth 6/7 sürümleri firebase_core 4/5 istiyor ve şu an gerekmiyor.
- Yeni `lib/core/auth/auth_service.dart`: anonim giriş, `currentUid`, hata durumunda yeniden deneme.
- `lib/main.dart`: Firebase başlatıldıktan sonra anonim giriş.
  - Online modu engellememeli: giriş tamamlanmadan oda işlemleri bekler.
  - Offline mod auth gerektirmez.
- `lib/core/pairing/pairing_service.dart`:
  - Kod üretimi (yeni alfabe), create-only yazım ve çakışmada yeniden deneme.
  - `joinRoom` okumadan "talep" eder.
  - `claimDeadline` / `expiresAt` alanları ve saatte bir `expiresAt` uzatma.
  - Hata kodları (`permission-denied` → `invalidOrExpiredCode`) l10n'a taşınır; bu, B40'ın kalan kısmını da çözer.
- `lib/screens/home_screen.dart` ve eşleşme sayfaları:
  - Kod gösterimi `ABCD-EFGH` biçiminde.
  - Giriş alanı: `TextInputType.text`, büyük harf, 9 karakter.
  - Kalan talep süresi geri sayımı ("bu kod 9:41 dk geçerli").
- Yeni `firestore.rules` ve `firestore.indexes.json` (boş).
- `firebase.json`: yalnızca `"firestore": {"rules": "firestore.rules", ...}` anahtarı eklenir (yukarıdaki nota bakın).
- Yeni `.firebaserc`: `{"projects":{"default":"bebekmonitor-282fd"}}`.
- Yeni `firestore-tests/` (Node): `@firebase/rules-unit-testing` ile kural testleri çalışır:
  - Sahip okuyabilir, yabancı okuyamaz.
  - Süresi dolmuş kod talep edilemez.
  - İkinci ebeveyn talep edemez.
  - Liste sorgusu reddedilir.
  - Adaylara yabancı yazamaz.

  Firestore emülatörü Java 11+ istiyor. Sistemde `java` yok; Android Studio'nun JDK'sı `JAVA_HOME` ile kullanılabilir. Kurulum gerekmez, ama sistem geneline bir şey kurmadan önce size soracağım.
- `lib/core/webrtc/multi_peer_service.dart` / `multi_camera_screen.dart`: tek izleyici kuralıyla çakışıyor. D6 kararınıza göre gizlenir ya da izleyici başına uid listesine geçilir.

**İzinler (Android):** Yeni izin yok.

**Firebase konsolunda yapmanız gerekenler** (sıra önemli):
1. **Authentication → Sign-in method → Anonymous → Enable.** Yeni uygulama sürümü kurulmadan **önce** yapılmalı.
2. Yeni sürümü iki telefona kurun ve test edin. Bu aşamada mevcut (açık) kurallar hâlâ geçerli.
3. **Firestore → Rules:** yeni kuralları yayınlayın.
   - Ya `npx firebase-tools deploy --only firestore:rules` (global kurulum gerekmez; bir kez `npx firebase-tools login` gerekir),
   - ya da `firestore.rules` içeriğini konsola yapıştırın.
   - Bundan sonra **eski sürüm uygulamalar çalışmaz.**
4. **Firestore → TTL:** `rooms` koleksiyonu için `expiresAt` alanına TTL politikası. Alt koleksiyon dokümanlarına da `expiresAt` yazılacak, onlar için de collection-group TTL politikası tanımlanır. TTL üst dokümanı silince alt koleksiyonları **silmez**.
5. İsteğe bağlı, önerilir: **App Check (Play Integrity)**. Önce izleme modunda açılır, sorun görülmezse zorunlu hale getirilir. Bu, emülatör ve bot denemelerini zorlaştırır. Paket: `firebase_app_check: ^0.3.2+10` (core 3.x uyumlu). Bu planın zorunlu parçası değil.

**Riskler:**
- **Geçiş:** kurallar yayınlanınca eski sürüm uygulamalar kırılır. Bu yüzden önce uygulama, sonra kurallar.
- Anonim uid, uygulama verisi silinince ya da uygulama yeniden kurulunca değişir. Ebeveyn bu durumda aynı odaya giremez; bebek yeni kod üretmelidir. Kabul edilebilir, ama mesajla açıklanmalı.
- `get()` kullanan alt koleksiyon kuralları her aday yazımında ekstra bir okuma maliyeti getirir (oturum başına birkaç düzine; önemsiz).
- `request.time < claimDeadline` sunucu saatini kullanır, cihaz saatinden bağımsızdır.
- İnternet yokken anonim giriş başarısız olur. Online mod zaten internet istiyor; offline mod etkilenmez.

**Büyüklük:** M–L, yaklaşık 400–600 satır Dart ve kural, artı ~200 satır kural testi.

---

## 4. D2 — Cloud Function ile FCM bildirimi

**Hedef:** `rooms/{code}/alerts/{id}` altına yeni bir doküman düşünce, ebeveyn uygulaması kapalı ya da ekranı kilitli olsa bile ebeveyne yüksek öncelikli bir bildirim gider.

**Akış:**
1. Ebeveyn odayı talep ederken (D3) `viewerFcmToken` ve `viewerLocale` (`tr`/`en`) alanlarını yazar. `onTokenRefresh` olayında bu alanları günceller.
2. Bebek mevcut haliyle `alerts`'e doküman yazar. İstemci tarafında 60 sn'lik bekleme süresi zaten var (B05).
3. Function, `onDocumentCreated('rooms/{code}/alerts/{id}')` ile tetiklenir (firebase-functions v2). Odayı okur; token yoksa çıkar.
   - **Sunucu tarafında da** 60 sn bekleme süresi uygular: odaya `lastPushAt` yazar.
   - Ebeveynin diline göre başlık ve gövde seçer.
   - `admin.messaging().send(...)` gönderir:
     - `android.priority = 'high'`
     - `android.notification.channelId = 'baby_monitor_alerts'`
     - `tag = 'cry_alert'`
     - `apns-priority: 10`
     - `data: {roomCode, alertId, db}`
   - Token geçersizse (`registration-token-not-registered`) odadaki token'ı siler.
4. Uygulamada **mükerrer bildirimi önlemek** için:
   - Firestore dinleyicisinin gösterdiği yerel bildirim ile FCM bildirimi aynı `tag` ve `id` değerlerini (`cry_alert` / 0) kullanır. Böylece Android ikincisini birincinin **yerine** koyar.
   - Uygulama ön plandayken `onMessage` ile gelen FCM gösterilmez (dinleyici zaten gösteriyor).
   - Bu davranış cihazda doğrulanmalı; gerekirse ön plan ve arka plan ayrımı uygulama durumuna göre yapılır.
5. Blaze'e geçilmezse Function deploy edilmez. İstemci tarafında token yazmak ve kanal oluşturmak zararsızdır, bugünkü davranış aynen sürer.

**Değişecek / eklenecek dosyalar:**
- Yeni `functions/` (TypeScript):
  - `package.json`: `firebase-functions` ^6, `firebase-admin` ^13, `engines.node: "22"`.
  - `tsconfig.json`, `src/index.ts` (`onCryAlertCreated`), `src/messages.ts` (TR/EN metinler).
  - `firebase-functions-test` ile birim testleri.
- `firebase.json`: `"functions": [{"source": "functions", "codebase": "default"}]` anahtarı eklenir (yukarıdaki nota bakın).
- `lib/core/services/notification_service.dart`:
  - Uygulama açılışında kanal açıkça oluşturulur (`AndroidNotificationChannel`, importance max). FCM, uygulama kapalıyken bu kanalı kullanır.
  - Token alma ve yenileme, `tag: 'cry_alert'`.
  - Bildirime dokununca ilgili ekranın açılması: `onDidReceiveNotificationResponse` ve `getInitialMessage` ile ana ekran ebeveyn modunda açılır. Şu an dokunmak sadece `debugPrint` çağırıyor (yarım özellik).
  - `FirebaseMessaging.instance` tembel (lazy) hale getirilir (B43).
- `lib/core/pairing/pairing_service.dart`: `setViewerPushToken(code, token, locale)`.
- `lib/screens/home_screen.dart`:
  - Ebeveyn katılınca token yazılır.
  - Bildirim izni (POST_NOTIFICATIONS) açılışta değil **ebeveyn rolü seçilince**, açıklamayla birlikte istenir. Reddedilirse uyarı gösterilir (B42).
- `android/app/src/main/AndroidManifest.xml`:
  - `com.google.firebase.messaging.default_notification_channel_id` meta-data.
  - Tek renkli bildirim ikonu `default_notification_icon` (B47).
- iOS (D10 kapsamı; ayrıca karar):
  - APNs anahtarı, `aps-environment` entitlement'ı.
  - `UIBackgroundModes: remote-notification`.

**Paketler:** İstemcide yeni paket yok (`firebase_messaging` ve `flutter_local_notifications` zaten var). Function tarafında `firebase-functions` ve `firebase-admin` (npm).

**Araçlar:**
- Node 24 sistemde var; Functions çalışma zamanı olarak Node 22 seçilecek.
- Firebase CLI kurulu değil. `npx firebase-tools ...` ile kurulum yapmadan kullanılabilir. Global kurulum (`npm i -g firebase-tools`) isterseniz size sorulur.

**İzinler (Android):** `POST_NOTIFICATIONS` zaten merge ediliyor (firebase_messaging). Yeni izin yok.

**Firebase konsolunda yapmanız gerekenler:**
1. **Blaze planı** (sizin kararınız). Functions için zorunlu.
   - Maliyet: ayda 2 milyon çağrı ücretsiz. Alarmlar zaten 60 sn'de bir ile sınırlı; pratikte ücretsiz katmanda kalır.
   - Bütçe uyarısı kurulması önerilir: **Google Cloud Console → Billing → Budgets**, ör. 1 $.
2. `npx firebase-tools login`, ardından `npx firebase-tools deploy --only functions`. Cloud Functions, Cloud Build ve Artifact Registry API'leri ilk deploy'da otomatik açılır; onay istenebilir.
3. **Cloud Messaging:** Android için ek ayar gerekmez (FCM v1 API, varsayılan servis hesabı). iOS için **APNs Authentication Key** yüklenir (iOS hedefleniyorsa).

**Riskler:**
- Android Doze ve OEM pil yöneticileri, yüksek öncelikli FCM'i bile geciktirebilir. Yüksek öncelikli mesajlar genelde hemen iletilir, ama bazı Xiaomi ve Huawei cihazlarda "otomatik başlatma" izni gerekebilir. Cihazda test edilmeli.
- Kullanıcı uygulamayı **zorla durdurursa** (Ayarlar → Durmaya zorla), Android FCM'i de engeller. Bu durum çözülemez.
- Mükerrer ya da eksik bildirim: yukarıdaki tag yöntemi cihazda doğrulanmalı.
- Function soğuk başlatması 1–3 sn gecikme ekleyebilir. `minInstances` ücretli olduğu için önerilmiyor.
- Function deploy edilmeden önce kurallar D3'e geçirilmiş olmalı. Function admin yetkisiyle çalıştığı için kurallardan etkilenmez, ama token alanının istemci tarafından yazılabilmesi D3 kurallarına bağlı.

**Büyüklük:** M. Yaklaşık 150–250 satır TypeScript, 150 satır Dart, artı Function testleri.

---

## 5. D1-b — Kamera ve mikrofon türünde gerçek foreground service

**Hedef:** Bebek cihazında Home tuşu, ekranın kilitlenmesi ya da başka bir uygulamaya geçilmesi durumunda bile yayın (online WebRTC ve offline Nearby) ve ağlama algılama sürsün. Kalıcı bir bildirimde "Bebek monitörü yayında" yazsın ve "Durdur" düğmesi olsun.

**Adım 0, deneme (spike, ~0,5 gün; kod commit'lenmeden önce cihazda kanıt):**
- Asgari bir foreground service ile şunlar doğrulanacak:
  - (a) flutter_webrtc kamera yakalaması uygulama arka plandayken ve ekran kapalıyken sürüyor mu?
  - (b) `camera` eklentisinin image stream'i (offline) ve sound_stream sürüyor mu?
  - (c) Dart isolate'i, Firestore dinleyicileri ve Nearby payload'ları ekran kapalıyken çalışmaya devam ediyor mu?
- Bilinen bir risk: `camera` eklentisi ve Flutter'ın yaşam döngüsü uygulama arka plana geçince kamerayı bırakmayı bekleyebilir. Şu an home_screen'de `WidgetsBindingObserver` **yok**; bu iyi (kamera elle kapatılmıyor), ama CameraX tabanlı uygulamanın kendi davranışı test edilmeli.

**Seçenek karşılaştırması:**

| | `flutter_foreground_task` (paket) | Kendi Kotlin servisimiz |
|---|---|---|
| Artı | Bildirim, izinler, düğmeler ve Dart'tan kontrol hazır. Aktif bakılıyor. | Bağımlılık yok, tam kontrol. Sadece servis ve bildirim (~150 satır Kotlin + MethodChannel). |
| Eksi | Son sürüm **11.0.3**, Flutter ≥ 3.44 / Dart ≥ 3.12 istiyor. Bizim ortam tam bu sürümde, ama `pubspec`'teki `sdk: ^3.6.2` alt sınırı yükseltilmeli. Ayrı bir TaskHandler isolate'i getiriyor; bize gerekmiyor ama zararı yok. | Android 14/15 kuralları (tür, izin, başlatma kısıtları) elle izlenmeli. |
| **Öneri** | **Bunu kullan.** Spike'ta sorun çıkarsa Kotlin'e geçilir. | Yedek plan |

**Değişecek / eklenecek dosyalar:**
- `pubspec.yaml`:
  - `flutter_foreground_task: ^11.0.3`
  - `environment.sdk` alt sınırı `^3.12.0` (paket bunu istiyor).
- `android/app/src/main/AndroidManifest.xml`:
  - İzinler: `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CAMERA`, `FOREGROUND_SERVICE_MICROPHONE`.
  - Offline Nearby için gerekiyorsa (spike'ta netleşecek): `FOREGROUND_SERVICE_CONNECTED_DEVICE`.
  - `<service android:name="com.pravera.flutter_foreground_task.service.ForegroundService" android:foregroundServiceType="camera|microphone" android:exported="false"/>`
- Yeni `lib/core/services/monitor_foreground_service.dart`:
  - `start({required bool offline})`, `stop()`, `isRunning`.
  - Bildirim metni ve "Durdur" düğmesi; düğmeye basılınca `_resetPairing` çağrılır.
- `lib/screens/home_screen.dart`:
  - Bebek yayını başlayınca servis başlatılır: online'da `startAsBaby` başarılı olduktan sonra, offline'da `startAdvertising` başarılı olduktan sonra.
  - `_resetPairing`, rol değişimi ve dispose'da servis durdurulur.
  - Servisin **uygulama ön plandayken** başlatılması zorunlu (Android 14 "while-in-use" kuralı). Yayın her zaman kullanıcı bir düğmeye bastığında başladığı için bu koşul sağlanıyor.
- `lib/l10n/app_localizations.dart`: bildirim metinleri.
- Pil optimizasyonu muafiyeti akışı (`_requestBatteryOptimization`) servisle birlikte gözden geçirilir.
- D1-a gece modu korunur; servis "ekran açık kalsın" zorunluluğunu kaldırır.

**İzinler (çalışma zamanı):** Kamera, mikrofon ve bildirim izinleri zaten isteniyor. Android 13+ cihazlarda bildirim izni reddedilirse servis bildirimi görünmez, ama servis yine çalışır. Kullanıcı yine de uyarılmalı.

**Firebase konsolu:** Yok.

**Google Play** (yayınlarken): Play Console'da "Foreground service types" beyanı ve kamera/mikrofon kullanımı için kısa bir video gerekir. Bu, mağazaya çıkma aşamasının işi.

**Riskler:**
- **En büyük risk:** kamera ya da mikrofon arka planda eklenti katmanında durabilir. Bu yüzden adım 0'daki spike yapılıyor. Kamera duruyorsa yakalamanın native servise taşınması gerekir; bu büyük bir iş ve ayrıca planlanır.
- Android 14+ servisi başlatma kısıtları: arka plandan başlatılamaz. Bu yüzden "yayın başlatıldığı anda" başlatılıyor.
- Bazı OEM'ler (MIUI, EMUI, ColorOS) servisi yine de öldürebilir. Kullanıcıyı "otomatik başlatma" ve "pil kısıtlaması yok" ayarlarına yönlendiren bir yardım ekranı önerilir.
- Ekran kapalıyken WebRTC'nin enerji tüketimi; uzun testte (Bölüm 10) ölçülecek.
- `sdk` alt sınırının yükselmesi, eski Flutter sürümüyle derlemeyi engeller. Sizin ortamınız uyumlu.

**Büyüklük:** L. Spike ~0,5 gün, uygulama 1,5–2 gün; yaklaşık 300–400 satır, manifest ve izin değişiklikleri.

---

## Ortak notlar

- **Kod değişikliği olmayan bağımlılıklar:** D3 ve D2 kurulduktan sonra `TEST_PLAN.md`'ye yeni bölümler eklenecek: kurallar, süresi dolan kod, FCM (ön plan, arka plan, kapalı), servis ve gece modu.
- **Geri alınabilirlik:** Her iş ayrı bir commit grubu.
  - Kurallar deploy edildikten sonra geri almak için önceki kurallar konsoldan geri yüklenebilir (konsol geçmiş tutar).
  - Function'lar `npx firebase-tools functions:delete onCryAlertCreated` ile kaldırılabilir.
- **Birbirine bağımlılık:**
  - D2'nin istemci kısmı D3'e bağlı (token alanı ve kurallar).
  - B08 şeması D3 kurallarına girdi olacak.
  - D1-a ve D1-b bağımsız.
