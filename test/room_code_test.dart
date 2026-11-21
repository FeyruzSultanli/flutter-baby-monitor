import 'dart:math';

import 'package:bebek_monitor_clean/core/pairing/room_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('alphabet has 32 characters without look-alikes', () {
    expect(RoomCode.alphabet.length, 32);
    expect(RoomCode.alphabet.split('').toSet().length, 32);
    for (final c in ['0', 'O', '1', 'I']) {
      expect(RoomCode.alphabet.contains(c), isFalse, reason: c);
    }
  });

  test('generated codes are valid and vary', () {
    final rnd = Random(42);
    final codes = {for (var i = 0; i < 200; i++) RoomCode.generate(rnd)};
    expect(codes.length, 200);
    for (final c in codes) {
      expect(RoomCode.isValid(c), isTrue, reason: c);
    }
  });

  test('every alphabet character is accepted by the validation regex', () {
    for (final c in RoomCode.alphabet.split('')) {
      expect(RoomCode.isValid(c * 8), isTrue, reason: c);
    }
  });

  test('format and normalize are inverse for user input', () {
    expect(RoomCode.format('ABCD2345'), 'ABCD-2345');
    expect(RoomCode.normalize('abcd-2345'), 'ABCD2345');
    expect(RoomCode.normalize(' ab cd 23 45 '), 'ABCD2345');
    expect(RoomCode.normalize(RoomCode.format('XYZW9876')), 'XYZW9876');
  });

  test('rejects wrong length, look-alikes and old 6-digit codes', () {
    expect(RoomCode.isValid('ABCD234'), isFalse);
    expect(RoomCode.isValid('ABCD23456'), isFalse);
    expect(RoomCode.isValid('ABCD0234'), isFalse);
    expect(RoomCode.isValid('ABCDO234'), isFalse);
    expect(RoomCode.isValid('ABCD1234'), isFalse);
    expect(RoomCode.isValid('123456'), isFalse);
    expect(RoomCode.isValid('abcd2345'), isFalse);
  });
}
