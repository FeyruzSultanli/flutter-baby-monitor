import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/alert_model.dart';

class AlertHistoryService {
  static final AlertHistoryService _instance = AlertHistoryService._internal();
  factory AlertHistoryService() => _instance;
  AlertHistoryService._internal();

  List<AlertModel> _alerts = [];
  bool _loaded = false;

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/alert_history.json');
  }

  Future<void> loadAlerts() async {
    if (_loaded) return;
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);
        _alerts = jsonList.map((e) => AlertModel.fromJson(e)).toList();
        // Sort by timestamp descending (newest first)
        _alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
    } catch (e) {
      debugPrint('Error loading alerts: $e');
    } finally {
      _loaded = true;
    }
  }

  Future<List<AlertModel>> getAlerts() async {
    await loadAlerts();
    return _alerts;
  }

  Future<void> addAlert(AlertModel alert) async {
    await loadAlerts();
    _alerts.insert(0, alert); // Add to beginning
    await _saveAlerts();
  }

  Future<void> _saveAlerts() async {
    try {
      final file = await _localFile;
      final jsonList = _alerts.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving alerts: $e');
    }
  }

  Future<void> clearHistory() async {
    _alerts.clear();
    await _saveAlerts();
  }
}
