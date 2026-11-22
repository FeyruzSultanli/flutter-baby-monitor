/// Last hour of noise on the baby phone (V2.1 §4, BabyLive21): the loudest
/// dB of each minute and the minutes with a cry alarm, kept in memory only.
class NoiseHistory {
  NoiseHistory({this.minutes = 60});

  final int minutes;
  final Map<int, double> _max = {};
  final Set<int> _alarm = {};
  final List<DateTime> _alarmStarts = [];
  bool _wasAlarm = false;

  static int _minute(DateTime t) => t.millisecondsSinceEpoch ~/ 60000;

  /// Records one reading. Returns true when a minute's value changed in a
  /// way the chart should redraw (new minute, new maximum, alarm start).
  bool add(double db, DateTime now, {bool alarm = false}) {
    final m = _minute(now);
    var changed = false;
    final prev = _max[m];
    if (prev == null || db > prev + 0.5) {
      _max[m] = prev == null ? db : (db > prev ? db : prev);
      changed = true;
    }
    if (alarm && _alarm.add(m)) changed = true;
    if (alarm && !_wasAlarm) {
      _alarmStarts.add(now);
      changed = true;
    }
    _wasAlarm = alarm;
    _prune(m);
    return changed;
  }

  void _prune(int currentMinute) {
    final oldest = currentMinute - minutes + 1;
    _max.removeWhere((k, _) => k < oldest);
    _alarm.removeWhere((k) => k < oldest);
    final cutoff = DateTime.fromMillisecondsSinceEpoch(oldest * 60000);
    _alarmStarts.removeWhere((t) => t.isBefore(cutoff));
  }

  /// [minutes] values, oldest first; null for minutes without readings.
  List<({double? db, bool alarm})> lastHour(DateTime now) {
    final m = _minute(now);
    return [
      for (var i = m - minutes + 1; i <= m; i++) (db: _max[i], alarm: _alarm.contains(i)),
    ];
  }

  /// Alarms that started within the last hour.
  int alarmCount(DateTime now) {
    _prune(_minute(now));
    return _alarmStarts.length;
  }

  DateTime? get lastAlarmAt => _alarmStarts.isEmpty ? null : _alarmStarts.last;

  void clear() {
    _max.clear();
    _alarm.clear();
    _alarmStarts.clear();
    _wasAlarm = false;
  }

  /// Demo / screenshots.
  void fill(DateTime now, double Function(int minutesAgo) db, {Set<int> alarmMinutesAgo = const {}}) {
    clear();
    final m = _minute(now);
    for (var i = 0; i < minutes; i++) {
      _max[m - i] = db(i);
      if (alarmMinutesAgo.contains(i)) _alarm.add(m - i);
    }
    for (final a in alarmMinutesAgo.toList()..sort((a, b) => b.compareTo(a))) {
      _alarmStarts.add(DateTime.fromMillisecondsSinceEpoch((m - a) * 60000));
    }
  }
}
