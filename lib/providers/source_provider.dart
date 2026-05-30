import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Payment Sources List Provider
final sourcesListProvider = StateNotifierProvider<SourcesListNotifier, List<String>>((ref) {
  return SourcesListNotifier();
});

class SourcesListNotifier extends StateNotifier<List<String>> {
  SourcesListNotifier() : super([]) {
    loadSources();
  }

  static const List<String> defaultSources = [
    'Cash',
    'Bank Account',
    'Credit Card',
  ];

  Future<void> loadSources() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final jsonStr = prefs.getString('sources_json');
    if (jsonStr == null || jsonStr.isEmpty) {
      await prefs.setString('sources_json', json.encode(defaultSources));
      state = List.from(defaultSources);
    } else {
      try {
        final List<dynamic> decoded = json.decode(jsonStr);
        state = decoded.map((e) => e.toString()).toList();
      } catch (e) {
        state = List.from(defaultSources);
      }
    }
  }

  Future<void> addSource(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || state.contains(trimmed)) return;
    final updated = List<String>.from(state)..add(trimmed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sources_json', json.encode(updated));
    state = updated;
  }

  Future<void> deleteSource(String name) async {
    final updated = List<String>.from(state)..remove(name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sources_json', json.encode(updated));
    state = updated;
  }

  Future<void> updateSource(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || state.contains(trimmed)) return;
    final updated = List<String>.from(state);
    final index = updated.indexOf(oldName);
    if (index != -1) {
      updated[index] = trimmed;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sources_json', json.encode(updated));
      state = updated;
    }
  }

  Future<void> reorderSources(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final List<String> updated = List<String>.from(state);
    if (oldIndex >= 0 && oldIndex < updated.length && newIndex >= 0 && newIndex < updated.length) {
      final item = updated.removeAt(oldIndex);
      updated.insert(newIndex, item);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sources_json', json.encode(updated));
      state = updated;
    }
  }
}

final sourceStartingBalancesProvider = StateNotifierProvider<SourceStartingBalancesNotifier, Map<String, double>>((ref) {
  return SourceStartingBalancesNotifier();
});

class SourceStartingBalancesNotifier extends StateNotifier<Map<String, double>> {
  SourceStartingBalancesNotifier() : super({}) {
    loadBalances();
  }

  Future<void> loadBalances() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final Map<String, double> balances = {};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('source_starting_balance_')) {
        final source = key.replaceFirst('source_starting_balance_', '');
        balances[source] = prefs.getDouble(key) ?? 0.0;
      }
    }
    state = balances;
  }

  Future<void> setStartingBalance(String source, double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('source_starting_balance_$source', amount);
    state = {...state, source: amount};
  }
}
