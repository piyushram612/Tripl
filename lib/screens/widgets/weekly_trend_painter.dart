import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_state_provider.dart';

class WeeklyTrendGraph extends ConsumerStatefulWidget {
  final List<double> values;
  final List<String> labels;
  final bool isOverspending;
  final String styleType;
  final String metricMode;
  final bool showGrid;
  final bool showLabels;
  final bool showGradient;
  final bool showGlow;
  final bool showTooltips;
  final String currency;
  
  const WeeklyTrendGraph({
    super.key,
    required this.values,
    required this.labels,
    this.isOverspending = false,
    this.styleType = 'bezier',
    this.metricMode = 'spent',
    this.showGrid = true,
    this.showLabels = true,
    this.showGradient = true,
    this.showGlow = true,
    this.showTooltips = true,
    required this.currency,
  });

  @override
  ConsumerState<WeeklyTrendGraph> createState() => _WeeklyTrendGraphState();
}

class _WeeklyTrendGraphState extends ConsumerState<WeeklyTrendGraph> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  List<double> _sourceValues = [];
  List<double> _targetValues = [];
  int? _draggedIndex;

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
    if (!widget.showTooltips && _draggedIndex != null) {
      _draggedIndex = null;
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

  void _handleTouch(Offset localPosition, double width, {bool isTap = false}) {
    if (widget.values.isEmpty || !widget.showTooltips) return;
    
    double maxVal = widget.values.reduce((a, b) => a > b ? a : b);
    if (widget.metricMode == 'spent' || widget.metricMode == 'income' || widget.metricMode == 'daily') {
      if (maxVal <= 0.0) {
        maxVal = 100.0;
      }
    } else {
      if (maxVal < 0.0) maxVal = 0.0;
    }

    double rightPadding = 0.0;
    if (widget.showLabels) {
      final dummyPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );
      final String maxText = '${maxVal < 0 ? '-' : ''}${widget.currency}${maxVal.abs().toStringAsFixed(0)}';
      dummyPainter.text = TextSpan(
        text: maxText,
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          fontFamily: 'Outfit',
        ),
      );
      dummyPainter.layout();
      rightPadding = dummyPainter.width + 16.0;
    }

    final double graphWidth = width - rightPadding;
    
    final double leftInset;
    final double rightInset;
    if (widget.styleType == 'bar') {
      final double estStepX = graphWidth / (widget.values.length - 1 == 0 ? 1 : widget.values.length - 1);
      final double estBarWidth = (estStepX * 0.55).clamp(4.0, 30.0);
      leftInset = estBarWidth / 2 + 4.0;
      rightInset = estBarWidth / 2 + 4.0;
    } else {
      leftInset = 8.0;
      rightInset = 8.0;
    }

    final double graphWidthForPoints = graphWidth - leftInset - rightInset;
    final double stepX = graphWidthForPoints / (widget.values.length - 1 == 0 ? 1 : widget.values.length - 1);
    final int index = ((localPosition.dx - leftInset) / stepX).round().clamp(0, widget.values.length - 1);
    
    setState(() {
      if (isTap && _draggedIndex == index) {
        _draggedIndex = null;
      } else {
        _draggedIndex = index;
      }
    });
  }

  void _clearTouch() {
    if (_draggedIndex != null) {
      setState(() {
        _draggedIndex = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Clear tooltip if tooltips are disabled or if another screen/route is pushed on top
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    if ((!widget.showTooltips || !isCurrentRoute) && _draggedIndex != null) {
      _draggedIndex = null;
    }

    // Replay entrance animation when switching back to the Home tab,
    // and clear touch tooltips when navigating to a different tab.
    ref.listen<int>(activeTabProvider, (previous, next) {
      if (next == 0) {
        _controller.forward(from: 0.0);
      } else {
        _clearTouch();
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          onPanStart: (details) => _handleTouch(details.localPosition, width, isTap: false),
          onPanUpdate: (details) => _handleTouch(details.localPosition, width, isTap: false),
          onTapDown: (details) => _handleTouch(details.localPosition, width, isTap: true),
          child: AnimatedBuilder(
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
                    styleType: widget.styleType,
                    metricMode: widget.metricMode,
                    showGrid: widget.showGrid,
                    showLabels: widget.showLabels,
                    showGradient: widget.showGradient,
                    showGlow: widget.showGlow,
                    draggedIndex: _draggedIndex,
                    currency: widget.currency,
                  ),
                ),
              );
            },
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
  final String styleType;
  final String metricMode;
  final bool showGrid;
  final bool showLabels;
  final bool showGradient;
  final bool showGlow;
  final int? draggedIndex;
  final String currency;

  _WeeklyTrendPainter({
    required this.values,
    required this.labels,
    required this.isOverspending,
    required this.styleType,
    required this.metricMode,
    required this.showGrid,
    required this.showLabels,
    required this.showGradient,
    required this.showGlow,
    required this.draggedIndex,
    required this.currency,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final width = size.width;
    final height = size.height;
    
    // Bottom padding for text labels
    const double bottomPadding = 24.0;
    final double graphHeight = height - bottomPadding;

    // Normalizing values between min and max height of the graph area
    double maxVal = values.reduce((a, b) => a > b ? a : b);
    double minVal = values.reduce((a, b) => a < b ? a : b);

    if (metricMode == 'spent' || metricMode == 'income' || metricMode == 'daily') {
      minVal = 0.0;
      if (maxVal <= 0.0) {
        maxVal = 100.0; // Default height fallback
      }
    } else {
      // Net mode
      if (minVal > 0.0) minVal = 0.0;
      if (maxVal < 0.0) maxVal = 0.0;
      if (maxVal == minVal) {
        maxVal = 100.0;
        minVal = -100.0;
      }
    }
    final double range = maxVal - minVal;

    double getYForValue(double val) {
      final double normalizedY = (val - minVal) / range;
      // Invert Y since (0,0) is top-left
      return graphHeight - (normalizedY * (graphHeight - 20) + 10);
    }

    double rightPadding = 0.0;
    if (showLabels) {
      final dummyPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );
      final String maxText = '${maxVal < 0 ? '-' : ''}$currency${maxVal.abs().toStringAsFixed(0)}';
      dummyPainter.text = TextSpan(
        text: maxText,
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          fontFamily: 'Outfit',
        ),
      );
      dummyPainter.layout();
      rightPadding = dummyPainter.width + 16.0; // add 16px for padding/safety margin
    }
    final double graphWidth = width - rightPadding;

    final double leftInset;
    final double rightInset;
    if (styleType == 'bar') {
      final double estStepX = graphWidth / (values.length - 1 == 0 ? 1 : values.length - 1);
      final double estBarWidth = (estStepX * 0.55).clamp(4.0, 30.0);
      leftInset = estBarWidth / 2 + 4.0;
      rightInset = estBarWidth / 2 + 4.0;
    } else {
      leftInset = 8.0;
      rightInset = 8.0;
    }

    final double firstX = leftInset;
    final double lastX = graphWidth - rightInset;

    // Grid paint for horizontal helper guidelines
    if (showGrid) {
      final gridPaint = Paint()
        ..color = const Color(0xFF152620)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;
      
      // Draw horizontal grid lines between firstX and lastX
      canvas.drawLine(Offset(firstX, getYForValue(maxVal)), Offset(lastX, getYForValue(maxVal)), gridPaint);
      canvas.drawLine(Offset(firstX, getYForValue((maxVal + minVal) / 2)), Offset(lastX, getYForValue((maxVal + minVal) / 2)), gridPaint);
      canvas.drawLine(Offset(firstX, getYForValue(minVal)), Offset(lastX, getYForValue(minVal)), gridPaint);
    }

    // Draw Y Axis Labels if toggled
    if (showLabels) {
      final labelTextPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );

      void drawYLabel(double val, double y) {
        final String text = '${val < 0 ? '-' : ''}$currency${val.abs().toStringAsFixed(0)}';
        labelTextPainter.text = TextSpan(
          text: text,
          style: const TextStyle(
            color: TallyTapTheme.textGray,
            fontSize: 8,
            fontWeight: FontWeight.w600,
            fontFamily: 'Outfit',
          ),
        );
        labelTextPainter.layout();
        // Paint centered vertically in the right padding area
        labelTextPainter.paint(canvas, Offset(graphWidth + 4, y - labelTextPainter.height / 2));
      }

      drawYLabel(maxVal, getYForValue(maxVal));
      drawYLabel((maxVal + minVal) / 2, getYForValue((maxVal + minVal) / 2));
      drawYLabel(minVal, getYForValue(minVal));
    }

    final double graphWidthForPoints = graphWidth - leftInset - rightInset;
    final double stepX = graphWidthForPoints / (values.length - 1 == 0 ? 1 : values.length - 1);
    final points = <Offset>[];

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < values.length; i++) {
      final double y = getYForValue(values[i]);
      final double x = leftInset + i * stepX;
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
    final Color fillStartColor = isOverspending ? const Color(0xFFEF4444).withValues(alpha: 0.2) : TallyTapTheme.primaryMint.withValues(alpha: 0.25);

    if (styleType == 'bar') {
      // Draw Bar Chart representation
      final double barWidth = (stepX * 0.55).clamp(4.0, 30.0);
      final barPaint = Paint()..style = PaintingStyle.fill;

      for (int i = 0; i < points.length; i++) {
        final pt = points[i];
        final double x = pt.dx;
        final double y = pt.dy;
        
        final double zeroY = getYForValue(0.0);
        final double top = y < zeroY ? y : zeroY;
        final double bottom = y < zeroY ? zeroY : y;
        
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTRB(x - barWidth / 2, top, x + barWidth / 2, bottom),
          const Radius.circular(6),
        );
        
        barPaint.shader = LinearGradient(
          colors: [
            strokeColor,
            strokeColor.withValues(alpha: showGradient ? 0.15 : 0.85),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTRB(x - barWidth / 2, top, x + barWidth / 2, bottom));
        
        canvas.drawRRect(rect, barPaint);
      }
    } else {
      // Draw Line (Bezier / Straight)
      final linePath = Path();
      linePath.moveTo(points.first.dx, points.first.dy);

      final fillPath = Path();
      fillPath.moveTo(points.first.dx, graphHeight);
      fillPath.lineTo(points.first.dx, points.first.dy);

      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        
        if (styleType == 'bezier') {
          final controlX1 = p0.dx + (p1.dx - p0.dx) / 2;
          final controlY1 = p0.dy;
          final controlX2 = p0.dx + (p1.dx - p0.dx) / 2;
          final controlY2 = p1.dy;

          linePath.cubicTo(controlX1, controlY1, controlX2, controlY2, p1.dx, p1.dy);
          fillPath.cubicTo(controlX1, controlY1, controlX2, controlY2, p1.dx, p1.dy);
        } else {
          // straight
          linePath.lineTo(p1.dx, p1.dy);
          fillPath.lineTo(p1.dx, p1.dy);
        }
      }

      fillPath.lineTo(points.last.dx, graphHeight);
      fillPath.close();

      // 1. Draw Gradient Fill beneath the curve
      if (showGradient) {
        final fillPaint = Paint()
          ..shader = LinearGradient(
            colors: [
              fillStartColor,
              strokeColor.withValues(alpha: 0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(points.first.dx, 0, points.last.dx - points.first.dx, graphHeight))
          ..style = PaintingStyle.fill;

        canvas.drawPath(fillPath, fillPaint);
      }

      // 2. Draw Glow Effect
      if (showGlow) {
        final glowPaint = Paint()
          ..color = strokeColor.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
          ..isAntiAlias = true;

        canvas.drawPath(linePath, glowPaint);
      }

      // 3. Draw Path Line
      final linePaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      canvas.drawPath(linePath, linePaint);
    }

    // 4. Draw Interactive Tooltip & Highlight Marker
    if (draggedIndex != null && draggedIndex! < points.length) {
      final selectedPt = points[draggedIndex!];
      
      // Draw vertical tracking guide line
      final verticalLinePaint = Paint()
        ..color = TallyTapTheme.textGray.withValues(alpha: 0.4)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      
      double startY = 10;
      const double dashHeight = 4.0;
      const double dashGap = 4.0;
      while (startY < graphHeight) {
        canvas.drawLine(Offset(selectedPt.dx, startY), Offset(selectedPt.dx, startY + dashHeight), verticalLinePaint);
        startY += dashHeight + dashGap;
      }

      // Draw tracking circle point marker
      final markerPaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.fill;
      
      final markerOutlinePaint = Paint()
        ..color = TallyTapTheme.obsidianCard
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      
      canvas.drawCircle(selectedPt, 6.0, markerPaint);
      canvas.drawCircle(selectedPt, 6.0, markerOutlinePaint);

      // Draw floating overlay tooltip card
      final String dayName = draggedIndex! < labels.length ? labels[draggedIndex!] : '';
      final double val = values[draggedIndex!];
      final String tooltipText = '${dayName.isNotEmpty ? "$dayName: " : ""}${val < 0 ? '-' : ''}$currency${val.abs().toStringAsFixed(0)}';

      final tooltipTextPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );
      tooltipTextPainter.text = TextSpan(
        text: tooltipText,
        style: const TextStyle(
          color: TallyTapTheme.textLight,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: 'Outfit',
        ),
      );
      tooltipTextPainter.layout();

      final double tooltipWidth = tooltipTextPainter.width + 16;
      final double tooltipHeight = tooltipTextPainter.height + 8;
      
      double tooltipX = selectedPt.dx - tooltipWidth / 2;
      if (tooltipX < 4) tooltipX = 4;
      if (tooltipX + tooltipWidth > width - 4) tooltipX = width - tooltipWidth - 4;
      
      double tooltipY = selectedPt.dy - tooltipHeight - 10;
      if (tooltipY < 4) {
        tooltipY = selectedPt.dy + 10; // Draw below point if clipping top
      }

      final tooltipRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tooltipX, tooltipY, tooltipWidth, tooltipHeight),
        const Radius.circular(8),
      );
      
      final tooltipBgPaint = Paint()
        ..color = const Color(0xFF162521)
        ..style = PaintingStyle.fill;
      
      final tooltipBorderPaint = Paint()
        ..color = strokeColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      
      canvas.drawRRect(tooltipRect, tooltipBgPaint);
      canvas.drawRRect(tooltipRect, tooltipBorderPaint);
      
      tooltipTextPainter.paint(
        canvas,
        Offset(tooltipX + 8, tooltipY + 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
