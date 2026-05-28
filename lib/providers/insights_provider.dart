import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/transaction_service.dart';
import 'budget_provider.dart';

class InsightsState {
  final double essential;
  final double joyful;
  final double avoidable;
  final double totalSpent;
  final String essentialPercent;
  final String joyfulPercent;
  final String avoidablePercent;
  
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
    required this.totalSpent,
    required this.essentialPercent,
    required this.joyfulPercent,
    required this.avoidablePercent,
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

  double diningSpent = 0.0;
  double commuteSpent = 0.0;
  double subSpent = 0.0;
  double utilitiesSpent = 0.0;
  double otherSpent = 0.0;

  for (var tx in transactions) {
    final clean = tx.category.toLowerCase();
    if (clean != 'income') {
      if (clean.contains('dining') || clean.contains('food') || clean.contains('dinner')) {
        diningSpent += tx.amount;
      } else if (clean.contains('commute') || clean.contains('transport')) {
        commuteSpent += tx.amount;
      } else if (clean.contains('sub') || clean.contains('entertainment')) {
        subSpent += tx.amount;
      } else if (clean.contains('utility') || clean.contains('bill')) {
        utilitiesSpent += tx.amount;
      } else {
        otherSpent += tx.amount;
      }
    }
  }

  final double diningLimit = budgetLimits['Dining'] ?? 800.0;
  final double commuteLimit = budgetLimits['Commute'] ?? 400.0;
  final double utilitiesLimit = budgetLimits['Utilities'] ?? 300.0;
  final double otherLimit = budgetLimits['Other'] ?? 2000.0;

  final double essential = otherSpent + utilitiesSpent + commuteSpent;
  final double joyful = diningSpent;
  final double avoidable = subSpent;
  final double totalSpent = essential + joyful + avoidable;

  final String essentialPercent = totalSpent > 0 ? '${(essential / totalSpent * 100).toStringAsFixed(0)}%' : '0%';
  final String joyfulPercent = totalSpent > 0 ? '${(joyful / totalSpent * 100).toStringAsFixed(0)}%' : '0%';
  final String avoidablePercent = totalSpent > 0 ? '${(avoidable / totalSpent * 100).toStringAsFixed(0)}%' : '0%';

  return InsightsState(
    essential: essential,
    joyful: joyful,
    avoidable: avoidable,
    totalSpent: totalSpent,
    essentialPercent: essentialPercent,
    joyfulPercent: joyfulPercent,
    avoidablePercent: avoidablePercent,
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
