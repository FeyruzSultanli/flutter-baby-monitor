// Helpers for the two-device end-to-end tests (baby_test.dart, parent_test.dart).
//
// The tests run against the local Firebase Emulator Suite (debug build with
// --dart-define=USE_FIREBASE_EMULATOR=true). They talk to the Firestore
// emulator's REST API with the emulator's admin token ("Bearer owner"), which
// bypasses the security rules: this is how the two devices find each other's
// room and check server-side state. That token only exists in the emulator.
//
// The host runner (scripts/run_e2e.py) watches logcat for these markers:
//   E2E_SCREENSHOT:<name>  -> adb exec-out screencap
//   E2E_HOST:<action>      -> runs a host action on this device (airplane mode)
//   E2E_RESULT:<key>=<val> -> collected into test-results/<run>/summary.md

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bebek_monitor_clean/core/firebase/emulator_config.dart';
import 'package:bebek_monitor_clean/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const String projectId = 'bebekmonitor-282fd';

/// Set by the runner where it cannot toggle airplane mode (iOS simulator).
const bool skipNetworkDrop = bool.fromEnvironment('E2E_SKIP_NETWORK_DROP');

/// Turkish UI text (the app starts in Turkish).
String tr(String key) => AppLocalizations.debugLocalizedValues['tr']![key]!;
String en(String key) => AppLocalizations.debugLocalizedValues['en']![key]!;

void screenshot(String name) {
  // ignore: avoid_print
  print('E2E_SCREENSHOT:$name');
}

void result(String key, Object value) {
  // ignore: avoid_print
  print('E2E_RESULT:$key=$value');
}

void log(String message) {
  // ignore: avoid_print
  print('E2E_LOG:$message');
}

/// Asks the host runner to do something to this device and gives it time.
Future<void> hostAction(String action,
    {Duration wait = const Duration(seconds: 4)}) async {
  // ignore: avoid_print
  print('E2E_HOST:$action');
  await Future<void>.delayed(wait);
}

/// Pumps frames (real time) until [condition] holds or [timeout] passes.
/// pumpAndSettle cannot be used: the app has endless animations.
Future<bool> pumpUntil(
  WidgetTester tester,
  FutureOr<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 30),
  Duration step = const Duration(milliseconds: 250),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump();
    if (await condition()) return true;
    await Future<void>.delayed(step);
  }
  await tester.pump();
  return await condition();
}

/// Pumps for [duration] of real time.
Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

/// Minimal Firestore emulator REST client with admin access.
class EmulatorDb {
  EmulatorDb()
      : _base =
            'http://$firebaseEmulatorHost:$firestoreEmulatorPort/v1/projects/$projectId/databases/(default)/documents';

  final String _base;
  final HttpClient _http = HttpClient();

  Future<dynamic> _request(String method, String path,
      [Map<String, dynamic>? body]) async {
    final request = await _http.openUrl(method, Uri.parse('$_base/$path'));
    request.headers.set('Authorization', 'Bearer owner');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode == 404) return null;
    if (response.statusCode >= 300) {
      throw HttpException('$method $path -> ${response.statusCode}: $text');
    }
    return text.isEmpty ? null : jsonDecode(text);
  }

  /// All rooms (admin), decoded to plain maps with an added 'id'.
  Future<List<Map<String, dynamic>>> rooms() => list('rooms');

  Future<List<Map<String, dynamic>>> list(String collectionPath) async {
    final json = await _request('GET', '$collectionPath?pageSize=300');
    final docs = (json?['documents'] as List?) ?? const [];
    return [for (final d in docs) _decodeDoc(d as Map<String, dynamic>)];
  }

  Future<Map<String, dynamic>?> get(String docPath) async {
    final json = await _request('GET', docPath);
    return json == null ? null : _decodeDoc(json as Map<String, dynamic>);
  }

  /// Creates/overwrites a document (admin, rules bypassed).
  Future<void> put(String docPath, Map<String, dynamic> data) async {
    await _request('PATCH', docPath, {
      'fields': {for (final e in data.entries) e.key: _encode(e.value)}
    });
  }

  static Map<String, dynamic> _decodeDoc(Map<String, dynamic> doc) {
    final fields = (doc['fields'] as Map<String, dynamic>?) ?? const {};
    final name = doc['name'] as String;
    return {
      'id': name.split('/').last,
      '_createTime': doc['createTime'],
      for (final e in fields.entries)
        e.key: _decode(e.value as Map<String, dynamic>),
    };
  }

  static dynamic _decode(Map<String, dynamic> v) {
    if (v.containsKey('nullValue')) return null;
    if (v.containsKey('stringValue')) return v['stringValue'];
    if (v.containsKey('booleanValue')) return v['booleanValue'];
    if (v.containsKey('integerValue'))
      return int.parse(v['integerValue'] as String);
    if (v.containsKey('doubleValue'))
      return (v['doubleValue'] as num).toDouble();
    if (v.containsKey('timestampValue'))
      return DateTime.parse(v['timestampValue'] as String);
    if (v.containsKey('mapValue')) {
      final fields =
          (v['mapValue']['fields'] as Map<String, dynamic>?) ?? const {};
      return {
        for (final e in fields.entries)
          e.key: _decode(e.value as Map<String, dynamic>)
      };
    }
    if (v.containsKey('arrayValue')) {
      final values = (v['arrayValue']['values'] as List?) ?? const [];
      return [for (final x in values) _decode(x as Map<String, dynamic>)];
    }
    return v;
  }

  static Map<String, dynamic> _encode(dynamic v) {
    if (v == null) return {'nullValue': null};
    if (v is bool) return {'booleanValue': v};
    if (v is int) return {'integerValue': '$v'};
    if (v is double) return {'doubleValue': v};
    if (v is String) return {'stringValue': v};
    if (v is DateTime) return {'timestampValue': v.toUtc().toIso8601String()};
    if (v is Map) {
      return {
        'mapValue': {
          'fields': {
            for (final e in v.entries) e.key as String: _encode(e.value)
          }
        }
      };
    }
    throw ArgumentError('Unsupported value $v');
  }
}

/// Waits until [read] returns a non-null value.
Future<T?> waitFor<T>(
  FutureOr<T?> Function() read, {
  required WidgetTester tester,
  Duration timeout = const Duration(seconds: 60),
  Duration step = const Duration(milliseconds: 500),
}) async {
  T? value;
  await pumpUntil(tester, () async {
    value = await read();
    return value != null;
  }, timeout: timeout, step: step);
  return value;
}
