import '../models/account.dart';
import '../models/totp_config.dart';
import '../services/vault_crypto_manager.dart';

/// Service that handles encryption/decryption for vault-specific data
class VaultEncryptionService {
  String? _cachedMasterPassword;

  VaultEncryptionService();

  /// Sets the master password for encryption operations
  void setMasterPassword(String masterPassword) {
    _cachedMasterPassword = masterPassword;
  }

  /// Clears the cached master password
  void clearMasterPassword() {
    _cachedMasterPassword = null;
  }

  /// Encrypts an account's sensitive data using vault-specific encryption
  Future<Account> encryptAccount(Account account) async {
    if (_cachedMasterPassword == null) {
      throw VaultEncryptionException('Master password not set');
    }

    final encryptedPassword = await VaultCryptoManager.encryptForVault(
      account.password,
      account.vaultId,
      _cachedMasterPassword!,
    );

    final encryptedUsername = await VaultCryptoManager.encryptForVault(
      account.username,
      account.vaultId,
      _cachedMasterPassword!,
    );

    // Encrypt TOTP configuration if present
    String? encryptedTotpConfig;
    if (account.totpConfig != null) {
      encryptedTotpConfig = await VaultCryptoManager.encryptForVault(
        account.totpConfig!.toJson(),
        account.vaultId,
        _cachedMasterPassword!,
      );
    }

    return account.copyWith(
      password: encryptedPassword,
      username: encryptedUsername,
      totpConfig: encryptedTotpConfig != null
          ? account.totpConfig!.copyWith(secret: encryptedTotpConfig)
          : null,
    );
  }

  /// Decrypts an account's sensitive data using vault-specific encryption
  Future<Account> decryptAccount(Account account) async {
    if (_cachedMasterPassword == null) {
      throw VaultEncryptionException('Master password not set');
    }

    try {
      final decryptedPassword = await VaultCryptoManager.decryptForVault(
        account.password,
        account.vaultId,
        _cachedMasterPassword!,
      );

      final decryptedUsername = await VaultCryptoManager.decryptForVault(
        account.username,
        account.vaultId,
        _cachedMasterPassword!,
      );

      // Decrypt TOTP configuration if present
      TOTPConfig? decryptedTotpConfig;
      if (account.totpConfig != null) {
        try {
          final decryptedTotpJson = await VaultCryptoManager.decryptForVault(
            account
                .totpConfig!
                .secret, // The encrypted JSON is stored in the secret field
            account.vaultId,
            _cachedMasterPassword!,
          );
          decryptedTotpConfig = TOTPConfig.fromJson(decryptedTotpJson);
        } catch (e) {
          // If TOTP decryption fails, log but don't fail the entire account
          print('Failed to decrypt TOTP config for account ${account.id}: $e');
        }
      }

      return account.copyWith(
        password: decryptedPassword,
        username: decryptedUsername,
        totpConfig: decryptedTotpConfig,
      );
    } catch (e) {
      throw VaultEncryptionException('Failed to decrypt account data: $e');
    }
  }

  /// Encrypts a list of accounts
  Future<List<Account>> encryptAccounts(List<Account> accounts) async {
    final encryptedAccounts = <Account>[];
    for (final account in accounts) {
      final encrypted = await encryptAccount(account);
      encryptedAccounts.add(encrypted);
    }
    return encryptedAccounts;
  }

  /// Decrypts a list of accounts
  Future<List<Account>> decryptAccounts(List<Account> accounts) async {
    final decryptedAccounts = <Account>[];
    for (final account in accounts) {
      try {
        final decrypted = await decryptAccount(account);
        decryptedAccounts.add(decrypted);
      } catch (e) {
        // Log error but continue with other accounts
        print('Failed to decrypt account ${account.id}: $e');
        // Add account with placeholder data to indicate decryption failure
        decryptedAccounts.add(
          account.copyWith(
            password: '[Decryption Failed]',
            username: '[Decryption Failed]',
          ),
        );
      }
    }
    return decryptedAccounts;
  }

  /// Validates that the master password can decrypt data for a specific vault
  Future<bool> validateMasterPasswordForVault(
    String vaultId,
    String masterPassword,
  ) async {
    try {
      // Try to get a test account from the vault to validate password
      final testData =
          'test_validation_${DateTime.now().millisecondsSinceEpoch}';
      final encrypted = await VaultCryptoManager.encryptForVault(
        testData,
        vaultId,
        masterPassword,
      );
      final decrypted = await VaultCryptoManager.decryptForVault(
        encrypted,
        vaultId,
        masterPassword,
      );
      return decrypted == testData;
    } catch (e) {
      return false;
    }
  }

  /// Changes the master password for a vault and re-encrypts all data
  Future<void> changeMasterPasswordForVault(
    String vaultId,
    String oldPassword,
    String newPassword,
    List<Account> accounts,
  ) async {
    // Decrypt all accounts with old password
    final oldMasterPassword = _cachedMasterPassword;
    _cachedMasterPassword = oldPassword;

    final decryptedAccounts = <Account>[];
    for (final account in accounts) {
      final decrypted = await decryptAccount(account);
      decryptedAccounts.add(decrypted);
    }

    // Re-encrypt with new password
    _cachedMasterPassword = newPassword;
    final reEncryptedAccounts = <Account>[];
    for (final account in decryptedAccounts) {
      final encrypted = await encryptAccount(account);
      reEncryptedAccounts.add(encrypted);
    }

    // Clear old vault crypto data
    await VaultCryptoManager.deleteVaultCrypto(vaultId);

    // Restore original master password if it was set
    _cachedMasterPassword = oldMasterPassword;
  }

  /// Clears cached encryption keys for a vault
  Future<void> clearVaultKeys(String vaultId) async {
    await VaultCryptoManager.clearVaultKey(vaultId);
  }

  /// Clears all cached encryption keys
  Future<void> clearAllKeys() async {
    await VaultCryptoManager.clearAllVaultKeys();
    _cachedMasterPassword = null;
  }

  /// Deletes all encryption data for a vault
  Future<void> deleteVaultEncryption(String vaultId) async {
    await VaultCryptoManager.deleteVaultCrypto(vaultId);
  }
}

/// Exception thrown by vault encryption operations
class VaultEncryptionException implements Exception {
  final String message;

  const VaultEncryptionException(this.message);

  @override
  String toString() => 'VaultEncryptionException: $message';
}
