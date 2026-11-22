import 'dart:math';

import 'package:bebek_monitor_clean/core/audio/audio_level.dart';
import 'package:bebek_monitor_clean/core/monitor/cry_freshness.dart';
import 'package:bebek_monitor_clean/core/webrtc/rtc_audio_stats.dart';
import 'package:bebek_monitor_clean/core/webrtc/sdp_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RtcStatsSnapshot.parse (V2.1 §1/§2)', () {
    test('reads standard stats', () {
      final s = RtcStatsSnapshot.parse([
        ('media-source', {'kind': 'audio', 'audioLevel': 0.25, 'totalAudioEnergy': 1.5, 'totalSamplesDuration': 30.0}),
        ('media-source', {'kind': 'video', 'width': 640}),
        ('outbound-rtp', {'kind': 'audio', 'bytesSent': 1200, 'packetsSent': 10}),
        ('outbound-rtp', {'kind': 'video', 'bytesSent': 99999}),
        ('inbound-rtp', {'kind': 'audio', 'audioLevel': 0.1, 'bytesReceived': 500, 'packetsReceived': 5, 'packetsLost': 1}),
        ('inbound-rtp', {'kind': 'video', 'bytesReceived': 7000, 'framesDecoded': 42, 'packetsReceived': 95, 'packetsLost': 0}),
        ('transport', {'selectedCandidatePairId': 'p1'}),
        ('candidate-pair', {'id': 'p1', 'state': 'succeeded', 'currentRoundTripTime': 0.08}),
        ('candidate-pair', {'id': 'p2', 'state': 'failed', 'currentRoundTripTime': 2.0}),
      ]);
      expect(s.localLevel, 0.25);
      expect(s.localEnergy, 1.5);
      expect(s.localDuration, 30.0);
      expect(s.audioBytesSent, 1200);
      expect(s.audioPacketsSent, 10);
      expect(s.remoteLevel, 0.1);
      expect(s.audioBytesReceived, 500);
      expect(s.inboundBytes, 7500);
      expect(s.videoFramesDecoded, 42);
      expect(s.rttMs, closeTo(80, 0.001));
      expect(s.packetsLost, 1);
      expect(s.packetsReceived, 100);
    });

    test('legacy track stats and missing audioLevel', () {
      final s = RtcStatsSnapshot.parse([
        ('track', {'kind': 'audio', 'remoteSource': true, 'audioLevel': 0.3}),
        // A real iPhone may report energy without a usable audioLevel.
        ('track', {'kind': 'audio', 'remoteSource': false, 'totalAudioEnergy': 2.0, 'totalSamplesDuration': 10.0}),
      ]);
      expect(s.remoteLevel, 0.3);
      expect(s.localLevel, isNull);
      expect(s.localEnergy, 2.0);
    });

    test('empty stats', () {
      final s = RtcStatsSnapshot.parse(const []);
      expect(s.localLevel, isNull);
      expect(s.inboundBytes, isNull);
      expect(s.rttMs, isNull);
    });
  });

  group('EnergyLevelMeter', () {
    test('RMS from energy growth', () {
      final m = EnergyLevelMeter();
      expect(m.update(1.0, 10.0), isNull); // first sample
      // Constant amplitude a over 0.25 s adds a^2 * 0.25 to the energy.
      const a = 0.2;
      final level = m.update(1.0 + a * a * 0.25, 10.25)!;
      expect(level, closeTo(a, 1e-9));
      // A loud cry (a = 0.5) maps well above the default threshold 60.
      final loud = m.update(1.0 + a * a * 0.25 + 0.25 * 0.25, 10.5)!;
      expect(webrtcAudioLevelToDb(loud), greaterThan(90));
      expect(webrtcAudioLevelToDb(loud), closeTo(20 * log(0.5) / ln10 + 100, 1e-6));
    });

    test('ignores resets and missing counters', () {
      final m = EnergyLevelMeter();
      m.update(5, 10);
      expect(m.update(1, 2), isNull); // counters went back (new peer)
      expect(m.update(null, 3), isNull);
      expect(m.update(1, 2), isNull); // no new samples
    });
  });

  test('ByteFlow', () {
    final f = ByteFlow();
    final t0 = DateTime(2026, 11, 23, 22);
    f.update(100, t0);
    expect(f.flowing(t0), isFalse);
    f.update(180, t0.add(const Duration(milliseconds: 200)));
    expect(f.flowing(t0.add(const Duration(milliseconds: 300))), isTrue);
    expect(f.flowing(t0.add(const Duration(seconds: 3))), isFalse);
  });

  test('ConnectionQuality from RTT and loss', () {
    expect(ConnectionQualityMeter.classify(rttMs: 60), ConnectionQuality.good);
    expect(ConnectionQualityMeter.classify(rttMs: 300), ConnectionQuality.fair);
    expect(ConnectionQualityMeter.classify(rttMs: 900), ConnectionQuality.poor);
    expect(ConnectionQualityMeter.classify(rttMs: 50, loss: 0.1), ConnectionQuality.poor);
    final m = ConnectionQualityMeter();
    m.update(const RtcStatsSnapshot(rttMs: 40, packetsLost: 0, packetsReceived: 100));
    expect(m.update(const RtcStatsSnapshot(rttMs: 40, packetsLost: 0, packetsReceived: 200)),
        ConnectionQuality.good);
    for (var i = 0; i < 5; i++) {
      m.update(RtcStatsSnapshot(rttMs: 40, packetsLost: 30 * (i + 1), packetsReceived: 200 + 70 * (i + 1)));
    }
    expect(m.quality, ConnectionQuality.poor);
  });

  group('SDP', () {
    const answer = 'v=0\r\no=- 1 2 IN IP4 127.0.0.1\r\ns=-\r\n'
        'm=audio 9 UDP/TLS/RTP/SAVPF 111\r\na=mid:0\r\na=recvonly\r\n'
        'm=video 9 UDP/TLS/RTP/SAVPF 96\r\na=mid:1\r\na=sendrecv\r\n';
    test('direction and mid per kind', () {
      expect(sdpDirection(answer), 'recvonly');
      expect(sdpDirection(answer, kind: 'video'), 'sendrecv');
      expect(sdpMid(answer), '0');
      expect(sdpMid(answer, kind: 'video'), '1');
      expect(sdpDirection('v=0\r\nm=audio 9 X 0\r\na=mid:a\r\n'), 'sendrecv');
      expect(sdpDirection(null), isNull);
      expect(sdpDirection('v=0\r\nm=video 9 X 0\r\n'), isNull);
    });
  });

  group('CryFreshness (parent clock skew, V2.1 §1)', () {
    final server = DateTime.utc(2026, 11, 23, 21, 0, 0);

    test('parent clock 2 min ahead still sees new cry states', () {
      final f = CryFreshness();
      const skew = Duration(minutes: 2);
      // First snapshot: judged by server time -> stale with this skew.
      expect(f.isFresh(server, server.add(skew)), isFalse);
      // The baby writes again 5 s later: a change, so fresh.
      final s2 = server.add(const Duration(seconds: 5));
      expect(f.isFresh(s2, s2.add(skew)), isTrue);
      expect(f.skew, skew);
      // Same stamp seen again 10 s later (another field changed): still fresh.
      expect(f.isFresh(s2, s2.add(skew).add(const Duration(seconds: 10))), isTrue);
      // No update for 25 s: stale.
      expect(f.isFresh(s2, s2.add(skew).add(const Duration(seconds: 25))), isFalse);
    });

    test('an old state from before joining is not fresh', () {
      final f = CryFreshness();
      expect(f.isFresh(server, server.add(const Duration(minutes: 30))), isFalse);
    });

    test('no skew: first state is fresh', () {
      final f = CryFreshness();
      expect(f.isFresh(server, server.add(const Duration(seconds: 1))), isTrue);
      expect(f.isFresh(null, server), isTrue);
      f.reset();
      expect(f.skew, isNull);
    });
  });
}
