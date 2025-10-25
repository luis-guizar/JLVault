import 'dart:async';
import '../models/premium_feature.dart';
import '../models/license_status.dart';
import 'license_manager.dart';

/// Result of a feature access request
class FeatureAccessResult {
  final bool hasAccess;
  final String? reason;
  final bool showUpgradePrompt;

  const FeatureAccessResult({
    required this.hasAccess,
    this.reason,
    this.showUpgradePrompt = false,
  });

  const FeatureAccessResult.granted() : this(hasAccess: true);

  const FeatureAccessResult.denied({
    String? reason,
    bool showUpgradePrompt = true,
  }) : this(
         hasAccess: false,
         reason: reason,
         showUpgradePrompt: showUpgradePrompt,
       );
}

/// Abstract base class for feature gating functionality
/// Controls access to premium features based on license status
abstract class FeatureGate {
  final LicenseManager _licenseManager;
  final StreamController<Map<PremiumFeature, bool>> _accessController =
      StreamController<Map<PremiumFeature, bool>>.broadcast();

  late StreamSubscription _licenseSubscription;
  Map<PremiumFeature, bool> _currentAccess = {};

  FeatureGate(this._licenseManager) {
    _initializeAccess();
    _licenseSubscription = _licenseManager.statusStream.listen(
      _onLicenseStatusChanged,
    );
  }

  /// Stream of feature access changes
  Stream<Map<PremiumFeature, bool>> get accessStream =>
      _accessController.stream;

  /// Current feature access map
  Map<PremiumFeature, bool> get currentAccess =>
      Map.unmodifiable(_currentAccess);

  /// Checks if a specific feature can be accessed
  bool canAccess(PremiumFeature feature) {
    return _currentAccess[feature] ?? false;
  }

  /// Requests access to a feature, potentially showing upgrade prompt
  Future<FeatureAccessResult> requestAccess(PremiumFeature feature) async {
    final hasAccess = canAccess(feature);

    if (hasAccess) {
      return const FeatureAccessResult.granted();
    }

    final licenseStatus = await _licenseManager.getCurrentStatus();
    final reason = _getAccessDeniedReason(feature, licenseStatus);

    return FeatureAccessResult.denied(
      reason: reason,
      showUpgradePrompt: _shouldShowUpgradePrompt(feature, licenseStatus),
    );
  }

  /// Checks if multiple features can be accessed
  Map<PremiumFeature, bool> canAccessMultiple(List<PremiumFeature> features) {
    return {for (final feature in features) feature: canAccess(feature)};
  }

  /// Gets the current license status
  Future<LicenseStatus> getLicenseStatus() =>
      _licenseManager.getCurrentStatus();

  /// Gets remaining trial days (0 if not in trial)
  Future<int> getRemainingTrialDays() =>
      _licenseManager.getRemainingTrialDays();

  /// Checks if user is eligible for trial
  Future<bool> isTrialEligible() => _licenseManager.isTrialEligible();

  /// Starts a trial period
  Future<bool> startTrial() => _licenseManager.startTrial();

  /// Gets remaining grace period days for license validation
  int getRemainingGraceDays() => _licenseManager.getRemainingGraceDays();

  /// Platform-specific method to initiate purchase flow
  Future<bool> initiatePurchase();

  /// Platform-specific method to restore purchases
  Future<bool> restorePurchases() => _licenseManager.restorePurchases();

  /// Initialize feature access based on current license status
  void _initializeAccess() {
    _updateFeatureAccess(_licenseManager.currentStatus);
  }

  /// Handle license status changes
  void _onLicenseStatusChanged(LicenseStatus status) {
    _updateFeatureAccess(status);
  }

  /// Update feature access based on license status
  void _updateFeatureAccess(LicenseStatus status) {
    final newAccess = <PremiumFeature, bool>{};

    for (final feature in PremiumFeature.values) {
      newAccess[feature] = _checkFeatureAccess(feature, status);
    }

    if (_hasAccessChanged(newAccess)) {
      _currentAccess = newAccess;
      _accessController.add(Map.unmodifiable(_currentAccess));
    }
  }

  /// Check if access map has changed
  bool _hasAccessChanged(Map<PremiumFeature, bool> newAccess) {
    if (_currentAccess.length != newAccess.length) return true;

    for (final entry in newAccess.entries) {
      if (_currentAccess[entry.key] != entry.value) return true;
    }

    return false;
  }

  /// Check access for a specific feature based on license status
  bool _checkFeatureAccess(PremiumFeature feature, LicenseStatus status) {
    switch (status) {
      case LicenseStatus.premium:
        return true;
      case LicenseStatus.trial:
        return true;
      case LicenseStatus.free:
        return false;
      case LicenseStatus.expired:
        return false;
      case LicenseStatus.validationFailed:
        // During validation failures, maintain access within grace period
        final graceDays = _licenseManager.getRemainingGraceDays();
        return graceDays > 0;
    }
  }

  /// Get reason for access denial
  String _getAccessDeniedReason(PremiumFeature feature, LicenseStatus status) {
    switch (status) {
      case LicenseStatus.free:
        return 'This feature requires Premium. Upgrade to unlock ${feature.displayName}.';
      case LicenseStatus.expired:
        return 'Your trial has expired. Upgrade to Premium to continue using ${feature.displayName}.';
      case LicenseStatus.validationFailed:
        final graceDays = _licenseManager.getRemainingGraceDays();
        if (graceDays > 0) {
          return 'License validation failed. You have $graceDays days remaining in grace period.';
        } else {
          return 'License validation failed and grace period expired. Please check your connection or restore purchases.';
        }
      case LicenseStatus.premium:
      case LicenseStatus.trial:
        return 'Access should be granted'; // This shouldn't happen
    }
  }

  /// Determine if upgrade prompt should be shown
  bool _shouldShowUpgradePrompt(PremiumFeature feature, LicenseStatus status) {
    switch (status) {
      case LicenseStatus.free:
        return true;
      case LicenseStatus.expired:
        return true;
      case LicenseStatus.validationFailed:
        final graceDays = _licenseManager.getRemainingGraceDays();
        return graceDays <= 0;
      case LicenseStatus.premium:
      case LicenseStatus.trial:
        return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _licenseSubscription.cancel();
    _accessController.close();
  }
}
