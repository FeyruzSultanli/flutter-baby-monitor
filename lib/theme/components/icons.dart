import 'package:flutter/material.dart';

/// The bassinet from the mockups (24×24 stroke icon): basin with posts,
/// legs and the baby's head. Material has no matching glyph.
class BassinetIcon extends StatelessWidget {
  const BassinetIcon({super.key, this.size = 24, this.color, this.strokeWidth = 1.6});

  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Colors.white;
    return ExcludeSemantics(
      child: CustomPaint(size: Size.square(size), painter: _BassinetPainter(c, strokeWidth)),
    );
  }
}

class _BassinetPainter extends CustomPainter {
  _BassinetPainter(this.color, this.strokeWidth);
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.scale(s);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Basin: M3 11h18v4a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4z
    final basin = Path()
      ..moveTo(3, 11)
      ..lineTo(21, 11)
      ..lineTo(21, 15)
      ..arcToPoint(const Offset(17, 19), radius: const Radius.circular(4))
      ..lineTo(7, 19)
      ..arcToPoint(const Offset(3, 15), radius: const Radius.circular(4))
      ..close();
    canvas.drawPath(basin, paint);
    canvas.drawLine(const Offset(3, 11), const Offset(3, 7), paint);
    canvas.drawLine(const Offset(21, 11), const Offset(21, 7), paint);
    canvas.drawLine(const Offset(7, 19), const Offset(6, 21), paint);
    canvas.drawLine(const Offset(17, 19), const Offset(18, 21), paint);
    canvas.drawCircle(const Offset(9, 8), 2, paint);
  }

  @override
  bool shouldRepaint(_BassinetPainter old) => old.color != color || old.strokeWidth != strokeWidth;
}
