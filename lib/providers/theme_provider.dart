import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme of the menu screens (system / light / dark), remembered across
/// launches. Baby, live and alarm screens are always dark (V2 §2).
class ThemeProvider extends ChangeNotifier {
  ThemeProvider() {
    _load();
  }

  static const String _key = 'themeMode';

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  Future<void> _load() async {
    try {
      final name = (await SharedPreferences.getInstance()).getString(_key);
      final mode = ThemeMode.values.where((m) => m.name == name).firstOrNull;
      if (mode != null && mode != _mode) {
        _mode = mode;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Loading theme failed: $e');
    }
  }

  void setThemeMode(ThemeMode newMode) {
    _mode = newMode;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((p) => p.setString(_key, newMode.name))
        .catchError((Object e) {
      debugPrint('Saving theme failed: $e');
      return false;
    });
  }
}
