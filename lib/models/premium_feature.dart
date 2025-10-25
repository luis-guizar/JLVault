/// Enum defining all premium features available in the app
enum PremiumFeature {
  /// Multiple vaults for organizing passwords
  multipleVaults,

  /// TOTP (Time-based One-Time Password) generator
  totpGenerator,

  /// Security health dashboard and analysis
  securityHealth,

  /// Import/export functionality for password data
  importExport,

  /// Peer-to-peer sync between devices
  p2pSync,

  /// Unlimited password storage (free tier limited to 50)
  unlimitedPasswords,

  /// Breach checking with offline HIBP dataset
  breachChecking,
}

/// Extension to provide human-readable descriptions and metadata
extension PremiumFeatureExtension on PremiumFeature {
  /// Display name for the feature
  String get displayName {
    switch (this) {
      case PremiumFeature.multipleVaults:
        return 'Multiple Vaults';
      case PremiumFeature.totpGenerator:
        return 'TOTP Authenticator';
      case PremiumFeature.securityHealth:
        return 'Security Health Dashboard';
      case PremiumFeature.importExport:
        return 'Import/Export';
      case PremiumFeature.p2pSync:
        return 'Device Sync';
      case PremiumFeature.unlimitedPasswords:
        return 'Unlimited Passwords';
      case PremiumFeature.breachChecking:
        return 'Breach Checking';
    }
  }

  /// Short description of the feature
  String get description {
    switch (this) {
      case PremiumFeature.multipleVaults:
        return 'Organize passwords into separate vaults (Personal, Work, Family)';
      case PremiumFeature.totpGenerator:
        return 'Built-in 2FA code generator with QR scanning';
      case PremiumFeature.securityHealth:
        return 'Monitor password strength, reuse, and breach status';
      case PremiumFeature.importExport:
        return 'Import from other password managers and export backups';
      case PremiumFeature.p2pSync:
        return 'Sync passwords between devices without cloud storage';
      case PremiumFeature.unlimitedPasswords:
        return 'Store unlimited passwords (free tier limited to 50)';
      case PremiumFeature.breachChecking:
        return 'Check passwords against breached databases offline';
    }
  }

  /// Icon name for the feature (Material Icons)
  String get iconName {
    switch (this) {
      case PremiumFeature.multipleVaults:
        return 'folder_special';
      case PremiumFeature.totpGenerator:
        return 'security';
      case PremiumFeature.securityHealth:
        return 'health_and_safety';
      case PremiumFeature.importExport:
        return 'import_export';
      case PremiumFeature.p2pSync:
        return 'sync';
      case PremiumFeature.unlimitedPasswords:
        return 'all_inclusive';
      case PremiumFeature.breachChecking:
        return 'shield';
    }
  }

  /// Priority order for displaying features (lower number = higher priority)
  int get priority {
    switch (this) {
      case PremiumFeature.unlimitedPasswords:
        return 1;
      case PremiumFeature.multipleVaults:
        return 2;
      case PremiumFeature.totpGenerator:
        return 3;
      case PremiumFeature.securityHealth:
        return 4;
      case PremiumFeature.p2pSync:
        return 5;
      case PremiumFeature.importExport:
        return 6;
      case PremiumFeature.breachChecking:
        return 7;
    }
  }
}
