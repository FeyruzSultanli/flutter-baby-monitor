import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Firestore-based signaling helper (rooms collection).
class SignalingService {
  SignalingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _firestore.collection('rooms');

  Future<void> setOffer(String roomCode, RTCSessionDescription offer) async {
    await _rooms.doc(roomCode).set(
      {
        'offer': {'sdp': offer.sdp, 'type': offer.type},
      },
      SetOptions(merge: true),
    );
  }

  Future<void> setAnswer(String roomCode, RTCSessionDescription answer) async {
    await _rooms.doc(roomCode).set(
      {
        'answer': {'sdp': answer.sdp, 'type': answer.type},
        'isPaired': true,
      },
      SetOptions(merge: true),
    );
  }

  Future<RTCSessionDescription?> fetchOffer(String roomCode) async {
    final doc = await _rooms.doc(roomCode).get();
    final data = doc.data();
    if (data == null) return null;
    final offer = data['offer'];
    if (offer == null) return null;
    return RTCSessionDescription(offer['sdp'], offer['type']);
  }

  Stream<RTCSessionDescription?> watchAnswer(String roomCode) {
    return _rooms.doc(roomCode).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      final answer = data['answer'];
      if (answer == null) return null;
      return RTCSessionDescription(answer['sdp'], answer['type']);
    });
  }

  Future<void> addIceCandidate(
    String roomCode,
    RTCIceCandidate candidate, {
    required bool fromCaller,
  }) async {
    final collection = fromCaller ? 'callerCandidates' : 'calleeCandidates';
    await _rooms.doc(roomCode).collection(collection).add({
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    });
  }

  Stream<RTCIceCandidate> listenForRemoteCandidates(
    String roomCode, {
    required bool fromCaller,
  }) {
    final collection = fromCaller ? 'callerCandidates' : 'calleeCandidates';
    return _rooms
        .doc(roomCode)
        .collection(collection)
        .snapshots()
        .transform(_candidateTransformer);
  }

  final StreamTransformer<QuerySnapshot<Map<String, dynamic>>,
      RTCIceCandidate> _candidateTransformer = StreamTransformer.fromHandlers(
    handleData: (snapshot, sink) {
      for (final doc in snapshot.docChanges) {
        final data = doc.doc.data();
        if (data == null) continue;
        final candidate = RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        );
        sink.add(candidate);
      }
    },
  );
}
