import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

import '../../theme/tokens.dart';
import 'app_audio.dart';

/// Lullaby / white noise sounds played on the baby phone (V2 5.4).
enum SootheTrack {
  whiteNoise('white', 'audio/soothe_white_noise.wav'),
  rain('rain', 'audio/soothe_rain.wav'),
  heartbeat('heart', 'audio/soothe_heartbeat.wav'),
  dandini('dandini', 'audio/soothe_dandini.wav');

  const SootheTrack(this.id, this.asset);
  final String id;
  final String asset;

  static SootheTrack? byId(Object? id) =>
      SootheTrack.values.where((t) => t.id == id).firstOrNull;
}

/// What the baby phone should play; stored in the room (`soothe`) or sent
/// over Nearby. `endsAt` null = until stopped.
@immutable
class SootheState {
  const SootheState({this.track, this.volume = 0.4, this.endsAt});

  final SootheTrack? track;
  final double volume;
  final DateTime? endsAt;

  static const SootheState off = SootheState();

  bool isPlayingAt(DateTime now) => track != null && (endsAt == null || endsAt!.isAfter(now));

  Map<String, Object?> toMap() => {
        'track': track?.id,
        'volume': double.parse(volume.toStringAsFixed(2)),
        'endsAt': endsAt?.millisecondsSinceEpoch,
      };

  static SootheState fromMap(Object? raw) {
    if (raw is! Map) return off;
    final volume = raw['volume'];
    final ends = raw['endsAt'];
    DateTime? endsAt;
    if (ends is int) {
      endsAt = DateTime.fromMillisecondsSinceEpoch(ends);
    } else if (ends != null) {
      try {
        endsAt = (ends as dynamic).toDate() as DateTime?; // Firestore Timestamp
      } catch (_) {}
    }
    return SootheState(
      track: SootheTrack.byId(raw['track']),
      volume: volume is num ? volume.toDouble().clamp(0.0, 1.0) : 0.4,
      endsAt: endsAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SootheState && other.track == track && other.volume == volume && other.endsAt == endsAt;

  @override
  int get hashCode => Object.hash(track, volume, endsAt);
}

/// Night light colors (V2 5.5).
enum NightLightColor {
  amber('amber', NinniColors.lightAmber),
  pink('pink', NinniColors.lightPink),
  purple('purple', NinniColors.lightPurple),
  blue('blue', NinniColors.lightBlue);

  const NightLightColor(this.id, this.color);
  final String id;
  final Color color;

  static NightLightColor byId(Object? id) =>
      NightLightColor.values.where((c) => c.id == id).firstOrNull ?? NightLightColor.amber;
}

@immutable
class NightLightState {
  const NightLightState({this.on = false, this.color = NightLightColor.amber});
  final bool on;
  final NightLightColor color;

  static const NightLightState off = NightLightState();

  Map<String, Object?> toMap() => {'on': on, 'color': color.id};

  static NightLightState fromMap(Object? raw) {
    if (raw is! Map) return off;
    return NightLightState(on: raw['on'] == true, color: NightLightColor.byId(raw['color']));
  }

  @override
  bool operator ==(Object other) => other is NightLightState && other.on == on && other.color == color;

  @override
  int get hashCode => Object.hash(on, color);
}

/// Cry detection while our own sound plays (V2 5.4, DECISIONS A29): the
/// sound reaches the microphone, so the threshold is raised to the measured
/// level of the sound + [margin], never by more than [maxRaise]. A crying
/// baby next to the phone is far louder than a quiet lullaby, so the alarm
/// still fires; the parent also controls the volume (max 70 %).
class SootheThreshold {
  static const double margin = 8;
  static const double maxRaise = 12;
  static const Duration measureFor = Duration(seconds: 4);

  final List<double> _samples = [];
  DateTime? _measureUntil;
  double? _baseline;
  bool _active = false;

  bool get active => _active;
  double? get baseline => _baseline;

  /// A sound started or its volume changed: measure again.
  void start(DateTime now) {
    _active = true;
    _baseline = null;
    _samples.clear();
    _measureUntil = now.add(measureFor);
  }

  void stop() {
    _active = false;
    _baseline = null;
    _samples.clear();
    _measureUntil = null;
  }

  /// Feed the measured level (not while an alarm is going on).
  void add(double db, DateTime now, {bool alarming = false}) {
    final until = _measureUntil;
    if (!_active || until == null) return;
    if (now.isBefore(until)) {
      if (!alarming) _samples.add(db);
      return;
    }
    if (_samples.isNotEmpty) {
      final sorted = List.of(_samples)..sort();
      _baseline = sorted[sorted.length ~/ 2];
    }
    _measureUntil = null;
  }

  /// The threshold to use instead of [user] right now.
  double effective(double user) {
    if (!_active) return user;
    final base = _baseline;
    // While measuring: the cautious upper bound, so the first seconds of a
    // loud lullaby do not raise a false alarm.
    final wanted = base == null ? user + maxRaise : base + margin;
    return wanted.clamp(user, user + maxRaise);
  }
}

/// Push-to-talk on the baby phone (V2 5.3): while the parent's voice comes
/// in, and for [tail] afterwards, cry detection pauses.
class TalkGate {
  TalkGate({this.tail = const Duration(seconds: 3), this.minLevel = 0.02});
  final Duration tail;
  /// WebRTC inbound audioLevel (0..1) that counts as speech.
  final double minLevel;
  DateTime? _lastHeard;

  void onRemoteLevel(double? level, DateTime now) {
    if (level != null && level >= minLevel) _lastHeard = now;
  }

  bool suppressed(DateTime now) {
    final last = _lastHeard;
    return last != null && now.difference(last) < tail;
  }

  void reset() => _lastHeard = null;
}

/// Plays a [SootheState] on the baby phone with audioplayers (looped).
class SoothePlayer {
  AudioPlayer? _player;
  SootheTrack? _track;
  double _volume = 0;
  Timer? _end;

  /// Volume ceiling (DECISIONS A29).
  static const double maxVolume = 0.7;

  SootheTrack? get track => _track;

  Future<void> apply(SootheState state, {required VoidCallback onEnded}) async {
    final now = DateTime.now();
    if (!state.isPlayingAt(now)) {
      await stop();
      return;
    }
    await AppAudio.configure();
    final player = _player ??= AudioPlayer(playerId: 'ninni_soothe');
    final volume = (state.volume * maxVolume).clamp(0.0, maxVolume);
    try {
      if (state.track != _track) {
        _track = state.track;
        await player.setReleaseMode(ReleaseMode.loop);
        await player.play(AssetSource(state.track!.asset), volume: volume);
      } else if ((volume - _volume).abs() > 0.001) {
        await player.setVolume(volume);
      }
      _volume = volume;
    } catch (e) {
      debugPrint('Soothe sound failed: $e');
    }
    _end?.cancel();
    final ends = state.endsAt;
    if (ends != null) {
      _end = Timer(ends.difference(now), () {
        unawaited(stop());
        onEnded();
      });
    }
  }

  Future<void> stop() async {
    _end?.cancel();
    _end = null;
    _track = null;
    _volume = 0;
    try {
      await _player?.stop();
    } catch (e) {
      debugPrint('Stopping soothe sound failed: $e');
    }
  }

  Future<void> dispose() async {
    await stop();
    final p = _player;
    _player = null;
    await p?.dispose();
  }
}
