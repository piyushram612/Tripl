import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlatformService {
  static const MethodChannel _channel = MethodChannel('com.waypointlattice.tripl/popup');

  /// EventChannel that streams a 'tap' string every time a back tap is detected
  /// while calibration mode is active on the native side.
  static const EventChannel backTapEventChannel =
      EventChannel('com.waypointlattice.tripl/backtap_events');

  // Key for preferences
  static const String _backTapKey = 'back_tap_enabled';

  /// Trigger the native transparent Compose popup activity.
  static Future<void> showPopup() async {
    try {
      await _channel.invokeMethod('showPopup');
    } on PlatformException catch (e) {
      print("Failed to trigger native popup: ${e.message}");
    }
  }

  /// Toggle the background Double Back Tap accelerometer service.
  static Future<void> setBackTapEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setBackTapEnabled', {'enabled': enabled});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_backTapKey, enabled);
    } on PlatformException catch (e) {
      print("Failed to toggle back tap: ${e.message}");
    }
  }

  /// Check if the back tap detector is currently marked as enabled.
  static Future<bool> isBackTapEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(_backTapKey) ?? false;

    // Sync status with native service on startup
    try {
      await _channel.invokeMethod('setBackTapEnabled', {'enabled': isEnabled});
    } catch (_) {}

    return isEnabled;
  }

  /// Tell the native service to enter calibration mode.
  static Future<void> setCalibrationMode(bool enabled) async {
    try {
      await _channel.invokeMethod('setCalibrationMode', {'enabled': enabled});
    } on PlatformException catch (e) {
      print("Failed to set calibration mode: ${e.message}");
    }
  }

  /// Push a new tap window (ms) directly to the running BackTapDetector.
  /// This takes effect immediately — no restart needed.
  static Future<void> setSensitivity(int ms) async {
    try {
      await _channel.invokeMethod('setSensitivity', {'ms': ms});
    } on PlatformException catch (e) {
      print("Failed to set sensitivity: ${e.message}");
    }
  }

  /// Toggle the background Double Back Tap haptic vibration.
  static Future<void> setHapticsEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setHapticsEnabled', {'enabled': enabled});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('haptics_enabled', enabled);
    } on PlatformException catch (e) {
      print("Failed to toggle haptics: ${e.message}");
    }
  }
}
