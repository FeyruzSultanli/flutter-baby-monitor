import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import '../enums/connection_status.dart';
import 'pairing_state.dart';
import 'room_code.dart';
import '../../models/video_settings.dart';

/// Thrown by [PairingService.joinRoom] when the room cannot be joined: wrong
/// code, deleted by the baby, claim window (10 min) over, expired, or already
/// paired with another parent. With the Firestore rules (D3) these cases are
/// indistinguishable on purpose. Lets the parent stop automatic rejoining.
class RoomUnavailableException implements Exception {
  const RoomUnavailableException(this.roomCode);
  final String roomCode;
  @override
  String toString() => 'Room $roomCode is not available';
}

/// Handles room lifecycle in Firestore (rooms/{roomCode}).
///
/// Security model (D3, see firestore.rules): the baby that creates a room is
/// its owner; the first parent that claims it within 10 minutes becomes its
/// only viewer. Both are identified by their anonymous Firebase Auth uid.
class PairingService {
  PairingService({FirebaseFirestore? firestore, AuthService? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? AuthService.instance;

  final FirebaseFirestore _firestore;
  final AuthService _auth;

  /// A room lives for at most this long unless the baby extends it
  /// ([extendExpiry]); Firestore TTL deletes it afterwards (D8).
  static const Duration roomLifetime = Duration(hours: 24);

  /// A new room must be claimed by a parent within this time (enforced by the
  /// rules with server time).
  static const Duration claimWindow = Duration(minutes: 10);

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _firestore.collection('rooms');

  static Timestamp _expiry() => Timestamp.fromDate(DateTime.now().add(roomLifetime));

  /// `expiresAt` value for subcollection documents (TTL, D8).
  static Timestamp expiryForChildDocs() => _expiry();

  /// Creates a room with a new 8-character code (D3). The code is written
  /// with create-only semantics: if it already exists the rules deny the
  /// write (no one can read others' rooms), and another code is tried.
  Future<String> createRoom({String? previousCode, double? noiseThreshold}) async {
    final uid = await _auth.ensureSignedIn();
    if (previousCode != null) {
      try {
        await closeRoom(previousCode);
      } catch (e) {
        debugPrint('Closing previous room failed: $e');
      }
    }

    for (var attempt = 0; attempt < 5; attempt++) {
      final code = RoomCode.generate();
      try {
        await _rooms.doc(code).set({
          'roomCode': code,
          'ownerUid': uid,
          'viewerUid': null,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': _expiry(),
          'isPaired': false,
          'offer': null,
          'answer': null,
          'facingMode': 'environment',
          'cryAlert': false,
          'cryDb': null,
          'cryUpdated': FieldValue.serverTimestamp(),
          'videoSettings': const VideoSettings().toJson(),
          'noiseThreshold': noiseThreshold,
          'viewerSession': null,
        });
        return code;
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
        debugPrint('Room code collision, retrying');
      }
    }
    throw Exception('Oda kodu oluşturulamadı, lütfen tekrar deneyin.');
  }

  /// Baby: keeps an active room alive (moves `expiresAt` forward).
  Future<void> extendExpiry(String roomCode) async {
    await _rooms.doc(roomCode).update({'expiresAt': _expiry()});
  }

  /// Deletes a room document and its candidate and alert subcollections.
  Future<void> closeRoom(String roomCode) async {
    final roomRef = _rooms.doc(roomCode);
    final callerCandidates = await roomRef.collection('callerCandidates').get();
    for (final doc in callerCandidates.docs) {
      await doc.reference.delete();
    }
    final calleeCandidates = await roomRef.collection('calleeCandidates').get();
    for (final doc in calleeCandidates.docs) {
      await doc.reference.delete();
    }
    // Best effort: if the Firestore rules do not allow deleting alerts, still
    // delete the room itself (and let createRoom continue).
    try {
      final alerts = await roomRef.collection('alerts').get();
      for (final doc in alerts.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Could not delete alerts of room $roomCode: $e');
    }
    await roomRef.delete();
  }

  /// The parent leaves the room; the baby closes the peer and waits (B08).
  Future<void> leaveRoom(String roomCode) async {
    await _rooms.doc(roomCode).update({'viewerSession': null, 'isPaired': false});
  }

  // Updates use update() rather than set(merge): on a deleted room they fail
  // instead of recreating a partial document (which the rules also deny).

  /// Marks room pairing state.
  Future<void> setPaired(String roomCode, bool paired) async {
    await _rooms.doc(roomCode).update({'isPaired': paired});
  }

  Future<void> setFacing(String roomCode, String facingMode) async {
    await _rooms
        .doc(roomCode)
        .update({'facingMode': facingMode});
  }

  Future<void> setCryAlert(
    String roomCode, {
    required bool alert,
    double? decibel,
  }) async {
    await _rooms.doc(roomCode).update({
        'cryAlert': alert,
        'cryDb': decibel,
        'cryUpdated': FieldValue.serverTimestamp(),
      });
  }

  Future<void> updateNoiseThreshold(String roomCode, double threshold) async {
    await _rooms.doc(roomCode).update({'noiseThreshold': threshold});
  }

  Future<void> updateVideoSettings(String roomCode, VideoSettings settings) async {
    await _rooms.doc(roomCode).update({'videoSettings': settings.toJson()});
  }

  /// Joins [roomCode] as viewer [session] (B08); also used to rejoin.
  ///
  /// The first join claims the room (sets `viewerUid`) without reading it
  /// first: non-members cannot read rooms (D3). A wrong, expired, deleted or
  /// already paired code fails with [RoomUnavailableException].
  Future<PairingState> joinRoom(String roomCode, {required String session}) async {
    final code = RoomCode.normalize(roomCode);
    if (!RoomCode.isValid(code)) throw RoomUnavailableException(code);
    final uid = await _auth.ensureSignedIn();
    final ref = _rooms.doc(code);
    try {
      await ref.update({
        'viewerUid': uid, // unchanged on a rejoin by the same parent
        'viewerSession': session,
        'viewerJoinedAt': FieldValue.serverTimestamp(),
        'isPaired': false,
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'not-found') {
        throw RoomUnavailableException(code);
      }
      rethrow;
    }
    final doc = await ref.get();
    final data = doc.data() ?? {};
    return PairingState(
      roomCode: code,
      isPaired: data['isPaired'] == true,
      status: ConnectionStatus.CONNECTING,
      facingMode: (data['facingMode'] as String? ?? 'environment'),
      cryAlert: data['cryAlert'] == true,
      cryDecibel: (data['cryDb'] as num?)?.toDouble(),
      cryUpdatedAt: (data['cryUpdated'] is Timestamp)
          ? (data['cryUpdated'] as Timestamp).toDate()
          : null,
      videoSettings: data['videoSettings'] != null
          ? VideoSettings.fromJson(data['videoSettings'])
          : const VideoSettings(),
      noiseThreshold: (data['noiseThreshold'] as num?)?.toDouble(),
      viewerSession: data['viewerSession'] as String?,
    );
  }

  /// Observe room document for pairing status.
  Stream<PairingState> watchRoom(String roomCode) {
    return _rooms.doc(roomCode).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) {
        return PairingState(
          roomCode: roomCode,
          isPaired: false,
          errorMessage: 'Oda silindi',
          status: ConnectionStatus.FAILED,
        );
      }
      final rawStatus =
          (data['status'] as String? ?? 'DISCONNECTED').toUpperCase();
      return PairingState(
        roomCode: roomCode,
        isPaired: data['isPaired'] == true,
        facingMode: (data['facingMode'] as String? ?? 'environment'),
        cryAlert: data['cryAlert'] == true,
        cryDecibel: (data['cryDb'] as num?)?.toDouble(),
        cryUpdatedAt: (data['cryUpdated'] is Timestamp)
            ? (data['cryUpdated'] as Timestamp).toDate()
            : null,
        status: ConnectionStatus.values.firstWhere(
          (e) => e.name.toUpperCase() == rawStatus,
          orElse: () => ConnectionStatus.DISCONNECTED,
        ),
        videoSettings: data['videoSettings'] != null
            ? VideoSettings.fromJson(data['videoSettings'])
            : const VideoSettings(),
        noiseThreshold: (data['noiseThreshold'] as num?)?.toDouble(),
        viewerSession: data['viewerSession'] as String?,
      );
    });
  }
}
