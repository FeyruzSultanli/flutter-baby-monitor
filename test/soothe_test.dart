import 'package:bebek_monitor_clean/core/audio/soothe.dart';
import 'package:bebek_monitor_clean/core/pairing/recent_room_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final t0 = DateTime(2026, 11, 22, 22);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  group('SootheThreshold (A29)', () {
    test('inactive: the user threshold', () {
      expect(SootheThreshold().effective(65), 65);
    });

    test('while measuring: cautious +12 dB, then baseline + 8 dB', () {
      final s = SootheThreshold()..start(t0);
      expect(s.effective(65), 77);
      for (var i = 0; i < 16; i++) {
        s.add(i.isEven ? 60 : 62, at(i * 250));
      }
      s.add(61, at(4100));
      expect(s.baseline, 62);
      expect(s.effective(65), 70);
    });

    test('a quiet sound keeps the user threshold, a loud one is capped', () {
      final quiet = SootheThreshold()..start(t0);
      quiet.add(40, at(100));
      quiet.add(40, at(4100));
      expect(quiet.effective(65), 65);

      final loud = SootheThreshold()..start(t0);
      loud.add(85, at(100));
      loud.add(85, at(4100));
      expect(loud.effective(65), 77);
    });

    test('levels during an alarm are not measured; stop() resets', () {
      final s = SootheThreshold()..start(t0);
      s.add(90, at(100), alarming: true);
      s.add(50, at(200));
      s.add(50, at(4100));
      expect(s.baseline, 50);
      s.stop();
      expect(s.effective(65), 65);
    });
  });

  group('TalkGate (5.3)', () {
    test('pauses detection while the parent talks and 3 s after', () {
      final g = TalkGate();
      expect(g.suppressed(t0), isFalse);
      g.onRemoteLevel(0.001, t0);
      expect(g.suppressed(t0), isFalse);
      g.onRemoteLevel(0.2, t0);
      expect(g.suppressed(at(2900)), isTrue);
      expect(g.suppressed(at(3000)), isFalse);
    });
  });

  group('SootheState / NightLightState', () {
    test('round trip through the room map', () {
      final s = SootheState(track: SootheTrack.rain, volume: 0.55, endsAt: DateTime(2026, 11, 22, 23));
      expect(SootheState.fromMap(s.toMap()), s);
      expect(SootheState.fromMap(null), SootheState.off);
      expect(SootheState.fromMap({'track': 'nope'}).track, isNull);
      expect(s.isPlayingAt(DateTime(2026, 11, 22, 22, 59)), isTrue);
      expect(s.isPlayingAt(DateTime(2026, 11, 22, 23, 1)), isFalse);
      const light = NightLightState(on: true, color: NightLightColor.pink);
      expect(NightLightState.fromMap(light.toMap()), light);
      expect(NightLightState.fromMap({'on': true, 'color': 'x'}).color, NightLightColor.amber);
    });
  });

  group('RecentRoomStore (5.2)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('keeps the 3 newest, no duplicates, skips invalid codes', () async {
      final store = RecentRoomStore();
      for (final code in ['AAAA2222', 'BBBB3333', 'CCCC4444', 'AAAA2222', 'DDDD5555']) {
        await store.remember(RecentRoom(code: code, joinedAt: DateTime(2026), name: 'Oda $code'));
      }
      final rooms = await store.load();
      expect(rooms.map((r) => r.code), ['DDDD5555', 'AAAA2222', 'CCCC4444']);
      expect(RecentRoom.fromJson({'code': 'bad', 'at': 1}), isNull);
      await store.forget('AAAA2222');
      expect((await store.load()).length, 2);
    });
  });
}
