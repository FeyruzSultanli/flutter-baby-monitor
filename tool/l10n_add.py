#!/usr/bin/env python3
"""Adds keys to lib/l10n/app_localizations.dart (hand-written tables).

Usage: python3 tool/l10n_add.py strings.json
strings.json: {"key": {"en": "...", "tr": "...", "az": "..."}, ...}
Existing keys are replaced. A getter `String get key` is added once.
"""
import json
import re
import sys

PATH = 'lib/l10n/app_localizations.dart'


def dart_str(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$').replace('\n', '\\n') + "'"


def main():
    entries = json.load(open(sys.argv[1], encoding='utf-8'))
    src = open(PATH, encoding='utf-8').read()
    langs = re.findall(r"\n    '([a-z]{2})': \{\n", src)
    for lang in langs:
        start = src.index(f"\n    '{lang}': {{\n")
        end = src.index('\n    },', start)
        block = src[start:end]
        for key, vals in entries.items():
            if lang not in vals:
                raise SystemExit(f'missing {lang} for {key}')
            line = f"      '{key}': {dart_str(vals[lang])},"
            pat = re.compile(r"\n      '" + re.escape(key) + r"': .*?,(?=\n)")
            if pat.search(block):
                block = pat.sub(lambda m: '\n' + line, block, count=1)
            else:
                block += '\n' + line
        src = src[:start] + block + src[end:]
    marker = '\n}\n\nclass _AppLocalizationsDelegate'
    getters = ''
    for key in entries:
        if re.search(r'String get ' + re.escape(key) + r'\b', src):
            continue
        getters += f"\n  String get {key} => _t('{key}');"
    if '  String _t(String key)' not in src:
        getters = ("\n\n  String _t(String key) =>\n"
                   "      _localizedValues[locale.languageCode]?[key] ?? _localizedValues['en']![key]!;"
                   + getters)
    src = src.replace(marker, getters + marker, 1)
    open(PATH, 'w', encoding='utf-8').write(src)
    print(f'{len(entries)} keys, languages: {", ".join(langs)}')


if __name__ == '__main__':
    main()
