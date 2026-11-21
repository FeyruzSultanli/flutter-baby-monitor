import 'dart:math';
import 'dart:typed_data';

/// Converts a chunk of 16-bit PCM audio (host byte order) to a positive
/// dB value: `20 * log10(rms)`, roughly 0..90 for full-scale input.
/// Used for offline-mode cry detection.
///
/// Always returns a finite value >= 0 (B11): silence or an empty chunk gives
/// 0 instead of -Infinity/NaN (which jsonEncode cannot encode), and a
/// trailing odd byte is ignored instead of throwing.
double pcm16ChunkToDb(List<int> bytes) {
  final evenLength = bytes.length - bytes.length % 2;
  if (evenLength == 0) return 0;
  final int16Data = Int16List.view(
    Uint8List.fromList(bytes.sublist(0, evenLength)).buffer,
  );

  double sumSquare = 0;
  for (final sample in int16Data) {
    sumSquare += sample * sample;
  }

  final rms = sqrt(sumSquare / int16Data.length);
  if (rms < 1) return 0;
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
