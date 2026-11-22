import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../tokens.dart';

/// Segmented control (Tasarruf / Dengeli / Net).
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = NinniPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.isNight ? NinniColors.night700 : NinniColors.cream100,
        borderRadius: BorderRadius.circular(NinniRadii.r14),
      ),
      child: Row(
        children: [
          for (final (value, label) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: value == selected,
                inMutuallyExclusiveGroup: true,
                label: label,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onChanged == null
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          onChanged!(value);
                        },
                  child: AnimatedContainer(
                    duration: NinniDurations.fast,
                    constraints: const BoxConstraints(minHeight: 40),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    decoration: BoxDecoration(
                      color: value == selected
                          ? (p.isNight ? NinniColors.white : NinniColors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                      label,
                      maxLines: 1,
                      style: NinniType.bodySm.copyWith(
                        fontSize: 14,
                        fontWeight: value == selected ? FontWeight.w700 : FontWeight.w600,
                        color: value == selected
                            ? NinniColors.ink
                            : (p.isNight ? NinniColors.onNightSoft : NinniColors.inkMuted),
                      ),
                    ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 52×32 switch (primary when on).
class NinniSwitch extends StatelessWidget {
  const NinniSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = NinniPalette.of(context);
    final off = p.isNight ? NinniColors.night700 : NinniColors.creamLineStrong;
    return Semantics(
      toggled: value,
      label: semanticLabel,
      enabled: onChanged != null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onChanged == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onChanged!(!value);
              },
        child: SizedBox(
          width: 56,
          height: NinniSpace.touch,
          child: Center(
            child: AnimatedContainer(
              duration: NinniDurations.fast,
              width: 52,
              height: 32,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value ? NinniColors.primary : off,
                borderRadius: BorderRadius.circular(NinniRadii.pill),
              ),
              child: AnimatedAlign(
                duration: NinniDurations.fast,
                curve: Curves.easeOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(color: NinniColors.white, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Filter chip (Bu gece / Dün / 7 gün).
class NinniChip extends StatelessWidget {
  const NinniChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = NinniPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? p.chipSelectedBg : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NinniRadii.pill),
          side: selected ? BorderSide.none : BorderSide(color: p.lineStrong, width: 1.5),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: NinniSpace.touch - 4, minWidth: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Text(
              label,
              style: NinniType.bodySm.copyWith(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? p.chipSelectedText : p.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
