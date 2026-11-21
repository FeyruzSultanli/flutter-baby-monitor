import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/alert_model.dart';

/// Persists the cry alert history as a JSON file in the app documents folder.
class AlertHistoryService {
  static final AlertHistoryService _instance = AlertHistoryService._internal();
  factory AlertHistoryService() => _instance;
  AlertHistoryService._internal() : _directory = getApplicationDocumentsDirectory;

  /// Creates a separate instance that stores its file in [directory]; for tests.
  @visibleForTesting
  AlertHistoryService.withDirectory(Future<Directory> Function() directory)
      : _directory = directory;

  /// Oldest entries beyond this are dropped so the file cannot grow forever (B29).
  static const int maxEntries = 500;

  static const String _fileName = 'alert_history.json';

  final Future<Directory> Function() _directory;

  List<AlertModel> _alerts = [];
  Future<void>? _loading;
  Future<void> _pendingWrite = Future.value();

  Future<File> get _localFile async {
    final directory = await _directory();
    return File('${directory.path}/$_fileName');
  }

  /// Loads the history once. Concurrent first callers share the same load.
  Future<void> loadAlerts() => _loading ??= _load();

  Future<void> _load() async {
    final file = await _localFile;
    try {
      if (!await file.exists()) return;
      final contents = await file.readAsString();
      final decoded = jsonDecode(contents);
      if (decoded is! List) throw const FormatException('alert history is not a list');
      // Parse entries one by one: a single bad record must not wipe the whole
      // history on the next save (B29).
      final alerts = <AlertModel>[];
      for (final entry in decoded) {
        try {
          alerts.add(AlertModel.fromJson(Map<String, dynamic>.from(entry as Map)));
        } catch (e) {
          debugPrint('Skipping invalid alert entry: $e');
        }
      }
      // Sort by timestamp descending (newest first)
      alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _alerts = alerts.take(maxEntries).toList();
    } catch (e) {
      debugPrint('Error loading alerts: $e');
      // Keep the unreadable file aside instead of overwriting it on next save.
      try {
        if (await file.exists()) {
          await file.rename('${file.path}.corrupt');
        }
      } catch (e) {
        debugPrint('Could not back up corrupt alert history: $e');
      }
    }
  }

  Future<List<AlertModel>> getAlerts() async {
    await loadAlerts();
    return _alerts;
  }

  Future<void> addAlert(AlertModel alert) async {
    await loadAlerts();
    _alerts.insert(0, alert); // Add to beginning
    if (_alerts.length > maxEntries) {
      _alerts.removeRange(maxEntries, _alerts.length);
    }
    await _saveAlerts();
  }

  /// Writes are queued so they never interleave, and each write goes to a
  /// temporary file that then replaces the real one, so an app kill
  /// mid-write cannot leave a truncated history (B29).
  Future<void> _saveAlerts() {
    final snapshot = jsonEncode(_alerts.map((e) => e.toJson()).toList());
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        final file = await _localFile;
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(snapshot, flush: true);
        await tmp.rename(file.path);
      } catch (e) {
        debugPrint('Error saving alerts: $e');
      }
    });
    return _pendingWrite;
  }

  Future<void> clearHistory() async {
    await loadAlerts();
    _alerts.clear();
    await _saveAlerts();
  }
}
