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

class SourceBillingCycleConfig {
  final int statementDay; // Day of the month when billing statement closes (1 to 28)
  final int dueDay;       // Day of the month when payment is due (1 to 28)
  final bool isEnabled;

  SourceBillingCycleConfig({
    required this.statementDay,
    required this.dueDay,
    required this.isEnabled,
  });

  Map<String, dynamic> toMap() {
    return {
      'statementDay': statementDay,
      'dueDay': dueDay,
      'isEnabled': isEnabled,
    };
  }

  factory SourceBillingCycleConfig.fromMap(Map<String, dynamic> map) {
    return SourceBillingCycleConfig(
      statementDay: map['statementDay'] ?? 1,
      dueDay: map['dueDay'] ?? 20,
      isEnabled: map['isEnabled'] ?? false,
    );
  }
}

final sourceBillingCyclesProvider = StateNotifierProvider<SourceBillingCyclesNotifier, Map<String, SourceBillingCycleConfig>>((ref) {
  return SourceBillingCyclesNotifier();
});

class SourceBillingCyclesNotifier extends StateNotifier<Map<String, SourceBillingCycleConfig>> {
  SourceBillingCyclesNotifier() : super({}) {
    loadConfigs();
  }

  Future<void> loadConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final Map<String, SourceBillingCycleConfig> configs = {};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('source_billing_cycle_')) {
        final source = key.replaceFirst('source_billing_cycle_', '');
        final jsonStr = prefs.getString(key);
        if (jsonStr != null && jsonStr.isNotEmpty) {
          try {
            configs[source] = SourceBillingCycleConfig.fromMap(json.decode(jsonStr));
          } catch (_) {}
        }
      }
    }
    state = configs;
  }

  Future<void> setConfig(String source, SourceBillingCycleConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'source_billing_cycle_$source';
    if (config.isEnabled) {
      await prefs.setString(key, json.encode(config.toMap()));
      state = {...state, source: config};
    } else {
      await prefs.remove(key);
      final updated = {...state}..remove(source);
      state = updated;
    }
  }
}
