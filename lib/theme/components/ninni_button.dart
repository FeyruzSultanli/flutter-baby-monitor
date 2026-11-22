import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../tokens.dart';

enum NinniButtonVariant { primary, secondary, ghost, danger }

/// Ninni button: 60 px primary (r20), 52 px secondary (r18). Pressing scales
/// to 97 % with a light haptic (V2 §4). Colors can be overridden for the
/// alarm screens (amber / apricot).
class NinniButton extends StatefulWidget {
  const NinniButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = NinniButtonVariant.primary,
    this.height,
    this.expand = true,
    this.busy = false,
    this.background,
    this.foreground,
    this.borderColor,
    this.fontSize,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final NinniButtonVariant variant;
  final double? height;
  final bool expand;
  final bool busy;
  final Color? background;
  final Color? foreground;
  final Color? borderColor;
  final double? fontSize;
  final String? semanticLabel;

  @override
  State<NinniButton> createState() => _NinniButtonState();
}

class _NinniButtonState extends State<NinniButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.busy;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final p = NinniPalette.of(context);
    final primary = widget.variant == NinniButtonVariant.primary;
    final height = widget.height ??
        (primary
            ? NinniSpace.primaryButtonHeight
            : NinniSpace.secondaryButtonHeight);
    final radius = primary ? NinniRadii.r20 : NinniRadii.r18;

    Color bg;
    Color fg;
    Color? border;
    switch (widget.variant) {
      case NinniButtonVariant.primary:
        bg = NinniColors.primary;
        fg = NinniColors.onPrimary;
        border = null;
      case NinniButtonVariant.secondary:
        bg = p.isNight ? Colors.transparent : NinniColors.white;
        fg = p.isNight ? NinniColors.onNight : NinniColors.ink;
        border = p.lineStrong;
      case NinniButtonVariant.ghost:
        bg = Colors.transparent;
        fg = p.textMuted;
        border = null;
      case NinniButtonVariant.danger:
        bg = Colors.transparent;
        fg = p.apricotText;
        border = p.dangerLine;
    }
    bg = widget.background ?? bg;
    fg = widget.foreground ?? fg;
    border = widget.borderColor ?? border;
    if (!_enabled) {
      fg = fg.withValues(alpha: 0.45);
      if (bg != Colors.transparent) bg = bg.withValues(alpha: 0.55);
    }
    final textStyle = TextStyle(
      fontFamily: NinniType.family,
      fontSize: widget.fontSize ?? (primary ? 17 : 15),
      fontWeight: primary ? FontWeight.w800 : FontWeight.w700,
      color: fg,
      height: 1.2,
    );

    final child = widget.busy
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 22, color: fg),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  style: textStyle,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                ),
              ),
            ],
          );

    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? 0.97 : 1,
        duration: NinniDurations.fast,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: height,
            minWidth: widget.expand ? double.infinity : NinniSpace.touch,
          ),
          child: Material(
            color: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              side: border == null
                  ? BorderSide.none
                  : BorderSide(color: border, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _enabled
                  ? () {
                      HapticFeedback.lightImpact();
                      widget.onPressed!();
                    }
                  : null,
              onHighlightChanged: _setPressed,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child:
                    Center(widthFactor: widget.expand ? null : 1, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 44×44 rounded square icon button (back, settings, close).
class NinniIconButton extends StatelessWidget {
  const NinniIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.background,
    this.foreground,
    this.size = NinniSpace.touch,
    this.radius = NinniRadii.r14,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? background;
  final Color? foreground;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = NinniPalette.of(context);
    void tap() {
      HapticFeedback.selectionClick();
      onPressed!();
    }

    // The visual square stays [size] (mockups: 40-44); the tap target is at
    // least 48 (Android) / 44 (iOS) (V2 phase 4).
    final hit = size < 48 ? 48.0 : size;
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed == null ? null : tap,
          child: SizedBox(
            width: hit,
            height: hit,
            child: Center(
              // One semantics node for the whole 48 px target (the outer
              // GestureDetector carries the tap action).
              child: ExcludeSemantics(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Material(
                    color: background ?? p.surfaceAlt,
                    borderRadius: BorderRadius.circular(radius),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onPressed == null ? null : tap,
                      child: Icon(icon, size: 22, color: foreground ?? p.text),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
