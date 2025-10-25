import 'package:flutter/foundation.dart';
import 'breach_checking_service.dart';
import 'feature_gate_factory.dart';
import 'license_manager_factory.dart';
import '../models/premium_feature.dart';

/// Development helper functions for testing premium features
class DevelopmentHelpers {
  /// Test HIBP breach checking functionality
  static Future<void> testBreachChecking() async {
    if (!kDebugMode) {
      debugPrint('testBreachChecking: Not in debug mode, skipping test');
      return;
    }

    debugPrint('=== HIBP Breach Checking Test ===');

    // Test feature gate access
    final licenseManager = LicenseManagerFactory.getInstance();
    final featureGate = FeatureGateFactory.create(licenseManager);
    final hasAccess = featureGate.canAccess(PremiumFeature.breachChecking);

    debugPrint('Feature gate access: $hasAccess');
    debugPrint('Development mode: ${FeatureGateFactory.isDevelopmentMode}');

    // Test breach checking service
    try {
      final result = await BreachCheckingService.checkPasswordBreach(
        'password123',
      );
      debugPrint('Breach check result: ${result.isBreached}');
      debugPrint('Breach check error: ${result.error}');

      if (result.error != null) {
        debugPrint('❌ Breach checking failed: ${result.error}');
      } else {
        debugPrint(
          '✅ Breach checking working: Password "password123" is ${result.isBreached ? "breached" : "safe"}',
        );
      }
    } catch (e) {
      debugPrint('❌ Exception during breach check: $e');
    }

    // Test dataset availability
    try {
      final isAvailable = await BreachCheckingService.isDatasetAvailable();
      debugPrint('Dataset available: $isAvailable');

      final info = await BreachCheckingService.getDatasetInfo();
      debugPrint('Dataset info: $info');
    } catch (e) {
      debugPrint('❌ Exception getting dataset info: $e');
    }

    debugPrint('=== End HIBP Test ===');
  }

  /// Test all premium features access
  static Future<void> testAllPremiumFeatures() async {
    if (!kDebugMode) {
      debugPrint('testAllPremiumFeatures: Not in debug mode, skipping test');
      return;
    }

    debugPrint('=== Premium Features Access Test ===');

    final licenseManager = LicenseManagerFactory.getInstance();
    final featureGate = FeatureGateFactory.create(licenseManager);

    for (final feature in PremiumFeature.values) {
      final hasAccess = featureGate.canAccess(feature);
      final status = hasAccess ? '✅' : '❌';
      debugPrint('$status ${feature.displayName}: $hasAccess');
    }

    final licenseStatus = await featureGate.getLicenseStatus();
    debugPrint('License status: $licenseStatus');

    debugPrint('=== End Premium Features Test ===');
  }

  /// Show development mode status
  static void showDevelopmentStatus() {
    if (!kDebugMode) return;

    debugPrint('=== Development Mode Status ===');
    debugPrint('Debug mode: $kDebugMode');
    debugPrint('Development mode: ${FeatureGateFactory.isDevelopmentMode}');
    debugPrint('Profile mode: $kProfileMode');
    debugPrint('Release mode: $kReleaseMode');
    debugPrint('=== End Status ===');
  }
}
