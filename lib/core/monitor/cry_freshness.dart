/// Parent: is the room's cry state recent enough to trust (V2.1 §1)?
///
/// The baby refreshes `cryUpdated` (a server timestamp) at least every 5 s.
/// The old check compared it with the parent's own clock: a parent phone
/// whose clock runs more than 20 s ahead of the server (common on phones
/// with a manually set or drifting clock) treated every update as stale and
/// never showed the cry alarm.
///
/// Now only the first snapshot after joining is judged by the server time
/// (it may hold an old state from before the parent joined). After that a
/// state counts as fresh while its `cryUpdated` changed within [maxAge] of
/// the parent's own (monotonic) time, whatever the clock difference.
class CryFreshness {
  CryFreshness({this.maxAge = const Duration(seconds: 20)});

  final Duration maxAge;
  DateTime? _stamp;
  DateTime? _seenAt;
  bool _first = true;

  /// Parent clock minus server time at the last change (positive: the parent
  /// clock is ahead). Includes the network delay. For diagnostics.
  Duration? skew;

  /// Returns whether a state with server time [stamp] is fresh at [now].
  bool isFresh(DateTime? stamp, DateTime now) {
    if (stamp == null) return true; // server timestamp not resolved yet
    if (stamp != _stamp) {
      _stamp = stamp;
      skew = now.difference(stamp);
      if (_first) {
        _first = false;
        // A state written long before we joined is not a live cry.
        _seenAt = now.difference(stamp).abs() < maxAge ? now : null;
      } else {
        _seenAt = now;
      }
    }
    final seen = _seenAt;
    return seen != null && now.difference(seen) < maxAge;
  }

  void reset() {
    _stamp = null;
    _seenAt = null;
    _first = true;
    skew = null;
  }
}
