import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App language (tr / en / az), remembered across launches.
class LanguageProvider extends ChangeNotifier {
  LanguageProvider() {
    _load();
  }

  static const String _key = 'language';
  static const List<String> supported = ['tr', 'en'];

  Locale _locale = const Locale('tr');

  Locale get locale => _locale;

  Future<void> _load() async {
    try {
      final code = (await SharedPreferences.getInstance()).getString(_key);
      if (code != null && supported.contains(code) && code != _locale.languageCode) {
        _locale = Locale(code);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Loading language failed: $e');
    }
  }

  void setLocale(Locale newLocale) {
    _locale = newLocale;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((p) => p.setString(_key, newLocale.languageCode))
        .catchError((Object e) {
      debugPrint('Saving language failed: $e');
      return false;
    });
  }
}
