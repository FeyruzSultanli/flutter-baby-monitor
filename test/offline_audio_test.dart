import 'dart:async';
import 'dart:typed_data';

import 'package:bebek_monitor_clean/core/audio/audio_level.dart';
import 'package:bebek_monitor_clean/core/audio/offline_audio.dart';
import 'package:bebek_monitor_clean/core/offline/offline_payload.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Little-endian PCM16 bytes, as Android's AudioRecord delivers them.
Uint8List pcm16(List<int> samples) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = StandardMethodCodec();

  tearDown(() {
    messenger.setMockMethodCallHandler(
        const MethodChannel(OfflineAudio.methodChannelName), null);
    messenger.setMockMessageHandler(OfflineAudio.micChannelName, null);
  });

  group('player', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      messenger.setMockMethodCallHandler(
          const MethodChannel(OfflineAudio.methodChannelName), (call) async {
        calls.add(call);
        return call.method == 'startPlayer' ? true : null;
      });
    });

    test('start, write and stop reach the native side in order', () async {
      final audio = OfflineAudio();
      final chunk = pcm16([1, -1, 300]);

      expect(await audio.startPlayer(), isTrue);
      await audio.writeChunk(chunk);
      await audio.stopPlayer();

      expect(calls.map((c) => c.method),
          ['startPlayer', 'writeChunk', 'stopPlayer']);
      expect((calls[1].arguments as Map)['data'], chunk);
    });

    test('startPlayer reports false when the native side returns null',
        () async {
      messenger.setMockMethodCallHandler(
          const MethodChannel(OfflineAudio.methodChannelName),
          (call) async => null);
      expect(await OfflineAudio().startPlayer(), isFalse);
    });
  });

  group('microphone stream', () {
    late List<String> nativeCalls;

    setUp(() {
      nativeCalls = [];
      messenger.setMockMessageHandler(OfflineAudio.micChannelName,
          (ByteData? message) async {
        final call = codec.decodeMethodCall(message);
        nativeCalls.add(call.method);
        return codec.encodeSuccessEnvelope(null);
      });
    });

    Future<void> sendFromNative(ByteData? envelope) =>
        messenger.handlePlatformMessage(
            OfflineAudio.micChannelName, envelope, (_) {});

    test('listening starts and cancelling stops the recorder', () async {
      final sub = OfflineAudio().micStream().listen((_) {});
      await pumpEventQueue();
      expect(nativeCalls, ['listen']);

      await sub.cancel();
      await pumpEventQueue();
      expect(nativeCalls, ['listen', 'cancel']);
    });

    test('PCM chunks arrive unchanged and work with the dB and payload code',
        () async {
      final received = <Uint8List>[];
      final sub = OfflineAudio().micStream().listen(received.add);
      await pumpEventQueue();

      final chunk = pcm16(List.filled(256, 1000));
      await sendFromNative(codec.encodeSuccessEnvelope(chunk));
      await pumpEventQueue();

      expect(received, hasLength(1));
      expect(received.single, chunk);
      // Same level as the existing pcm16ChunkToDb test for amplitude 1000.
      expect(pcm16ChunkToDb(received.single), closeTo(69.69, 0.01));
      // And it survives the Nearby payload framing.
      final decoded = OfflinePayload.decode(
          OfflinePayload.encode(OfflinePayloadType.audio, received.single));
      expect(decoded!.type, OfflinePayloadType.audio);
      expect(decoded.body, chunk);

      await sub.cancel();
    });

    test('a native error (e.g. no permission) reaches onError', () async {
      final errors = <Object>[];
      final done = Completer<void>();
      final sub = OfflineAudio().micStream().listen((_) {},
          onError: (Object e) {
        errors.add(e);
        if (!done.isCompleted) done.complete();
      });
      await pumpEventQueue();

      await sendFromNative(codec.encodeErrorEnvelope(
          code: 'PERMISSION_DENIED', message: 'RECORD_AUDIO not granted'));
      await done.future.timeout(const Duration(seconds: 2));

      expect(errors.single, isA<PlatformException>());
      expect((errors.single as PlatformException).code, 'PERMISSION_DENIED');
      await sub.cancel();
    });
  });
}
