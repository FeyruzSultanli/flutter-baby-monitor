// Single-device check of the online cry-detection input: the WebRTC
// "media-source" audioLevel that WebRTCService.getAudioLevel() reads (on both
// Android and iOS; no extra microphone reader, so it never competes with
// WebRTC for the microphone or the iOS audio session).
//
// It mirrors the baby's two states:
//   1. standby: local offer only (no parent yet),
//   2. connected: an in-process loopback peer answers.
// For each it reports whether audioLevel is present and its range.
//
//   flutter test integration_test/webrtc_audio_level_test.dart -d <device>
//
// Grant the microphone first (Android: adb shell pm grant ... RECORD_AUDIO;
// iOS simulator: xcrun simctl privacy <udid> grant microphone <bundle id>).

import 'package:bebek_monitor_clean/core/audio/pcm_microphone.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:integration_test/integration_test.dart';

Future<List<double>> sampleAudioLevels(
    WidgetTester tester, RTCPeerConnection pc, Duration duration) async {
  final levels = <double>[];
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    final stats = await pc.getStats();
    for (final report in stats) {
      if ((report.type == 'media-source' || report.type == 'track') &&
          report.values['kind'] == 'audio' &&
          report.values['audioLevel'] is num) {
        levels.add((report.values['audioLevel'] as num).toDouble());
        break;
      }
    }
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)));
  }
  return levels;
}

String describe(List<double> levels) {
  if (levels.isEmpty) return 'samples=0';
  final min = levels.reduce((a, b) => a < b ? a : b);
  final max = levels.reduce((a, b) => a > b ? a : b);
  return 'samples=${levels.length} min=${min.toStringAsFixed(4)} '
      'max=${max.toStringAsFixed(4)}';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('WebRTC local audioLevel in standby and when connected',
      (tester) async {
    // ignore: avoid_print
    print('AUDIO_LEVEL step=getUserMedia');
    final stream = await navigator.mediaDevices
        .getUserMedia({'audio': true, 'video': false});
    // ignore: avoid_print
    print('AUDIO_LEVEL step=meter');

    // 0. As in the app: the standby meter (record) runs before a call and
    //    is stopped before WebRTC starts capturing. WebRTC must still get
    //    the microphone afterwards (iOS audio session handoff).
    final mic = PcmMicrophone();
    final meterChunks = <int>[];
    final meterSub =
        (await mic.start()).listen((c) => meterChunks.add(c.length));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)));
    await meterSub.cancel();
    await mic.stop();
    // ignore: avoid_print
    print('AUDIO_LEVEL standby_meter chunks=${meterChunks.length}');
    final pc = await createPeerConnection({'sdpSemantics': 'unified-plan'});
    for (final track in stream.getAudioTracks()) {
      await pc.addTrack(track, stream);
    }

    // 1. Standby, as WebRTCService does before a parent joins.
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    final standby =
        await sampleAudioLevels(tester, pc, const Duration(seconds: 4));
    // ignore: avoid_print
    print('AUDIO_LEVEL standby ${describe(standby)}');

    // 2. Connected to an in-process "parent".
    // Candidates are queued until both descriptions are set (cf. B64).
    final remote = await createPeerConnection({'sdpSemantics': 'unified-plan'});
    final toRemote = <RTCIceCandidate>[];
    final toLocal = <RTCIceCandidate>[];
    var ready = false;
    pc.onIceCandidate = (c) => ready ? remote.addCandidate(c) : toRemote.add(c);
    remote.onIceCandidate = (c) => ready ? pc.addCandidate(c) : toLocal.add(c);
    await remote.setRemoteDescription(offer);
    final answer = await remote.createAnswer();
    await remote.setLocalDescription(answer);
    await pc.setRemoteDescription(answer);
    ready = true;
    for (final c in toRemote) {
      await remote.addCandidate(c);
    }
    for (final c in toLocal) {
      await pc.addCandidate(c);
    }
    final connected =
        await sampleAudioLevels(tester, pc, const Duration(seconds: 6));
    // ignore: avoid_print
    print('AUDIO_LEVEL connected ${describe(connected)} '
        'state=${pc.connectionState}');

    await remote.close();
    await pc.close();
    for (final t in stream.getTracks()) {
      await t.stop();
    }
    await stream.dispose();

    expect(meterChunks, isNotEmpty, reason: 'standby meter delivered audio');
    expect(connected, isNotEmpty,
        reason: 'media-source audioLevel must be reported once connected');
  });
}
