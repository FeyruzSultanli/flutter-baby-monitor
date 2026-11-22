import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Silences platform plugins that MonitorController touches at start-up
/// (battery_plus), so widget tests and the screenshot tool can build it.
void mockMonitorPlugins() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockStreamHandler(
    const EventChannel('dev.fluttercommunity.plus/charging'),
    MockStreamHandler.inline(onListen: (args, sink) {}),
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/battery'),
    (call) async => call.method == 'getBatteryLevel' ? 76 : 'charging',
  );
}
