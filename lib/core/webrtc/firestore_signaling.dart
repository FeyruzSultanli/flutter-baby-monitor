import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_interface.dart';
import 'signaling_messages.dart';

class FirestoreSignaling implements SignalingInterface {
  FirestoreSignaling({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  String? _currentRoomId;

  @override
  String? session;

  final _onOfferController = StreamController<RTCSessionDescription>.broadcast();
  final _onAnswerController = StreamController<RTCSessionDescription>.broadcast();
  final _onCandidateController = StreamController<RTCIceCandidate>.broadcast();
  final _onAlertController = StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription? _roomSub;
  StreamSubscription? _candidatesSub;
  StreamSubscription? _alertsSub;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _firestore.collection('rooms');

  /// TTL field for candidate/alert documents (D8). The rules cap it at 25 h
  /// after server time; 12 h tolerates a phone clock up to 13 h fast (B58).
  static Timestamp _childExpiry() =>
      Timestamp.fromDate(DateTime.now().add(const Duration(hours: 12)));

  @override
  Stream<RTCSessionDescription> get onOffer => _onOfferController.stream;

  @override
  Stream<RTCSessionDescription> get onAnswer => _onAnswerController.stream;

  @override
  Stream<RTCIceCandidate> get onCandidate => _onCandidateController.stream;

  @override
  Stream<Map<String, dynamic>> get onAlert => _onAlertController.stream;

  @override
  Future<void> sendCandidate(RTCIceCandidate candidate) async {
    if (_currentRoomId == null) return;
    // A baby standby peer has no session; its candidates are useless (B08).
    if (session == null) return;
    final collection = _isCaller ? 'callerCandidates' : 'calleeCandidates';
    await _rooms
        .doc(_currentRoomId)
        .collection(collection)
        .add({...candidateToMap(candidate, session), 'expiresAt': _childExpiry()});
  }

  @override
  Future<void> clearCandidates() async {
    final roomId = _currentRoomId;
    if (roomId == null) return;
    for (final collection in const ['callerCandidates', 'calleeCandidates']) {
      try {
        final docs = await _rooms.doc(roomId).collection(collection).get();
        for (final doc in docs.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('Clearing $collection failed: $e');
      }
    }
  }

  bool _isCaller = true; // Default
  // True once this side has sent an offer. The caller also receives its own
  // offer back from the room snapshot and must not flip to callee (B06).
  bool _sentOffer = false;

  @override
  Future<void> connect(String roomId) async {
    // A second connect() without disconnect() must not stack listeners (B23).
    await _roomSub?.cancel();
    await _alertsSub?.cancel();
    await _candidatesSub?.cancel();
    _candidatesSub = null;
    _currentRoomId = roomId;
    // Listen to room changes for Offer/Answer
    _roomSub = _rooms.doc(roomId).snapshots().listen((doc) {
      final data = doc.data();
      if (data == null) return;

      // Only offers/answers of the current viewer session count (B08); `null`
      // fields of a new room (B21) and stale ones of earlier joins are ignored.
      final offer = sessionDescriptionFromMap(data['offer'], session);
      if (offer != null) {
        // If we receive an offer we did not send ourselves, we are the callee
        if (!_sentOffer) _isCaller = false;
        _onOfferController.add(offer);
      }

      final answer = sessionDescriptionFromMap(data['answer'], session);
      if (answer != null) {
        _onAnswerController.add(answer);
      }
    }, onError: (Object e) => debugPrint('Room signaling listener error: $e'));

    // Listen to alerts. The first snapshots list every alert already stored
    // in the room; those are history, not new events, so skip them (B22).
    // A first snapshot served from the local cache can be followed by a
    // server snapshot that again reports old alerts as added, so history
    // counts as loaded only after the first snapshot from the server. (No
    // timestamp comparison: the alert time is server time, the device clock
    // may be off.) includeMetadataChanges makes Firestore also report the
    // cache -> server switch when no document changed; without it the first
    // real alert could be mistaken for history.
    var historyLoaded = false;
    _alertsSub = _rooms
        .doc(roomId)
        .collection('alerts')
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
      if (!historyLoaded) {
        if (!snapshot.metadata.isFromCache) historyLoaded = true;
        return;
      }
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          // Skip alerts written by this device (B04): the sender's own write
          // is reported immediately as a local, pending "added" change.
          if (change.doc.metadata.hasPendingWrites) continue;
          final data = change.doc.data();
          if (data == null) continue;
          _onAlertController.add(data);
        }
      }
    }, onError: (Object e) => debugPrint('Alerts listener error: $e'));
  }

  // Helper to start listening for candidates based on role
  void startListeningCandidates(bool isCaller) {
    final collection = isCaller ? 'calleeCandidates' : 'callerCandidates';
    _candidatesSub?.cancel();
    _candidatesSub = _rooms
        .doc(_currentRoomId)
        .collection(collection)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;
          // Candidates of earlier sessions are ignored (B08).
          final candidate = candidateFromMap(data, session);
          if (candidate != null) _onCandidateController.add(candidate);
        }
      }
    }, onError: (Object e) => debugPrint('Candidates listener error: $e'));
  }

  @override
  Future<void> disconnect() async {
    await _roomSub?.cancel();
    await _candidatesSub?.cancel();
    await _alertsSub?.cancel();
    _currentRoomId = null;
    _sentOffer = false;
    _isCaller = true;
  }

  @override
  Future<void> sendOffer(RTCSessionDescription offer) async {
    if (_currentRoomId == null) return;
    _isCaller = true;
    _sentOffer = true;
    await _rooms.doc(_currentRoomId).set(
      {
        'offer': sessionDescriptionToMap(offer, session),
      },
      SetOptions(merge: true),
    );
    // As caller, we listen for callee candidates
    startListeningCandidates(true);
  }

  @override
  Future<void> sendAnswer(RTCSessionDescription answer) async {
    if (_currentRoomId == null) return;
    _isCaller = false;
    await _rooms.doc(_currentRoomId).set(
      {
        'answer': sessionDescriptionToMap(answer, session),
        'isPaired': true,
      },
      SetOptions(merge: true),
    );
    // As callee, we listen for caller candidates
    startListeningCandidates(false);
  }

  @override
  Future<void> sendAlert(String title, String body, {double? db}) async {
    if (_currentRoomId == null) return;
    await _rooms.doc(_currentRoomId).collection('alerts').add({
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': _childExpiry(),
      if (db != null && db.isFinite) 'db': db,
    });
  }
}
