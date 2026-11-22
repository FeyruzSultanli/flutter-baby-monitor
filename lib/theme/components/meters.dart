import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';

/// Maps the shared noise scale (0..120 dB, audio_level.dart) to 0..1 for the
/// meters. 20 dB and below is silence, 100 dB fills the bar.
double noiseFraction(double db) => ((db - 20) / 80).clamp(0.0, 1.0);

/// dB bar with a threshold marker (baby live screen, V2 §2).
class LevelMeter extends StatelessWidget {
  const LevelMeter({
    super.key,
    required this.db,
    required this.thresholdDb,
    this.active = true,
  });

  final double db;
  final double thresholdDb;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final f = active ? noiseFraction(db) : 0.0;
    final t = noiseFraction(thresholdDb);
    final color = db >= thresholdDb
        ? NinniColors.apricot
        : (f >= t * 0.85 ? NinniColors.amber : NinniColors.mint);
    return ExcludeSemantics(
      child: SizedBox(
        height: 22,
        // No LayoutBuilder: the screen measures intrinsic heights.
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: NinniColors.night700,
                borderRadius: BorderRadius.circular(NinniRadii.pill),
              ),
            ),
            AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 120),
              alignment: Alignment.centerLeft,
              widthFactor: math.max(0.04, f),
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: active ? color : NinniColors.night700,
                  borderRadius: BorderRadius.circular(NinniRadii.pill),
                ),
              ),
            ),
            Align(
              alignment: Alignment(-1 + 2 * t, 0),
              child: Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                  color: NinniColors.apricot,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live sound bars (parent). Driven by the real level at ~10 Hz; each bar
/// animates implicitly, so there is no 60 fps ticker (V2 §4).
class SoundBars extends StatelessWidget {
  const SoundBars({
    super.key,
    required this.db,
    this.color = NinniColors.mint,
    this.bars = 7,
    this.height = 36,
    this.active = true,
  });

  final double db;
  final Color color;
  final int bars;
  final double height;
  final bool active;

  static const List<double> _shape = [0.42, 0.75, 0.5, 1.0, 0.58, 0.33, 0.67];

  @override
  Widget build(BuildContext context) {
    final f = active ? noiseFraction(db) : 0.0;
    // A slowly moving phase from the level itself keeps bars from looking
    // static without a ticker.
    final jitter = (db * 7).round();
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < bars; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 110),
                curve: Curves.easeOut,
                width: 5,
                height: math.max(
                    6,
                    height *
                        (0.18 + 0.82 * f * _shape[(i + jitter) % _shape.length])),
                decoration: BoxDecoration(
                  color: active ? color : NinniColors.night700,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
