import 'package:flutter/services.dart';
import '../models/account.dart';

/// Service for running encryption/decryption on native background threads
class PlatformCryptoService {
  static const MethodChannel _channel = MethodChannel('com.simplevault/crypto');

  static bool _isInitialized = false;

  /// Initialize the platform crypto service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _channel.invokeMethod('initialize');
      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize platform crypto: $e');
    }
  }

  /// Check if platform crypto is available
  static Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod('isAvailable');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Encrypt account on native background thread
  static Future<Account> encryptAccount(
    Account account,
    String vaultId,
    String masterPassword,
  ) async {
    await _ensureInitialized();

    try {
      final accountMap = account.toMap();
      // Remove null values to avoid serialization issues
      accountMap.removeWhere((key, value) => value == null);

      final result = await _channel.invokeMethod('encryptAccount', {
        'account': accountMap,
        'vaultId': vaultId,
        'masterPassword': masterPassword,
      });

      return Account.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      throw Exception('Platform encryption failed: ${e.message}');
    }
  }

  /// Decrypt account on native background thread
  static Future<Account> decryptAccount(
    Account account,
    String vaultId,
    String masterPassword,
  ) async {
    await _ensureInitialized();

    try {
      final accountMap = account.toMap();
      // Remove null values to avoid serialization issues
      accountMap.removeWhere((key, value) => value == null);

      final result = await _channel.invokeMethod('decryptAccount', {
        'account': accountMap,
        'vaultId': vaultId,
        'masterPassword': masterPassword,
      });

      return Account.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      throw Exception('Platform decryption failed: ${e.message}');
    }
  }

  /// Decrypt multiple accounts on native background thread
  static Future<List<Account>> decryptAccounts(
    List<Account> accounts,
    String vaultId,
    String masterPassword,
  ) async {
    if (accounts.isEmpty) return [];

    await _ensureInitialized();

    try {
      final accountMaps = accounts.map((account) {
        final map = account.toMap();
        map.removeWhere((key, value) => value == null);
        return map;
      }).toList();

      final result = await _channel.invokeMethod('decryptAccounts', {
        'accounts': accountMaps,
        'vaultId': vaultId,
        'masterPassword': masterPassword,
      });

      final List<dynamic> resultList = List<dynamic>.from(result);
      return resultList
          .map((json) => Account.fromMap(Map<String, dynamic>.from(json)))
          .toList();
    } on PlatformException catch (e) {
      throw Exception('Platform batch decryption failed: ${e.message}');
    }
  }

  /// Derive vault key on native background thread (for key caching)
  static Future<String> deriveVaultKey(
    String vaultId,
    String masterPassword,
  ) async {
    await _ensureInitialized();

    try {
      final result = await _channel.invokeMethod('deriveVaultKey', {
        'vaultId': vaultId,
        'masterPassword': masterPassword,
      });

      return result as String;
    } on PlatformException catch (e) {
      throw Exception('Platform key derivation failed: ${e.message}');
    }
  }

  /// Clear cached keys and sensitive data
  static Future<void> clearCache() async {
    if (!_isInitialized) return;

    try {
      await _channel.invokeMethod('clearCache');
    } catch (e) {
      // Ignore errors during cleanup
    }
  }

  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
}
