/// Delays between automatic rejoin attempts of the parent (B08 / B36):
/// 2 s, 4 s, 8 s, 16 s, then every 30 s.
class ReconnectBackoff {
  ReconnectBackoff({
    this.initial = const Duration(seconds: 2),
    this.max = const Duration(seconds: 30),
  });

  final Duration initial;
  final Duration max;
  int _attempt = 0;

  int get attempts => _attempt;

  /// Delay before the next attempt; each call doubles it up to [max].
  Duration next() {
    final factor = 1 << (_attempt < 16 ? _attempt : 16);
    _attempt++;
    final ms = initial.inMilliseconds * factor;
    return ms >= max.inMilliseconds ? max : Duration(milliseconds: ms);
  }

  void reset() => _attempt = 0;
}
