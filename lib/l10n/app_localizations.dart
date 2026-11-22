import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [Locale('tr'), Locale('en')];

  /// Raw translation tables, exposed only so tests can check TR/EN key parity.
  @visibleForTesting
  static Map<String, Map<String, String>> get debugLocalizedValues => _localizedValues;

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'settings': 'Settings',
      'theme': 'Theme',
      'systemDefault': 'System Default',
      'lightMode': 'Light Mode',
      'darkMode': 'Dark Mode',
      'language': 'Language',
      'offlineMode': 'Offline Mode (Nearby)',
      'offlineModeSubtitle': 'Use local connection without internet',
      'noiseThreshold': 'Noise Threshold',
      'moreSensitive': 'More sensitive',
      'lessSensitive': 'Less sensitive',
      'keepScreenOn': 'Keep Screen On',
      'keepScreenOnSubtitle': 'Screen will not turn off while app is open',
      'videoSettings': 'Video Settings',
      'resolution': 'Resolution',
      'frameRate': 'Frame Rate (FPS)',
      'bitrate': 'Bitrate (Kbps)',
      'low': 'Low',
      'medium': 'Medium',
      'high': 'High',
      'appTitle': 'Baby Monitor',
      'ok': 'OK',
      'cancel': 'Cancel',
      'error': 'Error',
      'loading': 'Loading...',
      'babyMode': 'Baby Mode',
      'parentMode': 'Parent Mode',
      'multiCameraMode': 'Multi Camera Mode',
      'createRoomCode': 'Create/Refresh Room Code',
      'startBroadcastOffline': 'Start Broadcast (Offline)',
      'enterRoomCode': 'Enter Room Code',
      'searchDeviceOffline': 'Search Device (Offline)',
      'camerasReadError': 'Cameras could not be read: ',
      'noCameraFound': 'No available camera found on device.',
      'cameraInitError': 'Camera initialization error: ',
      'firebaseConfigMissing': 'Firebase configuration not found. Pairing disabled.',
      'pairingInitError': 'Pairing could not be started: ',
      'roomCreationErrorFirebase': 'Room could not be created due to missing Firebase settings.',
      'roomCode': 'Room Code',
      'copy': 'Copy',
      'share': 'Share',
      'waitingForConnection': 'Waiting for connection...',
      'connected': 'Connected',
      'disconnected': 'Disconnected',
      'roomCodeCopied': 'Room code copied',
      'enterRoomCodeTitle': 'Enter Room Code',
      'enterRoomCodeSubtitle': 'Please enter the room code',
      'connect': 'Connect',
      'invalidRoomCode': 'Invalid room code',
      'roomNotFound': 'Room not found',
      'roomFull': 'Room full',
      'babyCrying': 'Baby Crying!',
      'noiseDetected': 'Noise detected',
      'lowBattery': 'Low Battery',
      'babyDeviceLowBattery': 'Baby device battery is low',
      'alertHistory': 'Alarm history',
      'today': 'Today',
      'yesterday': 'Yesterday',
      'noRecordsFound': 'No records found',
      'pickDate': 'Pick Date',
      'startTime': 'Start Time',
      'endTime': 'End Time',
      'filter': 'Filter',
      'clear': 'Clear',
      'videoGallery': 'Video Gallery',
      'recordings': 'Recordings',
      'recordingDeleted': 'Recording deleted',
      'delete': 'Delete',
      'play': 'Play',
      'noiseLevel': 'Noise Level',
      'cameraPreview': 'Camera Preview',
      'stop': 'Stop',
      'start': 'Start',
      'retry': 'Retry',
      'permissionDenied': 'Permission denied',
      'microphonePermissionRequired': 'Microphone permission is required',
      'cameraPermissionRequired': 'Camera permission is required',
      'storagePermissionRequired': 'Storage permission is required',
      'locationPermissionRequired': 'Location permission is required for offline mode',
      'nearbyDevicesPermissionRequired': 'Nearby devices permission is required',
      'notificationsPermissionRequired': 'Notifications permission is required',
      'batteryOptimization': 'Battery Optimization',
      'ignoreBatteryOptimizations': 'Ignore battery optimizations for better performance?',
      'yes': 'Yes',
      'no': 'No',
      'confirmDelete': 'Are you sure you want to delete this recording?',
      'shareVideo': 'Share Video',
      'videoPlayer': 'Video Player',
      'onlineMode': 'Online Mode',
      'findBroadcast': 'Find Broadcast',
      'joinRoom': 'Join Room',
      'stopRecording': 'Stop Recording',
      'startRecording': 'Start Recording',
      'disconnect': 'Disconnect',
      'startCamera': 'Start Camera',
      'stopCamera': 'Stop Camera',
      'createRoom': 'Create Room',
      'startBroadcast': 'Start Broadcast',
      'charging': 'Charging',
      'babyDeviceBattery': 'Baby Device Battery',
      'wifi': 'Wi-Fi',
      'network': 'Network',
      'temperature': 'Temperature',
      'clearHistory': 'Clear History',
      'clearHistoryConfirmation': 'Are you sure you want to delete all alert history?',
      'dateAll': 'Date: All',
      'date': 'Date',
      'pick': 'Pick',
      'change': 'Change',
      'timeRangeAll': 'Time Range: All',
      'end': 'End',
      'noAlertsYet': 'No alerts recorded yet.',
      'motionOrSoundDetected': 'Motion/Sound Detected',
      'videoPlaybackHint': 'If videos are not playing, please update the app on the Baby Unit device as well.',
      'gifAnimation': 'GIF Animation',
      'videoRecording': 'Video Recording',
      'videoFileNotFound': 'Video file not found',
      'videoFileEmpty': 'Video file is empty (0 bytes)',
      'videoInitTimeout': 'Video initialization timed out. File might be corrupted or unsupported.',
      'videoPlaybackError': 'Video could not be played',
      'addCamera': 'Add Camera',
      'enterRoomId': 'Enter Room ID',
      'add': 'Add',
      'multiCameraMonitoring': 'Multi Camera Monitoring',
      'noCameraAdded': 'No camera added yet.',
      'baby': 'Baby',
      'room': 'Room',
      'status': 'Status',
      'cameraInitializing': 'Camera initializing...',
      'previewNotReady': 'Preview not ready. Try starting the camera.',
      'openAppSettings': 'Open App Settings',
      'cameraNotReady': 'Camera not ready',
      'babyMightBeCrying': 'Baby might be crying',      'babyCryAlert': 'Baby Cry Alert',      'passive': 'Passive',
      'threshold': 'Threshold',
      'highNoise': 'High Noise',
      'cameraPaused': 'Camera Paused',
      'cameraOn': 'Camera On',
      'cameraOff': 'Camera Off',
      'audioMonitoringOn': 'Audio Monitoring On',
      'audioMonitoringOff': 'Audio Monitoring Off',
      'connectionStatus': 'Connection Status',
      'videoSettingsUpdated': 'Video settings updated',
      'unknownDevice': 'Unknown device',
      'addFirstCameraHint': 'Tap the + button to add your first camera',
      'offlineAndroidOnly': 'Offline mode is only available on Android',
      'offlineRecordingInfo': 'Offline recordings are silent, low-resolution GIFs. Maximum length',
      'offlineRecordingLimitReached': 'Offline recording reached its time limit and was saved',
      'nightModeExitHint': 'Night mode. Double-tap to exit',
      'nightModeAction': 'Night mode',
      'iosCameraForegroundHint': 'On iPhone the camera stops when the app is closed or the screen locks. Use night mode and keep the app open',
      'nightModeKeepAppOpen': 'Keep the app open and do not lock the screen, or the stream stops',
      'autoNightMode': 'Night mode when connected',
      'autoNightModeSubtitle': 'Baby device: screen turns black at minimum brightness once the parent connects',
      'roomClosed': 'The baby device closed the room. Ask for a new room code',
      'roomUnavailable': 'Code is wrong, expired, or already paired with another device',
      'anonymousAuthDisabled': 'Sign-in is not enabled for this app (Firebase: Anonymous sign-in)',
      'roomCodeValidHint': 'Enter this code on the parent device within 10 minutes',
      'noServerResponse': 'No response from the server. Check the internet connection and try again',
      'backgroundListening': 'Listen in the background',
      'backgroundListeningSubtitle': 'Parent phone: keep hearing the baby when the screen is locked',
      'serviceBabyTitle': 'Ninni is broadcasting',
      'serviceBabyText': 'Camera and microphone stay on for the parent phone',
      'serviceParentTitle': 'Ninni is listening',
      'serviceParentText': 'You will hear the baby and get alerts',
      'connectionLostTitle': 'Lost connection to the baby phone',
      'connectionLostBody': 'No picture or sound for {seconds} seconds. You cannot watch the baby right now.',
      'reconnecting': 'Trying to reconnect…',
      'tryAgain': 'Try again',
      'silenceAlarm': 'Silence alarm',
      'checkBabyPhone': 'CHECK THE BABY PHONE',
      'checkWifi': 'Is Wi-Fi on?',
      'checkAppOpen': 'The app may have been closed',
      'checkCharger': 'Last battery: {level}% — it may not be charging',
      'batteryLowTitle': 'Baby phone battery is low',
      'batteryLowBody': 'Battery at {level}%. Plug the baby phone into a charger.',
      'dismiss': 'Dismiss',
      'connectionLostNotification': 'No picture or sound from the baby phone. Open Ninni.',
      'alarmAfter2s': 'Alarm if crying lasts 2 s',
      'alarmDuration': 'Time before alarm',
      'alarmDurationSub': 'If the sound lasts this long',
      'alarmsLabel': 'alarms',
      'allow': 'Allow',
      'androidOnly': '(Android only)',
      'appTagline': 'Baby Monitor',
      'autoNightModeShort': 'The baby phone\'s screen goes dark',
      'babyCalm': 'Baby is calm',
      'babyCryingShort': 'Baby is crying',
      'babyStirring': 'Some sound',
      'babyDevice': 'Baby device',
      'babyDeviceBatteryShort': 'Baby device {level}%',
      'babyPairingTitle': 'Enter this code on the parent phone',
      'babyPairingSubtitle': 'The code is valid for 10 minutes.',
      'babyPlacementHint': 'Leave the phone on the charger, 1–2 metres from the baby.',
      'iosKeepOpenHint': 'On iPhone keep Ninni open and use night mode; the camera stops when the screen locks.',
      'babyShort': 'Baby',
      'youShort': 'You',
      'back': 'Back',
      'batteryCharging': '{level}% · charging',
      'batteryPercent': '{level}%',
      'cameraMicReady': 'Camera and microphone are ready',
      'cameraPreparing': 'Preparing camera…',
      'clearHistoryTitle': 'Clear history?',
      'clearHistoryBody': 'All alarm entries on this phone are deleted.',
      'close': 'Close',
      'codeExpired': 'The code has expired. Create a new one.',
      'codeValidFor': 'Code valid for {time} more',
      'connecting': 'Connecting',
      'continueLabel': 'Continue',
      'copied': 'Code copied',
      'cry': 'Crying',
      'cryStopped': 'stopped',
      'cryingForSeconds': 'for {s} seconds',
      'defaultRoomName': 'Baby room',
      'disconnectTitle': 'Disconnect?',
      'disconnectBody': 'You will stop watching and get no more alarms from this room.',
      'endBroadcast': 'End broadcast',
      'endBroadcastTitle': 'End the broadcast?',
      'endBroadcastBody': 'The parent phone disconnects and the room code stops working.',
      'enterNightMode': 'Switch to night mode',
      'fullscreen': 'Full screen',
      'granted': 'Granted',
      'history': 'History',
      'hoursShort': '{h} h',
      'hoursMinutesShort': '{h} h {m} min',
      'minutesShort': '{m} min',
      'minutesSecondsShort': '{m} min {s} s',
      'secondsShort': '{s} s',
      'imReady': 'I\'m ready',
      'joinTitle': 'Connect to the room',
      'joinSubtitle': 'Enter the 8 character code shown on the baby phone.',
      'last7Days': '7 days',
      'lastAlarmAt': 'last alarm {time}',
      'later': 'Later',
      'letsStart': 'Let\'s start',
      'levelActive': 'Some sound',
      'levelLoud': 'Loud',
      'levelOff': 'Starting…',
      'levelQuiet': 'Quiet',
      'licenses': 'Licences',
      'linkGood': 'Good connection',
      'live': 'LIVE',
      'liveView': 'Live view',
      'longestQuietLabel': 'longest quiet',
      'newCode': 'New code',
      'nightExitHint': 'Tap twice to exit',
      'nightStatusConnected': 'Broadcasting · parent connected',
      'nightStatusWaiting': 'Broadcasting · waiting for the parent',
      'noAlertsInRange': 'No alarms in this period. A quiet night!',
      'noInternet': 'No internet?',
      'notifyInterval': 'Notification interval',
      'notifyIntervalSub': 'At most, while crying continues',
      'perMinute': '1 / min',
      'now': 'now',
      'offlineBabyTitle': 'Waiting for a nearby parent phone',
      'offlineBabyBody': 'No internet needed. On the parent phone choose “With me” and tap “Search nearby”. Bluetooth, Wi-Fi and location must be on.',
      'offlineModeShort': 'Offline mode',
      'offlineParentTitle': 'Find the baby phone',
      'offlineParentBody': 'Both phones nearby, with Bluetooth, Wi-Fi and location on.',
      'onboardTitle1': 'While your baby sleeps,\nyou can sleep too',
      'onboardBody1': 'Turn the two phones you have into a baby monitor in seconds.',
      'onboardTitle2': 'Ready in three steps',
      'onboardStep1Title': 'Put one phone next to the baby',
      'onboardStep1Body': 'An old phone works too. Keep it on the charger.',
      'onboardStep2Title': 'Enter the code',
      'onboardStep2Body': 'The two phones pair over a secure connection. The code is valid for 10 minutes.',
      'onboardStep3Title': 'Know at once when the baby cries',
      'onboardStep3Body': 'Notifications arrive even when the app is closed. Live picture and sound.',
      'onboardTitle3': 'A few permissions are needed',
      'onboardBody3': 'We wrote why each one is needed. You can change them any time in the settings.',
      'openSettings': 'Open settings',
      'openVideo': 'Open the video',
      'pageOf': 'Page {n} of {total}',
      'parentConnected': 'Parent connected',
      'parentWaiting': 'Waiting for parent',
      'permCamera': 'Camera',
      'permCameraWhy': 'So you can see the baby',
      'permMic': 'Microphone',
      'permMicWhy': 'To hear crying and to talk',
      'permNotifications': 'Notifications',
      'permNotificationsWhy': 'For the cry alarm',
      'permNearby': 'Nearby devices',
      'permNearbyWhy': 'For offline mode (optional)',
      'privacyNote': 'Picture and sound go encrypted between the two phones. They are not stored on our servers.',
      'quality': 'Quality',
      'qualitySaver': 'Saver',
      'qualityBalanced': 'Balanced',
      'qualitySharp': 'Sharp',
      'record': 'Record',
      'stopRecordingShort': 'Stop',
      'replayIntro': 'Show the intro again',
      'roleTitle': 'Where will this phone be?',
      'roleSubtitle': 'Pair two phones: one next to the baby, the other with you.',
      'roleBabyTitle': 'Next to the baby',
      'roleBabyBody': 'This phone becomes the camera and microphone. It detects crying and lets you know.',
      'roleParentTitle': 'With me',
      'roleParentBody': 'Watch the baby live and get an alert as soon as they cry.',
      'roomShort': 'Room',
      'searchNearby': 'Search nearby',
      'searching': 'Searching for the baby phone…',
      'sectionAbout': 'About',
      'sectionAlarm': 'Alarm',
      'sectionApp': 'App',
      'sectionVideo': 'Picture',
      'sensitivity': 'Sensitivity',
      'shareCodeText': 'Ninni room code: {code}',
      'shortNoise': 'Short noise',
      'skip': 'Skip',
      'snooze5': 'Snooze 5 min',
      'soundLevel': 'Sound level',
      'switchCamera': 'Switch camera',
      'switchShort': 'Flip',
      'themeAuto': 'Automatic',
      'themeLight': 'Light',
      'themeDark': 'Dark',
      'thresholdValue': 'Threshold {db} dB',
      'tonight': 'Tonight',
      'totalCryLabel': 'total crying',
      'waitingForParent': 'Waiting for the parent phone',
    },
    'tr': {
      'settings': 'Ayarlar',
      'theme': 'Tema',
      'systemDefault': 'Sistem Varsayılanı',
      'lightMode': 'Açık Mod',
      'darkMode': 'Koyu Mod',
      'language': 'Dil',
      'offlineMode': 'Offline Mod (Nearby)',
      'offlineModeSubtitle': 'İnternet olmadan yerel bağlantı kullan',
      'noiseThreshold': 'Gürültü Eşiği',
      'moreSensitive': 'Daha hassas',
      'lessSensitive': 'Daha az hassas',
      'keepScreenOn': 'Ekranı Açık Tut',
      'keepScreenOnSubtitle': 'Uygulama açıkken ekran kapanmaz',
      'videoSettings': 'Video Ayarları',
      'resolution': 'Çözünürlük',
      'frameRate': 'Kare Hızı (FPS)',
      'bitrate': 'Bitrate (Kbps)',
      'low': 'Düşük',
      'medium': 'Orta',
      'high': 'Yüksek',
      'appTitle': 'Bebek Monitor',
      'ok': 'Tamam',
      'cancel': 'İptal',
      'error': 'Hata',
      'loading': 'Yükleniyor...',
      'babyMode': 'Bebek Modu',
      'parentMode': 'Ebeveyn Modu',
      'multiCameraMode': 'Çoklu Kamera Modu',
      'createRoomCode': 'Oda Kodu Oluştur/Yenile',
      'startBroadcastOffline': 'Yayın Başlat (Offline)',
      'enterRoomCode': 'Oda Kodunu Gir',
      'searchDeviceOffline': 'Cihaz Ara (Offline)',
      'camerasReadError': 'Kameralar okunamadı: ',
      'noCameraFound': 'Cihazda kullanılabilir kamera bulunamadı.',
      'cameraInitError': 'Kamera başlatma hatası: ',
      'firebaseConfigMissing': 'Firebase yapılandırması bulunamadı. Eşleştirme devre dışı.',
      'pairingInitError': 'Eşleştirme başlatılamadı: ',
      'roomCreationErrorFirebase': 'Firebase ayarları eksik olduğu için oda oluşturulamadı.',
      'roomCode': 'Oda Kodu',
      'copy': 'Kopyala',
      'share': 'Paylaş',
      'waitingForConnection': 'Bağlantı bekleniyor...',
      'connected': 'Bağlı',
      'disconnected': 'Bağlantı kesildi',
      'roomCodeCopied': 'Oda kodu kopyalandı',
      'enterRoomCodeTitle': 'Oda Kodu Girin',
      'enterRoomCodeSubtitle': 'Lütfen oda kodunu giriniz',
      'connect': 'Bağlan',
      'invalidRoomCode': 'Geçersiz oda kodu',
      'roomNotFound': 'Oda bulunamadı',
      'roomFull': 'Oda dolu',
      'babyCrying': 'Bebek Ağlıyor!',
      'noiseDetected': 'Gürültü algılandı',
      'lowBattery': 'Pil Düşük',
      'babyDeviceLowBattery': 'Bebek cihazının şarjı azaldı',
      'alertHistory': 'Alarm geçmişi',
      'today': 'Bugün',
      'yesterday': 'Dün',
      'noRecordsFound': 'Kayıt bulunamadı',
      'pickDate': 'Tarih Seç',
      'startTime': 'Başlangıç Saati',
      'endTime': 'Bitiş Saati',
      'filter': 'Filtrele',
      'clear': 'Temizle',
      'videoGallery': 'Video Galeri',
      'recordings': 'Kayıtlar',
      'recordingDeleted': 'Kayıt silindi',
      'delete': 'Sil',
      'play': 'Oynat',
      'noiseLevel': 'Gürültü Seviyesi',
      'cameraPreview': 'Kamera Önizleme',
      'stop': 'Durdur',
      'start': 'Başlat',
      'retry': 'Tekrar Dene',
      'permissionDenied': 'İzin reddedildi',
      'microphonePermissionRequired': 'Mikrofon izni gerekli',
      'cameraPermissionRequired': 'Kamera izni gerekli',
      'storagePermissionRequired': 'Depolama izni gerekli',
      'locationPermissionRequired': 'Offline mod için konum izni gerekli',
      'nearbyDevicesPermissionRequired': 'Yakındaki cihazlar izni gerekli',
      'notificationsPermissionRequired': 'Bildirim izni gerekli',
      'batteryOptimization': 'Pil Optimizasyonu',
      'ignoreBatteryOptimizations': 'Daha iyi performans için pil optimizasyonlarını yoksay?',
      'yes': 'Evet',
      'no': 'Hayır',
      'confirmDelete': 'Bu kaydı silmek istediğinizden emin misiniz?',
      'shareVideo': 'Videoyu Paylaş',
      'videoPlayer': 'Video Oynatıcı',
      'onlineMode': 'Online Mod',
      'findBroadcast': 'Yayın Bul',
      'joinRoom': 'Odaya Katıl',
      'stopRecording': 'Kaydı Durdur',
      'startRecording': 'Kayıt Başlat',
      'disconnect': 'Bağlantıyı kes',
      'startCamera': 'Kamerayı Aç',
      'stopCamera': 'Kamerayı Kapat',
      'createRoom': 'Oda Oluştur',
      'startBroadcast': 'Yayın Başlat',
      'charging': 'Şarj Oluyor',
      'babyDeviceBattery': 'Bebek Cihazı Pil',
      'wifi': 'WiFi',
      'network': 'Ağ',
      'temperature': 'Sıcaklık',
      'clearHistory': 'Geçmişi Temizle',
      'clearHistoryConfirmation': 'Tüm uyarı geçmişini silmek istediğinize emin misiniz?',
      'dateAll': 'Tarih: Tümü',
      'date': 'Tarih',
      'pick': 'Seç',
      'change': 'Değiştir',
      'timeRangeAll': 'Saat Aralığı: Tümü',
      'end': 'Bitir',
      'noAlertsYet': 'Henüz kaydedilmiş bir uyarı yok.',
      'motionOrSoundDetected': 'Hareket/Ses Algılandı',
      'videoPlaybackHint': 'Videolar oynatılmıyorsa, lütfen Bebek Ünitesi cihazındaki uygulamayı da güncelleyin.',
      'gifAnimation': 'GIF Animasyon',
      'videoRecording': 'Video Kaydı',
      'videoFileNotFound': 'Video dosyası bulunamadı',
      'videoFileEmpty': 'Video dosyası boş (0 byte)',
      'videoInitTimeout': 'Video başlatma zaman aşımına uğradı. Dosya bozuk veya desteklenmiyor olabilir.',
      'videoPlaybackError': 'Video oynatılamadı',
      'addCamera': 'Kamera Ekle',
      'enterRoomId': 'Oda ID giriniz',
      'add': 'Ekle',
      'multiCameraMonitoring': 'Çoklu Bebek İzleme',
      'noCameraAdded': 'Henüz kamera eklenmedi.',
      'baby': 'Bebek',
      'room': 'Oda',
      'status': 'Durum',
      'cameraInitializing': 'Kamera hazırlanıyor...',
      'previewNotReady': 'Önizleme hazır değil. Kamerayı başlatmayı deneyin.',
      'openAppSettings': 'Uygulama Ayarlarını Aç',
      'cameraNotReady': 'Kamera hazır değil',
      'babyMightBeCrying': 'Bebek ağlıyor olabilir',
      'babyCryAlert': 'Bebek Ağlama Alarmı',
      'passive': 'Pasif',
      'threshold': 'Eşik',
      'highNoise': 'Yüksek Ses',
      'cameraPaused': 'Kamera Duraklatıldı',
      'cameraOn': 'Kamera Açık',
      'cameraOff': 'Kamera Kapalı',
      'audioMonitoringOn': 'Ses İzleme Açık',
      'audioMonitoringOff': 'Ses İzleme Kapalı',
      'connectionStatus': 'Bağlantı Durumu',
      'videoSettingsUpdated': 'Video ayarları güncellendi',
      'unknownDevice': 'Bilinmeyen cihaz',
      'addFirstCameraHint': 'İlk kameranızı eklemek için + düğmesine dokunun',
      'offlineAndroidOnly': 'Offline mod yalnızca Android\'de kullanılabilir',
      'offlineRecordingInfo': 'Offline kayıtlar sessiz ve düşük çözünürlüklü GIF olur. En fazla süre',
      'offlineRecordingLimitReached': 'Offline kayıt süre sınırına ulaştı ve kaydedildi',
      'nightModeExitHint': 'Gece modu. Çıkmak için iki kez dokunun',
      'nightModeAction': 'Gece modu',
      'iosCameraForegroundHint': 'iPhone\'da uygulama kapanınca veya ekran kilitlenince kamera durur. Gece modunu kullanın ve uygulamayı açık bırakın',
      'nightModeKeepAppOpen': 'Yayının sürmesi için uygulamayı açık bırakın ve ekranı kilitlemeyin',
      'autoNightMode': 'Bağlanınca gece moduna geç',
      'autoNightModeSubtitle': 'Bebek cihazı: ebeveyn bağlanınca ekran en düşük parlaklıkta kararır',
      'roomClosed': 'Bebek cihazı odayı kapattı. Yeni bir oda kodu isteyin',
      'roomUnavailable': 'Kod hatalı, süresi dolmuş veya başka bir cihazla eşleşmiş',
      'anonymousAuthDisabled': 'Bu uygulama için giriş açık değil (Firebase: Anonim giriş)',
      'roomCodeValidHint': 'Bu kodu ebeveyn cihazına 10 dakika içinde girin',
      'noServerResponse': 'Sunucudan yanıt yok. İnternet bağlantısını kontrol edip tekrar deneyin',
      'backgroundListening': 'Arka planda dinle',
      'backgroundListeningSubtitle': 'Ebeveyn telefonu: ekran kilitliyken de bebeği duymaya devam et',
      'serviceBabyTitle': 'Ninni yayında',
      'serviceBabyText': 'Kamera ve mikrofon ebeveyn telefonu için açık',
      'serviceParentTitle': 'Ninni dinliyor',
      'serviceParentText': 'Bebeği duyacak ve uyarı alacaksınız',
      'connectionLostTitle': 'Bebek telefonuyla bağlantı koptu',
      'connectionLostBody': '{seconds} saniyedir görüntü ve ses gelmiyor. Bebeği şu anda izleyemiyorsunuz.',
      'reconnecting': 'Yeniden bağlanmaya çalışıyoruz…',
      'tryAgain': 'Tekrar dene',
      'silenceAlarm': 'Alarmı sustur',
      'checkBabyPhone': 'BEBEK TELEFONUNDA KONTROL EDİN',
      'checkWifi': 'Wi-Fi bağlantısı açık mı?',
      'checkAppOpen': 'Uygulama kapatılmış olabilir',
      'checkCharger': 'Son pil durumu: %{level} — şarjda olmayabilir',
      'batteryLowTitle': 'Bebek telefonunun pili azaldı',
      'batteryLowBody': 'Pil %{level}. Bebek telefonunu şarja takın.',
      'dismiss': 'Kapat',
      'connectionLostNotification': 'Bebek telefonundan görüntü ve ses gelmiyor. Ninni\'yi açın.',
      'alarmAfter2s': 'Ağlama 2 sn sürerse alarm',
      'alarmDuration': 'Alarm için süre',
      'alarmDurationSub': 'Ses bu kadar sürerse',
      'alarmsLabel': 'alarm',
      'allow': 'İzin ver',
      'androidOnly': '(yalnızca Android)',
      'appTagline': 'Bebek Monitörü',
      'autoNightModeShort': 'Bebek telefonunun ekranı kararır',
      'babyCalm': 'Bebek sakin',
      'babyCryingShort': 'Bebek ağlıyor',
      'babyStirring': 'Ses var',
      'babyDevice': 'Bebek cihazı',
      'babyDeviceBatteryShort': 'Bebek cihazı %{level}',
      'babyPairingTitle': 'Bu kodu ebeveyn telefonuna girin',
      'babyPairingSubtitle': 'Kod 10 dakika geçerlidir.',
      'babyPlacementHint': 'Telefonu şarja takılı ve bebeğe 1–2 metre uzakta bırakın.',
      'iosKeepOpenHint': 'iPhone\'da Ninni\'yi açık bırakın ve gece modunu kullanın; ekran kilitlenince kamera durur.',
      'babyShort': 'Bebek',
      'youShort': 'Siz',
      'back': 'Geri',
      'batteryCharging': '%{level} · şarjda',
      'batteryPercent': '%{level}',
      'cameraMicReady': 'Kamera ve mikrofon hazır',
      'cameraPreparing': 'Kamera hazırlanıyor…',
      'clearHistoryTitle': 'Geçmiş silinsin mi?',
      'clearHistoryBody': 'Bu telefondaki tüm alarm kayıtları silinir.',
      'close': 'Kapat',
      'codeExpired': 'Kodun süresi doldu. Yeni bir kod oluşturun.',
      'codeValidFor': 'Kod {time} dakika daha geçerli',
      'connecting': 'Bağlanıyor',
      'continueLabel': 'Devam',
      'copied': 'Kod kopyalandı',
      'cry': 'Ağlama',
      'cryStopped': 'durdu',
      'cryingForSeconds': '{s} saniyedir',
      'defaultRoomName': 'Bebek odası',
      'disconnectTitle': 'Bağlantı kesilsin mi?',
      'disconnectBody': 'İzleme durur ve bu odadan alarm almazsınız.',
      'endBroadcast': 'Yayını bitir',
      'endBroadcastTitle': 'Yayın bitirilsin mi?',
      'endBroadcastBody': 'Ebeveyn telefonunun bağlantısı kesilir ve oda kodu geçersiz olur.',
      'enterNightMode': 'Gece moduna geç',
      'fullscreen': 'Tam ekran',
      'granted': 'Verildi',
      'history': 'Geçmiş',
      'hoursShort': '{h} sa',
      'hoursMinutesShort': '{h} sa {m} dk',
      'minutesShort': '{m} dk',
      'minutesSecondsShort': '{m} dk {s} sn',
      'secondsShort': '{s} sn',
      'imReady': 'Hazırım',
      'joinTitle': 'Odaya bağlanın',
      'joinSubtitle': 'Bebek telefonunda görünen 8 haneli kodu girin.',
      'last7Days': '7 gün',
      'lastAlarmAt': 'son alarm {time}',
      'later': 'Sonra',
      'letsStart': 'Başlayalım',
      'levelActive': 'Hareketli',
      'levelLoud': 'Yüksek',
      'levelOff': 'Başlıyor…',
      'levelQuiet': 'Sessiz',
      'licenses': 'Lisanslar',
      'linkGood': 'Bağlantı iyi',
      'live': 'CANLI',
      'liveView': 'Canlı görüntü',
      'longestQuietLabel': 'en uzun sessiz',
      'newCode': 'Yeni kod',
      'nightExitHint': 'Çıkmak için iki kez dokunun',
      'nightStatusConnected': 'Yayın sürüyor · ebeveyn bağlı',
      'nightStatusWaiting': 'Yayın sürüyor · ebeveyn bekleniyor',
      'noAlertsInRange': 'Bu aralıkta alarm yok. Sakin bir gece!',
      'noInternet': 'İnternet yok mu?',
      'notifyInterval': 'Bildirim aralığı',
      'notifyIntervalSub': 'Ağlama sürerken en fazla',
      'perMinute': '1 / dk',
      'now': 'şimdi',
      'offlineBabyTitle': 'Yakındaki ebeveyn telefonu bekleniyor',
      'offlineBabyBody': 'İnternet gerekmez. Ebeveyn telefonunda “Benim yanımda”yı seçip “Yakındaki cihazı ara”ya dokunun. Bluetooth, Wi-Fi ve konum açık olmalı.',
      'offlineModeShort': 'İnternetsiz mod',
      'offlineParentTitle': 'Bebek telefonunu bulun',
      'offlineParentBody': 'İki telefon yakın olsun; Bluetooth, Wi-Fi ve konum açık olmalı.',
      'onboardTitle1': 'Bebeğiniz uyurken,\nsiz de rahat uyuyun',
      'onboardBody1': 'Elinizdeki iki telefonu birkaç saniyede bebek monitörüne dönüştürün.',
      'onboardTitle2': 'Üç adımda hazır',
      'onboardStep1Title': 'Bir telefonu bebeğin yanına koyun',
      'onboardStep1Body': 'Eski bir telefon da olur. Şarja takılı kalsın.',
      'onboardStep2Title': 'Kodu girin',
      'onboardStep2Body': 'İki telefon güvenli bir bağlantıyla eşleşir. Kod 10 dakika geçerlidir.',
      'onboardStep3Title': 'Ağladığında hemen haberiniz olsun',
      'onboardStep3Body': 'Uygulama kapalıyken bile bildirim gelir. Görüntü ve ses canlı.',
      'onboardTitle3': 'Birkaç izin gerekiyor',
      'onboardBody3': 'Her birinin neden gerektiğini yazdık. İstediğiniz zaman ayarlardan değiştirebilirsiniz.',
      'openSettings': 'Ayarları aç',
      'openVideo': 'Görüntüyü aç',
      'pageOf': 'Sayfa {n} / {total}',
      'parentConnected': 'Ebeveyn bağlı',
      'parentWaiting': 'Ebeveyn bekleniyor',
      'permCamera': 'Kamera',
      'permCameraWhy': 'Bebeği görebilmeniz için',
      'permMic': 'Mikrofon',
      'permMicWhy': 'Ağlamayı duymak ve konuşmak için',
      'permNotifications': 'Bildirimler',
      'permNotificationsWhy': 'Ağlama alarmı için',
      'permNearby': 'Yakındaki cihazlar',
      'permNearbyWhy': 'İnternetsiz mod için (isteğe bağlı)',
      'privacyNote': 'Görüntü ve ses iki telefon arasında şifreli olarak gider. Sunucularımızda saklanmaz.',
      'quality': 'Kalite',
      'qualitySaver': 'Tasarruf',
      'qualityBalanced': 'Dengeli',
      'qualitySharp': 'Net',
      'record': 'Kaydet',
      'stopRecordingShort': 'Durdur',
      'replayIntro': 'Tanıtımı tekrar göster',
      'roleTitle': 'Bu telefon nerede duracak?',
      'roleSubtitle': 'İki telefonu eşleştirin: biri bebeğin yanında, diğeri sizde.',
      'roleBabyTitle': 'Bebeğin yanında',
      'roleBabyBody': 'Bu telefon kamera ve mikrofon olur. Ağlamayı algılar, size haber verir.',
      'roleParentTitle': 'Benim yanımda',
      'roleParentBody': 'Bebeği canlı izleyin, ağladığında anında bildirim alın.',
      'roomShort': 'Oda',
      'searchNearby': 'Yakındaki cihazı ara',
      'searching': 'Bebek telefonu aranıyor…',
      'sectionAbout': 'Hakkında',
      'sectionAlarm': 'Alarm',
      'sectionApp': 'Uygulama',
      'sectionVideo': 'Görüntü',
      'sensitivity': 'Hassasiyet',
      'shareCodeText': 'Ninni oda kodu: {code}',
      'shortNoise': 'Kısa gürültü',
      'skip': 'Geç',
      'snooze5': '5 dk sessize al',
      'soundLevel': 'Ses seviyesi',
      'switchCamera': 'Kamerayı çevir',
      'switchShort': 'Çevir',
      'themeAuto': 'Otomatik',
      'themeLight': 'Açık',
      'themeDark': 'Koyu',
      'thresholdValue': 'Eşik {db} dB',
      'tonight': 'Bu gece',
      'totalCryLabel': 'toplam ağlama',
      'waitingForParent': 'Ebeveyn telefonu bekleniyor',
    },
  };

  String get settings => _localizedValues[locale.languageCode]!['settings']!;
  String get theme => _localizedValues[locale.languageCode]!['theme']!;
  String get systemDefault => _localizedValues[locale.languageCode]!['systemDefault']!;
  String get lightMode => _localizedValues[locale.languageCode]!['lightMode']!;
  String get darkMode => _localizedValues[locale.languageCode]!['darkMode']!;
  String get language => _localizedValues[locale.languageCode]!['language']!;
  String get offlineMode => _localizedValues[locale.languageCode]!['offlineMode']!;
  String get offlineModeSubtitle => _localizedValues[locale.languageCode]!['offlineModeSubtitle']!;
  String get noiseThreshold => _localizedValues[locale.languageCode]!['noiseThreshold']!;
  String get moreSensitive => _localizedValues[locale.languageCode]!['moreSensitive']!;
  String get lessSensitive => _localizedValues[locale.languageCode]!['lessSensitive']!;
  String get keepScreenOn => _localizedValues[locale.languageCode]!['keepScreenOn']!;
  String get keepScreenOnSubtitle => _localizedValues[locale.languageCode]!['keepScreenOnSubtitle']!;
  String get videoSettings => _localizedValues[locale.languageCode]!['videoSettings']!;
  String get resolution => _localizedValues[locale.languageCode]!['resolution']!;
  String get frameRate => _localizedValues[locale.languageCode]!['frameRate']!;
  String get bitrate => _localizedValues[locale.languageCode]!['bitrate']!;
  String get low => _localizedValues[locale.languageCode]!['low']!;
  String get medium => _localizedValues[locale.languageCode]!['medium']!;
  String get high => _localizedValues[locale.languageCode]!['high']!;
  String get appTitle => _localizedValues[locale.languageCode]!['appTitle']!;
  String get ok => _localizedValues[locale.languageCode]!['ok']!;
  String get cancel => _localizedValues[locale.languageCode]!['cancel']!;
  String get error => _localizedValues[locale.languageCode]!['error']!;
  String get loading => _localizedValues[locale.languageCode]!['loading']!;
  String get babyMode => _localizedValues[locale.languageCode]!['babyMode']!;
  String get parentMode => _localizedValues[locale.languageCode]!['parentMode']!;
  String get multiCameraMode => _localizedValues[locale.languageCode]!['multiCameraMode']!;
  String get createRoomCode => _localizedValues[locale.languageCode]!['createRoomCode']!;
  String get startBroadcastOffline => _localizedValues[locale.languageCode]!['startBroadcastOffline']!;
  String get enterRoomCode => _localizedValues[locale.languageCode]!['enterRoomCode']!;
  String get searchDeviceOffline => _localizedValues[locale.languageCode]!['searchDeviceOffline']!;
  String get camerasReadError => _localizedValues[locale.languageCode]!['camerasReadError']!;
  String get noCameraFound => _localizedValues[locale.languageCode]!['noCameraFound']!;
  String get cameraInitError => _localizedValues[locale.languageCode]!['cameraInitError']!;
  String get firebaseConfigMissing => _localizedValues[locale.languageCode]!['firebaseConfigMissing']!;
  String get pairingInitError => _localizedValues[locale.languageCode]!['pairingInitError']!;
  String get roomCreationErrorFirebase => _localizedValues[locale.languageCode]!['roomCreationErrorFirebase']!;
  String get roomCode => _localizedValues[locale.languageCode]!['roomCode']!;
  String get copy => _localizedValues[locale.languageCode]!['copy']!;
  String get share => _localizedValues[locale.languageCode]!['share']!;
  String get waitingForConnection => _localizedValues[locale.languageCode]!['waitingForConnection']!;
  String get connected => _localizedValues[locale.languageCode]!['connected']!;
  String get disconnected => _localizedValues[locale.languageCode]!['disconnected']!;
  String get roomCodeCopied => _localizedValues[locale.languageCode]!['roomCodeCopied']!;
  String get enterRoomCodeTitle => _localizedValues[locale.languageCode]!['enterRoomCodeTitle']!;
  String get enterRoomCodeSubtitle => _localizedValues[locale.languageCode]!['enterRoomCodeSubtitle']!;
  String get connect => _localizedValues[locale.languageCode]!['connect']!;
  String get invalidRoomCode => _localizedValues[locale.languageCode]!['invalidRoomCode']!;
  String get roomNotFound => _localizedValues[locale.languageCode]!['roomNotFound']!;
  String get roomFull => _localizedValues[locale.languageCode]!['roomFull']!;
  String get babyCrying => _localizedValues[locale.languageCode]!['babyCrying']!;
  String get noiseDetected => _localizedValues[locale.languageCode]!['noiseDetected']!;
  String get lowBattery => _localizedValues[locale.languageCode]!['lowBattery']!;
  String get babyDeviceLowBattery => _localizedValues[locale.languageCode]!['babyDeviceLowBattery']!;
  String get alertHistory => _localizedValues[locale.languageCode]!['alertHistory']!;
  String get today => _localizedValues[locale.languageCode]!['today']!;
  String get yesterday => _localizedValues[locale.languageCode]!['yesterday']!;
  String get noRecordsFound => _localizedValues[locale.languageCode]!['noRecordsFound']!;
  String get pickDate => _localizedValues[locale.languageCode]!['pickDate']!;
  String get startTime => _localizedValues[locale.languageCode]!['startTime']!;
  String get endTime => _localizedValues[locale.languageCode]!['endTime']!;
  String get filter => _localizedValues[locale.languageCode]!['filter']!;
  String get clear => _localizedValues[locale.languageCode]!['clear']!;
  String get videoGallery => _localizedValues[locale.languageCode]!['videoGallery']!;
  String get recordings => _localizedValues[locale.languageCode]!['recordings']!;
  String get recordingDeleted => _localizedValues[locale.languageCode]!['recordingDeleted']!;
  String get delete => _localizedValues[locale.languageCode]!['delete']!;
  String get play => _localizedValues[locale.languageCode]!['play']!;
  String get noiseLevel => _localizedValues[locale.languageCode]!['noiseLevel']!;
  String get cameraPreview => _localizedValues[locale.languageCode]!['cameraPreview']!;
  String get stop => _localizedValues[locale.languageCode]!['stop']!;
  String get start => _localizedValues[locale.languageCode]!['start']!;
  String get retry => _localizedValues[locale.languageCode]!['retry']!;
  String get permissionDenied => _localizedValues[locale.languageCode]!['permissionDenied']!;
  String get microphonePermissionRequired => _localizedValues[locale.languageCode]!['microphonePermissionRequired']!;
  String get cameraPermissionRequired => _localizedValues[locale.languageCode]!['cameraPermissionRequired']!;
  String get storagePermissionRequired => _localizedValues[locale.languageCode]!['storagePermissionRequired']!;
  String get locationPermissionRequired => _localizedValues[locale.languageCode]!['locationPermissionRequired']!;
  String get nearbyDevicesPermissionRequired => _localizedValues[locale.languageCode]!['nearbyDevicesPermissionRequired']!;
  String get notificationsPermissionRequired => _localizedValues[locale.languageCode]!['notificationsPermissionRequired']!;
  String get batteryOptimization => _localizedValues[locale.languageCode]!['batteryOptimization']!;
  String get ignoreBatteryOptimizations => _localizedValues[locale.languageCode]!['ignoreBatteryOptimizations']!;
  String get yes => _localizedValues[locale.languageCode]!['yes']!;
  String get no => _localizedValues[locale.languageCode]!['no']!;
  String get confirmDelete => _localizedValues[locale.languageCode]!['confirmDelete']!;
  String get shareVideo => _localizedValues[locale.languageCode]!['shareVideo']!;
  String get videoPlayer => _localizedValues[locale.languageCode]!['videoPlayer']!;
  String get onlineMode => _localizedValues[locale.languageCode]!['onlineMode']!;
  String get findBroadcast => _localizedValues[locale.languageCode]!['findBroadcast']!;
  String get joinRoom => _localizedValues[locale.languageCode]!['joinRoom']!;
  String get stopRecording => _localizedValues[locale.languageCode]!['stopRecording']!;
  String get startRecording => _localizedValues[locale.languageCode]!['startRecording']!;
  String get disconnect => _localizedValues[locale.languageCode]!['disconnect']!;
  String get startCamera => _localizedValues[locale.languageCode]!['startCamera']!;
  String get stopCamera => _localizedValues[locale.languageCode]!['stopCamera']!;
  String get createRoom => _localizedValues[locale.languageCode]!['createRoom']!;
  String get startBroadcast => _localizedValues[locale.languageCode]!['startBroadcast']!;
  String get charging => _localizedValues[locale.languageCode]!['charging']!;
  String get babyDeviceBattery => _localizedValues[locale.languageCode]!['babyDeviceBattery']!;
  String get wifi => _localizedValues[locale.languageCode]!['wifi']!;
  String get network => _localizedValues[locale.languageCode]!['network']!;
  String get temperature => _localizedValues[locale.languageCode]!['temperature']!;
  String get clearHistory => _localizedValues[locale.languageCode]!['clearHistory']!;
  String get clearHistoryConfirmation => _localizedValues[locale.languageCode]!['clearHistoryConfirmation']!;
  String get dateAll => _localizedValues[locale.languageCode]!['dateAll']!;
  String get date => _localizedValues[locale.languageCode]!['date']!;
  String get pick => _localizedValues[locale.languageCode]!['pick']!;
  String get change => _localizedValues[locale.languageCode]!['change']!;
  String get timeRangeAll => _localizedValues[locale.languageCode]!['timeRangeAll']!;
  String get end => _localizedValues[locale.languageCode]!['end']!;
  String get noAlertsYet => _localizedValues[locale.languageCode]!['noAlertsYet']!;
  String get motionOrSoundDetected => _localizedValues[locale.languageCode]!['motionOrSoundDetected']!;
  String get videoPlaybackHint => _localizedValues[locale.languageCode]!['videoPlaybackHint']!;
  String get gifAnimation => _localizedValues[locale.languageCode]!['gifAnimation']!;
  String get videoRecording => _localizedValues[locale.languageCode]!['videoRecording']!;
  String get videoFileNotFound => _localizedValues[locale.languageCode]!['videoFileNotFound']!;
  String get videoFileEmpty => _localizedValues[locale.languageCode]!['videoFileEmpty']!;
  String get videoInitTimeout => _localizedValues[locale.languageCode]!['videoInitTimeout']!;
  String get videoPlaybackError => _localizedValues[locale.languageCode]!['videoPlaybackError']!;
  String get addCamera => _localizedValues[locale.languageCode]!['addCamera']!;
  String get enterRoomId => _localizedValues[locale.languageCode]!['enterRoomId']!;
  String get add => _localizedValues[locale.languageCode]!['add']!;
  String get multiCameraMonitoring => _localizedValues[locale.languageCode]!['multiCameraMonitoring']!;
  String get noCameraAdded => _localizedValues[locale.languageCode]!['noCameraAdded']!;
  String get baby => _localizedValues[locale.languageCode]!['baby']!;
  String get room => _localizedValues[locale.languageCode]!['room']!;
  String get status => _localizedValues[locale.languageCode]!['status']!;
  String get cameraInitializing => _localizedValues[locale.languageCode]!['cameraInitializing']!;
  String get previewNotReady => _localizedValues[locale.languageCode]!['previewNotReady']!;
  String get openAppSettings => _localizedValues[locale.languageCode]!['openAppSettings']!;
  String get cameraNotReady => _localizedValues[locale.languageCode]!['cameraNotReady']!;
  String get babyCryAlert => _localizedValues[locale.languageCode]!['babyCryAlert']!;
  String get babyMightBeCrying => _localizedValues[locale.languageCode]!['babyMightBeCrying']!;
  String get passive => _localizedValues[locale.languageCode]!['passive']!;
  String get threshold => _localizedValues[locale.languageCode]!['threshold']!;
  String get highNoise => _localizedValues[locale.languageCode]!['highNoise']!;
  String get cameraPaused => _localizedValues[locale.languageCode]!['cameraPaused']!;
  String get cameraOn => _localizedValues[locale.languageCode]!['cameraOn']!;
  String get cameraOff => _localizedValues[locale.languageCode]!['cameraOff']!;
  String get audioMonitoringOn => _localizedValues[locale.languageCode]!['audioMonitoringOn']!;
  String get audioMonitoringOff => _localizedValues[locale.languageCode]!['audioMonitoringOff']!;
  String get connectionStatus => _localizedValues[locale.languageCode]!['connectionStatus']!;
  String get videoSettingsUpdated => _localizedValues[locale.languageCode]!['videoSettingsUpdated']!;
  String get unknownDevice => _localizedValues[locale.languageCode]!['unknownDevice']!;
  String get addFirstCameraHint => _localizedValues[locale.languageCode]!['addFirstCameraHint']!;
  String get offlineAndroidOnly => _localizedValues[locale.languageCode]!['offlineAndroidOnly']!;
  String get offlineRecordingInfo => _localizedValues[locale.languageCode]!['offlineRecordingInfo']!;
  String get offlineRecordingLimitReached => _localizedValues[locale.languageCode]!['offlineRecordingLimitReached']!;
  String get nightModeExitHint => _localizedValues[locale.languageCode]!['nightModeExitHint']!;
  String get nightModeAction => _localizedValues[locale.languageCode]!['nightModeAction']!;
  String get iosCameraForegroundHint => _localizedValues[locale.languageCode]!['iosCameraForegroundHint']!;
  String get nightModeKeepAppOpen => _localizedValues[locale.languageCode]!['nightModeKeepAppOpen']!;
  String get autoNightMode => _localizedValues[locale.languageCode]!['autoNightMode']!;
  String get autoNightModeSubtitle => _localizedValues[locale.languageCode]!['autoNightModeSubtitle']!;
  String get roomClosed => _localizedValues[locale.languageCode]!['roomClosed']!;
  String get roomUnavailable => _localizedValues[locale.languageCode]!['roomUnavailable']!;
  String get anonymousAuthDisabled => _localizedValues[locale.languageCode]!['anonymousAuthDisabled']!;
  String get roomCodeValidHint => _localizedValues[locale.languageCode]!['roomCodeValidHint']!;
  String get noServerResponse => _localizedValues[locale.languageCode]!['noServerResponse']!;

  String _t(String key) =>
      _localizedValues[locale.languageCode]?[key] ?? _localizedValues['en']![key]!;
  String get backgroundListening => _t('backgroundListening');
  String get backgroundListeningSubtitle => _t('backgroundListeningSubtitle');
  String get serviceBabyTitle => _t('serviceBabyTitle');
  String get serviceBabyText => _t('serviceBabyText');
  String get serviceParentTitle => _t('serviceParentTitle');
  String get serviceParentText => _t('serviceParentText');
  String get connectionLostTitle => _t('connectionLostTitle');
  String get connectionLostBody => _t('connectionLostBody');
  String get reconnecting => _t('reconnecting');
  String get tryAgain => _t('tryAgain');
  String get silenceAlarm => _t('silenceAlarm');
  String get checkBabyPhone => _t('checkBabyPhone');
  String get checkWifi => _t('checkWifi');
  String get checkAppOpen => _t('checkAppOpen');
  String get checkCharger => _t('checkCharger');
  String get batteryLowTitle => _t('batteryLowTitle');
  String get batteryLowBody => _t('batteryLowBody');
  String get dismiss => _t('dismiss');
  String get connectionLostNotification => _t('connectionLostNotification');
  String get alarmAfter2s => _t('alarmAfter2s');
  String get alarmDuration => _t('alarmDuration');
  String get alarmDurationSub => _t('alarmDurationSub');
  String get alarmsLabel => _t('alarmsLabel');
  String get allow => _t('allow');
  String get androidOnly => _t('androidOnly');
  String get appTagline => _t('appTagline');
  String get autoNightModeShort => _t('autoNightModeShort');
  String get babyCalm => _t('babyCalm');
  String get babyCryingShort => _t('babyCryingShort');
  String get babyStirring => _t('babyStirring');
  String get babyDevice => _t('babyDevice');
  String get babyDeviceBatteryShort => _t('babyDeviceBatteryShort');
  String get babyPairingTitle => _t('babyPairingTitle');
  String get babyPairingSubtitle => _t('babyPairingSubtitle');
  String get babyPlacementHint => _t('babyPlacementHint');
  String get iosKeepOpenHint => _t('iosKeepOpenHint');
  String get babyShort => _t('babyShort');
  String get youShort => _t('youShort');
  String get back => _t('back');
  String get batteryCharging => _t('batteryCharging');
  String get batteryPercent => _t('batteryPercent');
  String get cameraMicReady => _t('cameraMicReady');
  String get cameraPreparing => _t('cameraPreparing');
  String get clearHistoryTitle => _t('clearHistoryTitle');
  String get clearHistoryBody => _t('clearHistoryBody');
  String get close => _t('close');
  String get codeExpired => _t('codeExpired');
  String get codeValidFor => _t('codeValidFor');
  String get connecting => _t('connecting');
  String get continueLabel => _t('continueLabel');
  String get copied => _t('copied');
  String get cry => _t('cry');
  String get cryStopped => _t('cryStopped');
  String get cryingForSeconds => _t('cryingForSeconds');
  String get defaultRoomName => _t('defaultRoomName');
  String get disconnectTitle => _t('disconnectTitle');
  String get disconnectBody => _t('disconnectBody');
  String get endBroadcast => _t('endBroadcast');
  String get endBroadcastTitle => _t('endBroadcastTitle');
  String get endBroadcastBody => _t('endBroadcastBody');
  String get enterNightMode => _t('enterNightMode');
  String get fullscreen => _t('fullscreen');
  String get granted => _t('granted');
  String get history => _t('history');
  String get hoursShort => _t('hoursShort');
  String get hoursMinutesShort => _t('hoursMinutesShort');
  String get minutesShort => _t('minutesShort');
  String get minutesSecondsShort => _t('minutesSecondsShort');
  String get secondsShort => _t('secondsShort');
  String get imReady => _t('imReady');
  String get joinTitle => _t('joinTitle');
  String get joinSubtitle => _t('joinSubtitle');
  String get last7Days => _t('last7Days');
  String get lastAlarmAt => _t('lastAlarmAt');
  String get later => _t('later');
  String get letsStart => _t('letsStart');
  String get levelActive => _t('levelActive');
  String get levelLoud => _t('levelLoud');
  String get levelOff => _t('levelOff');
  String get levelQuiet => _t('levelQuiet');
  String get licenses => _t('licenses');
  String get linkGood => _t('linkGood');
  String get live => _t('live');
  String get liveView => _t('liveView');
  String get longestQuietLabel => _t('longestQuietLabel');
  String get newCode => _t('newCode');
  String get nightExitHint => _t('nightExitHint');
  String get nightStatusConnected => _t('nightStatusConnected');
  String get nightStatusWaiting => _t('nightStatusWaiting');
  String get noAlertsInRange => _t('noAlertsInRange');
  String get noInternet => _t('noInternet');
  String get notifyInterval => _t('notifyInterval');
  String get notifyIntervalSub => _t('notifyIntervalSub');
  String get perMinute => _t('perMinute');
  String get now => _t('now');
  String get offlineBabyTitle => _t('offlineBabyTitle');
  String get offlineBabyBody => _t('offlineBabyBody');
  String get offlineModeShort => _t('offlineModeShort');
  String get offlineParentTitle => _t('offlineParentTitle');
  String get offlineParentBody => _t('offlineParentBody');
  String get onboardTitle1 => _t('onboardTitle1');
  String get onboardBody1 => _t('onboardBody1');
  String get onboardTitle2 => _t('onboardTitle2');
  String get onboardStep1Title => _t('onboardStep1Title');
  String get onboardStep1Body => _t('onboardStep1Body');
  String get onboardStep2Title => _t('onboardStep2Title');
  String get onboardStep2Body => _t('onboardStep2Body');
  String get onboardStep3Title => _t('onboardStep3Title');
  String get onboardStep3Body => _t('onboardStep3Body');
  String get onboardTitle3 => _t('onboardTitle3');
  String get onboardBody3 => _t('onboardBody3');
  String get openSettings => _t('openSettings');
  String get openVideo => _t('openVideo');
  String get pageOf => _t('pageOf');
  String get parentConnected => _t('parentConnected');
  String get parentWaiting => _t('parentWaiting');
  String get permCamera => _t('permCamera');
  String get permCameraWhy => _t('permCameraWhy');
  String get permMic => _t('permMic');
  String get permMicWhy => _t('permMicWhy');
  String get permNotifications => _t('permNotifications');
  String get permNotificationsWhy => _t('permNotificationsWhy');
  String get permNearby => _t('permNearby');
  String get permNearbyWhy => _t('permNearbyWhy');
  String get privacyNote => _t('privacyNote');
  String get quality => _t('quality');
  String get qualitySaver => _t('qualitySaver');
  String get qualityBalanced => _t('qualityBalanced');
  String get qualitySharp => _t('qualitySharp');
  String get record => _t('record');
  String get stopRecordingShort => _t('stopRecordingShort');
  String get replayIntro => _t('replayIntro');
  String get roleTitle => _t('roleTitle');
  String get roleSubtitle => _t('roleSubtitle');
  String get roleBabyTitle => _t('roleBabyTitle');
  String get roleBabyBody => _t('roleBabyBody');
  String get roleParentTitle => _t('roleParentTitle');
  String get roleParentBody => _t('roleParentBody');
  String get roomShort => _t('roomShort');
  String get searchNearby => _t('searchNearby');
  String get searching => _t('searching');
  String get sectionAbout => _t('sectionAbout');
  String get sectionAlarm => _t('sectionAlarm');
  String get sectionApp => _t('sectionApp');
  String get sectionVideo => _t('sectionVideo');
  String get sensitivity => _t('sensitivity');
  String get shareCodeText => _t('shareCodeText');
  String get shortNoise => _t('shortNoise');
  String get skip => _t('skip');
  String get snooze5 => _t('snooze5');
  String get soundLevel => _t('soundLevel');
  String get switchCamera => _t('switchCamera');
  String get switchShort => _t('switchShort');
  String get themeAuto => _t('themeAuto');
  String get themeLight => _t('themeLight');
  String get themeDark => _t('themeDark');
  String get thresholdValue => _t('thresholdValue');
  String get tonight => _t('tonight');
  String get totalCryLabel => _t('totalCryLabel');
  String get waitingForParent => _t('waitingForParent');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
