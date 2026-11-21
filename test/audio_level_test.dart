import 'dart:math';
import 'dart:typed_data';

import 'package:bebek_monitor_clean/core/audio/audio_level.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a PCM16 (host byte order) chunk from samples.
List<int> pcm(List<int> samples) =>
    Int16List.fromList(samples).buffer.asUint8List().toList();

void main() {
  group('pcm16ChunkToDb (offline)', () {
    test('constant amplitude 1000 -> 60 dB', () {
      expect(pcm16ChunkToDb(pcm(List.filled(256, 1000))), closeTo(60, 1e-9));
    });

    test('sign does not matter (RMS)', () {
      final alternating = List<int>.generate(256, (i) => i.isEven ? 1000 : -1000);
      expect(pcm16ChunkToDb(pcm(alternating)), closeTo(60, 1e-9));
    });

    test('full scale is about 90 dB', () {
      expect(pcm16ChunkToDb(pcm(List.filled(128, 32767))), closeTo(90.3, 0.05));
    });

    test('10x amplitude adds 20 dB', () {
      final quiet = pcm16ChunkToDb(pcm(List.filled(64, 100)));
      final loud = pcm16ChunkToDb(pcm(List.filled(64, 1000)));
      expect(loud - quiet, closeTo(20, 1e-9));
    });

    test('sine wave RMS is amplitude/sqrt2', () {
      const amplitude = 10000;
      final samples = List<int>.generate(
          4800, (i) => (amplitude * sin(2 * pi * 440 * i / 48000)).round());
      final expected = 20 * log(amplitude / sqrt2) / ln10;
      expect(pcm16ChunkToDb(pcm(samples)), closeTo(expected, 0.05));
    });
  });

  group('webrtcAudioLevelToDb (online)', () {
    test('maps linear level to 20*log10(level)+100', () {
      expect(webrtcAudioLevelToDb(1.0), closeTo(100, 1e-9));
      expect(webrtcAudioLevelToDb(0.1), closeTo(80, 1e-9));
      expect(webrtcAudioLevelToDb(0.01), closeTo(60, 1e-9));
      expect(webrtcAudioLevelToDb(0.001), closeTo(40, 1e-9));
    });

    test('silence and negative values give 0', () {
      expect(webrtcAudioLevelToDb(0), 0);
      expect(webrtcAudioLevelToDb(-1), 0);
    });

    test('clamps to 0..120', () {
      expect(webrtcAudioLevelToDb(1e-9), 0);
      expect(webrtcAudioLevelToDb(100), 120);
    });
  });
}
