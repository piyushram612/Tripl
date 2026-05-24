import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme.dart';

class BudgetRingGraph extends StatelessWidget {
  final double spent;
  final double limit;

  const BudgetRingGraph({
    super.key,
    required this.spent,
    required this.limit,
  });

  @override
  Widget build(BuildContext context) {
    final double proportion = limit > 0 ? (spent / limit) : 0.0;
    
    return Container(
      width: 170,
      height: 170,
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      padding: const EdgeInsets.all(8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(140, 140),
            painter: _BudgetRingPainter(proportion: proportion),
          ),
          // Center Text Overlay
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'SPENT',
                style: TextStyle(
                  fontSize: 10,
                  color: TallyTapTheme.textGray,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '\$${spent.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                style: const TextStyle(
                  fontSize: 24,
                  color: TallyTapTheme.textLight,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'of \$${limit.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                style: const TextStyle(
                  fontSize: 11,
                  color: TallyTapTheme.textGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetRingPainter extends CustomPainter {
  final double proportion;

  _BudgetRingPainter({required this.proportion});

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    const double strokeWidth = 14.0;

    // 1. Base grey track paint
    final Paint trackPaint = Paint()
      ..color = const Color(0xFF14241F) // Deep obsidian track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, trackPaint);

    // 2. Active green progress arc paint
    final Paint progressPaint = Paint()
      ..color = TallyTapTheme.primaryMint
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round; // Beautiful rounded end caps

    // Start drawing from -pi / 2 (12 o'clock position)
    const double startAngle = -pi / 2;
    // Map proportion to radians
    final double sweepAngle = proportion * 2 * pi;

    if (sweepAngle > 0) {
      canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
