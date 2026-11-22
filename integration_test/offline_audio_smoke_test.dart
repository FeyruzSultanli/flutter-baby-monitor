// Single-device smoke test of the native offline audio channel
// (android/app/src/main/kotlin/.../OfflineAudio.kt) on an Android emulator or
// phone. Nearby itself cannot run on the emulator; this checks that the
// microphone delivers PCM16 chunks the dB code can use and that the player
// accepts chunks.
//
//   adb shell pm grant com.example.bebek_monitor_clean android.permission.RECORD_AUDIO
//   flutter test integration_test/offline_audio_smoke_test.dart -d <device>

import 'package:bebek_monitor_clean/core/audio/audio_level.dart';
import 'package:bebek_monitor_clean/core/audio/offline_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline audio: microphone chunks and player', (tester) async {
    expect(defaultTargetPlatform, TargetPlatform.android,
        reason: 'offline audio is Android-only');
    expect(await Permission.microphone.isGranted, isTrue,
        reason: 'grant RECORD_AUDIO with adb before running');

    final audio = OfflineAudio();

    // --- Microphone: ~2 s of audio ------------------------------------------
    final chunks = <Uint8List>[];
    final errors = <Object>[];
    final sub = audio.micStream().listen(chunks.add, onError: errors.add);
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await sub.cancel();

    expect(errors, isEmpty);
    expect(chunks, isNotEmpty, reason: 'microphone delivered audio');
    final bytes = chunks.fold<int>(0, (n, c) => n + c.length);
    // 16 kHz * 2 bytes * ~2 s; allow a wide margin for emulator start-up.
    expect(bytes, greaterThan(16000), reason: 'about 32 kB/s of PCM16');
    expect(chunks.every((c) => c.length.isEven), isTrue,
        reason: 'whole 16-bit samples');
    final db = pcm16ChunkToDb(chunks.last);
    expect(db.isFinite, isTrue);
    expect(db, inInclusiveRange(0, 100));
    // ignore: avoid_print
    print('OFFLINE_AUDIO chunks=${chunks.length} bytes=$bytes '
        'chunkSize=${chunks.first.length} lastDb=${db.toStringAsFixed(1)}');

    // After cancel no more chunks arrive (recording stopped).
    final countAfterCancel = chunks.length;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    expect(chunks.length, countAfterCancel);

    // --- Restart works (mode switches start/stop the microphone often) ------
    final again = <Uint8List>[];
    final sub2 = audio.micStream().listen(again.add);
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await sub2.cancel();
    expect(again, isNotEmpty, reason: 'microphone restarts');

    // --- Player: play back what was recorded --------------------------------
    expect(await audio.startPlayer(), isTrue);
    for (final c in chunks) {
      await audio.writeChunk(c);
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await audio.stopPlayer();
    // Writing after stop is ignored, and the player can start again.
    await audio.writeChunk(chunks.first);
    expect(await audio.startPlayer(), isTrue);
    await audio.stopPlayer();
  });
}
