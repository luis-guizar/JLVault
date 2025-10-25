import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:argon2/argon2.dart';

class EncryptionService {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'aes_key';
  static const _saltName = 'aes_salt';

  /// Derives encryption key using Argon2id with strong parameters
  static Future<encrypt.Key> _deriveKey(String password) async {
    // Get or create salt
    String? saltBase64;

    try {
      saltBase64 = await _storage.read(key: _saltName);
    } on PlatformException catch (_) {
      await _storage.delete(key: _saltName);
    }

    if (saltBase64 == null) {
      // Generate new 32-byte salt
      final salt = encrypt.Key.fromSecureRandom(32);
      await _storage.write(key: _saltName, value: salt.base64);
      saltBase64 = salt.base64;
    }

    final salt = base64.decode(saltBase64);

    // Use Argon2id to derive key with strong parameters
    // Parameters: memory: 64MB, iterations: 3, parallelism: 1, key length: 32 bytes
    final parameters = Argon2Parameters(
      Argon2Parameters.ARGON2_id, // Argon2id variant
      salt,
      version: Argon2Parameters.ARGON2_VERSION_13,
      iterations: 3,
      memoryPowerOf2: 16, // 2^16 = 65536 KB = 64MB
      lanes: 1, // parallelism
    );

    final argon2Generator = Argon2BytesGenerator();
    argon2Generator.init(parameters);

    final passwordBytes = parameters.converter.convert(password);
    final keyBytes = Uint8List(32); // 256-bit key
    argon2Generator.generateBytes(passwordBytes, keyBytes, 0, keyBytes.length);

    return encrypt.Key(keyBytes);
  }

  static Future<encrypt.Key> _getKey() async {
    String? keyString;

    try {
      keyString = await _storage.read(key: _keyName);
    } on PlatformException catch (_) {
      await _storage.delete(key: _keyName);
    }

    if (keyString == null) {
      // For backward compatibility, generate a random key if no password-based key exists
      // In a real implementation, this should use a user-provided password
      final newKey = encrypt.Key.fromSecureRandom(32);
      await _storage.write(key: _keyName, value: newKey.base64);
      keyString = newKey.base64;
    }

    return encrypt.Key.fromBase64(keyString);
  }

  static Future<String> encryptText(String plainText) async {
    final key = await _getKey();
    final iv = encrypt.IV.fromSecureRandom(12); // GCM uses 12-byte IV
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.gcm),
    );
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  static Future<String> decryptText(String cipherText) async {
    final key = await _getKey();

    final parts = cipherText.split(':');
    if (parts.length == 2) {
      try {
        final iv = encrypt.IV.fromBase64(parts[0]);

        // Try GCM mode first (new format)
        try {
          final encrypter = encrypt.Encrypter(
            encrypt.AES(key, mode: encrypt.AESMode.gcm),
          );
          return encrypter.decrypt64(parts[1], iv: iv);
        } catch (e) {
          // Fall back to CBC mode for backward compatibility
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
}
