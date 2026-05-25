import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme.dart';

class IntentRingGraph extends StatelessWidget {
  final double essential;
  final double joyful;
  final double avoidable;
  final double totalSpent;
  final String currency;

  const IntentRingGraph({
    super.key,
    required this.essential,
    required this.joyful,
    required this.avoidable,
    required this.totalSpent,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      height: 190,
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      padding: const EdgeInsets.all(8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(160, 160),
            painter: _IntentRingPainter(
              essential: essential,
              joyful: joyful,
              avoidable: avoidable,
            ),
          ),
          // Center Text
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'TOTAL SPENT',
                style: TextStyle(
                  fontSize: 10,
                  color: TallyTapTheme.textGray,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$currency${totalSpent.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                style: const TextStyle(
                  fontSize: 26,
                  color: TallyTapTheme.primaryMint,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IntentRingPainter extends CustomPainter {
  final double essential;
  final double joyful;
  final double avoidable;

  _IntentRingPainter({
    required this.essential,
    required this.joyful,
    required this.avoidable,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double total = essential + joyful + avoidable;
    if (total == 0) return;

    final double essentialAngle = (essential / total) * 2 * pi;
    final double joyfulAngle = (joyful / total) * 2 * pi;
    final double avoidableAngle = (avoidable / total) * 2 * pi;

    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    const double strokeWidth = 12.0; // Sleek thin ring matching mockup

    // Base background ring track
    final Paint trackPaint = Paint()
      ..color = const Color(0xFF14241F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, trackPaint);

    // Segment Paints
    final Paint essentialPaint = Paint()
      ..color = TallyTapTheme.primaryMint
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final Paint joyfulPaint = Paint()
      ..color = const Color(0xFF4B5E55) // Joyful premium gray-slate green
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final Paint avoidablePaint = Paint()
      ..color = const Color(0xFFFFB5B5) // Avoidable coral pink
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Start drawing from -pi/2 + spacer (12 o'clock position)
    double startAngle = -pi / 2;

    // Spacer angle to separate the segments premium style
    const double spacing = 0.05;

    // 1. Avoidable Segment (Top-Left)
    if (avoidableAngle > 0) {
      canvas.drawArc(
        rect,
        startAngle + spacing / 2,
        avoidableAngle - spacing,
        false,
        avoidablePaint,
      );
      startAngle += avoidableAngle;
    }

    // 2. Essential Segment (Vibrant Right and Bottom)
    if (essentialAngle > 0) {
      canvas.drawArc(
        rect,
        startAngle + spacing / 2,
        essentialAngle - spacing,
        false,
        essentialPaint,
      );
      startAngle += essentialAngle;
    }

    // 3. Joyful Segment (Left side)
    if (joyfulAngle > 0) {
      canvas.drawArc(
        rect,
        startAngle + spacing / 2,
        joyfulAngle - spacing,
        false,
        joyfulPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
