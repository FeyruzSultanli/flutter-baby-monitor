import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Cry alerts are FCM *notification* messages: Android shows them itself
  // (channel + icon from the manifest meta-data) while the app is in the
  // background or killed. Nothing else to do here.
  debugPrint("Handling a background message: ${message.messageId}");
}

/// Local notifications + Firebase Cloud Messaging (D2).
///
/// Cry alerts reach the parent in two ways:
/// - app running: the Firestore alerts listener shows a local notification;
/// - app in background/killed: the Cloud Function `onCryAlertCreated` sends
///   an FCM notification (once deployed).
/// Both use the same channel, notification id and tag ([cryAlertTag]), so
/// Android replaces one with the other instead of showing the alert twice.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Must match functions/src/messages.ts and the manifest meta-data.
  static const String channelId = 'baby_monitor_alerts';
  static const String cryAlertTag = 'cry_alert';
  static const int cryAlertId = 0;
  static const String smallIcon = '@drawable/ic_stat_notification';

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    channelId,
    'Baby Monitor Alerts',
    description: 'Notifications for baby monitor events',
    importance: Importance.max,
  );

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Lazy: FirebaseMessaging.instance throws if Firebase is not initialized,
  // which must not break local notifications (B43).
  FirebaseMessaging get _firebaseMessaging => FirebaseMessaging.instance;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Local notifications (work without Firebase)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(smallIcon);

    // iOS: permission is requested explicitly (requestPermission), not here.
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Tapping opens the app (default behaviour); nothing to route yet.
        debugPrint("Notification clicked: ${response.payload}");
      },
    );

    // Create the channel up front: FCM notifications that arrive while the
    // app is killed are shown on this channel (high importance, sound).
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    _isInitialized = true;

    // 2. Firebase Messaging (optional: skipped if Firebase is unavailable)
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      // Foreground: the Firestore alerts listener already shows the alert, so
      // an FCM message received now is not shown a second time.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM message in foreground (not shown): ${message.messageId}');
      });
    } catch (e) {
      debugPrint('Firebase Messaging unavailable: $e');
    }
  }

  /// Asks for notification permission (Android 13+, iOS). Called when the
  /// parent role is used, not at app start (B42). Returns true if granted.
  Future<bool> requestPermission() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      debugPrint('Notification permission: ${settings.authorizationStatus}');
      return granted;
    } catch (e) {
      // Firebase unavailable (e.g. failed to start): still ask the OS, local
      // cry notifications need the permission too (B59).
      debugPrint('FCM permission request failed ($e); using permission_handler');
      try {
        final status = await Permission.notification.request();
        return status.isGranted || status.isProvisional;
      } catch (e) {
        debugPrint('Notification permission request failed: $e');
        return false;
      }
    }
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channelId,
      'Baby Monitor Alerts',
      channelDescription: 'Notifications for baby monitor events',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      tag: cryAlertTag,
      icon: smallIcon,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // Showing fails when the user denied notifications (on iOS:
    // "Source is not authorized"); the in-app alarm still works, so log
    // instead of leaving an unhandled error (B66).
    try {
      await _localNotifications.show(
        cryAlertId,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Local notification not shown: $e');
    }
  }

  Future<String?> getFCMToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      debugPrint('FCM token unavailable: $e');
      return null;
    }
  }

  /// New FCM tokens (the parent writes them to its room).
  Stream<String> get onTokenRefresh {
    try {
      return _firebaseMessaging.onTokenRefresh;
    } catch (e) {
      debugPrint('FCM token refresh unavailable: $e');
      return const Stream<String>.empty();
    }
  }
}
