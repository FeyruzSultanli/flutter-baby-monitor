import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
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
import '../core/audio/audio_level.dart';
import '../core/offline/offline_payload.dart';
import '../core/pairing/pairing_service.dart';
import '../core/pairing/pairing_state.dart';
import '../core/webrtc/signaling_interface.dart';
import '../core/webrtc/firestore_signaling.dart';
import '../models/alert_model.dart';
import '../core/alert_history_service.dart';
import 'alert_history_screen.dart';
import 'video_gallery_screen.dart';
import '../core/webrtc/webrtc_service.dart';
import '../core/services/hybrid_notification_manager.dart';
import '../widgets/camera_preview_card.dart';
import '../widgets/fullscreen_view.dart';
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
  String? _recordingPath;

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
  DateTime? _noiseAboveSince;

  bool _isFullscreen = false;
  bool _fullscreenCryOverlay = false;

  bool _keepScreenOn = false;
  bool _nightMode = false;

  void Function(void Function())? _bottomSheetSetState;
  StreamSubscription<PairingState>? _roomSub;
  bool _lastCryAlertSent = false;
  // Cry notifications (Firestore alert docs / local notifications) are rate
  // limited so a long cry does not produce a notification every 2 s (B05).
  static const Duration _cryNotificationCooldown = Duration(seconds: 60);
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
    
    _initCoreServices();
    _initAudioServices();
    _initBatteryMonitoring();
    _setup();
  }

  Future<void> _initBatteryMonitoring() async {
    _battery.onBatteryStateChanged.listen((BatteryState state) {
      setState(() {
        _batteryState = state;
      });
      _sendBatteryUpdate();
    });

    _batterySyncTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      final level = await _battery.batteryLevel;
      setState(() {
        _batteryLevel = level;
      });
      _sendBatteryUpdate();
    });
    
    // Initial fetch
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
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
      await Nearby().sendBytesPayload(_connectedEndpointId!, payload);
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
    _batterySyncTimer?.cancel();
    _batteryStateSubscription?.cancel();
    _discoveryStreamController.close();
    _controller?.dispose();
    _alertController.dispose();
    if (_role == DeviceRole.BABY && _pairingState?.roomCode != null) {
      unawaited(_pairingService?.closeRoom(_pairingState!.roomCode));
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
      _nightMode = false;
    });
    if (role == DeviceRole.PARENT) {
      await _disposeCameraController();
    } else {
      unawaited(_restoreCameraIfIdle());
      unawaited(_requestBatteryOptimization());
    }
  }

  void _handleConnectionStatus(ConnectionStatus status) {
    if (!mounted) return;
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
  }

  void _handlePairingError(String message) {
    if (!mounted) return;
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

    if (restoreCamera) {
      await _restoreCameraIfIdle();
    }
    await _roomSub?.cancel();
    _roomSub = null;
    if (activeRoom != null) {
      try {
        if (deleteRoom) {
          await _pairingService?.closeRoom(activeRoom);
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
    _refreshBottomSheet();
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
      final newCode = await _pairingService!
          .createRoom(previousCode: _pairingState?.roomCode);
      final facingMode =
          _currentLens == CameraLensDirection.front ? 'user' : 'environment';
      unawaited(_pairingService!.setFacing(newCode, facingMode));
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
      await _webrtcService!.startAsBaby(newCode, facingMode: facingMode);
      
      // Automatically start noise monitoring for Online Mode
      await _startNoiseMonitoring();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).roomCode}: $newCode')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pairingError = '${AppLocalizations.of(context).error}: $e';
        _connectionStatus = ConnectionStatus.FAILED;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).error}: $e')),
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
    final roomCode = (code ?? _parentRoomController.text).trim();
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
      await _pairingService!.joinRoom(roomCode);
      _listenRoomUpdates(roomCode);
      await _webrtcService!.startAsParent(roomCode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).waitingForConnection}: $roomCode')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pairingError = e.toString();
        _connectionStatus = ConnectionStatus.FAILED;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).error}: $e')),
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

    // 3. Camera (Only for Baby)
    if (_role == DeviceRole.BABY) {
      perms.add(Permission.camera);
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

  Future<void> _startAdvertising() async {
    if (_pairingBusy) return;
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
    // PCM16 chunk -> positive dB (20*log10(rms), ~0..90 for full scale).
    final db = pcm16ChunkToDb(data);
    
    final now = DateTime.now();
    final bool alert = db >= _noiseThreshold;
    
    // Update local UI (Baby side)
    setState(() {
      _currentDecibel = db;
      _noiseAlert = alert;
    });

    // Send to Parent
    // Offline mode: Send frequently for smooth UI (e.g., every 200ms)
    // or if status changed.
    if (alert != _lastCryAlertSent || 
        (_lastCrySentAt == null || now.difference(_lastCrySentAt!) > const Duration(milliseconds: 200))) {
      
      _lastCryAlertSent = alert;
      _lastCrySentAt = now;

      final payloadMap = {
        'type': 'STATUS',
        'db': db,
        'alert': alert,
      };
      final payload =
          OfflinePayload.encodeJson(OfflinePayloadType.control, payloadMap);

      Nearby().sendBytesPayload(_connectedEndpointId!, payload);
    }
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
                      title: Text(device['name'] ?? "Unknown Device"),
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
    setState(() {
      _connectedEndpointId = null;
      _currentImageBytesNotifier.value = null;
      _connectionStatus = ConnectionStatus.DISCONNECTED;
    });
    if (_role == DeviceRole.BABY) {
      _controller?.stopImageStream();
      _isStreaming = false;
      _stopAudioStream();
    } else if (_role == DeviceRole.PARENT) {
      _player.stop();
      _isPlayerRunning = false;
    }
    _refreshBottomSheet();
  }

  void _onPayloadReceived(Uint8List bytes) {
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
        SnackBar(content: Text('Video settings updated: ${settings.fps} FPS, ${settings.quality}')),
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
        _pairingService?.setFacing(roomCode, facingMode);
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

    // Use WebRTC stats polling instead of NoiseMeter to avoid mic conflict on devices like Redmi Note 9 Pro
    _noisePollTimer?.cancel();
    _noisePollTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) async {
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
    // Record if no previous alert or if 5 seconds has passed since last recording
    if (_lastRecordedAlertTime == null || 
        now.difference(_lastRecordedAlertTime!) > const Duration(seconds: 5)) {
      _lastRecordedAlertTime = now;
      await AlertHistoryService().addAlert(AlertModel(
        timestamp: now,
        message: 'Baby crying / Noise detected',
        decibel: db,
      ));
    }
  }

  void _processNoiseLevel(double db) {
    final now = DateTime.now();
    final bool alert = db >= _noiseThreshold;
    DateTime? aboveSince = alert ? ( _noiseAboveSince ?? now ) : null;

    if (_role == DeviceRole.BABY) {
      setState(() {
        _currentDecibel = db;
        _noiseAboveSince = aboveSince;
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
          now.difference(_lastCrySentAt!) > const Duration(seconds: 2);

      if (roomCode != null && _pairingService != null && (statusChanged || timeToUpdate)) {
        _lastCryAlertSent = alert;
        _lastCrySentAt = now;
        unawaited(
          _pairingService!.setCryAlert(
            roomCode,
            alert: alert,
            decibel: db,
          ),
        );

        if (alert && _takeCryNotificationSlot(now)) {
          HybridNotificationManager().sendAlert(
            AppLocalizations.of(context).babyCryAlert,
            '${AppLocalizations.of(context).noiseLevel}: ${db.toStringAsFixed(1)} dB'
          );
        }
      }
      return;
    }

    setState(() {
      _currentDecibel = db;
      _noiseAboveSince = aboveSince;
      _noiseAlert = alert;
    });

    if (_role == DeviceRole.PARENT &&
        _isFullscreen &&
        db >= _noiseThreshold &&
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
    if (_role != DeviceRole.BABY) return;
    setState(() {
      _nightMode = !_nightMode;
    });
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
      _handlePairingError('${AppLocalizations.of(context).error}: $e');
    });
  }

  void _enterFullscreen() {
    setState(() {
      _isFullscreen = true;
      _nightMode = false;
    });
  }

  void _exitFullscreen() {
    setState(() {
      _isFullscreen = false;
      _fullscreenCryOverlay = false;
    });
  }

  String _formatRoomCode(String code) {
    if (code.length <= 3) return code;
    return '${code.substring(0, 3)} ${code.substring(3)}';
  }

  void _refreshBottomSheet() {
    final fn = _bottomSheetSetState;
    if (fn != null) {
      fn(() {});
    }
  }

  Widget _buildConnectionBadge(ColorScheme scheme) {
    final color = _connectionStatusColor(scheme);
    return Container(
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
            'Bağlantı: ${_connectionStatusLabel()}',
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
            controller: _parentRoomController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (value) => _joinRoomWithCode(value),
            decoration: InputDecoration(
              labelText: l10n.roomCode,
              hintText: '538241',
            ),
            enabled: _firebaseReady,
          ),
          SizedBox(height: gap),
        ],
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
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
    });
  }

  Future<void> _toggleRecording() async {
    try {
      if (_recorderService.isRecording) {
        // Stop Recording
        if (_isOfflineMode) {
          await _recorderService.stopOfflineRecording();
        } else {
          if (_recordingPath != null) {
            await _recorderService.stopWebRTCRecording(_recordingPath!);
            _recordingPath = null;
          }
        }
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
        } else {
          final stream = _webrtcService?.remoteRenderer.srcObject;
          if (stream != null) {
            _recordingPath = await _recorderService.startWebRTCRecording(stream);
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
          // Night Mode Overlay (Dimming Effect 80%)
          if (_nightMode)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true, // Allows clicks to pass through to the buttons below
                child: Container(
                  color: Colors.black.withValues(alpha: 0.8), // Simulates brightness dropping to ~20%
                ),
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
                      onNoiseThresholdChanged: (v) {
                        setState(() {
                          _noiseThreshold = v;
                        });
                      },
                      onKeepScreenOnChanged: _setKeepScreenOn,
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
                      isBaby ? 'Kamera Kapalı' : 'Bağlantı Bekleniyor',
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
                          'BEBEK AĞLIYOR!',
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
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
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
            icon: _recorderService.isRecording ? Icons.stop_circle_outlined : Icons.fiber_manual_record_outlined,
            label: _recorderService.isRecording ? l10n.stopRecording : l10n.startRecording,
            onTap: _toggleRecording,
            color: Colors.redAccent,
          ),
        ],
        _buildControlCard(
          scheme,
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
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    bool isOutlined = false,
  }) {
    return Material(
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
