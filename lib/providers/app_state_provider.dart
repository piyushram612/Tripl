import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/platform_service.dart';

// State Provider to manage active bottom navigation tab
final activeTabProvider = StateProvider<int>((ref) => 0);

// State Provider for the Double Back Tap Gesture toggle
final backTapEnabledProvider = StateNotifierProvider<BackTapNotifier, bool>((ref) {
  return BackTapNotifier();
});

class BackTapNotifier extends StateNotifier<bool> {
  BackTapNotifier() : super(false) {
    _init();
  }

  Future<void> _init() async {
    state = await PlatformService.isBackTapEnabled();
  }

  Future<void> toggle(bool val) async {
    state = val;
    await PlatformService.setBackTapEnabled(val);
  }
}

// State Provider for Haptic Feedback toggle
final hapticsEnabledProvider = StateNotifierProvider<HapticsEnabledNotifier, bool>((ref) {
  return HapticsEnabledNotifier();
});

class HapticsEnabledNotifier extends StateNotifier<bool> {
  static const _key = 'haptics_enabled';

  HapticsEnabledNotifier() : super(true) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true;
  }

  Future<void> toggle(bool val) async {
    state = val;
    await PlatformService.setHapticsEnabled(val);
  }
}

// ─── Calibration Completed Provider ───────────────────────────────────────────

final calibrationCompletedProvider =
    StateNotifierProvider<CalibrationCompletedNotifier, bool>((ref) {
  return CalibrationCompletedNotifier();
});

class CalibrationCompletedNotifier extends StateNotifier<bool> {
  static const _key = 'calibration_completed';

  CalibrationCompletedNotifier() : super(false) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    state = true;
  }

  static Future<bool> readOnce() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }
}

// ─── Tap Sensitivity Provider (ms window between first and last tap) ──────────

final tapSensitivityProvider =
    StateNotifierProvider<TapSensitivityNotifier, int>((ref) {
  return TapSensitivityNotifier();
});

class TapSensitivityNotifier extends StateNotifier<int> {
  static const _key = 'tap_sensitivity_ms';
  static const defaultMs = 500;

  TapSensitivityNotifier() : super(defaultMs) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_key) ?? defaultMs;
  }

  Future<void> setSensitivity(int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, ms);
    state = ms;
  }

  static Future<int> readOnce() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? defaultMs;
  }
}

// ─── Home Screen Layout Provider ──────────────────────────────────────────────

final homeEditModeProvider = StateProvider<bool>((ref) => false);

final homeLayoutProvider = StateNotifierProvider<HomeLayoutNotifier, List<String>>((ref) {
  return HomeLayoutNotifier();
});

class HomeLayoutNotifier extends StateNotifier<List<String>> {
  static const _key = 'home_widget_layout';
  static const defaultLayout = ['accounts', 'summary', 'breakdown', 'recent'];

  HomeLayoutNotifier() : super(defaultLayout) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLayout = prefs.getStringList(_key);
    if (savedLayout != null && savedLayout.isNotEmpty) {
      // Ensure all default keys exist in the saved layout (in case new ones are added later)
      final mergedLayout = List<String>.from(savedLayout);
      for (final key in defaultLayout) {
        if (!mergedLayout.contains(key)) {
          mergedLayout.add(key);
        }
      }
      state = mergedLayout;
    } else {
      state = defaultLayout;
    }
  }

  Future<void> updateLayout(List<String> newLayout) async {
    state = newLayout;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, newLayout);
  }

  Future<void> resetLayout() async {
    state = defaultLayout;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, defaultLayout);
  }
}

// Empty

// ─── Generic SharedPreferences Notifier ───────────────────────────────────────

class PrefNotifier<T> extends StateNotifier<T> {
  final String key;
  final T defaultValue;

  PrefNotifier(this.key, this.defaultValue) : super(defaultValue) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    if (T == int) {
      state = (prefs.getInt(key) ?? defaultValue) as T;
    } else if (T == String) {
      state = (prefs.getString(key) ?? defaultValue) as T;
    } else if (T == bool) {
      state = (prefs.getBool(key) ?? defaultValue) as T;
    }
  }

  Future<void> updateVal(T value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    if (T == int) {
      await prefs.setInt(key, value as int);
    } else if (T == String) {
      await prefs.setString(key, value as String);
    } else if (T == bool) {
      await prefs.setBool(key, value as bool);
    }
  }
}

// ─── Recent Reflections Settings Providers ────────────────────────────────────

final homeRecentCountProvider = StateNotifierProvider<PrefNotifier<int>, int>((ref) => PrefNotifier<int>('recent_ref_count', 5));
final homeRecentTypeProvider = StateNotifierProvider<PrefNotifier<String>, String>((ref) => PrefNotifier<String>('recent_ref_type', 'all'));
final homeRecentSortProvider = StateNotifierProvider<PrefNotifier<String>, String>((ref) => PrefNotifier<String>('recent_ref_sort', 'newest'));
final homeRecentDensityProvider = StateNotifierProvider<PrefNotifier<String>, String>((ref) => PrefNotifier<String>('recent_ref_density', 'comfortable'));
final homeRecentTimeframeProvider = StateNotifierProvider<PrefNotifier<String>, String>((ref) => PrefNotifier<String>('recent_ref_time', 'all'));
