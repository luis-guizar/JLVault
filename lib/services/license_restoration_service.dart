import 'dart:async';
import 'license_manager_factory.dart';
import 'license_storage.dart';
import '../models/license_status.dart';

/// Service for handling license restoration scenarios
class LicenseRestorationService {
  final LicenseStorage _storage = LicenseStorage();

  /// Attempts to restore purchases from the platform store
  Future<LicenseRestorationResult> restorePurchases() async {
    try {
      final licenseManager = LicenseManagerFactory.getInstance();

      // Initialize the license manager first
      await licenseManager.initialize();

      // Attempt to restore purchases from platform store
      final restoreSuccess = await licenseManager.restorePurchases();

      if (restoreSuccess) {
        // Get the updated status after restoration
        final status = await licenseManager.getCurrentStatus();
        return LicenseRestorationResult.success(status);
      } else {
        return LicenseRestorationResult.noPurchasesFound();
      }
    } catch (e) {
      return LicenseRestorationResult.error('Failed to restore purchases: $e');
    }
  }

  /// Restores license from local storage after app reinstall
  Future<LicenseRestorationResult> restoreFromLocalStorage() async {
    try {
      // Check if we have stored license data
      final licenseData = await _storage.getLicenseData();
      if (licenseData == null) {
        return LicenseRestorationResult.noLocalData();
      }

      // Initialize license manager with restored data
      final licenseManager = LicenseManagerFactory.getInstance();
      await licenseManager.initialize();

      // Validate the restored license
      final isValid = await licenseManager.validatePurchase(
        licenseData.platformPurchaseId,
      );
      if (isValid) {
        final status = await licenseManager.getCurrentStatus();
        return LicenseRestorationResult.success(status);
      } else {
        return LicenseRestorationResult.validationFailed();
      }
    } catch (e) {
      return LicenseRestorationResult.error(
        'Failed to restore from local storage: $e',
      );
    }
  }

  /// Performs a complete restoration attempt (platform + local)
  Future<LicenseRestorationResult> performCompleteRestore() async {
    // First try platform restoration
    final platformResult = await restorePurchases();
    if (platformResult.isSuccess) {
      return platformResult;
    }

    // If platform restoration fails, try local storage
    final localResult = await restoreFromLocalStorage();
    if (localResult.isSuccess) {
      return localResult;
    }

    // If both fail, return the more informative error
    if (platformResult.isError) {
      return platformResult;
    } else if (localResult.isError) {
      return localResult;
    }

    return LicenseRestorationResult.noPurchasesFound();
  }

  /// Checks if restoration is needed (no valid license found)
  Future<bool> needsRestoration() async {
    try {
      final licenseManager = LicenseManagerFactory.getInstance();
      await licenseManager.initialize();

      final status = await licenseManager.getCurrentStatus();
      return status == LicenseStatus.free || status == LicenseStatus.expired;
    } catch (e) {
      return true; // If we can't determine status, assume restoration is needed
    }
  }

  /// Clears all license data (for testing or reset purposes)
  Future<void> clearAllLicenseData() async {
    await _storage.clearAllData();

    final licenseManager = LicenseManagerFactory.getInstance();
    await licenseManager.initialize(); // Reinitialize with cleared data
  }
}

/// Result of a license restoration attempt
class LicenseRestorationResult {
  final bool isSuccess;
  final bool isError;
  final String? errorMessage;
  final LicenseStatus? restoredStatus;
  final LicenseRestorationFailureReason? failureReason;

  const LicenseRestorationResult._({
    required this.isSuccess,
    required this.isError,
    this.errorMessage,
    this.restoredStatus,
    this.failureReason,
  });

  /// Successful restoration
  factory LicenseRestorationResult.success(LicenseStatus status) {
    return LicenseRestorationResult._(
      isSuccess: true,
      isError: false,
      restoredStatus: status,
    );
  }

  /// No purchases found to restore
  factory LicenseRestorationResult.noPurchasesFound() {
    return const LicenseRestorationResult._(
      isSuccess: false,
      isError: false,
      failureReason: LicenseRestorationFailureReason.noPurchasesFound,
    );
  }

  /// No local license data found
  factory LicenseRestorationResult.noLocalData() {
    return const LicenseRestorationResult._(
      isSuccess: false,
      isError: false,
      failureReason: LicenseRestorationFailureReason.noLocalData,
    );
  }

  /// License validation failed
  factory LicenseRestorationResult.validationFailed() {
    return const LicenseRestorationResult._(
      isSuccess: false,
      isError: false,
      failureReason: LicenseRestorationFailureReason.validationFailed,
    );
  }

  /// Error occurred during restoration
  factory LicenseRestorationResult.error(String message) {
    return LicenseRestorationResult._(
      isSuccess: false,
      isError: true,
      errorMessage: message,
    );
  }

  /// Gets a user-friendly message describing the result
  String get message {
    if (isSuccess) {
      return 'License successfully restored! Status: ${restoredStatus?.displayName}';
    }

    if (isError) {
      return errorMessage ?? 'An unknown error occurred during restoration.';
    }

    switch (failureReason) {
      case LicenseRestorationFailureReason.noPurchasesFound:
        return 'No previous purchases found. You may need to purchase premium features.';
      case LicenseRestorationFailureReason.noLocalData:
        return 'No local license data found. Try restoring from the app store.';
      case LicenseRestorationFailureReason.validationFailed:
        return 'License validation failed. Please check your internet connection and try again.';
      case null:
        return 'Restoration failed for an unknown reason.';
    }
  }
}

/// Reasons why license restoration might fail
enum LicenseRestorationFailureReason {
  noPurchasesFound,
  noLocalData,
  validationFailed,
}
