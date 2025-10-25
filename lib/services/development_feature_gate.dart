import 'package:flutter/foundation.dart';
import '../models/premium_feature.dart';
import '../models/license_status.dart';
import 'feature_gate.dart';

/// Development-only feature gate that unlocks all premium features
/// This should ONLY be used during development and testing
class DevelopmentFeatureGate extends FeatureGate {
  DevelopmentFeatureGate(super.licenseManager) {
    if (kDebugMode) {
      debugPrint(
        '🔓 DevelopmentFeatureGate: Initialized - all premium features unlocked',
      );
      debugPrint(
        '🔓 DevelopmentFeatureGate: Available features: ${PremiumFeature.values.map((f) => f.displayName).join(', ')}',
      );
    }
  }

  @override
  bool canAccess(PremiumFeature feature) {
    // For development, allow access to all features
    // In production, this should be removed or gated behind a debug flag
    if (kDebugMode) {
      debugPrint(
        '🔓 DevelopmentFeatureGate: Access granted for ${feature.displayName}',
      );
    }
    return true;
  }

  @override
  Future<FeatureAccessResult> requestAccess(PremiumFeature feature) async {
    if (kDebugMode) {
      debugPrint(
        '🔓 DevelopmentFeatureGate: Request access granted for ${feature.displayName}',
      );
    }
    // Always grant access in development
    return const FeatureAccessResult.granted();
  }

  @override
  Map<PremiumFeature, bool> canAccessMultiple(List<PremiumFeature> features) {
    if (kDebugMode) {
      debugPrint(
        '🔓 DevelopmentFeatureGate: Bulk access granted for ${features.length} features: ${features.map((f) => f.displayName).join(', ')}',
      );
    }
    // Grant access to all requested features
    return {for (final feature in features) feature: true};
  }

  @override
  Map<PremiumFeature, bool> get currentAccess {
    // In development mode, always return true for all features
    final allFeatures = <PremiumFeature, bool>{};
    for (final feature in PremiumFeature.values) {
      allFeatures[feature] = true;
    }
    if (kDebugMode && allFeatures.isNotEmpty) {
      debugPrint(
        '🔓 DevelopmentFeatureGate: Current access map - all ${allFeatures.length} features unlocked',
      );
    }
    return Map.unmodifiable(allFeatures);
  }

  @override
  Future<bool> initiatePurchase() async {
    // Mock successful purchase for development
    return true;
  }

  @override
  Future<bool> restorePurchases() async {
    // Mock successful restore for development
    return true;
  }

  @override
  Future<LicenseStatus> getLicenseStatus() async {
    // Return premium status for development
    return LicenseStatus.premium;
  }

  @override
  Future<int> getRemainingTrialDays() async {
    // Return unlimited trial days for development
    return 999;
  }

  @override
  Future<bool> isTrialEligible() async {
    // Always eligible for trial in development
    return true;
  }

  @override
  Future<bool> startTrial() async {
    // Mock successful trial start
    return true;
  }

  @override
  int getRemainingGraceDays() {
    // Return unlimited grace days for development
    return 999;
  }
}
