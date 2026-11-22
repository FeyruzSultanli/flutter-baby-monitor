import 'dart:typed_data';

import 'package:bebek_monitor_clean/core/audio/offline_audio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
  const channel = MethodChannel(OfflineAudio.methodChannelName);

  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'startPlayer' ? true : null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('start, write and stop reach the native player in order', () async {
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
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    expect(await OfflineAudio().startPlayer(), isFalse);
  });
}
