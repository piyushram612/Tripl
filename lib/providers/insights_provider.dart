import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/transaction_service.dart';
import 'budget_provider.dart';
import 'category_provider.dart';

class CategoryBreakdownEntry {
  final String category;
  final double spent;
  final double limit;
  final double proportion;
  final String percentOfTotal;

  CategoryBreakdownEntry({
    required this.category,
    required this.spent,
    required this.limit,
    required this.proportion,
    required this.percentOfTotal,
  });
}

class InsightsState {
  // ── Intent buckets ──────────────────────────────────────────────────────────
  final double essential;
  final double joyful;
  final double avoidable;
  final double investments;
  final double totalSpent;

  final String essentialPercent;
  final String joyfulPercent;
  final String avoidablePercent;
  final String investmentsPercent;

  // ── 50/30/20 style splits (actuals) ─────────────────────────────────────────
  /// needs = essential
  final double needsActual;
  /// wants = joyful + avoidable
  final double wantsActual;
  /// savings = investments
  final double savingsActual;

  // ── Dynamic category breakdowns ─────────────────────────────────────────────
  final List<CategoryBreakdownEntry> categoryBreakdowns;

  InsightsState({
    required this.essential,
    required this.joyful,
    required this.avoidable,
    required this.investments,
    required this.totalSpent,
    required this.essentialPercent,
    required this.joyfulPercent,
    required this.avoidablePercent,
    required this.investmentsPercent,
    required this.needsActual,
    required this.wantsActual,
    required this.savingsActual,
    required this.categoryBreakdowns,
  });
}

class InsightsPeriodFilter {
  final String label;
  final DateTime? start;
  final DateTime? end;

  const InsightsPeriodFilter({
    required this.label,
    this.start,
    this.end,
  });
}

class InsightsPeriodFilterNotifier extends StateNotifier<InsightsPeriodFilter> {
  InsightsPeriodFilterNotifier() : super(_getThisMonthFilter());

  static InsightsPeriodFilter _getThisMonthFilter() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1));
    return InsightsPeriodFilter(label: 'This Month', start: start, end: end);
  }

  void setThisMonth() => state = _getThisMonthFilter();

  void setLastMonth() {
    final now = DateTime.now();
    // Handle year boundary
    final lastMonthYear = now.month == 1 ? now.year - 1 : now.year;
    final lastMonthVal = now.month == 1 ? 12 : now.month - 1;
    final start = DateTime(lastMonthYear, lastMonthVal, 1);
    final end = DateTime(now.year, now.month, 1).subtract(const Duration(seconds: 1));
    state = InsightsPeriodFilter(label: 'Last Month', start: start, end: end);
  }

  void setLast30Days() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    state = InsightsPeriodFilter(label: 'Last 30 Days', start: start, end: now);
  }

  void setLast90Days() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 90));
    state = InsightsPeriodFilter(label: 'Last 90 Days', start: start, end: now);
  }

  void setAllTime() {
    state = const InsightsPeriodFilter(label: 'All Time');
  }

  void setCustomMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1).subtract(const Duration(seconds: 1));
    final label = DateFormat('MMMM yyyy').format(month);
    state = InsightsPeriodFilter(label: label, start: start, end: end);
  }

  void setCustomRange(DateTime start, DateTime end) {
    final label = '${DateFormat('MMM d, yyyy').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}';
    state = InsightsPeriodFilter(label: label, start: start, end: end);
  }
}

final insightsPeriodFilterProvider = StateNotifierProvider<InsightsPeriodFilterNotifier, InsightsPeriodFilter>((ref) {
  return InsightsPeriodFilterNotifier();
});

final availableMonthsProvider = Provider<List<DateTime>>((ref) {
  final transactions = ref.watch(transactionListProvider);
  final Set<String> uniqueKeys = {};
  final List<DateTime> months = [];
  
  for (var tx in transactions) {
    final date = tx.date;
    final key = "${date.year}-${date.month}";
    if (!uniqueKeys.contains(key)) {
      uniqueKeys.add(key);
      months.add(DateTime(date.year, date.month));
    }
  }
  
  months.sort((a, b) => b.compareTo(a)); // Newest first
  return months;
});

final insightsProvider = Provider<InsightsState>((ref) {
  final transactions = ref.watch(transactionListProvider);
  final budgetLimits = ref.watch(budgetLimitsProvider);
  final intentMap = ref.watch(categoryIntentsProvider);
  final filter = ref.watch(insightsPeriodFilterProvider);
  final categories = ref.watch(categoriesListProvider);

  double essential = 0.0;
  double joyful = 0.0;
  double avoidable = 0.0;
  double investments = 0.0;

  final Map<String, double> categorySpent = {};

  for (var tx in transactions) {
    final clean = tx.category.trim();
    if (clean.toLowerCase() == 'income') continue;

    // Filter by date!
    if (filter.start != null && tx.date.isBefore(filter.start!)) continue;
    if (filter.end != null && tx.date.isAfter(filter.end!)) continue;

    final amount = tx.amount.abs();
    final intent = intentMap[clean] ?? CategoryIntent.essential;

    switch (intent) {
      case CategoryIntent.essential:
        essential += amount;
        break;
      case CategoryIntent.joyful:
        joyful += amount;
        break;
      case CategoryIntent.avoidable:
        avoidable += amount;
        break;
      case CategoryIntent.investments:
        investments += amount;
        break;
    }

    categorySpent[clean] = (categorySpent[clean] ?? 0.0) + amount;
  }

  final double totalSpent = essential + joyful + avoidable + investments;

  final String essentialPercent = totalSpent > 0 ? '${(essential / totalSpent * 100).toStringAsFixed(0)}%' : '0%';
  final String joyfulPercent = totalSpent > 0 ? '${(joyful / totalSpent * 100).toStringAsFixed(0)}%' : '0%';
  final String avoidablePercent = totalSpent > 0 ? '${(avoidable / totalSpent * 100).toStringAsFixed(0)}%' : '0%';
  final String investmentsPercent = totalSpent > 0 ? '${(investments / totalSpent * 100).toStringAsFixed(0)}%' : '0%';

  // Budget-split actuals
  final double needsActual = totalSpent > 0 ? (essential / totalSpent * 100) : 0;
  final double wantsActual = totalSpent > 0 ? ((joyful + avoidable) / totalSpent * 100) : 0;
  final double savingsActual = totalSpent > 0 ? (investments / totalSpent * 100) : 0;

  final List<CategoryBreakdownEntry> categoryBreakdowns = [];
  for (final cat in categories) {
    final spent = categorySpent[cat] ?? 0.0;
    if (spent > 0) {
      final limit = budgetLimits[cat] ?? 0.0;
      final proportion = totalSpent > 0 ? (spent / totalSpent).clamp(0.0, 1.0) : 0.0;
      final percentOfTotal = totalSpent > 0 ? '${(spent / totalSpent * 100).toStringAsFixed(0)}%' : '0%';
      categoryBreakdowns.add(CategoryBreakdownEntry(
        category: cat,
        spent: spent,
        limit: limit,
        proportion: proportion,
        percentOfTotal: percentOfTotal,
      ));
    }
  }

  categoryBreakdowns.sort((a, b) => b.spent.compareTo(a.spent));

  return InsightsState(
    essential: essential,
    joyful: joyful,
    avoidable: avoidable,
    investments: investments,
    totalSpent: totalSpent,
    essentialPercent: essentialPercent,
    joyfulPercent: joyfulPercent,
    avoidablePercent: avoidablePercent,
    investmentsPercent: investmentsPercent,
    needsActual: needsActual,
    wantsActual: wantsActual,
    savingsActual: savingsActual,
    categoryBreakdowns: categoryBreakdowns,
  );
});
