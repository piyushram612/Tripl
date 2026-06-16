import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/biometric_service.dart';

final biometricsEnabledProvider =
    StateNotifierProvider<BiometricsEnabledNotifier, bool>((ref) {
  return BiometricsEnabledNotifier();
});

class BiometricsEnabledNotifier extends StateNotifier<bool> {
  static const _key = 'biometric_lock_enabled';

  BiometricsEnabledNotifier() : super(false) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  /// Toggles the biometric lock. Authenticates the user to verify identity before saving.
  /// Returns true if successful, false if cancelled/failed.
  Future<bool> toggle(bool val) async {
    final hasHardware = await BiometricService.isHardwareAvailable();
    final hasEnrolled = await BiometricService.hasEnrolledBiometrics();

    if (!hasHardware || !hasEnrolled) {
      return false;
    }

    final reason = val
        ? 'Confirm your biometric identity to enable App Lock.'
        : 'Confirm your biometric identity to disable App Lock.';

    final authenticated = await BiometricService.authenticate(reason: reason);
    if (!authenticated) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, val);
    state = val;
    return true;
  }
}

// ─── Current Session Unlock State Provider ───────────────────────────────────

final appUnlockedProvider =
    StateNotifierProvider<AppUnlockedNotifier, bool>((ref) {
  return AppUnlockedNotifier();
});

class AppUnlockedNotifier extends StateNotifier<bool> {
  static const _key = 'biometric_lock_enabled';

  AppUnlockedNotifier() : super(true) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final isLockEnabled = prefs.getBool(_key) ?? false;
    if (isLockEnabled) {
      state = false; // Session starts locked
    } else {
      state = true;  // Session starts unlocked
    }
  }

  void unlock() {
    state = true;
  }

  void lock() {
    state = false;
  }
}

// ─── Biometric Prompt State Provider (to prevent lifecycle loops) ──────────────

final isAuthenticatingProvider = StateProvider<bool>((ref) => false);
