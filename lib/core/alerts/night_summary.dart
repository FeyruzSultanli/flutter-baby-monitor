import '../../models/alert_model.dart';

/// Filter of the alert history screen.
enum HistoryRange { tonight, yesterday, week }

class TimeWindow {
  const TimeWindow(this.start, this.end);
  final DateTime start;
  final DateTime end;

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);
}

/// Nights run from 18:00 to 12:00 the next day. "Tonight" is the latest night
/// that has started (before 18:00 that is last night), up to now.
TimeWindow windowFor(HistoryRange range, DateTime now) {
  final today18 = DateTime(now.year, now.month, now.day, 18);
  final tonightStart = now.isBefore(today18) ? today18.subtract(const Duration(days: 1)) : today18;
  DateTime cap(DateTime end) => end.isAfter(now) ? now : end;
  switch (range) {
    case HistoryRange.tonight:
      return TimeWindow(tonightStart, cap(tonightStart.add(const Duration(hours: 18))));
    case HistoryRange.yesterday:
      final start = tonightStart.subtract(const Duration(days: 1));
      return TimeWindow(start, start.add(const Duration(hours: 18)));
    case HistoryRange.week:
      return TimeWindow(now.subtract(const Duration(days: 7)), now);
  }
}

/// Nightly summary (V2 5.9): number of alarms, total crying time and the
/// longest quiet period, computed locally from the alert history.
class NightSummary {
  const NightSummary({
    required this.alarms,
    required this.totalCry,
    required this.longestQuiet,
    required this.events,
  });

  final int alarms;
  final Duration totalCry;
  final Duration longestQuiet;
  /// Alerts in the window, newest first.
  final List<AlertModel> events;

  static NightSummary of(List<AlertModel> alerts, TimeWindow window) {
    final inWindow = alerts.where((a) => window.contains(a.timestamp)).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    var total = Duration.zero;
    var longest = Duration.zero;
    var quietFrom = window.start;
    for (final a in inWindow) {
      final gap = a.timestamp.difference(quietFrom);
      if (gap > longest) longest = gap;
      final d = a.duration ?? Duration.zero;
      total += d;
      final end = a.timestamp.add(d);
      if (end.isAfter(quietFrom)) quietFrom = end;
    }
    final tail = window.end.difference(quietFrom);
    if (tail > longest) longest = tail;
    if (longest.isNegative) longest = Duration.zero;
    return NightSummary(
      alarms: inWindow.length,
      totalCry: total,
      longestQuiet: longest,
      events: inWindow.reversed.toList(),
    );
  }
}

/// A cry shorter than this is listed as "short noise".
const Duration shortNoiseLimit = Duration(seconds: 5);
