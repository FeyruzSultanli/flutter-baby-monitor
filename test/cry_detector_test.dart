import 'package:bebek_monitor_clean/core/audio/cry_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 3);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  /// Feeds [db] every [stepMs] from [fromMs] to [toMs] (exclusive) and returns
  /// the last result.
  bool feed(CryDetector d, double db, int fromMs, int toMs, {int stepMs = 250}) {
    var result = d.alarm;
    for (var ms = fromMs; ms < toMs; ms += stepMs) {
      result = d.update(db, at(ms));
    }
    return result;
  }

  test('a short loud burst (door slam) does not alarm', () {
    final d = CryDetector(threshold: 60);
    expect(feed(d, 80, 0, 500), isFalse);
    expect(feed(d, 40, 500, 3000), isFalse);
  });

  test('alarms after 2 s of continuous loud noise', () {
    final d = CryDetector(threshold: 60);
    expect(feed(d, 70, 0, 1900), isFalse);
    expect(d.update(70, at(2000)), isTrue);
  });

  test('the threshold value itself counts as loud', () {
    final d = CryDetector(threshold: 60);
    expect(feed(d, 60, 0, 2250), isTrue);
  });

  test('short breathing pauses do not restart the timer', () {
    final d = CryDetector(threshold: 60);
    feed(d, 75, 0, 1000);
    feed(d, 50, 1000, 1500); // 0.5 s dip < 0.6 s tolerance
    expect(feed(d, 75, 1500, 2250), isTrue);
  });

  test('a long pause restarts the timer', () {
    final d = CryDetector(threshold: 60);
    feed(d, 75, 0, 1500);
    feed(d, 50, 1500, 2750); // 1.25 s below
    expect(feed(d, 75, 2750, 4500), isFalse); // only 1.75 s since restart
    expect(d.update(75, at(4750)), isTrue);
  });

  test('alarm ends after the level stays low longer than the tolerance', () {
    final d = CryDetector(threshold: 60);
    expect(feed(d, 80, 0, 2250), isTrue);
    expect(d.update(40, at(2500)), isTrue); // within tolerance
    expect(d.update(40, at(3000)), isFalse);
  });

  test('changing the threshold takes effect on the next reading', () {
    final d = CryDetector(threshold: 80);
    expect(feed(d, 70, 0, 2500), isFalse);
    d.threshold = 65;
    expect(feed(d, 70, 2500, 4750), isTrue);
  });

  test('reset clears an active alarm', () {
    final d = CryDetector(threshold: 60);
    feed(d, 80, 0, 2500);
    expect(d.alarm, isTrue);
    d.reset();
    expect(d.alarm, isFalse);
    expect(d.update(80, at(2750)), isFalse);
  });
}
