import 'dart:math';
import 'dart:typed_data';

import 'package:bebek_monitor_clean/core/audio/audio_level.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a PCM16 (host byte order) chunk from samples.
List<int> pcm(List<int> samples) =>
    Int16List.fromList(samples).buffer.asUint8List().toList();

void main() {
  // Offline values are on the same scale as online: 20*log10(rms/32768)+100.
  double expectedDb(double rms) => 20 * log(rms / 32768) / ln10 + 100;

  group('pcm16ChunkToDb (offline)', () {
    test('constant amplitude 1000 -> ~69.7 on the shared scale', () {
      expect(pcm16ChunkToDb(pcm(List.filled(256, 1000))), closeTo(expectedDb(1000), 1e-9));
      expect(pcm16ChunkToDb(pcm(List.filled(256, 1000))), closeTo(69.69, 0.01));
    });

    test('sign does not matter (RMS)', () {
      final alternating = List<int>.generate(256, (i) => i.isEven ? 1000 : -1000);
      expect(pcm16ChunkToDb(pcm(alternating)), closeTo(expectedDb(1000), 1e-9));
    });

    test('full scale is ~100, same as WebRTC level 1.0', () {
      expect(pcm16ChunkToDb(pcm(List.filled(128, 32767))), closeTo(100, 0.01));
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
      expect(pcm16ChunkToDb(pcm(samples)), closeTo(expectedDb(amplitude / sqrt2), 0.05));
    });
  });

  group('one scale for online and offline (B28)', () {
    test('same loudness gives the same dB in both modes', () {
      for (final rms in [10.0, 100.0, 1000.0, 10000.0]) {
        final offline = pcm16ChunkToDb(pcm(List.filled(256, rms.round())));
        final online = webrtcAudioLevelToDb(rms / 32768);
        expect(offline, closeTo(online, 1e-6), reason: 'rms=$rms');
      }
    });
  });

  group('pcm16ChunkToDb edge cases (B11)', () {
    test('digital silence gives 0, not -Infinity', () {
      final db = pcm16ChunkToDb(pcm(List.filled(256, 0)));
      expect(db, 0);
      expect(db.isFinite, isTrue);
    });

    test('empty chunk gives 0, not NaN', () {
      expect(pcm16ChunkToDb(const []), 0);
    });

    test('single byte gives 0 instead of throwing', () {
      expect(pcm16ChunkToDb(const [7]), 0);
    });

    test('a trailing odd byte is ignored', () {
      final chunk = pcm(List.filled(64, 1000))..add(255);
      expect(pcm16ChunkToDb(chunk), closeTo(expectedDb(1000), 1e-9));
    });

    test('rms below one sample step gives 0 (never negative)', () {
      final samples = List<int>.filled(100, 0)..[0] = 1; // rms = 0.1
      expect(pcm16ChunkToDb(pcm(samples)), 0);
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
