import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

/// Shared audio settings for sounds the app plays itself (alarms, and in
/// phase 3 lullabies) next to a WebRTC call.
///
/// iOS has one audio session per app: `playAndRecord` + `mixWithOthers` +
/// `defaultToSpeaker` matches what WebRTC uses, so starting or stopping our
/// sounds does not reconfigure the call's session. Android: the alarm uses the
/// alarm stream and requests no audio focus (WebRTC keeps playing).
class AppAudio {
  AppAudio._();

  static bool _configured = false;

  static Future<void> configure() async {
    if (_configured || kIsWeb) return;
    _configured = true;
    try {
      await AudioPlayer.global.setAudioContext(AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playAndRecord,
          options: const {
            AVAudioSessionOptions.mixWithOthers,
            AVAudioSessionOptions.defaultToSpeaker,
            AVAudioSessionOptions.allowBluetoothA2DP,
          },
        ),
        android: const AudioContextAndroid(
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.none,
        ),
      ));
    } catch (e) {
      debugPrint('Audio context setup failed: $e');
    }
  }

  static const AudioContextAndroid alarmAndroid = AudioContextAndroid(
    contentType: AndroidContentType.sonification,
    usageType: AndroidUsageType.alarm,
    audioFocus: AndroidAudioFocus.none,
  );
}

/// Looping alarm with a vibration pattern (connection lost, V2 5.6).
class AlarmSound {
  AlarmSound({this.asset = 'audio/alarm_connection.wav'});

  final String asset;
  AudioPlayer? _player;
  Timer? _vibrationTimer;
  bool _playing = false;

  bool get isPlaying => _playing;

  Future<void> start() async {
    if (_playing) return;
    _playing = true;
    await AppAudio.configure();
    try {
      final player = _player ??= AudioPlayer(playerId: 'ninni_alarm');
      if (defaultTargetPlatform == TargetPlatform.android) {
        await player.setAudioContext(
            AudioContext(android: AppAudio.alarmAndroid, iOS: AudioContextIOS()));
      }
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource(asset), volume: 1.0);
    } catch (e) {
      debugPrint('Alarm sound failed: $e');
    }
    _vibrate();
    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(const Duration(seconds: 3), (_) => _vibrate());
  }

  void _vibrate() {
    unawaited(Future(() async {
      try {
        await Vibration.vibrate(pattern: [0, 400, 200, 400]);
      } catch (_) {}
    }));
  }

  Future<void> stop() async {
    if (!_playing) return;
    _playing = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    try {
      await _player?.stop();
    } catch (e) {
      debugPrint('Stopping alarm sound failed: $e');
    }
    try {
      await Vibration.cancel();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    final p = _player;
    _player = null;
    await p?.dispose();
  }
}
