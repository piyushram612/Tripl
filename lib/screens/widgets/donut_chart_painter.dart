import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme.dart';

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

class DonutChart extends StatelessWidget {
  final List<DonutChartItem> categories;
  final String currency;

  const DonutChart({
    super.key,
    required this.categories,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final double total = categories.fold(0.0, (sum, item) => sum + item.amount);

    return Container(
      width: 170,
      height: 170,
      decoration: const BoxDecoration(
        color: Colors.transparent, // Octagon shape fills the space
      ),
      padding: const EdgeInsets.all(8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(150, 150),
            painter: _DonutChartPainter(categories: categories),
          ),
          // Center content
          Column(
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
                '$currency${total.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}',
                style: const TextStyle(
                  fontSize: 18,
                  color: TallyTapTheme.textLight,
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

class _DonutChartPainter extends CustomPainter {
  final List<DonutChartItem> categories;

  _DonutChartPainter({required this.categories});

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
      // Draw background empty octagon
      final Paint emptyPaint = Paint()
        ..color = const Color(0xFF13221E)
        ..style = PaintingStyle.fill;
      canvas.drawPath(getOctagonPath(size), emptyPaint);

      final Paint holePaint = Paint()
        ..color = const Color(0xFF08100E) // Center hole
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.35, holePaint);
      return;
    }

    // 1. Clip canvas to octagon
    canvas.save();
    canvas.clipPath(getOctagonPath(size));

    // 2. Draw pie slices (expanded beyond bounds to fully fill the corners)
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double radius = size.width * 1.2;
    final Rect rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    double startAngle = -pi / 2;
    const double spacing = 0.04; // Elegant gap between segments

    for (final cat in categories) {
      final double angle = (cat.amount / total) * 2 * pi;
      if (angle > 0) {
        final Paint paint = Paint()
          ..color = cat.color
          ..style = PaintingStyle.fill;

        final slicePath = Path()
          ..moveTo(cx, cy)
          ..arcTo(rect, startAngle + spacing / 2, angle - spacing, false)
          ..lineTo(cx, cy)
          ..close();

        canvas.drawPath(slicePath, paint);
        startAngle += angle;
      }
    }
    canvas.restore();

    // 3. Draw circular donut hole cutout in center
    final Paint holePaint = Paint()
      ..color = const Color(0xFF08100E)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.35, holePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
