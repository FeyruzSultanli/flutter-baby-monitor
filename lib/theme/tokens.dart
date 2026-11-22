import 'package:flutter/painting.dart';

/// Ninni design tokens (docs/V2_PLAN.md §2). Screens use these instead of
/// literal colors and sizes.
abstract final class NinniColors {
  // Night (dark) surfaces
  static const night900 = Color(0xFF12142B);
  static const night800 = Color(0xFF1C1F3D);
  static const night700 = Color(0xFF2A2E55);
  static const nightLine = Color(0xFF2E3260);
  /// Camera placeholder / video background on night screens.
  static const nightVideo = Color(0xFF23264A);
  /// Inactive page dot on night screens.
  static const nightDot = Color(0xFF3A3E6B);
  /// Night mode (baby device): pure black.
  static const black = Color(0xFF000000);

  // Cream (light) surfaces
  static const cream50 = Color(0xFFFBF8F3);
  static const cream100 = Color(0xFFF1ECE3);
  static const creamLine = Color(0xFFECE6DB);
  /// Stronger light border (secondary buttons, chips).
  static const creamLineStrong = Color(0xFFD9D3C7);
  static const white = Color(0xFFFFFFFF);

  // Text
  static const ink = Color(0xFF191B33);
  static const inkMuted = Color(0xFF5E6283);
  static const onNight = Color(0xFFFFFFFF);
  static const onNightMuted = Color(0xFFA9ADCF);
  /// Body copy on night screens (slightly brighter than muted).
  static const onNightSoft = Color(0xFFC4C7E3);
  /// List text on night screens.
  static const onNightList = Color(0xFFE1E3F5);

  // Brand
  static const primary = Color(0xFF5B5BF0);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primarySoft = Color(0xFFECECFE);
  /// Primary as text on light surfaces (links, values): 4.5:1 on cream.
  static const primaryText = Color(0xFF4B4BD8);
  /// Primary as text/accent on night surfaces.
  static const primarySoftOnNight = Color(0xFFB9B9FF);
  static const primaryGlow = Color(0xFF8C8CFF);

  // Cry alarm and LIVE label only
  static const apricot = Color(0xFFFF8A5B);
  static const onApricot = Color(0xFF2A1206);
  static const apricotSoft = Color(0xFFFFE9DF);
  static const apricotSoftOnNight = Color(0xFFFFB494);
  static const apricotRing = Color(0xFFFF9D76);
  /// Apricot as text on light surfaces.
  static const apricotText = Color(0xFFC2531F);
  /// Border of the destructive button on night screens.
  static const apricotLineOnNight = Color(0xFF3A2A3A);

  // Connected / OK
  static const mint = Color(0xFF3DD6A3);
  static const mintOnNight = Color(0xFF7CEBC6);
  static const mintText = Color(0xFF12936B);
  static const mintPillOnNight = Color(0xFF123B33);
  /// Dimmed mint dot (night mode).
  static const mintDim = Color(0xFF2E8F70);

  // Connection lost / battery warning
  static const amber = Color(0xFFFFC46B);
  static const onAmber = Color(0xFF2A1D06);
  static const amberTileOnNight = Color(0xFF3A2C12);

  // Privacy note (onboarding)
  static const infoBg = Color(0xFF16304A);
  static const infoIcon = Color(0xFF9FD3FF);
  static const infoText = Color(0xFFCFE7FF);

  // Night mode clock
  static const nightClock = Color(0xFF5E6283);
  static const nightHint = Color(0xFF8A8EAE);

  // Night light colors (V2 5.5)
  static const lightAmber = Color(0xFFFFB45E);
  static const lightPink = Color(0xFFFF9FB2);
  static const lightPurple = Color(0xFFA99CFF);
  static const lightBlue = Color(0xFF7FC8FF);
}

abstract final class NinniRadii {
  static const double r12 = 12;
  static const double r14 = 14;
  static const double r18 = 18;
  static const double r20 = 20;
  static const double r22 = 22;
  static const double r24 = 24;
  static const double r28 = 28;
  static const double pill = 999;
}

abstract final class NinniSpace {
  /// Horizontal screen padding.
  static const double screen = 20;
  static const double cardPadding = 18;
  static const double gap = 12;
  /// Minimum touch target.
  static const double touch = 44;
  static const double primaryButtonHeight = 60;
  static const double secondaryButtonHeight = 52;
  /// Max content width on tablets.
  static const double maxContentWidth = 560;
}

abstract final class NinniDurations {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 280);
  static const pulse = Duration(milliseconds: 1600);
  static const twinkle = Duration(seconds: 3);
  static const breathe = Duration(seconds: 4);
}

/// Type scale (Plus Jakarta Sans, bundled in assets/fonts).
abstract final class NinniType {
  static const String family = 'PlusJakartaSans';
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static const display = TextStyle(
      fontFamily: family, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.1);
  static const h1 = TextStyle(
      fontFamily: family, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.15);
  static const h2 = TextStyle(
      fontFamily: family, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.2);
  static const title = TextStyle(
      fontFamily: family, fontSize: 17, fontWeight: FontWeight.w800, height: 1.25);
  static const body = TextStyle(
      fontFamily: family, fontSize: 16, fontWeight: FontWeight.w500, height: 1.5);
  static const bodySm = TextStyle(
      fontFamily: family, fontSize: 15, fontWeight: FontWeight.w500, height: 1.45);
  static const label = TextStyle(
      fontFamily: family, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.4, height: 1.3);
  static const caption = TextStyle(
      fontFamily: family, fontSize: 12, fontWeight: FontWeight.w600, height: 1.35);

  /// Numbers (dB, battery, time, code): tabular figures.
  static TextStyle numeric(TextStyle base) => base.copyWith(fontFeatures: _tabular);
}
