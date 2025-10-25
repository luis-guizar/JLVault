import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:argon2/argon2.dart';
import 'package:crypto/crypto.dart';
import '../models/account.dart';
import '../models/totp_config.dart';

/// Enhanced vault encryption service with AES-256-GCM and Argon2id
class VaultEncryptionService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
  );

  static const _vaultKeyPrefix = 'vault_key_v2_';
  static const _vaultSaltPrefix = 'vault_salt_v2_';
  static const _vaultNoncePrefix = 'vault_nonce_v2_';

  // Argon2id parameters for strong key derivation
  static const int _argon2Memory = 65536; // 64MB in KB
  static const int _argon2Iterations = 3;
  static const int _argon2Parallelism = 1;
  static const int _keyLength = 32; // 256-bit key
  static const int _saltLength = 32; // 256-bit salt
  static const int _nonceLength = 12; // GCM nonce length

  /// Generates a cryptographically secure random salt for a vault
  static Uint8List _generateSalt() {
    return encrypt.Key.fromSecureRandom(_saltLength).bytes;
  }

  /// Generates a cryptographically secure random nonce for GCM
  static Uint8List _generateNonce() {
    return encrypt.IV.fromSecureRandom(_nonceLength).bytes;
  }

  /// Derives a vault-specific encryption key using Argon2id
  static Future<Uint8List> _deriveVaultKey(
    String masterPassword,
    Uint8List salt,
  ) async {
    final parameters = Argon2Parameters(
      Argon2Parameters.ARGON2_id, // Argon2id variant for best security
      salt,
      version: Argon2Parameters.ARGON2_VERSION_13,
      iterations: _argon2Iterations,
      memory: _argon2Memory,
      lanes: _argon2Parallelism,
    );

    final argon2Generator = Argon2BytesGenerator();
    argon2Generator.init(parameters);

    final passwordBytes = utf8.encode(masterPassword);
    final keyBytes = Uint8List(_keyLength);
    argon2Generator.generateBytes(passwordBytes, keyBytes, 0, keyBytes.length);

    // Clear password bytes from memory
    passwordBytes.fillRange(0, passwordBytes.length, 0);

    return keyBytes;
  }

  /// Gets or creates the salt for a specific vault
  static Future<Uint8List> _getVaultSalt(String vaultId) async {
    final saltKey = '$_vaultSaltPrefix$vaultId';

    try {
      final saltBase64 = await _storage.read(key: saltKey);
      if (saltBase64 != null) {
        return base64.decode(saltBase64);
      }
    } on PlatformException catch (_) {
      await _storage.delete(key: saltKey);
    }

    // Generate new salt
    final salt = _generateSalt();
    await _storage.write(key: saltKey, value: base64.encode(salt));
    return salt;
  }

  /// Gets or creates the encryption key for a specific vault
  static Future<Uint8List> getVaultKey(
    String vaultId,
    String masterPassword,
  ) async {
    // Always derive key from password for security (no caching of derived keys)
    final salt = await _getVaultSalt(vaultId);
    final key = await _deriveVaultKey(masterPassword, salt);

    return key;
  }

  /// Encrypts data using AES-256-GCM with vault-specific key
  static Future<String> encryptForVault(
    String plainText,
    String vaultId,
    String masterPassword,
  ) async {
    final keyBytes = await getVaultKey(vaultId, masterPassword);
    final key = encrypt.Key(keyBytes);
    final nonce = _generateNonce();
    final iv = encrypt.IV(nonce);

    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.gcm),
    );

    final encrypted = encrypter.encrypt(plainText, iv: iv);

    // Clear key from memory
    keyBytes.fillRange(0, keyBytes.length, 0);

    // Format: nonce:ciphertext:tag (GCM includes authentication tag)
    return '${base64.encode(nonce)}:${encrypted.base64}';
  }

  /// Decrypts data using AES-256-GCM with vault-specific key
  static Future<String> decryptForVault(
    String cipherText,
    String vaultId,
    String masterPassword,
  ) async {
    final keyBytes = await getVaultKey(vaultId, masterPassword);
    final key = encrypt.Key(keyBytes);

    try {
      final parts = cipherText.split(':');
      if (parts.length == 2) {
        // New format: nonce:ciphertext
        final nonce = base64.decode(parts[0]);
        final iv = encrypt.IV(nonce);

        final encrypter = encrypt.Encrypter(
          encrypt.AES(key, mode: encrypt.AESMode.gcm),
        );

        final decrypted = encrypter.decrypt64(parts[1], iv: iv);

        // Clear key from memory
        keyBytes.fillRange(0, keyBytes.length, 0);

        return decrypted;
      } else {
        // Legacy format fallback
        return await _decryptLegacyFormat(cipherText, key);
      }
    } catch (e) {
      // Clear key from memory on error
      keyBytes.fillRange(0, keyBytes.length, 0);
      rethrow;
    }
  }

  /// Handles decryption of legacy formats for backward compatibility
  static Future<String> _decryptLegacyFormat(
    String cipherText,
    encrypt.Key key,
  ) async {
    final parts = cipherText.split(':');

    if (parts.length == 2) {
      try {
        final iv = encrypt.IV.fromBase64(parts[0]);

        // Try GCM mode first
        try {
          final encrypter = encrypt.Encrypter(
            encrypt.AES(key, mode: encrypt.AESMode.gcm),
          );
          return encrypter.decrypt64(parts[1], iv: iv);
        } catch (e) {
          // Fall back to CBC mode
          final encrypter = encrypt.Encrypter(
            encrypt.AES(key, mode: encrypt.AESMode.cbc),
          );
          return encrypter.decrypt64(parts[1], iv: iv);
        }
      } catch (e) {
        // Continue to legacy fallback
      }
    }

    // Legacy decryption without IV (CBC mode)
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );
    final iv = encrypt.IV.fromLength(16);
    return encrypter.decrypt64(cipherText, iv: iv);
  }

  /// Validates that a master password can decrypt vault data
  static Future<bool> validateVaultPassword(
    String vaultId,
    String masterPassword,
    String testCipherText,
  ) async {
    try {
      await decryptForVault(testCipherText, vaultId, masterPassword);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Changes the master password for a vault by re-encrypting all data
  static Future<List<String>> changeVaultMasterPassword(
    String vaultId,
    String oldMasterPassword,
    String newMasterPassword,
    List<String> encryptedData,
  ) async {
    // Decrypt all data with old password
    final decryptedData = <String>[];
    for (final encrypted in encryptedData) {
      final decrypted = await decryptForVault(
        encrypted,
        vaultId,
        oldMasterPassword,
      );
      decryptedData.add(decrypted);
    }

    // Generate new salt for the vault
    await deleteVaultCrypto(vaultId);

    // Encrypt all data with new password
    final reEncryptedData = <String>[];
    for (final plainText in decryptedData) {
      final encrypted = await encryptForVault(
        plainText,
        vaultId,
        newMasterPassword,
      );
      reEncryptedData.add(encrypted);
    }

    // Clear decrypted data from memory
    // Note: Dart strings are immutable, so we can't clear them from memory
    // In a production app, consider using Uint8List for sensitive data

    return reEncryptedData;
  }

  /// Clears cached keys for a vault (for security)
  static Future<void> clearVaultKey(String vaultId) async {
    final keyName = '$_vaultKeyPrefix$vaultId';
    try {
      await _storage.delete(key: keyName);
    } on PlatformException catch (_) {
      // Key might not exist, ignore
    }
  }

  /// Clears all cached vault keys
  static Future<void> clearAllVaultKeys() async {
    try {
      final allKeys = await _storage.readAll();
      for (final key in allKeys.keys) {
        if (key.startsWith(_vaultKeyPrefix)) {
          await _storage.delete(key: key);
        }
      }
    } on PlatformException catch (_) {
      // Ignore errors during cleanup
    }
  }

  /// Deletes all encryption data for a vault (keys, salts, nonces)
  static Future<void> deleteVaultCrypto(String vaultId) async {
    final keyName = '$_vaultKeyPrefix$vaultId';
    final saltName = '$_vaultSaltPrefix$vaultId';
    final nonceName = '$_vaultNoncePrefix$vaultId';

    try {
      await Future.wait([
        _storage.delete(key: keyName),
        _storage.delete(key: saltName),
        _storage.delete(key: nonceName),
      ]);
    } on PlatformException catch (_) {
      // Keys might not exist, ignore
    }
  }

  /// Generates a secure hash of data for integrity checking
  static String generateDataHash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifies data integrity using hash
  static bool verifyDataIntegrity(String data, String expectedHash) {
    final actualHash = generateDataHash(data);
    return actualHash == expectedHash;
  }

  /// Securely wipes sensitive data from memory (best effort)
  static void secureClear(Uint8List data) {
    data.fillRange(0, data.length, 0);
  }

  /// Gets encryption metadata for a vault
  static Future<Map<String, dynamic>> getVaultEncryptionMetadata(
    String vaultId,
  ) async {
    final saltKey = '$_vaultSaltPrefix$vaultId';
    final saltExists = await _storage.containsKey(key: saltKey);

    return {
      'vaultId': vaultId,
      'algorithm': 'AES-256-GCM',
      'keyDerivation': 'Argon2id',
      'keyDerivationParams': {
        'memory': _argon2Memory,
        'iterations': _argon2Iterations,
        'parallelism': _argon2Parallelism,
      },
      'saltExists': saltExists,
      'version': '2.0',
    };
  }

  // Compatibility methods for existing code

  static String? _currentMasterPassword;
  static String _currentVaultId = 'default';

  /// Gets the current master password (for isolate operations)
  static String? get currentMasterPassword => _currentMasterPassword;

  /// Sets the master password for the current session
  static void setMasterPassword(String password) {
    _currentMasterPassword = password;
  }

  /// Clears the master password from memory
  static void clearMasterPassword() {
    _currentMasterPassword = null;
  }

  /// Sets the current vault ID
  static void setCurrentVaultId(String vaultId) {
    _currentVaultId = vaultId;
  }

  /// Encrypts an account using the current vault and master password
  static Future<Account> encryptAccount(Account account) async {
    if (_currentMasterPassword == null) {
      throw Exception('Master password not set');
    }

    final encryptedUsername = await encryptForVault(
      account.username,
      _currentVaultId,
      _currentMasterPassword!,
    );

    final encryptedPassword = await encryptForVault(
      account.password,
      _currentVaultId,
      _currentMasterPassword!,
    );

    String? encryptedTotpConfig;
    if (account.totpConfig != null) {
      encryptedTotpConfig = await encryptForVault(
        jsonEncode(account.totpConfig!.toJson()),
        _currentVaultId,
        _currentMasterPassword!,
      );
    }

    return Account(
      id: account.id,
      vaultId: account.vaultId,
      name: account.name,
      username: encryptedUsername,
      password: encryptedPassword,
      totpConfig: encryptedTotpConfig != null
          ? TOTPConfig.fromJson(jsonDecode(encryptedTotpConfig))
          : null,
      createdAt: account.createdAt,
      modifiedAt: account.modifiedAt,
    );
  }

  /// Decrypts an account using the current vault and master password
  static Future<Account> decryptAccount(Account account) async {
    if (_currentMasterPassword == null) {
      throw Exception('Master password not set');
    }

    final decryptedUsername = await decryptForVault(
      account.username,
      _currentVaultId,
      _currentMasterPassword!,
    );

    final decryptedPassword = await decryptForVault(
      account.password,
      _currentVaultId,
      _currentMasterPassword!,
    );

    TOTPConfig? decryptedTotpConfig;
    if (account.totpConfig != null) {
      // For compatibility, handle both encrypted and unencrypted TOTP configs
      try {
        final decryptedTotpJson = await decryptForVault(
          jsonEncode(account.totpConfig!.toJson()),
          _currentVaultId,
          _currentMasterPassword!,
        );
        decryptedTotpConfig = TOTPConfig.fromJson(
          jsonDecode(decryptedTotpJson),
        );
      } catch (e) {
        // If decryption fails, assume it's already decrypted
        decryptedTotpConfig = account.totpConfig;
      }
    }

    return Account(
      id: account.id,
      vaultId: account.vaultId,
      name: account.name,
      username: decryptedUsername,
      password: decryptedPassword,
      totpConfig: decryptedTotpConfig,
      createdAt: account.createdAt,
      modifiedAt: account.modifiedAt,
    );
  }

  /// Decrypts a list of accounts using the current vault and master password
  static Future<List<Account>> decryptAccounts(List<Account> accounts) async {
    final decryptedAccounts = <Account>[];

    for (final account in accounts) {
      try {
        final decrypted = await decryptAccount(account);
        decryptedAccounts.add(decrypted);
      } catch (e) {
        // Skip accounts that can't be decrypted
        continue;
      }
    }

    return decryptedAccounts;
  }
}
