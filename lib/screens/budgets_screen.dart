import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../providers/app_state_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/dashboard_provider.dart';
import '../services/transaction_service.dart';
import 'widgets/dashed_border_container.dart';
import 'sheets/manage_budgets_sheet.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> with SingleTickerProviderStateMixin {
  String? _activeDragCategory;
  Offset _dragStartPos = Offset.zero;
  double _dragStartValue = 0.0;
  final Map<String, double> _localLimits = {};

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

  String _getWeekRangeString() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    final formatter = DateFormat('MMM d');
    return '${formatter.format(startOfWeek)} - ${formatter.format(endOfWeek)}';
  }

  String _getMonthString() {
    return DateFormat('MMMM yyyy').format(DateTime.now());
  }

  void _showManageBudgetsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TallyTapTheme.obsidianBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const ManageBudgetsSheet(),
    );
  }

  IconData _getIconForCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('din') || lower.contains('food')) return Icons.local_dining_rounded;
    if (lower.contains('commute') || lower.contains('trans')) return Icons.directions_transit_rounded;
    if (lower.contains('sub')) return Icons.subscriptions_rounded;
    if (lower.contains('util')) return Icons.bolt_rounded;
    if (lower.contains('groc')) return Icons.shopping_basket_rounded;
    if (lower.contains('shop')) return Icons.shopping_bag_rounded;
    if (lower.contains('health')) return Icons.favorite_rounded;
    if (lower.contains('house') || lower.contains('home')) return Icons.home_rounded;
    if (lower.contains('travel')) return Icons.flight_rounded;
    return Icons.category_rounded;
  }

  Color _getColorForCategory(String category, int index) {
    final lower = category.toLowerCase();
    if (lower.contains('din')) return TallyTapTheme.primaryMint;
    if (lower.contains('commute')) return Colors.orangeAccent;
    if (lower.contains('sub')) return Colors.pinkAccent;
    if (lower.contains('util')) return Colors.lightBlueAccent;
    final palette = [
      TallyTapTheme.primaryViolet,
      Colors.purpleAccent,
      Colors.yellowAccent,
      Colors.tealAccent,
      Colors.deepOrangeAccent,
    ];
    return palette[index % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    // Replay entrance animation when switching to the Budgets tab
    ref.listen<int>(activeTabProvider, (previous, next) {
      if (next == 1) {
        _controller.forward(from: 0.0);
      }
    });

    final globalBudget = ref.watch(globalBudgetProvider);
    final budgetLimits = ref.watch(budgetLimitsProvider);
    final currency = ref.watch(currencyProvider);
    final transactions = ref.watch(transactionListProvider);
    final dashboard = ref.watch(dashboardProvider);
    final spentPerCategory = dashboard.spentPerCategory;

    // Reset/clear local limits when not dragging to keep in sync with provider updates
    if (_activeDragCategory == null) {
      _localLimits.clear();
    }

    final now = DateTime.now();
    
    // Helpers to check period bounds
    bool isDateInCurrentWeek(DateTime date) {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      return date.isAfter(startOfDay.subtract(const Duration(seconds: 1)));
    }

    bool isDateInCurrentMonth(DateTime date) {
      return date.year == now.year && date.month == now.month;
    }

    // Dynamic calculations for BOTH periods independently
    double weeklySpent = 0.0;
    double monthlySpent = 0.0;

    for (var tx in transactions) {
      if (tx.category.toLowerCase() != 'income') {
        if (isDateInCurrentWeek(tx.date)) {
          weeklySpent += tx.amount;
        }
        if (isDateInCurrentMonth(tx.date)) {
          monthlySpent += tx.amount;
        }
      }
    }

    // Overallocation calculation using local limits when dragging, otherwise database limits
    final double totalCategoryBudgets = budgetLimits.entries.fold(0.0, (sum, entry) {
      final cat = entry.key;
      final limit = _localLimits[cat] ?? entry.value;
      return sum + limit;
    });
    final double currentGlobalLimit = globalBudget.amount;
    final bool isOverallocated = totalCategoryBudgets > currentGlobalLimit;
    final double overallocationDelta = totalCategoryBudgets - currentGlobalLimit;

    // Categories list
    final List<String> activeCategories = budgetLimits.keys.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          // Top Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TallyTapTheme.obsidianCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TallyTapTheme.borderGreen),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: TallyTapTheme.primaryMint,
                  size: 20,
                ),
              ),
              const Text(
                'TallyTap',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: TallyTapTheme.textLight,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(width: 38), // To balance the left wallet icon container and keep TallyTap centered
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Budgets Hub',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: TallyTapTheme.primaryMint,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Overview your parameters and adjust allocations directly.',
            style: TextStyle(
              fontSize: 14,
              color: TallyTapTheme.textGray,
            ),
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Double Global Budgets stack at the top
                  const Text(
                    'GLOBAL LIMITS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: TallyTapTheme.textGray,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Horizontally scrollable Global Budgets list
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildGlobalBudgetCard(
                              context: context,
                              title: 'Weekly Budget',
                              spent: weeklySpent,
                              limit: globalBudget.weeklyAmount,
                              period: 'weekly',
                              dateString: _getWeekRangeString(),
                              currency: currency,
                              isActive: globalBudget.period == 'weekly',
                              animationValue: _animation.value,
                              onTap: () {
                                ref.read(globalBudgetProvider.notifier).setPeriod('weekly');
                              },
                            ),
                            const SizedBox(width: 16),
                            _buildGlobalBudgetCard(
                              context: context,
                              title: 'Monthly Budget',
                              spent: monthlySpent,
                              limit: globalBudget.monthlyAmount,
                              period: 'monthly',
                              dateString: _getMonthString(),
                              currency: currency,
                              isActive: globalBudget.period == 'monthly',
                              animationValue: _animation.value,
                              onTap: () {
                                ref.read(globalBudgetProvider.notifier).setPeriod('monthly');
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Shifted Adjust budget limits card above
                  DashedBorderContainer(
                    child: InkWell(
                      onTap: () => _showManageBudgetsSheet(context),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        height: 65,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.tune_rounded, color: TallyTapTheme.primaryMint, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'ADJUST BUDGET LIMITS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: TallyTapTheme.primaryMint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Overallocation Warning Banner
                  if (isOverallocated) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 20.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C1616),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEF4444), width: 1.0),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Category Budgets Overallocated',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: TallyTapTheme.textLight,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'The sum of your category budgets ($currency${totalCategoryBudgets.toStringAsFixed(0)}) exceeds your global limit ($currency${currentGlobalLimit.toStringAsFixed(0)}) by $currency${overallocationDelta.toStringAsFixed(0)}.',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: TallyTapTheme.textGray,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // 2. Category Wise Budgets section displayed directly on screen
                  const Text(
                    'CATEGORIES',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: TallyTapTheme.textGray,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (activeCategories.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Text(
                          'No categories defined. Configure them in Settings!',
                          style: TextStyle(color: TallyTapTheme.textGray, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ...activeCategories.asMap().entries.map((entry) {
                      final index = entry.key;
                      final cat = entry.value;
                      final spent = spentPerCategory[cat] ?? 0.0;
                      final limit = _localLimits[cat] ?? budgetLimits[cat] ?? 500.0;
                      final icon = _getIconForCategory(cat);
                      final color = _getColorForCategory(cat, index);
                      final proportion = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
                      final isDragging = _activeDragCategory == cat;

                      return GestureDetector(
                        onLongPressStart: (details) {
                          HapticFeedback.heavyImpact();
                          setState(() {
                            _activeDragCategory = cat;
                            _dragStartPos = details.globalPosition;
                            _dragStartValue = limit;
                            _localLimits[cat] = limit;
                          });
                        },
                        onLongPressMoveUpdate: (details) {
                          final double deltaX = details.globalPosition.dx - _dragStartPos.dx;
                          double val = _dragStartValue + (deltaX * 5.0);
                          val = val.clamp(0.0, double.infinity);
                          
                          final roundedVal = (val / 10).round() * 10.0;
                          final oldVal = _localLimits[cat] ?? _dragStartValue;
                          if (oldVal != roundedVal) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _localLimits[cat] = roundedVal;
                            });
                          }
                        },
                        onLongPressEnd: (details) {
                          HapticFeedback.mediumImpact();
                          final finalVal = _localLimits[cat] ?? _dragStartValue;
                          ref.read(budgetLimitsProvider.notifier).setLimit(cat, finalVal);
                          setState(() {
                            _activeDragCategory = null;
                          });
                        },
                        child: _buildCategoryBudgetCard(
                          title: cat,
                          spent: spent,
                          limit: limit,
                          icon: icon,
                          proportion: proportion,
                          progressColor: color,
                          currency: currency,
                          isDragging: isDragging,
                        ),
                      );
                    }).toList(),
                    
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBudgetCard({
    required String title,
    required double spent,
    required double limit,
    required IconData icon,
    required double proportion,
    required Color progressColor,
    required String currency,
    required bool isDragging,
  }) {
    final percent = (proportion * 100).toStringAsFixed(0);
    final activeColor = progressColor;

    return Transform.scale(
      scale: isDragging ? 1.04 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDragging ? const Color(0xFF132A22) : TallyTapTheme.obsidianCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDragging ? TallyTapTheme.primaryMint : TallyTapTheme.borderGreen,
            width: isDragging ? 1.5 : 1.0,
          ),
          boxShadow: isDragging
              ? [
                  BoxShadow(
                    color: TallyTapTheme.primaryMint.withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1B17),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: TallyTapTheme.borderGreen, width: 0.5),
                    ),
                    child: Icon(icon, color: TallyTapTheme.primaryMint, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                        ),
                        if (isDragging) ...[
                          const SizedBox(height: 2),
                          const Text(
                            '← Drag left/right to adjust →',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: TallyTapTheme.primaryMint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13221E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$percent%',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: TallyTapTheme.textLight),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$currency${spent.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: TallyTapTheme.textLight),
                  ),
                  Text(
                    '/ $currency${limit.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}',
                    style: const TextStyle(fontSize: 12, color: TallyTapTheme.textGray, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF14241F),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: proportion,
                  child: Container(
                    decoration: BoxDecoration(
                      color: activeColor,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalBudgetCard({
    required BuildContext context,
    required String title,
    required double spent,
    required double limit,
    required String period,
    required String dateString,
    required String currency,
    required bool isActive,
    required double animationValue,
    required VoidCallback onTap,
  }) {
    final double animatedSpent = spent * animationValue;
    final proportion = limit > 0 ? (animatedSpent / limit).clamp(0.0, 1.0) : 0.0;
    final percent = (proportion * 100).toStringAsFixed(0);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.82,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: TallyTapTheme.obsidianCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive ? TallyTapTheme.primaryMint : TallyTapTheme.borderGreen,
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: TallyTapTheme.primaryMint.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Circular progress on the left
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(70, 70),
                    painter: _MiniBudgetRingPainter(proportion: proportion),
                  ),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: TallyTapTheme.textLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Details on the right
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: TallyTapTheme.textGray,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F2B20),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: const Color(0xFF144D37)),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: TallyTapTheme.primaryMint,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateString,
                    style: const TextStyle(
                      fontSize: 11,
                      color: TallyTapTheme.textGray,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$currency${animatedSpent.toStringAsFixed(0)} ',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: TallyTapTheme.textLight,
                          ),
                        ),
                        TextSpan(
                          text: '/ $currency${limit.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: TallyTapTheme.textGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBudgetRingPainter extends CustomPainter {
  final double proportion;

  _MiniBudgetRingPainter({required this.proportion});

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    const double strokeWidth = 8.0;

    final Paint trackPaint = Paint()
      ..color = const Color(0xFF14241F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, trackPaint);

    final Paint progressPaint = Paint()
      ..color = TallyTapTheme.primaryMint
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
