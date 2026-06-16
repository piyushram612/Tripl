import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Check if the device is capable of biometric authentication.
  static Future<bool> isHardwareAvailable() async {
    try {
      final bool isSupported = await _auth.isDeviceSupported();
      final bool canCheck = await _auth.canCheckBiometrics;
      return isSupported && canCheck;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Check if there are enrolled biometrics on the device.
  static Future<bool> hasEnrolledBiometrics() async {
    try {
      if (!await isHardwareAvailable()) return false;
      final List<BiometricType> available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Trigger the native authentication dialog.
  /// Returns true if authenticated, false otherwise.
  static Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          biometricOnly: false, // Allows device PIN/passcode fallback
        ),
      );
    } on PlatformException catch (_) {
      return false;
    }
  }
}
