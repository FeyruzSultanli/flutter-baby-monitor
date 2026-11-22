import 'dart:async';
import 'dart:io';

import 'package:bebek_monitor_clean/core/auth/auth_service.dart';
import 'package:bebek_monitor_clean/core/errors/user_facing_error.dart';
import 'package:bebek_monitor_clean/core/pairing/pairing_service.dart';
import 'package:bebek_monitor_clean/l10n/app_localizations.dart';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  UserErrorKind kind(Object e) => UserFacingError.classify(e);

  group('UserFacingError.classify (V2.1 §3)', () {
    test('network failures', () {
      // The text Cavid saw on Android.
      expect(
        kind(FirebaseException(
          plugin: 'firebase_auth',
          code: 'network-request-failed',
          message: 'A network error (such as timeout, interrupted connection or unreachable host) has occurred.',
        )),
        UserErrorKind.network,
      );
      expect(kind(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')), UserErrorKind.network);
      expect(kind(FirebaseException(plugin: 'cloud_firestore', code: 'deadline-exceeded')), UserErrorKind.network);
      expect(kind(const SocketException('Failed host lookup')), UserErrorKind.network);
      expect(kind(TimeoutException('x')), UserErrorKind.network);
      expect(kind(const PairingTimeoutException()), UserErrorKind.network);
      expect(kind(PlatformException(code: 'network-request-failed')), UserErrorKind.network);
      expect(kind(Exception('Failed to get document because the client is offline.')), UserErrorKind.network);
    });

    test('room, sign-in, permission and camera', () {
      expect(kind(const RoomUnavailableException('K7MQT2H9')), UserErrorKind.roomUnavailable);
      expect(kind(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')),
          UserErrorKind.roomUnavailable);
      expect(kind(const AnonymousAuthDisabledException()), UserErrorKind.signInDisabled);
      expect(kind(FirebaseException(plugin: 'firebase_auth', code: 'operation-not-allowed')),
          UserErrorKind.signInDisabled);
      expect(kind(CameraException('CameraAccessDenied', 'no')), UserErrorKind.permission);
      expect(kind(CameraException('cameraNotReadable', 'busy')), UserErrorKind.camera);
      expect(kind(FirebaseException(plugin: 'core', code: 'no-app')), UserErrorKind.notConfigured);
      expect(kind(StateError('boom')), UserErrorKind.unknown);
    });

    test('retry only where it can help', () {
      expect(const UserFacingError(UserErrorKind.network).retryable, isTrue);
      expect(const UserFacingError(UserErrorKind.unknown).retryable, isTrue);
      expect(const UserFacingError(UserErrorKind.roomUnavailable).retryable, isFalse);
      expect(const UserFacingError(UserErrorKind.permission).retryable, isFalse);
    });

    test('messages never contain the raw exception text, in all languages', () {
      final raw = FirebaseException(
        plugin: 'firebase_auth',
        code: 'network-request-failed',
        message: 'timeout, interrupted connection or unreachable host',
      );
      for (final code in ['tr', 'en', 'az']) {
        final l10n = AppLocalizations(Locale(code));
        for (final k in UserErrorKind.values) {
          final text = UserFacingError(k).message(l10n);
          expect(text, isNotEmpty);
          expect(text.toLowerCase(), isNot(contains('firebase')));
          expect(text.toLowerCase(), isNot(contains('exception')));
        }
        final text = UserFacingError.describe(raw, l10n);
        expect(text, isNot(contains('unreachable')));
      }
      expect(UserFacingError.describe(raw, AppLocalizations(const Locale('tr'))),
          'İnternet bağlantısı yok. Wi-Fi veya mobil veriyi kontrol edin.');
    });
  });
}
