import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptionService {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'aes_key';

  static Future<encrypt.Key> _getKey() async {
    String? keyString;

    try {
      keyString = await _storage.read(key: _keyName);
    } on PlatformException catch (_) {
      await _storage.delete(key: _keyName);
    }
    // This logic now runs if the key was null OR if reading it failed
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
    return '${iv.base64}:${encrypted.base64}';
  }

  static Future<String> decryptText(String cipherText) async {
    final key = await _getKey();
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    final parts = cipherText.split(':');
    if (parts.length == 2) {
      try {
        final iv = encrypt.IV.fromBase64(parts[0]);
        return encrypter.decrypt64(parts[1], iv: iv);
      } catch (e) {
        // Hi!
      }
    }
    final iv = encrypt.IV.fromLength(16);
    return encrypter.decrypt64(cipherText, iv: iv);
  }
}
