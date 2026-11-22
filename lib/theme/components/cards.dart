import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../tokens.dart';

/// Surface card: white with a fine border on cream, night800 on night.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NinniSpace.cardPadding),
    this.radius = NinniRadii.r22,
    this.color,
    this.border = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final bool border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = NinniPalette.of(context);
    final bg = color ?? p.surface;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: border && !p.isNight && color == null
          ? BorderSide(color: p.line, width: 1.5)
          : BorderSide.none,
    );
    final content = Padding(padding: padding, child: child);
    return Material(
      color: bg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap!();
              },
              child: content,
            ),
    );
  }
}

/// Upper case section label ("ALARM", "SON BAĞLANDIĞINIZ").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.padding = const EdgeInsets.only(left: 4)});

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = NinniPalette.of(context);
    return Padding(
      padding: padding,
      child: Semantics(
        header: true,
        child: Text(text.toUpperCase(), style: NinniType.label.copyWith(color: p.textMuted)),
      ),
    );
  }
}

/// A row in a settings card: title, optional subtitle, trailing widget or
/// value text with a chevron.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.divider = true,
    this.showChevron,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool divider;
  final bool? showChevron;

  @override
  Widget build(BuildContext context) {
    final p = NinniPalette.of(context);
    final chevron = showChevron ?? (onTap != null && trailing == null);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: NinniType.bodySm.copyWith(color: p.text, fontWeight: FontWeight.w700)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: NinniType.caption.copyWith(color: p.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (trailing != null) trailing!,
            if (value != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  chevron ? '$value ›' : value!,
                  textAlign: TextAlign.end,
                  style: NinniType.numeric(
                      NinniType.bodySm.copyWith(color: p.textMuted, fontWeight: FontWeight.w600)),
                ),
              )
            else if (chevron)
              Icon(Icons.chevron_right_rounded, color: p.textMuted),
          ],
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider
            ? Border(bottom: BorderSide(color: p.isNight ? p.line : NinniColors.cream100))
            : null,
      ),
      child: onTap == null
          ? Semantics(container: true, child: row)
          : InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap!();
              },
              child: row,
            ),
    );
  }
}

/// Square icon + label tile (parent grid: Ninni / Kaydet / Çevir / Ayarlar).
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.iconWidget,
    this.active = false,
    this.height = 80,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Widget? iconWidget;
  final bool active;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: Material(
          color: active ? NinniColors.night700 : NinniColors.night800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NinniRadii.r20),
            side: active
                ? const BorderSide(color: NinniColors.primaryGlow, width: 2)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onTap!();
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  iconWidget ?? Icon(icon, size: 24, color: NinniColors.onNight),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: NinniType.caption.copyWith(color: NinniColors.onNight, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
