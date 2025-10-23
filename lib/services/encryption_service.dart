import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptionService {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'aes_key';

  static Future<encrypt.Key> _getKey() async {
    var keyString = await _storage.read(key: _keyName);
    if (keyString == null) {
      final newKey = encrypt.Key.fromSecureRandom(32);
      await _storage.write(key: _keyName, value: newKey.base64);
      keyString = newKey.base64;
    }
    return encrypt.Key.fromBase64(keyString);
  }

  static Future<String> encryptText(String plainText) async {
    final key = await _getKey();
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    // Store IV with encrypted data: IV (base64) + ':' + encrypted data (base64)
    return '${iv.base64}:${encrypted.base64}';
  }

  static Future<String> decryptText(String cipherText) async {
    final key = await _getKey();
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    // Check if data contains IV (new format) or is old format
    final parts = cipherText.split(':');
    if (parts.length == 2) {
      // New format: IV:EncryptedData
      try {
        final iv = encrypt.IV.fromBase64(parts[0]);
        return encrypter.decrypt64(parts[1], iv: iv);
      } catch (e) {
        // Fall through to old format
      }
    }

    // Old format: just encrypted data with zero IV
    final iv = encrypt.IV.fromLength(16);
    return encrypter.decrypt64(cipherText, iv: iv);
  }
}
