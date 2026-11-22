import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

enum PillTone { mint, apricot, amber, neutral }

/// Rounded status pill with an optional dot or icon ("Ebeveyn bağlı",
/// "CANLI", "%76 · şarjda").
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.tone = PillTone.neutral,
    this.icon,
    this.leading,
    this.dot = true,
    this.height = 32,
    this.onVideo = false,
    this.semanticLabel,
  });

  final String label;
  final PillTone tone;
  final IconData? icon;
  /// Custom icon widget (e.g. BassinetIcon), drawn like [icon].
  final Widget? leading;
  final bool dot;
  final double height;
  /// Over a video: always the dark night900 background.
  final bool onVideo;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = NinniPalette.of(context);
    late Color bg;
    late Color fg;
    late Color dotColor;
    switch (tone) {
      case PillTone.mint:
        bg = onVideo ? NinniColors.night900 : (p.isNight ? NinniColors.mintPillOnNight : NinniColors.mint.withValues(alpha: 0.14));
        fg = p.isNight || onVideo ? NinniColors.mintOnNight : NinniColors.mintText;
        dotColor = NinniColors.mint;
      case PillTone.apricot:
        bg = NinniColors.apricot;
        fg = NinniColors.onApricot;
        dotColor = NinniColors.onApricot;
      case PillTone.amber:
        bg = NinniColors.amber;
        fg = NinniColors.onAmber;
        dotColor = NinniColors.onAmber;
      case PillTone.neutral:
        bg = onVideo ? NinniColors.night900 : (p.isNight ? NinniColors.night800 : NinniColors.cream100);
        fg = p.isNight || onVideo ? NinniColors.onNightSoft : NinniColors.inkMuted;
        dotColor = fg;
    }
    final bold = tone == PillTone.apricot || tone == PillTone.amber;
    return Semantics(
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minHeight: height),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(NinniRadii.pill)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              IconTheme(data: IconThemeData(color: fg, size: 16), child: leading!),
              const SizedBox(width: 6),
            ] else if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ] else if (dot) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
            ],
            // V2.1 §4.2: never cut with "…"; shrink instead.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                label,
                maxLines: 1,
                style: NinniType.numeric(TextStyle(
                  fontFamily: NinniType.family,
                  fontSize: height < 31 ? 12 : 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                  letterSpacing: bold ? 0.4 : 0,
                  color: fg,
                )),
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The apricot "CANLI" badge on live video.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, required this.label, this.height = 28});

  final String label;
  final double height;

  @override
  Widget build(BuildContext context) =>
      StatusPill(label: label, tone: PillTone.apricot, height: height);
}
