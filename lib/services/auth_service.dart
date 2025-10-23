import 'dart:async';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class AuthService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Checks if device supports local authentication (biometrics or device credentials)
  static Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  /// Checks if biometrics are available
  static Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  /// Gets available biometric types (e.g., fingerprint, face)
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      return <BiometricType>[];
    }
  }

  /// Authenticates using any available method (biometric or device credentials)
  static Future<bool> authenticate({
    String reason = 'Unlock Password Manager',
  }) async {
    bool authenticated = false;
    try {
      authenticated = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (e) {
      // Handle platform errors
      print('PlatformException: ${e.message}');
    } catch (e) {
      print('Unexpected error: $e');
    }
    return authenticated;
  }

  /// Authenticates using biometrics only
  static Future<bool> authenticateWithBiometrics({
    String reason = 'Scan your fingerprint to authenticate',
  }) async {
    bool authenticated = false;
    try {
      authenticated = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (e) {
      print('PlatformException: ${e.message}');
    } catch (e) {
      print('Unexpected error: $e');
    }
    return authenticated;
  }

  /// Cancels any ongoing authentication
  static Future<void> cancelAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (e) {
      print('Error stopping authentication: $e');
    }
  }
}
