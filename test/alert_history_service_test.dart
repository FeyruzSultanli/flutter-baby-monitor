import 'dart:convert';
import 'dart:io';

import 'package:bebek_monitor_clean/core/alert_history_service.dart';
import 'package:bebek_monitor_clean/models/alert_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('alert_history_test');
    file = File('${dir.path}/alert_history.json');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  AlertHistoryService service() => AlertHistoryService.withDirectory(() async => dir);

  AlertModel alert(int minute) => AlertModel(
        timestamp: DateTime(2026, 1, 1, 0, minute),
        message: 'm$minute',
        decibel: 60,
      );

  test('add then reload from disk, newest first', () async {
    final s = service();
    await s.addAlert(alert(1));
    await s.addAlert(alert(2));

    final reloaded = await service().getAlerts();
    expect(reloaded.map((a) => a.message), ['m2', 'm1']);
  });

  test('one invalid entry does not drop the others', () async {
    await file.writeAsString(jsonEncode([
      alert(1).toJson(),
      {'timestamp': 'not a date', 'message': 'bad'},
      {'message': null},
      alert(3).toJson(),
    ]));
    final alerts = await service().getAlerts();
    expect(alerts.map((a) => a.message), ['m3', 'm1']);
  });

  test('a corrupt file is kept aside, not overwritten', () async {
    await file.writeAsString('{"truncated": ');
    final s = service();
    expect(await s.getAlerts(), isEmpty);
    await s.addAlert(alert(5));

    expect(File('${file.path}.corrupt').readAsStringSync(), '{"truncated": ');
    final reloaded = await service().getAlerts();
    expect(reloaded.single.message, 'm5');
  });

  test('history is capped at maxEntries', () async {
    final s = service();
    for (var i = 0; i < AlertHistoryService.maxEntries + 5; i++) {
      await s.addAlert(AlertModel(
        timestamp: DateTime(2026).add(Duration(seconds: i)),
        message: 'a$i',
      ));
    }
    final reloaded = await service().getAlerts();
    expect(reloaded.length, AlertHistoryService.maxEntries);
    expect(reloaded.first.message, 'a${AlertHistoryService.maxEntries + 4}');
  });

  test('concurrent adds are all persisted', () async {
    final s = service();
    await Future.wait([for (var i = 0; i < 20; i++) s.addAlert(alert(i))]);
    final reloaded = await service().getAlerts();
    expect(reloaded.length, 20);
    expect(File('${file.path}.tmp').existsSync(), isFalse);
  });

  test('clearHistory empties the file', () async {
    final s = service();
    await s.addAlert(alert(1));
    await s.clearHistory();
    expect(await service().getAlerts(), isEmpty);
  });
}
