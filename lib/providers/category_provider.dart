import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Categories List Provider
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
        state = decoded.map((e) => e.toString()).toList();
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
