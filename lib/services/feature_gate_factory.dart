import 'dart:io';
import 'package:flutter/foundation.dart';
import 'feature_gate.dart';
import 'android_feature_gate.dart';
import 'development_feature_gate.dart';
import 'license_manager.dart';

/// Factory class for creating platform-specific FeatureGate instances
class FeatureGateFactory {
  /// Enable development mode to unlock all premium features
  /// This should be set to false in production builds
  static const bool _developmentMode =
      kDebugMode; // Automatically true in debug builds

  /// Creates a FeatureGate instance appropriate for the current platform
  static FeatureGate create(LicenseManager licenseManager) {
    // Use development feature gate in debug mode to unlock all features
    if (_developmentMode) {
      return DevelopmentFeatureGate(licenseManager);
    }

    if (Platform.isAndroid) {
      return AndroidFeatureGate(licenseManager);
    } else {
      throw UnsupportedError(
        'FeatureGate is only supported on Android platform. '
        'Current platform: ${Platform.operatingSystem}',
      );
    }
  }

  /// Check if currently running in development mode
  static bool get isDevelopmentMode => _developmentMode;
}
