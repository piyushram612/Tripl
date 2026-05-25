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
}
