import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/transaction_service.dart';
import 'budget_provider.dart';
import 'category_provider.dart';

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

  // ── Legacy category sub-totals (for Category Breakdown card) ────────────────
  final double diningSpent;
  final double commuteSpent;
  final double utilitiesSpent;
  final double otherSpent;

  final double diningLimit;
  final double commuteLimit;
  final double utilitiesLimit;
  final double otherLimit;

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
    required this.diningSpent,
    required this.commuteSpent,
    required this.utilitiesSpent,
    required this.otherSpent,
    required this.diningLimit,
    required this.commuteLimit,
    required this.utilitiesLimit,
    required this.otherLimit,
  });
}

final insightsProvider = Provider<InsightsState>((ref) {
  final transactions = ref.watch(transactionListProvider);
  final budgetLimits = ref.watch(budgetLimitsProvider);
  final intentMap = ref.watch(categoryIntentsProvider);

  double essential = 0.0;
  double joyful = 0.0;
  double avoidable = 0.0;
  double investments = 0.0;

  // Sub-totals for legacy Category Breakdown card
  double diningSpent = 0.0;
  double commuteSpent = 0.0;
  double utilitiesSpent = 0.0;
  double otherSpent = 0.0;

  for (var tx in transactions) {
    final clean = tx.category.trim();
    if (clean.toLowerCase() == 'income') continue;

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

    // Sub-totals for the category breakdown section (keyword fallback for legacy)
    final lc = clean.toLowerCase();
    if (lc.contains('dining') || lc.contains('food') || lc.contains('dinner')) {
      diningSpent += amount;
    } else if (lc.contains('commute') || lc.contains('transport')) {
      commuteSpent += amount;
    } else if (lc.contains('utility') || lc.contains('bill')) {
      utilitiesSpent += amount;
    } else {
      otherSpent += amount;
    }
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

  final double diningLimit = budgetLimits['Dining'] ?? 800.0;
  final double commuteLimit = budgetLimits['Commute'] ?? 400.0;
  final double utilitiesLimit = budgetLimits['Utilities'] ?? 300.0;
  final double otherLimit = budgetLimits['Other'] ?? 2000.0;

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
    diningSpent: diningSpent,
    commuteSpent: commuteSpent,
    utilitiesSpent: utilitiesSpent,
    otherSpent: otherSpent,
    diningLimit: diningLimit,
    commuteLimit: commuteLimit,
    utilitiesLimit: utilitiesLimit,
    otherLimit: otherLimit,
  );
});
