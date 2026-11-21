import 'dart:convert';
import 'dart:typed_data';

import 'package:bebek_monitor_clean/core/offline/offline_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OfflinePayloadType', () {
    test('wire codes are stable', () {
      expect(OfflinePayloadType.image.code, 1);
      expect(OfflinePayloadType.control.code, 2);
      expect(OfflinePayloadType.audio.code, 3);
      expect(OfflinePayloadType.battery.code, 4);
    });

    test('fromCode maps known codes and rejects unknown ones', () {
      for (final type in OfflinePayloadType.values) {
        expect(OfflinePayloadType.fromCode(type.code), type);
      }
      expect(OfflinePayloadType.fromCode(0), isNull);
      expect(OfflinePayloadType.fromCode(5), isNull);
      expect(OfflinePayloadType.fromCode(255), isNull);
    });
  });

  group('OfflinePayload.encode/decode', () {
    test('prefixes body with the type byte', () {
      final bytes = OfflinePayload.encode(OfflinePayloadType.audio, [10, 20, 30]);
      expect(bytes, [3, 10, 20, 30]);
    });

    test('round-trips binary bodies for every type', () {
      final body = Uint8List.fromList(List<int>.generate(1000, (i) => i % 256));
      for (final type in OfflinePayloadType.values) {
        final decoded = OfflinePayload.decode(OfflinePayload.encode(type, body))!;
        expect(decoded.type, type);
        expect(decoded.body, body);
      }
    });

    test('empty body is allowed', () {
      final decoded =
          OfflinePayload.decode(OfflinePayload.encode(OfflinePayloadType.image, const []))!;
      expect(decoded.type, OfflinePayloadType.image);
      expect(decoded.body, isEmpty);
    });

    test('decode returns null for empty input and unknown type byte', () {
      expect(OfflinePayload.decode(Uint8List(0)), isNull);
      expect(OfflinePayload.decode(Uint8List.fromList([9, 1, 2])), isNull);
    });

    test('decoded body is a copy, not a view of the input', () {
      final input = OfflinePayload.encode(OfflinePayloadType.image, [1, 2, 3]);
      final decoded = OfflinePayload.decode(input)!;
      input[1] = 99;
      expect(decoded.body, [1, 2, 3]);
    });
  });

  group('OfflinePayload JSON messages', () {
    test('STATUS message round-trips', () {
      final bytes = OfflinePayload.encodeJson(
        OfflinePayloadType.control,
        {'type': 'STATUS', 'db': 61.5, 'alert': true},
      );
      expect(bytes.first, 2);
      final map = OfflinePayload.decode(bytes)!.decodeJson();
      expect(map, {'type': 'STATUS', 'db': 61.5, 'alert': true});
    });

    test('BATTERY message round-trips', () {
      final bytes = OfflinePayload.encodeJson(
        OfflinePayloadType.battery,
        {'type': 'BATTERY', 'level': 42, 'state': 'BatteryState.charging'},
      );
      final decoded = OfflinePayload.decode(bytes)!;
      expect(decoded.type, OfflinePayloadType.battery);
      expect(decoded.decodeJson()['level'], 42);
    });

    test('non-ASCII text survives (UTF-8)', () {
      final bytes = OfflinePayload.encodeJson(
        OfflinePayloadType.control,
        {'type': 'SETTINGS', 'note': 'Bebek ağlıyor ğüşıöç'},
      );
      expect(OfflinePayload.decode(bytes)!.decodeJson()['note'], 'Bebek ağlıyor ğüşıöç');
    });

    test('decodeJson throws on a non-object body', () {
      final notJson = OfflinePayload.decode(
          OfflinePayload.encode(OfflinePayloadType.control, utf8.encode('not json')))!;
      expect(notJson.decodeJson, throwsFormatException);

      final list = OfflinePayload.decode(
          OfflinePayload.encode(OfflinePayloadType.control, utf8.encode('[1,2]')))!;
      expect(list.decodeJson, throwsA(isA<TypeError>()));
    });
  });
}
