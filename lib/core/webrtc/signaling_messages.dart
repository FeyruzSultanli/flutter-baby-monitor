import 'dart:math';

import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Wire format helpers for Firestore signaling (B08: session-tagged messages).
///
/// Every parent join creates a new viewer session id. Offers, answers and ICE
/// candidates carry that id, and each side only accepts messages of its
/// current session, so leftovers from an earlier join are ignored.

/// Random id for a viewer session (12 chars, URL-safe).
String newViewerSessionId([Random? random]) {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rnd = random ?? Random.secure();
  return List.generate(12, (_) => alphabet[rnd.nextInt(alphabet.length)]).join();
}

Map<String, dynamic> sessionDescriptionToMap(RTCSessionDescription sdp, String? session) => {
      'sdp': sdp.sdp,
      'type': sdp.type,
      'session': session,
    };

/// Returns the description stored in [value] if it is a map that belongs to
/// [session]; otherwise null (missing, `null`, malformed or another session).
RTCSessionDescription? sessionDescriptionFromMap(Object? value, String? session) {
  if (value is! Map) return null;
  if (value['session'] != session) return null;
  final sdp = value['sdp'];
  final type = value['type'];
  if (sdp is! String || type is! String) return null;
  return RTCSessionDescription(sdp, type);
}

Map<String, dynamic> candidateToMap(RTCIceCandidate candidate, String? session) => {
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
      'session': session,
    };

/// Returns the candidate in [data] if it belongs to [session]; otherwise null.
RTCIceCandidate? candidateFromMap(Map<String, dynamic> data, String? session) {
  if (data['session'] != session) return null;
  final candidate = data['candidate'];
  if (candidate is! String) return null;
  final mLineIndex = data['sdpMLineIndex'];
  return RTCIceCandidate(
    candidate,
    data['sdpMid'] as String?,
    mLineIndex is num ? mLineIndex.toInt() : null,
  );
}
