import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';

class CustomizationNotifier extends StateNotifier<void> {
  CustomizationNotifier() : super(null) {
    loadCustomizations();
  }

  Future<void> loadCustomizations() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load category colors
    final catColorsStr = prefs.getString('custom_category_colors') ?? '{}';
    try {
      final Map<String, dynamic> decoded = json.decode(catColorsStr);
      TallyTapTheme.customCategoryColors = decoded.map((k, v) => MapEntry(k, Color(v as int)));
    } catch (_) {}

    // Load category icons
    final catIconsStr = prefs.getString('custom_category_icons') ?? '{}';
    try {
      final Map<String, dynamic> decoded = json.decode(catIconsStr);
      TallyTapTheme.customCategoryIcons = decoded.map((k, v) => MapEntry(k, IconData(v as int, fontFamily: 'MaterialIcons')));
    } catch (_) {}

    // Load source colors
    final srcColorsStr = prefs.getString('custom_source_colors') ?? '{}';
    try {
      final Map<String, dynamic> decoded = json.decode(srcColorsStr);
      TallyTapTheme.customSourceColors = decoded.map((k, v) => MapEntry(k, Color(v as int)));
    } catch (_) {}
  }

  Future<void> updateCategoryColor(String category, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = Map<String, Color>.from(TallyTapTheme.customCategoryColors);
    updated[category] = color;
    TallyTapTheme.customCategoryColors = updated;

    final encoded = json.encode(updated.map((k, v) => MapEntry(k, v.value)));
    await prefs.setString('custom_category_colors', encoded);
    
    // Notify Riverpod of changes
    state = null;
  }

  Future<void> updateCategoryIcon(String category, IconData icon) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = Map<String, IconData>.from(TallyTapTheme.customCategoryIcons);
    updated[category] = icon;
    TallyTapTheme.customCategoryIcons = updated;

    final encoded = json.encode(updated.map((k, v) => MapEntry(k, v.codePoint)));
    await prefs.setString('custom_category_icons', encoded);
    
    state = null;
  }

  Future<void> updateSourceColor(String source, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = Map<String, Color>.from(TallyTapTheme.customSourceColors);
    updated[source] = color;
    TallyTapTheme.customSourceColors = updated;

    final encoded = json.encode(updated.map((k, v) => MapEntry(k, v.value)));
    await prefs.setString('custom_source_colors', encoded);
    
    state = null;
  }
}

final customizationProvider = StateNotifierProvider<CustomizationNotifier, void>((ref) {
  return CustomizationNotifier();
});
