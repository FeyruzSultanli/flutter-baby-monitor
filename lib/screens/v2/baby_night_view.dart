import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';

/// Baby phone night mode (mockup BabyNight, D1-a): black, a dim clock,
/// the broadcast state, double tap to leave. No animations (V2 §4). With the
/// night light on (V2 5.5) the screen glows softly in the chosen color.
class BabyNightView extends StatefulWidget {
  const BabyNightView({
    super.key,
    required this.parentConnected,
    required this.onExit,
    this.lightColor,
  });

  final bool parentConnected;
  final VoidCallback onExit;
  /// Night light color, or null when the light is off.
  final Color? lightColor;

  @override
  State<BabyNightView> createState() => _BabyNightViewState();
}

class _BabyNightViewState extends State<BabyNightView> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  // One rebuild per minute, on the minute.
  void _scheduleTick() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    _clock = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleTick();
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final light = widget.lightColor;
    final time = DateFormat.Hm().format(DateTime.now());
    final status = widget.parentConnected ? l10n.nightStatusConnected : l10n.nightStatusWaiting;
    // With the night light, text stays readable but very dim.
    final clockColor = light == null ? NinniColors.nightClock : Colors.black.withValues(alpha: 0.35);
    final hintColor = light == null ? NinniColors.nightHint : Colors.black.withValues(alpha: 0.4);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onExit();
      },
      child: GestureDetector(
        key: const Key('nightModeOverlay'),
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onExit,
        child: Semantics(
          label: '$time. $status. ${l10n.nightExitHint}',
          button: true,
          onTap: widget.onExit,
          excludeSemantics: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: NinniColors.black,
              gradient: light == null
                  ? null
                  : RadialGradient(
                      radius: 1.1,
                      colors: [light.withValues(alpha: 0.55), light.withValues(alpha: 0.32)],
                    ),
            ),
            child: SafeArea(
              child: SizedBox.expand(
                child: Column(
                  children: [
                    const Spacer(flex: 5),
                    Icon(Icons.dark_mode_outlined, size: 28, color: clockColor),
                    const SizedBox(height: 14),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        time,
                        style: NinniType.numeric(TextStyle(
                          fontFamily: NinniType.family,
                          fontSize: 64,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -2,
                          color: clockColor,
                        )),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.parentConnected ? NinniColors.mintDim : hintColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(status,
                              textAlign: TextAlign.center,
                              style: NinniType.label.copyWith(
                                  letterSpacing: 0, fontWeight: FontWeight.w600, color: hintColor)),
                        ),
                      ],
                    ),
                    const Spacer(flex: 6),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      child: Text(l10n.nightExitHint,
                          textAlign: TextAlign.center,
                          style: NinniType.label.copyWith(
                              letterSpacing: 0, fontWeight: FontWeight.w600, color: hintColor)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
