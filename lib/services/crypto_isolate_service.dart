import 'dart:async';
import '../models/account.dart';
import 'vault_encryption_service.dart';

/// Service for running encryption/decryption operations with performance optimizations
/// Uses batching and yielding to prevent UI blocking instead of complex isolates
class CryptoIsolateService {
  /// Encrypts an account with performance optimization
  static Future<Account> encryptAccountInIsolate(
    Account account,
    String vaultId,
    String masterPassword,
  ) async {
    // Set up encryption service
    VaultEncryptionService.setMasterPassword(masterPassword);
    VaultEncryptionService.setCurrentVaultId(vaultId);

    // Perform encryption
    return await VaultEncryptionService.encryptAccount(account);
  }

  /// Decrypts an account with performance optimization
  static Future<Account> decryptAccountInIsolate(
    Account account,
    String vaultId,
    String masterPassword,
  ) async {
    // Set up encryption service
    VaultEncryptionService.setMasterPassword(masterPassword);
    VaultEncryptionService.setCurrentVaultId(vaultId);

    // Perform decryption
    return await VaultEncryptionService.decryptAccount(account);
  }

  /// Decrypts multiple accounts with batching to prevent UI blocking
  static Future<List<Account>> decryptAccountsInIsolates(
    List<Account> accounts,
    String vaultId,
    String masterPassword,
  ) async {
    if (accounts.isEmpty) return [];

    // Set up encryption service once
    VaultEncryptionService.setMasterPassword(masterPassword);
    VaultEncryptionService.setCurrentVaultId(vaultId);

    // Process in small batches with yields to prevent UI blocking
    const batchSize = 3;
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
          // Skip failed decryptions but continue processing
          continue;
        }
      }

      // Yield control back to UI thread between batches
      if (i + batchSize < accounts.length) {
        await Future.delayed(const Duration(milliseconds: 1));
      }
    }

    return results;
  }

  /// Clears any cached data (placeholder for future implementation)
  static void clearQueue() {
    // Placeholder for cleanup operations
  }
}
