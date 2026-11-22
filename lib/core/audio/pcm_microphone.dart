import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'audio_level.dart';

/// Microphone as a stream of raw PCM chunks (16 kHz, mono, 16-bit
/// little-endian), the format [pcm16ChunkToDb] and the offline Nearby audio
/// payload use. Backed by the `record` package (BSD-3-Clause), on Android
/// and iOS.
///
/// Used by
/// - offline mode (baby): the chunks are sent over Nearby and measured;
/// - online mode (baby) while no parent is connected: WebRTC does not open
///   the microphone before a call is set up, so its audio level stays 0;
///   this meter keeps cry detection working until the parent joins.
///   It is stopped before WebRTC negotiates a call so the two never hold the
///   microphone at the same time.
class PcmMicrophone {
  static const int sampleRate = 16000;

  /// Upper bounds for the native start/stop calls. A microphone that does
  /// not answer must not block the queue (and with it the start of a call,
  /// which waits for the standby meter to stop).
  static const Duration startTimeout = Duration(seconds: 5);
  static const Duration stopTimeout = Duration(seconds: 3);

  static const RecordConfig config = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: sampleRate,
    numChannels: 1,
    androidConfig: AndroidRecordConfig(
      audioSource: AndroidAudioSource.mic,
      // Do not switch the audio route to a Bluetooth headset (SCO).
      manageBluetooth: false,
    ),
  );

  AudioRecorder? _recorder;
  Future<void> _pending = Future.value();

  bool get isRunning => _recorder != null;

  /// Starts recording and returns the PCM stream. Throws when the microphone
  /// is unavailable (e.g. permission denied).
  Future<Stream<Uint8List>> start() {
    final completer = Completer<Stream<Uint8List>>();
    _pending = _pending.then((_) async {
      try {
        await _stopNow();
        final recorder = AudioRecorder();
        // Owned from here on, so a later stop() releases it even if
        // starting times out.
        _recorder = recorder;
        if (!await recorder.hasPermission(request: false).timeout(startTimeout)) {
          throw StateError('Microphone permission not granted');
        }
        final stream = await recorder.startStream(config).timeout(startTimeout);
        completer.complete(stream);
      } catch (e, st) {
        await _stopNow();
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  /// Stops recording (no-op when not running). Start/stop calls run in order.
  Future<void> stop() {
    _pending = _pending.then((_) => _stopNow());
    return _pending;
  }

  Future<void> _stopNow() async {
    final recorder = _recorder;
    _recorder = null;
    if (recorder == null) return;
    try {
      await recorder.stop().timeout(stopTimeout);
    } catch (e) {
      debugPrint('Microphone stop failed: $e');
    }
    try {
      await recorder.dispose().timeout(stopTimeout);
    } catch (e) {
      debugPrint('Microphone dispose failed: $e');
    }
  }
}

/// Loudest level (on the shared dB scale) among the PCM chunks received since
/// the last [take]. The noise poll reads it every 250 ms, so a short loud
/// chunk between two polls is not missed.
class PeakDbTracker {
  double? _peak;

  void addChunk(List<int> pcm16) {
    final db = pcm16ChunkToDb(pcm16);
    final peak = _peak;
    if (peak == null || db > peak) _peak = db;
  }

  /// Returns the peak since the last call (null when no chunk arrived) and
  /// starts a new interval.
  double? take() {
    final peak = _peak;
    _peak = null;
    return peak;
  }
}
