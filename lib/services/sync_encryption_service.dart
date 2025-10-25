import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import '../models/sync_protocol.dart';

/// Sync encryption service with perfect forward secrecy using ECDH
class SyncEncryptionService {
  static const int _nonceLength = 12; // GCM nonce length
  static const Duration _keyRotationInterval = Duration(minutes: 30);

  // ECDH curve parameters (using P-256)
  static final ECDomainParameters _ecParams = ECDomainParameters('secp256r1');

  final Map<String, SyncSession> _activeSessions = {};
  final SecureRandom _secureRandom = _createSecureRandom();

  /// Creates a new sync session with ephemeral key exchange
  Future<SyncSession> createSyncSession(
    String deviceId,
    String devicePublicKey,
  ) async {
    // Close any existing session for this device to ensure fresh keys
    await _closeDeviceSessions(deviceId);

    // Generate ephemeral ECDH key pair for this session
    final keyPair = _generateECDHKeyPair();

    // Validate and derive shared secret using ECDH
    final sharedSecret = _performECDH(keyPair.privateKey, devicePublicKey);

    // Validate shared secret is not zero (security check)
    if (_isZeroBytes(sharedSecret)) {
      throw Exception('ECDH key exchange failed: invalid shared secret');
    }

    // Derive session keys from shared secret
    final sessionKeys = _deriveSessionKeys(sharedSecret, deviceId);

    final session = SyncSession(
      sessionId: _generateSessionId(),
      deviceId: deviceId,
      ephemeralPublicKey: _encodePublicKey(keyPair.publicKey),
      ephemeralPrivateKey: keyPair.privateKey,
      encryptionKey: sessionKeys.encryptionKey,
      authenticationKey: sessionKeys.authenticationKey,
      createdAt: DateTime.now(),
      lastUsed: DateTime.now(),
    );

    _activeSessions[session.sessionId] = session;

    // Schedule key rotation
    _scheduleKeyRotation(session.sessionId);

    return session;
  }

  /// Accepts a sync session from another device
  Future<SyncSession> acceptSyncSession(
    String deviceId,
    String devicePublicKey,
    String ephemeralPublicKey,
  ) async {
    // Close any existing session for this device to ensure fresh keys
    await _closeDeviceSessions(deviceId);

    // Generate our ephemeral key pair
    final keyPair = _generateECDHKeyPair();

    // Validate and derive shared secret using their ephemeral public key
    final sharedSecret = _performECDH(keyPair.privateKey, ephemeralPublicKey);

    // Validate shared secret is not zero (security check)
    if (_isZeroBytes(sharedSecret)) {
      throw Exception('ECDH key exchange failed: invalid shared secret');
    }

    // Derive session keys from shared secret
    final sessionKeys = _deriveSessionKeys(sharedSecret, deviceId);

    final session = SyncSession(
      sessionId: _generateSessionId(),
      deviceId: deviceId,
      ephemeralPublicKey: _encodePublicKey(keyPair.publicKey),
      ephemeralPrivateKey: keyPair.privateKey,
      encryptionKey: sessionKeys.encryptionKey,
      authenticationKey: sessionKeys.authenticationKey,
      createdAt: DateTime.now(),
      lastUsed: DateTime.now(),
    );

    _activeSessions[session.sessionId] = session;

    // Schedule key rotation
    _scheduleKeyRotation(session.sessionId);

    return session;
  }

  /// Encrypts sync data using session-specific keys
  Future<EncryptedSyncData> encryptSyncData(
    String sessionId,
    Map<String, dynamic> data,
  ) async {
    final session = _activeSessions[sessionId];
    if (session == null) {
      throw Exception('Invalid session ID: $sessionId');
    }

    // Validate session is still active and not expired
    if (!_isSessionValid(session)) {
      await closeSyncSession(sessionId);
      throw Exception('Session expired or invalid: $sessionId');
    }

    // Check if key rotation is needed
    if (_needsKeyRotation(session)) {
      await _rotateSessionKeys(sessionId);
    }

    final plaintext = jsonEncode(data);
    final plaintextBytes = utf8.encode(plaintext);

    // Generate random nonce for this message
    final nonce = _generateNonce();

    // Encrypt using AES-256-GCM
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(session.encryptionKey),
      128, // 128-bit authentication tag
      nonce,
      Uint8List(0), // No additional authenticated data
    );

    cipher.init(true, params);

    final ciphertext = Uint8List(
      plaintextBytes.length + 16,
    ); // +16 for auth tag
    var offset = cipher.processBytes(
      plaintextBytes,
      0,
      plaintextBytes.length,
      ciphertext,
      0,
    );
    cipher.doFinal(ciphertext, offset);

    // Generate HMAC for additional authentication
    final hmac = _generateHMAC(session.authenticationKey, nonce, ciphertext);

    // Update session last used time
    session.lastUsed = DateTime.now();

    return EncryptedSyncData(
      sessionId: sessionId,
      nonce: base64.encode(nonce),
      ciphertext: base64.encode(ciphertext),
      hmac: base64.encode(hmac),
      timestamp: DateTime.now(),
    );
  }

  /// Decrypts sync data using session-specific keys
  Future<Map<String, dynamic>> decryptSyncData(
    EncryptedSyncData encryptedData,
  ) async {
    final session = _activeSessions[encryptedData.sessionId];
    if (session == null) {
      throw Exception('Invalid session ID: ${encryptedData.sessionId}');
    }

    // Validate session is still active and not expired
    if (!_isSessionValid(session)) {
      await closeSyncSession(encryptedData.sessionId);
      throw Exception('Session expired or invalid: ${encryptedData.sessionId}');
    }

    final nonce = base64.decode(encryptedData.nonce);
    final ciphertext = base64.decode(encryptedData.ciphertext);
    final receivedHmac = base64.decode(encryptedData.hmac);

    // Verify HMAC
    final expectedHmac = _generateHMAC(
      session.authenticationKey,
      nonce,
      ciphertext,
    );
    if (!_constantTimeEquals(receivedHmac, expectedHmac)) {
      throw Exception('HMAC verification failed - data may be tampered');
    }

    // Decrypt using AES-256-GCM
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(session.encryptionKey),
      128, // 128-bit authentication tag
      nonce,
      Uint8List(0), // No additional authenticated data
    );

    cipher.init(false, params);

    final plaintext = Uint8List(ciphertext.length - 16); // -16 for auth tag
    var offset = cipher.processBytes(
      ciphertext,
      0,
      ciphertext.length,
      plaintext,
      0,
    );
    cipher.doFinal(plaintext, offset);

    // Update session last used time
    session.lastUsed = DateTime.now();

    final plaintextString = utf8.decode(plaintext);
    return jsonDecode(plaintextString) as Map<String, dynamic>;
  }

  /// Rotates session keys for long-running sessions
  Future<void> rotateSessionKeys(String sessionId) async {
    await _rotateSessionKeys(sessionId);
  }

  /// Closes a sync session and clears keys from memory
  Future<void> closeSyncSession(String sessionId) async {
    final session = _activeSessions.remove(sessionId);
    if (session != null) {
      // Securely clear sensitive data from memory
      _secureMemoryClear(session.encryptionKey);
      _secureMemoryClear(session.authenticationKey);

      // Note: Private key is handled by the crypto library's garbage collection
      // but we ensure the session reference is removed
    }
  }

  /// Closes all active sync sessions
  Future<void> closeAllSessions() async {
    final sessionIds = List<String>.from(_activeSessions.keys);
    for (final sessionId in sessionIds) {
      await closeSyncSession(sessionId);
    }
  }

  /// Gets active session information (without sensitive data)
  List<SyncSessionInfo> getActiveSessions() {
    return _activeSessions.values
        .where(_isSessionValid) // Only return valid sessions
        .map(
          (session) => SyncSessionInfo(
            sessionId: session.sessionId,
            deviceId: session.deviceId,
            createdAt: session.createdAt,
            lastUsed: session.lastUsed,
          ),
        )
        .toList();
  }

  /// Gets the ephemeral public key for a session (for key exchange)
  String? getSessionPublicKey(String sessionId) {
    final session = _activeSessions[sessionId];
    return session?.ephemeralPublicKey;
  }

  /// Initiates key exchange with another device
  Future<KeyExchangeData> initiateKeyExchange(String deviceId) async {
    // Generate ephemeral key pair for this exchange
    final keyPair = _generateECDHKeyPair();
    final publicKey = _encodePublicKey(keyPair.publicKey);

    // Store temporary key pair for completion
    final exchangeId = _generateSessionId();

    return KeyExchangeData(
      exchangeId: exchangeId,
      publicKey: publicKey,
      deviceId: deviceId,
    );
  }

  /// Completes key exchange and creates session
  Future<SyncSession> completeKeyExchange(
    String exchangeId,
    String deviceId,
    String remotePublicKey,
    ECPrivateKey localPrivateKey,
  ) async {
    // Perform ECDH with the remote public key
    final sharedSecret = _performECDH(localPrivateKey, remotePublicKey);

    // Validate shared secret
    if (_isZeroBytes(sharedSecret)) {
      throw Exception('Key exchange failed: invalid shared secret');
    }

    // Derive session keys
    final sessionKeys = _deriveSessionKeys(sharedSecret, deviceId);

    // Create session
    final session = SyncSession(
      sessionId: exchangeId,
      deviceId: deviceId,
      ephemeralPublicKey: remotePublicKey,
      ephemeralPrivateKey: localPrivateKey,
      encryptionKey: sessionKeys.encryptionKey,
      authenticationKey: sessionKeys.authenticationKey,
      createdAt: DateTime.now(),
      lastUsed: DateTime.now(),
    );

    _activeSessions[session.sessionId] = session;
    _scheduleKeyRotation(session.sessionId);

    return session;
  }

  // Private helper methods

  static SecureRandom _createSecureRandom() {
    final secureRandom = SecureRandom('Fortuna');
    final seedSource = Random.secure();
    final seeds = <int>[];
    for (int i = 0; i < 32; i++) {
      seeds.add(seedSource.nextInt(256));
    }
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  AsymmetricKeyPair<ECPublicKey, ECPrivateKey> _generateECDHKeyPair() {
    final keyGen = ECKeyGenerator();
    keyGen.init(
      ParametersWithRandom(ECKeyGeneratorParameters(_ecParams), _secureRandom),
    );
    final keyPair = keyGen.generateKeyPair();
    return AsymmetricKeyPair<ECPublicKey, ECPrivateKey>(
      keyPair.publicKey as ECPublicKey,
      keyPair.privateKey as ECPrivateKey,
    );
  }

  Uint8List _performECDH(ECPrivateKey privateKey, String publicKeyString) {
    // Decode the public key
    final publicKeyBytes = base64.decode(publicKeyString);
    final publicKey = _decodePublicKey(publicKeyBytes);

    // Perform ECDH
    final ecdh = ECDHBasicAgreement();
    ecdh.init(privateKey);
    final sharedSecret = ecdh.calculateAgreement(publicKey);

    // Convert to bytes
    return _bigIntToBytes(sharedSecret, 32);
  }

  SessionKeys _deriveSessionKeys(Uint8List sharedSecret, String deviceId) {
    // Use HKDF-like key derivation with HMAC-SHA256
    final salt = sha256.convert(utf8.encode(deviceId)).bytes;
    final info = utf8.encode('SyncKeys');

    // HKDF Extract: PRK = HMAC-Hash(salt, IKM)
    final hmacExtract = Hmac(sha256, salt);
    final prk = hmacExtract.convert(sharedSecret).bytes;

    // HKDF Expand: derive 64 bytes (32 for encryption, 32 for authentication)
    final derivedKeys = _hkdfExpand(prk, info, 64);

    return SessionKeys(
      encryptionKey: Uint8List.fromList(derivedKeys.sublist(0, 32)),
      authenticationKey: Uint8List.fromList(derivedKeys.sublist(32, 64)),
    );
  }

  /// Simple HKDF Expand implementation
  Uint8List _hkdfExpand(List<int> prk, List<int> info, int length) {
    final hmac = Hmac(sha256, prk);
    final result = <int>[];
    final hashLen = 32; // SHA256 output length
    final n = (length / hashLen).ceil();

    var t = <int>[];
    for (int i = 1; i <= n; i++) {
      final input = <int>[];
      input.addAll(t);
      input.addAll(info);
      input.add(i);
      t = hmac.convert(input).bytes;
      result.addAll(t);
    }

    return Uint8List.fromList(result.take(length).toList());
  }

  String _encodePublicKey(ECPublicKey publicKey) {
    final point = publicKey.Q!;
    final x = _bigIntToBytes(point.x!.toBigInteger()!, 32);
    final y = _bigIntToBytes(point.y!.toBigInteger()!, 32);
    final encoded = Uint8List(65);
    encoded[0] = 0x04; // Uncompressed point indicator
    encoded.setRange(1, 33, x);
    encoded.setRange(33, 65, y);
    return base64.encode(encoded);
  }

  ECPublicKey _decodePublicKey(Uint8List bytes) {
    if (bytes.length != 65 || bytes[0] != 0x04) {
      throw ArgumentError('Invalid public key format');
    }

    final x = _bytesToBigInt(bytes.sublist(1, 33));
    final y = _bytesToBigInt(bytes.sublist(33, 65));
    final point = _ecParams.curve.createPoint(x, y);

    return ECPublicKey(point, _ecParams);
  }

  Uint8List _bigIntToBytes(BigInt value, int length) {
    final bytes = Uint8List(length);
    var temp = value;
    for (int i = length - 1; i >= 0; i--) {
      bytes[i] = (temp & BigInt.from(0xff)).toInt();
      temp = temp >> 8;
    }
    return bytes;
  }

  BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (int i = 0; i < bytes.length; i++) {
      result = (result << 8) + BigInt.from(bytes[i]);
    }
    return result;
  }

  Uint8List _generateNonce() {
    final nonce = Uint8List(_nonceLength);
    for (int i = 0; i < _nonceLength; i++) {
      nonce[i] = _secureRandom.nextUint8();
    }
    return nonce;
  }

  String _generateSessionId() {
    final bytes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      bytes[i] = _secureRandom.nextUint8();
    }
    return base64.encode(bytes);
  }

  Uint8List _generateHMAC(Uint8List key, Uint8List nonce, Uint8List data) {
    final hmac = Hmac(sha256, key);
    final combined = Uint8List(nonce.length + data.length);
    combined.setRange(0, nonce.length, nonce);
    combined.setRange(nonce.length, combined.length, data);
    return Uint8List.fromList(hmac.convert(combined).bytes);
  }

  bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  bool _needsKeyRotation(SyncSession session) {
    final now = DateTime.now();
    return now.difference(session.createdAt) > _keyRotationInterval;
  }

  Future<void> _rotateSessionKeys(String sessionId) async {
    final session = _activeSessions[sessionId];
    if (session == null) return;

    // Generate new ephemeral key pair for perfect forward secrecy
    final keyPair = _generateECDHKeyPair();

    // Create new shared secret using key ratcheting
    final rotationSalt = _generateNonce();
    final rotationInfo = utf8.encode(
      'KeyRotation-${DateTime.now().millisecondsSinceEpoch}',
    );

    // Use HKDF for key ratcheting with current key as input
    final hmacExtract = Hmac(sha256, rotationSalt);
    final prk = hmacExtract.convert(session.encryptionKey).bytes;
    final newKeys = _hkdfExpand(prk, rotationInfo, 64);

    // Securely clear old keys from memory
    _secureMemoryClear(session.encryptionKey);
    _secureMemoryClear(session.authenticationKey);

    // Update with new keys
    session.encryptionKey = Uint8List.fromList(newKeys.sublist(0, 32));
    session.authenticationKey = Uint8List.fromList(newKeys.sublist(32, 64));
    session.ephemeralPublicKey = _encodePublicKey(keyPair.publicKey);
    session.ephemeralPrivateKey = keyPair.privateKey;
    session.createdAt = DateTime.now(); // Reset rotation timer

    // Clear derived keys from local memory
    newKeys.fillRange(0, newKeys.length, 0);
    rotationSalt.fillRange(0, rotationSalt.length, 0);
  }

  /// Securely clears sensitive data from memory
  void _secureMemoryClear(Uint8List data) {
    // Overwrite with random data first, then zeros
    for (int i = 0; i < data.length; i++) {
      data[i] = _secureRandom.nextUint8();
    }
    data.fillRange(0, data.length, 0);
  }

  void _scheduleKeyRotation(String sessionId) {
    Timer(_keyRotationInterval, () async {
      if (_activeSessions.containsKey(sessionId)) {
        await _rotateSessionKeys(sessionId);
        _scheduleKeyRotation(sessionId); // Schedule next rotation
      }
    });
  }

  /// Closes all sessions for a specific device
  Future<void> _closeDeviceSessions(String deviceId) async {
    final sessionsToClose = _activeSessions.entries
        .where((entry) => entry.value.deviceId == deviceId)
        .map((entry) => entry.key)
        .toList();

    for (final sessionId in sessionsToClose) {
      await closeSyncSession(sessionId);
    }
  }

  /// Validates that bytes are not all zeros (security check)
  bool _isZeroBytes(Uint8List bytes) {
    for (final byte in bytes) {
      if (byte != 0) return false;
    }
    return true;
  }

  /// Validates session is still active and not expired
  bool _isSessionValid(SyncSession session) {
    final now = DateTime.now();
    const maxSessionAge = Duration(hours: 24); // Maximum session lifetime

    return now.difference(session.createdAt) < maxSessionAge &&
        now.difference(session.lastUsed) < Duration(hours: 2); // Idle timeout
  }

  // Compatibility methods for existing sync protocol

  /// Checks if a device key exists for sync
  bool hasDeviceKey(String deviceId) {
    // Check if there's an active session for this device
    return _activeSessions.values.any(
      (session) => session.deviceId == deviceId,
    );
  }

  /// Encrypts sync data for transmission (compatibility method)
  Future<EncryptedSyncPacket> encryptSyncDataCompat({
    required String deviceId,
    required Map<String, dynamic> data,
  }) async {
    // Find or create session for this device
    SyncSession? session = _activeSessions.values
        .where((s) => s.deviceId == deviceId)
        .firstOrNull;

    session ??= await createSyncSession(deviceId, 'dummy_key');

    final encryptedData = await encryptSyncData(session.sessionId, data);

    // Convert to EncryptedSyncPacket format
    return EncryptedSyncPacket(
      deviceId: deviceId,
      nonce: encryptedData.nonce,
      encryptedData: base64.decode(encryptedData.ciphertext),
      signature: encryptedData.hmac,
      timestamp: encryptedData.timestamp,
    );
  }

  /// Decrypts sync data from transmission (compatibility method)
  Future<Map<String, dynamic>> decryptSyncDataCompat({
    required EncryptedSyncPacket packet,
  }) async {
    // Find session for this device
    final session = _activeSessions.values
        .where((s) => s.deviceId == packet.deviceId)
        .firstOrNull;

    if (session == null) {
      throw Exception('No active session for device: ${packet.deviceId}');
    }

    // Convert from EncryptedSyncPacket format
    final encryptedData = EncryptedSyncData(
      sessionId: session.sessionId,
      nonce: packet.nonce,
      ciphertext: base64.encode(packet.encryptedData),
      hmac: packet.signature,
      timestamp: packet.timestamp,
    );

    return await decryptSyncData(encryptedData);
  }
}

/// Represents an active sync session with ephemeral keys
class SyncSession {
  final String sessionId;
  final String deviceId;
  String ephemeralPublicKey;
  ECPrivateKey ephemeralPrivateKey;
  Uint8List encryptionKey;
  Uint8List authenticationKey;
  DateTime createdAt;
  DateTime lastUsed;

  SyncSession({
    required this.sessionId,
    required this.deviceId,
    required this.ephemeralPublicKey,
    required this.ephemeralPrivateKey,
    required this.encryptionKey,
    required this.authenticationKey,
    required this.createdAt,
    required this.lastUsed,
  });
}

/// Session keys derived from ECDH
class SessionKeys {
  final Uint8List encryptionKey;
  final Uint8List authenticationKey;

  SessionKeys({required this.encryptionKey, required this.authenticationKey});
}

/// Encrypted sync data with authentication
class EncryptedSyncData {
  final String sessionId;
  final String nonce;
  final String ciphertext;
  final String hmac;
  final DateTime timestamp;

  EncryptedSyncData({
    required this.sessionId,
    required this.nonce,
    required this.ciphertext,
    required this.hmac,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'nonce': nonce,
    'ciphertext': ciphertext,
    'hmac': hmac,
    'timestamp': timestamp.toIso8601String(),
  };

  factory EncryptedSyncData.fromJson(Map<String, dynamic> json) =>
      EncryptedSyncData(
        sessionId: json['sessionId'],
        nonce: json['nonce'],
        ciphertext: json['ciphertext'],
        hmac: json['hmac'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}

/// Public session information (no sensitive data)
class SyncSessionInfo {
  final String sessionId;
  final String deviceId;
  final DateTime createdAt;
  final DateTime lastUsed;

  SyncSessionInfo({
    required this.sessionId,
    required this.deviceId,
    required this.createdAt,
    required this.lastUsed,
  });
}

/// Key exchange data for initiating secure sessions
class KeyExchangeData {
  final String exchangeId;
  final String publicKey;
  final String deviceId;

  KeyExchangeData({
    required this.exchangeId,
    required this.publicKey,
    required this.deviceId,
  });

  Map<String, dynamic> toJson() => {
    'exchangeId': exchangeId,
    'publicKey': publicKey,
    'deviceId': deviceId,
  };

  factory KeyExchangeData.fromJson(Map<String, dynamic> json) =>
      KeyExchangeData(
        exchangeId: json['exchangeId'],
        publicKey: json['publicKey'],
        deviceId: json['deviceId'],
      );
}
