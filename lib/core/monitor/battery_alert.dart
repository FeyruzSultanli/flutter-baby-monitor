/// Baby phone battery (V2 5.7): one warning per low-battery episode.
///
/// Fires once when the level drops below [threshold] while not charging.
/// Re-armed when the phone is charging or back at [rearmLevel] or more, so
/// a level hovering around the threshold does not warn repeatedly.
class LowBatteryAlert {
  LowBatteryAlert({this.threshold = 15, this.rearmLevel = 20});

  final int threshold;
  final int rearmLevel;
  bool _fired = false;

  bool get hasFired => _fired;

  /// Returns true when the warning should be shown now.
  bool update({required int? level, required bool charging}) {
    if (level == null) return false;
    if (charging || level >= rearmLevel) {
      _fired = false;
      return false;
    }
    if (level < threshold && !_fired) {
      _fired = true;
      return true;
    }
    return false;
  }

  void reset() => _fired = false;
}

/// Baby battery as stored in the room (`battery` field) and shown on the
/// parent.
class BabyBattery {
  const BabyBattery({required this.level, required this.charging, this.updatedAt});

  final int level;
  final bool charging;
  final DateTime? updatedAt;

  static BabyBattery? fromRoom(Object? raw) {
    if (raw is! Map) return null;
    final level = raw['level'];
    if (level is! num) return null;
    final at = raw['at'];
    DateTime? updatedAt;
    try {
      // Firestore Timestamp without importing cloud_firestore here.
      updatedAt = (at as dynamic)?.toDate() as DateTime?;
    } catch (_) {
      updatedAt = null;
    }
    return BabyBattery(
      level: level.round().clamp(0, 100),
      charging: raw['charging'] == true,
      updatedAt: updatedAt,
    );
  }
}
