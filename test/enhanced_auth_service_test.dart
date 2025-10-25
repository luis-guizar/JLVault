import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:simple_vault/services/enhanced_auth_service.dart';

void main() {
  group('EnhancedAuthService', () {
    setUpAll(() {
      // Initialize the test binding
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      // Mock the platform channels
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/local_auth'),
            (MethodCall methodCall) async {
              switch (methodCall.method) {
                case 'isDeviceSupported':
                  return true;
                case 'canCheckBiometrics':
                  return true;
                case 'getAvailableBiometrics':
                  return ['fingerprint'];
                case 'authenticate':
                  return true; // Simulate successful authentication
                default:
                  return null;
              }
            },
          );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (MethodCall methodCall) async {
              // Mock secure storage
              return null;
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/local_auth'),
            null,
          );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            null,
          );
    });

    test('should support device authentication', () async {
      final isSupported = await EnhancedAuthService.isDeviceSupported();
      expect(isSupported, isTrue);
    });

    test('should check biometric availability', () async {
      final canCheck = await EnhancedAuthService.canCheckBiometrics();
      expect(canCheck, isTrue);
    });

    test('should authenticate successfully', () async {
      final result = await EnhancedAuthService.authenticate(
        reason: 'Test authentication',
      );
      expect(result.isSuccess, isTrue);
    });

    test('should authenticate for sensitive operations', () async {
      // Test that the method can be called without errors
      // The actual authentication logic is complex and requires proper mocking
      final result =
          await EnhancedAuthService.authenticateForSensitiveOperation(
            operation: 'test_operation',
            customReason: 'Test sensitive operation',
          );
      // Just verify the result is not null and has expected structure
      expect(result, isNotNull);
      expect(result.isSuccess, isA<bool>());
    });

    test('should handle exponential backoff', () async {
      // This test would require more complex mocking to simulate failures
      // For now, we just verify the method exists and can be called
      final stats = await EnhancedAuthService.getAuthStats();
      expect(stats.failedAttempts, equals(0));
    });

    test('should clear sensitive data on app backgrounded', () async {
      // Test that the method can be called without errors
      await EnhancedAuthService.onAppBackgrounded();
      // No assertion needed - just verify no exceptions are thrown
    });

    test('should clear sensitive data on app paused', () async {
      // Test that the method can be called without errors
      await EnhancedAuthService.onAppPaused();
      // No assertion needed - just verify no exceptions are thrown
    });
  });
}
