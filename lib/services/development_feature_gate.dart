import '../models/premium_feature.dart';
import '../models/license_status.dart';
import 'feature_gate.dart';

/// Development-only feature gate that unlocks all premium features
/// This should ONLY be used during development and testing
class DevelopmentFeatureGate extends FeatureGate {
  DevelopmentFeatureGate(super.licenseManager);

  @override
  bool canAccess(PremiumFeature feature) {
    // For development, allow access to all features
    // In production, this should be removed or gated behind a debug flag
    return true;
  }

  @override
  Future<FeatureAccessResult> requestAccess(PremiumFeature feature) async {
    // Always grant access in development
    return const FeatureAccessResult.granted();
  }

  @override
  Map<PremiumFeature, bool> canAccessMultiple(List<PremiumFeature> features) {
    // Grant access to all requested features
    return {for (final feature in features) feature: true};
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
