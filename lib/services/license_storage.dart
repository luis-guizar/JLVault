import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/license_data.dart';

/// Handles secure storage of license data using platform keychain/keystore
class LicenseStorage {
  static const String _licenseDataKey = 'simple_vault_license_data';
  static const String _trialStartKey = 'simple_vault_trial_start';
  static const String _deviceIdKey = 'simple_vault_device_id';

  final FlutterSecureStorage _secureStorage;

  LicenseStorage({FlutterSecureStorage? secureStorage})
    : _secureStorage =
          secureStorage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              encryptedSharedPreferences: true,
              keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
              storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
            ),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
              synchronizable: false,
            ),
          );

  /// Stores license data securely
  Future<void> storeLicenseData(LicenseData licenseData) async {
    try {
      final jsonString = jsonEncode(licenseData.toJson());
      await _secureStorage.write(key: _licenseDataKey, value: jsonString);
    } catch (e) {
      throw LicenseStorageException('Failed to store license data: $e');
    }
  }

  /// Retrieves stored license data
  Future<LicenseData?> getLicenseData() async {
    try {
      final jsonString = await _secureStorage.read(key: _licenseDataKey);
      if (jsonString == null) return null;

      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return LicenseData.fromJson(jsonMap);
    } catch (e) {
      // If data is corrupted, clear it
      await clearLicenseData();
      return null;
    }
  }

  /// Stores trial start date
  Future<void> storeTrialStartDate(DateTime startDate) async {
    try {
      await _secureStorage.write(
        key: _trialStartKey,
        value: startDate.toIso8601String(),
      );
    } catch (e) {
      throw LicenseStorageException('Failed to store trial start date: $e');
    }
  }

  /// Retrieves trial start date
  Future<DateTime?> getTrialStartDate() async {
    try {
      final dateString = await _secureStorage.read(key: _trialStartKey);
      if (dateString == null) return null;
      return DateTime.parse(dateString);
    } catch (e) {
      // If data is corrupted, clear it
      await clearTrialData();
      return null;
    }
  }

  /// Stores or retrieves unique device identifier
  Future<String> getOrCreateDeviceId() async {
    try {
      String? deviceId = await _secureStorage.read(key: _deviceIdKey);
      if (deviceId == null) {
        // Generate new device ID
        deviceId = _generateDeviceId();
        await _secureStorage.write(key: _deviceIdKey, value: deviceId);
      }
      return deviceId;
    } catch (e) {
      throw LicenseStorageException('Failed to get device ID: $e');
    }
  }

  /// Clears all license-related data
  Future<void> clearLicenseData() async {
    try {
      await _secureStorage.delete(key: _licenseDataKey);
    } catch (e) {
      // Ignore errors when clearing
    }
  }

  /// Clears trial data
  Future<void> clearTrialData() async {
    try {
      await _secureStorage.delete(key: _trialStartKey);
    } catch (e) {
      // Ignore errors when clearing
    }
  }

  /// Clears all stored data
  Future<void> clearAllData() async {
    await clearLicenseData();
    await clearTrialData();
    try {
      await _secureStorage.delete(key: _deviceIdKey);
    } catch (e) {
      // Ignore errors when clearing
    }
  }

  /// Checks if secure storage is available
  Future<bool> isAvailable() async {
    try {
      await _secureStorage.containsKey(key: 'test_key');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Generates a unique device identifier
  String _generateDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp * 31) % 1000000; // Simple pseudo-random
    return 'sv_${timestamp}_$random';
  }
}

/// Exception thrown when license storage operations fail
class LicenseStorageException implements Exception {
  final String message;

  const LicenseStorageException(this.message);

  @override
  String toString() => 'LicenseStorageException: $message';
}
