import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_state_provider.dart';

class IntentRingGraph extends ConsumerStatefulWidget {
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
  ConsumerState<IntentRingGraph> createState() => _IntentRingGraphState();
}

class _IntentRingGraphState extends ConsumerState<IntentRingGraph> with SingleTickerProviderStateMixin {
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
    // Replay entrance animation when switching to the Insights tab
    ref.listen<int>(activeTabProvider, (previous, next) {
      if (next == 2) {
        _controller.forward(from: 0.0);
      }
    });

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
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(160, 160),
                painter: _IntentRingPainter(
                  essential: widget.essential,
                  joyful: widget.joyful,
                  avoidable: widget.avoidable,
                  animationValue: _animation.value,
                ),
              );
            },
          ),
          // Center Text
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final animatedTotal = widget.totalSpent * _animation.value;
              return Column(
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
                    '${widget.currency}${animatedTotal.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                    style: const TextStyle(
                      fontSize: 26,
                      color: TallyTapTheme.primaryMint,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
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

class _IntentRingPainter extends CustomPainter {
  final double essential;
  final double joyful;
  final double avoidable;
  final double animationValue;

  _IntentRingPainter({
    required this.essential,
    required this.joyful,
    required this.avoidable,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double total = essential + joyful + avoidable;
    if (total == 0) return;

    final double essentialAngle = (essential / total) * 2 * pi;
    final double joyfulAngle = (joyful / total) * 2 * pi;
    final double avoidableAngle = (avoidable / total) * 2 * pi;

    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    const double strokeWidth = 12.0;

    final Paint trackPaint = Paint()
      ..color = const Color(0xFF14241F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, trackPaint);

    final Paint essentialPaint = Paint()
      ..color = TallyTapTheme.primaryMint
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final Paint joyfulPaint = Paint()
      ..color = const Color(0xFF4B5E55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final Paint avoidablePaint = Paint()
      ..color = const Color(0xFFFFB5B5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    double overallSweep = 2 * pi * animationValue;
    double relativeStart = 0.0;
    const double spacing = 0.05;

    // 1. Avoidable Segment (Coral Pink)
    if (avoidableAngle > 0) {
      if (overallSweep > relativeStart) {
        final double drawAngle = (overallSweep - relativeStart).clamp(0.0, avoidableAngle);
        if (drawAngle > 0) {
          final double activeSpacing = drawAngle >= avoidableAngle ? spacing : 0.0;
          canvas.drawArc(
            rect,
            -pi / 2 + relativeStart + activeSpacing / 2,
            drawAngle - activeSpacing,
            false,
            avoidablePaint,
          );
        }
      }
      relativeStart += avoidableAngle;
    }

    // 2. Essential Segment (Mint Green)
    if (essentialAngle > 0) {
      if (overallSweep > relativeStart) {
        final double drawAngle = (overallSweep - relativeStart).clamp(0.0, essentialAngle);
        if (drawAngle > 0) {
          final double activeSpacing = drawAngle >= essentialAngle ? spacing : 0.0;
          canvas.drawArc(
            rect,
            -pi / 2 + relativeStart + activeSpacing / 2,
            drawAngle - activeSpacing,
            false,
            essentialPaint,
          );
        }
      }
      relativeStart += essentialAngle;
    }

    // 3. Joyful Segment (Slate Green)
    if (joyfulAngle > 0) {
      if (overallSweep > relativeStart) {
        final double drawAngle = (overallSweep - relativeStart).clamp(0.0, joyfulAngle);
        if (drawAngle > 0) {
          final double activeSpacing = drawAngle >= joyfulAngle ? spacing : 0.0;
          canvas.drawArc(
            rect,
            -pi / 2 + relativeStart + activeSpacing / 2,
            drawAngle - activeSpacing,
            false,
            joyfulPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
