import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/transaction_service.dart';
import 'budget_provider.dart';
import 'category_provider.dart';

class DonutChartCategory {
  final String name;
  final double amount;

  DonutChartCategory({required this.name, required this.amount});
}

class DashboardState {
  final double totalSpent;
  final List<double> weeklyTrend;
  final List<DonutChartCategory> dynamicCategories;
  final Map<String, double> spentPerCategory;

  DashboardState({
    required this.totalSpent,
    required this.weeklyTrend,
    required this.dynamicCategories,
    required this.spentPerCategory,
  });
}

final dashboardProvider = Provider<DashboardState>((ref) {
  final transactions = ref.watch(transactionListProvider);
  final globalBudget = ref.watch(globalBudgetProvider);
  final categories = ref.watch(categoriesListProvider);

  bool isDateInCurrentWeek(DateTime date) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    return date.isAfter(startOfDay.subtract(const Duration(seconds: 1)));
  }

  bool isDateInCurrentMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  double totalSpent = 0.0;
  final Map<String, double> catSum = {};

  String capitalizeCategory(String cat) {
    if (cat.isEmpty) return cat;
    final match = categories.firstWhere(
      (c) => c.toLowerCase() == cat.toLowerCase(),
      orElse: () => '',
    );
    if (match.isNotEmpty) return match;
    return cat.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  for (var tx in transactions) {
    if (!tx.isIncome) {
      if (globalBudget.period == 'weekly') {
        if (!isDateInCurrentWeek(tx.date)) continue;
      } else {
        if (!isDateInCurrentMonth(tx.date)) continue;
      }
      totalSpent += tx.amount;
      
      final normalizedCat = capitalizeCategory(tx.category);
      catSum[normalizedCat] = (catSum[normalizedCat] ?? 0.0) + tx.amount;
    }
  }

  final now = DateTime.now();
  final List<double> weeklyTrend = List.generate(7, (index) {
    final targetDate = now.subtract(Duration(days: 6 - index));
    double balance = 0.0;
    
    for (var tx in transactions) {
      final txDateOnly = DateTime(tx.date.year, tx.date.month, tx.date.day);
      final targetDateOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);
      
      if (txDateOnly.isBefore(targetDateOnly) || txDateOnly.isAtSameMomentAs(targetDateOnly)) {
        if (tx.isIncome) {
          balance += tx.amount;
        } else {
          balance -= tx.amount;
        }
      }
    }
    return balance;
  });

  final dynamicCategories = catSum.entries.map((entry) {
    return DonutChartCategory(
      name: entry.key,
      amount: entry.value,
    );
  }).toList()..sort((a, b) => b.amount.compareTo(a.amount));

  return DashboardState(
    totalSpent: totalSpent,
    weeklyTrend: weeklyTrend,
    dynamicCategories: dynamicCategories,
    spentPerCategory: catSum,
  );
});
