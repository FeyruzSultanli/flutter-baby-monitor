import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';
import 'ninni_button.dart';

/// Forces the night theme for its subtree (baby side, live view, alarms,
/// onboarding are always dark; V2 §2).
class NightTheme extends StatelessWidget {
  const NightTheme({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(data: NinniTheme.night, child: child);
}

/// Standard screen frame: safe area, 20 px side padding, scrolls when the
/// content does not fit (small phones, large text) and centers a max 560 px
/// column on tablets. [footer] sticks to the bottom when there is room.
class ScreenFrame extends StatelessWidget {
  const ScreenFrame({
    super.key,
    required this.items,
    this.footer = const [],
    this.gap = 24,
    this.padding = const EdgeInsets.fromLTRB(NinniSpace.screen, 16, NinniSpace.screen, 24),
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final List<Widget> items;
  final List<Widget> footer;
  final double gap;
  final EdgeInsets padding;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          padding: padding,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: NinniSpace.maxContentWidth,
                minHeight: (constraints.maxHeight - padding.vertical).clamp(0, double.infinity),
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: crossAxisAlignment,
                  children: [
                    ..._spaced(items, gap),
                    if (footer.isNotEmpty) ...[
                      const Spacer(),
                      SizedBox(height: gap),
                      ..._spaced(footer, 12),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  static List<Widget> _spaced(List<Widget> items, double gap) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) out.add(SizedBox(height: gap));
      out.add(items[i]);
    }
    return out;
  }
}

/// Title + subtitle block.
class ScreenHeading extends StatelessWidget {
  const ScreenHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.style,
    this.textAlign = TextAlign.start,
  });

  final String title;
  final String? subtitle;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final p = NinniPalette.of(context);
    return Column(
      crossAxisAlignment:
          textAlign == TextAlign.center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, textAlign: textAlign, style: (style ?? NinniType.h1).copyWith(color: p.text)),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, textAlign: textAlign, style: NinniType.bodySm.copyWith(color: p.textMuted)),
        ],
      ],
    );
  }
}

/// Back button + optional title (light menu screens).
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.backLabel, this.title, this.onBack, this.trailing});

  final String backLabel;
  final String? title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = NinniPalette.of(context);
    return Row(
      children: [
        NinniIconButton(
          key: const Key('backButton'),
          icon: Icons.chevron_left_rounded,
          tooltip: backLabel,
          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
        ),
        if (title != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title!, style: NinniType.h2.copyWith(color: p.text)),
            ),
          ),
        ] else
          const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Bottom sheet frame: handle, title and close button (Lullaby, pickers).
class BottomSheetFrame extends StatelessWidget {
  const BottomSheetFrame({
    super.key,
    required this.title,
    required this.closeLabel,
    required this.child,
  });

  final String title;
  final String closeLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = NinniPalette.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            NinniSpace.screen, 12, NinniSpace.screen, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: p.isNight ? NinniColors.nightDot : NinniColors.creamLineStrong,
                  borderRadius: BorderRadius.circular(NinniRadii.pill),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: NinniType.h2.copyWith(color: p.text)),
                  ),
                ),
                NinniIconButton(
                  icon: Icons.close_rounded,
                  tooltip: closeLabel,
                  size: 40,
                  radius: NinniRadii.r12,
                  background: p.isNight ? NinniColors.night700 : NinniColors.cream100,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Flexible(child: SingleChildScrollView(child: child)),
          ],
        ),
      ),
    );
  }
}

/// Shows a spring-animated bottom sheet with the current theme.
Future<T?> showNinniSheet<T>(BuildContext context, WidgetBuilder builder, {bool night = false}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 420),
      reverseDuration: Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
    ),
    backgroundColor: night ? NinniColors.night800 : null,
    builder: (ctx) => night ? NightTheme(child: Builder(builder: builder)) : builder(ctx),
  );
}
