# Sesler — lisans

Bu klasördeki tüm sesler `tool/gen_sounds.py` ile **bu projede sentezlendi** (yalnızca Python standart kütüphanesi). Üçüncü taraf kayıt veya örnek (sample) yok; projenin kendi lisansı geçerlidir.

| Dosya | İçerik | Kaynak |
|---|---|---|
| `alarm_connection.wav` | Bağlantı koptu alarmı (iki inen zil) | Sentez |
| `alarm_cry.wav` | Ağlama alarmı (üç yükselen zil) | Sentez |
| `soothe_white_noise.wav` | Beyaz gürültü (yumuşak, pembe gürültü filtresi) | Sentez, kesintisiz döngü |
| `soothe_rain.wav` | Yağmur (filtrelenmiş gürültü + damlalar) | Sentez, kesintisiz döngü |
| `soothe_heartbeat.wav` | Kalp atışı, 70 vuruş/dk | Sentez |
| `soothe_dandini.wav` | "Dandini dandini dastana", kutu müziği tınısı | Sentez. Melodi geleneksel Türk ninnisidir (anonim, kamu malı). Nota aktarımı bizim; kulakla kontrol edilmeli (BLOCKERS) |

Yeniden üretmek için: `python3 tool/gen_sounds.py`.
