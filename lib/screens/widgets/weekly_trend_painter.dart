import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_state_provider.dart';

class WeeklyTrendGraph extends ConsumerStatefulWidget {
  final List<double> values;
  final List<String> labels;
  final bool isOverspending;
  
  const WeeklyTrendGraph({
    super.key,
    required this.values,
    required this.labels,
    this.isOverspending = false,
  });

  @override
  ConsumerState<WeeklyTrendGraph> createState() => _WeeklyTrendGraphState();
}

class _WeeklyTrendGraphState extends ConsumerState<WeeklyTrendGraph> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  List<double> _sourceValues = [];
  List<double> _targetValues = [];

  @override
  void initState() {
    super.initState();
    _sourceValues = List.from(widget.values);
    _targetValues = List.from(widget.values);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(WeeklyTrendGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_areListsEqual(oldWidget.values, widget.values)) {
      _sourceValues = _getCurrentAnimatedValues();
      _targetValues = List.from(widget.values);
      _controller.forward(from: 0.0);
    }
  }

  bool _areListsEqual(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  List<double> _getCurrentAnimatedValues() {
    final t = _animation.value;
    if (t == 1.0) return List.from(_targetValues);
    if (t == 0.0) return List.from(_sourceValues);

    final M = _targetValues.length;
    final N = _sourceValues.length;
    if (N == 0) return List.from(_targetValues);

    final result = <double>[];
    for (int i = 0; i < M; i++) {
      double prevIndexFraction = N == 1 ? 0.0 : i * (N - 1) / (M - 1 == 0 ? 1 : M - 1);
      int idx1 = prevIndexFraction.floor().clamp(0, N - 1);
      int idx2 = prevIndexFraction.ceil().clamp(0, N - 1);
      double tIndex = prevIndexFraction - idx1;
      double prevVal = _sourceValues[idx1] + (_sourceValues[idx2] - _sourceValues[idx1]) * tIndex;
      double targetVal = _targetValues[i];
      result.add(prevVal + (targetVal - prevVal) * t);
    }
    return result;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Replay entrance animation when switching back to the Home tab
    ref.listen<int>(activeTabProvider, (previous, next) {
      if (next == 0) {
        _controller.forward(from: 0.0);
      }
    });

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final animatedValues = _getCurrentAnimatedValues();
        return SizedBox(
          height: 110, // Expanded height to comfortably accommodate visual Day labels
          width: double.infinity,
          child: CustomPaint(
            painter: _WeeklyTrendPainter(
              values: animatedValues,
              labels: widget.labels,
              isOverspending: widget.isOverspending,
            ),
          ),
        );
      },
    );
  }
}

class _WeeklyTrendPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final bool isOverspending;

  _WeeklyTrendPainter({
    required this.values,
    required this.labels,
    required this.isOverspending,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final width = size.width;
    final height = size.height;
    
    // Bottom padding for text labels
    const double bottomPadding = 24.0;
    final double graphHeight = height - bottomPadding;

    // Grid paint for horizontal helper guidelines
    final gridPaint = Paint()
      ..color = const Color(0xFF152620)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    
    // Draw horizontal grid lines for professional reference
    canvas.drawLine(Offset(0, graphHeight * 0.3), Offset(width, graphHeight * 0.3), gridPaint);
    canvas.drawLine(Offset(0, graphHeight * 0.7), Offset(width, graphHeight * 0.7), gridPaint);

    // Normalizing values between min and max height of the graph area
    final double maxVal = values.reduce((a, b) => a > b ? a : b);
    final double minVal = values.reduce((a, b) => a < b ? a : b);
    final double range = maxVal - minVal == 0 ? 1 : maxVal - minVal;

    final double stepX = width / (values.length - 1 == 0 ? 1 : values.length - 1);
    final points = <Offset>[];

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < values.length; i++) {
      final double normalizedY = maxVal - minVal == 0 ? 0.5 : (values[i] - minVal) / range;
      // Invert Y since (0,0) is top-left
      final double y = graphHeight - (normalizedY * (graphHeight - 20) + 10);
      final double x = i * stepX;
      points.add(Offset(x, y));

      // Draw day labels if not empty
      if (i < labels.length && labels[i].isNotEmpty) {
        textPainter.text = TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: TallyTapTheme.textGray,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            fontFamily: 'Outfit',
          ),
        );
        textPainter.layout();
        // Center the label text under each data point X coordinate
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, height - 16));
      }
    }

    // Determine curve and gradient colors based on overspending status (Mint Green vs Vibrant Red)
    final Color strokeColor = isOverspending ? const Color(0xFFEF4444) : TallyTapTheme.primaryMint;
    final Color fillStartColor = isOverspending ? const Color(0xFFEF4444).withOpacity(0.2) : TallyTapTheme.primaryMint.withOpacity(0.25);

    // 1. Draw Gradient Fill beneath the curve
    final fillPath = Path();
    fillPath.moveTo(0, graphHeight);
    fillPath.lineTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      
      final controlX1 = p0.dx + (p1.dx - p0.dx) / 2;
      final controlY1 = p0.dy;
      final controlX2 = p0.dx + (p1.dx - p0.dx) / 2;
      final controlY2 = p1.dy;

      fillPath.cubicTo(controlX1, controlY1, controlX2, controlY2, p1.dx, p1.dy);
    }
    fillPath.lineTo(width, graphHeight);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          fillStartColor,
          strokeColor.withOpacity(0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, width, graphHeight))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // 2. Draw Bezier Line
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      
      final controlX1 = p0.dx + (p1.dx - p0.dx) / 2;
      final controlY1 = p0.dy;
      final controlX2 = p0.dx + (p1.dx - p0.dx) / 2;
      final controlY2 = p1.dy;

      linePath.cubicTo(controlX1, controlY1, controlX2, controlY2, p1.dx, p1.dy);
    }

    final linePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Dotted/Blurred glow effect using mask filter
    final glowPaint = Paint()
      ..color = strokeColor.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
      ..isAntiAlias = true;

    canvas.drawPath(linePath, glowPaint);
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
