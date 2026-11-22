import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [Locale('tr'), Locale('en'), Locale('az')];

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
      'recordingSaved': 'Recording saved to the gallery',
      'recordingNoPicture': 'No picture arrived, so nothing was recorded',
      'babyPairingSubtitleQr': 'Or scan the QR code with the other phone\'s camera.',
      'qrSemantic': 'QR code of the room',
      'roomNameTitle': 'Room name',
      'save': 'Save',
      'scanQr': 'Scan QR code',
      'qrScanHint': 'Point the camera at the QR code on the baby phone.',
      'qrNotNinni': 'This is not a Ninni room code. Try the QR on the baby phone.',
      'qrNoCameraPermission': 'Ninni has no camera permission. Allow it in the settings, or type the code.',
      'qrCameraUnavailable': 'The camera cannot be opened. Type the code instead.',
      'recentRoom': 'Last connected',
      'reconnect': 'Reconnect',
      'yesterdayLower': 'yesterday',
      'holdToTalk': 'Hold to talk to the baby',
      'holdToTalkHint': 'Your voice plays on the baby phone while you hold',
      'talkingNow': 'Talking… release to stop',
      'talkNeedsMic': 'Talking to the baby needs microphone permission',
      'lullabyShort': 'Lullaby',
      'lullabyTitle': 'Soothe the baby',
      'sootheWhite': 'White noise',
      'sootheWhiteSub': 'Soft and steady',
      'sootheRain': 'Rain',
      'sootheRainSub': 'Nature sound',
      'sootheHeart': 'Heartbeat',
      'sootheHeartSub': 'Womb sound',
      'sootheDandini': 'Dandini dandini',
      'sootheDandiniSub': 'Traditional lullaby',
      'playingNow': 'Playing',
      'volumeOnBaby': 'Volume (on the baby phone)',
      'continuous': 'Always',
      'nightLight': 'Night light',
      'nightLightSub': 'The baby phone\'s screen glows softly',
      'lightColor': 'Light color',
      'colorAmber': 'Amber',
      'colorPink': 'Pink',
      'colorPurple': 'Purple',
      'colorBlue': 'Blue',
      'languageAz': 'Azərbaycanca',
      'errNoInternet': 'No internet connection. Check Wi-Fi or mobile data.',
      'errSignIn': 'Could not sign in. Try again in a moment.',
      'errPermission': 'A required permission is missing. Allow camera and microphone in Settings.',
      'errCamera': 'The camera could not be opened. Close and reopen the app.',
      'errNotConfigured': 'Online connection is not available in this build.',
      'errUnknown': 'Something went wrong. Try again.',
      'offlineBannerTitle': 'No internet',
      'offlineBannerBody': 'We will try again as soon as you are back online.',
      'offlineBannerAndroid': 'To monitor without internet, use Offline mode on two Android phones.',
      'backOnline': 'Back online',
      'talkFailed': 'The microphone could not be opened. Try again.',
      'talkBabyHears': 'Your baby can hear you',
      'talkStarting': 'Opening the microphone',
      'talkNotReaching': 'Your voice is not reaching the baby',
      'micTestTitle': 'Test the microphone',
      'micTestSubtitle': 'See the room\'s sound, set the threshold',
      'micTestOwn': 'This phone\'s microphone',
      'micTestInCall': 'Broadcast microphone (what cry detection measures)',
      'micTestFromBaby': 'Sound from the baby phone',
      'micTestOver': 'Above threshold',
      'micTestUnder': 'Below threshold',
      'micTestPeak': 'Loudest in 10 s',
      'micTestNoMic': 'The microphone could not be opened. Check the microphone permission.',
      'micTestHint': 'Make a sound close to your baby\'s cry (speak loudly or play a cry recording). If the bar stays past the marker for 2 seconds, the alarm goes off. Raise the threshold in a noisy room.',
      'thresholdShort': 'Threshold',
      'diagTitle': 'Diagnostics',
      'diagCopy': 'Copy',
      'diagCopied': 'Copied',
      'diagHint': 'Live values for finding real-device bugs. The same values are logged once a second as CRYDIAG / TALKDIAG lines.',
      'version': 'Version',
      'greetMorning': 'Good morning',
      'greetDay': 'Good afternoon',
      'greetEvening': 'Good evening',
      'greetNight': 'Good night',
      'homeWatchTitle': 'Watch the baby room',
      'homeWatchLast': 'Last connected · {when}',
      'homeBabyTitle': 'Baby phone',
      'homeBabyBody': 'Becomes the camera and microphone',
      'homeNewTitle': 'New room',
      'homeNewBody': 'Connect with a QR or code',
      'tipLabel': 'Tip:',
      'tip1': 'Plug the baby phone in and turn on night mode. The phone stays cooler and the screen light will not disturb your baby.',
      'tip2': 'Place the baby phone at least 1 metre from the crib, where it can see your baby.',
      'tip3': 'Alarm too often or never? Set the threshold for your room in Settings → Test the microphone.',
      'tip4': 'Keep "Listen in the background" on in Settings to hear your baby with the screen locked.',
      'tip5': 'Hold the middle button to talk; your voice plays from the baby phone\'s speaker.',
      'tip6Android': 'No internet? Two Android phones can use Offline mode.',
      'tip6Ios': 'Scan the QR code on the parent phone to connect in seconds.',
      'onAirFor': 'On air · {time}',
      'watchingFor': 'Watching for {time}',
      'durationHm': '{h} h {m} min',
      'durationM': '{m} min',
      'linkShortOk': 'Connected',
      'linkShortWait': 'Waiting',
      'cameraBack': 'Back camera',
      'cameraFront': 'Front camera',
      'lastHour': 'Last hour',
      'alarmsAt': '{n} alarms · {time}',
      'noAlarmsShort': 'No alarms',
      'boxParent': 'Parent',
      'boxParentOn': 'Watching',
      'boxParentOff': 'Waiting',
      'boxLullaby': 'Lullaby',
      'boxLight': 'Light',
      'stateOff': 'Off',
      'babyRestless': 'Baby is restless',
      'tonightAlarms': '{n} alarms tonight',
      'tonightNone': 'No alarms tonight',
      'lastShort': 'last {time}',
      'historyLink': 'History ›',
      'talkShort': 'Hold to talk',
      'lightOn': 'Light on',
      'lightOff': 'Light off',
      'qualityGood': 'Good',
      'qualityFair': 'Fair',
      'qualityPoor': 'Weak',
      'connectionQualityLabel': 'Connection quality: {q}',
      'babyBatteryLabel': 'Baby phone battery {level}%',
      'moreActions': 'More actions',
      'calmNight': 'A calm night!',
      'calmNightBody': 'No cry alarms in this period.',
      'byHour': 'Alarms by hour',
      'roomCardDevices': 'Connected device: {device}',
      'roomCardNone': 'No device connected yet',
      'deviceParentPhone': 'parent phone',
      'deviceBabyPhone': 'baby phone',
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
      'recordingSaved': 'Kayıt galeriye kaydedildi',
      'recordingNoPicture': 'Görüntü gelmediği için kayıt yapılamadı',
      'babyPairingSubtitleQr': 'Ya da diğer telefonun kamerasıyla QR kodu okutun.',
      'qrSemantic': 'Odanın QR kodu',
      'roomNameTitle': 'Oda adı',
      'save': 'Kaydet',
      'scanQr': 'QR kodu okut',
      'qrScanHint': 'Kamerayı bebek telefonundaki QR koda tutun.',
      'qrNotNinni': 'Bu bir Ninni oda kodu değil. Bebek telefonundaki QR\'ı deneyin.',
      'qrNoCameraPermission': 'Ninni\'nin kamera izni yok. Ayarlardan izin verin ya da kodu elle girin.',
      'qrCameraUnavailable': 'Kamera açılamadı. Kodu elle girin.',
      'recentRoom': 'Son bağlandığınız',
      'reconnect': 'Tekrar bağlan',
      'yesterdayLower': 'dün',
      'holdToTalk': 'Basılı tutun, bebeğe konuşun',
      'holdToTalkHint': 'Basılı tuttukça sesiniz bebek telefonunda çalar',
      'talkingNow': 'Konuşuyorsunuz… bırakınca durur',
      'talkNeedsMic': 'Bebeğe konuşmak için mikrofon izni gerekiyor',
      'lullabyShort': 'Ninni',
      'lullabyTitle': 'Bebeği sakinleştir',
      'sootheWhite': 'Beyaz gürültü',
      'sootheWhiteSub': 'Yumuşak ve sabit',
      'sootheRain': 'Yağmur',
      'sootheRainSub': 'Doğa sesi',
      'sootheHeart': 'Kalp atışı',
      'sootheHeartSub': 'Rahim sesi',
      'sootheDandini': 'Dandini dandini',
      'sootheDandiniSub': 'Geleneksel ninni',
      'playingNow': 'Çalıyor',
      'volumeOnBaby': 'Ses düzeyi (bebek telefonunda)',
      'continuous': 'Sürekli',
      'nightLight': 'Gece lambası',
      'nightLightSub': 'Bebek telefonunun ekranı yumuşak ışık verir',
      'lightColor': 'Işık rengi',
      'colorAmber': 'Kehribar',
      'colorPink': 'Pembe',
      'colorPurple': 'Mor',
      'colorBlue': 'Mavi',
      'languageAz': 'Azərbaycanca',
      'errNoInternet': 'İnternet bağlantısı yok. Wi-Fi veya mobil veriyi kontrol edin.',
      'errSignIn': 'Giriş yapılamadı. Biraz sonra tekrar deneyin.',
      'errPermission': 'Gerekli izin verilmedi. Ayarlardan kamera ve mikrofon iznini açın.',
      'errCamera': 'Kamera açılamadı. Uygulamayı kapatıp yeniden açın.',
      'errNotConfigured': 'Bu sürümde çevrim içi bağlantı kullanılamıyor.',
      'errUnknown': 'Bir şeyler ters gitti. Tekrar deneyin.',
      'offlineBannerTitle': 'İnternet yok',
      'offlineBannerBody': 'Bağlantı gelince otomatik yeniden denenecek.',
      'offlineBannerAndroid': 'İnternetsiz izlemek için iki Android telefonda İnternetsiz modu kullanın.',
      'backOnline': 'İnternet geri geldi',
      'talkFailed': 'Mikrofon açılamadı. Tekrar deneyin.',
      'talkBabyHears': 'Bebek sizi duyuyor',
      'talkStarting': 'Mikrofon açılıyor',
      'talkNotReaching': 'Ses bebeğe ulaşmıyor',
      'micTestTitle': 'Mikrofonu test et',
      'micTestSubtitle': 'Odadaki sesi görün, eşiği ayarlayın',
      'micTestOwn': 'Bu telefonun mikrofonu',
      'micTestInCall': 'Yayındaki mikrofon (ağlama algılamanın ölçtüğü)',
      'micTestFromBaby': 'Bebek telefonundan gelen ses',
      'micTestOver': 'Eşik aşıldı',
      'micTestUnder': 'Eşiğin altında',
      'micTestPeak': 'Son 10 sn en yüksek',
      'micTestNoMic': 'Mikrofon açılamadı. Mikrofon iznini kontrol edin.',
      'micTestHint': 'Bebeğin ağlamasına yakın bir ses çıkarın (yüksek sesle konuşun ya da bir ağlama kaydı çalın). Çubuk kesikli çizgiyi 2 saniye aşarsa alarm çalar. Odanız gürültülüyse eşiği yükseltin.',
      'thresholdShort': 'Eşik',
      'diagTitle': 'Tanı',
      'diagCopy': 'Kopyala',
      'diagCopied': 'Kopyalandı',
      'diagHint': 'Gerçek cihaz hatalarını bulmak için canlı değerler. Aynı bilgiler saniyede bir CRYDIAG / TALKDIAG satırı olarak loga yazılır.',
      'version': 'Sürüm',
      'greetMorning': 'Günaydın',
      'greetDay': 'İyi günler',
      'greetEvening': 'İyi akşamlar',
      'greetNight': 'İyi geceler',
      'homeWatchTitle': 'Bebek odasını izle',
      'homeWatchLast': 'Son bağlantı · {when}',
      'homeBabyTitle': 'Bebek telefonu',
      'homeBabyBody': 'Kamera ve mikrofon olur',
      'homeNewTitle': 'Yeni oda',
      'homeNewBody': 'QR ya da kodla bağlan',
      'tipLabel': 'İpucu:',
      'tip1': 'Bebek telefonunu şarja takın ve gece modunu açın. Telefon daha az ısınır, ekran ışığı bebeği rahatsız etmez.',
      'tip2': 'Bebek telefonunu beşikten en az 1 metre uzağa, bebeği gören bir yere koyun.',
      'tip3': 'Alarm çok sık ya da hiç çalmıyorsa Ayarlar → Mikrofonu test et ile eşiği odanıza göre ayarlayın.',
      'tip4': 'Ekran kilitliyken de dinlemek için Ayarlar\'da "Arka planda dinle" açık kalsın.',
      'tip5': 'Bebeğe konuşmak için ortadaki düğmeyi basılı tutun; sesiniz bebek telefonunun hoparlöründen çıkar.',
      'tip6Android': 'İnternet yoksa iki Android telefonla İnternetsiz modu kullanabilirsiniz.',
      'tip6Ios': 'Ebeveyn telefonunda QR kodu okutarak saniyeler içinde bağlanın.',
      'onAirFor': 'Yayında · {time}',
      'watchingFor': '{time}\'dır izleniyor',
      'durationHm': '{h} sa {m} dk',
      'durationM': '{m} dk',
      'linkShortOk': 'Bağlı',
      'linkShortWait': 'Bekliyor',
      'cameraBack': 'Arka kamera',
      'cameraFront': 'Ön kamera',
      'lastHour': 'Son 1 saat',
      'alarmsAt': '{n} alarm · {time}',
      'noAlarmsShort': 'Alarm yok',
      'boxParent': 'Ebeveyn',
      'boxParentOn': 'İzliyor',
      'boxParentOff': 'Bekleniyor',
      'boxLullaby': 'Ninni',
      'boxLight': 'Işık',
      'stateOff': 'Kapalı',
      'babyRestless': 'Bebek huzursuz',
      'tonightAlarms': 'Bu gece {n} alarm',
      'tonightNone': 'Bu gece alarm yok',
      'lastShort': 'son {time}',
      'historyLink': 'Geçmiş ›',
      'talkShort': 'Basılı tut, konuş',
      'lightOn': 'Işık açık',
      'lightOff': 'Işık kapalı',
      'qualityGood': 'İyi',
      'qualityFair': 'Orta',
      'qualityPoor': 'Zayıf',
      'connectionQualityLabel': 'Bağlantı kalitesi: {q}',
      'babyBatteryLabel': 'Bebek telefonunun pili %{level}',
      'moreActions': 'Diğer işlemler',
      'calmNight': 'Sakin bir gece!',
      'calmNightBody': 'Bu aralıkta hiç ağlama alarmı yok.',
      'byHour': 'Saat saat alarmlar',
      'roomCardDevices': 'Bağlı cihaz: {device}',
      'roomCardNone': 'Henüz bağlı cihaz yok',
      'deviceParentPhone': 'ebeveyn telefonu',
      'deviceBabyPhone': 'bebek telefonu',
    },
    'az': {
      'settings': 'Parametrlər',
      'theme': 'Tema',
      'systemDefault': 'Sistem standartı',
      'lightMode': 'İşıqlı rejim',
      'darkMode': 'Qaranlıq rejim',
      'language': 'Dil',
      'offlineMode': 'İnternetsiz rejim (Nearby)',
      'offlineModeSubtitle': 'İnternet olmadan yerli bağlantıdan istifadə et',
      'noiseThreshold': 'Səs-küy həddi',
      'moreSensitive': 'Daha həssas',
      'lessSensitive': 'Daha az həssas',
      'keepScreenOn': 'Ekranı açıq saxla',
      'keepScreenOnSubtitle': 'Tətbiq açıq olanda ekran sönmür',
      'videoSettings': 'Video parametrləri',
      'resolution': 'Ayırdetmə qabiliyyəti',
      'frameRate': 'Kadr tezliyi (FPS)',
      'bitrate': 'Bitreyt (Kbps)',
      'low': 'Aşağı',
      'medium': 'Orta',
      'high': 'Yüksək',
      'appTitle': 'Körpə Monitoru',
      'ok': 'Oldu',
      'cancel': 'Ləğv et',
      'error': 'Xəta',
      'loading': 'Yüklənir...',
      'babyMode': 'Körpə rejimi',
      'parentMode': 'Valideyn rejimi',
      'multiCameraMode': 'Çoxkameralı rejim',
      'createRoomCode': 'Otaq kodu yarat/yenilə',
      'startBroadcastOffline': 'Yayımı başlat (internetsiz)',
      'enterRoomCode': 'Otaq kodunu daxil edin',
      'searchDeviceOffline': 'Cihaz axtar (internetsiz)',
      'camerasReadError': 'Kameraları oxumaq mümkün olmadı: ',
      'noCameraFound': 'Cihazda istifadə üçün kamera tapılmadı.',
      'cameraInitError': 'Kameranı işə salma xətası: ',
      'firebaseConfigMissing': 'Firebase konfiqurasiyası tapılmadı. Cütləşmə deaktivdir.',
      'pairingInitError': 'Cütləşməni başlatmaq mümkün olmadı: ',
      'roomCreationErrorFirebase': 'Firebase parametrləri çatışmadığı üçün otaq yaradılmadı.',
      'roomCode': 'Otaq kodu',
      'copy': 'Kopyala',
      'share': 'Paylaş',
      'waitingForConnection': 'Bağlantı gözlənilir...',
      'connected': 'Qoşulub',
      'disconnected': 'Bağlantı kəsildi',
      'roomCodeCopied': 'Otaq kodu kopyalandı',
      'enterRoomCodeTitle': 'Otaq kodunu daxil edin',
      'enterRoomCodeSubtitle': 'Zəhmət olmasa, otaq kodunu daxil edin',
      'connect': 'Qoşul',
      'invalidRoomCode': 'Yanlış otaq kodu',
      'roomNotFound': 'Otaq tapılmadı',
      'roomFull': 'Otaq doludur',
      'babyCrying': 'Körpə ağlayır!',
      'noiseDetected': 'Səs-küy aşkarlandı',
      'lowBattery': 'Batareya azdır',
      'babyDeviceLowBattery': 'Körpə cihazının batareyası azalıb',
      'alertHistory': 'Siqnal tarixçəsi',
      'today': 'Bu gün',
      'yesterday': 'Dünən',
      'noRecordsFound': 'Qeyd tapılmadı',
      'pickDate': 'Tarix seçin',
      'startTime': 'Başlama vaxtı',
      'endTime': 'Bitmə vaxtı',
      'filter': 'Filtrlə',
      'clear': 'Təmizlə',
      'videoGallery': 'Video qalereya',
      'recordings': 'Yazılar',
      'recordingDeleted': 'Yazı silindi',
      'delete': 'Sil',
      'play': 'Oynat',
      'noiseLevel': 'Səs-küy səviyyəsi',
      'cameraPreview': 'Kamera önizləməsi',
      'stop': 'Dayandır',
      'start': 'Başlat',
      'retry': 'Yenidən cəhd et',
      'permissionDenied': 'İcazə verilmədi',
      'microphonePermissionRequired': 'Mikrofon icazəsi tələb olunur',
      'cameraPermissionRequired': 'Kamera icazəsi tələb olunur',
      'storagePermissionRequired': 'Yaddaş icazəsi tələb olunur',
      'locationPermissionRequired': 'İnternetsiz rejim üçün məkan icazəsi tələb olunur',
      'nearbyDevicesPermissionRequired': 'Yaxınlıqdakı cihazlar icazəsi tələb olunur',
      'notificationsPermissionRequired': 'Bildiriş icazəsi tələb olunur',
      'batteryOptimization': 'Batareya optimallaşdırması',
      'ignoreBatteryOptimizations': 'Daha yaxşı performans üçün batareya optimallaşdırması söndürülsün?',
      'yes': 'Bəli',
      'no': 'Xeyr',
      'confirmDelete': 'Bu yazını silmək istədiyinizə əminsiniz?',
      'shareVideo': 'Videonu paylaş',
      'videoPlayer': 'Video pleyer',
      'onlineMode': 'Onlayn rejim',
      'findBroadcast': 'Yayımı tap',
      'joinRoom': 'Otağa qoşul',
      'stopRecording': 'Yazını dayandır',
      'startRecording': 'Yazını başlat',
      'disconnect': 'Bağlantını kəs',
      'startCamera': 'Kameranı aç',
      'stopCamera': 'Kameranı bağla',
      'createRoom': 'Otaq yarat',
      'startBroadcast': 'Yayımı başlat',
      'charging': 'Şarj olunur',
      'babyDeviceBattery': 'Körpə cihazının batareyası',
      'wifi': 'Wi-Fi',
      'network': 'Şəbəkə',
      'temperature': 'Temperatur',
      'clearHistory': 'Tarixçəni təmizlə',
      'clearHistoryConfirmation': 'Bütün siqnal tarixçəsini silmək istədiyinizə əminsiniz?',
      'dateAll': 'Tarix: Hamısı',
      'date': 'Tarix',
      'pick': 'Seç',
      'change': 'Dəyiş',
      'timeRangeAll': 'Saat aralığı: Hamısı',
      'end': 'Bitir',
      'noAlertsYet': 'Hələ heç bir siqnal qeydə alınmayıb.',
      'motionOrSoundDetected': 'Hərəkət/səs aşkarlandı',
      'videoPlaybackHint': 'Videolar oynanılmırsa, zəhmət olmasa körpə cihazındakı tətbiqi də yeniləyin.',
      'gifAnimation': 'GIF animasiya',
      'videoRecording': 'Video yazısı',
      'videoFileNotFound': 'Video faylı tapılmadı',
      'videoFileEmpty': 'Video faylı boşdur (0 bayt)',
      'videoInitTimeout': 'Videonu açmaq üçün vaxt bitdi. Fayl zədələnmiş və ya dəstəklənməyən ola bilər.',
      'videoPlaybackError': 'Videonu oynatmaq mümkün olmadı',
      'addCamera': 'Kamera əlavə et',
      'enterRoomId': 'Otaq ID-sini daxil edin',
      'add': 'Əlavə et',
      'multiCameraMonitoring': 'Bir neçə körpəni izləmə',
      'noCameraAdded': 'Hələ kamera əlavə edilməyib.',
      'baby': 'Körpə',
      'room': 'Otaq',
      'status': 'Vəziyyət',
      'cameraInitializing': 'Kamera hazırlanır...',
      'previewNotReady': 'Önizləmə hazır deyil. Kameranı işə salmağa çalışın.',
      'openAppSettings': 'Tətbiq parametrlərini aç',
      'cameraNotReady': 'Kamera hazır deyil',
      'babyMightBeCrying': 'Deyəsən, körpə ağlayır',
      'babyCryAlert': 'Körpənin ağlama siqnalı',
      'passive': 'Passiv',
      'threshold': 'Hədd',
      'highNoise': 'Yüksək səs',
      'cameraPaused': 'Kamera fasilədədir',
      'cameraOn': 'Kamera açıq',
      'cameraOff': 'Kamera bağlı',
      'audioMonitoringOn': 'Səs izləmə açıq',
      'audioMonitoringOff': 'Səs izləmə bağlı',
      'connectionStatus': 'Bağlantı vəziyyəti',
      'videoSettingsUpdated': 'Video parametrləri yeniləndi',
      'unknownDevice': 'Naməlum cihaz',
      'addFirstCameraHint': 'İlk kameranızı əlavə etmək üçün + düyməsinə toxunun',
      'offlineAndroidOnly': 'İnternetsiz rejim yalnız Android-də mövcuddur',
      'offlineRecordingInfo': 'İnternetsiz yazılar səssiz və aşağı keyfiyyətli GIF olur. Maksimum müddət',
      'offlineRecordingLimitReached': 'İnternetsiz yazı vaxt limitinə çatdı və yadda saxlanıldı',
      'nightModeExitHint': 'Gecə rejimi. Çıxmaq üçün iki dəfə toxunun',
      'nightModeAction': 'Gecə rejimi',
      'iosCameraForegroundHint': 'iPhone-da tətbiq bağlananda və ya ekran kilidlənəndə kamera dayanır. Gecə rejimindən istifadə edin və tətbiqi açıq saxlayın',
      'nightModeKeepAppOpen': 'Yayımın davam etməsi üçün tətbiqi açıq saxlayın və ekranı kilidləməyin',
      'autoNightMode': 'Qoşulanda gecə rejiminə keç',
      'autoNightModeSubtitle': 'Körpə cihazı: valideyn qoşulanda ekran minimum parlaqlıqda qaralır',
      'roomClosed': 'Körpə cihazı otağı bağladı. Yeni otaq kodu istəyin',
      'roomUnavailable': 'Kod səhvdir, vaxtı bitib və ya artıq başqa cihazla cütləşib',
      'anonymousAuthDisabled': 'Bu tətbiq üçün giriş aktiv deyil (Firebase: Anonim giriş)',
      'roomCodeValidHint': 'Bu kodu 10 dəqiqə ərzində valideyn cihazına daxil edin',
      'noServerResponse': 'Serverdən cavab yoxdur. İnternet bağlantısını yoxlayıb yenidən cəhd edin',
      'backgroundListening': 'Arxa planda dinlə',
      'backgroundListeningSubtitle': 'Valideyn telefonu: ekran kilidli olanda da körpəni eşitməyə davam et',
      'serviceBabyTitle': 'Ninni yayımdadır',
      'serviceBabyText': 'Kamera və mikrofon valideyn telefonu üçün açıqdır',
      'serviceParentTitle': 'Ninni dinləyir',
      'serviceParentText': 'Körpəni eşidəcək və bildiriş alacaqsınız',
      'connectionLostTitle': 'Körpə telefonu ilə bağlantı kəsildi',
      'connectionLostBody': '{seconds} saniyədir görüntü və səs gəlmir. Hazırda körpəni izləyə bilmirsiniz.',
      'reconnecting': 'Yenidən qoşulmağa çalışırıq…',
      'tryAgain': 'Yenidən cəhd et',
      'silenceAlarm': 'Siqnalı söndür',
      'checkBabyPhone': 'KÖRPƏ TELEFONUNU YOXLAYIN',
      'checkWifi': 'Wi-Fi açıqdırmı?',
      'checkAppOpen': 'Tətbiq bağlanmış ola bilər',
      'checkCharger': 'Son batareya: %{level} — şarjda olmaya bilər',
      'batteryLowTitle': 'Körpə telefonunun batareyası azalıb',
      'batteryLowBody': 'Batareya %{level}. Körpə telefonunu şarja qoşun.',
      'dismiss': 'Bağla',
      'connectionLostNotification': 'Körpə telefonundan görüntü və səs gəlmir. Ninni-ni açın.',
      'alarmAfter2s': 'Ağlama 2 san davam edərsə, siqnal',
      'alarmDuration': 'Siqnaldan əvvəlki müddət',
      'alarmDurationSub': 'Səs bu qədər davam edərsə',
      'alarmsLabel': 'siqnal',
      'allow': 'İcazə ver',
      'androidOnly': '(yalnız Android)',
      'appTagline': 'Körpə monitoru',
      'autoNightModeShort': 'Körpə telefonunun ekranı qaralır',
      'babyCalm': 'Körpə sakitdir',
      'babyCryingShort': 'Körpə ağlayır',
      'babyStirring': 'Səs var',
      'babyDevice': 'Körpə cihazı',
      'babyDeviceBatteryShort': 'Körpə cihazı %{level}',
      'babyPairingTitle': 'Bu kodu valideyn telefonuna daxil edin',
      'babyPairingSubtitle': 'Kod 10 dəqiqə etibarlıdır.',
      'babyPlacementHint': 'Telefonu şarjda və körpədən 1–2 metr aralıda qoyun.',
      'iosKeepOpenHint': 'iPhone-da Ninni-ni açıq saxlayın və gecə rejimindən istifadə edin; ekran kilidlənəndə kamera dayanır.',
      'babyShort': 'Körpə',
      'youShort': 'Siz',
      'back': 'Geri',
      'batteryCharging': '%{level} · şarjda',
      'batteryPercent': '%{level}',
      'cameraMicReady': 'Kamera və mikrofon hazırdır',
      'cameraPreparing': 'Kamera hazırlanır…',
      'clearHistoryTitle': 'Tarixçə silinsin?',
      'clearHistoryBody': 'Bu telefondakı bütün siqnal qeydləri silinəcək.',
      'close': 'Bağla',
      'codeExpired': 'Kodun vaxtı bitib. Yenisini yaradın.',
      'codeValidFor': 'Kod daha {time} etibarlıdır',
      'connecting': 'Qoşulur',
      'continueLabel': 'Davam et',
      'copied': 'Kod kopyalandı',
      'cry': 'Ağlama',
      'cryStopped': 'dayandı',
      'cryingForSeconds': '{s} saniyədir',
      'defaultRoomName': 'Körpə otağı',
      'disconnectTitle': 'Bağlantı kəsilsin?',
      'disconnectBody': 'İzləmə dayanacaq və bu otaqdan siqnal almayacaqsınız.',
      'endBroadcast': 'Yayımı bitir',
      'endBroadcastTitle': 'Yayım bitirilsin?',
      'endBroadcastBody': 'Valideyn telefonunun bağlantısı kəsiləcək və otaq kodu etibarsız olacaq.',
      'enterNightMode': 'Gecə rejiminə keç',
      'fullscreen': 'Tam ekran',
      'granted': 'Verilib',
      'history': 'Tarixçə',
      'hoursShort': '{h} saat',
      'hoursMinutesShort': '{h} saat {m} dəq',
      'minutesShort': '{m} dəq',
      'minutesSecondsShort': '{m} dəq {s} san',
      'secondsShort': '{s} san',
      'imReady': 'Hazıram',
      'joinTitle': 'Otağa qoşulun',
      'joinSubtitle': 'Körpə telefonunda göstərilən 8 simvollu kodu daxil edin.',
      'last7Days': '7 gün',
      'lastAlarmAt': 'son siqnal {time}',
      'later': 'Sonra',
      'letsStart': 'Başlayaq',
      'levelActive': 'Səs var',
      'levelLoud': 'Yüksək',
      'levelOff': 'Başlayır…',
      'levelQuiet': 'Sakit',
      'licenses': 'Lisenziyalar',
      'linkGood': 'Bağlantı yaxşıdır',
      'live': 'CANLI',
      'liveView': 'Canlı görüntü',
      'longestQuietLabel': 'ən uzun sakitlik',
      'newCode': 'Yeni kod',
      'nightExitHint': 'Çıxmaq üçün iki dəfə toxunun',
      'nightStatusConnected': 'Yayım gedir · valideyn qoşulub',
      'nightStatusWaiting': 'Yayım gedir · valideyn gözlənilir',
      'noAlertsInRange': 'Bu müddətdə siqnal yoxdur. Sakit gecə!',
      'noInternet': 'İnternet yoxdur?',
      'notifyInterval': 'Bildiriş intervalı',
      'notifyIntervalSub': 'Ağlama davam etdikcə, ən çox',
      'perMinute': '1 / dəq',
      'now': 'indi',
      'offlineBabyTitle': 'Yaxınlıqdakı valideyn telefonu gözlənilir',
      'offlineBabyBody': 'İnternet lazım deyil. Valideyn telefonunda “Mənim yanımda” seçin və “Yaxınlıqda axtar” düyməsinə toxunun. Bluetooth, Wi-Fi və məkan açıq olmalıdır.',
      'offlineModeShort': 'İnternetsiz rejim',
      'offlineParentTitle': 'Körpə telefonunu tapın',
      'offlineParentBody': 'Hər iki telefon yaxında olsun; Bluetooth, Wi-Fi və məkan açıq olmalıdır.',
      'onboardTitle1': 'Körpəniz yatanda,\nsiz də rahat yatın',
      'onboardBody1': 'Əlinizdəki iki telefonu bir neçə saniyəyə körpə monitoruna çevirin.',
      'onboardTitle2': 'Üç addımda hazır',
      'onboardStep1Title': 'Bir telefonu körpənin yanına qoyun',
      'onboardStep1Body': 'Köhnə telefon da olar. Şarjda qalsın.',
      'onboardStep2Title': 'Kodu daxil edin',
      'onboardStep2Body': 'İki telefon təhlükəsiz bağlantı ilə cütləşir. Kod 10 dəqiqə etibarlıdır.',
      'onboardStep3Title': 'Körpə ağlayanda dərhal xəbəriniz olsun',
      'onboardStep3Body': 'Tətbiq bağlı olanda belə bildiriş gəlir. Canlı görüntü və səs.',
      'onboardTitle3': 'Bir neçə icazə lazımdır',
      'onboardBody3': 'Hər birinin nə üçün lazım olduğunu yazmışıq. İstənilən vaxt parametrlərdən dəyişə bilərsiniz.',
      'openSettings': 'Parametrləri aç',
      'openVideo': 'Görüntünü aç',
      'pageOf': 'Səhifə {n} / {total}',
      'parentConnected': 'Valideyn qoşulub',
      'parentWaiting': 'Valideyn gözlənilir',
      'permCamera': 'Kamera',
      'permCameraWhy': 'Körpəni görə bilməyiniz üçün',
      'permMic': 'Mikrofon',
      'permMicWhy': 'Ağlamağı eşitmək və danışmaq üçün',
      'permNotifications': 'Bildirişlər',
      'permNotificationsWhy': 'Ağlama siqnalı üçün',
      'permNearby': 'Yaxınlıqdakı cihazlar',
      'permNearbyWhy': 'İnternetsiz rejim üçün (istəyə bağlı)',
      'privacyNote': 'Görüntü və səs iki telefon arasında şifrələnmiş şəkildə ötürülür. Serverlərimizdə saxlanılmır.',
      'quality': 'Keyfiyyət',
      'qualitySaver': 'Qənaətli',
      'qualityBalanced': 'Balanslı',
      'qualitySharp': 'Aydın',
      'record': 'Yaz',
      'stopRecordingShort': 'Dayandır',
      'replayIntro': 'Tanıtımı yenidən göstər',
      'roleTitle': 'Bu telefon harada olacaq?',
      'roleSubtitle': 'İki telefonu cütləşdirin: biri körpənin yanında, digəri sizdə.',
      'roleBabyTitle': 'Körpənin yanında',
      'roleBabyBody': 'Bu telefon kamera və mikrofon olur. Ağlamağı aşkarlayır və sizə xəbər verir.',
      'roleParentTitle': 'Mənim yanımda',
      'roleParentBody': 'Körpəni canlı izləyin, ağlayan kimi dərhal bildiriş alın.',
      'roomShort': 'Otaq',
      'searchNearby': 'Yaxınlıqda axtar',
      'searching': 'Körpə telefonu axtarılır…',
      'sectionAbout': 'Haqqında',
      'sectionAlarm': 'Siqnal',
      'sectionApp': 'Tətbiq',
      'sectionVideo': 'Görüntü',
      'sensitivity': 'Həssaslıq',
      'shareCodeText': 'Ninni otaq kodu: {code}',
      'shortNoise': 'Qısa səs-küy',
      'skip': 'Keç',
      'snooze5': '5 dəq səssiz et',
      'soundLevel': 'Səs səviyyəsi',
      'switchCamera': 'Kameranı çevir',
      'switchShort': 'Çevir',
      'themeAuto': 'Avtomatik',
      'themeLight': 'İşıqlı',
      'themeDark': 'Qaranlıq',
      'thresholdValue': 'Hədd {db} dB',
      'tonight': 'Bu gecə',
      'totalCryLabel': 'ümumi ağlama',
      'waitingForParent': 'Valideyn telefonu gözlənilir',
      'recordingSaved': 'Yazı qalereyada saxlanıldı',
      'recordingNoPicture': 'Görüntü gəlmədiyi üçün yazmaq mümkün olmadı',
      'babyPairingSubtitleQr': 'Və ya digər telefonun kamerası ilə QR kodu oxudun.',
      'qrSemantic': 'Otağın QR kodu',
      'roomNameTitle': 'Otağın adı',
      'save': 'Yadda saxla',
      'scanQr': 'QR kodu oxut',
      'qrScanHint': 'Kameranı körpə telefonundakı QR koda tutun.',
      'qrNotNinni': 'Bu, Ninni otaq kodu deyil. Körpə telefonundakı QR-ı yoxlayın.',
      'qrNoCameraPermission': 'Ninni-nin kamera icazəsi yoxdur. Parametrlərdən icazə verin və ya kodu əl ilə daxil edin.',
      'qrCameraUnavailable': 'Kamera açılmadı. Kodu əl ilə daxil edin.',
      'recentRoom': 'Son qoşulduğunuz',
      'reconnect': 'Yenidən qoşul',
      'yesterdayLower': 'dünən',
      'holdToTalk': 'Basıb saxlayın, körpəyə danışın',
      'holdToTalkHint': 'Basıb saxladıqca səsiniz körpə telefonunda səslənir',
      'talkingNow': 'Danışırsınız… buraxanda dayanır',
      'talkNeedsMic': 'Körpəyə danışmaq üçün mikrofon icazəsi lazımdır',
      'lullabyShort': 'Layla',
      'lullabyTitle': 'Körpəni sakitləşdir',
      'sootheWhite': 'Ağ səs-küy',
      'sootheWhiteSub': 'Yumşaq və sabit',
      'sootheRain': 'Yağış',
      'sootheRainSub': 'Təbiət səsi',
      'sootheHeart': 'Ürək döyüntüsü',
      'sootheHeartSub': 'Bətn səsi',
      'sootheDandini': 'Dandini dandini',
      'sootheDandiniSub': 'Ənənəvi layla',
      'playingNow': 'Səslənir',
      'volumeOnBaby': 'Səs səviyyəsi (körpə telefonunda)',
      'continuous': 'Daimi',
      'nightLight': 'Gecə lampası',
      'nightLightSub': 'Körpə telefonunun ekranı yumşaq işıq saçır',
      'lightColor': 'İşığın rəngi',
      'colorAmber': 'Kəhrəba',
      'colorPink': 'Çəhrayı',
      'colorPurple': 'Bənövşəyi',
      'colorBlue': 'Mavi',
      'languageAz': 'Azərbaycanca',
      'errNoInternet': 'İnternet bağlantısı yoxdur. Wi-Fi və ya mobil interneti yoxlayın.',
      'errSignIn': 'Daxil olmaq mümkün olmadı. Bir az sonra yenidən cəhd edin.',
      'errPermission': 'Lazımi icazə verilməyib. Ayarlardan kamera və mikrofon icazəsini açın.',
      'errCamera': 'Kamera açılmadı. Tətbiqi bağlayıb yenidən açın.',
      'errNotConfigured': 'Bu versiyada onlayn bağlantı mövcud deyil.',
      'errUnknown': 'Nəsə səhv getdi. Yenidən cəhd edin.',
      'offlineBannerTitle': 'İnternet yoxdur',
      'offlineBannerBody': 'Bağlantı bərpa olunanda avtomatik yenidən cəhd ediləcək.',
      'offlineBannerAndroid': 'İnternetsiz izləmək üçün iki Android telefonda İnternetsiz rejimdən istifadə edin.',
      'backOnline': 'İnternet bərpa olundu',
      'talkFailed': 'Mikrofon açılmadı. Yenidən cəhd edin.',
      'talkBabyHears': 'Körpə sizi eşidir',
      'talkStarting': 'Mikrofon açılır',
      'talkNotReaching': 'Səs körpəyə çatmır',
      'micTestTitle': 'Mikrofonu yoxla',
      'micTestSubtitle': 'Otaqdakı səsi görün, həddi tənzimləyin',
      'micTestOwn': 'Bu telefonun mikrofonu',
      'micTestInCall': 'Yayımdakı mikrofon (ağlama aşkarlamasının ölçdüyü)',
      'micTestFromBaby': 'Körpə telefonundan gələn səs',
      'micTestOver': 'Hədd aşıldı',
      'micTestUnder': 'Həddən aşağı',
      'micTestPeak': 'Son 10 san ən yüksək',
      'micTestNoMic': 'Mikrofon açılmadı. Mikrofon icazəsini yoxlayın.',
      'micTestHint': 'Körpənin ağlamasına yaxın səs çıxarın (ucadan danışın və ya ağlama səsi səsləndirin). Zolaq işarəni 2 saniyə aşarsa, siqnal çalır. Otaq səs-küylüdürsə, həddi qaldırın.',
      'thresholdShort': 'Hədd',
      'diagTitle': 'Diaqnostika',
      'diagCopy': 'Kopyala',
      'diagCopied': 'Kopyalandı',
      'diagHint': 'Real cihaz xətalarını tapmaq üçün canlı dəyərlər. Eyni məlumat saniyədə bir dəfə CRYDIAG / TALKDIAG sətri kimi loga yazılır.',
      'version': 'Versiya',
      'greetMorning': 'Sabahınız xeyir',
      'greetDay': 'Gününüz xeyir',
      'greetEvening': 'Axşamınız xeyir',
      'greetNight': 'Gecəniz xeyrə',
      'homeWatchTitle': 'Körpə otağını izlə',
      'homeWatchLast': 'Son bağlantı · {when}',
      'homeBabyTitle': 'Körpə telefonu',
      'homeBabyBody': 'Kamera və mikrofon olur',
      'homeNewTitle': 'Yeni otaq',
      'homeNewBody': 'QR və ya kodla qoşul',
      'tipLabel': 'Məsləhət:',
      'tip1': 'Körpə telefonunu şarja qoşun və gecə rejimini açın. Telefon az qızır, ekran işığı körpəni narahat etmir.',
      'tip2': 'Körpə telefonunu beşikdən ən azı 1 metr aralı, körpəni görən yerə qoyun.',
      'tip3': 'Siqnal tez-tez çalır və ya heç çalmır? Ayarlar → Mikrofonu yoxla bölməsində həddi otağınıza görə tənzimləyin.',
      'tip4': 'Ekran kilidli olanda da dinləmək üçün Ayarlarda "Arxa planda dinlə" açıq qalsın.',
      'tip5': 'Körpəyə danışmaq üçün ortadakı düyməni basılı saxlayın; səsiniz körpə telefonunun dinamikindən çıxır.',
      'tip6Android': 'İnternet yoxdursa, iki Android telefonla İnternetsiz rejimdən istifadə edə bilərsiniz.',
      'tip6Ios': 'Valideyn telefonunda QR kodu oxudaraq saniyələr içində qoşulun.',
      'onAirFor': 'Yayımda · {time}',
      'watchingFor': '{time} ərzində izlənilir',
      'durationHm': '{h} saat {m} dəq',
      'durationM': '{m} dəq',
      'linkShortOk': 'Qoşulub',
      'linkShortWait': 'Gözləyir',
      'cameraBack': 'Arxa kamera',
      'cameraFront': 'Ön kamera',
      'lastHour': 'Son 1 saat',
      'alarmsAt': '{n} siqnal · {time}',
      'noAlarmsShort': 'Siqnal yoxdur',
      'boxParent': 'Valideyn',
      'boxParentOn': 'İzləyir',
      'boxParentOff': 'Gözlənilir',
      'boxLullaby': 'Layla',
      'boxLight': 'İşıq',
      'stateOff': 'Sönülü',
      'babyRestless': 'Körpə narahatdır',
      'tonightAlarms': 'Bu gecə {n} siqnal',
      'tonightNone': 'Bu gecə siqnal yoxdur',
      'lastShort': 'son {time}',
      'historyLink': 'Tarixçə ›',
      'talkShort': 'Basıb danış',
      'lightOn': 'İşıq açıq',
      'lightOff': 'İşıq sönülü',
      'qualityGood': 'Yaxşı',
      'qualityFair': 'Orta',
      'qualityPoor': 'Zəif',
      'connectionQualityLabel': 'Bağlantı keyfiyyəti: {q}',
      'babyBatteryLabel': 'Körpə telefonunun batareyası %{level}',
      'moreActions': 'Digər əməliyyatlar',
      'calmNight': 'Sakit gecə!',
      'calmNightBody': 'Bu aralıqda heç bir ağlama siqnalı yoxdur.',
      'byHour': 'Saatbasaat siqnallar',
      'roomCardDevices': 'Qoşulmuş cihaz: {device}',
      'roomCardNone': 'Hələ qoşulmuş cihaz yoxdur',
      'deviceParentPhone': 'valideyn telefonu',
      'deviceBabyPhone': 'körpə telefonu',
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
  String get recordingSaved => _t('recordingSaved');
  String get recordingNoPicture => _t('recordingNoPicture');
  String get babyPairingSubtitleQr => _t('babyPairingSubtitleQr');
  String get qrSemantic => _t('qrSemantic');
  String get roomNameTitle => _t('roomNameTitle');
  String get save => _t('save');
  String get scanQr => _t('scanQr');
  String get qrScanHint => _t('qrScanHint');
  String get qrNotNinni => _t('qrNotNinni');
  String get qrNoCameraPermission => _t('qrNoCameraPermission');
  String get qrCameraUnavailable => _t('qrCameraUnavailable');
  String get recentRoom => _t('recentRoom');
  String get reconnect => _t('reconnect');
  String get yesterdayLower => _t('yesterdayLower');
  String get holdToTalk => _t('holdToTalk');
  String get holdToTalkHint => _t('holdToTalkHint');
  String get talkingNow => _t('talkingNow');
  String get talkNeedsMic => _t('talkNeedsMic');
  String get lullabyShort => _t('lullabyShort');
  String get lullabyTitle => _t('lullabyTitle');
  String get sootheWhite => _t('sootheWhite');
  String get sootheWhiteSub => _t('sootheWhiteSub');
  String get sootheRain => _t('sootheRain');
  String get sootheRainSub => _t('sootheRainSub');
  String get sootheHeart => _t('sootheHeart');
  String get sootheHeartSub => _t('sootheHeartSub');
  String get sootheDandini => _t('sootheDandini');
  String get sootheDandiniSub => _t('sootheDandiniSub');
  String get playingNow => _t('playingNow');
  String get volumeOnBaby => _t('volumeOnBaby');
  String get continuous => _t('continuous');
  String get nightLight => _t('nightLight');
  String get nightLightSub => _t('nightLightSub');
  String get lightColor => _t('lightColor');
  String get colorAmber => _t('colorAmber');
  String get colorPink => _t('colorPink');
  String get colorPurple => _t('colorPurple');
  String get colorBlue => _t('colorBlue');
  String get languageAz => _t('languageAz');
  String get errNoInternet => _t('errNoInternet');
  String get errSignIn => _t('errSignIn');
  String get errPermission => _t('errPermission');
  String get errCamera => _t('errCamera');
  String get errNotConfigured => _t('errNotConfigured');
  String get errUnknown => _t('errUnknown');
  String get offlineBannerTitle => _t('offlineBannerTitle');
  String get offlineBannerBody => _t('offlineBannerBody');
  String get offlineBannerAndroid => _t('offlineBannerAndroid');
  String get backOnline => _t('backOnline');
  String get talkFailed => _t('talkFailed');
  String get talkBabyHears => _t('talkBabyHears');
  String get talkStarting => _t('talkStarting');
  String get talkNotReaching => _t('talkNotReaching');
  String get micTestTitle => _t('micTestTitle');
  String get micTestSubtitle => _t('micTestSubtitle');
  String get micTestOwn => _t('micTestOwn');
  String get micTestInCall => _t('micTestInCall');
  String get micTestFromBaby => _t('micTestFromBaby');
  String get micTestOver => _t('micTestOver');
  String get micTestUnder => _t('micTestUnder');
  String get micTestPeak => _t('micTestPeak');
  String get micTestNoMic => _t('micTestNoMic');
  String get micTestHint => _t('micTestHint');
  String get thresholdShort => _t('thresholdShort');
  String get diagTitle => _t('diagTitle');
  String get diagCopy => _t('diagCopy');
  String get diagCopied => _t('diagCopied');
  String get diagHint => _t('diagHint');
  String get version => _t('version');
  String get greetMorning => _t('greetMorning');
  String get greetDay => _t('greetDay');
  String get greetEvening => _t('greetEvening');
  String get greetNight => _t('greetNight');
  String get homeWatchTitle => _t('homeWatchTitle');
  String get homeWatchLast => _t('homeWatchLast');
  String get homeBabyTitle => _t('homeBabyTitle');
  String get homeBabyBody => _t('homeBabyBody');
  String get homeNewTitle => _t('homeNewTitle');
  String get homeNewBody => _t('homeNewBody');
  String get tipLabel => _t('tipLabel');
  String get tip1 => _t('tip1');
  String get tip2 => _t('tip2');
  String get tip3 => _t('tip3');
  String get tip4 => _t('tip4');
  String get tip5 => _t('tip5');
  String get tip6Android => _t('tip6Android');
  String get tip6Ios => _t('tip6Ios');
  String get onAirFor => _t('onAirFor');
  String get watchingFor => _t('watchingFor');
  String get durationHm => _t('durationHm');
  String get durationM => _t('durationM');
  String get linkShortOk => _t('linkShortOk');
  String get linkShortWait => _t('linkShortWait');
  String get cameraBack => _t('cameraBack');
  String get cameraFront => _t('cameraFront');
  String get lastHour => _t('lastHour');
  String get alarmsAt => _t('alarmsAt');
  String get noAlarmsShort => _t('noAlarmsShort');
  String get boxParent => _t('boxParent');
  String get boxParentOn => _t('boxParentOn');
  String get boxParentOff => _t('boxParentOff');
  String get boxLullaby => _t('boxLullaby');
  String get boxLight => _t('boxLight');
  String get stateOff => _t('stateOff');
  String get babyRestless => _t('babyRestless');
  String get tonightAlarms => _t('tonightAlarms');
  String get tonightNone => _t('tonightNone');
  String get lastShort => _t('lastShort');
  String get historyLink => _t('historyLink');
  String get talkShort => _t('talkShort');
  String get lightOn => _t('lightOn');
  String get lightOff => _t('lightOff');
  String get qualityGood => _t('qualityGood');
  String get qualityFair => _t('qualityFair');
  String get qualityPoor => _t('qualityPoor');
  String get connectionQualityLabel => _t('connectionQualityLabel');
  String get babyBatteryLabel => _t('babyBatteryLabel');
  String get moreActions => _t('moreActions');
  String get calmNight => _t('calmNight');
  String get calmNightBody => _t('calmNightBody');
  String get byHour => _t('byHour');
  String get roomCardDevices => _t('roomCardDevices');
  String get roomCardNone => _t('roomCardNone');
  String get deviceParentPhone => _t('deviceParentPhone');
  String get deviceBabyPhone => _t('deviceBabyPhone');
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
