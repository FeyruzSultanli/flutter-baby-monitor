import 'dart:math';
import 'dart:typed_data';

/// Converts a chunk of 16-bit PCM audio (host byte order) to the app's single
/// noise scale (see [webrtcAudioLevelToDb]): the chunk's RMS is normalized to
/// full scale (32768) and mapped with `20 * log10(level) + 100`, so offline
/// (Nearby) and online (WebRTC) cry detection use the same threshold (B28).
///
/// Always returns a finite value in 0..120 (B11): silence or an empty chunk
/// gives 0, and a trailing odd byte is ignored instead of throwing.
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
  return webrtcAudioLevelToDb(rms / pcm16FullScale);
}

/// Full-scale amplitude of 16-bit PCM.
const double pcm16FullScale = 32768;

/// Converts a WebRTC `audioLevel` stat (linear 0..1, 1 = 0 dBFS) to the app's
/// noise scale: `20 * log10(level) + 100`, clamped to 0..120. Full scale is
/// 100, typical speech is roughly 55..75.
double webrtcAudioLevelToDb(double level) {
  double db = 0;
  if (level > 0) {
    db = 20 * log(level) / ln10 + 100;
  }
  return db.clamp(0.0, 120.0);
}

/// Cry detection level during a WebRTC call (V2.1 §1, B75): the louder of
/// `audioLevel` (short peak) and the energy RMS of the poll interval, so a
/// device where one of the two stays 0 or is missing (seen on real iPhones)
/// still detects crying. Null when neither is available.
double? callAudioDb(double? audioLevel, double? energyRms) {
  final a = audioLevel == null ? null : webrtcAudioLevelToDb(audioLevel);
  final b = energyRms == null ? null : webrtcAudioLevelToDb(energyRms);
  if (a == null) return b;
  if (b == null) return a;
  return a > b ? a : b;
}
