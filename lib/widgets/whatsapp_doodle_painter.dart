import 'dart:math' as math;
import 'package:flutter/material.dart';

/// WhatsApp Authentic Vector Doodle Background Painter
/// Procedurally renders charming repeated chat glyphs (chat, coffee, music, camera, heart, plane, etc.)
class WhatsAppDoodlePainter extends CustomPainter {
  final Color color;
  final double opacity;
  final double scale;

  WhatsAppDoodlePainter({
    this.color = Colors.white,
    this.opacity = 0.12,
    this.scale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.4)
      ..style = PaintingStyle.fill;

    const double stepX = 85.0;
    const double stepY = 85.0;

    int cols = (size.width / stepX).ceil() + 1;
    int rows = (size.height / stepY).ceil() + 1;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final x = c * stepX + ((r % 2 == 1) ? stepX / 2 : 0.0);
        final y = r * stepY;

        // Skip if outside canvas
        if (x < -20 || x > size.width + 20 || y < -20 || y > size.height + 20) continue;

        final itemIndex = (r * 7 + c * 3) % 12;

        canvas.save();
        canvas.translate(x, y);
        // Subtle natural rotation for playful doodle aesthetic
        final angle = (((r + c) % 5) - 2) * 0.08;
        canvas.rotate(angle);
        canvas.scale(scale);

        _drawGlyph(canvas, paint, fillPaint, itemIndex);
        canvas.restore();
      }
    }
  }

  void _drawGlyph(Canvas canvas, Paint stroke, Paint fill, int index) {
    switch (index) {
      case 0:
        // Chat bubble
        final rrect = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-10, -8, 20, 15),
          const Radius.circular(5),
        );
        canvas.drawRRect(rrect, stroke);
        final tail = Path()
          ..moveTo(-5, 7)
          ..lineTo(-8, 11)
          ..lineTo(-1, 7);
        canvas.drawPath(tail, stroke);
        break;

      case 1:
        // Heart
        final heart = Path()
          ..moveTo(0, 3)
          ..cubicTo(-6, -6, -11, 2, 0, 10)
          ..cubicTo(11, 2, 6, -6, 0, 3);
        canvas.drawPath(heart, stroke);
        break;

      case 2:
        // Musical note
        canvas.drawCircle(const Offset(-4, 5), 3, stroke);
        canvas.drawCircle(const Offset(4, 3), 3, stroke);
        canvas.drawLine(const Offset(-1, 5), const Offset(-1, -7), stroke);
        canvas.drawLine(const Offset(7, 3), const Offset(7, -9), stroke);
        canvas.drawLine(const Offset(-1, -7), const Offset(7, -9), stroke);
        break;

      case 3:
        // Camera
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -6, 20, 14), const Radius.circular(3)),
          stroke,
        );
        canvas.drawCircle(const Offset(0, 1), 3.5, stroke);
        canvas.drawRect(const Rect.fromLTWH(-4, -9, 8, 3), stroke);
        break;

      case 4:
        // Coffee mug
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-7, -6, 14, 14), const Radius.circular(3)),
          stroke,
        );
        // Mug handle
        final handle = Path()
          ..moveTo(7, -3)
          ..cubicTo(11, -3, 11, 3, 7, 3);
        canvas.drawPath(handle, stroke);
        // Steam
        canvas.drawLine(const Offset(-3, -8), const Offset(-3, -11), stroke);
        canvas.drawLine(const Offset(2, -8), const Offset(2, -11), stroke);
        break;

      case 5:
        // Star
        _drawStar(canvas, stroke, 0, 0, 5, 8, 4);
        break;

      case 6:
        // Paper airplane
        final plane = Path()
          ..moveTo(-10, 8)
          ..lineTo(10, 0)
          ..lineTo(-10, -8)
          ..lineTo(-5, 0)
          ..close();
        canvas.drawPath(plane, stroke);
        canvas.drawLine(const Offset(-5, 0), const Offset(10, 0), stroke);
        break;

      case 7:
        // Headphones
        final arch = Path()
          ..moveTo(-8, 4)
          ..cubicTo(-8, -8, 8, -8, 8, 4);
        canvas.drawPath(arch, stroke);
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-11, 2, 4, 7), const Radius.circular(2)),
          stroke,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(7, 2, 4, 7), const Radius.circular(2)),
          stroke,
        );
        break;

      case 8:
        // Clock
        canvas.drawCircle(Offset.zero, 8, stroke);
        canvas.drawLine(Offset.zero, const Offset(0, -4), stroke);
        canvas.drawLine(Offset.zero, const Offset(3, 0), stroke);
        break;

      case 9:
        // Smiley Face
        canvas.drawCircle(Offset.zero, 8, stroke);
        canvas.drawCircle(const Offset(-3, -2), 1, fill);
        canvas.drawCircle(const Offset(3, -2), 1, fill);
        final smile = Path()
          ..moveTo(-4, 2)
          ..quadraticBezierTo(0, 5, 4, 2);
        canvas.drawPath(smile, stroke);
        break;

      case 10:
        // Phone receiver
        final phone = Path()
          ..moveTo(-6, -6)
          ..lineTo(-3, -8)
          ..lineTo(-1, -4)
          ..lineTo(-3, -2)
          ..cubicTo(-1, 2, 2, 5, 6, 7)
          ..lineTo(8, 5)
          ..lineTo(11, 7)
          ..lineTo(8, 10)
          ..cubicTo(2, 8, -4, 2, -6, -6);
        canvas.drawPath(phone, stroke);
        break;

      case 11:
      default:
        // Planet / Saturn ring
        canvas.drawCircle(Offset.zero, 5, stroke);
        final ring = Path()
          ..moveTo(-10, 2)
          ..cubicTo(-7, -4, 7, -4, 10, -2)
          ..cubicTo(7, 4, -7, 4, -10, 2);
        canvas.drawPath(ring, stroke);
        break;
    }
  }

  void _drawStar(Canvas canvas, Paint paint, double cx, double cy, int spikes, double outerRadius, double innerRadius) {
    double rot = math.pi / 2 * 3;
    double x = cx;
    double y = cy;
    double step = math.pi / spikes;

    final path = Path();
    path.moveTo(cx, cy - outerRadius);
    for (int i = 0; i < spikes; i++) {
      x = cx + math.cos(rot) * outerRadius;
      y = cy + math.sin(rot) * outerRadius;
      path.lineTo(x, y);
      rot += step;

      x = cx + math.cos(rot) * innerRadius;
      y = cy + math.sin(rot) * innerRadius;
      path.lineTo(x, y);
      rot += step;
    }
    path.lineTo(cx, cy - outerRadius);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WhatsAppDoodlePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.opacity != opacity ||
        oldDelegate.scale != scale;
  }
}

/// Widget helper to layer the WhatsApp vector doodle over any child
class WhatsAppDoodleBackground extends StatelessWidget {
  final Widget? child;
  final Color color;
  final double opacity;
  final double scale;

  const WhatsAppDoodleBackground({
    super.key,
    this.child,
    this.color = Colors.white,
    this.opacity = 0.10,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: WhatsAppDoodlePainter(
        color: color,
        opacity: opacity,
        scale: scale,
      ),
      child: child,
    );
  }
}
