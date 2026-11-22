import 'package:bebek_monitor_clean/core/alerts/night_summary.dart';
import 'package:bebek_monitor_clean/models/alert_model.dart';
import 'package:flutter_test/flutter_test.dart';

AlertModel _a(DateTime t, int seconds, {double db = 70}) =>
    AlertModel(timestamp: t, message: 'x', decibel: db, durationSeconds: seconds);

void main() {
  group('windowFor', () {
    test('tonight after 18:00 starts today, before 18:00 last night', () {
      final evening = DateTime(2026, 11, 22, 23, 30);
      expect(windowFor(HistoryRange.tonight, evening).start, DateTime(2026, 11, 22, 18));
      expect(windowFor(HistoryRange.tonight, evening).end, evening);
      final morning = DateTime(2026, 11, 23, 7);
      expect(windowFor(HistoryRange.tonight, morning).start, DateTime(2026, 11, 22, 18));
      final afternoon = DateTime(2026, 11, 23, 15);
      expect(windowFor(HistoryRange.tonight, afternoon).end, DateTime(2026, 11, 23, 12));
    });

    test('yesterday is the night before; week is 7 days', () {
      final now = DateTime(2026, 11, 23, 7);
      final y = windowFor(HistoryRange.yesterday, now);
      expect(y.start, DateTime(2026, 11, 21, 18));
      expect(y.end, DateTime(2026, 11, 22, 12));
      expect(windowFor(HistoryRange.week, now).start, DateTime(2026, 11, 16, 7));
    });
  });

  group('NightSummary', () {
    final start = DateTime(2026, 11, 22, 18);
    final window = TimeWindow(start, DateTime(2026, 11, 23, 6));

    test('counts alarms, crying time and the longest quiet period', () {
      final alerts = [
        _a(DateTime(2026, 11, 22, 23, 48), 2),
        _a(DateTime(2026, 11, 23, 1, 12), 200),
        _a(DateTime(2026, 11, 23, 2, 14), 6),
        _a(DateTime(2026, 11, 21, 23), 60), // other night
      ];
      final s = NightSummary.of(alerts, window);
      expect(s.alarms, 3);
      expect(s.totalCry, const Duration(seconds: 208));
      // 18:00 -> 23:48 is the longest gap.
      expect(s.longestQuiet, const Duration(hours: 5, minutes: 48));
      expect(s.events.first.timestamp, DateTime(2026, 11, 23, 2, 14));
    });

    test('a quiet night is one long quiet period', () {
      final s = NightSummary.of(const [], window);
      expect(s.alarms, 0);
      expect(s.totalCry, Duration.zero);
      expect(s.longestQuiet, const Duration(hours: 12));
    });

    test('entries without duration count as zero crying time', () {
      final s = NightSummary.of([AlertModel(timestamp: DateTime(2026, 11, 22, 20), message: 'x')], window);
      expect(s.totalCry, Duration.zero);
      expect(s.alarms, 1);
    });
  });

  test('AlertModel keeps the duration in JSON', () {
    final a = _a(DateTime(2026, 11, 22, 20), 42);
    final b = AlertModel.fromJson(a.toJson());
    expect(b.duration, const Duration(seconds: 42));
    expect(AlertModel.fromJson({'timestamp': '2026-11-22T20:00:00.000', 'message': 'x'}).duration, isNull);
  });
}
