import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';

// ── CustomizationNotifier ─────────────────────────────────────────────────
// State is an int revision counter — incrementing it ensures Riverpod always
// detects a change (unlike void/null where null==null skips rebuilds).

class CustomizationNotifier extends StateNotifier<int> {
  CustomizationNotifier() : super(0) {
    loadCustomizations();
  }

  /// Bump the revision counter to force all watchers to rebuild.
  void _notify() => state = state + 1;

  /// Picks the palette color least-used by existing categories, so a new
  /// category always gets a visually distinct color from its neighbours.
  Color _pickUnusedColor(Iterable<String> existingCategories) {
    final palette = TallyTapTheme.categoryPalette;
    // Count how many existing categories use each palette slot
    final usageCount = List<int>.filled(palette.length, 0);
    for (final cat in existingCategories) {
      if (TallyTapTheme.customCategoryColors.containsKey(cat)) {
        final color = TallyTapTheme.customCategoryColors[cat]!;
        final idx = palette.indexWhere((c) => c.value == color.value);
        if (idx >= 0) usageCount[idx]++;
      } else {
        // Auto-assigned hash slot
        final hash = cat.codeUnits.fold(0, (h, c) => (h * 31 + c) & 0xFFFFFFFF);
        usageCount[hash % palette.length]++;
      }
    }
    // Find the slot with the lowest usage count
    int minUsage = usageCount.reduce((a, b) => a < b ? a : b);
    final leastUsed = usageCount.indexWhere((u) => u == minUsage);
    return palette[leastUsed];
  }

  Future<void> loadCustomizations() async {
    final prefs = await SharedPreferences.getInstance();

    // Load category colors
    final catColorsStr = prefs.getString('custom_category_colors') ?? '{}';
    try {
      final Map<String, dynamic> decoded = json.decode(catColorsStr);
      TallyTapTheme.customCategoryColors =
          decoded.map((k, v) => MapEntry(k, Color(v as int)));
    } catch (_) {}

    // Load category icons
    final catIconsStr = prefs.getString('custom_category_icons') ?? '{}';
    try {
      final Map<String, dynamic> decoded = json.decode(catIconsStr);
      TallyTapTheme.customCategoryIcons = decoded.map(
          (k, v) {
            final codePoint = v as int;
            final icon = TallyTapTheme.availableIcons.firstWhere(
              (i) => i.codePoint == codePoint,
              orElse: () => Icons.local_mall_outlined,
            );
            return MapEntry(k, icon);
          });
    } catch (_) {}

    // Load source colors
    final srcColorsStr = prefs.getString('custom_source_colors') ?? '{}';
    try {
      final Map<String, dynamic> decoded = json.decode(srcColorsStr);
      TallyTapTheme.customSourceColors =
          decoded.map((k, v) => MapEntry(k, Color(v as int)));
    } catch (_) {}

    // Seed colors for default categories that don't have a custom color yet.
    // This runs on every app start but only adds entries for categories
    // that are truly missing, so user overrides are always preserved.
    await _seedDefaultCategoryColors(prefs);

    _notify(); // Trigger rebuild after load so UI gets initial values
  }

  /// Assigns a deterministic unique color to each default category that doesn't
  /// already have a custom color stored. This is idempotent — safe to call
  /// on every app start.
  Future<void> _seedDefaultCategoryColors(SharedPreferences prefs) async {
    const defaultCategories = [
      'Dining', 'Commute', 'Subscriptions', 'Utilities', 'Groceries',
      'Shopping', 'Housing', 'Health', 'Travel', 'Investments', 'Savings', 'Other',
    ];
    final palette = TallyTapTheme.categoryPalette;
    bool changed = false;
    for (int i = 0; i < defaultCategories.length; i++) {
      final cat = defaultCategories[i];
      if (!TallyTapTheme.customCategoryColors.containsKey(cat)) {
        // Spread defaults evenly across the palette, cycling if more than palette.length
        final color = palette[i % palette.length];
        TallyTapTheme.customCategoryColors =
            Map.from(TallyTapTheme.customCategoryColors)..[cat] = color;
        changed = true;
      }
    }
    if (changed) {
      final encoded = json.encode(
          TallyTapTheme.customCategoryColors.map((k, v) => MapEntry(k, v.toARGB32())));
      await prefs.setString('custom_category_colors', encoded);
    }
  }

  /// Call this when a new category is added so it gets a fresh color that
  /// avoids clashing with existing categories.
  Future<void> autoAssignCategoryColor(
      String newCategory, Iterable<String> allCategories) async {
    if (TallyTapTheme.customCategoryColors.containsKey(newCategory)) return;
    final color = _pickUnusedColor(
        allCategories.where((c) => c != newCategory));
    await updateCategoryColor(newCategory, color);
  }

  Future<void> updateCategoryColor(String category, Color color) async {
    // 1. Update in-memory map immediately
    TallyTapTheme.customCategoryColors =
        Map.from(TallyTapTheme.customCategoryColors)..[category] = color;
    // 2. Notify all watchers right away (revision bumps → guaranteed rebuild)
    _notify();
    // 3. Persist in background
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(
        TallyTapTheme.customCategoryColors.map((k, v) => MapEntry(k, v.value)));
    await prefs.setString('custom_category_colors', encoded);
  }

  Future<void> updateCategoryIcon(String category, IconData icon) async {
    TallyTapTheme.customCategoryIcons =
        Map.from(TallyTapTheme.customCategoryIcons)..[category] = icon;
    _notify();
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(TallyTapTheme.customCategoryIcons
        .map((k, v) => MapEntry(k, v.codePoint)));
    await prefs.setString('custom_category_icons', encoded);
  }

  Future<void> updateSourceColor(String source, Color color) async {
    TallyTapTheme.customSourceColors =
        Map.from(TallyTapTheme.customSourceColors)..[source] = color;
    _notify();
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(
        TallyTapTheme.customSourceColors.map((k, v) => MapEntry(k, v.value)));
    await prefs.setString('custom_source_colors', encoded);
  }

  Future<void> migrateCategoryCustomizations(
      String oldName, String newName) async {
    final prefs = await SharedPreferences.getInstance();

    final colors = Map<String, Color>.from(TallyTapTheme.customCategoryColors);
    if (colors.containsKey(oldName)) {
      colors[newName] = colors.remove(oldName)!;
      TallyTapTheme.customCategoryColors = colors;
      await prefs.setString('custom_category_colors',
          json.encode(colors.map((k, v) => MapEntry(k, v.value))));
    }

    final icons = Map<String, IconData>.from(TallyTapTheme.customCategoryIcons);
    if (icons.containsKey(oldName)) {
      icons[newName] = icons.remove(oldName)!;
      TallyTapTheme.customCategoryIcons = icons;
      await prefs.setString('custom_category_icons',
          json.encode(icons.map((k, v) => MapEntry(k, v.codePoint))));
    }

    _notify();
  }

  Future<void> migrateSourceCustomizations(
      String oldName, String newName) async {
    final prefs = await SharedPreferences.getInstance();

    final colors = Map<String, Color>.from(TallyTapTheme.customSourceColors);
    if (colors.containsKey(oldName)) {
      colors[newName] = colors.remove(oldName)!;
      TallyTapTheme.customSourceColors = colors;
      await prefs.setString('custom_source_colors',
          json.encode(colors.map((k, v) => MapEntry(k, v.value))));
    }

    _notify();
  }
}

final customizationProvider =
    StateNotifierProvider<CustomizationNotifier, int>((ref) {
  return CustomizationNotifier();
});

// ── SnoozeDurationNotifier ────────────────────────────────────────────────

final snoozeDurationProvider =
    StateNotifierProvider<SnoozeDurationNotifier, int>((ref) {
  return SnoozeDurationNotifier();
});

class SnoozeDurationNotifier extends StateNotifier<int> {
  SnoozeDurationNotifier() : super(240) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt('tallytap_snooze_duration_mins') ?? 240;
  }

  Future<void> setDuration(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tallytap_snooze_duration_mins', minutes);
    state = minutes;
  }
}
