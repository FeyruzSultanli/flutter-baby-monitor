import 'package:bebek_monitor_clean/core/recording/offline_frame_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 12);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  test('defaults: 20 s at 10 fps = 200 frames', () {
    final gate = OfflineFrameGate();
    expect(gate.maxFrames, 200);
  });

  test('rejects everything before start()', () {
    expect(OfflineFrameGate().accept(t0), isFalse);
  });

  test('samples frames to one per interval', () {
    final gate = OfflineFrameGate()..start(t0);
    // 30 fps input for 1 s -> about 10 stored frames
    var stored = 0;
    for (var ms = 0; ms < 1000; ms += 33) {
      if (gate.accept(at(ms))) stored++;
    }
    expect(stored, inInclusiveRange(9, 10));
  });

  test('stops at the duration limit and reports it', () {
    final gate = OfflineFrameGate(maxDuration: const Duration(seconds: 2))..start(t0);
    expect(gate.accept(at(0)), isTrue);
    expect(gate.limitReached, isFalse);
    expect(gate.accept(at(2000)), isFalse);
    expect(gate.limitReached, isTrue);
    expect(gate.accept(at(2100)), isFalse);
  });

  test('stops at the frame limit', () {
    final gate = OfflineFrameGate(maxDuration: const Duration(seconds: 1))..start(t0);
    var stored = 0;
    for (var ms = 0; ms < 990; ms += 100) {
      if (gate.accept(at(ms))) stored++;
    }
    expect(stored, gate.maxFrames);
    expect(gate.limitReached, isTrue);
  });

  test('slow input still ends at maxDuration', () {
    final gate = OfflineFrameGate(maxDuration: const Duration(seconds: 3))..start(t0);
    expect(gate.accept(at(0)), isTrue);
    expect(gate.accept(at(1500)), isTrue);
    expect(gate.accept(at(3001)), isFalse);
    expect(gate.limitReached, isTrue);
    expect(gate.acceptedFrames, 2);
  });

  test('start() resets a previous recording', () {
    final gate = OfflineFrameGate(maxDuration: const Duration(seconds: 1))..start(t0);
    gate.accept(at(1500));
    expect(gate.limitReached, isTrue);
    gate.start(at(5000));
    expect(gate.limitReached, isFalse);
    expect(gate.accept(at(5000)), isTrue);
  });
}
