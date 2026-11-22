import 'dart:typed_data';

import 'package:bebek_monitor_clean/core/audio/audio_level.dart';
import 'package:bebek_monitor_clean/core/audio/cry_detector.dart';
import 'package:bebek_monitor_clean/core/audio/pcm_microphone.dart';
import 'package:bebek_monitor_clean/core/offline/offline_payload.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

/// Little-endian PCM16 bytes, as `record` delivers them on Android and iOS.
Uint8List pcm16(List<int> samples) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  group('PcmMicrophone.config', () {
    test('is the PCM format the dB code and Nearby payloads use', () {
      const c = PcmMicrophone.config;
      expect(c.encoder, AudioEncoder.pcm16bits);
      expect(c.sampleRate, 16000);
      expect(c.numChannels, 1);
    });

    test('keeps Android audio routing as before (mic, no Bluetooth SCO)', () {
      const c = PcmMicrophone.config;
      expect(c.androidConfig.audioSource, AndroidAudioSource.mic);
      expect(c.androidConfig.manageBluetooth, isFalse);
      expect(c.androidConfig.muteAudio, isFalse);
    });
  });

  group('PeakDbTracker', () {
    test('returns null when no chunk arrived', () {
      expect(PeakDbTracker().take(), isNull);
    });

    test('keeps the loudest chunk of the interval and then resets', () {
      final tracker = PeakDbTracker()
        ..addChunk(pcm16(List.filled(256, 100)))
        ..addChunk(pcm16(List.filled(256, 1000)))
        ..addChunk(pcm16(List.filled(256, 300)));

      expect(tracker.take(),
          closeTo(pcm16ChunkToDb(pcm16(List.filled(256, 1000))), 1e-9));
      expect(tracker.take(), isNull);
    });

    test('a short loud chunk between two polls is not missed', () {
      final tracker = PeakDbTracker();
      for (var i = 0; i < 6; i++) {
        tracker.addChunk(pcm16(List.filled(256, i == 3 ? 20000 : 50)));
      }
      expect(tracker.take(), greaterThan(90));
    });

    test('sustained loud chunks trigger the cry detector after 2 s', () {
      final tracker = PeakDbTracker();
      final detector = CryDetector(threshold: 60);
      final start = DateTime(2026);
      bool? alarmAt(int ms) {
        tracker.addChunk(pcm16(List.filled(512, 8000)));
        return detector.update(tracker.take()!, start.add(Duration(milliseconds: ms)));
      }

      expect(alarmAt(0), isFalse);
      expect(alarmAt(1000), isFalse);
      expect(alarmAt(2250), isTrue);
    });
  });

  test('microphone chunks survive the Nearby payload framing', () {
    final chunk = pcm16(List.filled(256, 1000));
    final decoded = OfflinePayload.decode(
        OfflinePayload.encode(OfflinePayloadType.audio, chunk));
    expect(decoded!.type, OfflinePayloadType.audio);
    expect(decoded.body, chunk);
    expect(pcm16ChunkToDb(decoded.body), closeTo(69.69, 0.01));
  });
}
