import 'dart:math';

/// Room codes (D3): 8 characters from an alphabet without look-alikes
/// (no 0/O, 1/I), shown as `ABCD-EFGH`. 32^8 ≈ 1.1e12 possible codes.
class RoomCode {
  RoomCode._();

  static const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int length = 8;

  /// Same rule as `firestore.rules` (`isValidCode`).
  static final RegExp _valid = RegExp(r'^[A-HJ-NP-Z2-9]{8}$');

  static String generate([Random? random]) {
    final rnd = random ?? Random.secure();
    return List.generate(length, (_) => alphabet[rnd.nextInt(alphabet.length)]).join();
  }

  /// `ABCDEFGH` -> `ABCD-EFGH` (other lengths are returned unchanged).
  static String format(String code) =>
      code.length == length ? '${code.substring(0, 4)}-${code.substring(4)}' : code;

  /// Turns user input into a code: upper case, spaces and dashes removed.
  static String normalize(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');

  static bool isValid(String code) => _valid.hasMatch(code);

  /// Join link in the QR code (V2 5.1).
  static String joinUri(String code) => 'ninni://join?code=${format(code)}';

  /// Code typed or pasted on the parent phone: accepts `abcd-ef23`, spaces
  /// and a pasted join link; keeps at most 8 valid characters. [rejected] is
  /// true when characters outside the alphabet (look-alikes 0, O, 1, I, or
  /// symbols) were dropped, so the input can shake.
  static ({String code, bool rejected}) sanitizeInput(String input) {
    var text = input;
    final link = RegExp(r'code=([A-Za-z0-9\- ]+)').firstMatch(text);
    if (link != null) text = link.group(1)!;
    final upper = text.toUpperCase();
    final buffer = StringBuffer();
    var rejected = false;
    for (final rune in upper.runes) {
      final ch = String.fromCharCode(rune);
      if (ch == '-' || ch == ' ' || ch == '\n' || ch == '\t') continue;
      if (alphabet.contains(ch)) {
        if (buffer.length < length) buffer.write(ch);
      } else {
        rejected = true;
      }
    }
    return (code: buffer.toString(), rejected: rejected);
  }
}
