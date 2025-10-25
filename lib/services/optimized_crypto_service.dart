import 'dart:async';
import '../models/account.dart';
import 'vault_encryption_service.dart';

/// Optimized crypto service with caching and batching
class OptimizedCryptoService {
  static final Map<String, String> _keyCache = {};
  static Timer? _cacheCleanupTimer;

  /// Decrypts accounts with optimizations
  static Future<List<Account>> decryptAccountsOptimized(
    List<Account> accounts,
    String vaultId,
    String masterPassword,
  ) async {
    if (accounts.isEmpty) return [];

    // Set up encryption service once
    VaultEncryptionService.setMasterPassword(masterPassword);
    VaultEncryptionService.setCurrentVaultId(vaultId);

    // Process in smaller batches with yields to prevent UI blocking
    const batchSize = 5;
    final List<Account> results = [];

    for (int i = 0; i < accounts.length; i += batchSize) {
      final batch = accounts.skip(i).take(batchSize).toList();

      // Process batch
      for (final account in batch) {
        try {
          final decrypted = await VaultEncryptionService.decryptAccount(
            account,
          );
          results.add(decrypted);
        } catch (e) {
          // Skip failed decryptions
          continue;
        }
      }

      // Yield control back to UI thread between batches
      if (i + batchSize < accounts.length) {
        await Future.delayed(Duration.zero);
      }
    }

    return results;
  }

  /// Encrypts account with caching
  static Future<Account> encryptAccountOptimized(
    Account account,
    String vaultId,
    String masterPassword,
  ) async {
    VaultEncryptionService.setMasterPassword(masterPassword);
    VaultEncryptionService.setCurrentVaultId(vaultId);

    return await VaultEncryptionService.encryptAccount(account);
  }

  /// Clears sensitive caches
  static void clearCaches() {
    _keyCache.clear();
    _cacheCleanupTimer?.cancel();
  }

  /// Schedules cache cleanup
  static void _scheduleCacheCleanup() {
    _cacheCleanupTimer?.cancel();
    _cacheCleanupTimer = Timer(const Duration(minutes: 5), clearCaches);
  }
}
