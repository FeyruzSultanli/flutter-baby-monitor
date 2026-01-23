import 'package:flutter_webrtc/flutter_webrtc.dart';

abstract class SignalingInterface {
  /// Connects to the signaling channel (e.g. Firestore room or P2P socket).
  Future<void> connect(String roomId);

  /// Disconnects and cleans up.
  Future<void> disconnect();

  /// Sends an SDP Offer.
  Future<void> sendOffer(RTCSessionDescription offer);

  /// Sends an SDP Answer.
  Future<void> sendAnswer(RTCSessionDescription answer);

  /// Sends an ICE Candidate.
  Future<void> sendCandidate(RTCIceCandidate candidate);

  /// Stream of incoming SDP Offers.
  Stream<RTCSessionDescription> get onOffer;

  /// Stream of incoming SDP Answers.
  Stream<RTCSessionDescription> get onAnswer;

  /// Stream of incoming ICE Candidates.
  Stream<RTCIceCandidate> get onCandidate;

  /// Sends an alert message.
  Future<void> sendAlert(String title, String body);

  /// Stream of incoming alert messages.
  Stream<Map<String, dynamic>> get onAlert;
}
