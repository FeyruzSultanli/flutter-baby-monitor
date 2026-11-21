import 'dart:math';

import 'package:bebek_monitor_clean/core/webrtc/reconnect_backoff.dart';
import 'package:bebek_monitor_clean/core/webrtc/signaling_messages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  group('viewer session id', () {
    test('12 url-safe chars, different each time', () {
      final a = newViewerSessionId();
      final b = newViewerSessionId();
      expect(a, matches(RegExp(r'^[a-z0-9]{12}$')));
      expect(a, isNot(b));
    });

    test('deterministic with a seeded Random', () {
      expect(newViewerSessionId(Random(1)), newViewerSessionId(Random(1)));
    });
  });

  group('session descriptions', () {
    final offer = RTCSessionDescription('v=0 sdp', 'offer');

    test('round trip for the same session', () {
      final map = sessionDescriptionToMap(offer, 's1');
      final back = sessionDescriptionFromMap(map, 's1')!;
      expect(back.sdp, 'v=0 sdp');
      expect(back.type, 'offer');
    });

    test('ignores another session (stale offer/answer from an earlier join)', () {
      final map = sessionDescriptionToMap(offer, 'old');
      expect(sessionDescriptionFromMap(map, 'new'), isNull);
    });

    test('ignores null, non-maps and malformed maps (B21)', () {
      expect(sessionDescriptionFromMap(null, 's1'), isNull);
      expect(sessionDescriptionFromMap('offer', 's1'), isNull);
      expect(sessionDescriptionFromMap({'session': 's1', 'type': 'offer'}, 's1'), isNull);
    });

    test('legacy messages without a session never match a session', () {
      expect(sessionDescriptionFromMap({'sdp': 'x', 'type': 'offer'}, 's1'), isNull);
    });
  });

  group('candidates', () {
    final candidate = RTCIceCandidate('candidate:1 1 udp 1 1.2.3.4 5 typ srflx', '0', 0);

    test('round trip for the same session', () {
      final back = candidateFromMap(candidateToMap(candidate, 's1'), 's1')!;
      expect(back.candidate, candidate.candidate);
      expect(back.sdpMid, '0');
      expect(back.sdpMLineIndex, 0);
    });

    test('drops candidates of other sessions', () {
      expect(candidateFromMap(candidateToMap(candidate, 'old'), 'new'), isNull);
    });

    test('drops malformed entries', () {
      expect(candidateFromMap({'session': 's1'}, 's1'), isNull);
    });
  });

  group('ReconnectBackoff', () {
    test('2, 4, 8, 16, then 30 s', () {
      final b = ReconnectBackoff();
      expect([for (var i = 0; i < 7; i++) b.next().inSeconds], [2, 4, 8, 16, 30, 30, 30]);
      expect(b.attempts, 7);
    });

    test('reset starts over', () {
      final b = ReconnectBackoff()..next()..next();
      b.reset();
      expect(b.next().inSeconds, 2);
    });
  });
}
