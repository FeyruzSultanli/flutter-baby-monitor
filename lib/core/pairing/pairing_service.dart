import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../enums/connection_status.dart';
import 'pairing_state.dart';
import '../../models/video_settings.dart';

/// Handles room lifecycle in Firestore (rooms/{roomCode}).
class PairingService {
  PairingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _firestore.collection('rooms');

  /// Creates a 6-digit numeric room and stores a fresh document.
  Future<String> createRoom({String? previousCode}) async {
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

  Future<void> updateVideoSettings(String roomCode, VideoSettings settings) async {
    await _rooms.doc(roomCode).set(
      {'videoSettings': settings.toJson()},
      SetOptions(merge: true),
    );
  }

  /// Basic join validation and snapshot.
  Future<PairingState> joinRoom(String roomCode) async {
    final doc = await _rooms.doc(roomCode).get();
    if (!doc.exists) {
      throw Exception('Geçersiz oda kodu veya oda bulunamadı.');
    }
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
      );
    });
  }
}
