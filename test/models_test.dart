import 'dart:convert';

import 'package:bebek_monitor_clean/core/enums/connection_status.dart';
import 'package:bebek_monitor_clean/core/pairing/pairing_state.dart';
import 'package:bebek_monitor_clean/models/alert_model.dart';
import 'package:bebek_monitor_clean/models/video_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VideoSettings', () {
    test('defaults are 15 fps / MEDIUM', () {
      const s = VideoSettings();
      expect(s.fps, 15);
      expect(s.quality, 'MEDIUM');
    });

    test('toJson/fromJson round-trip (also through a JSON string)', () {
      const s = VideoSettings(fps: 5, quality: 'HIGH');
      final back = VideoSettings.fromJson(
          jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect(back.fps, 5);
      expect(back.quality, 'HIGH');
    });

    test('fromJson falls back to defaults for missing fields', () {
      final s = VideoSettings.fromJson(const {});
      expect(s.fps, 15);
      expect(s.quality, 'MEDIUM');
    });

    test('copyWith overrides only given fields', () {
      const s = VideoSettings(fps: 10, quality: 'LOW');
      expect(s.copyWith(fps: 30).fps, 30);
      expect(s.copyWith(fps: 30).quality, 'LOW');
      expect(s.copyWith(quality: 'HIGH').fps, 10);
    });
  });

  group('AlertModel', () {
    test('toJson/fromJson round-trip', () {
      final a = AlertModel(
        timestamp: DateTime.utc(2026, 1, 2, 3, 4, 5),
        message: 'Baby crying',
        decibel: 72.5,
      );
      final back = AlertModel.fromJson(
          jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>);
      expect(back.timestamp, a.timestamp);
      expect(back.message, a.message);
      expect(back.decibel, 72.5);
    });

    test('decibel is optional and int values are accepted', () {
      final noDb = AlertModel.fromJson(
          {'timestamp': '2026-01-01T00:00:00.000', 'message': 'x', 'decibel': null});
      expect(noDb.decibel, isNull);
      final intDb = AlertModel.fromJson(
          {'timestamp': '2026-01-01T00:00:00.000', 'message': 'x', 'decibel': 60});
      expect(intDb.decibel, 60.0);
    });
  });

  group('PairingState', () {
    test('defaults', () {
      final s = PairingState(roomCode: '123456');
      expect(s.isPaired, isFalse);
      expect(s.status, ConnectionStatus.DISCONNECTED);
      expect(s.facingMode, 'environment');
      expect(s.cryAlert, isFalse);
      expect(s.cryDecibel, isNull);
      expect(s.errorMessage, isNull);
      expect(s.videoSettings.fps, 15);
    });

    test('copyWith keeps roomCode and unspecified fields', () {
      final updated = DateTime(2026);
      final s = PairingState(roomCode: '123456', facingMode: 'user', cryDecibel: 40)
          .copyWith(
        isPaired: true,
        status: ConnectionStatus.CONNECTED,
        cryAlert: true,
        cryUpdatedAt: updated,
      );
      expect(s.roomCode, '123456');
      expect(s.isPaired, isTrue);
      expect(s.status, ConnectionStatus.CONNECTED);
      expect(s.facingMode, 'user');
      expect(s.cryAlert, isTrue);
      expect(s.cryDecibel, 40);
      expect(s.cryUpdatedAt, updated);
    });

    test('noiseThreshold defaults to null and survives copyWith', () {
      final s = PairingState(roomCode: '1');
      expect(s.noiseThreshold, isNull);
      final withThreshold = s.copyWith(noiseThreshold: 72);
      expect(withThreshold.noiseThreshold, 72);
      expect(withThreshold.copyWith(isPaired: true).noiseThreshold, 72);
    });

    test('copyWith clears errorMessage unless it is passed again', () {
      final failed = PairingState(roomCode: '1', errorMessage: 'boom');
      expect(failed.copyWith(isPaired: true).errorMessage, isNull);
      expect(failed.copyWith(errorMessage: 'still').errorMessage, 'still');
    });
  });
}
