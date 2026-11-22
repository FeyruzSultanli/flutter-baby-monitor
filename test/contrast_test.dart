import 'dart:math' as math;

import 'package:bebek_monitor_clean/theme/tokens.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.x contrast ratio.
double contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final l1 = lum(a);
  final l2 = lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  // (name, text, background) — body/caption text: at least 4.5:1 (V2 §6/4).
  const normal = <(String, Color, Color)>[
    ('white on night900', NinniColors.onNight, NinniColors.night900),
    ('white on night800', NinniColors.onNight, NinniColors.night800),
    ('white on night700', NinniColors.onNight, NinniColors.night700),
    ('muted on night900', NinniColors.onNightMuted, NinniColors.night900),
    ('muted on night800', NinniColors.onNightMuted, NinniColors.night800),
    ('soft on night800', NinniColors.onNightSoft, NinniColors.night800),
    ('soft on night700', NinniColors.onNightSoft, NinniColors.night700),
    ('muted on video', NinniColors.onNightMuted, NinniColors.nightVideo),
    ('white on primary', NinniColors.onPrimary, NinniColors.primary),
    ('accent on night800', NinniColors.primarySoftOnNight, NinniColors.night800),
    ('ink on cream50', NinniColors.ink, NinniColors.cream50),
    ('inkMuted on cream50', NinniColors.inkMuted, NinniColors.cream50),
    ('inkMuted on white', NinniColors.inkMuted, NinniColors.white),
    ('inkMuted on cream100', NinniColors.inkMuted, NinniColors.cream100),
    ('primaryText on cream50', NinniColors.primaryText, NinniColors.cream50),
    ('primaryText on white', NinniColors.primaryText, NinniColors.white),
    ('onApricot on apricot', NinniColors.onApricot, NinniColors.apricot),
    ('onApricot on apricotSoftOnNight', NinniColors.onApricot, NinniColors.apricotSoftOnNight),
    ('apricotText on apricotSoft', NinniColors.apricotText, NinniColors.apricotSoft),
    ('apricot accent on night800', NinniColors.apricotSoftOnNight, NinniColors.night800),
    ('onAmber on amber', NinniColors.onAmber, NinniColors.amber),
    ('mint on mint pill', NinniColors.mintOnNight, NinniColors.mintPillOnNight),
    ('mint on night900', NinniColors.mintOnNight, NinniColors.night900),
    ('mintText on cream50', NinniColors.mintText, NinniColors.cream50),
    ('info text on info bg', NinniColors.infoText, NinniColors.infoBg),
    ('list on night900', NinniColors.onNightList, NinniColors.night900),
    ('night hint on black', NinniColors.nightHint, NinniColors.black),
    ('chip selected', NinniColors.white, NinniColors.ink),
  ];
  // Large text (>= 24 px or 19 px bold): at least 3:1. The night mode clock
  // is deliberately dim (64 px light).
  const large = <(String, Color, Color)>[
    ('night clock on black', NinniColors.nightClock, NinniColors.black),
  ];

  for (final (name, fg, bg) in normal) {
    test('$name >= 4.5:1', () {
      expect(contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: contrast(fg, bg).toStringAsFixed(2));
    });
  }
  for (final (name, fg, bg) in large) {
    test('$name >= 3:1 (large text)', () {
      expect(contrast(fg, bg), greaterThanOrEqualTo(3.0), reason: contrast(fg, bg).toStringAsFixed(2));
    });
  }
}
