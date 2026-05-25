import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../providers/category_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/dashboard_provider.dart';
import 'widgets/budget_ring_painter.dart';
import 'widgets/dashed_border_container.dart';
import 'sheets/manage_budgets_sheet.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesListProvider);
    final budgetLimits = ref.watch(budgetLimitsProvider);
    final globalBudget = ref.watch(globalBudgetProvider);
    final currency = ref.watch(currencyProvider);
    final dashboard = ref.watch(dashboardProvider);

    final totalSpent = dashboard.totalSpent;
    final spentPerCategory = dashboard.spentPerCategory;

    final double overallProportion = globalBudget.amount > 0 ? (totalSpent / globalBudget.amount) : 0.0;
    final String percentText = '${(overallProportion * 100).toStringAsFixed(0)}%';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: TallyTapTheme.borderGreen, width: 1.5),
                  image: const DecorationImage(
                    image: NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&auto=format&fit=crop&q=80'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            globalBudget.period == 'weekly' ? 'Weekly Budgets' : 'Monthly Budgets',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: TallyTapTheme.primaryMint,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Track your spending across categories.',
            style: TextStyle(
              fontSize: 14,
              color: TallyTapTheme.textGray,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: TallyTapTheme.obsidianCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TallyTapTheme.borderGreen),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chevron_left_rounded, color: TallyTapTheme.textGray, size: 18),
                    const SizedBox(width: 12),
                    Text(
                      globalBudget.period == 'weekly' ? _getWeekRangeString() : _getMonthString(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: TallyTapTheme.textLight,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.chevron_right_rounded, color: TallyTapTheme.textGray, size: 18),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          BudgetRingGraph(spent: totalSpent, limit: globalBudget.amount, currency: currency),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.circle, color: TallyTapTheme.primaryMint, size: 8),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Global ${globalBudget.period == 'monthly' ? 'Monthly' : 'Weekly'} Budget',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                                  ),
                                ],
                              ),
                              Text(
                                percentText,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
                              ),
                            ],
                          ),
                          const Divider(color: TallyTapTheme.borderGreen, height: 24, thickness: 0.5),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 13, color: TallyTapTheme.textLight, height: 1.4),
                              children: [
                                TextSpan(text: "You are pacing well within your global $currency${globalBudget.amount.toStringAsFixed(0)} ${globalBudget.period} limit. Adjust settings in the "),
                                const TextSpan(
                                  text: "Manage Limits",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: TallyTapTheme.primaryMint),
                                ),
                                const TextSpan(text: " panel below."),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            onPressed: () => _showManageBudgetsSheet(context),
                            icon: const Icon(Icons.tune_rounded, color: TallyTapTheme.primaryMint, size: 16),
                            label: const Text(
                              'Manage Limits',
                              style: TextStyle(color: TallyTapTheme.primaryMint, fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: TallyTapTheme.borderGreen),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: TallyTapTheme.textLight,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...categories.asMap().entries.map((entry) {
                    final index = entry.key;
                    final cat = entry.value;
                    final spent = spentPerCategory[cat] ?? 0.0;
                    final limit = budgetLimits[cat] ?? 500.0;
                    final icon = _getIconForCategory(cat);
                    final color = _getColorForCategory(cat, index);
                    final proportion = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;

                    return _buildCategoryBudgetCard(
                      title: cat,
                      spent: spent,
                      limit: limit,
                      icon: icon,
                      proportion: proportion,
                      progressColor: color,
                      currency: currency,
                    );
                  }).toList(),
                  DashedBorderContainer(
                    child: InkWell(
                      onTap: () => _showManageBudgetsSheet(context),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        height: 90,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_circle_outline_rounded, color: TallyTapTheme.textGray, size: 24),
                            SizedBox(height: 8),
                            Text(
                              'ADJUST BUDGETS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: TallyTapTheme.textGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
  }) {
    final percent = (proportion * 100).toStringAsFixed(0);
    final activeColor = progressColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TallyTapTheme.textLight),
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
                widthFactor: proportion > 1.0 ? 1.0 : proportion,
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
    );
  }
}
