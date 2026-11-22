// Single-device smoke test of the app's own audio paths on a real device,
// an Android emulator or an iOS simulator:
// - PcmMicrophone (`record` package): PCM16 chunks the dB code can use, and
//   restart after stop (offline streaming and the online standby meter);
// - OfflineAudio player (Android only): plays the recorded chunks back.
// Nearby itself still needs two Android phones.
//
// Grant the microphone first:
//   adb shell pm grant com.example.bebek_monitor_clean android.permission.RECORD_AUDIO
//   xcrun simctl privacy <udid> grant microphone com.feyruz.bebekmonitorclean
//   flutter test integration_test/audio_smoke_test.dart -d <device>

import 'package:bebek_monitor_clean/core/audio/audio_level.dart';
import 'package:bebek_monitor_clean/core/audio/offline_audio.dart';
import 'package:bebek_monitor_clean/core/audio/pcm_microphone.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> wait(WidgetTester tester, int ms) =>
      tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));

  testWidgets('microphone PCM chunks (record) and offline player',
      (tester) async {
    expect(await Permission.microphone.isGranted, isTrue,
        reason: 'grant the microphone before running');

    final mic = PcmMicrophone();

    // --- Microphone: ~2 s of audio ------------------------------------------
    final chunks = <Uint8List>[];
    final errors = <Object>[];
    final sub = (await mic.start()).listen(chunks.add, onError: errors.add);
    await wait(tester, 2000);
    await sub.cancel();
    await mic.stop();

    expect(errors, isEmpty);
    expect(chunks, isNotEmpty, reason: 'microphone delivered audio');
    final bytes = chunks.fold<int>(0, (n, c) => n + c.length);
    // 16 kHz * 2 bytes * ~2 s; wide margin for start-up.
    expect(bytes, greaterThan(16000), reason: 'about 32 kB/s of PCM16');
    expect(bytes, lessThan(32000 * 4), reason: 'not 44.1/48 kHz or stereo');
    expect(chunks.every((c) => c.length.isEven), isTrue,
        reason: 'whole 16-bit samples');
    final db = pcm16ChunkToDb(chunks.last);
    expect(db.isFinite, isTrue);
    expect(db, inInclusiveRange(0, 100));
    final dbs = chunks.map(pcm16ChunkToDb).toList()..sort();
    final peakSample = chunks
        .map((c) => ByteData.sublistView(c))
        .expand((d) => List.generate(
            d.lengthInBytes ~/ 2, (i) => d.getInt16(i * 2, Endian.little).abs()))
        .fold<int>(0, (a, b) => a > b ? a : b);
    // ignore: avoid_print
    print('AUDIO_SMOKE platform=$defaultTargetPlatform chunks=${chunks.length} '
        'bytes=$bytes chunkSize=${chunks.first.length} '
        'db min=${dbs.first.toStringAsFixed(1)} '
        'median=${dbs[dbs.length ~/ 2].toStringAsFixed(1)} '
        'max=${dbs.last.toStringAsFixed(1)} peakSample=$peakSample');

    // --- Restart works (standby meter <-> call, mode switches) --------------
    final again = <Uint8List>[];
    final sub2 = (await mic.start()).listen(again.add);
    await wait(tester, 1000);
    await sub2.cancel();
    await mic.stop();
    expect(again, isNotEmpty, reason: 'microphone restarts');
    expect(mic.isRunning, isFalse);

    // --- Offline player (Android only) --------------------------------------
    if (defaultTargetPlatform == TargetPlatform.android) {
      final audio = OfflineAudio();
      expect(await audio.startPlayer(), isTrue);
      for (final c in chunks) {
        await audio.writeChunk(c);
      }
      await wait(tester, 500);
      await audio.stopPlayer();
      await audio.writeChunk(chunks.first); // ignored after stop
      expect(await audio.startPlayer(), isTrue);
      await audio.stopPlayer();
    }
  });
}
