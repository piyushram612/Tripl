import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_state_provider.dart';

class IntentRingGraph extends ConsumerStatefulWidget {
  final double essential;
  final double joyful;
  final double avoidable;
  final double investments;
  final double totalSpent;
  final String currency;

  const IntentRingGraph({
    super.key,
    required this.essential,
    required this.joyful,
    required this.avoidable,
    required this.investments,
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
                  investments: widget.investments,
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
  final double investments;
  final double animationValue;

  // Intent bucket colours
  static const Color _essentialColor = TallyTapTheme.primaryMint;       // Mint
  static const Color _joyfulColor = Color(0xFF9FB6DF);                   // Slate blue
  static const Color _avoidableColor = Color(0xFFFFB5B5);               // Coral pink
  static const Color _investmentsColor = Color(0xFF8B5CF6);             // Royal violet

  _IntentRingPainter({
    required this.essential,
    required this.joyful,
    required this.avoidable,
    required this.investments,
    required this.animationValue,
  });

  Paint _makePaint(Color color, double strokeWidth) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final double total = essential + joyful + avoidable + investments;
    if (total == 0) return;

    final double avoidableAngle  = (avoidable   / total) * 2 * pi;
    final double essentialAngle  = (essential   / total) * 2 * pi;
    final double joyfulAngle     = (joyful      / total) * 2 * pi;
    final double investAngle     = (investments / total) * 2 * pi;

    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    const double strokeWidth = 12.0;

    // Track ring
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      Paint()
        ..color = const Color(0xFF14241F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    final Paint avoidablePaint  = _makePaint(_avoidableColor, strokeWidth);
    final Paint essentialPaint  = _makePaint(_essentialColor, strokeWidth);
    final Paint joyfulPaint     = _makePaint(_joyfulColor, strokeWidth);
    final Paint investmentsPaint = _makePaint(_investmentsColor, strokeWidth);

    double overallSweep = 2 * pi * animationValue;
    double relativeStart = 0.0;
    const double spacing = 0.05;

    void drawSegment(double segAngle, Paint paint) {
      if (segAngle <= 0) return;
      if (overallSweep <= relativeStart) {
        relativeStart += segAngle;
        return;
      }
      final double drawAngle = (overallSweep - relativeStart).clamp(0.0, segAngle);
      if (drawAngle > 0) {
        final double activeSpacing = drawAngle >= segAngle ? spacing : 0.0;
        canvas.drawArc(
          rect,
          -pi / 2 + relativeStart + activeSpacing / 2,
          drawAngle - activeSpacing,
          false,
          paint,
        );
      }
      relativeStart += segAngle;
    }

    // Render order: Avoidable → Essential → Joyful → Investments
    drawSegment(avoidableAngle,  avoidablePaint);
    drawSegment(essentialAngle,  essentialPaint);
    drawSegment(joyfulAngle,     joyfulPaint);
    drawSegment(investAngle,     investmentsPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
