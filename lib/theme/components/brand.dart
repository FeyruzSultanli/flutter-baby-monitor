import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';

/// The Ninni mark (V2 §1), painted: night rounded square, cream crescent
/// (circle 76,84 r46 minus circle 100,62 r40) and an apricot dot (104,74
/// r11) on a 160×160 grid.
class AppIconPainter extends CustomPainter {
  const AppIconPainter({
    this.background = NinniColors.night900,
    this.crescent = NinniColors.cream50,
    this.dot = NinniColors.apricot,
    this.showBackground = true,
    this.circleBackground,
  });

  final Color background;
  final Color crescent;
  final Color dot;
  final bool showBackground;
  /// Onboarding: a round night800 disc instead of the rounded square.
  final Color? circleBackground;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 160;
    canvas.save();
    canvas.translate((size.width - 160 * s) / 2, (size.height - 160 * s) / 2);
    canvas.scale(s);
    if (circleBackground != null) {
      canvas.drawCircle(const Offset(80, 80), 76, Paint()..color = circleBackground!);
    } else if (showBackground) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 160, 160), const Radius.circular(40)),
        Paint()..color = background,
      );
    }
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: const Offset(76, 84), radius: 46)),
      Path()..addOval(Rect.fromCircle(center: const Offset(100, 62), radius: 40)),
    );
    canvas.drawPath(moon, Paint()..color = crescent..isAntiAlias = true);
    canvas.drawCircle(const Offset(104, 74), 11, Paint()..color = dot);
    canvas.restore();
  }

  @override
  bool shouldRepaint(AppIconPainter old) =>
      old.background != background ||
      old.crescent != crescent ||
      old.dot != dot ||
      old.showBackground != showBackground ||
      old.circleBackground != circleBackground;
}

class AppIcon extends StatelessWidget {
  const AppIcon({super.key, this.size = 36, this.painter = const AppIconPainter()});

  final double size;
  final AppIconPainter painter;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(size: Size.square(size), painter: painter),
    );
  }
}

/// "ninni" word mark next to the icon.
class NinniWordmark extends StatelessWidget {
  const NinniWordmark({super.key, this.color = NinniColors.ink, this.size = 22});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(size: size * 36 / 22),
        SizedBox(width: size * 10 / 22),
        Text(
          'ninni',
          style: TextStyle(
            fontFamily: NinniType.family,
            fontSize: size,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Twinkling stars behind the night onboarding (V2 §4): 20–30 stars, each
/// with its own phase in a 3 s opacity loop. Static when animations are off.
class Starfield extends StatefulWidget {
  const Starfield({super.key, this.count = 24, this.seed = 7});

  final int count;
  final int seed;

  @override
  State<Starfield> createState() => _StarfieldState();
}

class _StarfieldState extends State<Starfield> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: NinniDurations.twinkle);
  late final List<_Star> _stars = _makeStars();

  List<_Star> _makeStars() {
    final r = math.Random(widget.seed);
    const colors = [NinniColors.white, NinniColors.white, NinniColors.onNightSoft, Color(0xFFFFD2BF)];
    return List.generate(widget.count, (_) {
      return _Star(
        x: r.nextDouble(),
        y: r.nextDouble() * 0.62,
        radius: 1.2 + r.nextDouble() * 1.4,
        phase: r.nextDouble(),
        color: colors[r.nextInt(colors.length)],
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _StarPainter(_stars, _c),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Star {
  const _Star({required this.x, required this.y, required this.radius, required this.phase, required this.color});
  final double x;
  final double y;
  final double radius;
  final double phase;
  final Color color;
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.stars, this.anim) : super(repaint: anim);
  final List<_Star> stars;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in stars) {
      final t = (anim.value + s.phase) % 1.0;
      final opacity = 0.25 + 0.75 * (0.5 - 0.5 * math.cos(t * 2 * math.pi));
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.radius,
        Paint()..color = s.color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => false;
}

/// The onboarding moon: breathes 4 % over 4 s.
class BreathingMoon extends StatefulWidget {
  const BreathingMoon({super.key, this.size = 200});
  final double size;

  @override
  State<BreathingMoon> createState() => _BreathingMoonState();
}

class _BreathingMoonState extends State<BreathingMoon> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: NinniDurations.breathe);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.scale(
        scale: 1 + 0.04 * (0.5 - 0.5 * math.cos(_c.value * 2 * math.pi)),
        child: child,
      ),
      child: AppIcon(
        size: widget.size,
        painter: const AppIconPainter(circleBackground: NinniColors.night800),
      ),
    );
  }
}

/// Waiting indicator: a dot with a ring spreading out (1.6 s).
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, this.color = NinniColors.primaryGlow, this.size = 14});
  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: NinniDurations.pulse);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _c.stop();
      _c.value = 0.3;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return ExcludeSemantics(
      child: SizedBox(
        width: s * 2.2,
        height: s * 2.2,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: s * (1 + 1.2 * t),
                  height: s * (1 + 1.2 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NinniColors.primary.withValues(alpha: 0.35 * (1 - t)),
                  ),
                ),
                Container(
                  width: s * 0.57,
                  height: s * 0.57,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Cry alarm: three rings spreading out from the center (V2 §4).
class AlarmRings extends StatefulWidget {
  const AlarmRings({super.key, required this.child, this.size = 200});
  final Widget child;
  final double size;

  @override
  State<AlarmRings> createState() => _AlarmRingsState();
}

class _AlarmRingsState extends State<AlarmRings> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2100));
  bool _static = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _static = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_static) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final rings = <Widget>[];
          if (_static) {
            rings.addAll([
              _ring(size, NinniColors.apricotRing, 1),
              _ring(size * 0.75, NinniColors.apricotSoftOnNight, 1),
            ]);
          } else {
            for (var i = 0; i < 3; i++) {
              final t = (_c.value + i / 3) % 1.0;
              rings.add(_ring(size * (0.5 + 0.5 * t), NinniColors.apricotSoftOnNight, 1 - t));
            }
          }
          return Stack(alignment: Alignment.center, children: [...rings, child!]);
        },
        child: widget.child,
      ),
    );
  }

  Widget _ring(double d, Color c, double opacity) => Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.withValues(alpha: 0.85 * opacity.clamp(0.0, 1.0)),
        ),
      );
}
