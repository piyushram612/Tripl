import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Category Intent Labels
// ─────────────────────────────────────────────────────────────────────────────

/// The four buckets a spending category can map to.
class CategoryIntent {
  static const String essential = 'Essential';
  static const String joyful = 'Joyful';
  static const String avoidable = 'Avoidable';
  static const String investments = 'Investments';

  static const List<String> all = [essential, joyful, avoidable, investments];
}

// ─────────────────────────────────────────────────────────────────────────────
// Category Visibility Labels
// ─────────────────────────────────────────────────────────────────────────────

class CategoryVisibility {
  static const String expense = 'expense';
  static const String income = 'income';
  static const String both = 'both';

  static const List<String> all = [expense, income, both];
}

// ─────────────────────────────────────────────────────────────────────────────
// Categories List Provider
// ─────────────────────────────────────────────────────────────────────────────

final categoriesListProvider = StateNotifierProvider<CategoriesListNotifier, List<String>>((ref) {
  return CategoriesListNotifier();
});

class CategoriesListNotifier extends StateNotifier<List<String>> {
  CategoriesListNotifier() : super([]) {
    loadCategories();
  }

  static const List<String> defaultCategories = [
    'Dining',
    'Commute',
    'Subscriptions',
    'Utilities',
    'Groceries',
    'Shopping',
    'Housing',
    'Health',
    'Travel',
    'Investments',
    'Savings',
    'Salary',
    'Bonus',
    'Dividends',
    'Gift',
    'Other',
  ];

  Future<void> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final jsonStr = prefs.getString('categories_json');
    if (jsonStr == null || jsonStr.isEmpty) {
      await prefs.setString('categories_json', json.encode(defaultCategories));
      state = List.from(defaultCategories);
    } else {
      try {
        final List<dynamic> decoded = json.decode(jsonStr);
        final existing = decoded.map((e) => e.toString()).toList();
        // Migrate: ensure new default categories are present for existing users
        bool changed = false;
        for (final cat in ['Investments', 'Savings', 'Salary', 'Bonus', 'Dividends', 'Gift']) {
          if (!existing.contains(cat)) {
            existing.add(cat);
            changed = true;
          }
        }
        if (changed) {
          await prefs.setString('categories_json', json.encode(existing));
        }
        state = existing;
      } catch (e) {
        state = List.from(defaultCategories);
      }
    }
  }

  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || state.contains(trimmed)) return;
    final updated = List<String>.from(state)..add(trimmed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('categories_json', json.encode(updated));
    state = updated;
  }

  Future<void> deleteCategory(String name) async {
    final updated = List<String>.from(state)..remove(name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('categories_json', json.encode(updated));
    state = updated;
  }

  Future<void> updateCategory(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || state.contains(trimmed)) return;
    final updated = List<String>.from(state);
    final index = updated.indexOf(oldName);
    if (index != -1) {
      updated[index] = trimmed;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('categories_json', json.encode(updated));

      // Update budget limit key if it exists
      final oldKey = 'budget_limit_$oldName';
      final newKey = 'budget_limit_$trimmed';
      if (prefs.containsKey(oldKey)) {
        final limit = prefs.getDouble(oldKey);
        if (limit != null) {
          await prefs.setDouble(newKey, limit);
          await prefs.remove(oldKey);
        }
      }

      // Migrate category intent key
      final intentKey = 'category_intent_$oldName';
      final newIntentKey = 'category_intent_$trimmed';
      if (prefs.containsKey(intentKey)) {
        final intent = prefs.getString(intentKey);
        if (intent != null) {
          await prefs.setString(newIntentKey, intent);
          await prefs.remove(intentKey);
        }
      }

      state = updated;
    }
  }

  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final List<String> updated = List<String>.from(state);
    if (oldIndex >= 0 && oldIndex < updated.length && newIndex >= 0 && newIndex < updated.length) {
      final item = updated.removeAt(oldIndex);
      updated.insert(newIndex, item);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('categories_json', json.encode(updated));
      state = updated;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category Intent Provider — maps category name → intent bucket
// ─────────────────────────────────────────────────────────────────────────────

/// Sensible defaults applied on first launch (or for any category not yet configured).
const Map<String, String> _defaultIntents = {
  'Dining': CategoryIntent.joyful,
  'Commute': CategoryIntent.essential,
  'Subscriptions': CategoryIntent.avoidable,
  'Utilities': CategoryIntent.essential,
  'Groceries': CategoryIntent.essential,
  'Shopping': CategoryIntent.avoidable,
  'Housing': CategoryIntent.essential,
  'Health': CategoryIntent.essential,
  'Travel': CategoryIntent.joyful,
  'Investments': CategoryIntent.investments,
  'Savings': CategoryIntent.investments,
  'Salary': CategoryIntent.essential,
  'Bonus': CategoryIntent.joyful,
  'Dividends': CategoryIntent.investments,
  'Gift': CategoryIntent.joyful,
  'Other': CategoryIntent.essential,
};

final categoryIntentsProvider = StateNotifierProvider<CategoryIntentsNotifier, Map<String, String>>((ref) {
  return CategoryIntentsNotifier();
});

class CategoryIntentsNotifier extends StateNotifier<Map<String, String>> {
  CategoryIntentsNotifier() : super({}) {
    loadIntents();
  }

  static const String _keyPrefix = 'category_intent_';

  Future<void> loadIntents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final Map<String, String> loaded = Map.from(_defaultIntents);

    // Overlay any user overrides stored individually
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_keyPrefix)) {
        final catName = key.substring(_keyPrefix.length);
        final intent = prefs.getString(key);
        if (intent != null && CategoryIntent.all.contains(intent)) {
          loaded[catName] = intent;
        }
      }
    }
    state = loaded;
  }

  /// Returns the intent for [category], defaulting to Essential.
  String getIntent(String category) {
    return state[category.trim()] ?? CategoryIntent.essential;
  }

  Future<void> updateIntent(String category, String intent) async {
    if (!CategoryIntent.all.contains(intent)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix${category.trim()}', intent);
    state = Map.from(state)..[category.trim()] = intent;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category Visibility Provider
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, String> _defaultVisibilities = {
  'Dining': CategoryVisibility.expense,
  'Commute': CategoryVisibility.expense,
  'Subscriptions': CategoryVisibility.expense,
  'Utilities': CategoryVisibility.expense,
  'Groceries': CategoryVisibility.expense,
  'Shopping': CategoryVisibility.expense,
  'Housing': CategoryVisibility.expense,
  'Health': CategoryVisibility.expense,
  'Travel': CategoryVisibility.expense,
  'Investments': CategoryVisibility.both,
  'Savings': CategoryVisibility.both,
  'Salary': CategoryVisibility.income,
  'Bonus': CategoryVisibility.income,
  'Dividends': CategoryVisibility.income,
  'Gift': CategoryVisibility.both,
  'Other': CategoryVisibility.both,
};

final categoryVisibilityProvider = StateNotifierProvider<CategoryVisibilityNotifier, Map<String, String>>((ref) {
  return CategoryVisibilityNotifier();
});

class CategoryVisibilityNotifier extends StateNotifier<Map<String, String>> {
  CategoryVisibilityNotifier() : super({}) {
    loadVisibilities();
  }

  static const String _prefKey = 'category_visibilities_json';

  Future<void> loadVisibilities() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final Map<String, String> loaded = Map.from(_defaultVisibilities);

    final jsonStr = prefs.getString(_prefKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded = json.decode(jsonStr);
        for (final entry in decoded.entries) {
          if (CategoryVisibility.all.contains(entry.value)) {
            loaded[entry.key] = entry.value as String;
          }
        }
      } catch (_) {}
    }
    state = loaded;
  }

  String getVisibility(String category) {
    return state[category.trim()] ?? CategoryVisibility.expense;
  }

  Future<void> updateVisibility(String category, String visibility) async {
    if (!CategoryVisibility.all.contains(visibility)) return;
    final updated = Map<String, String>.from(state)..[category.trim()] = visibility;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, json.encode(updated));
    state = updated;
  }

  Future<void> removeVisibility(String category) async {
    final updated = Map<String, String>.from(state)..remove(category.trim());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, json.encode(updated));
    state = updated;
  }

  Future<void> renameVisibility(String oldName, String newName) async {
    final oldTrimmed = oldName.trim();
    final newTrimmed = newName.trim();
    if (state.containsKey(oldTrimmed)) {
      final vis = state[oldTrimmed]!;
      final updated = Map<String, String>.from(state)
        ..remove(oldTrimmed)
        ..[newTrimmed] = vis;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, json.encode(updated));
      state = updated;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Budget Split Provider — user-configurable target percentages
// ─────────────────────────────────────────────────────────────────────────────

class BudgetSplitTargets {
  /// Target % for Essential (Needs). 0–100.
  final double needsTarget;

  /// Target % for Joyful + Avoidable (Wants). 0–100.
  final double wantsTarget;

  /// Target % for Investments (Savings). 0–100.
  final double savingsTarget;

  const BudgetSplitTargets({
    required this.needsTarget,
    required this.wantsTarget,
    required this.savingsTarget,
  });

  /// The three values must sum to 100 (enforced by the notifier).
  double get total => needsTarget + wantsTarget + savingsTarget;
}

final budgetSplitProvider = StateNotifierProvider<BudgetSplitNotifier, BudgetSplitTargets>((ref) {
  return BudgetSplitNotifier();
});

class BudgetSplitNotifier extends StateNotifier<BudgetSplitTargets> {
  BudgetSplitNotifier()
      : super(const BudgetSplitTargets(needsTarget: 50, wantsTarget: 30, savingsTarget: 20)) {
    _load();
  }

  static const String _needsKey = 'budget_split_needs';
  static const String _wantsKey = 'budget_split_wants';
  static const String _savingsKey = 'budget_split_savings';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final needs = prefs.getDouble(_needsKey) ?? 50.0;
    final wants = prefs.getDouble(_wantsKey) ?? 30.0;
    final savings = prefs.getDouble(_savingsKey) ?? 20.0;
    state = BudgetSplitTargets(
      needsTarget: needs,
      wantsTarget: wants,
      savingsTarget: savings,
    );
  }

  /// Persist new split targets. Values are clamped and normalised so they sum to 100.
  Future<void> updateTargets({
    required double needs,
    required double wants,
    required double savings,
  }) async {
    final total = needs + wants + savings;
    if (total == 0) return;
    final n = (needs / total * 100).roundToDouble();
    final w = (wants / total * 100).roundToDouble();
    final s = (100 - n - w).roundToDouble().clamp(0, 100).toDouble();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_needsKey, n);
    await prefs.setDouble(_wantsKey, w);
    await prefs.setDouble(_savingsKey, s);
    state = BudgetSplitTargets(needsTarget: n, wantsTarget: w, savingsTarget: s);
  }
}
