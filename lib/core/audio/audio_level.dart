import 'dart:math';
import 'dart:typed_data';

/// Converts a chunk of 16-bit PCM audio (host byte order) to a positive
/// dB value: `20 * log10(rms)`, roughly 0..90 for full-scale input.
/// Used for offline-mode cry detection.
double pcm16ChunkToDb(List<int> bytes) {
  final int16Data = Int16List.view(Uint8List.fromList(bytes).buffer);

  double sumSquare = 0;
  for (final sample in int16Data) {
    sumSquare += sample * sample;
  }

  final rms = sqrt(sumSquare / int16Data.length);
  return 20 * log(rms) / ln10;
}

/// Converts a WebRTC `audioLevel` stat (linear 0..1, 1 = 0 dBFS) to the
/// 0..120 scale used for online-mode cry detection: `20 * log10(level) + 100`.
double webrtcAudioLevelToDb(double level) {
  double db = 0;
  if (level > 0) {
    db = 20 * log(level) / ln10 + 100;
  }
  return db.clamp(0.0, 120.0);
}
