import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_state_provider.dart';

class DonutChartItem {
  final String name;
  final double amount;
  final Color color;

  DonutChartItem({
    required this.name,
    required this.amount,
    required this.color,
  });
}

class DonutChart extends ConsumerStatefulWidget {
  final List<DonutChartItem> categories;
  final String currency;

  const DonutChart({
    super.key,
    required this.categories,
    required this.currency,
  });

  @override
  ConsumerState<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends ConsumerState<DonutChart> with SingleTickerProviderStateMixin {
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
  void didUpdateWidget(DonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_areCategoriesEqual(oldWidget.categories, widget.categories)) {
      _controller.forward(from: 0.0);
    }
  }

  bool _areCategoriesEqual(List<DonutChartItem> a, List<DonutChartItem> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].name != b[i].name || a[i].amount != b[i].amount || a[i].color != b[i].color) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Replay entrance animation when switching back to the Home tab
    ref.listen<int>(activeTabProvider, (previous, next) {
      if (next == 0) {
        _controller.forward(from: 0.0);
      }
    });

    final double total = widget.categories.fold(0.0, (sum, item) => sum + item.amount);

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
                size: const Size(150, 150),
                painter: _DonutChartPainter(
                  categories: widget.categories,
                  animationValue: _animation.value,
                ),
              );
            },
          ),
          // Center content
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final animatedTotal = total * _animation.value;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 12,
                      color: TallyTapTheme.textGray,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.currency}${animatedTotal.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: TallyTapTheme.textLight,
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

class _DonutChartPainter extends CustomPainter {
  final List<DonutChartItem> categories;
  final double animationValue;

  _DonutChartPainter({
    required this.categories,
    required this.animationValue,
  });

  Path getOctagonPath(Size size) {
    final double S = size.width;
    final double c = S * 0.22; // 22% corner cut matches premium mockup exactly
    final path = Path()
      ..moveTo(c, 0)
      ..lineTo(S - c, 0)
      ..lineTo(S, c)
      ..lineTo(S, S - c)
      ..lineTo(S - c, S)
      ..lineTo(c, S)
      ..lineTo(0, S - c)
      ..lineTo(0, c)
      ..close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double total = categories.fold(0.0, (sum, e) => sum + e.amount);

    if (total == 0) {
      final Paint emptyPaint = Paint()
        ..color = const Color(0xFF13221E)
        ..style = PaintingStyle.fill;
      canvas.drawPath(getOctagonPath(size), emptyPaint);

      final Paint holePaint = Paint()
        ..color = const Color(0xFF08100E)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.35, holePaint);
      return;
    }

    canvas.save();
    canvas.clipPath(getOctagonPath(size));

    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double radius = size.width * 1.2;
    final Rect rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    double currentSweep = 2 * pi * animationValue;
    double relativeStart = 0.0;
    const double spacing = 0.04;

    for (final cat in categories) {
      final double relAngle = (cat.amount / total) * 2 * pi;
      if (relAngle > 0) {
        if (currentSweep > relativeStart) {
          final double drawAngle = (currentSweep - relativeStart).clamp(0.0, relAngle);
          
          if (drawAngle > 0) {
            final Paint paint = Paint()
              ..color = cat.color
              ..style = PaintingStyle.fill;

            // Only apply spacing if the segment has fully finished
            final double activeSpacing = drawAngle >= relAngle ? spacing : 0.0;
            final double start = -pi / 2 + relativeStart;
            final slicePath = Path()
              ..moveTo(cx, cy)
              ..arcTo(rect, start + activeSpacing / 2, drawAngle - activeSpacing, false)
              ..lineTo(cx, cy)
              ..close();

            canvas.drawPath(slicePath, paint);
          }
        }
        relativeStart += relAngle;
      }
    }
    canvas.restore();

    final Paint holePaint = Paint()
      ..color = const Color(0xFF08100E)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.35, holePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
