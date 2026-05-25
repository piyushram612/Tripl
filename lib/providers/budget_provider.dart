import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'category_provider.dart';

final budgetLimitsProvider = StateNotifierProvider<BudgetLimitsNotifier, Map<String, double>>((ref) {
  return BudgetLimitsNotifier();
});

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

    final defaultLimits = {
      'Dining': 800.0,
      'Commute': 400.0,
      'Subscriptions': 400.0,
      'Utilities': 300.0,
      'Other': 2000.0,
    };

    for (final cat in activeCategories) {
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
}

class GlobalBudgetState {
  final double amount;
  final String period; // 'monthly' or 'weekly'

  GlobalBudgetState({required this.amount, required this.period});
}

final globalBudgetProvider = StateNotifierProvider<GlobalBudgetNotifier, GlobalBudgetState>((ref) {
  return GlobalBudgetNotifier();
});

class GlobalBudgetNotifier extends StateNotifier<GlobalBudgetState> {
  GlobalBudgetNotifier() : super(GlobalBudgetState(amount: 2000.0, period: 'monthly')) {
    loadGlobalBudget();
  }

  Future<void> loadGlobalBudget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final amount = prefs.getDouble('global_budget_amount') ?? 2000.0;
    final period = prefs.getString('global_budget_period') ?? 'monthly';
    state = GlobalBudgetState(amount: amount, period: period);
  }

  Future<void> setGlobalBudget(double amount, String period) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('global_budget_amount', amount);
    await prefs.setString('global_budget_period', period);
    state = GlobalBudgetState(amount: amount, period: period);
  }
}
