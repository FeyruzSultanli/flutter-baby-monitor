import 'dart:io';

import 'package:bebek_monitor_clean/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final tables = AppLocalizations.debugLocalizedValues;

  test('only tr and en tables exist', () {
    expect(tables.keys.toSet(), {'en', 'tr'});
  });

  test('TR and EN have exactly the same keys', () {
    final en = tables['en']!.keys.toSet();
    final tr = tables['tr']!.keys.toSet();
    expect(en.difference(tr), isEmpty, reason: 'missing in tr');
    expect(tr.difference(en), isEmpty, reason: 'missing in en');
  });

  test('no translation is empty', () {
    for (final entry in tables.entries) {
      for (final kv in entry.value.entries) {
        expect(kv.value.trim(), isNotEmpty, reason: '${entry.key}.${kv.key}');
      }
    }
  });

  test('every getter refers to an existing key (getters use ! and would crash)', () {
    final source = File('lib/l10n/app_localizations.dart').readAsStringSync();
    final used = RegExp(r"_localizedValues\[locale\.languageCode\]!\['(\w+)'\]!")
        .allMatches(source)
        .map((m) => m.group(1)!)
        .toSet();
    expect(used, isNotEmpty);
    for (final lang in tables.keys) {
      final missing = used.difference(tables[lang]!.keys.toSet());
      expect(missing, isEmpty, reason: 'keys used by getters but missing in $lang');
    }
  });

  test('delegate supports tr/en only', () {
    const delegate = AppLocalizations.delegate;
    expect(delegate.isSupported(const Locale('tr')), isTrue);
    expect(delegate.isSupported(const Locale('en')), isTrue);
    expect(delegate.isSupported(const Locale('de')), isFalse);
  });
}
