import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'meters.dart';

/// Color of a level relative to the threshold (mint, amber near it,
/// apricot above it).
Color levelColor(double db, double threshold) {
  if (db >= threshold) return NinniColors.apricot;
  if (noiseFraction(db) >= noiseFraction(threshold) * 0.85) return NinniColors.amber;
  return NinniColors.mint;
}

/// Number that counts to its new value (V2.1 §4.4). Static when animations
/// are off.
class CountText extends StatelessWidget {
  const CountText(this.value, {super.key, required this.style, this.duration = const Duration(milliseconds: 450)});

  final num value;
  final TextStyle style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final target = value.toDouble();
    if (reduce) return Text('${value.round()}', style: NinniType.numeric(style));
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: target),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}', style: NinniType.numeric(style)),
    );
  }
}

/// Ring gauge: the dB arc with a threshold notch (baby live sound card).
class RingGauge extends StatelessWidget {
  const RingGauge(
      {super.key, required this.db, required this.threshold, this.size = 96, this.active = true, this.unit = 'dB'});

  final double db;
  final double threshold;
  final double size;
  final bool active;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final value = active ? db : 0.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: noiseFraction(value)),
            duration: const Duration(milliseconds: 160),
            builder: (context, f, _) => CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                fraction: f,
                threshold: noiseFraction(threshold),
                color: active ? levelColor(value, threshold) : NinniColors.night700,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CountText(value,
                  duration: const Duration(milliseconds: 200),
                  style: NinniType.h2.copyWith(fontSize: 26, height: 1, color: NinniColors.onNight)),
              Text(unit,
                  style: NinniType.caption
                      .copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: NinniColors.onNightMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.threshold, required this.color});
  final double fraction;
  final double threshold;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.094;
    final c = size.center(Offset.zero);
    final r = size.width / 2 - stroke / 2 - size.width * 0.03;
    final track = Paint()
      ..color = NinniColors.night700
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(c, r, track);
    if (fraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * fraction.clamp(0.02, 1.0),
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke,
      );
    }
    // Threshold notch across the ring.
    final a = -math.pi / 2 + 2 * math.pi * threshold;
    final dir = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(
      c + dir * (r - stroke * 0.85),
      c + dir * (r + stroke * 0.85),
      Paint()
        ..color = NinniColors.apricot
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.threshold != threshold || old.color != color;
}

/// "Last hour" bars: one bar per minute (aggregated when narrow), the
/// threshold as a dashed line, alarm minutes in apricot.
class MinuteBars extends StatelessWidget {
  const MinuteBars({super.key, required this.values, required this.threshold, this.height = 44});

  final List<({double? db, bool alarm})> values;
  final double threshold;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _MinuteBarsPainter(values, threshold)),
      ),
    );
  }
}

class _MinuteBarsPainter extends CustomPainter {
  _MinuteBarsPainter(this.values, this.threshold);
  final List<({double? db, bool alarm})> values;
  final double threshold;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const gap = 2.0;
    const minBar = 2.5;
    final maxBars = ((size.width + gap) / (minBar + gap)).floor().clamp(1, values.length);
    final group = (values.length / maxBars).ceil();
    final bars = <({double? db, bool alarm})>[];
    for (var i = 0; i < values.length; i += group) {
      double? m;
      var alarm = false;
      for (var j = i; j < math.min(i + group, values.length); j++) {
        final v = values[j];
        if (v.db != null && (m == null || v.db! > m)) m = v.db;
        alarm = alarm || v.alarm;
      }
      bars.add((db: m, alarm: alarm));
    }
    final w = (size.width - gap * (bars.length - 1)) / bars.length;
    for (var i = 0; i < bars.length; i++) {
      final b = bars[i];
      final f = b.db == null ? 0.0 : noiseFraction(b.db!);
      final h = math.max(3.0, f * size.height);
      final color = b.db == null
          ? NinniColors.night700
          : (b.alarm
              ? NinniColors.apricot
              : (b.db! >= threshold * 0.85
                  ? NinniColors.amber.withValues(alpha: 0.85)
                  : NinniColors.mint.withValues(alpha: 0.85)));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(i * (w + gap), size.height - h, w, h), const Radius.circular(2)),
        Paint()..color = color,
      );
    }
    // Dashed threshold line.
    final y = size.height - noiseFraction(threshold) * size.height;
    final dash = Paint()
      ..color = NinniColors.apricot.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), dash);
    }
  }

  @override
  bool shouldRepaint(_MinuteBarsPainter old) => !listEquals(old.values, values) || old.threshold != threshold;
}

/// Live wave (parent sound card, talk card): the last [count] readings of
/// [level] as centered bars, from real audio (V2.1 §4.5).
class LiveWave extends StatefulWidget {
  const LiveWave({
    super.key,
    required this.level,
    this.count = 36,
    this.height = 34,
    this.color = NinniColors.mint,
    this.active = true,
    this.linear = false,
    this.initial,
  });

  /// Starting bars (0..1), e.g. for demo screenshots.
  final List<double>? initial;

  /// dB on the app scale, or (with [linear]) 0..1.
  final ValueListenable<double> level;
  final int count;
  final double height;
  final Color color;
  final bool active;
  final bool linear;

  @override
  State<LiveWave> createState() => _LiveWaveState();
}

class _LiveWaveState extends State<LiveWave> {
  late final List<double> _samples = [
    for (var i = 0; i < widget.count; i++)
      widget.initial == null || widget.initial!.isEmpty ? 0.0 : widget.initial![i % widget.initial!.length],
  ];
  final ValueNotifier<int> _rev = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    widget.level.addListener(_onLevel);
  }

  @override
  void didUpdateWidget(LiveWave old) {
    super.didUpdateWidget(old);
    if (old.level != widget.level) {
      old.level.removeListener(_onLevel);
      widget.level.addListener(_onLevel);
    }
  }

  void _onLevel() {
    final v = widget.level.value;
    final f = widget.linear ? math.sqrt(v.clamp(0.0, 1.0)) : noiseFraction(v);
    _samples.removeAt(0);
    _samples.add(widget.active ? f : 0);
    _rev.value++;
  }

  @override
  void dispose() {
    widget.level.removeListener(_onLevel);
    _rev.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: CustomPaint(painter: _WavePainter(_samples, _rev, widget.color)),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.samples, this.rev, this.color) : super(repaint: rev);
  final List<double> samples;
  final ValueNotifier<int> rev;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 3.0;
    final n = samples.length;
    final w = (size.width - gap * (n - 1)) / n;
    final paint = Paint()..color = color;
    for (var i = 0; i < n; i++) {
      final h = math.max(4.0, samples[i] * size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(i * (w + gap) + w / 2, size.height / 2), width: w, height: h),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.color != color;
}

/// Hourly alarm bars for the night (alert history, 21:00 → 07:00).
class HourBars extends StatelessWidget {
  const HourBars(
      {super.key,
      required this.counts,
      required this.labels,
      this.height = 72,
      required this.barColor,
      required this.emptyColor,
      required this.labelStyle});

  final List<int> counts;
  final List<String> labels;
  final double height;
  final Color barColor;
  final Color emptyColor;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    final maxCount = counts.fold<int>(1, math.max);
    return ExcludeSemantics(
      child: Column(
        children: [
          SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < counts.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: counts[i] / maxCount),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (context, f, _) => Container(
                        height: math.max(4, f * height),
                        decoration: BoxDecoration(
                          color: counts[i] == 0 ? emptyColor : barColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Text(labels[i],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: labelStyle),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Rings spreading out of the talk button while talking (V2.1 §4.5).
class TalkRings extends StatefulWidget {
  const TalkRings({super.key, required this.active, required this.size, required this.child});
  final bool active;
  final double size;
  final Widget child;

  @override
  State<TalkRings> createState() => _TalkRingsState();
}

class _TalkRingsState extends State<TalkRings> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  void _sync() {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.active && !reduce) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(TalkRings old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (widget.active)
            for (final delay in [0.0, 0.5])
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final t = (_c.value + delay) % 1.0;
                  return Transform.scale(
                    scale: 1 + 0.5 * t,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: NinniColors.primaryGlow.withValues(alpha: 0.5 * (1 - t)), width: 2),
                      ),
                    ),
                  );
                },
              ),
          widget.child,
        ],
      ),
    );
  }
}
