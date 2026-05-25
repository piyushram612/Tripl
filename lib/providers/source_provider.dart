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
}
