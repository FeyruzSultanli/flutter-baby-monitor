import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'signaling_interface.dart';

class WifiDirectSignalingService implements SignalingInterface {
  FlutterP2pHost? _host;
  FlutterP2pClient? _client;
  StreamSubscription? _msgSub;
  
  final _onOfferController = StreamController<RTCSessionDescription>.broadcast();
  final _onAnswerController = StreamController<RTCSessionDescription>.broadcast();
  final _onCandidateController = StreamController<RTCIceCandidate>.broadcast();
  final _onAlertController = StreamController<Map<String, dynamic>>.broadcast();

  void setP2P({FlutterP2pHost? host, FlutterP2pClient? client}) {
    _host = host;
    _client = client;
  }

  @override
  Stream<RTCSessionDescription> get onOffer => _onOfferController.stream;

  @override
  Stream<RTCSessionDescription> get onAnswer => _onAnswerController.stream;

  @override
  Stream<RTCIceCandidate> get onCandidate => _onCandidateController.stream;

  Stream<Map<String, dynamic>> get onAlert => _onAlertController.stream;

  @override
  Future<void> connect(String roomId) async {
    // In this new P2P model, connection is handled by HomeScreen via P2P classes.
    // Here we just start listening to messages.
    _msgSub?.cancel();
    
    Stream<String>? stream;
    if (_host != null) {
      stream = _host!.streamReceivedTexts();
    } else if (_client != null) {
      stream = _client!.streamReceivedTexts();
    }
    
    if (stream != null) {
      _msgSub = stream.listen(_handleMessage, onError: (e) {
        debugPrint("Signaling message error: $e");
      });
    }
  }

  void _handleMessage(String message) {
    try {
      final map = jsonDecode(message);
      final type = map['type'];
      final payload = map['payload'];
      
      if (type == 'offer') {
        final offer = RTCSessionDescription(payload['sdp'], payload['type']);
        _onOfferController.add(offer);
      } else if (type == 'answer') {
        final answer = RTCSessionDescription(payload['sdp'], payload['type']);
        _onAnswerController.add(answer);
      } else if (type == 'candidate') {
        final candidate = RTCIceCandidate(
          payload['candidate'],
          payload['sdpMid'],
          payload['sdpMLineIndex'],
        );
        _onCandidateController.add(candidate);
      } else if (type == 'alert') {
        _onAlertController.add(payload);
      }
    } catch (e) {
      debugPrint("Error parsing signaling message: $e");
    }
  }

  Future<void> _send(String type, Map<String, dynamic> payload) async {
    final msg = jsonEncode({
      'type': type,
      'payload': payload,
    });
    
    if (_host != null) {
      await _host!.broadcastText(msg);
    } else if (_client != null) {
      await _client!.broadcastText(msg);
    } else {
      debugPrint("Cannot send signaling message: No P2P connection");
    }
  }

  @override
  Future<void> disconnect() async {
    await _msgSub?.cancel();
    _msgSub = null;
    // We don't dispose host/client here as they are managed by HomeScreen
  }

  @override
  Future<void> sendOffer(RTCSessionDescription offer) async {
    await _send('offer', {
      'sdp': offer.sdp,
      'type': offer.type,
    });
  }

  @override
  Future<void> sendAnswer(RTCSessionDescription answer) async {
    await _send('answer', {
      'sdp': answer.sdp,
      'type': answer.type,
    });
  }

  @override
  Future<void> sendCandidate(RTCIceCandidate candidate) async {
    await _send('candidate', {
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    });
  }

  @override
  Future<void> sendAlert(String title, String body) async {
    await _send('alert', {
      'title': title,
      'body': body,
    });
  }
}
