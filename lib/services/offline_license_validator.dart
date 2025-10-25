import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/license_data.dart';
import '../models/license_status.dart';

/// Handles offline license validation with grace period support
class OfflineLicenseValidator {
  static const int _gracePeriodDays = 7;
  static const int _maxOfflineDays = 30; // Maximum days to allow offline usage

  /// Validates a license offline using stored data and grace period logic
  static LicenseStatus validateOffline(
    LicenseData? licenseData,
    DateTime? trialStartDate,
  ) {
    final now = DateTime.now();

    // Check for valid premium license
    if (licenseData != null) {
      return _validatePremiumLicense(licenseData, now);
    }

    // Check for active trial
    if (trialStartDate != null) {
      return _validateTrialLicense(trialStartDate, now);
    }

    return LicenseStatus.free;
  }

  /// Validates premium license with grace period handling
  static LicenseStatus _validatePremiumLicense(
    LicenseData licenseData,
    DateTime now,
  ) {
    // Check if license is expired
    if (licenseData.isExpired) {
      return LicenseStatus.expired;
    }

    // Check validation freshness
    final daysSinceValidation = now
        .difference(licenseData.lastValidated)
        .inDays;

    // If validation is recent (within 24 hours), license is valid
    if (daysSinceValidation < 1) {
      return LicenseStatus.premium;
    }

    // If within grace period, allow continued usage
    if (daysSinceValidation <= _gracePeriodDays) {
      return LicenseStatus.premium;
    }

    // If beyond grace period but within max offline period, mark as validation failed
    if (daysSinceValidation <= _maxOfflineDays) {
      return LicenseStatus.validationFailed;
    }

    // Beyond maximum offline period, consider expired
    return LicenseStatus.expired;
  }

  /// Validates trial license
  static LicenseStatus _validateTrialLicense(
    DateTime trialStartDate,
    DateTime now,
  ) {
    const trialDurationDays = 14; // 14-day trial
    final daysSinceStart = now.difference(trialStartDate).inDays;

    if (daysSinceStart < trialDurationDays) {
      return LicenseStatus.trial;
    } else {
      return LicenseStatus.expired;
    }
  }

  /// Calculates remaining grace period days
  static int getRemainingGraceDays(LicenseData licenseData) {
    final now = DateTime.now();
    final daysSinceValidation = now
        .difference(licenseData.lastValidated)
        .inDays;
    final remainingDays = _gracePeriodDays - daysSinceValidation;
    return remainingDays > 0 ? remainingDays : 0;
  }

  /// Checks if license needs validation (older than 24 hours)
  static bool needsValidation(LicenseData licenseData) {
    final now = DateTime.now();
    final hoursSinceValidation = now
        .difference(licenseData.lastValidated)
        .inHours;
    return hoursSinceValidation >= 24;
  }

  /// Generates a simple offline validation token for additional security
  static String generateOfflineToken(LicenseData licenseData, String deviceId) {
    final data =
        '${licenseData.licenseKey}:${licenseData.purchaseDate.millisecondsSinceEpoch}:$deviceId';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16); // Use first 16 characters
  }

  /// Validates an offline token
  static bool validateOfflineToken(
    String token,
    LicenseData licenseData,
    String deviceId,
  ) {
    final expectedToken = generateOfflineToken(licenseData, deviceId);
    return token == expectedToken;
  }

  /// Checks if the app has been offline for too long
  static bool isOfflineTooLong(LicenseData licenseData) {
    final now = DateTime.now();
    final daysSinceValidation = now
        .difference(licenseData.lastValidated)
        .inDays;
    return daysSinceValidation > _maxOfflineDays;
  }

  /// Gets a user-friendly message for the current license status
  static String getStatusMessage(
    LicenseStatus status,
    LicenseData? licenseData,
  ) {
    switch (status) {
      case LicenseStatus.free:
        return 'You are using the free version. Upgrade to premium for full features.';
      case LicenseStatus.trial:
        return 'You are in trial mode. Enjoy premium features!';
      case LicenseStatus.premium:
        return 'Premium license active. All features unlocked.';
      case LicenseStatus.expired:
        return 'Your license has expired. Please renew to continue using premium features.';
      case LicenseStatus.validationFailed:
        if (licenseData != null) {
          final remainingDays = getRemainingGraceDays(licenseData);
          if (remainingDays > 0) {
            return 'License validation failed. You have $remainingDays days remaining in grace period.';
          } else {
            return 'License validation failed and grace period expired. Please connect to the internet to validate your license.';
          }
        }
        return 'License validation failed. Please connect to the internet.';
    }
  }
}
