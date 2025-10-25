import '../data/db_helper.dart';
import '../models/license_status.dart';
import 'feature_gate.dart';

/// Service that manages password limits for free users
class PasswordLimitService {
  static const int _freeUserPasswordLimit = 50;

  final FeatureGate _featureGate;

  PasswordLimitService(this._featureGate);

  /// Gets the maximum number of passwords allowed for current license
  Future<int> getPasswordLimit() async {
    final status = await _featureGate.getLicenseStatus();

    switch (status) {
      case LicenseStatus.premium:
      case LicenseStatus.trial:
        return -1; // Unlimited
      case LicenseStatus.free:
      case LicenseStatus.expired:
      case LicenseStatus.validationFailed:
        return _freeUserPasswordLimit;
    }
  }

  /// Checks if user can add more passwords
  Future<bool> canAddPassword() async {
    final limit = await getPasswordLimit();
    if (limit == -1) return true; // Unlimited

    final currentCount = await getCurrentPasswordCount();
    return currentCount < limit;
  }

  /// Gets the current number of passwords stored
  Future<int> getCurrentPasswordCount() async {
    final accounts = await DBHelper.getAll();
    return accounts.length;
  }

  /// Gets remaining password slots for free users
  Future<int> getRemainingPasswordSlots() async {
    final limit = await getPasswordLimit();
    if (limit == -1) return -1; // Unlimited

    final currentCount = await getCurrentPasswordCount();
    return (limit - currentCount).clamp(0, limit);
  }

  /// Checks if user has reached the password limit
  Future<bool> hasReachedLimit() async {
    final canAdd = await canAddPassword();
    return !canAdd;
  }

  /// Gets a user-friendly message about password limits
  Future<String> getLimitMessage() async {
    final status = await _featureGate.getLicenseStatus();
    final currentCount = await getCurrentPasswordCount();
    final limit = await getPasswordLimit();

    switch (status) {
      case LicenseStatus.premium:
        return 'Premium: Unlimited passwords ($currentCount stored)';
      case LicenseStatus.trial:
        final remainingDays = await _featureGate.getRemainingTrialDays();
        return 'Trial: Unlimited passwords ($currentCount stored, $remainingDays days remaining)';
      case LicenseStatus.free:
        final remaining = await getRemainingPasswordSlots();
        if (remaining > 0) {
          return 'Free: $currentCount/$limit passwords ($remaining remaining)';
        } else {
          return 'Free: $currentCount/$limit passwords (limit reached)';
        }
      case LicenseStatus.expired:
        return 'Trial expired: $currentCount/$limit passwords (upgrade to unlock unlimited)';
      case LicenseStatus.validationFailed:
        final graceDays = _featureGate.getRemainingGraceDays();
        if (graceDays > 0) {
          return 'License validation failed: $currentCount passwords ($graceDays grace days remaining)';
        } else {
          return 'License validation failed: $currentCount/$limit passwords (please restore purchases)';
        }
    }
  }

  /// Gets a short status indicator for UI
  Future<String> getStatusIndicator() async {
    final status = await _featureGate.getLicenseStatus();
    final currentCount = await getCurrentPasswordCount();

    switch (status) {
      case LicenseStatus.premium:
        return '$currentCount passwords';
      case LicenseStatus.trial:
        final remainingDays = await _featureGate.getRemainingTrialDays();
        return '$currentCount passwords (Trial: ${remainingDays}d)';
      case LicenseStatus.free:
        final limit = await getPasswordLimit();
        return '$currentCount/$limit passwords';
      case LicenseStatus.expired:
        final limit = await getPasswordLimit();
        return '$currentCount/$limit passwords (Expired)';
      case LicenseStatus.validationFailed:
        final graceDays = _featureGate.getRemainingGraceDays();
        if (graceDays > 0) {
          return '$currentCount passwords (Grace: ${graceDays}d)';
        } else {
          final limit = await getPasswordLimit();
          return '$currentCount/$limit passwords (Validation Failed)';
        }
    }
  }
}
