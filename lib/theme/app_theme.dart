import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Semantic colors that differ between the light (cream) and dark (night)
/// themes. Screens read them with `NinniPalette.of(context)`.
@immutable
class NinniPalette extends ThemeExtension<NinniPalette> {
  const NinniPalette({
    required this.isNight,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.line,
    required this.lineStrong,
    required this.text,
    required this.textMuted,
    required this.textSoft,
    required this.accentText,
    required this.primarySoftBg,
    required this.mintText,
    required this.apricotText,
    required this.dangerLine,
    required this.chipSelectedBg,
    required this.chipSelectedText,
  });

  final bool isNight;
  final Color bg;
  final Color surface;
  /// Back button, info boxes, segmented control track.
  final Color surfaceAlt;
  final Color line;
  final Color lineStrong;
  final Color text;
  final Color textMuted;
  /// Longer body copy (slightly brighter than muted on night).
  final Color textSoft;
  /// Links and highlighted values.
  final Color accentText;
  final Color primarySoftBg;
  final Color mintText;
  final Color apricotText;
  final Color dangerLine;
  final Color chipSelectedBg;
  final Color chipSelectedText;

  static const light = NinniPalette(
    isNight: false,
    bg: NinniColors.cream50,
    surface: NinniColors.white,
    surfaceAlt: NinniColors.cream100,
    line: NinniColors.creamLine,
    lineStrong: NinniColors.creamLineStrong,
    text: NinniColors.ink,
    textMuted: NinniColors.inkMuted,
    textSoft: NinniColors.inkMuted,
    accentText: NinniColors.primaryText,
    primarySoftBg: NinniColors.primarySoft,
    mintText: NinniColors.mintText,
    apricotText: NinniColors.apricotText,
    dangerLine: NinniColors.apricotSoft,
    chipSelectedBg: NinniColors.ink,
    chipSelectedText: NinniColors.white,
  );

  static const night = NinniPalette(
    isNight: true,
    bg: NinniColors.night900,
    surface: NinniColors.night800,
    surfaceAlt: NinniColors.night800,
    line: NinniColors.nightLine,
    lineStrong: NinniColors.nightLine,
    text: NinniColors.onNight,
    textMuted: NinniColors.onNightMuted,
    textSoft: NinniColors.onNightSoft,
    accentText: NinniColors.primarySoftOnNight,
    primarySoftBg: NinniColors.night700,
    mintText: NinniColors.mintOnNight,
    apricotText: NinniColors.apricotSoftOnNight,
    dangerLine: NinniColors.apricotLineOnNight,
    chipSelectedBg: NinniColors.white,
    chipSelectedText: NinniColors.ink,
  );

  static NinniPalette of(BuildContext context) =>
      Theme.of(context).extension<NinniPalette>() ?? light;

  @override
  NinniPalette copyWith() => this;

  @override
  NinniPalette lerp(NinniPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return NinniPalette(
      isNight: t < 0.5 ? isNight : other.isNight,
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      line: l(line, other.line),
      lineStrong: l(lineStrong, other.lineStrong),
      text: l(text, other.text),
      textMuted: l(textMuted, other.textMuted),
      textSoft: l(textSoft, other.textSoft),
      accentText: l(accentText, other.accentText),
      primarySoftBg: l(primarySoftBg, other.primarySoftBg),
      mintText: l(mintText, other.mintText),
      apricotText: l(apricotText, other.apricotText),
      dangerLine: l(dangerLine, other.dangerLine),
      chipSelectedBg: l(chipSelectedBg, other.chipSelectedBg),
      chipSelectedText: l(chipSelectedText, other.chipSelectedText),
    );
  }
}

abstract final class NinniTheme {
  static final ThemeData light = _build(NinniPalette.light);
  static final ThemeData night = _build(NinniPalette.night);

  static ThemeData _build(NinniPalette p) {
    final brightness = p.isNight ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: NinniColors.primary,
      onPrimary: NinniColors.onPrimary,
      secondary: NinniColors.primary,
      onSecondary: NinniColors.onPrimary,
      error: NinniColors.apricot,
      onError: NinniColors.onApricot,
      surface: p.bg,
      onSurface: p.text,
      onSurfaceVariant: p.textMuted,
      outline: p.lineStrong,
      outlineVariant: p.line,
      surfaceContainerHighest: p.surfaceAlt,
      surfaceContainer: p.surface,
      primaryContainer: p.primarySoftBg,
      onPrimaryContainer: p.accentText,
    );
    final text = TextTheme(
      displaySmall: NinniType.display.copyWith(color: p.text),
      headlineMedium: NinniType.h1.copyWith(color: p.text),
      headlineSmall: NinniType.h2.copyWith(color: p.text),
      titleLarge: NinniType.h2.copyWith(color: p.text),
      titleMedium: NinniType.title.copyWith(color: p.text),
      titleSmall: NinniType.bodySm.copyWith(color: p.text, fontWeight: FontWeight.w700),
      bodyLarge: NinniType.body.copyWith(color: p.text),
      bodyMedium: NinniType.bodySm.copyWith(color: p.text),
      bodySmall: NinniType.caption.copyWith(color: p.textMuted),
      labelLarge: NinniType.bodySm.copyWith(color: p.text, fontWeight: FontWeight.w700),
      labelMedium: NinniType.label.copyWith(color: p.textMuted),
      labelSmall: NinniType.caption.copyWith(color: p.textMuted),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: NinniType.family,
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      textTheme: text,
      extensions: [p],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: NinniType.h2.copyWith(color: p.text),
      ),
      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.isNight ? NinniColors.primaryGlow : NinniColors.primary,
        inactiveTrackColor: p.isNight ? NinniColors.night700 : NinniColors.cream100,
        thumbColor: p.isNight ? NinniColors.primaryGlow : NinniColors.primary,
        overlayColor: NinniColors.primary.withValues(alpha: 0.12),
        trackHeight: 6,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.isNight ? NinniColors.night700 : NinniColors.ink,
        contentTextStyle: NinniType.bodySm.copyWith(color: NinniColors.white),
        actionTextColor: NinniColors.primarySoftOnNight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NinniRadii.r14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.isNight ? NinniColors.night800 : NinniColors.cream50,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        showDragHandle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.isNight ? NinniColors.night800 : NinniColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NinniRadii.r24)),
        titleTextStyle: NinniType.title.copyWith(color: p.text),
        contentTextStyle: NinniType.bodySm.copyWith(color: p.textSoft),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accentText,
          minimumSize: const Size(NinniSpace.touch, NinniSpace.touch),
          textStyle: NinniType.bodySm.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.isNight ? NinniColors.primarySoftOnNight : NinniColors.primary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal),
        // iOS keeps the native page transition: it carries the swipe-back
        // gesture (DECISIONS A24).
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
