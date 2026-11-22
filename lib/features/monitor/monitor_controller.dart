import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:image/image.dart' as img;
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app_keys.dart';
import '../../core/alert_history_service.dart';
import '../../core/audio/app_audio.dart';
import '../../core/audio/audio_level.dart';
import '../../core/audio/cry_detector.dart';
import '../../core/audio/offline_audio.dart';
import '../../core/audio/pcm_microphone.dart';
import '../../core/auth/auth_service.dart';
import '../../core/debug/debug_hooks.dart';
import '../../core/enums/connection_status.dart';
import '../../core/enums/device_role.dart';
import '../../core/monitor/battery_alert.dart';
import '../../core/monitor/connection_watchdog.dart';
import '../../core/offline/offline_payload.dart';
import '../../core/pairing/pairing_service.dart';
import '../../core/pairing/pairing_state.dart';
import '../../core/pairing/room_code.dart';
import '../../core/recording/video_recorder_service.dart';
import '../../core/services/hybrid_notification_manager.dart';
import '../../core/services/monitor_foreground_service.dart';
import '../../core/webrtc/firestore_signaling.dart';
import '../../core/webrtc/reconnect_backoff.dart';
import '../../core/webrtc/signaling_interface.dart';
import '../../core/webrtc/signaling_messages.dart';
import '../../core/webrtc/webrtc_service.dart';
import '../../l10n/app_localizations.dart';
import '../../models/alert_model.dart';
import '../../models/video_settings.dart';

/// Fixed states for screenshots (see [MonitorController.debugDemo]).
enum DemoScene { roleSelect, babyPairing, babyLive, babyNight, parentJoin, parentLive, cryAlert, connectionLost }

/// All monitoring logic of the app (both roles, online and offline), moved
/// out of the old 3400-line HomeScreen (V2 phase 2). Screens only read its
/// state and call its actions; it has no widgets of its own.
///
/// The body is the former `_HomeScreenState` logic, kept as close to the
/// original as possible (B08 sessions, B70 standby microphone, D3 rooms…).
/// `setState`/`mounted` below are small shims so that code stays readable.
class MonitorController extends ChangeNotifier with WidgetsBindingObserver {
  MonitorController({required Locale Function() locale}) : _locale = locale {
    _init();
  }

  final Locale Function() _locale;
  AppLocalizations get l10n => AppLocalizations(_locale());
  ScaffoldMessengerState? get _messenger => rootMessengerKey.currentState;
  BuildContext? get _dialogContext => rootNavigatorKey.currentContext;

  bool get mounted => !_disposing;

  /// Shim for the ported code: run [fn], then notify the screens.
  @protected
  void setState(VoidCallback fn) {
    fn();
    if (!_disposing) notifyListeners();
  }

  // Role is null until the user picks one on the role screen (V2 §3.2).
  bool _roleChosen = false;

  // Parent: full-screen cry alarm (V2 §3.8, 5.8).
  bool _cryActive = false;
  bool _cryAlarmVisible = false;
  DateTime? _cryStartedAt;
  double? _cryPeakDb;
  DateTime? _crySnoozedUntil;
  final AlarmSound _cryAlarmSound =
      AlarmSound(asset: 'audio/alarm_cry.wav', playerId: 'ninni_cry_alarm');

  // Baby: a parent was connected at least once in this broadcast (pairing
  // screen -> live screen).
  bool _parentEverConnected = false;

  // Offline parent: endpoints found by discovery (shown on the join screen).
  bool _discovering = false;

  // Baby: when the current room was created (code countdown, 10 min claim).
  DateTime? _roomCreatedAt;

  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  CameraLensDirection _currentLens = CameraLensDirection.back;

  bool _initializing = false;
  bool _hasCamPermission = false;
  String? _message;
  DeviceRole _role = DeviceRole.BABY;

  PairingService? _pairingService;
  WebRTCService? _webrtcService;
  PairingState? _pairingState;
  ConnectionStatus _connectionStatus = ConnectionStatus.DISCONNECTED;
  String? _pairingError;
  bool _pairingBusy = false;
  bool _firebaseReady = false;
  VideoSettings _videoSettings = const VideoSettings();
  
  final VideoRecorderService _recorderService = VideoRecorderService();

  // Offline / Wi-Fi Direct Mode
  bool _isOfflineMode = false;
  final Strategy _p2pStrategy = Strategy.P2P_STAR;
  String? _connectedEndpointId;
  final ValueNotifier<Uint8List?> _currentImageBytesNotifier = ValueNotifier<Uint8List?>(null);
  Uint8List? get _currentImageBytes => _currentImageBytesNotifier.value;
  DateTime _lastFrameTime = DateTime.now();
  bool _isStreaming = false;
  // Only one camera frame is converted/sent at a time; frames arriving while
  // one is in flight are dropped instead of piling up isolates (B10).
  bool _frameInFlight = false;
  final List<Map<String, String>> _discoveredEndpoints = []; // {id, name}
  final StreamController<List<Map<String, String>>> _discoveryStreamController = StreamController.broadcast();

  // Microphone PCM (`record` package): offline streaming over Nearby, and
  // the online baby's noise meter while no parent is connected.
  final PcmMicrophone _mic = PcmMicrophone();
  // Audio Streaming (Offline, Android only): raw PCM over Nearby.
  final OfflineAudio _offlineAudio = OfflineAudio();
  StreamSubscription<Uint8List>? _audioSub;
  bool _isAudioStreaming = false;
  // Online baby, no parent connected (standby): WebRTC does not capture, so
  // the loudest chunk of our own microphone feeds cry detection.
  StreamSubscription<Uint8List>? _standbyMicSub;
  bool _standbyMicActive = false;
  final PeakDbTracker _standbyPeak = PeakDbTracker();
  bool _isPlayerRunning = false; // Track player state

  bool _listeningNoise = false;
  double _currentDecibel = 0.0;

  double _noiseThreshold = 60.0;
  bool _noiseAlert = false;
  // Alarm only after >= 2 s above the threshold (D5 / B27).
  final CryDetector _cryDetector = CryDetector(threshold: 60.0);
  // Threshold changes are synced to the other device (debounced) so the
  // baby's detection can be calibrated from the parent (D5).
  Timer? _thresholdSyncTimer;

  // Parent side of the session protocol (B08): our current viewer session and
  // automatic rejoin after the connection was lost.
  String? _viewerSession;
  final ReconnectBackoff _rejoinBackoff = ReconnectBackoff();
  Timer? _rejoinTimer;
  // Bumped by every manual join, rejoin attempt and reset; an attempt whose
  // token is outdated stops before writing a session (no competing sessions).
  int _joinToken = 0;

  // Baby: keeps the active room's expiresAt in the future (TTL, D8).
  Timer? _roomHeartbeat;

  // Parent: FCM token updates for the joined room (D2).
  StreamSubscription<String>? _pushTokenSub;
  bool _notificationPermissionWarned = false;


  bool _keepScreenOn = false;
  bool _nightMode = false;
  // Enter night mode automatically once a parent connects (baby device, D1-a).
  bool _autoNightMode = false;

  bool _disposing = false;
  StreamSubscription<PairingState>? _roomSub;
  bool _lastCryAlertSent = false;
  // Cry notifications (Firestore alert docs / local notifications) are rate
  // limited so a long cry does not produce a notification every 2 s (B05).
  static const Duration _cryNotificationCooldown = Duration(seconds: 60);
  // How often the baby refreshes cryAlert/cryDb in the room (noise bar on the
  // parent). Was 2 s; 5 s saves Firestore writes (D8). Alarm changes are
  // still sent immediately.
  static const Duration _cryStateUpdateInterval = Duration(seconds: 5);
  DateTime? _lastCryNotificationAt;
  DateTime? _lastCrySentAt;
  DateTime? _lastRecordedAlertTime;


  // Battery
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.full;
  StreamSubscription<BatteryState>? _batteryStateSubscription;
  Timer? _batterySyncTimer;
  int? _remoteBatteryLevel;
  BatteryState? _remoteBatteryState;

  // Noise Polling for WebRTC
  Timer? _noisePollTimer;

  // V2 phase 1 -----------------------------------------------------------
  // Parent: connection lost alarm (5.6).
  final ConnectionWatchdog _watchdog = ConnectionWatchdog();
  Timer? _watchdogTimer;
  int _watchdogTicks = 0;
  int? _lastInboundBytes;
  bool _connectionLost = false;
  DateTime? _connectionLostSince;
  bool _connectionAlarmSilenced = false;
  final AlarmSound _connectionAlarm = AlarmSound();
  // Parent: one warning per low battery episode of the baby phone (5.7).
  final LowBatteryAlert _lowBattery = LowBatteryAlert();
  bool _showBatteryWarning = false;
  // Baby: one battery push (alert document) per low battery episode.
  final LowBatteryAlert _babyBatteryPush = LowBatteryAlert();
  int? _sentBatteryLevel;
  bool? _sentBatteryCharging;
  // Parent: keep hearing the baby with the screen locked (5.10).
  static const String _backgroundListeningKey = 'backgroundListening';
  bool _backgroundListening = true;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  /// Former initState. The camera starts only when the baby role is chosen.
  void _init() {
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadPreferences());
    _pushTokenSub = HybridNotificationManager().onPushTokenRefresh.listen((token) {
      final roomCode = _pairingState?.roomCode;
      if (_role == DeviceRole.PARENT && _viewerSession != null && roomCode != null) {
        unawaited(_registerPushToken(roomCode, token: token));
      }
    }, onError: (Object e) => debugPrint('Push token refresh error: $e'));
    _recorderService.onOfflineLimitReached = () {
      unawaited(_stopOfflineRecordingAtLimit());
    };
    _coreReady = _initCoreServices();
    _initBatteryMonitoring();
  }

  /// Completes when Firebase/WebRTC services are set up (or failed).
  Future<void> _coreReady = Future.value();

  Future<void> _initBatteryMonitoring() async {
    // Keep the subscription so dispose() can cancel it, and never call
    // setState after dispose (B19).
    _batteryStateSubscription = _battery.onBatteryStateChanged.listen(
      (BatteryState state) {
        if (!mounted) return;
        setState(() {
          _batteryState = state;
        });
        _sendBatteryUpdate();
      },
      onError: (Object e) => debugPrint('Battery state stream error: $e'),
    );

    _batterySyncTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      try {
        final level = await _battery.batteryLevel;
        if (!mounted) return;
        setState(() {
          _batteryLevel = level;
        });
        _sendBatteryUpdate();
      } catch (e) {
        debugPrint('Battery level read error: $e');
      }
    });
    
    // Initial fetch
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      if (!mounted) return;
      setState(() {
        _batteryLevel = level;
        _batteryState = state;
      });
    } catch (e) {
      debugPrint('Battery init error: $e');
    }
  }

  Future<void> _sendBatteryUpdate() async {
    if (_role != DeviceRole.BABY) return;
    
    final payloadMap = {
      'type': 'BATTERY',
      'level': _batteryLevel,
      'state': _batteryState.toString(),
    };
    
    final payload =
        OfflinePayload.encodeJson(OfflinePayloadType.battery, payloadMap);

    if (_isOfflineMode && _connectedEndpointId != null) {
      try {
        await Nearby().sendBytesPayload(_connectedEndpointId!, payload);
      } catch (e) {
        debugPrint('Battery payload send error: $e');
      }
    } else if (!_isOfflineMode && _pairingState?.roomCode != null && _pairingService != null) {
      // Online: the room's `battery` field (V2 5.7), written only when the
      // level or charging state changed.
      final roomCode = _pairingState!.roomCode;
      final charging = _isCharging(_batteryState);
      if (_sentBatteryLevel != _batteryLevel || _sentBatteryCharging != charging) {
        _sentBatteryLevel = _batteryLevel;
        _sentBatteryCharging = charging;
        try {
          await _pairingService!.setBattery(roomCode, level: _batteryLevel, charging: charging);
        } catch (e) {
          // e.g. rules that do not know the field yet; retried next minute.
          debugPrint('Battery update failed: $e');
          _sentBatteryLevel = null;
        }
      }
      // Low battery: one alert document per episode, so the Cloud Function
      // can push it while the parent app is closed.
      if (_babyBatteryPush.update(level: _batteryLevel, charging: charging) && mounted) {
        unawaited(HybridNotificationManager()
            .sendAlert(
              l10n.batteryLowTitle,
              l10n.batteryLowBody.replaceAll('{level}', '$_batteryLevel'),
              type: 'battery',
              level: _batteryLevel,
            )
            .catchError((Object e) => debugPrint('Battery alert failed: $e')));
      }
    }
  }

  static bool _isCharging(BatteryState? state) =>
      state == BatteryState.charging || state == BatteryState.full;

  // V2 phase 1 helpers -------------------------------------------------------

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listening = prefs.getBool(_backgroundListeningKey);
      final autoNight = prefs.getBool(_autoNightKey);
      final threshold = prefs.getDouble(_thresholdKey);
      if (!mounted) return;
      setState(() {
        if (listening != null) _backgroundListening = listening;
        if (autoNight != null) _autoNightMode = autoNight;
        if (threshold != null) {
          _noiseThreshold = threshold;
          _cryDetector.threshold = threshold;
        }
      });
    } catch (e) {
      debugPrint('Loading preferences failed: $e');
    }
  }

  Future<void> _setBackgroundListening(bool value) async {
    setState(() => _backgroundListening = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_backgroundListeningKey, value);
    } catch (e) {
      debugPrint('Saving background listening failed: $e');
    }
    if (_role == DeviceRole.PARENT && _pairingState != null) {
      if (value) {
        await _startMonitorService();
      } else {
        await MonitorForegroundService.instance.stop();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (_role != DeviceRole.PARENT || _backgroundListening) return;
    // Background listening off: mute the baby while the app is not visible
    // (on iOS the `audio` background mode would keep playing otherwise).
    final visible = state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;
    _webrtcService?.setRemoteAudioEnabled(visible);
  }

  bool get _inForeground => _lifecycle == AppLifecycleState.resumed;

  /// Android foreground service: baby broadcast always, parent only with
  /// background listening on (V2 5.10 / 5.12).
  Future<void> _startMonitorService() async {
    if (!MonitorForegroundService.isSupported || !mounted) return;
    final isBaby = _role == DeviceRole.BABY;
    if (!isBaby && !_backgroundListening) return;
    if (isBaby) {
      // Android 13+: without notification permission the service still
      // runs, but its notification is hidden.
      unawaited(HybridNotificationManager().requestPermission().then<void>((_) {},
          onError: (Object e) => debugPrint('Notification permission failed: $e')));
    }
    await MonitorForegroundService.instance.start(
      role: _role,
      offline: _isOfflineMode,
      title: isBaby ? l10n.serviceBabyTitle : l10n.serviceParentTitle,
      text: isBaby ? l10n.serviceBabyText : l10n.serviceParentText,
    );
  }

  /// Parent: starts the connection watchdog for a new session (V2 5.6).
  void _startWatchdog() {
    _watchdog.start();
    _watchdog.onStatus(_connectionStatus, DateTime.now());
    _lastInboundBytes = null;
    _watchdogTicks = 0;
    _watchdogTimer?.cancel();
    _watchdogTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => unawaited(_watchdogTick()));
  }

  Future<void> _watchdogTick() async {
    if (!mounted || _disposing || !_watchdog.isActive) return;
    // Online: media flows while inbound RTP bytes grow (checked every 2 s).
    if (!_isOfflineMode && (++_watchdogTicks).isEven) {
      final bytes = await _webrtcService?.getInboundBytes();
      if (bytes != null) {
        final last = _lastInboundBytes;
        if (last != null && bytes > last) _watchdog.onMedia(DateTime.now());
        _lastInboundBytes = bytes;
      }
    }
    if (!mounted || !_watchdog.isActive) return;
    if (_watchdog.evaluate(DateTime.now())) {
      _onConnectionLostChanged(_watchdog.isLost);
    }
  }

  void _stopWatchdog() {
    _watchdog.stop();
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    if (_connectionLost) _onConnectionLostChanged(false);
  }

  void _onConnectionLostChanged(bool lost) {
    if (!mounted) return;
    setState(() {
      _connectionLost = lost;
      _connectionLostSince = lost ? (_watchdog.lostSince ?? DateTime.now()) : null;
      if (!lost) _connectionAlarmSilenced = false;
    });
    if (lost) {
      debugPrint('Connection watchdog: connection lost');
      unawaited(HapticFeedback.heavyImpact());
      if (!_connectionAlarmSilenced) unawaited(_connectionAlarm.start());
      unawaited(HybridNotificationManager().showConnectionLost(
          title: l10n.connectionLostTitle, body: l10n.connectionLostNotification));
      // Connected but no media: the peer is stuck, start a new session.
      if (!_isOfflineMode && _connectionStatus == ConnectionStatus.CONNECTED) {
        _scheduleRejoin();
      }
    } else {
      debugPrint('Connection watchdog: connection back');
      unawaited(_connectionAlarm.stop());
      unawaited(HybridNotificationManager().cancelConnectionLost());
    }
  }

  void _silenceConnectionAlarm() {
    setState(() => _connectionAlarmSilenced = true);
    unawaited(_connectionAlarm.stop());
  }

  void _retryConnection() {
    if (_isOfflineMode) {
      unawaited(_startDiscovery());
      return;
    }
    _rejoinTimer?.cancel();
    _rejoinBackoff.reset();
    unawaited(_rejoinRoom());
  }

  /// Parent: battery of the baby phone (room field or Nearby payload).
  void _onRemoteBattery(int level, bool charging) {
    _remoteBatteryLevel = level;
    _remoteBatteryState = charging ? BatteryState.charging : BatteryState.discharging;
    if (_role != DeviceRole.PARENT) return;
    if (charging || level >= _lowBattery.rearmLevel) _showBatteryWarning = false;
    if (_lowBattery.update(level: level, charging: charging)) {
      _showBatteryWarning = true;
      unawaited(HapticFeedback.mediumImpact());
      if (!_inForeground && mounted) {
        unawaited(HybridNotificationManager().showBatteryLow(
            title: l10n.batteryLowTitle,
            body: l10n.batteryLowBody.replaceAll('{level}', '$level')));
      }
    }
  }


  Future<void> _setup() async {
    if (_initializing) return;
    if (_controller != null && _controller!.value.isInitialized) return;
    setState(() => _initializing = true);

    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = '${l10n.camerasReadError}$e';
          _initializing = false;
        });
      }
      return;
    }

    await _initControllerForLens(_currentLens);
    if (mounted) {
      setState(() => _initializing = false);
    }
  }

  Future<void> _disposeCameraController() async {
    final oldController = _controller;
    if (oldController == null) return;
    _controller = null;
    if (mounted) {
      setState(() {
      });
    }
    try {
      await oldController.dispose();
    } catch (e) {
      debugPrint('Camera dispose failed: $e');
    }
  }

  Future<void> _restoreCameraIfIdle() async {
    // V2: the camera package preview is only used by the offline broadcast
    // (online the WebRTC renderer shows the camera).
    if (!_isOfflineMode || _pairingState == null) return;
    if (!mounted || _initializing) return;
    if (_role != DeviceRole.BABY) return;
    if (_webrtcService?.localRenderer.srcObject != null) return;
    if (_controller != null && _controller!.value.isInitialized) return;
    await _setup();
  }

  Future<void> _initControllerForLens(CameraLensDirection lens) async {
    if (_webrtcService?.localRenderer.srcObject != null) {
      return;
    }
    if (_cameras.isEmpty) {
      if (mounted) {
        setState(() => _message = l10n.noCameraFound);
      }
      return;
    }

    final CameraDescription selected = _cameras.firstWhere(
      (c) => c.lensDirection == lens,
      orElse: () => _cameras.first,
    );

    final old = _controller;
    _controller = null;
    await old?.dispose();

    final newController = CameraController(
      selected,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await newController.initialize();

      if (!mounted) return;
      setState(() {
        _controller = newController;
        _message = null;
        _currentLens = selected.lensDirection;
        _hasCamPermission = true;
      });
      
      // Restart stream if in Offline Mode and connected
      if (_isOfflineMode && _role == DeviceRole.BABY && _connectedEndpointId != null) {
        _isStreaming = false;
        _startImageStream();
        _startAudioStream();
      }
    } catch (e) {
      await newController.dispose();
      if (!mounted) return;
      setState(() {
        _message = '${l10n.cameraInitError}$e';
      });
    }
  }

  @override
  void dispose() {
    // Services stopped below report status changes synchronously (e.g.
    // WebRTCService.hangUp -> DISCONNECTED); `mounted` is still true during
    // dispose, so the handlers check this flag instead (B62).
    _disposing = true;
    WidgetsBinding.instance.removeObserver(this);
    _watchdogTimer?.cancel();
    unawaited(_connectionAlarm.dispose());
    unawaited(MonitorForegroundService.instance.stop());
    if (_recorderService.isRecording) {
      unawaited(_recorderService.stopAny().catchError(
          (Object e) => debugPrint('Stopping recording on dispose failed: $e')));
    }
    _batterySyncTimer?.cancel();
    _thresholdSyncTimer?.cancel();
    _rejoinTimer?.cancel();
    _roomHeartbeat?.cancel();
    _pushTokenSub?.cancel();
    _batteryStateSubscription?.cancel();
    // Resources that were not released before (B25).
    _noisePollTimer?.cancel();
    _audioSub?.cancel();
    _standbyMicSub?.cancel();
    unawaited(_mic.stop().catchError(
        (Object e) => debugPrint('Microphone stop on dispose failed: $e')));
    // The offline audio channel exists only on Android.
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_offlineAudio.stopPlayer().catchError(
          (Object e) => debugPrint('Audio player stop on dispose failed: $e')));
    }
    if (_isOfflineMode && defaultTargetPlatform == TargetPlatform.android) {
      unawaited(Future(() async {
        try {
          await Nearby().stopAdvertising();
          await Nearby().stopDiscovery();
          await Nearby().stopAllEndpoints();
        } catch (e) {
          debugPrint('Nearby stop on dispose failed: $e');
        }
      }));
    }
    if (_nightMode) {
      unawaited(ScreenBrightness.instance.resetApplicationScreenBrightness().catchError(
          (Object e) => debugPrint('Resetting brightness on dispose failed: $e')));
    }
    _currentImageBytesNotifier.dispose();
    _discoveryStreamController.close();
    _controller?.dispose();
    unawaited(_cryAlarmSound.dispose());
    if (_role == DeviceRole.BABY && _pairingState?.roomCode != null) {
      unawaited(_pairingService?.closeRoom(_pairingState!.roomCode).catchError(
          (Object e) => debugPrint('Closing room on dispose failed: $e')));
    }
    _roomSub?.cancel();
    _webrtcService?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }


  void _handleConnectionStatus(ConnectionStatus status) {
    if (!mounted || _disposing) return;
    if (_role == DeviceRole.PARENT) _watchdog.onStatus(status, DateTime.now());
    setState(() {
      _connectionStatus = status;
      if (status == ConnectionStatus.CONNECTED ||
          status == ConnectionStatus.FAILED) {
        _pairingBusy = false;
      }
      if (_pairingState != null) {
        final isPaired = status == ConnectionStatus.CONNECTED;
        _pairingState = _pairingState!.copyWith(
          isPaired: isPaired || _pairingState!.isPaired,
          status: status,
        );
      }
    });
    if (status == ConnectionStatus.CONNECTED) {
      if (_role == DeviceRole.BABY && !_parentEverConnected) {
        setState(() => _parentEverConnected = true);
      }
      _rejoinBackoff.reset();
      _rejoinTimer?.cancel();
      _maybeEnterAutoNightMode();
    } else if (status == ConnectionStatus.FAILED) {
      _scheduleRejoin();
    }
  }

  /// Parent, online: after the connection failed, join the same room again
  /// with a new session (2 s, 4 s, 8 s, 16 s, then every 30 s) until it
  /// works, the room is gone, or the user disconnects (B08).
  void _scheduleRejoin() {
    if (_role != DeviceRole.PARENT || _isOfflineMode) return;
    if (_viewerSession == null || _pairingState == null) return;
    if (_rejoinTimer?.isActive ?? false) return;
    final delay = _rejoinBackoff.next();
    debugPrint('Rejoin attempt ${_rejoinBackoff.attempts} in ${delay.inSeconds} s');
    _rejoinTimer = Timer(delay, () => unawaited(_rejoinRoom()));
  }

  Future<void> _rejoinRoom() async {
    final roomCode = _pairingState?.roomCode;
    final pairing = _pairingService;
    final webrtc = _webrtcService;
    if (!mounted || roomCode == null || pairing == null || webrtc == null) return;
    if (_viewerSession == null || _role != DeviceRole.PARENT) return;
    final token = ++_joinToken;
    final session = newViewerSessionId();
    _viewerSession = session;
    try {
      await pairing.joinRoom(roomCode, session: session);
      if (!mounted || token != _joinToken) return;
      await webrtc.startAsParent(roomCode, session: session);
      unawaited(_registerPushToken(roomCode));
    } on RoomUnavailableException {
      // The room is gone (closed by the baby or expired): stop retrying.
      _viewerSession = null;
      _stopWatchdog();
      if (mounted) _handlePairingError(l10n.roomClosed);
    } on AnonymousAuthDisabledException {
      // Retrying cannot help until sign-in is enabled in the console (B60).
      _viewerSession = null;
      if (mounted) _handlePairingError(l10n.anonymousAuthDisabled);
    } catch (e) {
      debugPrint('Rejoin failed: $e');
      if (token == _joinToken) _scheduleRejoin();
    }
  }

  void _handlePairingError(String message) {
    if (!mounted || _disposing) return;
    if (_role == DeviceRole.PARENT) {
      _watchdog.onStatus(ConnectionStatus.FAILED, DateTime.now());
    }
    setState(() {
      _pairingError = message;
      _connectionStatus = ConnectionStatus.FAILED;
      _pairingBusy = false;
      if (_pairingState != null) {
        _pairingState = _pairingState!.copyWith(
          errorMessage: message,
          status: ConnectionStatus.FAILED,
        );
      }
    });
    _messenger?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Disposes the current WebRTC service (if any) after the UI stopped
  /// referencing its renderers. Called when switching online/offline mode.
  Future<void> _disposeWebRtcService() async {
    final previous = _webrtcService;
    if (previous == null) return;
    if (mounted) {
      setState(() {
        _webrtcService = null;
        _pairingService = null;
      });
      // Let the frame without the old renderers be drawn before disposing them.
      await WidgetsBinding.instance.endOfFrame;
    } else {
      _webrtcService = null;
      _pairingService = null;
    }
    HybridNotificationManager().clearSignalingService();
    try {
      await previous.dispose();
    } catch (e) {
      debugPrint('WebRTC dispose failed: $e');
    }
  }

  Future<void> _initCoreServices() async {
    try {
      await _disposeWebRtcService();
      if (!mounted) return;

      if (_isOfflineMode) {
        // Offline mode streams over Nearby Connections directly; WebRTC is not used.
        setState(() {
          _firebaseReady = Firebase.apps.isNotEmpty;
          _pairingError = null;
        });
        return;
      }

      // Firebase is required for Firestore; if not initialized, pairing stays disabled.
      if (Firebase.apps.isEmpty) {
        setState(() {
          _firebaseReady = false;
          _pairingError =
              l10n.firebaseConfigMissing;
        });
        return;
      }

      final PairingService pairing = PairingService();
      final SignalingInterface signaling = FirestoreSignaling();

      final webrtc = WebRTCService(
        signalingService: signaling,
        pairingService: pairing,
        onStatusChanged: _handleConnectionStatus,
        onError: _handlePairingError,
        // Cry detection: own microphone meter in standby, WebRTC's audio
        // level during a call; never both on the microphone at once.
        beforeBabyCall: _stopStandbyMic,
        onBabyStandby: () => unawaited(_startStandbyMic()),
      );
      await webrtc.initRenderers();
      if (!mounted) {
        await webrtc.dispose();
        return;
      }
      setState(() {
        _pairingService = pairing;
        _webrtcService = webrtc;
        _firebaseReady = true;
        _pairingError = null;
      });
      
      // Set signaling service for notifications
      HybridNotificationManager().setSignalingService(signaling);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _firebaseReady = false;
        _pairingError = '${l10n.pairingInitError}$e';
      });
    }
  }


  Future<void> _resetPairing({bool deleteRoom = false, bool restoreCamera = true}) async {
    final activeRoom = _pairingState?.roomCode;
    // Stop automatic rejoin first, so nothing writes a new session while (or
    // after) we leave the room (B08).
    final wasViewer = _viewerSession != null;
    _viewerSession = null;
    _joinToken++;
    _rejoinTimer?.cancel();
    _rejoinBackoff.reset();
    _roomHeartbeat?.cancel();
    _stopWatchdog();
    unawaited(MonitorForegroundService.instance.stop());
    _showBatteryWarning = false;
    _lowBattery.reset();
    _babyBatteryPush.reset();
    _sentBatteryLevel = null;
    _sentBatteryCharging = null;
    await _exitNightMode();

    // Finish a running recording before its source stream goes away, so the
    // file is finalized instead of left unplayable (B14).
    if (_recorderService.isRecording) {
      try {
        await _recorderService.stopAny();
      } catch (e) {
        debugPrint('Stopping recording on reset failed: $e');
      }
      if (mounted) setState(() {});
    }

    await _webrtcService?.hangUp();
    
    // Dispose P2P. Nearby exists only on Android; creating the Nearby()
    // singleton elsewhere listens on a missing event channel (B65).
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await Nearby().stopAdvertising();
        await Nearby().stopDiscovery();
        await Nearby().stopAllEndpoints();
      } catch (e) {
        debugPrint('Nearby stop failed: $e');
      }
    }
    try {
      _connectedEndpointId = null;
      _currentImageBytesNotifier.value = null;
      if (_isStreaming) {
        await _controller?.stopImageStream();
        _isStreaming = false;
      }
      _stopAudioStream();
    } catch (e) {
      debugPrint('P2P dispose error: $e');
    }

    // Stop Noise Monitoring (Online Mode)
    await _stopNoiseMonitoring();

    // Streaming turned the wakelock on; release it again unless the user
    // asked to keep the screen on (B24).
    if (!_keepScreenOn) {
      try {
        await WakelockPlus.disable();
      } catch (e) {
        debugPrint('Wakelock disable failed: $e');
      }
    }

    if (restoreCamera) {
      await _restoreCameraIfIdle();
    }
    await _roomSub?.cancel();
    _roomSub = null;
    if (activeRoom != null) {
      try {
        if (deleteRoom) {
          await _pairingService?.closeRoom(activeRoom);
        } else if (_role == DeviceRole.PARENT && wasViewer) {
          // Clear our session so the baby closes its peer and waits (B08).
          await _pairingService?.leaveRoom(activeRoom);
        } else {
          await _pairingService?.setPaired(activeRoom, false);
        }
      } catch (e) {
        debugPrint('Room cleanup failed: $e');
      }
    }
    if (!mounted) return;
    _cryActive = false;
    _cryAlarmVisible = false;
    unawaited(_cryAlarmSound.stop());
    setState(() {
      _pairingState = null;
      _pairingError = null;
      _connectionStatus = ConnectionStatus.DISCONNECTED;
      _pairingBusy = false;
      _parentEverConnected = false;
      _discovering = false;
      _roomCreatedAt = null;
    });
    _lastCryAlertSent = false;
    _lastCrySentAt = null;
    _lastCryNotificationAt = null;
    _cryDetector.reset();
  }

  /// Applies a new cry threshold. Local changes are sent to the other device
  /// after a short debounce; remote values are ignored while a local change
  /// is still waiting to be sent, so an older remote value cannot undo it.
  void _setNoiseThreshold(double value, {bool fromRemote = false}) {
    if (fromRemote && (_thresholdSyncTimer?.isActive ?? false)) return;
    if ((value - _noiseThreshold).abs() < 0.01) return;
    if (!mounted) return;
    setState(() {
      _noiseThreshold = value;
      _cryDetector.threshold = value;
    });
    if (fromRemote) return;
    _thresholdSyncTimer?.cancel();
    _thresholdSyncTimer =
        Timer(const Duration(milliseconds: 500), () => unawaited(_syncNoiseThreshold()));
  }

  Future<void> _syncNoiseThreshold() async {
    final value = _noiseThreshold;
    try {
      if (_isOfflineMode) {
        final endpointId = _connectedEndpointId;
        if (endpointId == null) return;
        await Nearby().sendBytesPayload(
          endpointId,
          OfflinePayload.encodeJson(
              OfflinePayloadType.control, {'type': 'THRESHOLD', 'value': value}),
        );
      } else {
        final roomCode = _pairingState?.roomCode;
        final pairing = _pairingService;
        if (roomCode == null || pairing == null) return;
        await pairing.updateNoiseThreshold(roomCode, value);
      }
    } catch (e) {
      debugPrint('Threshold sync failed: $e');
    }
  }

  /// Returns true (and starts a new cooldown) if a cry notification may be
  /// sent now; false while the previous one is still within the cooldown.
  bool _takeCryNotificationSlot(DateTime now) {
    final last = _lastCryNotificationAt;
    if (last != null && now.difference(last) < _cryNotificationCooldown) {
      return false;
    }
    _lastCryNotificationAt = now;
    return true;
  }

  Future<void> _createRoomCode() async {
    if (_pairingBusy) return;
    await WakelockPlus.enable(); // Keep screen on for Online Mode
    if (_role != DeviceRole.BABY || _pairingService == null || _webrtcService == null) {
      if (mounted) {
        _messenger?.showSnackBar(
          SnackBar(
            content:
                Text(l10n.roomCreationErrorFirebase),
          ),
        );
      }
        return;
    }
    setState(() {
      _pairingBusy = true;
      _pairingError = null;
    });
    try {
      // The previous room is deleted inside createRoom; stop listening to it
      // first so its deletion is not reported as an error (B57).
      await _roomSub?.cancel();
      _roomSub = null;
      final newCode = await _pairingService!
          .createRoom(
            previousCode: _pairingState?.roomCode,
            noiseThreshold: _noiseThreshold,
          );
      final facingMode =
          _currentLens == CameraLensDirection.front ? 'user' : 'environment';
      unawaited(_pairingService!.setFacing(newCode, facingMode).catchError(
          (Object e) => debugPrint('setFacing failed: $e')));
      await _disposeCameraController();
      setState(() {
        _pairingState = PairingState(
          roomCode: newCode,
          status: ConnectionStatus.CONNECTING,
          facingMode: facingMode,
        );
        _connectionStatus = ConnectionStatus.CONNECTING;
      });
      _roomCreatedAt = DateTime.now();
      _listenRoomUpdates(newCode);
      _startRoomHeartbeat(newCode);
      await _webrtcService!.startAsBaby(newCode, facingMode: facingMode);
      unawaited(_startMonitorService());
      _sentBatteryLevel = null;
      unawaited(_sendBatteryUpdate());
      
      // Automatically start noise monitoring for Online Mode
      await _startNoiseMonitoring();

      if (!mounted) return;
      _messenger?.showSnackBar(
        SnackBar(content: Text('${l10n.roomCode}: ${RoomCode.format(newCode)}')),
      );
      // iOS stops the camera as soon as the app leaves the foreground, so
      // suggest night mode (screen stays on, black) for the baby phone.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        _messenger?.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            // With an action a SnackBar persists by default and would cover
            // the bottom controls for good (B67).
            persist: false,
            content: Text(l10n.iosCameraForegroundHint),
            action: SnackBarAction(
              label: l10n.nightModeAction,
              onPressed: () => unawaited(_enterNightMode()),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final message = _pairingErrorText(e);
      setState(() {
        _pairingError = message;
        _connectionStatus = ConnectionStatus.FAILED;
      });
      _messenger?.showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _pairingBusy = false);
      }
      await _restoreCameraIfIdle();
    }
  }

  Future<void> _joinRoomWithCode([String? code]) async {
    if (_pairingBusy) return;
    if (_role != DeviceRole.PARENT) return;
    if (_pairingService == null || _webrtcService == null) {
      if (mounted) {
        _messenger?.showSnackBar(
          SnackBar(
              content: Text(l10n.firebaseConfigMissing)),
        );
      }
        return;
    }
    final roomCode = RoomCode.normalize(code ?? '');
    if (roomCode.isEmpty) {
      _messenger?.showSnackBar(
        SnackBar(content: Text(l10n.enterRoomCodeSubtitle)),
      );
        return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _pairingBusy = true;
      _pairingError = null;
      _pairingState = PairingState(
        roomCode: roomCode,
        status: ConnectionStatus.CONNECTING,
        facingMode: 'environment',
      );
      _connectionStatus = ConnectionStatus.CONNECTING;
    });
    // Sheet açıksa hemen kapat, kullanıcıyı ana ekrana getir.

    try {
      // Each join is a new viewer session; the baby answers it with a fresh
      // offer, so leaving and joining the same room works (B08).
      _rejoinTimer?.cancel();
      _rejoinBackoff.reset();
      final token = ++_joinToken;
      final session = newViewerSessionId();
      _viewerSession = session;
      await _pairingService!.joinRoom(roomCode, session: session);
      if (token != _joinToken) return;
      _listenRoomUpdates(roomCode);
      await _webrtcService!.startAsParent(roomCode, session: session);
      unawaited(_registerPushToken(roomCode));
      _startWatchdog();
      unawaited(_startMonitorService());
      if (!mounted) return;
      _messenger?.showSnackBar(
        SnackBar(content: Text('${l10n.waitingForConnection}: $roomCode')),
      );
    } catch (e) {
      if (!mounted) return;
      // A code that cannot be joined is final: no automatic rejoin.
      // V2: a failed first join goes back to the join screen.
      _viewerSession = null;
      _stopWatchdog();
      unawaited(MonitorForegroundService.instance.stop());
      final message = _pairingErrorText(e);
      setState(() {
        _pairingError = message;
        _connectionStatus = ConnectionStatus.FAILED;
        _pairingState = null;
      });
      _messenger?.showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _pairingBusy = false);
      }
    }
  }

  Future<void> _requestBatteryOptimization() async {
    if (!Platform.isAndroid) return;
    
    // Check if optimization is already ignored
    var status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) return;

    // Show dialog to explain why we need this
    if (!mounted) return;
    
    final dialogContext = _dialogContext;
    if (dialogContext == null) return;
    final bool? shouldRequest = await showDialog<bool>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: Text(l10n.batteryOptimization),
        content: Text(l10n.ignoreBatteryOptimizations),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.no),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.yes),
          ),
        ],
      ),
    );

    if (shouldRequest == true) {
      status = await Permission.ignoreBatteryOptimizations.request();
      if (!status.isGranted) {
        debugPrint("Ignore battery optimizations permission denied");
      }
    }
  }

  Future<bool> _checkP2PPermissions() async {
    List<Permission> perms = [];

    // 1. Location (Required for discovery/advertising on most Android versions)
    perms.add(Permission.location);

    // 2. Android Version specific Bluetooth/Nearby
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final int sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 33) {
        // Android 13+ (API 33)
        perms.add(Permission.nearbyWifiDevices);
        perms.add(Permission.bluetoothScan);
        perms.add(Permission.bluetoothAdvertise);
        perms.add(Permission.bluetoothConnect);
      } else if (sdkInt >= 31) {
        // Android 12 (API 31/32)
        perms.add(Permission.bluetoothScan);
        perms.add(Permission.bluetoothAdvertise);
        perms.add(Permission.bluetoothConnect);
      } else {
        // Android < 12
        perms.add(Permission.bluetooth);
      }
    }

    // 3. Camera + microphone (Only for Baby): offline audio streaming and cry
    // detection need RECORD_AUDIO (B12).
    if (_role == DeviceRole.BABY) {
      perms.add(Permission.camera);
      perms.add(Permission.microphone);
    }

    Map<Permission, PermissionStatus> statuses = await perms.request();

    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (status.isDenied || status.isPermanentlyDenied) {
        debugPrint("Permission denied: $permission");
        allGranted = false;
      }
    });

    if (!allGranted) {
      if (mounted) {
        _messenger?.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            persist: false,
            content: Text(l10n.permissionDenied),
            action: SnackBarAction(
              label: l10n.settings,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return false;
    }
    return true;
  }

  /// Nearby Connections (and the androidInfo calls below) exist only on
  /// Android; on other platforms show a message instead of crashing (B46).
  bool _ensureOfflineSupported() {
    if (Platform.isAndroid) return true;
    _messenger?.showSnackBar(
      SnackBar(content: Text(l10n.offlineAndroidOnly)),
    );
    return false;
  }

  Future<void> _startAdvertising() async {
    if (_pairingBusy) return;
    if (!_ensureOfflineSupported()) return;
    if (!await _checkP2PPermissions()) return;

    setState(() => _pairingBusy = true);
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final userName = "${androidInfo.brand} ${androidInfo.model}".toUpperCase();
      
      bool a = await Nearby().startAdvertising(
        userName,
        _p2pStrategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: "com.example.bebek_monitor",
      );
      
      if (a) {
        setState(() {
          _pairingState = PairingState(
            roomCode: l10n.startBroadcastOffline,
            status: ConnectionStatus.CONNECTING,
            facingMode: 'environment',
          );
          _connectionStatus = ConnectionStatus.CONNECTING;
        });
        _messenger?.showSnackBar(
          SnackBar(content: Text(l10n.waitingForConnection)),
        );
        // Initialize camera if not already
        if (_controller == null || !_controller!.value.isInitialized) {
          await _initControllerForLens(CameraLensDirection.back);
        }
        await WakelockPlus.enable(); // Keep screen on for Wifi Direct
        unawaited(_startMonitorService());
      } else {
        throw Exception("Advertising failed to start");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pairingError = 'P2P ${l10n.error}: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _pairingBusy = false);
      }
    }
  }

  void _startImageStream() {
    if (_controller == null || _isStreaming) return;
    
    _isStreaming = true;
    _controller!.startImageStream((CameraImage image) {
      // Limit FPS based on settings
      final targetFps = _videoSettings.fps;
      final intervalMs = (1000 / targetFps).round();
      
      final now = DateTime.now();
      if (now.difference(_lastFrameTime).inMilliseconds < intervalMs) {
        return;
      }
      _lastFrameTime = now;
      
      _processAndSendImage(image);
    });
  }

  Future<void> _startAudioStream() async {
    if (_isAudioStreaming || _connectedEndpointId == null) return;
    _isAudioStreaming = true;

    try {
      final stream = await _mic.start();
      if (!_isAudioStreaming || !mounted) {
        // Stopped (disconnect/dispose) while the microphone was starting.
        await _mic.stop();
        return;
      }
      _audioSub = stream.listen((data) {
        if (_connectedEndpointId != null) {
          // 1. Send Audio Data
          final payload = OfflinePayload.encode(OfflinePayloadType.audio, data);
          Nearby().sendBytesPayload(_connectedEndpointId!, payload);

          // 2. Calculate dB and Send Status
          _calculateAndSendDb(data);
        }
      }, onError: (Object e) {
        debugPrint('Offline microphone error: $e');
        _stopAudioStream();
      });
    } catch (e) {
      debugPrint("Error starting audio stream: $e");
      _isAudioStreaming = false;
    }
  }

  void _stopAudioStream() {
    unawaited(_audioSub?.cancel());
    _audioSub = null;
    if (_isAudioStreaming) {
      unawaited(_mic.stop().catchError(
          (Object e) => debugPrint('Stopping offline audio failed: $e')));
    }
    _isAudioStreaming = false;
  }

  /// Online baby in standby (no parent connected): our own microphone meter
  /// feeds cry detection, because WebRTC does not capture audio before a
  /// call. Stopped before a call starts (WebRTCService.beforeBabyCall).
  Future<void> _startStandbyMic() async {
    if (!mounted || _isOfflineMode || _role != DeviceRole.BABY) return;
    if (_standbyMicActive) return;
    if (_isDebugIosSimulator) {
      // CoreAudio on the iOS simulator aborts the app when a second audio
      // engine starts (BLOCKERS 4); E2E tests inject the level instead.
      debugPrint('Standby noise meter skipped on the iOS simulator');
      return;
    }
    _standbyMicActive = true;
    _standbyPeak.take();
    try {
      final stream = await _mic.start();
      if (!_standbyMicActive || !mounted) {
        await _mic.stop();
        return;
      }
      _standbyMicSub = stream.listen(_standbyPeak.addChunk,
          onError: (Object e) {
        debugPrint('Standby noise meter error: $e');
        unawaited(_stopStandbyMic());
      });
    } catch (e) {
      // e.g. no microphone permission: fall back to WebRTC's level.
      debugPrint('Standby noise meter unavailable: $e');
      _standbyMicActive = false;
    }
  }

  Future<void> _stopStandbyMic() async {
    final wasActive = _standbyMicActive;
    _standbyMicActive = false;
    await _standbyMicSub?.cancel();
    _standbyMicSub = null;
    if (wasActive) {
      try {
        await _mic.stop();
      } catch (e) {
        debugPrint('Standby noise meter stop failed: $e');
      }
    }
  }

  static bool get _isDebugIosSimulator =>
      kDebugMode &&
      defaultTargetPlatform == TargetPlatform.iOS &&
      Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');

  void _calculateAndSendDb(List<int> data) {
    // PCM16 chunk -> shared noise scale (same as online, see audio_level.dart)
    final db = pcm16ChunkToDb(data);

    final now = DateTime.now();
    final bool alert = _cryDetector.update(db, now);

    // Publish (local UI + parent) on alert changes or every 200 ms. Audio
    // chunks arrive many times per second; rebuilding the whole HomeScreen
    // for each one wasted CPU/battery on the baby device (B20).
    final shouldPublish = alert != _lastCryAlertSent ||
        _lastCrySentAt == null ||
        now.difference(_lastCrySentAt!) > const Duration(milliseconds: 200);
    if (!shouldPublish) return;

    _lastCryAlertSent = alert;
    _lastCrySentAt = now;

    // Update local UI (Baby side)
    if (mounted) {
      setState(() {
        _currentDecibel = db;
        _noiseAlert = alert;
      });
    }

    // Send to Parent
    final endpointId = _connectedEndpointId;
    if (endpointId == null) return;
    final payloadMap = {
      'type': 'STATUS',
      'db': db,
      'alert': alert,
    };
    final payload =
        OfflinePayload.encodeJson(OfflinePayloadType.control, payloadMap);

    unawaited(Nearby().sendBytesPayload(endpointId, payload).catchError(
        (Object e) => debugPrint('Status payload send error: $e')));
  }

  Future<void> _processAndSendImage(CameraImage image) async {
    if (_connectedEndpointId == null) return;
    if (_frameInFlight) return;
    _frameInFlight = true;

    try {
      // 1. Prepare data (Main Thread - Fast)
      // Extract raw bytes efficiently. 
      // We perform minimal work here to unblock UI immediately.
      final int angle = (Platform.isAndroid && _controller != null) 
          ? _controller!.description.sensorOrientation 
          : 0;

      final params = <String, dynamic>{
        'width': image.width,
        'height': image.height,
        'yPlane': image.planes[0].bytes,
        'uPlane': image.planes[1].bytes,
        'vPlane': image.planes[2].bytes,
        'yRowStride': image.planes[0].bytesPerRow,
        'uvRowStride': image.planes[1].bytesPerRow,
        'uvPixelStride': image.planes[1].bytesPerPixel ?? 1,
        'angle': angle,
        'qualitySetting': _videoSettings.quality,
      };

      // 2. Heavy Processing (Isolate - Background)
      // Pass copy of bytes to not block UI
      final jpegBytes = await compute(_processImageInIsolate, params);

      // Save frame if recording (Offline Mode on Baby Side)
      if (_recorderService.isRecording) {
        _recorderService.addOfflineFrame(jpegBytes);
      }

      // 3. Send (Main Thread)
      if (_connectedEndpointId == null) return;

      final payload = OfflinePayload.encode(OfflinePayloadType.image, jpegBytes);

      await Nearby().sendBytesPayload(
        _connectedEndpointId!,
        payload,
      );
    } catch (e) {
      debugPrint("Error sending frame: $e");
    } finally {
      _frameInFlight = false;
    }
  }

  Future<void> _startDiscovery() async {
    if (!_ensureOfflineSupported()) return;
    if (!await _checkP2PPermissions()) return;

    _discoveredEndpoints.clear();
    _discoveryStreamController.add(_discoveredEndpoints);
    setState(() => _discovering = true);

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final userName = "${androidInfo.brand} ${androidInfo.model}".toUpperCase();

      bool a = await Nearby().startDiscovery(
        userName,
        _p2pStrategy,
        onEndpointFound: (id, name, serviceId) {
          if (!_discoveredEndpoints.any((e) => e['id'] == id)) {
            _discoveredEndpoints.add({'id': id, 'name': name});
            _discoveryStreamController.add(List.from(_discoveredEndpoints));
            _notify();
          }
        },
        onEndpointLost: (id) {
          _discoveredEndpoints.removeWhere((e) => e['id'] == id);
          _discoveryStreamController.add(List.from(_discoveredEndpoints));
          _notify();
        },
        serviceId: "com.example.bebek_monitor",
      );
      
      if (a) {
        _messenger?.showSnackBar(
          SnackBar(content: Text(l10n.searchDeviceOffline)),
        );
      }
    } catch (e) {
      debugPrint("Discovery error: $e");
    }
  }

  Future<void> _connectToEndpoint(String id, String name) async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final userName = "${androidInfo.brand} ${androidInfo.model}".toUpperCase();

    Nearby().requestConnection(
      userName,
      id,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    );
    
    _messenger?.showSnackBar(
       SnackBar(content: Text('$name: ${l10n.waitingForConnection}')),
    );
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    // Auto-accept connection
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (endId, payload) {
        if (payload.type == PayloadType.BYTES) {
          _onPayloadReceived(payload.bytes!);
        }
      },
    );
  }

  void _onConnectionResult(String id, Status status) {
    if (status == Status.CONNECTED) {
      setState(() {
        _connectedEndpointId = id;
        _connectionStatus = ConnectionStatus.CONNECTED;
        _pairingState = PairingState(
          roomCode: "${l10n.connected} (Offline)",
          status: ConnectionStatus.CONNECTED,
          facingMode: 'environment',
        );
      });
      
      if (_role == DeviceRole.BABY) {
        _parentEverConnected = true;
        _startImageStream();
        _startAudioStream();
        _maybeEnterAutoNightMode();
        // The baby's threshold is the active one; tell the new parent.
        unawaited(_syncNoiseThreshold());
      } else if (_role == DeviceRole.PARENT) {
        if (!_watchdog.isActive) _startWatchdog();
        _watchdog.onStatus(ConnectionStatus.CONNECTED, DateTime.now());
        unawaited(_startMonitorService());
        // Reset the player but DO NOT start it yet: it starts when the first
        // audio packet arrives, to avoid a buffer underrun.
        // Note: We do NOT use Helper.setSpeakerphoneOn(true) here for Offline mode
        // because the offline player uses the media stream, which plays on the speaker.
        // Using WebRTC's Helper might switch mode to IN_COMMUNICATION which can mute MUSIC stream on some devices.
        _isPlayerRunning = false;
        unawaited(_offlineAudio.stopPlayer().catchError(
            (Object e) => debugPrint('Offline player reset failed: $e')));
      }
    } else {
      setState(() {
        _connectedEndpointId = null;
        _connectionStatus = ConnectionStatus.FAILED;
      });
    }
  }

  void _onDisconnected(String id) {
    if (!mounted) return;
    setState(() {
      _connectedEndpointId = null;
      _currentImageBytesNotifier.value = null;
      _connectionStatus = ConnectionStatus.DISCONNECTED;
    });
    if (_role == DeviceRole.BABY) {
      // stopImageStream throws if no stream is running; never leave the
      // future unhandled (B26).
      if (_isStreaming) {
        unawaited(_controller?.stopImageStream().catchError(
            (Object e) => debugPrint('stopImageStream on disconnect failed: $e')));
      }
      _isStreaming = false;
      _stopAudioStream();
    } else if (_role == DeviceRole.PARENT) {
      _watchdog.onStatus(ConnectionStatus.DISCONNECTED, DateTime.now());
      unawaited(_offlineAudio.stopPlayer().catchError(
          (Object e) => debugPrint('Offline player stop failed: $e')));
      _isPlayerRunning = false;
    }
  }

  void _onPayloadReceived(Uint8List bytes) {
    // Payloads already queued by Nearby can still arrive after dispose (B25).
    if (!mounted) return;
    final message = OfflinePayload.decode(bytes);
    if (message == null) return;

    final type = message.type;
    if (_role == DeviceRole.PARENT &&
        (type == OfflinePayloadType.image || type == OfflinePayloadType.audio)) {
      _watchdog.onMedia(DateTime.now());
    }
    if (type == OfflinePayloadType.image) {
      // Image Data
      final wasEmpty = _currentImageBytesNotifier.value == null;
      
      // Update Notifier only - Avoid full screen rebuild!
      _currentImageBytesNotifier.value = message.body;
      
      // Trigger rebuild only on first frame to update UI state (canShowPreview)
      if (wasEmpty) {
          setState(() {});
      }
      
      if (_recorderService.isRecording && _currentImageBytes != null) {
        _recorderService.addOfflineFrame(_currentImageBytes!);
      }
    } else if (type == OfflinePayloadType.control) {
      // Settings or Status Command
      try {
        final map = message.decodeJson();
        
        if (map['type'] == 'SETTINGS') {
           final newSettings = VideoSettings.fromJson(map['data']);
           _applyRemoteSettings(newSettings);
        } else if (map['type'] == 'THRESHOLD') {
           final value = map['value'];
           if (value is num) _setNoiseThreshold(value.toDouble(), fromRemote: true);
        } else if (map['type'] == 'SWITCH_CAMERA') {
           // Handle Camera Switch Request from Parent
           if (_role == DeviceRole.BABY) {
             _switchCamera(remoteRequest: true);
           }
        } else if (map['type'] == 'STATUS') {
           // Handle Noise Alert from Baby
           final double db = (map['db'] as num).toDouble();
           final bool alert = map['alert'] as bool;
           
           final wasAlert = _noiseAlert;
           setState(() {
             _currentDecibel = db;
             _noiseAlert = alert;
           });
           // Offline there is no Firestore alert listener: notify here, at
           // the start of a cry and at most once per cooldown.
           if (alert && !wasAlert && _takeCryNotificationSlot(DateTime.now())) {
             unawaited(HybridNotificationManager().showLocalNotification(
               title: l10n.babyCryAlert,
               body: '${l10n.noiseLevel}: ${db.toStringAsFixed(1)} dB',
             ));
           }
           _onRemoteCryState(alert, db);
        }
      } catch (e) {
        debugPrint("Error parsing payload: $e");
      }
    } else if (type == OfflinePayloadType.audio) {
      // Audio Data
      if (_role == DeviceRole.PARENT) {
        // Background listening off: do not play while the app is not visible.
        if (!_backgroundListening && !_inForeground) return;
        // Platform channel messages are handled in order, so the player is
        // started before the first chunk is written.
        if (!_isPlayerRunning) {
          _isPlayerRunning = true;
          unawaited(_offlineAudio.startPlayer().then((ok) {
            if (!ok) debugPrint('Offline player could not start');
          }).catchError((Object e) {
            debugPrint('Offline player start failed: $e');
          }));
        }
        unawaited(_offlineAudio.writeChunk(message.body).catchError(
            (Object e) => debugPrint('Offline audio write failed: $e')));
      }
    } else if (type == OfflinePayloadType.battery) {
      // Battery Data
      try {
        final map = message.decodeJson();
        if (map['type'] == 'BATTERY') {
          final stateStr = map['state'] as String;
          final state = BatteryState.values.firstWhere(
            (e) => e.toString() == stateStr,
            orElse: () => BatteryState.unknown,
          );
          final level = map['level'];
          if (level is num) {
            setState(() => _onRemoteBattery(level.round(), _isCharging(state)));
          }
        }
      } catch (e) {
        debugPrint("Error parsing battery payload: $e");
      }
    }
  }

  Future<void> _updateVideoSettings(VideoSettings newSettings) async {
    setState(() {
      _videoSettings = newSettings;
    });

    if (_isOfflineMode) {
      // Send to peer via Nearby
      if (_connectedEndpointId != null) {
        final payloadMap = {
          'type': 'SETTINGS',
          'data': newSettings.toJson(),
        };
        final payload =
            OfflinePayload.encodeJson(OfflinePayloadType.control, payloadMap);
        
        await Nearby().sendBytesPayload(_connectedEndpointId!, payload);
      }
      // Apply locally if we are the baby (sender)
      if (_role == DeviceRole.BABY) {
        _restartStreamWithNewSettings();
      }
    } else {
      // Online Mode - Update Firestore
      final roomCode = _pairingState?.roomCode;
      if (roomCode != null && _pairingService != null) {
        await _pairingService!.updateVideoSettings(roomCode, newSettings);
      }
      // Local apply is handled by _listenRoomUpdates
    }
  }

  void _applyRemoteSettings(VideoSettings settings) {
    if (_videoSettings.fps == settings.fps && _videoSettings.quality == settings.quality) return;
    
    setState(() {
      _videoSettings = settings;
    });
    
    if (_role == DeviceRole.BABY) {
      _restartStreamWithNewSettings();
      _messenger?.showSnackBar(
        SnackBar(content: Text('${l10n.videoSettingsUpdated}: ${settings.fps} FPS, ${settings.quality}')),
      );
    }
  }

  Future<void> _restartStreamWithNewSettings() async {
    if (!_isStreaming) return;
    
    // For Wi-Fi Direct, we just need to update the throttling logic in _startImageStream
    // But since _startImageStream is a loop driven by camera stream, we might need to stop and start
    // to ensure the new closure captures the new settings? 
    // Actually, _startImageStream uses _videoSettings.fps which is a member variable, 
    // so it should pick up the change on the next frame!
    // However, if we changed resolution (which we do in _processAndSendImage), it also picks it up dynamically.
    
    // So strictly speaking, we don't need to restart the camera controller unless we change the ResolutionPreset.
    // In _processAndSendImage, we are resizing manually, so we don't need to change CameraController preset.
    
    // But let's restart the stream just to be clean and reset any timers.
    await _controller?.stopImageStream();
    _isStreaming = false;
    _startImageStream();
  }

  Future<void> _switchCamera({CameraLensDirection? target, bool remoteRequest = false}) async {
    final effectiveTarget = target ??
        (_currentLens == CameraLensDirection.back
            ? CameraLensDirection.front
            : CameraLensDirection.back);
    final hasWebRtcLocal =
        _role == DeviceRole.BABY && _webrtcService?.localRenderer.srcObject != null;
    final hasRemote =
        _role == DeviceRole.PARENT && _webrtcService?.remoteRenderer.srcObject != null;
    final roomCode = _pairingState?.roomCode;

    if (_isOfflineMode) {
      if (_role == DeviceRole.PARENT && _connectedEndpointId != null) {
        // Send Switch Camera Command to Baby
        final payloadMap = {
          'type': 'SWITCH_CAMERA',
        };
        final payload =
            OfflinePayload.encodeJson(OfflinePayloadType.control, payloadMap);
        
        await Nearby().sendBytesPayload(_connectedEndpointId!, payload);
        
        // Optimistically update local state if needed, though for Parent in Offline mode 
        // we are just viewing the stream, so we don't track lens direction locally as much as Online mode.
        // But we can toggle the UI state if we want.
        setState(() {
          _currentLens = effectiveTarget;
        });
        return;
      }
      // If Baby (Offline), fall through to local switch
    }

    if (_role == DeviceRole.PARENT && roomCode != null) {
      final facingMode =
          effectiveTarget == CameraLensDirection.front ? 'user' : 'environment';
      try {
        await _pairingService?.setFacing(roomCode, facingMode);
        if (!mounted) return;
        setState(() {
          _currentLens = effectiveTarget;
        });
      } catch (e) {
        if (!mounted) return;
        _messenger?.showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
      return;
    }

    if ((hasWebRtcLocal || hasRemote) && roomCode != null) {
      final facingMode =
          effectiveTarget == CameraLensDirection.front ? 'user' : 'environment';
      try {
        await _webrtcService!.switchCamera(
          roomCode,
          facingMode: facingMode,
          remoteRequest: remoteRequest || _role == DeviceRole.PARENT,
        );
        if (!mounted) return;
        setState(() {
          _currentLens = effectiveTarget;
        });
        unawaited(_pairingService?.setFacing(roomCode, facingMode).catchError(
            (Object e) => debugPrint('setFacing failed: $e')));
      } catch (e) {
        if (!mounted) return;
        _messenger?.showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
      return;
    }

    await _initControllerForLens(effectiveTarget);
  }

  Future<void> _startNoiseMonitoring() async {
    if (_isOfflineMode) {
      // In Offline Mode, noise monitoring is handled by _startAudioStream automatically
      return;
    }

    if (_listeningNoise) return;

    // During a call: WebRTC stats (no second microphone reader next to
    // WebRTC; that conflicted on devices like Redmi Note 9 Pro). In standby
    // WebRTC does not capture, so our own meter runs instead (onBabyStandby /
    // beforeBabyCall switch between the two).
    _noisePollTimer?.cancel();
    _noisePollTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) async {
      // Debug builds only: integration tests can inject a "fake cry" level.
      final fakeDb = DebugHooks.fakeNoiseDb;
      if (fakeDb != null) {
        _processNoiseLevel(fakeDb);
        return;
      }
      if (_standbyMicActive) {
        // Standby: loudest chunk of our own microphone since the last tick.
        final db = _standbyPeak.take();
        if (db != null) _processNoiseLevel(db);
        return;
      }
      if (_webrtcService == null) return;
      final level = await _webrtcService!.getAudioLevel();
      if (level != null) {
        // Linear 0..1 -> 20*log10(level) + 100, clamped to 0..120.
        _processNoiseLevel(webrtcAudioLevelToDb(level));
      }
    });

    if (mounted) {
      setState(() {
        _listeningNoise = true;
      });
    }
  }

  Future<void> _stopNoiseMonitoring() async {
    // The standby meter can be running before monitoring started.
    await _stopStandbyMic();
    if (!_listeningNoise) return;
    _noisePollTimer?.cancel();
    _noisePollTimer = null;

    if (mounted) {
      setState(() {
        _listeningNoise = false;
        _noiseAlert = false;
        _currentDecibel = 0.0;
      });
    }
  }

  Future<void> _recordAlertIfNeeded(double? db) async {
    final now = DateTime.now();
    // Record at most one history entry per cry notification window (was every
    // 5 s, up to ~720 entries per hour of crying; B29).
    if (_lastRecordedAlertTime == null || 
        now.difference(_lastRecordedAlertTime!) > _cryNotificationCooldown) {
      _lastRecordedAlertTime = now;
      if (!mounted) return;
      final message = l10n.babyCryAlert;
      await AlertHistoryService().addAlert(AlertModel(
        timestamp: now,
        message: message,
        decibel: db,
      ));
    }
  }

  void _processNoiseLevel(double db) {
    final now = DateTime.now();
    final bool alert = _cryDetector.update(db, now);

    if (_role == DeviceRole.BABY) {
      setState(() {
        _currentDecibel = db;
        _noiseAlert = false;
      });
      final roomCode = _pairingState?.roomCode;
      
      // Online Mode Logic:
      // 1. Always send if Alert status changed (Quiet <-> Crying)
      // 2. If Crying (Alert=true), send every 2 seconds to keep alert fresh
      // 3. If Quiet (Alert=false), send every 2 seconds to keep the bar moving (Liveness)
      //    (Previously it was only sending if Alert=true, causing "passive bar")
      
      final bool statusChanged = alert != _lastCryAlertSent;
      final bool timeToUpdate = _lastCrySentAt == null || 
          now.difference(_lastCrySentAt!) > _cryStateUpdateInterval;

      if (roomCode != null && _pairingService != null && (statusChanged || timeToUpdate)) {
        _lastCryAlertSent = alert;
        _lastCrySentAt = now;
        unawaited(
          _pairingService!.setCryAlert(
            roomCode,
            alert: alert,
            decibel: db,
          ).catchError((Object e) => debugPrint('Cry state update failed: $e')),
        );

        if (alert && _takeCryNotificationSlot(now)) {
          unawaited(HybridNotificationManager().sendAlert(
            l10n.babyCryAlert,
            '${l10n.noiseLevel}: ${db.toStringAsFixed(1)} dB',
            db: db,
          ).catchError((Object e) => debugPrint('Sending cry alert failed: $e')));
        }
      }
      return;
    }

    setState(() {
      _currentDecibel = db;
      _noiseAlert = alert;
    });
  }

  Future<void> _setKeepScreenOn(bool value) async {
    setState(() => _keepScreenOn = value);
    if (value) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }


  /// Night mode (D1-a): black full-screen layer, minimum app brightness and a
  /// wakelock, while streaming continues underneath. Baby device only.
  Future<void> _enterNightMode() async {
    if (!mounted || _nightMode || _role != DeviceRole.BABY) return;
    setState(() => _nightMode = true);
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('Wakelock enable failed: $e');
    }
    try {
      // Only this app's window; the system brightness setting is untouched.
      await ScreenBrightness.instance.setApplicationScreenBrightness(0.0);
    } catch (e) {
      debugPrint('Setting brightness failed: $e');
    }
  }

  Future<void> _exitNightMode() async {
    if (!_nightMode) return;
    if (mounted) {
      setState(() => _nightMode = false);
    } else {
      _nightMode = false;
    }
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (e) {
      debugPrint('Resetting brightness failed: $e');
    }
    // Keep the wakelock while broadcasting or if the user asked for it.
    if (!_keepScreenOn && _pairingState == null) {
      try {
        await WakelockPlus.disable();
      } catch (e) {
        debugPrint('Wakelock disable failed: $e');
      }
    }
  }

  void _maybeEnterAutoNightMode() {
    if (_autoNightMode && _role == DeviceRole.BABY && !_nightMode) {
      unawaited(_enterNightMode());
    }
  }

  void _listenRoomUpdates(String roomCode) {
    _roomSub?.cancel();
    _roomSub = _pairingService?.watchRoom(roomCode).listen((roomState) {
      if (!mounted) return;
      setState(() {
        if (_pairingState != null && _pairingState!.roomCode == roomCode) {
          _pairingState = _pairingState!.copyWith(
            isPaired: roomState.isPaired,
            status: roomState.status,
            facingMode: roomState.facingMode,
            errorMessage: roomState.errorMessage,
            cryAlert: roomState.cryAlert,
            cryDecibel: roomState.cryDecibel,
            cryUpdatedAt: roomState.cryUpdatedAt,
            videoSettings: roomState.videoSettings,
          );
        }
      });

      // Threshold set on the other device (calibration, D5)
      final remoteThreshold = roomState.noiseThreshold;
      if (remoteThreshold != null) {
        _setNoiseThreshold(remoteThreshold, fromRemote: true);
      }

      // Check for settings update
      if (_role == DeviceRole.BABY) {
        if (roomState.videoSettings.fps != _videoSettings.fps || 
            roomState.videoSettings.quality != _videoSettings.quality) {
             _applyRemoteSettings(roomState.videoSettings);
        }
      } else if (_role == DeviceRole.PARENT) {
        // Sync local UI state with remote if changed by other parent or baby
        if (roomState.videoSettings.fps != _videoSettings.fps || 
            roomState.videoSettings.quality != _videoSettings.quality) {
             setState(() {
               _videoSettings = roomState.videoSettings;
             });
        }
      }

      if (_role == DeviceRole.BABY) {
        // A parent joined (new session) or left (null): renegotiate (B08).
        unawaited(_webrtcService?.onViewerSessionChanged(roomState.viewerSession));
      }

      if (_role == DeviceRole.BABY) {
        final targetLens = roomState.facingMode == 'user'
            ? CameraLensDirection.front
            : CameraLensDirection.back;
        if (targetLens != _currentLens) {
          unawaited(_switchCamera(target: targetLens, remoteRequest: true));
        }
      }
      if (_role == DeviceRole.PARENT) {
        final battery = roomState.battery;
        if (battery != null) {
          setState(() => _onRemoteBattery(battery.level, battery.charging));
        }
        final updatedAt = roomState.cryUpdatedAt;
        final isFresh =
            updatedAt == null || DateTime.now().difference(updatedAt) < const Duration(seconds: 20);
        final remoteAlert = roomState.cryAlert && isFresh;
        setState(() {
          _noiseAlert = remoteAlert;
          if (roomState.cryDecibel != null) {
            _currentDecibel = roomState.cryDecibel!;
          }
        });
        _onRemoteCryState(remoteAlert, roomState.cryDecibel);
      }
      }, onError: (Object e) {
      // e.g. Firestore permission or network errors (B23)
      debugPrint('Room listener error: $e');
      if (!mounted) return;
      // With the security rules, a deleted (or expired) room is no longer
      // readable, so its listener ends with permission-denied rather than an
      // empty snapshot (B57): tell the user the room was closed.
      if (e is FirebaseException && e.code == 'permission-denied') {
        if (_role == DeviceRole.PARENT) {
          _viewerSession = null;
          _rejoinTimer?.cancel();
          _stopWatchdog();
        }
        _handlePairingError(l10n.roomClosed);
        return;
      }
      _handlePairingError('${l10n.error}: $e');
    });
  }


  /// User-facing text for room create/join errors (D3).
  String _pairingErrorText(Object e) {
    if (e is RoomUnavailableException) return l10n.roomUnavailable;
    if (e is AnonymousAuthDisabledException) return l10n.anonymousAuthDisabled;
    if (e is PairingTimeoutException) return l10n.noServerResponse;
    return '${l10n.error}: $e';
  }

  /// Parent: stores this device's FCM token and UI language in the room so
  /// the Cloud Function can push cry alerts while the app is closed (D2).
  Future<void> _registerPushToken(String roomCode, {String? token}) async {
    final pairing = _pairingService;
    if (pairing == null || _isOfflineMode) return;
    final pushToken = token ?? await HybridNotificationManager().getPushToken();
    if (pushToken == null) {
      debugPrint('Push: no FCM token, push notifications will not arrive');
      return;
    }
    if (!mounted) return;
    final locale = _locale().languageCode;
    try {
      await pairing.setViewerPushToken(roomCode, pushToken, locale);
      debugPrint('Push: FCM token stored in room $roomCode');
    } catch (e) {
      debugPrint('Storing push token failed: $e');
    }
  }

  /// Parent: notification permission is needed for cry alerts. Asked when
  /// the parent role is used (not at app start), with a hint if denied (B42).
  Future<void> _ensureNotificationPermission() async {
    final granted = await HybridNotificationManager().requestPermission();
    if (granted || !mounted || _notificationPermissionWarned) return;
    _notificationPermissionWarned = true;
    _messenger?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        persist: false,
        content: Text(l10n.notificationsPermissionRequired),
        action: SnackBarAction(label: l10n.settings, onPressed: () => openAppSettings()),
      ),
    );
  }

  void _startRoomHeartbeat(String roomCode) {
    _roomHeartbeat?.cancel();
    _roomHeartbeat = Timer.periodic(const Duration(hours: 1), (_) {
      final pairing = _pairingService;
      if (pairing == null || _pairingState?.roomCode != roomCode) return;
      unawaited(pairing.extendExpiry(roomCode).catchError(
          (Object e) => debugPrint('Extending room expiry failed: $e')));
    });
  }

  Future<void> _toggleRecording() async {
    try {
      if (_recorderService.isRecording) {
        // Stop Recording (whichever kind is running, even if the mode changed)
        await _recorderService.stopAny();
        if (mounted) {
          setState(() {});
          _messenger?.showSnackBar(SnackBar(
            content: Text(_recorderService.lastStopDroppedNoFrames
                ? l10n.recordingNoPicture
                : l10n.recordingSaved),
          ));
        }
      } else {
        // Start Recording
        // Request permissions
        await [
          Permission.storage,
          Permission.photos,
          Permission.manageExternalStorage, // For Android 11+ sometimes needed
        ].request();

        // Basic check, gal handles most.
        
        if (_isOfflineMode) {
          await _recorderService.startOfflineRecording();
          if (mounted) {
            final seconds = VideoRecorderService.offlineMaxDuration.inSeconds;
            _messenger?.showSnackBar(
              SnackBar(content: Text('${l10n.offlineRecordingInfo}: $seconds s')),
            );
          }
        } else {
          final stream = _webrtcService?.remoteRenderer.srcObject;
          if (stream != null) {
            await _recorderService.startWebRTCRecording(stream,
                framesProbe: () async => await _webrtcService?.getInboundVideoFrames());
          } else {
            if (mounted) {
              _messenger?.showSnackBar(
                SnackBar(content: Text(l10n.noRecordsFound)),
              );
            }
            return;
          }
        }
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Recording error: $e');
      if (mounted) {
        _messenger?.showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    }
  }

  /// Offline recordings end automatically at their length limit (D7).
  Future<void> _stopOfflineRecordingAtLimit() async {
    if (!_recorderService.isRecording) return;
    try {
      await _recorderService.stopAny();
    } catch (e) {
      debugPrint('Stopping offline recording at limit failed: $e');
    }
    if (!mounted) return;
    setState(() {});
    _messenger?.showSnackBar(
      SnackBar(content: Text(l10n.offlineRecordingLimitReached)),
    );
  }

  // ---------------------------------------------------------------------------
  // V2: parent cry alarm (full screen, §3.8) and snooze (5.8)
  // ---------------------------------------------------------------------------

  /// Parent: cry state from the baby (room field or Nearby status). A new cry
  /// opens the full-screen alarm with sound and vibration unless snoozed; the
  /// screen stays until the parent reacts, the sound stops with the cry.
  void _onRemoteCryState(bool alert, double? db) {
    if (_role != DeviceRole.PARENT) return;
    final now = DateTime.now();
    if (alert && !_cryActive) {
      _cryActive = true;
      _cryStartedAt = now;
      _cryPeakDb = db;
      unawaited(_recordAlertIfNeeded(db));
      final snoozed = _crySnoozedUntil != null && now.isBefore(_crySnoozedUntil!);
      if (!snoozed) {
        _cryAlarmVisible = true;
        unawaited(HapticFeedback.heavyImpact());
        unawaited(_cryAlarmSound.start());
      }
      _notify();
    } else if (alert && _cryActive) {
      if (db != null && db > (_cryPeakDb ?? 0)) {
        _cryPeakDb = db;
        _notify();
      }
    } else if (!alert && _cryActive) {
      _cryActive = false;
      unawaited(_cryAlarmSound.stop());
      final started = _cryStartedAt;
      if (started != null) {
        unawaited(AlertHistoryService()
            .finishLastAlert(now.difference(started))
            .catchError((Object e) => debugPrint('Alert duration not saved: $e')));
      }
      _notify();
    }
  }

  void _notify() {
    if (!_disposing) notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Public API for the screens
  // ---------------------------------------------------------------------------

  /// Null until the user chose a role (role screen).
  DeviceRole? get role => _roleChosen ? _role : null;
  bool get isBaby => _role == DeviceRole.BABY;
  bool get isOffline => _isOfflineMode;
  static bool get offlineSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  ConnectionStatus get connectionStatus => _connectionStatus;
  bool get isConnected => _connectionStatus == ConnectionStatus.CONNECTED;
  PairingState? get pairingState => _pairingState;
  /// Online room code (null offline or before a room exists).
  String? get roomCode => _isOfflineMode ? null : _pairingState?.roomCode;
  /// Broadcasting (baby) or joined (parent).
  bool get isActive => _pairingState != null;
  bool get pairingBusy => _pairingBusy;
  String? get pairingError => _pairingError;
  bool get firebaseReady => _firebaseReady;
  bool get parentEverConnected => _parentEverConnected;

  CameraController? get cameraController => _controller;
  bool get cameraInitializing => _initializing;
  bool get hasCameraPermission => _hasCamPermission;
  String? get cameraMessage => _message;
  bool get frontCamera => _currentLens == CameraLensDirection.front;
  RTCVideoRenderer? get localRenderer => _webrtcService?.localRenderer;
  RTCVideoRenderer? get remoteRenderer => _webrtcService?.remoteRenderer;
  bool get hasLocalVideo => _webrtcService?.localRenderer.srcObject != null;
  bool get hasRemoteVideo => _webrtcService?.remoteRenderer.srcObject != null;
  ValueListenable<Uint8List?> get offlineFrame => _currentImageBytesNotifier;

  double get decibel => _currentDecibel;
  bool get noiseAlert => _noiseAlert;
  bool get listeningNoise => _listeningNoise;
  double get noiseThreshold => _noiseThreshold;

  int get batteryLevel => _batteryLevel;
  bool get batteryCharging => _isCharging(_batteryState);
  int? get remoteBatteryLevel => _remoteBatteryLevel;
  bool get remoteBatteryCharging => _remoteBatteryState == BatteryState.charging;
  bool get showBatteryWarning => _showBatteryWarning && _role == DeviceRole.PARENT;

  bool get isRecording => _recorderService.isRecording;
  bool get nightMode => _nightMode;
  bool get autoNightMode => _autoNightMode;
  bool get keepScreenOn => _keepScreenOn;
  bool get backgroundListening => _backgroundListening;
  VideoSettings get videoSettings => _videoSettings;

  bool get connectionLost => _connectionLost && _role == DeviceRole.PARENT;
  DateTime? get connectionLostSince => _connectionLostSince;
  bool get connectionAlarmSilenced => _connectionAlarmSilenced;

  bool get cryAlarmVisible => _cryAlarmVisible && _role == DeviceRole.PARENT;
  bool get babyCrying => _cryActive;
  DateTime? get cryStartedAt => _cryStartedAt;
  double? get cryPeakDb => _cryPeakDb;
  DateTime? get crySnoozedUntil {
    final until = _crySnoozedUntil;
    return (until != null && DateTime.now().isBefore(until)) ? until : null;
  }
  /// Time of the last cry alarm in this session (parent live card).
  DateTime? get lastAlertAt => _lastRecordedAlertTime;

  DateTime? get roomCreatedAt => _roomCreatedAt;

  /// Room name given on the baby phone (V2 5.2); null until set.
  String? get roomName => null;

  /// Night light color on the baby phone (V2 5.5); null when off.
  Color? get nightLightColor => null;

  List<Map<String, String>> get discoveredEndpoints => List.unmodifiable(_discoveredEndpoints);
  bool get discovering => _discovering;

  /// Role screen: this phone becomes the baby or the parent device.
  Future<void> selectRole(DeviceRole role) async {
    if (_roleChosen && _role == role) return;
    if (_roleChosen) {
      await _resetPairing(
        deleteRoom: _role == DeviceRole.BABY && _pairingState != null,
        restoreCamera: false,
      );
    }
    setState(() {
      _role = role;
      _roleChosen = true;
      _parentEverConnected = false;
      _pairingError = null;
    });
    if (role == DeviceRole.PARENT) {
      unawaited(_ensureNotificationPermission());
      await _disposeCameraController();
      return;
    }
    // Baby: camera, then microphone (one prompt at a time, B12), then start.
    await _requestBabyPermissions();
    await _coreReady;
    if (!mounted || _role != DeviceRole.BABY || !_roleChosen) return;
    await startBroadcast();
    unawaited(_requestBatteryOptimization());
  }

  /// Back to the role screen (ends a broadcast / leaves the room).
  Future<void> leaveRole() async {
    await _resetPairing(
      deleteRoom: _role == DeviceRole.BABY && _pairingState != null,
      restoreCamera: false,
    );
    await _disposeCameraController();
    setState(() {
      _roleChosen = false;
      _parentEverConnected = false;
      _pairingError = null;
    });
  }

  Future<void> setOfflineMode(bool value) async {
    if (value == _isOfflineMode) return;
    if (value && !offlineSupported) return;
    setState(() => _isOfflineMode = value);
    await _resetPairing(restoreCamera: false);
    _coreReady = _initCoreServices();
    await _coreReady;
  }

  /// Baby: (re)creates the room code online or starts advertising offline.
  Future<void> startBroadcast() async {
    if (_isOfflineMode) {
      await _startAdvertising();
    } else {
      await _createRoomCode();
    }
  }

  Future<void> joinRoom(String code) async {
    await _coreReady;
    await _joinRoomWithCode(code);
  }

  Future<void> startDiscovery() async {
    setState(() => _discovering = true);
    await _startDiscovery();
  }

  Future<void> stopDiscovery() async {
    setState(() => _discovering = false);
    if (!offlineSupported) return;
    try {
      await Nearby().stopDiscovery();
    } catch (e) {
      debugPrint('Stopping discovery failed: $e');
    }
  }

  Future<void> connectToEndpoint(String id, String name) async {
    setState(() => _discovering = false);
    await _connectToEndpoint(id, name);
  }

  /// Parent: leave the room (back to the join screen). Baby: see [leaveRole].
  Future<void> disconnect() => _resetPairing(deleteRoom: _role == DeviceRole.BABY, restoreCamera: false);

  Future<void> switchCamera() => _switchCamera();
  Future<void> toggleRecording() => _toggleRecording();
  Future<void> enterNightMode() => _enterNightMode();
  Future<void> exitNightMode() => _exitNightMode();
  void setNoiseThreshold(double value) {
    _setNoiseThreshold(value);
    unawaited(_savePref((p) => p.setDouble(_thresholdKey, value)));
  }

  Future<void> setVideoSettings(VideoSettings settings) => _updateVideoSettings(settings);

  void setAutoNightMode(bool value) {
    setState(() => _autoNightMode = value);
    unawaited(_savePref((p) => p.setBool(_autoNightKey, value)));
  }

  Future<void> setKeepScreenOn(bool value) => _setKeepScreenOn(value);
  Future<void> setBackgroundListening(bool value) => _setBackgroundListening(value);
  void retryConnection() => _retryConnection();
  void silenceConnectionAlarm() => _silenceConnectionAlarm();
  void dismissBatteryWarning() => setState(() => _showBatteryWarning = false);

  /// Cry alarm "Tamam" / "Görüntüyü aç".
  void acknowledgeCryAlarm() {
    _cryAlarmVisible = false;
    unawaited(_cryAlarmSound.stop());
    _notify();
  }

  /// Cry alarm "5 dk sessize al" (V2 5.8): no alarm screen or sound until
  /// then; history and notifications continue.
  void snoozeCryAlarm([Duration duration = const Duration(minutes: 5)]) {
    _crySnoozedUntil = DateTime.now().add(duration);
    acknowledgeCryAlarm();
  }

  void cancelCrySnooze() {
    _crySnoozedUntil = null;
    _notify();
  }

  // Demo scenes ---------------------------------------------------------------

  /// Puts the controller into a fixed state for store screenshots and
  /// design checks (V2 phase 4). No streaming, no network: only the fields
  /// the screens read. Used by tool/screenshots_test.dart and, in builds
  /// with `--dart-define=NINNI_DEMO=<scene>`, by the app itself.
  @visibleForTesting
  void debugDemo(DemoScene scene) {
    final now = DateTime.now();
    _roleChosen = scene != DemoScene.roleSelect;
    _isOfflineMode = false;
    _pairingError = null;
    _pairingBusy = false;
    _batteryLevel = 76;
    _batteryState = BatteryState.charging;
    _noiseThreshold = 65;
    _cryDetector.threshold = 65;
    _listeningNoise = true;
    _cryActive = false;
    _cryAlarmVisible = false;
    _connectionLost = false;
    _firebaseReady = true;
    switch (scene) {
      case DemoScene.roleSelect:
        _pairingState = null;
      case DemoScene.babyPairing:
        _role = DeviceRole.BABY;
        _pairingState = PairingState(roomCode: 'K7MQT2H9', status: ConnectionStatus.CONNECTING);
        _roomCreatedAt = now.subtract(const Duration(seconds: 18));
        _connectionStatus = ConnectionStatus.CONNECTING;
        _parentEverConnected = false;
      case DemoScene.babyLive:
      case DemoScene.babyNight:
        _role = DeviceRole.BABY;
        _pairingState = PairingState(roomCode: 'K7MQT2H9', status: ConnectionStatus.CONNECTED, isPaired: true);
        _connectionStatus = ConnectionStatus.CONNECTED;
        _parentEverConnected = true;
        _currentDecibel = 42;
        _nightMode = scene == DemoScene.babyNight;
      case DemoScene.parentJoin:
        _role = DeviceRole.PARENT;
        _pairingState = null;
        _connectionStatus = ConnectionStatus.DISCONNECTED;
      case DemoScene.parentLive:
      case DemoScene.cryAlert:
      case DemoScene.connectionLost:
        _role = DeviceRole.PARENT;
        _pairingState = PairingState(roomCode: 'K7MQT2H9', status: ConnectionStatus.CONNECTED, isPaired: true);
        _connectionStatus = ConnectionStatus.CONNECTED;
        _remoteBatteryLevel = scene == DemoScene.connectionLost ? 9 : 76;
        _remoteBatteryState = BatteryState.discharging;
        _currentDecibel = scene == DemoScene.cryAlert ? 74 : 38;
        _noiseAlert = scene == DemoScene.cryAlert;
        _lastRecordedAlertTime = DateTime(now.year, now.month, now.day, 1, 12);
        if (scene == DemoScene.cryAlert) {
          _cryActive = true;
          _cryAlarmVisible = true;
          _cryStartedAt = now.subtract(const Duration(seconds: 6));
          _cryPeakDb = 74;
        }
        if (scene == DemoScene.connectionLost) {
          _connectionLost = true;
          _connectionLostSince = now.subtract(const Duration(seconds: 45));
        }
    }
    _notify();
  }

  // Preferences --------------------------------------------------------------

  static const String _autoNightKey = 'autoNightMode';
  static const String _thresholdKey = 'noiseThreshold';

  Future<void> _savePref(Future<bool> Function(SharedPreferences p) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (e) {
      debugPrint('Saving preference failed: $e');
    }
  }

  Future<void> _requestBabyPermissions() async {
    try {
      await Permission.camera.request();
      await Permission.microphone.request();
    } catch (e) {
      debugPrint('Permission request failed: $e');
    }
  }
}

// Top-level function for running heavy image processing in an isolate
Future<Uint8List> _processImageInIsolate(Map<String, dynamic> params) async {
  final width = params['width'] as int;
  final height = params['height'] as int;
  final yBytes = params['yPlane'] as Uint8List;
  final uBytes = params['uPlane'] as Uint8List;
  final vBytes = params['vPlane'] as Uint8List;
  final yRowStride = params['yRowStride'] as int;
  final uvRowStride = params['uvRowStride'] as int;
  final uvPixelStride = params['uvPixelStride'] as int;
  final angle = params['angle'] as int;
  final qualityStr = params['qualitySetting'] as String;

  // 1. YUV Conversion (Optimized)
  int step = 1;
  if (width > 640) step = 2;
  if (width > 1280) step = 4;

  final int outWidth = (width / step).ceil();
  final int outHeight = (height / step).ceil();

  final img.Image image = img.Image(width: outWidth, height: outHeight);

  for (int h = 0; h < height; h += step) {
    for (int w = 0; w < width; w += step) {
      final int uvIndex = uvPixelStride * (w / 2).floor() + uvRowStride * (h / 2).floor();
      final int index = h * yRowStride + w;

      if (index >= yBytes.length || uvIndex >= uBytes.length || uvIndex >= vBytes.length) continue;

      final y = yBytes[index];
      final u = uBytes[uvIndex];
      final v = vBytes[uvIndex];

      int r = (y + (1.370705 * (v - 128))).toInt();
      int g = (y - (0.337633 * (u - 128)) - (0.698001 * (v - 128))).toInt();
      int b = (y + (1.732446 * (u - 128))).toInt();

      r = r.clamp(0, 255);
      g = g.clamp(0, 255);
      b = b.clamp(0, 255);

      image.setPixelRgb((w / step).floor(), (h / step).floor(), r, g, b);
    }
  }

  img.Image processed = image;

  // 2. Rotation
  if (angle != 0) {
    processed = img.copyRotate(processed, angle: angle);
  }

  // 3. Resize
  if (qualityStr == 'LOW' && processed.width > 320) {
    processed = img.copyResize(processed, width: 320);
  } else if (qualityStr == 'MEDIUM' && processed.width > 480) {
    processed = img.copyResize(processed, width: 480);
  }

  // 4. Quality
  int jpegQuality = 50;
  switch (qualityStr) {
    case 'LOW': jpegQuality = 25; break;
    case 'MEDIUM': jpegQuality = 50; break;
    case 'HIGH': jpegQuality = 75; break;
  }

  return Uint8List.fromList(img.encodeJpg(processed, quality: jpegQuality));
}
