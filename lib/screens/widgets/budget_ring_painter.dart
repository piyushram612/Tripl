import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme.dart';

class BudgetRingGraph extends StatefulWidget {
  final double spent;
  final double limit;
  final String currency;

  const BudgetRingGraph({
    super.key,
    required this.spent,
    required this.limit,
    required this.currency,
  });

  @override
  State<BudgetRingGraph> createState() => _BudgetRingGraphState();
}

class _BudgetRingGraphState extends State<BudgetRingGraph> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double proportion = widget.limit > 0 ? (widget.spent / widget.limit) : 0.0;
    
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
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(140, 140),
                painter: _BudgetRingPainter(proportion: proportion * _animation.value),
              );
            },
          ),
          // Center Text Overlay
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final animatedSpent = widget.spent * _animation.value;
              return Column(
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
                  Builder(
                    builder: (context) {
                      Color spentColor = TallyTapTheme.textLight;
                      if (proportion >= 0.75) {
                        spentColor = const Color(0xFFEF4444);
                      } else if (proportion >= 0.50) {
                        spentColor = const Color(0xFFF59E0B);
                      }
                      return Text(
                        '${widget.currency}${animatedSpent.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                        style: TextStyle(
                          fontSize: 24,
                          color: spentColor,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      );
                    }
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'of ${widget.currency}${widget.limit.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: TallyTapTheme.textGray,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
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

    final Paint trackPaint = Paint()
      ..color = const Color(0xFF14241F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, trackPaint);

    Color progressColor = TallyTapTheme.primaryMint;
    if (proportion >= 0.75) {
      progressColor = const Color(0xFFEF4444);
    } else if (proportion >= 0.50) {
      progressColor = const Color(0xFFF59E0B);
    }

    final Paint progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const double startAngle = -pi / 2;
    final double sweepAngle = proportion * 2 * pi;

    if (sweepAngle > 0) {
      canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
