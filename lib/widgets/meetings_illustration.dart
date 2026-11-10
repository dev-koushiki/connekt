import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A creative, modern, and attractive illustration for the Meetings empty state.
/// Features a glowing communication hub, concentric connection orbits,
/// floating glassmorphic feature badges, and ambient sparkling stars.
class MeetingsIllustration extends StatefulWidget {
  final double width;
  final double height;

  const MeetingsIllustration({
    super.key,
    this.width = 300,
    this.height = 230,
  });

  @override
  State<MeetingsIllustration> createState() => _MeetingsIllustrationState();
}

class _MeetingsIllustrationState extends State<MeetingsIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final floatVal = math.sin(_controller.value * math.pi) * 6.0;
        final pulseVal = 1.0 + (math.sin(_controller.value * math.pi) * 0.04);

        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Ambient Background Glow & Geometric Connection Orbit Rings
              CustomPaint(
                size: Size(widget.width, widget.height),
                painter: _OrbitalRingsPainter(pulseFactor: pulseVal),
              ),

              // 2. Center Hero Communication Hub (Glowing Orb)
              Transform.scale(
                scale: pulseVal,
                child: Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF2563EB), // Vibrant Royal Blue
                        Color(0xFF007AFF), // Electric Blue
                        Color(0xFF06B6D4), // Soft Cyan
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.35),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF007AFF).withOpacity(0.4),
                        blurRadius: 28,
                        spreadRadius: 4,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: const Color(0xFF06B6D4).withOpacity(0.25),
                        blurRadius: 45,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Inner light ring
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      // Video Camera Icon
                      const Icon(
                        Icons.videocam_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Floating Creative Satellite Badges
              // Badge A: Top-Right Contact Avatar Bubble
              Positioned(
                top: 24 - floatVal,
                right: 36,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161C2C),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF60A5FA).withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: const Color(0xFF2563EB).withOpacity(0.25),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Color(0xFF93C5FD),
                          size: 20,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF161C2C), width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Badge B: Top-Left "HD Audio Wave" Glass Pill
              Positioned(
                top: 36 + floatVal,
                left: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151A29).withOpacity(0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withOpacity(0.35),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.graphic_eq_rounded,
                        color: Color(0xFF38BDF8),
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'HD Audio',
                        style: TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Badge C: Bottom-Left "Encrypted P2P" Security Pill
              Positioned(
                bottom: 24 - (floatVal * 0.8),
                left: 32,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151A29).withOpacity(0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF818CF8).withOpacity(0.35),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        color: Color(0xFFA5B4FC),
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'End-to-End',
                        style: TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Badge D: Bottom-Right "CONNEKT Video" Capsule
              Positioned(
                bottom: 30 + (floatVal * 0.7),
                right: 26,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151A29).withOpacity(0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF60A5FA).withOpacity(0.35),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF007AFF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Fast Sync',
                        style: TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Ambient Sparkle Crosses (✦)
              Positioned(
                top: 14,
                left: 105,
                child: _buildSparkle(size: 14, color: const Color(0xFF93C5FD)),
              ),
              Positioned(
                top: 60,
                right: 20,
                child: _buildSparkle(size: 10, color: const Color(0xFF60A5FA).withOpacity(0.7)),
              ),
              Positioned(
                bottom: 45,
                left: 18,
                child: _buildSparkle(size: 9, color: const Color(0xFF38BDF8).withOpacity(0.7)),
              ),
              Positioned(
                bottom: 12,
                right: 115,
                child: _buildSparkle(size: 13, color: const Color(0xFF93C5FD)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSparkle({required double size, required Color color}) {
    return Icon(
      Icons.auto_awesome,
      size: size,
      color: color,
    );
  }
}

/// Draws precision geometric orbital rings and a soft radial ambient light
class _OrbitalRingsPainter extends CustomPainter {
  final double pulseFactor;

  _OrbitalRingsPainter({required this.pulseFactor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Soft Ambient Radial Light
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF1E3A8A).withOpacity(0.32 * pulseFactor),
          const Color(0xFF007AFF).withOpacity(0.12 * pulseFactor),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 110));
    canvas.drawCircle(center, 110, glowPaint);

    // 2. Inner Solid Orbit
    final innerOrbitPaint = Paint()
      ..color = const Color(0xFF3B82F6).withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, 64 * pulseFactor, innerOrbitPaint);

    // 3. Middle Dashed Orbit
    final dashedOrbitPaint = Paint()
      ..color = const Color(0xFF60A5FA).withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    _drawDashedCircle(canvas, center, 88, dashedOrbitPaint, dashCount: 36);

    // 4. Outer Delicate Orbit
    final outerOrbitPaint = Paint()
      ..color = const Color(0xFF93C5FD).withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    _drawDashedCircle(canvas, center, 114, outerOrbitPaint, dashCount: 48);

    // 5. Small geometric orbital node dots
    final nodePaint = Paint()
      ..color = const Color(0xFF60A5FA).withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final dot1 = Offset(center.dx + 88 * math.cos(0.8), center.dy + 88 * math.sin(0.8));
    final dot2 = Offset(center.dx + 88 * math.cos(3.6), center.dy + 88 * math.sin(3.6));
    final dot3 = Offset(center.dx + 114 * math.cos(2.1), center.dy + 114 * math.sin(2.1));
    final dot4 = Offset(center.dx + 114 * math.cos(5.2), center.dy + 114 * math.sin(5.2));

    canvas.drawCircle(dot1, 3.0, nodePaint);
    canvas.drawCircle(dot2, 2.5, nodePaint);
    canvas.drawCircle(dot3, 2.5, nodePaint);
    canvas.drawCircle(dot4, 2.5, nodePaint);
  }

  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint, {
    required int dashCount,
  }) {
    final double dashAngle = (2 * math.pi) / dashCount;
    for (int i = 0; i < dashCount; i++) {
      if (i % 2 == 0) {
        final double startAngle = i * dashAngle;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          dashAngle * 0.6,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitalRingsPainter oldDelegate) =>
      oldDelegate.pulseFactor != pulseFactor;
}
