/// Represents the current status of the user's license
enum LicenseStatus {
  /// User has not purchased premium features
  free,

  /// User is in trial period with access to premium features
  trial,

  /// User has valid premium license
  premium,

  /// User's trial or license has expired
  expired,

  /// License validation failed (network issues, etc.)
  /// Falls back to cached status with grace period
  validationFailed,
}

/// Extension to provide human-readable descriptions
extension LicenseStatusExtension on LicenseStatus {
  String get displayName {
    switch (this) {
      case LicenseStatus.free:
        return 'Free';
      case LicenseStatus.trial:
        return 'Trial';
      case LicenseStatus.premium:
        return 'Premium';
      case LicenseStatus.expired:
        return 'Expired';
      case LicenseStatus.validationFailed:
        return 'Validation Failed';
    }
  }

  bool get isPremium =>
      this == LicenseStatus.premium || this == LicenseStatus.trial;
  bool get isActive => isPremium;
  bool get needsUpgrade =>
      this == LicenseStatus.free || this == LicenseStatus.expired;
}
