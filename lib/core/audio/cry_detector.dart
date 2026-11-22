/// Turns a stream of noise readings into a cry alarm (decision D5, B27).
///
/// The alarm starts only after the level has stayed at or above [threshold]
/// for [sustain] (default 2 s), so a single door slam or cough does not
/// trigger it. Short dips below the threshold (breathing pauses while crying)
/// shorter than [gapTolerance] do not restart the timer, and an active alarm
/// ends once the level stayed below the threshold for longer than
/// [gapTolerance].
class CryDetector {
  CryDetector({
    this.threshold = 60,
    this.sustain = defaultSustain,
    this.gapTolerance = defaultGapTolerance,
  });

  static const Duration defaultSustain = Duration(seconds: 2);
  static const Duration defaultGapTolerance = Duration(milliseconds: 600);

  /// Noise level (shared scale, see audio_level.dart) that counts as loud.
  double threshold;
  final Duration sustain;
  final Duration gapTolerance;

  DateTime? _aboveSince;
  DateTime? _lastAbove;
  bool _alarm = false;

  bool get alarm => _alarm;

  /// How long the level has been at or above the threshold (diagnostics).
  Duration aboveFor(DateTime now) {
    final since = _aboveSince;
    return since == null ? Duration.zero : now.difference(since);
  }

  /// Feeds one reading taken at [now] and returns whether the alarm is on.
  bool update(double db, DateTime now) {
    if (db >= threshold) {
      _aboveSince ??= now;
      _lastAbove = now;
      if (!_alarm && now.difference(_aboveSince!) >= sustain) {
        _alarm = true;
      }
    } else {
      final lastAbove = _lastAbove;
      if (lastAbove == null || now.difference(lastAbove) > gapTolerance) {
        _aboveSince = null;
        _lastAbove = null;
        _alarm = false;
      }
    }
    return _alarm;
  }

  void reset() {
    _aboveSince = null;
    _lastAbove = null;
    _alarm = false;
  }
}
