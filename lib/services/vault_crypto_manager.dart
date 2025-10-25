import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

/// Manages encryption keys and operations for multiple vaults
class VaultCryptoManager {
  static const _storage = FlutterSecureStorage();
  static const _masterKeyPrefix = 'vault_key_';
  static const _saltPrefix = 'vault_salt_';

  /// Derives a vault-specific encryption key from master password and vault salt
  static Future<encrypt.Key> _deriveVaultKey(
    String masterPassword,
    String vaultId,
  ) async {
    // Get or create vault-specific salt
    final saltKey = '$_saltPrefix$vaultId';
    String? saltBase64;

    try {
      saltBase64 = await _storage.read(key: saltKey);
    } on PlatformException catch (_) {
      await _storage.delete(key: saltKey);
    }

    if (saltBase64 == null) {
      // Generate new salt for this vault
      final salt = encrypt.Key.fromSecureRandom(32);
      await _storage.write(key: saltKey, value: salt.base64);
      saltBase64 = salt.base64;
    }

    final salt = base64.decode(saltBase64);

    // Use PBKDF2 to derive key from master password + vault salt
    final key = _pbkdf2(masterPassword, salt, 100000, 32);
    return encrypt.Key(key);
  }

  /// PBKDF2 key derivation function
  static Uint8List _pbkdf2(
    String password,
    Uint8List salt,
    int iterations,
    int keyLength,
  ) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final blocks = <int>[];

    for (int i = 1; i <= (keyLength / 32).ceil(); i++) {
      final block = _pbkdf2Block(hmac, salt, iterations, i);
      blocks.addAll(block);
    }

    return Uint8List.fromList(blocks.take(keyLength).toList());
  }

  static List<int> _pbkdf2Block(
    Hmac hmac,
    Uint8List salt,
    int iterations,
    int blockIndex,
  ) {
    final u = List<int>.filled(32, 0);
    final saltWithIndex = Uint8List(salt.length + 4);
    saltWithIndex.setRange(0, salt.length, salt);
    saltWithIndex.setRange(salt.length, salt.length + 4, [
      (blockIndex >> 24) & 0xff,
      (blockIndex >> 16) & 0xff,
      (blockIndex >> 8) & 0xff,
      blockIndex & 0xff,
    ]);

    var ui = hmac.convert(saltWithIndex).bytes;
    u.setRange(0, ui.length, ui);

    for (int i = 1; i < iterations; i++) {
      ui = hmac.convert(ui).bytes;
      for (int j = 0; j < u.length; j++) {
        u[j] ^= ui[j];
      }
    }

    return u;
  }

  /// Gets or creates the encryption key for a specific vault
  static Future<encrypt.Key> getVaultKey(
    String vaultId,
    String masterPassword,
  ) async {
    final keyName = '$_masterKeyPrefix$vaultId';

    try {
      // Try to get cached key first
      final cachedKey = await _storage.read(key: keyName);
      if (cachedKey != null) {
        return encrypt.Key.fromBase64(cachedKey);
      }
    } on PlatformException catch (_) {
      await _storage.delete(key: keyName);
    }

    // Derive new key and cache it
    final key = await _deriveVaultKey(masterPassword, vaultId);
    await _storage.write(key: keyName, value: key.base64);
    return key;
  }

  /// Encrypts text using vault-specific key
  static Future<String> encryptForVault(
    String plainText,
    String vaultId,
    String masterPassword,
  ) async {
    final key = await getVaultKey(vaultId, masterPassword);
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypts text using vault-specific key
  static Future<String> decryptForVault(
    String cipherText,
    String vaultId,
    String masterPassword,
  ) async {
    final key = await getVaultKey(vaultId, masterPassword);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    final parts = cipherText.split(':');
    if (parts.length == 2) {
      try {
        final iv = encrypt.IV.fromBase64(parts[0]);
        return encrypter.decrypt64(parts[1], iv: iv);
      } catch (e) {
        // Fall back to legacy decryption for backward compatibility
      }
    }

    // Legacy decryption without IV
    final iv = encrypt.IV.fromLength(16);
    return encrypter.decrypt64(cipherText, iv: iv);
  }

  /// Clears cached keys for a vault (useful when switching vaults or on logout)
  static Future<void> clearVaultKey(String vaultId) async {
    final keyName = '$_masterKeyPrefix$vaultId';
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
        if (key.startsWith(_masterKeyPrefix)) {
          await _storage.delete(key: key);
        }
      }
    } on PlatformException catch (_) {
      // Ignore errors during cleanup
    }
  }

  /// Deletes all encryption data for a vault (keys and salts)
  static Future<void> deleteVaultCrypto(String vaultId) async {
    final keyName = '$_masterKeyPrefix$vaultId';
    final saltName = '$_saltPrefix$vaultId';

    try {
      await _storage.delete(key: keyName);
      await _storage.delete(key: saltName);
    } on PlatformException catch (_) {
      // Keys might not exist, ignore
    }
  }

  /// Re-encrypts vault data with a new master password
  static Future<void> changeVaultMasterPassword(
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

    // Clear old key and salt
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

    // Return re-encrypted data (caller should update database)
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
}
