import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../auth/auth_service.dart';
import '../pairing/pairing_service.dart';

/// What went wrong, in words a parent understands (V2.1 §3). Raw exception
/// texts (for example "Firebase auth network request failed … timeout,
/// interrupted connection or unreachable host") are only logged, never shown.
enum UserErrorKind {
  /// No internet / server not reachable (retrying later can help).
  network,

  /// The room code is wrong, expired or already used.
  roomUnavailable,

  /// The baby phone closed the room.
  roomClosed,

  /// Anonymous sign-in is disabled in the Firebase console.
  signInDisabled,

  /// Camera or microphone permission is missing.
  permission,

  /// The camera could not be opened.
  camera,

  /// Firebase is not configured in this build.
  notConfigured,

  /// Anything else.
  unknown,
}

class UserFacingError {
  const UserFacingError(this.kind);

  final UserErrorKind kind;

  /// Firestore / Auth codes that mean "no connection to the server".
  static const Set<String> networkCodes = {
    'network-request-failed',
    'unavailable',
    'deadline-exceeded',
    'network-error',
    'timeout',
  };

  /// Maps any thrown object to a [UserFacingError]. Pure (no I/O), so it can
  /// be unit tested with fake exceptions.
  factory UserFacingError.from(Object error) => UserFacingError(classify(error));

  static UserErrorKind classify(Object error) {
    if (error is UserFacingError) return error.kind;
    if (error is RoomUnavailableException) return UserErrorKind.roomUnavailable;
    if (error is AnonymousAuthDisabledException) return UserErrorKind.signInDisabled;
    if (error is PairingTimeoutException) return UserErrorKind.network;
    if (error is SocketException || error is TimeoutException || error is HttpException) {
      return UserErrorKind.network;
    }
    if (error is CameraException) {
      final code = error.code.toLowerCase();
      if (code.contains('denied') || code.contains('permission')) {
        return UserErrorKind.permission;
      }
      return UserErrorKind.camera;
    }
    if (error is FirebaseException) {
      final code = error.code.toLowerCase();
      if (networkCodes.contains(code)) return UserErrorKind.network;
      if (code == 'operation-not-allowed' || code == 'admin-restricted-operation') {
        return UserErrorKind.signInDisabled;
      }
      if (code == 'permission-denied' || code == 'not-found') {
        return UserErrorKind.roomUnavailable;
      }
      if (code == 'no-app' || code == 'not-initialized') return UserErrorKind.notConfigured;
    }
    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      if (networkCodes.contains(code)) return UserErrorKind.network;
      if (code.contains('permission') || code.contains('denied')) {
        return UserErrorKind.permission;
      }
    }
    // Last resort: native SDKs sometimes wrap network failures in generic
    // exceptions; recognize them by their (English) text.
    final text = error.toString().toLowerCase();
    if (_looksLikeNetwork(text)) return UserErrorKind.network;
    return UserErrorKind.unknown;
  }

  static bool _looksLikeNetwork(String text) =>
      text.contains('network') ||
      text.contains('unreachable host') ||
      text.contains('failed host lookup') ||
      text.contains('connection refused') ||
      text.contains('connection reset') ||
      text.contains('interrupted connection') ||
      text.contains('timed out') ||
      text.contains('timeout') ||
      text.contains('offline');

  /// Whether "Try again" makes sense (the error may go away on its own).
  bool get retryable => kind == UserErrorKind.network || kind == UserErrorKind.unknown;

  String message(AppLocalizations l10n) {
    switch (kind) {
      case UserErrorKind.network:
        return l10n.errNoInternet;
      case UserErrorKind.roomUnavailable:
        return l10n.roomUnavailable;
      case UserErrorKind.roomClosed:
        return l10n.roomClosed;
      case UserErrorKind.signInDisabled:
        return l10n.errSignIn;
      case UserErrorKind.permission:
        return l10n.errPermission;
      case UserErrorKind.camera:
        return l10n.errCamera;
      case UserErrorKind.notConfigured:
        return l10n.errNotConfigured;
      case UserErrorKind.unknown:
        return l10n.errUnknown;
    }
  }

  /// Logs [error] (with its full text) and returns the user-facing text.
  static String describe(Object error, AppLocalizations l10n, {String context = ''}) {
    debugPrint('Error${context.isEmpty ? '' : ' ($context)'}: $error');
    return UserFacingError.from(error).message(l10n);
  }

  @override
  String toString() => 'UserFacingError($kind)';
}
