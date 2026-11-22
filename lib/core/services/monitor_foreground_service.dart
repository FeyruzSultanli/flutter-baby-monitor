import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../enums/device_role.dart';

/// Android foreground service types for a monitoring session (V2 5.10/5.12).
///
/// Android 14+ refuses to start a camera or microphone service without the
/// matching runtime permission, so only granted kinds are requested.
/// `connectedDevice` (Nearby, offline) and `mediaPlayback` (parent listening)
/// need no runtime permission.
@visibleForTesting
List<String> monitorServiceTypes({
  required DeviceRole role,
  required bool offline,
  required bool cameraGranted,
  required bool microphoneGranted,
}) {
  final types = <String>[];
  if (role == DeviceRole.BABY) {
    if (cameraGranted) types.add('camera');
    if (microphoneGranted) types.add('microphone');
  } else {
    types.add('mediaPlayback');
  }
  if (offline) types.add('connectedDevice');
  return types;
}

/// Keeps the baby broadcast (camera, microphone, Nearby) and the parent's
/// background listening alive while the screen is off or another app is in
/// front. Android only: iOS has no equivalent for the camera, so the baby
/// phone uses night mode there; the parent's audio continues through the iOS
/// `audio` background mode.
///
/// The work itself stays in the app's Flutter engine; the native
/// `MonitorService` only holds the notification and wake/Wi-Fi locks.
class MonitorForegroundService {
  MonitorForegroundService._();
  static final MonitorForegroundService instance = MonitorForegroundService._();

  static const MethodChannel _channel = MethodChannel('ninni/monitor_service');

  bool _running = false;
  bool get isRunning => _running;

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Starts (or updates) the service. Must be called while the app is in the
  /// foreground (Android 12+ start restrictions); broadcasts and listening
  /// always start from a user action, so this holds.
  Future<void> start({
    required DeviceRole role,
    required bool offline,
    required String title,
    required String text,
  }) async {
    if (!isSupported) return;
    try {
      final camera = await Permission.camera.isGranted;
      final microphone = await Permission.microphone.isGranted;
      final types = monitorServiceTypes(
        role: role,
        offline: offline,
        cameraGranted: camera,
        microphoneGranted: microphone,
      );
      if (types.isEmpty) {
        debugPrint('Monitor service: no permitted type, not started');
        return;
      }
      await _channel.invokeMethod<bool>('start', {
        'title': title,
        'text': text,
        'types': types,
      });
      _running = true;
      debugPrint('Monitor service started (${types.join('|')})');
      // The native start is asynchronous; log a refusal for diagnostics.
      Future<void>.delayed(const Duration(seconds: 2), () async {
        final status = await _status();
        if (status != null && status['running'] != true) {
          _running = false;
          debugPrint('Monitor service not running: ${status['error']}');
        }
      });
    } catch (e) {
      debugPrint('Monitor service start failed: $e');
    }
  }

  Future<void> stop() async {
    if (!isSupported || !_running) return;
    _running = false;
    try {
      await _channel.invokeMethod<bool>('stop');
      debugPrint('Monitor service stopped');
    } catch (e) {
      debugPrint('Monitor service stop failed: $e');
    }
  }

  Future<Map<Object?, Object?>?> _status() async {
    try {
      return await _channel.invokeMethod<Map<Object?, Object?>>('status');
    } catch (_) {
      return null;
    }
  }
}
