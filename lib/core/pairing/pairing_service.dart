import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../enums/connection_status.dart';
import 'pairing_state.dart';
import '../../models/video_settings.dart';

/// Thrown by [PairingService.joinRoom] when the room does not exist (deleted
/// by the baby, or a wrong code). Lets the parent stop automatic rejoining.
class RoomNotFoundException implements Exception {
  const RoomNotFoundException(this.roomCode);
  final String roomCode;
  @override
  String toString() => 'Geçersiz oda kodu veya oda bulunamadı.';
}

/// Handles room lifecycle in Firestore (rooms/{roomCode}).
class PairingService {
  PairingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _firestore.collection('rooms');

  /// Creates a 6-digit numeric room and stores a fresh document.
  Future<String> createRoom({String? previousCode, double? noiseThreshold}) async {
    if (previousCode != null) {
      await closeRoom(previousCode);
    }

    String code;
    int attempts = 0;
    final rand = Random();

    // Avoid collisions with a small retry loop.
    while (true) {
      code = (100000 + rand.nextInt(900000)).toString();
      final exists = await _rooms.doc(code).get();
      if (!exists.exists) break;
      attempts++;
      if (attempts > 3) {
        throw Exception('Oda kodu oluşturulamadı, lütfen tekrar deneyin.');
      }
    }

    await _rooms.doc(code).set({
      'roomCode': code,
      'createdAt': FieldValue.serverTimestamp(),
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

  /// Returns a snapshot of room existence.
  Future<bool> roomExists(String roomCode) async {
    final doc = await _rooms.doc(roomCode).get();
    return doc.exists;
  }

  /// The parent leaves the room; the baby closes the peer and waits (B08).
  Future<void> leaveRoom(String roomCode) async {
    await _rooms.doc(roomCode).set(
      {'viewerSession': null, 'isPaired': false},
      SetOptions(merge: true),
    );
  }

  /// Marks room pairing state.
  Future<void> setPaired(String roomCode, bool paired) async {
    await _rooms.doc(roomCode).set({'isPaired': paired}, SetOptions(merge: true));
  }

  Future<void> setFacing(String roomCode, String facingMode) async {
    await _rooms
        .doc(roomCode)
        .set({'facingMode': facingMode}, SetOptions(merge: true));
  }

  Future<void> setCryAlert(
    String roomCode, {
    required bool alert,
    double? decibel,
  }) async {
    await _rooms.doc(roomCode).set(
      {
        'cryAlert': alert,
        'cryDb': decibel,
        'cryUpdated': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateNoiseThreshold(String roomCode, double threshold) async {
    await _rooms.doc(roomCode).set(
      {'noiseThreshold': threshold},
      SetOptions(merge: true),
    );
  }

  Future<void> updateVideoSettings(String roomCode, VideoSettings settings) async {
    await _rooms.doc(roomCode).set(
      {'videoSettings': settings.toJson()},
      SetOptions(merge: true),
    );
  }

  /// Validates the room and joins it as viewer [session] (B08): the baby
  /// reacts to the new session with a fresh offer. Also used to rejoin.
  Future<PairingState> joinRoom(String roomCode, {required String session}) async {
    final doc = await _rooms.doc(roomCode).get();
    if (!doc.exists) {
      throw RoomNotFoundException(roomCode);
    }
    await _rooms.doc(roomCode).set(
      {
        'viewerSession': session,
        'viewerJoinedAt': FieldValue.serverTimestamp(),
        'isPaired': false,
      },
      SetOptions(merge: true),
    );
    final data = doc.data() ?? {};
    return PairingState(
      roomCode: roomCode,
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
