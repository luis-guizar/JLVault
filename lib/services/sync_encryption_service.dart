import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import '../models/sync_protocol.dart';

/// Service for encrypting and decrypting sync data
class SyncEncryptionService {
  final Map<String, Uint8List> _deviceKeys = {};
  final Map<String, Uint8List> _sessionKeys = {};
  final Random _random = Random.secure();

  /// Generate a new device-specific encryption key
  Future<Uint8List> generateDeviceKey(String deviceId) async {
    final key = _generateRandomBytes(32); // 256-bit key
    _deviceKeys[deviceId] = key;
    return key;
  }

  /// Set device key (from pairing process)
  void setDeviceKey(String deviceId, Uint8List key) {
    _deviceKeys[deviceId] = key;
  }

  /// Generate a session key for temporary encryption
  Future<Uint8List> generateSessionKey(String deviceId) async {
    final sessionKey = _generateRandomBytes(32);
    _sessionKeys[deviceId] = sessionKey;
    return sessionKey;
  }

  /// Encrypt sync data for transmission
  Future<EncryptedSyncPacket> encryptSyncData({
    required String deviceId,
    required Map<String, dynamic> data,
    bool useSessionKey = false,
  }) async {
    final key = useSessionKey ? _sessionKeys[deviceId] : _deviceKeys[deviceId];

    if (key == null) {
      throw SyncEncryptionException(
        'No encryption key found for device: $deviceId',
      );
    }

    try {
      // Convert data to JSON bytes
      final jsonData = jsonEncode(data);
      final dataBytes = utf8.encode(jsonData);

      // Generate nonce
      final nonce = _generateRandomBytes(12); // 96-bit nonce for AES-GCM

      // Encrypt data using AES-GCM
      final encrypter = Encrypter(AES(Key(key), mode: AESMode.gcm));
      final iv = IV(nonce);
      final encrypted = encrypter.encryptBytes(dataBytes, iv: iv);

      // Create signature
      final signature = _createSignature(encrypted.bytes, key);

      return EncryptedSyncPacket(
        deviceId: deviceId,
        nonce: base64Encode(nonce),
        encryptedData: encrypted.bytes,
        signature: signature,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      throw SyncEncryptionException(
        'Failed to encrypt sync data: ${e.toString()}',
      );
    }
  }

  /// Decrypt sync data from transmission
  Future<Map<String, dynamic>> decryptSyncData({
    required EncryptedSyncPacket packet,
    bool useSessionKey = false,
  }) async {
    final key = useSessionKey
        ? _sessionKeys[packet.deviceId]
        : _deviceKeys[packet.deviceId];

    if (key == null) {
      throw SyncEncryptionException(
        'No decryption key found for device: ${packet.deviceId}',
      );
    }

    try {
      // Verify signature
      final expectedSignature = _createSignature(packet.encryptedData, key);
      if (packet.signature != expectedSignature) {
        throw SyncEncryptionException(
          'Invalid signature - data may be tampered',
        );
      }

      // Decrypt data
      final nonce = base64Decode(packet.nonce);
      final encrypter = Encrypter(AES(Key(key), mode: AESMode.gcm));
      final iv = IV(nonce);
      final encrypted = Encrypted(packet.encryptedData);

      final decryptedBytes = encrypter.decryptBytes(encrypted, iv: iv);
      final jsonString = utf8.decode(decryptedBytes);

      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw SyncEncryptionException(
        'Failed to decrypt sync data: ${e.toString()}',
      );
    }
  }

  /// Encrypt individual vault entry data
  Future<Uint8List> encryptEntryData({
    required String deviceId,
    required Map<String, dynamic> entryData,
  }) async {
    final key = _deviceKeys[deviceId];
    if (key == null) {
      throw SyncEncryptionException(
        'No encryption key found for device: $deviceId',
      );
    }

    try {
      final jsonData = jsonEncode(entryData);
      final dataBytes = utf8.encode(jsonData);

      final nonce = _generateRandomBytes(12);
      final encrypter = Encrypter(AES(Key(key), mode: AESMode.gcm));
      final iv = IV(nonce);
      final encrypted = encrypter.encryptBytes(dataBytes, iv: iv);

      // Combine nonce + encrypted data
      final result = Uint8List(nonce.length + encrypted.bytes.length);
      result.setRange(0, nonce.length, nonce);
      result.setRange(nonce.length, result.length, encrypted.bytes);

      return result;
    } catch (e) {
      throw SyncEncryptionException(
        'Failed to encrypt entry data: ${e.toString()}',
      );
    }
  }

  /// Decrypt individual vault entry data
  Future<Map<String, dynamic>> decryptEntryData({
    required String deviceId,
    required Uint8List encryptedData,
  }) async {
    final key = _deviceKeys[deviceId];
    if (key == null) {
      throw SyncEncryptionException(
        'No decryption key found for device: $deviceId',
      );
    }

    try {
      // Extract nonce and encrypted data
      final nonce = encryptedData.sublist(0, 12);
      final ciphertext = encryptedData.sublist(12);

      final encrypter = Encrypter(AES(Key(key), mode: AESMode.gcm));
      final iv = IV(nonce);
      final encrypted = Encrypted(ciphertext);

      final decryptedBytes = encrypter.decryptBytes(encrypted, iv: iv);
      final jsonString = utf8.decode(decryptedBytes);

      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw SyncEncryptionException(
        'Failed to decrypt entry data: ${e.toString()}',
      );
    }
  }

  /// Derive a shared key from two device keys (for key exchange)
  Future<Uint8List> deriveSharedKey(
    Uint8List localKey,
    Uint8List remoteKey,
  ) async {
    // Simple key derivation - in production, use proper ECDH
    final combined = Uint8List(localKey.length + remoteKey.length);
    combined.setRange(0, localKey.length, localKey);
    combined.setRange(localKey.length, combined.length, remoteKey);

    final digest = sha256.convert(combined);
    return Uint8List.fromList(digest.bytes);
  }

  /// Create HMAC signature for data integrity
  String _createSignature(Uint8List data, Uint8List key) {
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(data);
    return base64Encode(digest.bytes);
  }

  /// Generate cryptographically secure random bytes
  Uint8List _generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  /// Clear all encryption keys (for security)
  void clearKeys() {
    _deviceKeys.clear();
    _sessionKeys.clear();
  }

  /// Clear keys for a specific device
  void clearDeviceKeys(String deviceId) {
    _deviceKeys.remove(deviceId);
    _sessionKeys.remove(deviceId);
  }

  /// Check if device key exists
  bool hasDeviceKey(String deviceId) {
    return _deviceKeys.containsKey(deviceId);
  }

  /// Get device key (for testing/debugging only)
  Uint8List? getDeviceKey(String deviceId) {
    return _deviceKeys[deviceId];
  }
}

/// Exception thrown when sync encryption operations fail
class SyncEncryptionException implements Exception {
  final String message;
  final dynamic originalError;

  const SyncEncryptionException(this.message, {this.originalError});

  @override
  String toString() {
    return 'SyncEncryptionException: $message';
  }
}
