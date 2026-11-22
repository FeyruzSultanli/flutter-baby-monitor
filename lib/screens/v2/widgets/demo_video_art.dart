import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/components/brand.dart';
import '../../../theme/tokens.dart';

/// Calm stand-in for the camera picture in demo / store screenshots
/// (V2 phase 4): a night nursery with a crib and the moon. Never shown in
/// normal use.
class DemoVideoArt extends StatelessWidget {
  const DemoVideoArt({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(painter: _NurseryPainter(), size: Size.infinite),
    );
  }
}

class _NurseryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B2F5E), Color(0xFF1B1D3C)],
        ).createShader(rect),
    );
    // Soft lamp glow
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.3),
      size.shortestSide * 0.55,
      Paint()
        ..shader = RadialGradient(colors: [
          NinniColors.lightAmber.withValues(alpha: 0.28),
          NinniColors.lightAmber.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(
            center: Offset(size.width * 0.78, size.height * 0.3), radius: size.shortestSide * 0.55)),
    );
    // Stars
    final r = math.Random(3);
    final star = Paint()..color = NinniColors.white.withValues(alpha: 0.5);
    for (var i = 0; i < 18; i++) {
      canvas.drawCircle(Offset(r.nextDouble() * size.width, r.nextDouble() * size.height * 0.45), 1 + r.nextDouble(), star);
    }
    // Moon
    final moonSize = size.shortestSide * 0.22;
    canvas.save();
    canvas.translate(size.width * 0.66, size.height * 0.2);
    const AppIconPainter(showBackground: false, crescent: Color(0xFFE9E4F5)).paint(canvas, Size.square(moonSize));
    canvas.restore();
    // Crib
    final w = size.width * 0.56;
    final h = size.height * 0.26;
    final left = (size.width - w) / 2;
    final top = size.height * 0.6;
    final rail = Paint()
      ..color = const Color(0xFF8C8FC4)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(left, top + h * 0.45, w, h * 0.42), const Radius.circular(14)),
      Paint()..color = const Color(0xFF3A3E73),
    );
    canvas.drawLine(Offset(left, top), Offset(left + w, top), rail);
    for (var i = 0; i <= 8; i++) {
      final x = left + w * i / 8;
      canvas.drawLine(Offset(x, top), Offset(x, top + h * 0.5), rail);
    }
    // Sleeping baby (blanket + head)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(left + w * 0.28, top + h * 0.3, w * 0.5, h * 0.26), const Radius.circular(20)),
      Paint()..color = const Color(0xFFFFD2BF),
    );
    canvas.drawCircle(Offset(left + w * 0.24, top + h * 0.4), h * 0.13, Paint()..color = const Color(0xFFF6E3D6));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
