import 'package:bebek_monitor_clean/core/enums/connection_status.dart';
import 'package:bebek_monitor_clean/core/enums/device_role.dart';
import 'package:bebek_monitor_clean/core/monitor/battery_alert.dart';
import 'package:bebek_monitor_clean/core/monitor/connection_watchdog.dart';
import 'package:bebek_monitor_clean/core/services/monitor_foreground_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 11, 22, 22);
  DateTime at(int s) => t0.add(Duration(seconds: s));

  group('ConnectionWatchdog', () {
    test('never alarms before the first connection', () {
      final w = ConnectionWatchdog()..start();
      w.onStatus(ConnectionStatus.FAILED, at(1));
      expect(w.evaluate(at(30)), isFalse);
      expect(w.isLost, isFalse);
    });

    test('failed after connected is lost at once, recovers with media', () {
      final w = ConnectionWatchdog()..start();
      w.onStatus(ConnectionStatus.CONNECTED, at(0));
      w.onMedia(at(1));
      expect(w.evaluate(at(2)), isFalse);
      w.onStatus(ConnectionStatus.FAILED, at(3));
      expect(w.evaluate(at(3)), isTrue);
      expect(w.isLost, isTrue);
      expect(w.lostSince, at(3));
      w.onStatus(ConnectionStatus.CONNECTED, at(10));
      w.onMedia(at(11));
      expect(w.evaluate(at(11)), isTrue);
      expect(w.isLost, isFalse);
    });

    test('disconnected counts only after the grace period', () {
      final w = ConnectionWatchdog()..start();
      w.onStatus(ConnectionStatus.CONNECTED, at(0));
      w.onMedia(at(0));
      w.onStatus(ConnectionStatus.CONNECTING, at(10));
      expect(w.evaluate(at(14)), isFalse);
      expect(w.evaluate(at(15)), isTrue);
    });

    test('connected without media for 20 s is lost', () {
      final w = ConnectionWatchdog()..start();
      w.onStatus(ConnectionStatus.CONNECTED, at(0));
      w.onMedia(at(5));
      expect(w.evaluate(at(24)), isFalse);
      expect(w.evaluate(at(25)), isTrue);
      w.onMedia(at(26));
      expect(w.evaluate(at(26)), isTrue);
      expect(w.isLost, isFalse);
    });

    test('stop() ends the alarm and prevents new ones', () {
      final w = ConnectionWatchdog()..start();
      w.onStatus(ConnectionStatus.CONNECTED, at(0));
      w.onStatus(ConnectionStatus.FAILED, at(1));
      w.evaluate(at(1));
      w.stop();
      expect(w.isLost, isFalse);
      expect(w.evaluate(at(60)), isFalse);
    });
  });

  group('LowBatteryAlert', () {
    test('fires once below 15 % when not charging', () {
      final a = LowBatteryAlert();
      expect(a.update(level: 40, charging: false), isFalse);
      expect(a.update(level: 14, charging: false), isTrue);
      expect(a.update(level: 13, charging: false), isFalse);
      expect(a.update(level: 16, charging: false), isFalse);
      expect(a.update(level: 14, charging: false), isFalse);
    });

    test('charging or >= 20 % re-arms; no alert while charging', () {
      final a = LowBatteryAlert();
      expect(a.update(level: 10, charging: true), isFalse);
      expect(a.update(level: 10, charging: false), isTrue);
      expect(a.update(level: 10, charging: true), isFalse);
      expect(a.update(level: 9, charging: false), isTrue);
      expect(a.update(level: 25, charging: false), isFalse);
      expect(a.update(level: 12, charging: false), isTrue);
    });

    test('BabyBattery parses the room field', () {
      expect(BabyBattery.fromRoom(null), isNull);
      expect(BabyBattery.fromRoom({'level': 'x'}), isNull);
      final b = BabyBattery.fromRoom({'level': 42.0, 'charging': true})!;
      expect(b.level, 42);
      expect(b.charging, isTrue);
    });
  });

  group('monitorServiceTypes', () {
    test('baby requests only granted kinds, plus Nearby offline', () {
      expect(
          monitorServiceTypes(
              role: DeviceRole.BABY,
              offline: false,
              cameraGranted: true,
              microphoneGranted: false),
          ['camera']);
      expect(
          monitorServiceTypes(
              role: DeviceRole.BABY,
              offline: true,
              cameraGranted: true,
              microphoneGranted: true),
          ['camera', 'microphone', 'connectedDevice']);
    });

    test('parent listens with media playback', () {
      expect(
          monitorServiceTypes(
              role: DeviceRole.PARENT,
              offline: false,
              cameraGranted: false,
              microphoneGranted: false),
          ['mediaPlayback']);
    });
  });
}
