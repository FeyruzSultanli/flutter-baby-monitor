import 'package:flutter/foundation.dart';

/// Test hooks for integration tests on emulators/simulators.
///
/// Every hook is inert outside **debug** builds: [kDebugMode] is a
/// compile-time constant, so in profile/release builds the getters always
/// return null and the setters do nothing (and the compiler removes them).
class DebugHooks {
  DebugHooks._();

  static double? _fakeNoiseDb;

  /// "Fake cry": when set, the baby device uses this noise level (shared dB
  /// scale, see audio_level.dart) instead of the microphone measurement in
  /// online mode, so cry detection can be tested without real sound.
  static double? get fakeNoiseDb => kDebugMode ? _fakeNoiseDb : null;

  static set fakeNoiseDb(double? value) {
    if (kDebugMode) _fakeNoiseDb = value;
  }
}
