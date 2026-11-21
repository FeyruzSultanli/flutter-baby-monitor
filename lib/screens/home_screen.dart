import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';

import 'package:image/image.dart' as img;
import 'package:sound_stream/sound_stream.dart';

import '../l10n/app_localizations.dart';
import '../core/recording/video_recorder_service.dart';
import '../core/enums/connection_status.dart';
import '../core/enums/device_role.dart';
import '../core/feature_flags.dart';
import '../core/debug/debug_hooks.dart';
import '../core/audio/audio_level.dart';
import '../core/audio/cry_detector.dart';
import '../core/offline/offline_payload.dart';
import '../core/pairing/pairing_service.dart';
import '../core/pairing/pairing_state.dart';
import '../core/pairing/room_code.dart';
import '../core/auth/auth_service.dart';
import '../core/webrtc/signaling_interface.dart';
import '../core/webrtc/firestore_signaling.dart';
import '../models/alert_model.dart';
import '../core/alert_history_service.dart';
import 'alert_history_screen.dart';
import 'video_gallery_screen.dart';
import '../core/webrtc/reconnect_backoff.dart';
import '../core/webrtc/signaling_messages.dart';
import '../core/webrtc/webrtc_service.dart';
import '../core/services/hybrid_notification_manager.dart';
import '../widgets/camera_preview_card.dart';
import '../widgets/fullscreen_view.dart';
import '../widgets/night_mode_overlay.dart';
import '../widgets/noise_level_bar.dart';
import '../widgets/settings_sheet.dart';
import '../models/video_settings.dart';
import 'multi_camera_screen.dart';

enum _MenuAction {
  babyMode,
  parentMode,
  multiCameraMode,
  createRoomCode,
  joinRoomCode,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  CameraLensDirection _currentLens = CameraLensDirection.back;

  bool _initializing = false;
  bool _hasCamPermission = false;
  bool _previewPaused = false;
  String? _message;
  DeviceRole _role = DeviceRole.BABY;

  PairingService? _pairingService;
  WebRTCService? _webrtcService;
  PairingState? _pairingState;
  ConnectionStatus _connectionStatus = ConnectionStatus.DISCONNECTED;
  String? _pairingError;
  bool _pairingBusy = false;
  final TextEditingController _parentRoomController = TextEditingController();
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

  // Audio Streaming (Offline)
  final RecorderStream _recorder = RecorderStream();
  final PlayerStream _player = PlayerStream();
  StreamSubscription<List<int>>? _audioSub;
  bool _isAudioStreaming = false;
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

  bool _isFullscreen = false;
  bool _fullscreenCryOverlay = false;

  bool _keepScreenOn = false;
  bool _nightMode = false;
  // Enter night mode automatically once a parent connects (baby device, D1-a).
  bool _autoNightMode = false;

  void Function(void Function())? _bottomSheetSetState;
  BuildContext? _bottomSheetContext;
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

  late final AnimationController _alertController;

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

  @override
  void initState() {
    super.initState();
    _alertController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      lowerBound: 0.85,
      upperBound: 1.1,
    )..repeat(reverse: true);
    
    _pushTokenSub = HybridNotificationManager().onPushTokenRefresh.listen((token) {
      final roomCode = _pairingState?.roomCode;
      if (_role == DeviceRole.PARENT && _viewerSession != null && roomCode != null) {
        unawaited(_registerPushToken(roomCode, token: token));
      }
    }, onError: (Object e) => debugPrint('Push token refresh error: $e'));
    _recorderService.onOfflineLimitReached = () {
      unawaited(_stopOfflineRecordingAtLimit());
    };
    _initCoreServices();
    _initBatteryMonitoring();
    // Camera setup (CAMERA permission prompt) first, then audio services
    // (sound_stream asks for RECORD_AUDIO in initialize). Running both at once
    // can make Android drop one of the concurrent permission requests (B12).
    unawaited(_setup().whenComplete(_initAudioServices));
  }

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
    } else if (!_isOfflineMode && _pairingState?.roomCode != null) {
      // For online mode, we could use signaling or data channel. 
      // Since we don't have a dedicated data channel set up in this snippet for generic data,
      // we will skip online battery sync for now or implement it via Firestore if needed.
      // But let's assume we use the same WebRTC data channel if available.
      // For now, let's stick to Offline mode support as requested or add Firestore support.
      // Adding Firestore support for battery:
      if (_pairingService != null) {
         // We can add a field to the room document.
         // But for simplicity, let's just focus on Offline mode first as it's direct.
      }
    }
  }

  Future<void> _initAudioServices() async {
    try {
      await _recorder.initialize();
      await _player.initialize();
    } catch (e) {
      debugPrint('Audio services init error: $e');
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
          _message = '${AppLocalizations.of(context).camerasReadError}$e';
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
        _previewPaused = false;
      });
    }
    try {
      await oldController.dispose();
    } catch (e) {
      debugPrint('Camera dispose failed: $e');
    }
  }

  Future<void> _restoreCameraIfIdle() async {
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
        setState(() => _message = AppLocalizations.of(context).noCameraFound);
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
        _previewPaused = false;
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
        _message = '${AppLocalizations.of(context).cameraInitError}$e';
      });
    }
  }

  @override
  void dispose() {
    // Services stopped below report status changes synchronously (e.g.
    // WebRTCService.hangUp -> DISCONNECTED); `mounted` is still true during
    // dispose, so the handlers check this flag instead (B62).
    _disposing = true;
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
    unawaited(Future(() async {
      try {
        await _recorder.stop();
        await _player.stop();
      } catch (e) {
        debugPrint('Audio stream stop on dispose failed: $e');
      }
    }));
    if (_isOfflineMode) {
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
    _alertController.dispose();
    if (_role == DeviceRole.BABY && _pairingState?.roomCode != null) {
      unawaited(_pairingService?.closeRoom(_pairingState!.roomCode).catchError(
          (Object e) => debugPrint('Closing room on dispose failed: $e')));
    }
    _parentRoomController.dispose();
    _roomSub?.cancel();
    _webrtcService?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  List<PopupMenuEntry<_MenuAction>> _buildMenuItems() {
    final l10n = AppLocalizations.of(context);
    final items = <PopupMenuEntry<_MenuAction>>[
      PopupMenuItem(
        value: _MenuAction.babyMode,
        child: Text(l10n.babyMode),
      ),
      PopupMenuItem(
        value: _MenuAction.parentMode,
        child: Text(l10n.parentMode),
      ),
      if (kMultiCameraEnabled)
        PopupMenuItem(
          value: _MenuAction.multiCameraMode,
          child: Text(l10n.multiCameraMode),
        ),
      const PopupMenuDivider(),
    ];

    if (_role == DeviceRole.BABY) {
      items.add(
        PopupMenuItem(
          value: _MenuAction.createRoomCode,
          child: Text(_isOfflineMode ? l10n.startBroadcastOffline : l10n.createRoomCode),
        ),
      );
    } else {
      items.add(
        PopupMenuItem(
          value: _MenuAction.joinRoomCode,
          child: Text(_isOfflineMode ? l10n.searchDeviceOffline : l10n.enterRoomCode),
        ),
      );
    }

    return items;
  }

  void _onMenuActionSelected(_MenuAction action) {
    switch (action) {
      case _MenuAction.babyMode:
        _switchRole(DeviceRole.BABY);
        break;
      case _MenuAction.parentMode:
        _switchRole(DeviceRole.PARENT);
        break;
      case _MenuAction.multiCameraMode:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MultiCameraScreen()),
        );
        break;
      case _MenuAction.createRoomCode:
        if (_isOfflineMode) {
          _startAdvertising();
        } else {
          _createRoomCode();
          _showPairingSheet(forBaby: true);
        }
        break;
      case _MenuAction.joinRoomCode:
        if (_isOfflineMode) {
          _startDiscovery();
        } else {
          _showPairingSheet(forBaby: false);
        }
        break;
    }
  }

  Future<void> _switchRole(DeviceRole role) async {
    if (_role == role) return;
    final previousRoom = _pairingState?.roomCode;
    await _resetPairing(
      deleteRoom: _role == DeviceRole.BABY && previousRoom != null,
      restoreCamera: role == DeviceRole.BABY,
    );
    if (!mounted) return;
    setState(() {
      _role = role;
    });
    if (role == DeviceRole.PARENT) {
      unawaited(_ensureNotificationPermission());
      await _disposeCameraController();
    } else {
      unawaited(_restoreCameraIfIdle());
      unawaited(_requestBatteryOptimization());
    }
  }

  void _handleConnectionStatus(ConnectionStatus status) {
    if (!mounted || _disposing) return;
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
    _refreshBottomSheet();
    if (status == ConnectionStatus.CONNECTED) {
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
      if (mounted) _handlePairingError(AppLocalizations.of(context).roomClosed);
    } on AnonymousAuthDisabledException {
      // Retrying cannot help until sign-in is enabled in the console (B60).
      _viewerSession = null;
      if (mounted) _handlePairingError(AppLocalizations.of(context).anonymousAuthDisabled);
    } catch (e) {
      debugPrint('Rejoin failed: $e');
      if (token == _joinToken) _scheduleRejoin();
    }
  }

  void _handlePairingError(String message) {
    if (!mounted || _disposing) return;
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
    _refreshBottomSheet();
    ScaffoldMessenger.of(context).showSnackBar(
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
              AppLocalizations.of(context).firebaseConfigMissing;
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
        _pairingError = '${AppLocalizations.of(context).pairingInitError}$e';
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
    
    // Dispose P2P
    try {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
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
    setState(() {
      _pairingState = null;
      _pairingError = null;
      _connectionStatus = ConnectionStatus.DISCONNECTED;
      _pairingBusy = false;
    });
    _lastCryAlertSent = false;
    _lastCrySentAt = null;
    _lastCryNotificationAt = null;
    _cryDetector.reset();
    _refreshBottomSheet();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context).roomCreationErrorFirebase),
          ),
        );
      }
      _refreshBottomSheet();
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
      _listenRoomUpdates(newCode);
      _startRoomHeartbeat(newCode);
      await _webrtcService!.startAsBaby(newCode, facingMode: facingMode);
      
      // Automatically start noise monitoring for Online Mode
      await _startNoiseMonitoring();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).roomCode}: ${RoomCode.format(newCode)}')),
      );
      // iOS stops the camera as soon as the app leaves the foreground, so
      // suggest night mode (screen stays on, black) for the baby phone.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _pairingBusy = false);
      }
      await _restoreCameraIfIdle();
    }
    _refreshBottomSheet();
  }

  Future<void> _joinRoomWithCode([String? code]) async {
    if (_pairingBusy) return;
    if (_role != DeviceRole.PARENT) return;
    if (_pairingService == null || _webrtcService == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context).firebaseConfigMissing)),
        );
      }
      _refreshBottomSheet();
      return;
    }
    final roomCode = RoomCode.normalize(code ?? _parentRoomController.text);
    if (roomCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).enterRoomCodeSubtitle)),
      );
      _refreshBottomSheet();
      return;
    }

    FocusScope.of(context).unfocus();
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
    unawaited(Navigator.of(context).maybePop());
    _refreshBottomSheet();

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).waitingForConnection}: $roomCode')),
      );
    } catch (e) {
      if (!mounted) return;
      // A code that cannot be joined is final: no automatic rejoin.
      if (e is RoomUnavailableException) _viewerSession = null;
      final message = _pairingErrorText(e);
      setState(() {
        _pairingError = message;
        _connectionStatus = ConnectionStatus.FAILED;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _pairingBusy = false);
      }
    }
    _refreshBottomSheet();
  }

  Future<void> _requestBatteryOptimization() async {
    if (!Platform.isAndroid) return;
    
    // Check if optimization is already ignored
    var status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) return;

    // Show dialog to explain why we need this
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    
    final bool? shouldRequest = await showDialog<bool>(
      context: context,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).permissionDenied),
            action: SnackBarAction(
              label: AppLocalizations.of(context).settings,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).offlineAndroidOnly)),
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
            roomCode: AppLocalizations.of(context).startBroadcastOffline,
            status: ConnectionStatus.CONNECTING,
            facingMode: 'environment',
          );
          _connectionStatus = ConnectionStatus.CONNECTING;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).waitingForConnection)),
        );
        // Initialize camera if not already
        if (_controller == null || !_controller!.value.isInitialized) {
          await _initControllerForLens(CameraLensDirection.back);
        }
        await WakelockPlus.enable(); // Keep screen on for Wifi Direct
      } else {
        throw Exception("Advertising failed to start");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pairingError = 'P2P ${AppLocalizations.of(context).error}: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _pairingBusy = false);
      }
    }
    _refreshBottomSheet();
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
    
    try {
      _audioSub = _recorder.audioStream.listen((data) {
        if (_connectedEndpointId != null) {
          // 1. Send Audio Data
          final payload = OfflinePayload.encode(OfflinePayloadType.audio, data);
          Nearby().sendBytesPayload(_connectedEndpointId!, payload);

          // 2. Calculate dB and Send Status
          _calculateAndSendDb(data);
        }
      });
      
      await _recorder.start();
      _isAudioStreaming = true;
    } catch (e) {
      debugPrint("Error starting audio stream: $e");
    }
  }

  void _stopAudioStream() {
    _audioSub?.cancel();
    _audioSub = null;
    _recorder.stop();
    _isAudioStreaming = false;
  }

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
    _showDeviceSelectionDialog();

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
          }
        },
        onEndpointLost: (id) {
          _discoveredEndpoints.removeWhere((e) => e['id'] == id);
          _discoveryStreamController.add(List.from(_discoveredEndpoints));
        },
        serviceId: "com.example.bebek_monitor",
      );
      
      if (a) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).searchDeviceOffline)),
        );
      }
    } catch (e) {
      debugPrint("Discovery error: $e");
    }
  }

  void _showDeviceSelectionDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.searchDeviceOffline),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: StreamBuilder<List<Map<String, String>>>(
              stream: _discoveryStreamController.stream,
              initialData: _discoveredEndpoints,
              builder: (context, snapshot) {
                final devices = snapshot.data ?? [];
                if (devices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(l10n.loading),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return ListTile(
                      leading: const Icon(Icons.phone_android),
                      title: Text(device['name'] ?? l10n.unknownDevice),
                      subtitle: Text(device['id'] ?? ""),
                      onTap: () {
                        Navigator.of(context).pop();
                        _connectToEndpoint(device['id']!, device['name']!);
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Nearby().stopDiscovery();
                Navigator.of(context).pop();
              },
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
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
    
    ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text('$name: ${AppLocalizations.of(context).waitingForConnection}')),
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
          roomCode: "${AppLocalizations.of(context).connected} (Offline)",
          status: ConnectionStatus.CONNECTED,
          facingMode: 'environment',
        );
      });
      
      if (_role == DeviceRole.BABY) {
        _startImageStream();
        _startAudioStream();
        _maybeEnterAutoNightMode();
        // The baby's threshold is the active one; tell the new parent.
        unawaited(_syncNoiseThreshold());
      } else if (_role == DeviceRole.PARENT) {
        // Ensure player is initialized but DO NOT start yet.
        // We will start it when the first audio packet arrives to avoid buffer underrun.
        // Note: We do NOT use Helper.setSpeakerphoneOn(true) here for Offline mode
        // because sound_stream uses STREAM_MUSIC which naturally plays on the speaker.
        // Using WebRTC's Helper might switch mode to IN_COMMUNICATION which can mute MUSIC stream on some devices.
        _player.initialize().then((_) {
          _player.stop(); // Reset state
          _isPlayerRunning = false;
        });
      }
    } else {
      setState(() {
        _connectedEndpointId = null;
        _connectionStatus = ConnectionStatus.FAILED;
      });
    }
    _refreshBottomSheet();
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
      _player.stop();
      _isPlayerRunning = false;
    }
    _refreshBottomSheet();
  }

  void _onPayloadReceived(Uint8List bytes) {
    // Payloads already queued by Nearby can still arrive after dispose (B25).
    if (!mounted) return;
    final message = OfflinePayload.decode(bytes);
    if (message == null) return;

    final type = message.type;
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
           
           setState(() {
             _currentDecibel = db;
             _noiseAlert = alert;
           });
           
           if (alert && !_fullscreenCryOverlay) {
              _recordAlertIfNeeded(db);
              if (_takeCryNotificationSlot(DateTime.now())) {
                HybridNotificationManager().showLocalNotification(
                  title: AppLocalizations.of(context).babyCryAlert,
                  body: '${AppLocalizations.of(context).noiseLevel}: ${db.toStringAsFixed(1)} dB'
                );
              }
              setState(() {
                _fullscreenCryOverlay = true;
              });
              try {
                Vibration.vibrate(duration: 1000);
              } catch (_) {}
              Timer(const Duration(seconds: 2), () {
                if (!mounted) return;
                setState(() {
                  _fullscreenCryOverlay = false;
                });
              });
           } else if (!alert) {
             setState(() {
               _fullscreenCryOverlay = false;
             });
           }
        }
      } catch (e) {
        debugPrint("Error parsing payload: $e");
      }
    } else if (type == OfflinePayloadType.audio) {
      // Audio Data
      if (_role == DeviceRole.PARENT) {
        if (!_isPlayerRunning) {
          _player.start();
          _isPlayerRunning = true;
        }
        _player.writeChunk(message.body);
      }
    } else if (type == OfflinePayloadType.battery) {
      // Battery Data
      try {
        final map = message.decodeJson();
        if (map['type'] == 'BATTERY') {
          setState(() {
            _remoteBatteryLevel = map['level'];
            final stateStr = map['state'] as String;
            _remoteBatteryState = BatteryState.values.firstWhere(
              (e) => e.toString() == stateStr,
              orElse: () => BatteryState.unknown,
            );
          });
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).videoSettingsUpdated}: ${settings.fps} FPS, ${settings.quality}')),
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

  Future<void> _togglePreview() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      if (_previewPaused) {
        await _controller!.resumePreview();
      } else {
        await _controller!.pausePreview();
      }
      setState(() => _previewPaused = !_previewPaused);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context).error}: $e')));
      }
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).error}: $e')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).error}: $e')),
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

    // Use WebRTC stats polling instead of a separate mic reader (e.g. noise_meter) to avoid mic conflict on devices like Redmi Note 9 Pro
    _noisePollTimer?.cancel();
    _noisePollTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) async {
      // Debug builds only: integration tests can inject a "fake cry" level.
      final fakeDb = DebugHooks.fakeNoiseDb;
      if (fakeDb != null) {
        _processNoiseLevel(fakeDb);
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
      final message = AppLocalizations.of(context).babyCryAlert;
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
            AppLocalizations.of(context).babyCryAlert,
            '${AppLocalizations.of(context).noiseLevel}: ${db.toStringAsFixed(1)} dB',
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

    if (_role == DeviceRole.PARENT &&
        _isFullscreen &&
        alert &&
        !_fullscreenCryOverlay) {
      setState(() {
        _fullscreenCryOverlay = true;
      });

      try {
        Vibration.vibrate(duration: 1000);
      } catch (_) {}

      Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() {
          _fullscreenCryOverlay = false;
        });
      });
    }
  }

  String _connectionStatusLabel() {
    final l10n = AppLocalizations.of(context);
    switch (_connectionStatus) {
      case ConnectionStatus.DISCONNECTED:
        return l10n.disconnected;
      case ConnectionStatus.CONNECTING:
        return l10n.waitingForConnection;
      case ConnectionStatus.CONNECTED:
        return l10n.connected;
      case ConnectionStatus.FAILED:
        return l10n.error;
    }
  }

  Color _connectionStatusColor(ColorScheme scheme) {
    switch (_connectionStatus) {
      case ConnectionStatus.CONNECTED:
        return scheme.primary;
      case ConnectionStatus.CONNECTING:
        return scheme.tertiary;
      case ConnectionStatus.FAILED:
        return scheme.error;
      case ConnectionStatus.DISCONNECTED:
        return scheme.outline;
    }
  }

  Future<void> _setKeepScreenOn(bool value) async {
    setState(() => _keepScreenOn = value);
    if (value) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }

  void _toggleNightMode() {
    if (_nightMode) {
      unawaited(_exitNightMode());
    } else {
      unawaited(_enterNightMode());
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
        if (remoteAlert && !_fullscreenCryOverlay) {
          _recordAlertIfNeeded(roomState.cryDecibel);
          setState(() {
            _fullscreenCryOverlay = true;
          });
          try {
            Vibration.vibrate(duration: 1000);
          } catch (_) {}
          Timer(const Duration(seconds: 2), () {
            if (!mounted) return;
            setState(() {
              _fullscreenCryOverlay = false;
            });
          });
        }
        if (!remoteAlert) {
          setState(() {
            _fullscreenCryOverlay = false;
          });
        }
      }
      _refreshBottomSheet();
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
        }
        _handlePairingError(AppLocalizations.of(context).roomClosed);
        return;
      }
      _handlePairingError('${AppLocalizations.of(context).error}: $e');
    });
  }

  void _enterFullscreen() {
    unawaited(_exitNightMode());
    setState(() {
      _isFullscreen = true;
    });
  }

  void _exitFullscreen() {
    setState(() {
      _isFullscreen = false;
      _fullscreenCryOverlay = false;
    });
  }

  String _formatRoomCode(String code) => RoomCode.format(code);

  /// User-facing text for room create/join errors (D3).
  String _pairingErrorText(Object e) {
    final l10n = AppLocalizations.of(context);
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
    if (pushToken == null || !mounted) return;
    final locale = Localizations.localeOf(context).languageCode;
    try {
      await pairing.setViewerPushToken(roomCode, pushToken, locale);
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
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
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

  void _refreshBottomSheet() {
    final fn = _bottomSheetSetState;
    // The closing sheet can rebuild during its exit animation and register
    // its setState again after whenComplete cleared it; once it is disposed
    // that setState must not be called (B61).
    if (fn == null || !(_bottomSheetContext?.mounted ?? false)) {
      _bottomSheetSetState = null;
      _bottomSheetContext = null;
      return;
    }
    fn(() {});
  }

  Widget _buildConnectionBadge(ColorScheme scheme) {
    final color = _connectionStatusColor(scheme);
    return Container(
      key: const Key('connectionBadge'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_tethering, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '${AppLocalizations.of(context).connectionStatus}: ${_connectionStatusLabel()}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _babyPairingContent(ColorScheme scheme, double gap) {
    final roomCode = _pairingState?.roomCode;
    final hasStream = (_webrtcService?.localRenderer.srcObject != null) || _isStreaming;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.babyMode} - ${l10n.roomCode}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    roomCode != null
                        ? '${l10n.roomCode}: ${_formatRoomCode(roomCode)}'
                        : '${l10n.createRoomCode}.',
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (roomCode != null && !(_pairingState?.isPaired ?? false)) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.roomCodeValidHint,
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _pairingBusy || (!_firebaseReady && !_isOfflineMode)
                  ? null
                  : (_isOfflineMode ? _startAdvertising : _createRoomCode),
              icon: _pairingBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.qr_code_2_outlined),
              label: Text(_pairingBusy
                  ? l10n.loading
                  : (_isOfflineMode ? l10n.startBroadcastOffline : l10n.createRoomCode)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildConnectionBadge(scheme),
        if (_pairingError != null) ...[
          const SizedBox(height: 8),
          Text(
            _pairingError!,
            style: TextStyle(color: scheme.error),
          ),
        ],
        SizedBox(height: gap),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                !_firebaseReady
                    ? l10n.firebaseConfigMissing
                    : roomCode == null
                        ? '${l10n.createRoomCode}.'
                        : '${l10n.roomCode}: ${_formatRoomCode(roomCode)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (roomCode != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      hasStream
                          ? Icons.wifi_tethering
                          : Icons.hourglass_top_outlined,
                      color: hasStream ? scheme.primary : scheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasStream
                            ? l10n.connected
                            : l10n.waitingForConnection,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (roomCode != null) ...[
          SizedBox(height: gap),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed:
                  _pairingBusy ? null : () => _resetPairing(deleteRoom: true),
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(l10n.stop),
            ),
          ),
        ],
      ],
    );
  }

  Widget _parentPairingContent(ColorScheme scheme, double gap) {
    final roomCode = _pairingState?.roomCode;
    final hasRemote = _webrtcService?.remoteRenderer.srcObject != null;
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.parentMode} - ${l10n.enterRoomCode}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        if (!_isOfflineMode) ...[
          TextField(
            key: const Key('roomCodeField'),
            controller: _parentRoomController,
            keyboardType: TextInputType.visiblePassword, // letters + digits, no autocorrect
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: RoomCode.length + 1, // with the dash
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')),
            ],
            onSubmitted: (value) => _joinRoomWithCode(value),
            decoration: InputDecoration(
              labelText: l10n.roomCode,
              hintText: 'ABCD-EF23',
              counterText: '',
            ),
            enabled: _firebaseReady,
          ),
          SizedBox(height: gap),
        ],
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const Key('joinRoomButton'),
                onPressed: _pairingBusy || (!_firebaseReady && !_isOfflineMode)
                    ? null
                    : (_isOfflineMode ? _startDiscovery : _joinRoomWithCode),
                icon: _pairingBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link_outlined),
                label: Text(_pairingBusy
                    ? l10n.loading
                    : (_isOfflineMode ? l10n.searchDeviceOffline : l10n.connect)),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonalIcon(
              onPressed: _pairingBusy
                  ? null
                  : () {
                      _resetPairing(deleteRoom: false);
                    },
              icon: const Icon(Icons.close),
              label: Text(l10n.cancel),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildConnectionBadge(scheme),
            if (roomCode != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('${l10n.roomCode}: ${_formatRoomCode(roomCode)}'),
              ),
          ],
        ),
        if (_pairingError != null) ...[
          const SizedBox(height: 8),
          Text(
            _pairingError!,
            style: TextStyle(color: scheme.error),
          ),
        ],
        SizedBox(height: gap),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: _isOfflineMode && _currentImageBytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _currentImageBytes!,
                    gaplessPlayback: true,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                )
              : !_firebaseReady && !_isOfflineMode
                  ? Center(
                      child: Text(l10n.firebaseConfigMissing),
                    )
                  : hasRemote
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: RTCVideoView(
                            _webrtcService!.remoteRenderer,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          ),
                        )
                      : Center(
                          child: Text(
                            _connectionStatus == ConnectionStatus.CONNECTED
                                ? l10n.waitingForConnection
                                : '${l10n.connected}: ${_connectionStatusLabel()}',
                          ),
                        ),
        ),
      ],
    );
  }

  void _showPairingSheet({required bool forBaby}) {
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final gap = size.height < 720 ? 10.0 : 14.0;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final bottomPadding = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (ctx, modalSetState) {
            _bottomSheetSetState = modalSetState;
            _bottomSheetContext = ctx;
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding + 20),
              child: SingleChildScrollView(
                child: forBaby
                    ? _babyPairingContent(scheme, gap)
                    : _parentPairingContent(scheme, gap),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _bottomSheetSetState = null;
      _bottomSheetContext = null;
    });
  }

  Future<void> _toggleRecording() async {
    try {
      if (_recorderService.isRecording) {
        // Stop Recording (whichever kind is running, even if the mode changed)
        await _recorderService.stopAny();
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppLocalizations.of(context).videoGallery} ${AppLocalizations.of(context).recordings}')),
          );
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
            final l10n = AppLocalizations.of(context);
            final seconds = VideoRecorderService.offlineMaxDuration.inSeconds;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${l10n.offlineRecordingInfo}: $seconds s')),
            );
          }
        } else {
          final stream = _webrtcService?.remoteRenderer.srcObject;
          if (stream != null) {
            await _recorderService.startWebRTCRecording(stream);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context).noRecordsFound)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).error}: $e')),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).offlineRecordingLimitReached)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isBaby = _role == DeviceRole.BABY;
    final hasCameraPreview = _controller != null && _controller!.value.isInitialized;
    final RTCVideoRenderer? previewRenderer =
        isBaby ? _webrtcService?.localRenderer : _webrtcService?.remoteRenderer;
    final hasWebRtcPreview = previewRenderer?.srcObject != null;
    final hasOfflinePreview = _currentImageBytes != null;
    final canShowPreview = hasCameraPreview || hasWebRtcPreview || hasOfflinePreview;
    final scheme = Theme.of(context).colorScheme;

    if (_isFullscreen) {
      return ValueListenableBuilder<Uint8List?>(
        valueListenable: _currentImageBytesNotifier,
        builder: (context, imageBytes, child) {
          return FullscreenView(
            canShowPreview: canShowPreview,
            controller: _controller,
            webrtcRenderer: previewRenderer,
            mirrorWebRtc: isBaby && _currentLens == CameraLensDirection.front,
            overlayActive: _fullscreenCryOverlay,
            onExit: _exitFullscreen,
            offlineImage: imageBytes,
            isRecording: _recorderService.isRecording,
            onRecordToggle: _toggleRecording,
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: _nightMode ? Colors.black : scheme.surface,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildCustomAppBar(scheme),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildModeToggle(scheme),
                          const SizedBox(height: 20),
                          _buildVideoMonitor(
                            context,
                            scheme,
                            canShowPreview,
                            hasCameraPreview,
                            hasWebRtcPreview,
                            previewRenderer,
                            isBaby,
                          ),
                          const SizedBox(height: 20),
                          _buildStatusSection(scheme),
                          const SizedBox(height: 20),
                          _buildControlGrid(scheme, isBaby, canShowPreview),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Night mode: opaque black layer; double tap / back exits (D1-a)
          if (_nightMode)
            Positioned.fill(
              child: NightModeOverlay(
                status: _connectionStatus,
                onExit: () => unawaited(_exitNightMode()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomAppBar(ColorScheme scheme) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.child_care, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    l10n.appTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.video_library_rounded),
                tooltip: l10n.videoGallery,
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const VideoGalleryScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: l10n.alertHistory,
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AlertHistoryScreen()),
                  );
                },
              ),
              IconButton(
                key: const Key('settingsButton'),
                icon: const Icon(Icons.settings_outlined),
                tooltip: l10n.settings,
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    showDragHandle: true,
                    builder: (_) => SettingsSheet(
                      noiseThreshold: _noiseThreshold,
                      keepScreenOn: _keepScreenOn,
                      isOfflineMode: _isOfflineMode,
                      videoSettings: _videoSettings,
                      onVideoSettingsChanged: _updateVideoSettings,
                      onNoiseThresholdChanged: _setNoiseThreshold,
                      onKeepScreenOnChanged: _setKeepScreenOn,
                      autoNightMode: _autoNightMode,
                      onAutoNightModeChanged: (v) {
                        setState(() => _autoNightMode = v);
                      },
                      onOfflineModeChanged: (val) async {
                        Navigator.pop(context);
                        setState(() {
                          _isOfflineMode = val;
                        });
                        await _resetPairing();
                        await _initCoreServices();
                      },
                    ),
                  );
                },
              ),
              PopupMenuButton<_MenuAction>(
                key: const Key('mainMenuButton'),
                onSelected: _onMenuActionSelected,
                itemBuilder: (context) => _buildMenuItems(),
                icon: const Icon(Icons.more_vert_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle(ColorScheme scheme) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _switchRole(DeviceRole.BABY),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _role == DeviceRole.BABY ? scheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _role == DeviceRole.BABY
                      ? [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    l10n.babyMode,
                    style: TextStyle(
                      color: _role == DeviceRole.BABY ? scheme.onPrimary : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _switchRole(DeviceRole.PARENT),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _role == DeviceRole.PARENT ? scheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _role == DeviceRole.PARENT
                      ? [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    l10n.parentMode,
                    style: TextStyle(
                      color: _role == DeviceRole.PARENT ? scheme.onPrimary : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoMonitor(
    BuildContext context,
    ColorScheme scheme,
    bool canShowPreview,
    bool hasCameraPreview,
    bool hasWebRtcPreview,
    RTCVideoRenderer? previewRenderer,
    bool isBaby,
  ) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video Feed
            if (canShowPreview)
              ValueListenableBuilder<Uint8List?>(
                valueListenable: _currentImageBytesNotifier,
                builder: (context, imageBytes, child) {
                  return CameraPreviewCard(
                    controller: _controller,
                    initializing: _initializing,
                    hasPermission: _hasCamPermission,
                    message: _message,
                    webrtcRenderer: previewRenderer,
                    mirrorWebRtc: isBaby && _currentLens == CameraLensDirection.front,
                    offlineImage: imageBytes,
                    isRecording: _recorderService.isRecording,
                    onRecordToggle: _toggleRecording,
                  );
                },
              )
            else
              Container(
                color: scheme.surfaceContainerHighest,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isBaby ? Icons.videocam_off_outlined : Icons.signal_wifi_off,
                      size: 48,
                      color: scheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isBaby
                          ? AppLocalizations.of(context).cameraOff
                          : AppLocalizations.of(context).waitingForConnection,
                      style: TextStyle(color: scheme.outline),
                    ),
                  ],
                ),
              ),

            // Overlays
            if (canShowPreview) ...[
              // Top Controls
              Positioned(
                top: 12,
                right: 12,
                child: Row(
                  children: [
                    if (isBaby)
                      _buildOverlayButton(
                        icon: Icons.cameraswitch_rounded,
                        onTap: () => _switchCamera(),
                      ),
                    const SizedBox(width: 8),
                    _buildOverlayButton(
                      icon: Icons.fullscreen_rounded,
                      onTap: _enterFullscreen,
                    ),
                  ],
                ),
              ),
              
              if (isBaby)
                Positioned(
                  top: 12,
                  left: 12,
                  child: _buildOverlayButton(
                    key: const Key('nightModeButton'),
                    icon: _nightMode ? Icons.dark_mode : Icons.dark_mode_outlined,
                    onTap: _toggleNightMode,
                    active: _nightMode,
                  ),
                ),

              // Recording Indicator
              if (_recorderService.isRecording)
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'KAYIT',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],

            // Cry Alert Overlay
            if (_noiseAlert)
              Container(
                color: Colors.red.withValues(alpha: 0.3),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: scheme.error,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: scheme.onError),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context).babyCrying.toUpperCase(),
                          style: TextStyle(
                            color: scheme.onError,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayButton({
    Key? key,
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: active ? Colors.black : Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildStatusSection(ColorScheme scheme) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.wifi, color: _connectionStatusColor(scheme)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.connectionStatus,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _connectionStatusLabel(),
                      key: const Key('connectionStatusText'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _connectionStatusColor(scheme),
                      ),
                    ),
                  ],
                ),
              ),
              if (_pairingState?.roomCode != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        l10n.roomCode,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                      ),
                      Text(
                        _pairingState!.roomCode,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          NoiseLevelBar(
            currentDb: _currentDecibel,
            thresholdDb: _noiseThreshold,
            listening: _listeningNoise,
          ),
          if (_remoteBatteryLevel != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  _remoteBatteryState == BatteryState.charging 
                      ? Icons.battery_charging_full 
                      : Icons.battery_std, 
                  color: scheme.primary
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.babyDeviceBattery,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '%$_remoteBatteryLevel${_remoteBatteryState == BatteryState.charging ? ' (${l10n.charging})' : ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlGrid(ColorScheme scheme, bool isBaby, bool canShowPreview) {
    final l10n = AppLocalizations.of(context);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        if (isBaby) ...[
          _buildControlCard(
            scheme,
            icon: Icons.qr_code_2_rounded,
            label: _isOfflineMode ? l10n.startBroadcast : l10n.createRoom,
            onTap: () {
              if (_isOfflineMode) {
                _startAdvertising();
              } else {
                _createRoomCode();
                _showPairingSheet(forBaby: true);
              }
            },
            color: scheme.primary,
          ),
          _buildControlCard(
            scheme,
            icon: canShowPreview ? Icons.videocam_off_outlined : Icons.videocam_outlined,
            label: canShowPreview ? l10n.stopCamera : l10n.startCamera,
            onTap: canShowPreview ? _togglePreview : _setup,
            color: scheme.secondary,
          ),
        ] else ...[
          _buildControlCard(
            scheme,
            icon: Icons.link_rounded,
            label: _isOfflineMode ? l10n.findBroadcast : l10n.joinRoom,
            onTap: () {
              if (_isOfflineMode) {
                _startDiscovery();
              } else {
                _showPairingSheet(forBaby: false);
              }
            },
            color: scheme.primary,
          ),
          _buildControlCard(
            scheme,
            key: const Key('recordButton'),
            icon: _recorderService.isRecording ? Icons.stop_circle_outlined : Icons.fiber_manual_record_outlined,
            label: _recorderService.isRecording ? l10n.stopRecording : l10n.startRecording,
            onTap: _toggleRecording,
            color: Colors.redAccent,
          ),
        ],
        // Online/offline switch: offline (Nearby Connections) is Android only.
        if (defaultTargetPlatform == TargetPlatform.android)
        _buildControlCard(
          scheme,
          key: const Key('modeToggleButton'),
          icon: _isOfflineMode ? Icons.wifi_off_rounded : Icons.wifi_rounded,
          label: _isOfflineMode ? l10n.offlineMode : l10n.onlineMode,
          onTap: () async {
             setState(() {
               _isOfflineMode = !_isOfflineMode;
             });
             await _resetPairing();
             await _initCoreServices();
          },
          color: Colors.orange,
          isOutlined: true,
        ),
        _buildControlCard(
          scheme,
          key: const Key('disconnectButton'),
          icon: Icons.stop_circle_outlined,
          label: l10n.disconnect,
          onTap: () => _resetPairing(deleteRoom: isBaby),
          color: scheme.error,
          isOutlined: true,
        ),
      ],
    );
  }

  Widget _buildControlCard(
    ColorScheme scheme, {
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    bool isOutlined = false,
  }) {
    return Material(
      key: key,
      color: isOutlined ? Colors.transparent : color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isOutlined ? BorderSide(color: color.withValues(alpha: 0.5)) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
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
