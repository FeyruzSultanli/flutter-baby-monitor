import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';

/// Night sky background for dark screens (V2.1 §4.3): a vertical gradient
/// #1A1D45 → #12142B over the top part and very faint twinkling stars.
/// [starStrength] 1 = normal, ~0.5 on the baby side; 0 = no stars (night
/// mode has none).
class NightSky extends StatelessWidget {
  const NightSky({super.key, required this.child, this.starStrength = 1, this.gradientStop = 0.42, this.seed = 11});

  final Widget child;
  final double starStrength;
  final double gradientStop;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [NinniColors.nightSkyTop, NinniColors.night900],
          stops: [0, gradientStop],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (starStrength > 0)
            Positioned.fill(
              child: _FaintStars(strength: starStrength, seed: seed),
            ),
          child,
        ],
      ),
    );
  }
}

class _FaintStars extends StatefulWidget {
  const _FaintStars({required this.strength, required this.seed});
  final double strength;
  final int seed;

  @override
  State<_FaintStars> createState() => _FaintStarsState();
}

class _FaintStarsState extends State<_FaintStars> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  late final List<(double, double, double, double, Color)> _stars = () {
    final r = math.Random(widget.seed);
    return List.generate(9, (i) {
      return (
        r.nextDouble(),
        0.01 + r.nextDouble() * 0.16, // top band only
        1.0 + r.nextDouble() * 0.6,
        r.nextDouble(),
        i % 4 == 0 ? NinniColors.starWarm : NinniColors.white,
      );
    });
  }();

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
  Widget build(BuildContext context) => ExcludeSemantics(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(painter: _FaintStarPainter(_stars, _c, widget.strength)),
          ),
        ),
      );
}

class _FaintStarPainter extends CustomPainter {
  _FaintStarPainter(this.stars, this.anim, this.strength) : super(repaint: anim);
  final List<(double, double, double, double, Color)> stars;
  final Animation<double> anim;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (x, y, r, phase, color) in stars) {
      final t = (anim.value + phase) % 1.0;
      // Mockup: opacity .15 → .6.
      final o = (0.15 + 0.45 * (0.5 - 0.5 * math.cos(t * 2 * math.pi))) * strength;
      canvas.drawCircle(Offset(x * size.width, y * size.height), r, Paint()..color = color.withValues(alpha: o));
    }
  }

  @override
  bool shouldRepaint(_FaintStarPainter old) => old.strength != strength;
}

/// Home screen night illustration (mockup Home21): stars, a breathing moon
/// with the apricot dot, two slowly drifting clouds, a hill and a cradle.
class HomeIllustration extends StatefulWidget {
  const HomeIllustration({super.key, required this.height});
  final double height;

  @override
  State<HomeIllustration> createState() => _HomeIllustrationState();
}

class _HomeIllustrationState extends State<HomeIllustration> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 9));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _c.stop();
      _c.value = 0.25;
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
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: CustomPaint(painter: _HomePainter(_c)),
        ),
      ),
    );
  }
}

class _HomePainter extends CustomPainter {
  _HomePainter(this.anim) : super(repaint: anim);
  final Animation<double> anim;

  static const _stars = [
    (40.0, 70.0, 2.0, 0.0, NinniColors.white),
    (120.0, 40.0, 1.5, 0.25, NinniColors.white),
    (200.0, 96.0, 2.0, 0.5, NinniColors.starWarm),
    (250.0, 30.0, 1.5, 0.72, NinniColors.white),
    (70.0, 150.0, 1.5, 0.38, NinniColors.onNightSoft),
    (350.0, 150.0, 2.0, 0.12, NinniColors.white),
    (170.0, 20.0, 1.2, 0.6, NinniColors.onNightSoft),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn in the mockup's 390 x 330 space, scaled to the width and
    // anchored at the bottom (the hill and cradle stay on the ground).
    final s = size.width / 390;
    final h = size.height / s;
    canvas.save();
    canvas.scale(s);
    final rect = Rect.fromLTWH(0, 0, 390, h);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [NinniColors.homeSkyTop, NinniColors.night900],
        ).createShader(rect),
    );
    final dy = h - 330; // shift the 330-high scene to the bottom
    final t = anim.value;
    final wave = 0.5 - 0.5 * math.cos(t * 2 * math.pi);

    for (final (x, y, r, phase, color) in _stars) {
      final tt = (t * 3 + phase) % 1.0;
      final o = 0.25 + 0.75 * (0.5 - 0.5 * math.cos(tt * 2 * math.pi));
      canvas.drawCircle(Offset(x, y + dy * 0.4), r, Paint()..color = color.withValues(alpha: o));
    }

    // Moon (breathes 4 %) with the bite and the apricot dot.
    canvas.save();
    final moonC = Offset(300, 70 + dy * 0.4);
    final breathe = 1 + 0.04 * (0.5 - 0.5 * math.cos(t * 2 * math.pi * 2.25));
    canvas.translate(moonC.dx, moonC.dy);
    canvas.scale(breathe);
    canvas.translate(-moonC.dx, -moonC.dy);
    final moon = Path()..addOval(Rect.fromCircle(center: moonC, radius: 40));
    final bite = Path()..addOval(Rect.fromCircle(center: moonC + const Offset(18, -18), radius: 34));
    canvas.drawPath(Path.combine(PathOperation.difference, moon, bite), Paint()..color = NinniColors.cream50);
    canvas.drawCircle(moonC + const Offset(24, -8), 9, Paint()..color = NinniColors.apricot);
    canvas.restore();

    // Clouds drift ±10 px, out of phase.
    void cloud(double cx, double cy, double rx, double ry, double cx2, double cy2, double rx2, double ry2, Color c,
        double shift) {
      final p = Paint()..color = c;
      canvas.drawOval(Rect.fromCenter(center: Offset(cx + shift, cy + dy), width: rx * 2, height: ry * 2), p);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx2 + shift, cy2 + dy), width: rx2 * 2, height: ry2 * 2), p);
    }

    cloud(90, 214, 70, 22, 128, 200, 40, 24, NinniColors.cloudA, 10 * wave);
    cloud(300, 240, 80, 22, 268, 226, 40, 22, NinniColors.cloudB, -10 * wave);

    // Hill.
    final hill = Path()
      ..moveTo(0, 290 + dy)
      ..quadraticBezierTo(100, 250 + dy, 200, 280 + dy)
      ..quadraticBezierTo(300, 310 + dy, 390, 270 + dy)
      ..lineTo(390, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(hill, Paint()..color = NinniColors.hill);

    // Cradle.
    canvas.save();
    canvas.translate(160, 236 + dy);
    final cream = Paint()..color = NinniColors.cream50;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 24, 72, 30), const Radius.circular(10)), cream);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(6, 54, 6, 12), const Radius.circular(3)), cream);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(60, 54, 6, 12), const Radius.circular(3)), cream);
    canvas.drawPath(
      Path()
        ..moveTo(4, 24)
        ..quadraticBezierTo(36, -4, 68, 24),
      Paint()
        ..color = NinniColors.cream50
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(24, 30), 7, Paint()..color = NinniColors.starWarm);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HomePainter old) => false;
}

/// [NightSky] behind menu screens when they are shown in the dark theme
/// (V2.1 §4.3); nothing in the light theme.
class ThemedSky extends StatelessWidget {
  const ThemedSky({super.key, required this.child, this.starStrength = 0.8});
  final Widget child;
  final double starStrength;

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    return night ? NightSky(starStrength: starStrength, child: child) : child;
  }
}
