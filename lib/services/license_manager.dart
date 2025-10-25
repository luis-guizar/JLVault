import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/license_status.dart';
import '../models/license_data.dart';
import 'offline_license_validator.dart';

/// Abstract base class for license management
/// Provides core functionality for license validation and storage
abstract class LicenseManager {
  static const String _licenseDataKey = 'license_data';
  static const String _trialStartKey = 'trial_start_date';
  static const int _trialDurationDays = 14; // 14-day trial period

  final FlutterSecureStorage _secureStorage;
  final StreamController<LicenseStatus> _statusController =
      StreamController<LicenseStatus>.broadcast();

  LicenseStatus _currentStatus = LicenseStatus.free;
  LicenseData? _cachedLicenseData;
  DateTime? _trialStartDate;

  LicenseManager({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Stream of license status changes
  Stream<LicenseStatus> get statusStream => _statusController.stream;

  /// Current license status
  LicenseStatus get currentStatus => _currentStatus;

  /// Cached license data (if available)
  LicenseData? get licenseData => _cachedLicenseData;

  /// Initialize the license manager and load cached data
  Future<void> initialize() async {
    await _loadCachedData();
    await _updateStatus();
  }

  /// Gets the current license status with validation
  Future<LicenseStatus> getCurrentStatus() async {
    await _updateStatus();
    return _currentStatus;
  }

  /// Validates a purchase token and stores license data
  /// Platform-specific implementation required
  Future<bool> validatePurchase(String purchaseToken);

  /// Restores purchases from platform store
  /// Platform-specific implementation required
  Future<bool> restorePurchases();

  /// Starts a trial period for the user
  Future<bool> startTrial() async {
    if (_trialStartDate != null) {
      return false; // Trial already started
    }

    final now = DateTime.now();
    _trialStartDate = now;

    await _secureStorage.write(
      key: _trialStartKey,
      value: now.toIso8601String(),
    );

    await _updateStatus();
    return true;
  }

  /// Checks if user is eligible for trial
  Future<bool> isTrialEligible() async {
    return _trialStartDate == null && _cachedLicenseData == null;
  }

  /// Gets remaining trial days (returns 0 if not in trial)
  Future<int> getRemainingTrialDays() async {
    if (_trialStartDate == null) return 0;

    final daysSinceStart = DateTime.now().difference(_trialStartDate!).inDays;
    final remaining = _trialDurationDays - daysSinceStart;
    return remaining > 0 ? remaining : 0;
  }

  /// Gets remaining grace period days for license validation
  int getRemainingGraceDays() {
    if (_cachedLicenseData == null) return 0;
    return OfflineLicenseValidator.getRemainingGraceDays(_cachedLicenseData!);
  }

  /// Gets a user-friendly status message
  String getStatusMessage() {
    return OfflineLicenseValidator.getStatusMessage(
      _currentStatus,
      _cachedLicenseData,
    );
  }

  /// Checks if the app has been offline for too long
  bool isOfflineTooLong() {
    if (_cachedLicenseData == null) return false;
    return OfflineLicenseValidator.isOfflineTooLong(_cachedLicenseData!);
  }

  /// Stores license data securely
  Future<void> _storeLicenseData(LicenseData licenseData) async {
    _cachedLicenseData = licenseData;
    await _secureStorage.write(
      key: _licenseDataKey,
      value: jsonEncode(licenseData.toJson()),
    );
  }

  /// Protected method for subclasses to store license data
  @protected
  Future<void> storeLicenseData(LicenseData licenseData) async {
    await _storeLicenseData(licenseData);
  }

  /// Loads cached license data from secure storage
  Future<void> _loadCachedData() async {
    try {
      // Load license data
      final licenseDataString = await _secureStorage.read(key: _licenseDataKey);
      if (licenseDataString != null) {
        final licenseDataJson =
            jsonDecode(licenseDataString) as Map<String, dynamic>;
        _cachedLicenseData = LicenseData.fromJson(licenseDataJson);
      }

      // Load trial start date
      final trialStartString = await _secureStorage.read(key: _trialStartKey);
      if (trialStartString != null) {
        _trialStartDate = DateTime.parse(trialStartString);
      }
    } catch (e) {
      // If loading fails, clear corrupted data
      await _clearLicenseData();
    }
  }

  /// Updates the current license status based on cached data and validation
  Future<void> _updateStatus() async {
    final newStatus = await _calculateStatus();

    if (newStatus != _currentStatus) {
      _currentStatus = newStatus;
      _statusController.add(_currentStatus);
    }
  }

  /// Calculates the current license status using offline validator
  Future<LicenseStatus> _calculateStatus() async {
    // Use offline validator for consistent logic
    final status = OfflineLicenseValidator.validateOffline(
      _cachedLicenseData,
      _trialStartDate,
    );

    // If we have cached license data and it needs validation, try to validate online
    if (_cachedLicenseData != null &&
        OfflineLicenseValidator.needsValidation(_cachedLicenseData!)) {
      final validationResult = await _validateCachedLicense();
      if (validationResult) {
        // Validation successful, recalculate status with updated data
        return OfflineLicenseValidator.validateOffline(
          _cachedLicenseData,
          _trialStartDate,
        );
      }
    }

    return status;
  }

  /// Validates cached license with platform store
  /// Platform-specific implementation required
  Future<bool> _validateCachedLicense() async {
    if (_cachedLicenseData == null) return false;

    try {
      final isValid = await validatePurchase(
        _cachedLicenseData!.platformPurchaseId,
      );
      if (isValid) {
        // Update last validated timestamp
        final updatedLicenseData = _cachedLicenseData!.copyWith(
          lastValidated: DateTime.now(),
        );
        await _storeLicenseData(updatedLicenseData);
      }
      return isValid;
    } catch (e) {
      // Network or platform error - assume valid within grace period
      return false;
    }
  }

  /// Clears all license data
  Future<void> _clearLicenseData() async {
    _cachedLicenseData = null;
    _trialStartDate = null;
    await _secureStorage.delete(key: _licenseDataKey);
    await _secureStorage.delete(key: _trialStartKey);
  }

  /// Disposes resources
  void dispose() {
    _statusController.close();
  }
}
