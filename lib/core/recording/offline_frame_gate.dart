/// Decides which incoming offline frames are stored for a recording, and when
/// the recording hit its length limit (decision D7).
///
/// Frames are sampled at a fixed rate that matches the GIF playback rate, so
/// the GIF plays in real time, and storage stops after [maxDuration].
class OfflineFrameGate {
  OfflineFrameGate({
    this.maxDuration = defaultMaxDuration,
    this.frameInterval = defaultFrameInterval,
  });

  /// Longest offline recording.
  static const Duration defaultMaxDuration = Duration(seconds: 20);

  /// 10 fps, matching the GIF frame delay of 10 centiseconds.
  static const Duration defaultFrameInterval = Duration(milliseconds: 100);

  final Duration maxDuration;
  final Duration frameInterval;

  DateTime? _startedAt;
  // Next sampling slot (start + n * frameInterval). Slot-based sampling keeps
  // the stored rate at 1/frameInterval even when input frames do not line up
  // with the interval (e.g. 30 fps input).
  DateTime? _nextSlot;
  int _accepted = 0;
  bool _limitReached = false;

  /// Maximum number of frames one recording can contain.
  int get maxFrames => maxDuration.inMilliseconds ~/ frameInterval.inMilliseconds;

  int get acceptedFrames => _accepted;

  bool get limitReached => _limitReached;

  void start(DateTime now) {
    _startedAt = now;
    _nextSlot = now;
    _accepted = 0;
    _limitReached = false;
  }

  /// Returns true if the frame arriving at [now] should be stored.
  bool accept(DateTime now) {
    final startedAt = _startedAt;
    if (startedAt == null || _limitReached) return false;
    if (now.difference(startedAt) >= maxDuration || _accepted >= maxFrames) {
      _limitReached = true;
      return false;
    }
    var slot = _nextSlot!;
    if (now.isBefore(slot)) return false;
    // Skip slots that passed without a frame, so a gap is not filled later.
    while (!slot.isAfter(now)) {
      slot = slot.add(frameInterval);
    }
    _nextSlot = slot;
    _accepted++;
    if (_accepted >= maxFrames) _limitReached = true;
    return true;
  }
}
