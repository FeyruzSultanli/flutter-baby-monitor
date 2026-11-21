import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Local Firebase Emulator Suite for development and automated tests.
///
/// Enabled only in **debug** builds started with
/// `--dart-define=USE_FIREBASE_EMULATOR=true`. Release and profile builds
/// always use the real Firebase project ([kDebugMode] is a compile-time
/// constant, so this code is removed from release builds).
///
/// Emulator ports match the Firebase CLI defaults (see firebase.json):
/// Auth 9099, Firestore 8080. The Android emulator reaches the host machine
/// at 10.0.2.2; the iOS simulator at localhost.
const bool kUseFirebaseEmulatorDefine = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

/// Optional override of the emulator host (e.g. a LAN IP for a real phone).
const String _hostOverride = String.fromEnvironment('FIREBASE_EMULATOR_HOST');

const int firestoreEmulatorPort = 8080;
const int authEmulatorPort = 9099;

bool get useFirebaseEmulator => kDebugMode && kUseFirebaseEmulatorDefine;

String get firebaseEmulatorHost {
  if (_hostOverride.isNotEmpty) return _hostOverride;
  if (!kIsWeb && Platform.isAndroid) return '10.0.2.2';
  return 'localhost';
}

/// Points Firestore and Auth at the local emulators. Call right after
/// `Firebase.initializeApp` and before any other Firebase call.
Future<void> connectToFirebaseEmulatorIfRequested() async {
  if (!useFirebaseEmulator) return;
  final host = firebaseEmulatorHost;
  FirebaseFirestore.instance.useFirestoreEmulator(host, firestoreEmulatorPort);
  await FirebaseAuth.instance.useAuthEmulator(host, authEmulatorPort);
  debugPrint('Using Firebase Emulator Suite at $host (Firestore $firestoreEmulatorPort, Auth $authEmulatorPort)');
}
