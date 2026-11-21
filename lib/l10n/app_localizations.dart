import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
      'offlineMode': 'Offline Mode (Wi-Fi Direct)',
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
      'alertHistory': 'Alert History',
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
      'locationPermissionRequired': 'Location permission is required for Wi-Fi Direct',
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
    },
    'tr': {
      'settings': 'Ayarlar',
      'theme': 'Tema',
      'systemDefault': 'Sistem Varsayılanı',
      'lightMode': 'Açık Mod',
      'darkMode': 'Koyu Mod',
      'language': 'Dil',
      'offlineMode': 'Offline Mod (Wi-Fi Direct)',
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
      'alertHistory': 'Alarm Geçmişi',
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
      'locationPermissionRequired': 'Wi-Fi Direct için konum izni gerekli',
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
      'disconnect': 'Bağlantıyı Kes',
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
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'tr'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
