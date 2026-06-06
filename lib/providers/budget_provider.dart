import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'category_provider.dart';

final budgetLimitsProvider = StateNotifierProvider<BudgetLimitsNotifier, Map<String, double>>((ref) {
  return BudgetLimitsNotifier();
});

final excludedCategoriesProvider = StateNotifierProvider<ExcludedCategoriesNotifier, List<String>>((ref) {
  return ExcludedCategoriesNotifier();
});

class ExcludedCategoriesNotifier extends StateNotifier<List<String>> {
  ExcludedCategoriesNotifier() : super([]) {
    loadExcluded();
  }

  Future<void> loadExcluded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    state = prefs.getStringList('excluded_budget_categories') ?? [];
  }

  Future<void> toggleExclusion(String category) async {
    final prefs = await SharedPreferences.getInstance();
    final current = List<String>.from(state);
    if (current.contains(category)) {
      current.remove(category);
    } else {
      current.add(category);
    }
    await prefs.setStringList('excluded_budget_categories', current);
    state = current;
  }
}

class BudgetLimitsNotifier extends StateNotifier<Map<String, double>> {
  BudgetLimitsNotifier() : super({}) {
    loadLimits();
  }

  Future<void> loadLimits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    
    final Map<String, double> loaded = {};
    
    final jsonStr = prefs.getString('categories_json');
    List<String> activeCategories = CategoriesListNotifier.defaultCategories;
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = json.decode(jsonStr);
        activeCategories = decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }

    final excludedCats = prefs.getStringList('excluded_budget_categories') ?? [];

    final defaultLimits = {
      'Dining': 800.0,
      'Commute': 400.0,
      'Subscriptions': 400.0,
      'Utilities': 300.0,
      'Other': 2000.0,
    };

    for (final cat in activeCategories) {
      if (excludedCats.contains(cat)) {
        continue;
      }
      final key = 'budget_limit_$cat';
      final defaultLimit = defaultLimits[cat] ?? 500.0;
      loaded[cat] = prefs.getDouble(key) ?? defaultLimit;
    }
    state = loaded;
  }

  Future<void> setLimit(String category, double limit) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'budget_limit_$category';
    await prefs.setDouble(key, limit);
    await loadLimits();
  }

  Future<void> setMultipleLimits(Map<String, double> newLimits) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in newLimits.entries) {
      final key = 'budget_limit_${entry.key}';
      await prefs.setDouble(key, entry.value);
    }
    await loadLimits();
  }
}

class GlobalBudgetState {
  final double monthlyAmount;
  final double weeklyAmount;
  final String period; // 'monthly' or 'weekly'

  GlobalBudgetState({
    required this.monthlyAmount,
    required this.weeklyAmount,
    required this.period,
  });

  double get amount => period == 'monthly' ? monthlyAmount : weeklyAmount;
}

final globalBudgetProvider = StateNotifierProvider<GlobalBudgetNotifier, GlobalBudgetState>((ref) {
  return GlobalBudgetNotifier();
});

class GlobalBudgetNotifier extends StateNotifier<GlobalBudgetState> {
  GlobalBudgetNotifier() : super(GlobalBudgetState(monthlyAmount: 2000.0, weeklyAmount: 500.0, period: 'monthly')) {
    loadGlobalBudget();
  }

  Future<void> loadGlobalBudget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final monthlyAmount = prefs.getDouble('global_budget_monthly_amount') ?? 2000.0;
    final weeklyAmount = prefs.getDouble('global_budget_weekly_amount') ?? 500.0;
    final period = prefs.getString('global_budget_period') ?? 'monthly';
    state = GlobalBudgetState(
      monthlyAmount: monthlyAmount,
      weeklyAmount: weeklyAmount,
      period: period,
    );
  }

  Future<void> setGlobalBudget(double amount, String period) async {
    final prefs = await SharedPreferences.getInstance();
    if (period == 'monthly') {
      await prefs.setDouble('global_budget_monthly_amount', amount);
    } else {
      await prefs.setDouble('global_budget_weekly_amount', amount);
    }
    await prefs.setString('global_budget_period', period);
    await loadGlobalBudget();
  }

  Future<void> setPeriod(String period) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('global_budget_period', period);
    await loadGlobalBudget();
  }
}
