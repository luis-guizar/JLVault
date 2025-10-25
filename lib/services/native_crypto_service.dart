import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/account.dart';

/// Service for using native platform crypto operations
class NativeCryptoService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.simple_vault/crypto',
  );

  /// Encrypts an account using native crypto
  static Future<Account> encryptAccountNative(
    Account account,
    String vaultId,
    String masterPassword,
  ) async {
    try {
      final result = await _channel.invokeMethod('encryptAccount', {
        'account': jsonEncode(account.toMap()),
        'vaultId': vaultId,
        'masterPassword': masterPassword,
      });

      return Account.fromMap(jsonDecode(result));
    } on PlatformException catch (e) {
      throw Exception('Native encryption failed: ${e.message}');
    }
  }

  /// Decrypts an account using native crypto
  static Future<Account> decryptAccountNative(
    Account account,
    String vaultId,
    String masterPassword,
  ) async {
    try {
      final result = await _channel.invokeMethod('decryptAccount', {
        'account': jsonEncode(account.toMap()),
        'vaultId': vaultId,
        'masterPassword': masterPassword,
      });

      return Account.fromMap(jsonDecode(result));
    } on PlatformException catch (e) {
      throw Exception('Native decryption failed: ${e.message}');
    }
  }

  /// Decrypts multiple accounts using native crypto
  static Future<List<Account>> decryptAccountsNative(
    List<Account> accounts,
    String vaultId,
    String masterPassword,
  ) async {
    if (accounts.isEmpty) return [];

    try {
      final accountsJson = accounts.map((a) => a.toMap()).toList();
      final result = await _channel.invokeMethod('decryptAccounts', {
        'accounts': jsonEncode(accountsJson),
        'vaultId': vaultId,
        'masterPassword': masterPassword,
      });

      final List<dynamic> resultList = jsonDecode(result);
      return resultList.map((json) => Account.fromMap(json)).toList();
    } on PlatformException catch (e) {
      throw Exception('Native batch decryption failed: ${e.message}');
    }
  }

  /// Checks if native crypto is available
  static Future<bool> isNativeCryptoAvailable() async {
    try {
      await _channel.invokeMethod('isAvailable');
      return true;
    } catch (e) {
      return false;
    }
  }
}
