import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Thrown when anonymous sign-in is disabled in the Firebase console
/// (Authentication -> Sign-in method -> Anonymous).
class AnonymousAuthDisabledException implements Exception {
  const AnonymousAuthDisabledException();
  @override
  String toString() => 'Anonymous sign-in is not enabled for this Firebase project';
}

/// Anonymous Firebase Auth (D3). Firestore rules identify the baby (room
/// owner) and the parent (viewer) by this uid. The uid is stored on the
/// device and stays the same until the app data is cleared or the app is
/// reinstalled.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  Future<String>? _signingIn;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  String? get uid => _auth.currentUser?.uid;

  /// Returns the current uid, signing in anonymously first if needed.
  /// Concurrent callers share one sign-in attempt; a failed attempt can be
  /// retried by calling again.
  Future<String> ensureSignedIn() {
    final current = _auth.currentUser;
    if (current != null) return Future.value(current.uid);
    return _signingIn ??= _signIn().whenComplete(() => _signingIn = null);
  }

  Future<String> _signIn() async {
    try {
      final credential = await _auth.signInAnonymously();
      final user = credential.user;
      if (user == null) throw StateError('Anonymous sign-in returned no user');
      debugPrint('Signed in anonymously');
      return user.uid;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'operation-not-allowed' || e.code == 'admin-restricted-operation') {
        throw const AnonymousAuthDisabledException();
      }
      rethrow;
    }
  }
}
