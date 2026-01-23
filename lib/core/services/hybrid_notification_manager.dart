import 'dart:async';
import 'package:flutter/foundation.dart';
import '../webrtc/signaling_interface.dart';
import 'notification_service.dart';

class HybridNotificationManager {
  static final HybridNotificationManager _instance = HybridNotificationManager._internal();
  factory HybridNotificationManager() => _instance;
  HybridNotificationManager._internal();

  final NotificationService _notificationService = NotificationService();
  SignalingInterface? _signalingService;
  StreamSubscription? _alertSub;

  Future<void> initialize() async {
    await _notificationService.initialize();
  }

  void setSignalingService(SignalingInterface signalingService) {
    _alertSub?.cancel();
    _signalingService = signalingService;
    _alertSub = _signalingService!.onAlert.listen((data) {
      final title = data['title'] ?? 'Alert';
      final body = data['body'] ?? 'Event detected';
      _notificationService.showLocalNotification(title: title, body: body);
    });
  }

  Future<void> sendAlert(String title, String body) async {
    if (_signalingService != null) {
      await _signalingService!.sendAlert(title, body);
    } else {
      debugPrint("Cannot send alert: No signaling service set");
    }
  }

  Future<void> showLocalNotification({required String title, required String body}) async {
    await _notificationService.showLocalNotification(title: title, body: body);
  }
  
  void dispose() {
    _alertSub?.cancel();
  }
}
