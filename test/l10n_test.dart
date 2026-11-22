import 'dart:io';

import 'package:bebek_monitor_clean/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final tables = AppLocalizations.debugLocalizedValues;

  test('tr, en and az (V2 5.11) tables exist', () {
    expect(tables.keys.toSet(), {'en', 'tr', 'az'});
  });

  test('TR, EN and AZ have exactly the same keys', () {
    final en = tables['en']!.keys.toSet();
    for (final lang in ['tr', 'az']) {
      final other = tables[lang]!.keys.toSet();
      expect(en.difference(other), isEmpty, reason: 'missing in $lang');
      expect(other.difference(en), isEmpty, reason: 'missing in en (vs $lang)');
    }
  });

  test('placeholders are kept in every language', () {
    final placeholder = RegExp(r'\{[a-z]+\}');
    for (final key in tables['en']!.keys) {
      final expected = placeholder.allMatches(tables['en']![key]!).map((m) => m.group(0)).toSet();
      for (final lang in ['tr', 'az']) {
        final got = placeholder.allMatches(tables[lang]![key]!).map((m) => m.group(0)).toSet();
        expect(got, expected, reason: '$lang.$key');
      }
    }
  });

  test('new (_t) getters exist in every language', () {
    final source = File('lib/l10n/app_localizations.dart').readAsStringSync();
    final used = RegExp(r"_t\('(\w+)'\)").allMatches(source).map((m) => m.group(1)!).toSet();
    for (final lang in tables.keys) {
      expect(used.difference(tables[lang]!.keys.toSet()), isEmpty, reason: lang);
    }
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
