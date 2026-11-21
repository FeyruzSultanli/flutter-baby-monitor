import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_interface.dart';

class FirestoreSignaling implements SignalingInterface {
  FirestoreSignaling({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  String? _currentRoomId;

  final _onOfferController = StreamController<RTCSessionDescription>.broadcast();
  final _onAnswerController = StreamController<RTCSessionDescription>.broadcast();
  final _onCandidateController = StreamController<RTCIceCandidate>.broadcast();
  final _onAlertController = StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription? _roomSub;
  StreamSubscription? _candidatesSub;
  StreamSubscription? _alertsSub;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _firestore.collection('rooms');

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
    final collection = _isCaller ? 'callerCandidates' : 'calleeCandidates';
    await _rooms.doc(_currentRoomId).collection(collection).add({
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    });
  }

  bool _isCaller = true; // Default

  @override
  Future<void> connect(String roomId) async {
    _currentRoomId = roomId;
    // Listen to room changes for Offer/Answer
    _roomSub = _rooms.doc(roomId).snapshots().listen((doc) {
      final data = doc.data();
      if (data == null) return;

      // Check for Offer
      if (data.containsKey('offer')) {
        final offerMap = data['offer'];
        final offer = RTCSessionDescription(offerMap['sdp'], offerMap['type']);
        // If we receive an offer, we are the callee
        _isCaller = false;
        _onOfferController.add(offer);
      }

      // Check for Answer
      if (data.containsKey('answer')) {
        final answerMap = data['answer'];
        final answer = RTCSessionDescription(answerMap['sdp'], answerMap['type']);
        _onAnswerController.add(answer);
      }
    });

    // Listen to alerts
    _alertsSub = _rooms.doc(roomId).collection('alerts').snapshots().listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          // Skip alerts written by this device (B04): the sender's own write
          // is reported immediately as a local, pending "added" change.
          if (change.doc.metadata.hasPendingWrites) continue;
          final data = change.doc.data();
          if (data != null) {
             _onAlertController.add(data);
          }
        }
      }
    });
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
          if (data != null) {
            final candidate = RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            );
            _onCandidateController.add(candidate);
          }
        }
      }
    });
  }

  @override
  Future<void> disconnect() async {
    await _roomSub?.cancel();
    await _candidatesSub?.cancel();
    await _alertsSub?.cancel();
    _currentRoomId = null;
  }

  @override
  Future<void> sendOffer(RTCSessionDescription offer) async {
    if (_currentRoomId == null) return;
    _isCaller = true;
    await _rooms.doc(_currentRoomId).set(
      {
        'offer': {'sdp': offer.sdp, 'type': offer.type},
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
        'answer': {'sdp': answer.sdp, 'type': answer.type},
        'isPaired': true,
      },
      SetOptions(merge: true),
    );
    // As callee, we listen for caller candidates
    startListeningCandidates(false);
  }

  @override
  Future<void> sendAlert(String title, String body) async {
    if (_currentRoomId == null) return;
    await _rooms.doc(_currentRoomId).collection('alerts').add({
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
