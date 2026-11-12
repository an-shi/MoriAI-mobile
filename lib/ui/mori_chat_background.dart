import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mori_ai/ui/mori_theme.dart';

/// A very light, hand-drawn leaf/dot wallpaper. It gives the chat a warm,
/// textured feel without competing with message content.
class MoriChatBackground extends StatelessWidget {
  const MoriChatBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.chatPalette;
    return ColoredBox(
      color: palette.background,
      child: CustomPaint(
        painter: _ChatPatternPainter(color: palette.pattern),
        child: child,
      ),
    );
  }
}

class _ChatPatternPainter extends CustomPainter {
  const _ChatPatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05
      ..strokeCap = StrokeCap.round;

    const step = 58.0;
    final rows = (size.height / step).ceil() + 1;
    final cols = (size.width / step).ceil() + 1;
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final x = col * step + (row.isEven ? 18 : 44);
        final y = row * step + 20;
        if (x > size.width + 14 || y > size.height + 14) {
          continue;
        }
        _drawSprig(canvas, paint, Offset(x, y), (row + col) % 3);
      }
    }
  }

  void _drawSprig(Canvas canvas, Paint paint, Offset center, int variant) {
    if (variant == 0) {
      canvas.drawCircle(center, 1.25, paint..style = PaintingStyle.fill);
      paint.style = PaintingStyle.stroke;
      return;
    }

    final path = Path();
    if (variant == 1) {
      path.moveTo(center.dx - 5, center.dy + 4);
      path.quadraticBezierTo(
        center.dx - 1,
        center.dy - 2,
        center.dx + 3,
        center.dy - 6,
      );
      path.moveTo(center.dx - 3.5, center.dy + 0.5);
      path.quadraticBezierTo(
        center.dx - 6.5,
        center.dy - 1,
        center.dx - 6,
        center.dy - 4.5,
      );
      path.moveTo(center.dx - 0.5, center.dy - 2.2);
      path.quadraticBezierTo(
        center.dx + 2.5,
        center.dy - 4.2,
        center.dx + 1.2,
        center.dy - 7,
      );
    } else {
      final angle = (center.dx + center.dy) % math.pi;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      path
        ..moveTo(-5, 0)
        ..quadraticBezierTo(0, -3.2, 5, 0)
        ..quadraticBezierTo(0, 3.2, -5, 0);
      canvas.drawPath(path, paint);
      canvas.restore();
      return;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ChatPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}
