import 'package:flutter_test/flutter_test.dart';
import 'package:simple_vault/services/sync_encryption_service.dart';

void main() {
  group('SyncEncryptionService Perfect Forward Secrecy Tests', () {
    late SyncEncryptionService service1;
    late SyncEncryptionService service2;

    setUp(() {
      service1 = SyncEncryptionService();
      service2 = SyncEncryptionService();
    });

    tearDown(() async {
      await service1.closeAllSessions();
      await service2.closeAllSessions();
    });

    test('should perform complete key exchange between two devices', () async {
      const device1Id = 'device-1';
      const device2Id = 'device-2';

      // Device 1 initiates key exchange
      final keyExchange1 = await service1.initiateKeyExchange(device2Id);

      // Device 2 initiates key exchange
      final keyExchange2 = await service2.initiateKeyExchange(device1Id);

      // Both devices accept each other's sessions
      final session1 = await service1.acceptSyncSession(
        device2Id,
        keyExchange2.publicKey,
        keyExchange2.publicKey,
      );

      final session2 = await service2.acceptSyncSession(
        device1Id,
        keyExchange1.publicKey,
        keyExchange1.publicKey,
      );

      // Verify sessions are created
      expect(session1.sessionId, isNotEmpty);
      expect(session1.deviceId, equals(device2Id));
      expect(session1.encryptionKey.length, equals(32)); // AES-256 key
      expect(session1.authenticationKey.length, equals(32)); // HMAC key

      expect(session2.sessionId, isNotEmpty);
      expect(session2.deviceId, equals(device1Id));
      expect(session2.encryptionKey.length, equals(32));
      expect(session2.authenticationKey.length, equals(32));
    });

    test('should encrypt and decrypt data between sessions', () async {
      const device1Id = 'device-1';
      const device2Id = 'device-2';

      // Create sessions
      final keyExchange1 = await service1.initiateKeyExchange(device2Id);
      final keyExchange2 = await service2.initiateKeyExchange(device1Id);

      final session1 = await service1.acceptSyncSession(
        device2Id,
        keyExchange2.publicKey,
        keyExchange2.publicKey,
      );

      // Test data
      final testData = {
        'passwords': [
          {
            'title': 'Test Account',
            'username': 'user@test.com',
            'password': 'secret123',
          },
        ],
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Encrypt data with session 1
      final encryptedData = await service1.encryptSyncData(
        session1.sessionId,
        testData,
      );

      expect(encryptedData.sessionId, equals(session1.sessionId));
      expect(encryptedData.nonce, isNotEmpty);
      expect(encryptedData.ciphertext, isNotEmpty);
      expect(encryptedData.hmac, isNotEmpty);

      // Decrypt data with same session
      final decryptedData = await service1.decryptSyncData(encryptedData);
      expect(decryptedData, equals(testData));
    });

    test('should rotate keys automatically', () async {
      const device1Id = 'device-1';
      const device2Id = 'device-2';

      // Create session
      final keyExchange = await service1.initiateKeyExchange(device2Id);
      final session = await service1.acceptSyncSession(
        device2Id,
        keyExchange.publicKey,
        keyExchange.publicKey,
      );

      // Store original keys
      final originalEncryptionKey = List<int>.from(session.encryptionKey);
      final originalAuthKey = List<int>.from(session.authenticationKey);

      // Manually trigger key rotation
      await service1.rotateSessionKeys(session.sessionId);

      // Keys should be different after rotation
      expect(session.encryptionKey, isNot(equals(originalEncryptionKey)));
      expect(session.authenticationKey, isNot(equals(originalAuthKey)));
    });

    test('should close sessions and clear keys', () async {
      const device1Id = 'device-1';
      const device2Id = 'device-2';

      // Create session
      final keyExchange = await service1.initiateKeyExchange(device2Id);
      final session = await service1.acceptSyncSession(
        device2Id,
        keyExchange.publicKey,
        keyExchange.publicKey,
      );
      final sessionId = session.sessionId;

      // Verify session exists
      expect(service1.getActiveSessions().length, equals(1));

      // Close session
      await service1.closeSyncSession(sessionId);

      // Verify session is removed
      expect(service1.getActiveSessions().length, equals(0));

      // Verify keys are cleared (should be all zeros)
      expect(session.encryptionKey.every((byte) => byte == 0), isTrue);
      expect(session.authenticationKey.every((byte) => byte == 0), isTrue);
    });

    test('should handle multiple concurrent sessions', () async {
      const device1Id = 'device-1';
      const device2Id = 'device-2';
      const device3Id = 'device-3';

      // Create multiple sessions
      final keyExchange1 = await service1.initiateKeyExchange(device2Id);
      final keyExchange2 = await service1.initiateKeyExchange(device3Id);

      final session1 = await service1.acceptSyncSession(
        device2Id,
        keyExchange1.publicKey,
        keyExchange1.publicKey,
      );
      final session2 = await service1.acceptSyncSession(
        device3Id,
        keyExchange2.publicKey,
        keyExchange2.publicKey,
      );

      // Verify both sessions exist
      expect(service1.getActiveSessions().length, equals(2));

      // Verify sessions have different keys
      expect(session1.encryptionKey, isNot(equals(session2.encryptionKey)));
      expect(
        session1.authenticationKey,
        isNot(equals(session2.authenticationKey)),
      );

      // Test encryption with different sessions
      final testData = {'test': 'data'};

      final encrypted1 = await service1.encryptSyncData(
        session1.sessionId,
        testData,
      );
      final encrypted2 = await service1.encryptSyncData(
        session2.sessionId,
        testData,
      );

      // Encrypted data should be different (different keys/nonces)
      expect(encrypted1.ciphertext, isNot(equals(encrypted2.ciphertext)));

      // But both should decrypt to the same original data
      final decrypted1 = await service1.decryptSyncData(encrypted1);
      final decrypted2 = await service1.decryptSyncData(encrypted2);

      expect(decrypted1, equals(testData));
      expect(decrypted2, equals(testData));
    });

    test('should reject invalid session IDs', () async {
      const invalidSessionId = 'invalid-session-id';
      final testData = {'test': 'data'};

      // Should throw exception for invalid session
      expect(
        () => service1.encryptSyncData(invalidSessionId, testData),
        throwsException,
      );
    });

    test('should validate HMAC on decryption', () async {
      const device1Id = 'device-1';
      const device2Id = 'device-2';

      // Create session and encrypt data
      final keyExchange = await service1.initiateKeyExchange(device2Id);
      final session = await service1.acceptSyncSession(
        device2Id,
        keyExchange.publicKey,
        keyExchange.publicKey,
      );

      final testData = {'test': 'data'};
      final encryptedData = await service1.encryptSyncData(
        session.sessionId,
        testData,
      );

      // Tamper with HMAC
      final tamperedData = EncryptedSyncData(
        sessionId: encryptedData.sessionId,
        nonce: encryptedData.nonce,
        ciphertext: encryptedData.ciphertext,
        hmac: 'tampered-hmac',
        timestamp: encryptedData.timestamp,
      );

      // Should throw exception for invalid HMAC
      expect(() => service1.decryptSyncData(tamperedData), throwsException);
    });

    test('should provide session public keys for exchange', () async {
      const deviceId = 'test-device';

      // Initiate key exchange
      final keyExchange = await service1.initiateKeyExchange(deviceId);

      expect(keyExchange.exchangeId, isNotEmpty);
      expect(keyExchange.publicKey, isNotEmpty);
      expect(keyExchange.deviceId, equals(deviceId));
    });

    test('should ensure forward secrecy by using ephemeral keys', () async {
      const device1Id = 'device-1';
      const device2Id = 'device-2';

      // Create first session
      final keyExchange1 = await service1.initiateKeyExchange(device2Id);
      final session1 = await service1.acceptSyncSession(
        device2Id,
        keyExchange1.publicKey,
        keyExchange1.publicKey,
      );

      // Close first session
      await service1.closeSyncSession(session1.sessionId);

      // Create second session with same device
      final keyExchange2 = await service1.initiateKeyExchange(device2Id);
      final session2 = await service1.acceptSyncSession(
        device2Id,
        keyExchange2.publicKey,
        keyExchange2.publicKey,
      );

      // Sessions should have different ephemeral keys (forward secrecy)
      expect(
        session1.ephemeralPublicKey,
        isNot(equals(session2.ephemeralPublicKey)),
      );
      expect(session1.encryptionKey, isNot(equals(session2.encryptionKey)));
      expect(
        session1.authenticationKey,
        isNot(equals(session2.authenticationKey)),
      );
    });
  });
}
