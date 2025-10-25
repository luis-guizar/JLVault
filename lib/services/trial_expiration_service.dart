import 'dart:async';
import '../models/license_status.dart';
import '../models/premium_feature.dart';
import 'feature_gate.dart';

/// Service that handles trial expiration and graceful feature locking
class TrialExpirationService {
  final FeatureGate _featureGate;
  late StreamSubscription _licenseSubscription;

  final StreamController<TrialExpirationEvent> _eventController =
      StreamController<TrialExpirationEvent>.broadcast();

  TrialExpirationService(this._featureGate) {
    _licenseSubscription = _featureGate.accessStream.listen(_onAccessChanged);
  }

  /// Stream of trial expiration events
  Stream<TrialExpirationEvent> get eventStream => _eventController.stream;

  /// Check if trial is about to expire (within 3 days)
  Future<bool> isTrialAboutToExpire() async {
    final status = await _featureGate.getLicenseStatus();
    if (status != LicenseStatus.trial) return false;

    final remainingDays = await _featureGate.getRemainingTrialDays();
    return remainingDays <= 3 && remainingDays > 0;
  }

  /// Check if trial has just expired
  Future<bool> hasTrialJustExpired() async {
    final status = await _featureGate.getLicenseStatus();
    return status == LicenseStatus.expired;
  }

  /// Get trial expiration warning message
  Future<String?> getExpirationWarning() async {
    final status = await _featureGate.getLicenseStatus();

    if (status == LicenseStatus.trial) {
      final remainingDays = await _featureGate.getRemainingTrialDays();
      if (remainingDays <= 3 && remainingDays > 0) {
        return 'Your trial expires in $remainingDays day${remainingDays == 1 ? '' : 's'}. '
            'Upgrade now to keep your premium features.';
      } else if (remainingDays == 0) {
        return 'Your trial expires today! Upgrade now to avoid losing premium features.';
      }
    } else if (status == LicenseStatus.expired) {
      return 'Your trial has expired. Premium features are now locked. '
          'Upgrade to Premium to restore full access.';
    }

    return null;
  }

  /// Get list of features that will be locked when trial expires
  List<PremiumFeature> getFeaturesToBeLocked() {
    return PremiumFeature.values;
  }

  /// Get user-friendly message about what happens when trial expires
  String getTrialExpirationExplanation() {
    return 'When your trial expires:\n'
        '• You\'ll keep all your existing passwords\n'
        '• Premium features will be locked\n'
        '• Password limit will be reduced to 50\n'
        '• You can upgrade anytime to restore full access';
  }

  /// Handle access changes and emit events
  void _onAccessChanged(Map<PremiumFeature, bool> accessMap) async {
    final status = await _featureGate.getLicenseStatus();

    // Check for trial expiration
    if (status == LicenseStatus.expired) {
      final lockedFeatures = accessMap.entries
          .where((entry) => !entry.value)
          .map((entry) => entry.key)
          .toList();

      if (lockedFeatures.isNotEmpty) {
        _eventController.add(
          TrialExpirationEvent.featuresLocked(lockedFeatures),
        );
      }
    }

    // Check for trial warning
    if (status == LicenseStatus.trial) {
      final remainingDays = await _featureGate.getRemainingTrialDays();
      if (remainingDays <= 3 && remainingDays > 0) {
        _eventController.add(TrialExpirationEvent.trialWarning(remainingDays));
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _licenseSubscription.cancel();
    _eventController.close();
  }
}

/// Events related to trial expiration
class TrialExpirationEvent {
  final TrialExpirationEventType type;
  final List<PremiumFeature>? lockedFeatures;
  final int? remainingDays;

  const TrialExpirationEvent._({
    required this.type,
    this.lockedFeatures,
    this.remainingDays,
  });

  const TrialExpirationEvent.featuresLocked(List<PremiumFeature> features)
    : this._(
        type: TrialExpirationEventType.featuresLocked,
        lockedFeatures: features,
      );

  const TrialExpirationEvent.trialWarning(int days)
    : this._(type: TrialExpirationEventType.trialWarning, remainingDays: days);
}

enum TrialExpirationEventType { featuresLocked, trialWarning }
