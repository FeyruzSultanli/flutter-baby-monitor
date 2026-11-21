import 'dart:convert';
import 'dart:typed_data';

/// Message types sent over Nearby Connections byte payloads in offline mode.
///
/// Wire format: `[type byte][body...]`.
enum OfflinePayloadType {
  /// JPEG camera frame (baby → parent).
  image(1),

  /// JSON control/status message: `SETTINGS`, `SWITCH_CAMERA`, `STATUS`.
  control(2),

  /// Raw PCM16 audio chunk (baby → parent).
  audio(3),

  /// JSON battery message: `{type: BATTERY, level, state}`.
  battery(4);

  const OfflinePayloadType(this.code);

  final int code;

  static OfflinePayloadType? fromCode(int code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// A decoded offline payload.
class OfflinePayload {
  const OfflinePayload(this.type, this.body);

  final OfflinePayloadType type;
  final Uint8List body;

  /// Frames [body] with the [type] byte.
  static Uint8List encode(OfflinePayloadType type, List<int> body) {
    final payload = Uint8List(body.length + 1);
    payload[0] = type.code;
    payload.setRange(1, payload.length, body);
    return payload;
  }

  /// Frames a JSON map (UTF-8) with the [type] byte.
  static Uint8List encodeJson(OfflinePayloadType type, Map<String, dynamic> json) {
    return encode(type, utf8.encode(jsonEncode(json)));
  }

  /// Splits [bytes] into type + body. Returns null for empty input or an
  /// unknown type byte.
  static OfflinePayload? decode(Uint8List bytes) {
    if (bytes.isEmpty) return null;
    final type = OfflinePayloadType.fromCode(bytes[0]);
    if (type == null) return null;
    return OfflinePayload(type, bytes.sublist(1));
  }

  /// Decodes [body] as a UTF-8 JSON object. Throws [FormatException] (or a
  /// [TypeError]) if the body is not a JSON object.
  Map<String, dynamic> decodeJson() {
    return jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
  }
}
