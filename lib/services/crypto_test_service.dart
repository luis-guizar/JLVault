import 'package:flutter/foundation.dart';
import '../models/account.dart';
import 'platform_crypto_service.dart';
import 'crypto_isolate_service.dart';

/// Service for testing crypto performance
class CryptoTestService {
  /// Test platform crypto performance vs isolate service
  static Future<Map<String, dynamic>> performanceTest({
    int accountCount = 10,
    String vaultId = 'test_vault',
    String masterPassword = 'test_password_123',
  }) async {
    final results = <String, dynamic>{};

    // Create test accounts
    final testAccounts = List.generate(
      accountCount,
      (index) => Account(
        id: index,
        name: 'Test Account $index',
        username: 'user$index@example.com',
        password: 'password$index',
        vaultId: vaultId,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      ),
    );

    if (kDebugMode) {
      print('Testing crypto performance with $accountCount accounts...');
    }

    // Test platform crypto if available
    if (await PlatformCryptoService.isAvailable()) {
      final platformStopwatch = Stopwatch()..start();

      try {
        // Encrypt all accounts
        final encryptedAccounts = <Account>[];
        for (final account in testAccounts) {
          final encrypted = await PlatformCryptoService.encryptAccount(
            account,
            vaultId,
            masterPassword,
          );
          encryptedAccounts.add(encrypted);
        }

        // Decrypt all accounts
        final decryptedAccounts = await PlatformCryptoService.decryptAccounts(
          encryptedAccounts,
          vaultId,
          masterPassword,
        );

        platformStopwatch.stop();

        results['platform_crypto'] = {
          'available': true,
          'encrypt_decrypt_time_ms': platformStopwatch.elapsedMilliseconds,
          'accounts_processed': decryptedAccounts.length,
          'success': decryptedAccounts.length == accountCount,
        };

        if (kDebugMode) {
          print('Platform crypto: ${platformStopwatch.elapsedMilliseconds}ms');
        }
      } catch (e) {
        results['platform_crypto'] = {
          'available': true,
          'error': e.toString(),
          'success': false,
        };

        if (kDebugMode) {
          print('Platform crypto error: $e');
        }
      }
    } else {
      results['platform_crypto'] = {'available': false, 'success': false};
    }

    // Test isolate service for comparison
    final isolateStopwatch = Stopwatch()..start();

    try {
      // Encrypt all accounts
      final encryptedAccounts = <Account>[];
      for (final account in testAccounts) {
        final encrypted = await CryptoIsolateService.encryptAccountInIsolate(
          account,
          vaultId,
          masterPassword,
        );
        encryptedAccounts.add(encrypted);
      }

      // Decrypt all accounts
      final decryptedAccounts =
          await CryptoIsolateService.decryptAccountsInIsolates(
            encryptedAccounts,
            vaultId,
            masterPassword,
          );

      isolateStopwatch.stop();

      results['isolate_service'] = {
        'encrypt_decrypt_time_ms': isolateStopwatch.elapsedMilliseconds,
        'accounts_processed': decryptedAccounts.length,
        'success': decryptedAccounts.length == accountCount,
      };

      if (kDebugMode) {
        print('Isolate service: ${isolateStopwatch.elapsedMilliseconds}ms');
      }
    } catch (e) {
      results['isolate_service'] = {'error': e.toString(), 'success': false};

      if (kDebugMode) {
        print('Isolate service error: $e');
      }
    }

    // Calculate performance improvement
    if (results['platform_crypto']?['success'] == true &&
        results['isolate_service']?['success'] == true) {
      final platformTime =
          results['platform_crypto']['encrypt_decrypt_time_ms'] as int;
      final isolateTime =
          results['isolate_service']['encrypt_decrypt_time_ms'] as int;

      final improvement = ((isolateTime - platformTime) / isolateTime * 100)
          .round();
      results['performance_improvement_percent'] = improvement;

      if (kDebugMode) {
        print(
          'Performance improvement: ${improvement}% faster with platform crypto',
        );
      }
    }

    return results;
  }

  /// Quick test to verify platform crypto is working
  static Future<bool> quickTest() async {
    try {
      if (!await PlatformCryptoService.isAvailable()) {
        return false;
      }

      final testAccount = Account(
        id: 1,
        name: 'Test Account',
        username: 'test@example.com',
        password: 'test_password',
        vaultId: 'test_vault',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );

      // Encrypt
      final encrypted = await PlatformCryptoService.encryptAccount(
        testAccount,
        'test_vault',
        'master_password',
      );

      // Decrypt
      final decrypted = await PlatformCryptoService.decryptAccount(
        encrypted,
        'test_vault',
        'master_password',
      );

      // Verify data integrity
      return decrypted.username == testAccount.username &&
          decrypted.password == testAccount.password &&
          decrypted.name == testAccount.name;
    } catch (e) {
      if (kDebugMode) {
        print('Platform crypto quick test failed: $e');
      }
      return false;
    }
  }
}
