import 'package:flutter/services.dart';

/// Speaker for offline (Nearby) mode: plays raw PCM chunks (16 kHz, mono,
/// 16-bit little-endian) as they arrive from the baby. The microphone side is
/// [PcmMicrophone] (`record` package).
///
/// Backed by a small Android platform channel (`OfflineAudio.kt`, AudioTrack);
/// offline mode is Android-only, so nothing here is available on iOS.
class OfflineAudio {
  OfflineAudio({
    MethodChannel methodChannel = const MethodChannel(methodChannelName),
  }) : _methods = methodChannel;

  static const String methodChannelName = 'bebek_monitor/offline_audio';
  static const int sampleRate = 16000;

  final MethodChannel _methods;

  /// Prepares and starts the speaker. Returns false if the device could not
  /// create the audio track.
  Future<bool> startPlayer() async =>
      await _methods.invokeMethod<bool>('startPlayer') ?? false;

  /// Queues a PCM chunk for playback (no-op while the player is stopped).
  Future<void> writeChunk(Uint8List data) =>
      _methods.invokeMethod<void>('writeChunk', {'data': data});

  /// Stops the speaker and drops what is still queued.
  Future<void> stopPlayer() => _methods.invokeMethod<void>('stopPlayer');
}
