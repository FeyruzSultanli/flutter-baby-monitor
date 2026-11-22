import 'package:flutter/services.dart';

/// Raw PCM audio for offline (Nearby) mode: 16 kHz, mono, 16-bit
/// little-endian, the format [pcm16ChunkToDb] expects.
///
/// Backed by a small Android platform channel (`OfflineAudio.kt`); offline
/// mode is Android-only, so nothing here is available on iOS.
class OfflineAudio {
  OfflineAudio({
    MethodChannel methodChannel = const MethodChannel(methodChannelName),
    EventChannel micChannel = const EventChannel(micChannelName),
  })  : _methods = methodChannel,
        _mic = micChannel;

  static const String methodChannelName = 'bebek_monitor/offline_audio';
  static const String micChannelName = 'bebek_monitor/offline_audio/mic';
  static const int sampleRate = 16000;

  final MethodChannel _methods;
  final EventChannel _mic;

  /// Microphone PCM chunks. Listening starts recording (RECORD_AUDIO must
  /// already be granted, otherwise the stream reports PERMISSION_DENIED);
  /// cancelling the subscription stops it.
  Stream<Uint8List> micStream() =>
      _mic.receiveBroadcastStream().map((event) => event as Uint8List);

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
