# DECISIONS.md — Otonom çalışma kararları

> Kullanıcı yokken alınan kararlar. Her biri: konu, seçenekler, seçim, neden.
> Daha önceki kararlar (K1–K7, D1–D11) BUGS.md ve PLAN_NEXT.md'de.

## Oturum: otonom mod (emülatör testleri, iOS)

### A1 — Güvenlik kuralları nereye
- **Seçenekler:** `.claude/settings.json` (repoya girer) / `.claude/settings.local.json` (yerel).
- **Seçim:** `.claude/settings.local.json`, `.gitignore`'da.
- **Neden:** Kullanıcı açıkça bunu istedi; makineye özel izinler repoya girmemeli.

### A2 — Firebase Emulator Suite yapılandırması
- **Seçenekler:** (a) `firebase.json`'a `emulators` bölümü eklemek, (b) yalnızca emülatörler için ayrı `firebase.emulators.json` + `--config`.
- **Seçim:** (b). `scripts/firebase_emulators.sh` bu dosyayla Auth + Firestore (bizim `firestore.rules`) + Functions başlatır.
- **Neden:** Gerçek deploy'da kullanılan `firebase.json` değişmesin; emülatör ayarı ayrı ve geri alınabilir.
- **Proje kimliği:** Emülatör `--project bebekmonitor-282fd` ile çalışır, çünkü uygulamanın Firebase ayarları bu kimliği kullanır (ad alanları eşleşmeli). Emülatör tamamen yereldir, giriş yapılmaz, gerçek projeye veri yazılmaz.

### A3 — Function emülatörde FCM'e gitmesin
- **Seçim:** `FUNCTIONS_EMULATOR === 'true'` iken gönderim yapılmaz; gönderilecek başlık/gövde odaya `lastPushPreview` olarak yazılır (yalnızca emülatörde).
- **Neden:** Emülatör uyarısı, emüle edilmeyen servislere yapılan çağrıların gerçek projeyi etkileyeceğini söylüyor. Testler gerçek FCM'e hiç istek atmamalı.

### A4 — Uygulama emülatöre nasıl bağlanır
- **Seçim:** Yalnızca debug derlemede ve `--dart-define=USE_FIREBASE_EMULATOR=true` verilirse (`kDebugMode` derleme zamanı sabiti). Android'de host adresi `10.0.2.2`, iOS simülatöründe `localhost`. Düz HTTP izni yalnızca `src/debug` manifestinde bu adresler için var.
- **Neden:** Release her zaman gerçek Firebase'e bağlanmalı; emülatör kodu release'e girmemeli.

### A5 — iOS minimum sürüm
- **Seçenekler:** 13 (Flutter varsayılanı) / 15 / 16.
- **Seçim:** iOS 15 (Podfile + Runner hedefi).
- **Neden:** Firebase, WebRTC ve kamera eklentileri ≥13 istiyor; 15 ileride çıkacak eklenti sürümleri için pay bırakıyor ve iPhone 6s/SE (1. nesil) ve sonrasını kapsıyor.

### A6 — iOS izin metinleri ve Xcode projesi
- **Seçim:** Temel metinler İngilizce `Info.plist`'te; Türkçe ve İngilizce `tr.lproj`/`en.lproj` `InfoPlist.strings` dosyalarında.
- **Nasıl:** Dosyaları projeye CocoaPods'un `xcodeproj` gem'i ile ekledim. `project.pbxproj`'u elle ya da regex'le düzenlemek yerine projenin kendi API'si kullanıldı; bu güvenli ve yapısal bir yöntem.
- **Neden:** iOS, izin metnini cihaz diline göre seçer.

### A7 — iOS'ta offline
- **Seçim:** Ayarlarda anahtarın yerine "Offline mod yalnızca Android'de kullanılabilir" açıklaması gösteriliyor; kontrol kartı gizli. Android aynen kalıyor.
- **Neden:** Kullanıcının istediği bu; kod silinmedi.

### A8 — Android E2E: önce API 36, sonra API 35 Google Play
- **Durum:** API 35 Google Play image'ın indirmesi takıldı (849 MB'ta durdu); ikinci denemede tamamlandı.
- **Seçim:** Beklememek için testleri, makinede kurulu olan API 36 `google_apis` image'ı (Google Play servisleri var, Play Store yok) ile oluşturulan "baby"/"parent" AVD'leriyle geliştirdim ve hataları ayıkladım. Son koşu, aynı adlarla API 35 Google Play image üzerine yeniden kurulan AVD'lerde.
- **Neden:** Kullanıcının istediği Play'li image; iki koşu arasında test kodu aynı.

### A9 — E2E'de WebRTC bağlantısı nasıl ölçülür
- **Seçim:** Ana ekrandaki bağlantı durumu metni ("Bağlı"). Odadaki `isPaired` alanı yeterli değil, çünkü ebeveyn cevap verirken bu alanı `true` yapıyor (ilk koşularda yanıltıcı sonuç verdi).

### A10 — iOS simülatörü: iOS 27 çalışma zamanı
- **Durum:** iOS 26.5 simülatöründe uygulama açılışta çöküyor. Neden: `sound_stream` eklentisi kayıt sırasında `AVAudioEngine` başlatıyor, CoreAudio `AURemoteIO` RPC zaman aşımına uğrayıp `abort` ediyor. Aynı derleme iOS 27.0 simülatöründe sorunsuz açılıyor.
- **Seçim:** E2E iOS 27 simülatörlerinde (`baby-ios27`, `parent-ios27`). Kodda değişiklik yok.
- **Not:** Eski `baby-ios` / `parent-ios` (iOS 26.5) simülatörleri ve `try-ios27` kapatıldı ama silinmedi (proje dışında dosya silmeme kuralı). İsterseniz Xcode → Devices and Simulators'tan silebilirsiniz.

## Cavid'in kararı bekleniyor

- **`sound_stream` GPL-3.0 lisanslı:** Offline modda ses akışı için kullanılan bu paket GPL-3.0. Uygulama App Store/Play'de dağıtılırsa GPL yükümlülükleri (kaynak kodun açılması) doğar; App Store ile GPL uyumu da tartışmalı. Seçenekler:
  - (a) Offline ses akışını MIT/BSD lisanslı bir paketle değiştirmek (ör. `record` + `flutter_sound` / `just_audio` ya da Android'e özel kısa bir platform kanalı),
  - (b) Uygulamayı GPL ile yayınlamayı kabul etmek.
  - **Önerim (a).** iOS'ta bu paket zaten kullanılmıyor (offline iOS'ta kapalı), ama açılışta ses motorunu başlatıyor.

- **Android ↔ iOS offline:** Gerekli mi? Seçenekler ve önerim (yerel Wi-Fi üzerinden WebRTC + LAN signaling, sonra hotspot) PLAN_NEXT.md bölüm 6'da.
