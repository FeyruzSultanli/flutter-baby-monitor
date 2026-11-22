import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// iOS: makes sure the APNs device token reaches Firebase Messaging before an
/// FCM token is requested.
///
/// firebase_messaging registers for remote notifications when it sees the
/// app's "did finish launching" notification. Since the UIScene migration
/// the plugins are registered later (AppDelegate.didInitializeImplicitFlutterEngine),
/// after that notification, so the plugin never registers and getToken()
/// fails with "APNS token has not been set yet". The app therefore asks iOS
/// itself (AppDelegate, channel below) once Firebase is configured; Firebase
/// Messaging's app delegate proxy then receives the token.
class PushRegistration {
  static const MethodChannel _channel = MethodChannel('bebek_monitor/push');

  /// Registers with APNs (iOS only) and waits until Firebase Messaging has
  /// the APNs token. Returns the token, or null on timeout / other platforms.
  static Future<String?> ensureApnsToken({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return null;
    final messaging = FirebaseMessaging.instance;
    final existing = await messaging.getAPNSToken();
    if (existing != null) return existing;
    try {
      await _channel.invokeMethod<void>('registerForRemoteNotifications');
    } catch (e) {
      debugPrint('APNs registration request failed: $e');
    }
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final token = await messaging.getAPNSToken();
      if (token != null) return token;
    }
    debugPrint('APNs token not available after ${timeout.inSeconds} s '
        '(registration: ${await apnsStatus()})');
    return null;
  }

  /// The app's last APNs registration result: "not requested", "pending",
  /// "token" or "error: ..." (iOS only; null elsewhere).
  static Future<String?> apnsStatus() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return null;
    try {
      return await _channel.invokeMethod<String>('apnsStatus');
    } catch (e) {
      return 'unknown ($e)';
    }
  }
}
