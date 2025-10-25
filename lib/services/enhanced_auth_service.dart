import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Enhanced authentication service with security features
class EnhancedAuthService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
  );

  // Security configuration
  static const int _maxFailedAttempts = 5;
  static const Duration _baseBackoffDuration = Duration(seconds: 1);
  static const Duration _maxBackoffDuration = Duration(minutes: 5);
  static const Duration _sensitiveOperationTimeout = Duration(minutes: 5);

  // Storage keys
  static const String _failedAttemptsKey = 'auth_failed_attempts';
  static const String _lastFailureTimeKey = 'auth_last_failure_time';
  static const String _lastSuccessTimeKey = 'auth_last_success_time';

  // Memory clearing
  static final List<Uint8List> _sensitiveDataBuffers = [];
  static Timer? _memoryCleanupTimer;
  static Timer? _backgroundTimer;

  /// Initialize the enhanced auth service
  static Future<void> initialize() async {
    // Start periodic memory cleanup
    _startMemoryCleanup();

    // Listen for app lifecycle changes
    _startBackgroundMonitoring();
  }

  /// Dispose of resources
  static Future<void> dispose() async {
    _memoryCleanupTimer?.cancel();
    _backgroundTimer?.cancel();
    await _clearAllSensitiveData();
  }

  /// Checks if device supports local authentication
  static Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      await _logSecurityEvent('device_support_check_failed', {
        'error': e.toString(),
      });
      return false;
    }
  }

  /// Checks if biometrics are available
  static Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (e) {
      await _logSecurityEvent('biometric_check_failed', {
        'error': e.toString(),
      });
      return false;
    }
  }

  /// Gets available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      await _logSecurityEvent('biometric_types_check_failed', {
        'error': e.toString(),
      });
      return <BiometricType>[];
    }
  }

  /// Enhanced authentication with exponential backoff
  static Future<AuthResult> authenticate({
    String reason = 'Unlock Password Manager',
    bool biometricOnly = false,
    bool requireRecentAuth = false,
  }) async {
    // Check if authentication is currently blocked
    final backoffResult = await _checkBackoffStatus();
    if (!backoffResult.canAttempt) {
      return AuthResult.blocked(
        reason:
            'Too many failed attempts. Try again in ${backoffResult.remainingTime?.inSeconds} seconds.',
        remainingBackoffTime: backoffResult.remainingTime,
      );
    }

    // Check if recent authentication is required and valid
    if (requireRecentAuth) {
      final recentAuthResult = await _checkRecentAuthentication();
      if (!recentAuthResult) {
        return AuthResult.failure(
          reason: 'Recent authentication required for this operation',
          requiresReauth: true,
        );
      }
    }

    bool authenticated = false;
    String? errorMessage;

    try {
      authenticated = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: true,
      );

      if (authenticated) {
        await _handleSuccessfulAuth();
        return AuthResult.success();
      } else {
        await _handleFailedAuth('User cancelled or authentication failed');
        return AuthResult.failure(reason: 'Authentication failed');
      }
    } on PlatformException catch (e) {
      errorMessage = _handlePlatformException(e);
      await _handleFailedAuth(errorMessage);
      return AuthResult.failure(reason: errorMessage);
    } catch (e) {
      errorMessage = 'Unexpected authentication error: ${e.toString()}';
      await _handleFailedAuth(errorMessage);
      return AuthResult.failure(reason: errorMessage);
    }
  }

  /// Authenticate for sensitive operations (vault deletion, export, etc.)
  static Future<AuthResult> authenticateForSensitiveOperation({
    required String operation,
    String? customReason,
  }) async {
    final reason = customReason ?? 'Authenticate to perform $operation';

    // Always require biometric authentication for sensitive operations
    final result = await authenticate(
      reason: reason,
      biometricOnly: true,
      requireRecentAuth: true,
    );

    if (result.isSuccess) {
      await _logSecurityEvent('sensitive_operation_auth_success', {
        'operation': operation,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } else {
      await _logSecurityEvent('sensitive_operation_auth_failed', {
        'operation': operation,
        'reason': result.errorMessage,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    return result;
  }

  /// Cancels any ongoing authentication
  static Future<void> cancelAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (e) {
      await _logSecurityEvent('auth_cancellation_failed', {
        'error': e.toString(),
      });
    }
  }

  /// Clears sensitive data from memory when app is backgrounded
  static Future<void> onAppBackgrounded() async {
    await _clearAllSensitiveData();
    await _logSecurityEvent('app_backgrounded', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Clears sensitive data from memory when app is paused
  static Future<void> onAppPaused() async {
    await _clearAllSensitiveData();
    await _logSecurityEvent('app_paused', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Registers sensitive data buffer for automatic cleanup
  static void registerSensitiveData(Uint8List data) {
    _sensitiveDataBuffers.add(data);
  }

  /// Manually clear specific sensitive data
  static void clearSensitiveData(Uint8List data) {
    data.fillRange(0, data.length, 0);
    _sensitiveDataBuffers.remove(data);
  }

  /// Gets authentication statistics for security monitoring
  static Future<AuthStats> getAuthStats() async {
    try {
      final failedAttempts =
          int.tryParse(await _storage.read(key: _failedAttemptsKey) ?? '0') ??
          0;

      final lastFailureTimeStr = await _storage.read(key: _lastFailureTimeKey);
      final lastSuccessTimeStr = await _storage.read(key: _lastSuccessTimeKey);

      DateTime? lastFailureTime;
      DateTime? lastSuccessTime;

      if (lastFailureTimeStr != null) {
        lastFailureTime = DateTime.tryParse(lastFailureTimeStr);
      }

      if (lastSuccessTimeStr != null) {
        lastSuccessTime = DateTime.tryParse(lastSuccessTimeStr);
      }

      return AuthStats(
        failedAttempts: failedAttempts,
        lastFailureTime: lastFailureTime,
        lastSuccessTime: lastSuccessTime,
      );
    } catch (e) {
      return AuthStats(failedAttempts: 0);
    }
  }

  /// Resets authentication failure count (admin function)
  static Future<void> resetFailureCount() async {
    try {
      await _storage.delete(key: _failedAttemptsKey);
      await _storage.delete(key: _lastFailureTimeKey);
      await _logSecurityEvent('failure_count_reset', {
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      await _logSecurityEvent('failure_count_reset_failed', {
        'error': e.toString(),
      });
    }
  }

  // Private helper methods

  static Future<BackoffResult> _checkBackoffStatus() async {
    try {
      final failedAttempts =
          int.tryParse(await _storage.read(key: _failedAttemptsKey) ?? '0') ??
          0;

      if (failedAttempts < _maxFailedAttempts) {
        return BackoffResult(canAttempt: true);
      }

      final lastFailureTimeStr = await _storage.read(key: _lastFailureTimeKey);
      if (lastFailureTimeStr == null) {
        return BackoffResult(canAttempt: true);
      }

      final lastFailureTime = DateTime.parse(lastFailureTimeStr);
      final backoffDuration = _calculateBackoffDuration(failedAttempts);
      final canAttemptTime = lastFailureTime.add(backoffDuration);
      final now = DateTime.now();

      if (now.isAfter(canAttemptTime)) {
        return BackoffResult(canAttempt: true);
      } else {
        return BackoffResult(
          canAttempt: false,
          remainingTime: canAttemptTime.difference(now),
        );
      }
    } catch (e) {
      // If we can't read the data, allow the attempt
      return BackoffResult(canAttempt: true);
    }
  }

  static Duration _calculateBackoffDuration(int failedAttempts) {
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, then cap at 5 minutes
    final exponentialSeconds = (1 << (failedAttempts - _maxFailedAttempts))
        .clamp(1, 300);
    final duration = Duration(seconds: exponentialSeconds);

    // Manual clamp for Duration
    if (duration < _baseBackoffDuration) {
      return _baseBackoffDuration;
    } else if (duration > _maxBackoffDuration) {
      return _maxBackoffDuration;
    } else {
      return duration;
    }
  }

  static Future<bool> _checkRecentAuthentication() async {
    try {
      final lastSuccessTimeStr = await _storage.read(key: _lastSuccessTimeKey);
      if (lastSuccessTimeStr == null) return false;

      final lastSuccessTime = DateTime.parse(lastSuccessTimeStr);
      final now = DateTime.now();

      return now.difference(lastSuccessTime) < _sensitiveOperationTimeout;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _handleSuccessfulAuth() async {
    try {
      // Reset failure count
      await _storage.delete(key: _failedAttemptsKey);
      await _storage.delete(key: _lastFailureTimeKey);

      // Record success time
      await _storage.write(
        key: _lastSuccessTimeKey,
        value: DateTime.now().toIso8601String(),
      );

      await _logSecurityEvent('auth_success', {
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      await _logSecurityEvent('auth_success_logging_failed', {
        'error': e.toString(),
      });
    }
  }

  static Future<void> _handleFailedAuth(String reason) async {
    try {
      final currentFailures =
          int.tryParse(await _storage.read(key: _failedAttemptsKey) ?? '0') ??
          0;

      final newFailures = currentFailures + 1;

      await _storage.write(
        key: _failedAttemptsKey,
        value: newFailures.toString(),
      );
      await _storage.write(
        key: _lastFailureTimeKey,
        value: DateTime.now().toIso8601String(),
      );

      await _logSecurityEvent('auth_failure', {
        'reason': reason,
        'failureCount': newFailures,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Check for suspicious activity
      if (newFailures >= _maxFailedAttempts) {
        await _logSecurityEvent('suspicious_activity_detected', {
          'type': 'excessive_auth_failures',
          'failureCount': newFailures,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      await _logSecurityEvent('auth_failure_logging_failed', {
        'error': e.toString(),
      });
    }
  }

  static String _handlePlatformException(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return 'Biometric authentication is not available on this device';
      case 'NotEnrolled':
        return 'No biometric credentials are enrolled on this device';
      case 'LockedOut':
        return 'Biometric authentication is temporarily locked. Please try again later';
      case 'PermanentlyLockedOut':
        return 'Biometric authentication is permanently locked. Please use device credentials';
      case 'BiometricOnly':
        return 'Only biometric authentication is allowed for this operation';
      default:
        return 'Authentication error: ${e.message ?? e.code}';
    }
  }

  static Future<void> _clearAllSensitiveData() async {
    for (final buffer in _sensitiveDataBuffers) {
      buffer.fillRange(0, buffer.length, 0);
    }
    _sensitiveDataBuffers.clear();
  }

  static void _startMemoryCleanup() {
    _memoryCleanupTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      // Periodic cleanup of any orphaned sensitive data
      _clearAllSensitiveData();
    });
  }

  static void _startBackgroundMonitoring() {
    _backgroundTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      // Monitor for unusual patterns or potential security issues
      _checkForSuspiciousActivity();
    });
  }

  static Future<void> _checkForSuspiciousActivity() async {
    try {
      final stats = await getAuthStats();

      // Check for rapid repeated failures
      if (stats.lastFailureTime != null) {
        final timeSinceLastFailure = DateTime.now().difference(
          stats.lastFailureTime!,
        );
        if (stats.failedAttempts >= 3 &&
            timeSinceLastFailure < const Duration(minutes: 1)) {
          await _logSecurityEvent('rapid_auth_failures_detected', {
            'failureCount': stats.failedAttempts,
            'timeSpan': timeSinceLastFailure.inSeconds,
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      }
    } catch (e) {
      // Ignore monitoring errors to avoid affecting normal operation
    }
  }

  static Future<void> _logSecurityEvent(
    String eventType,
    Map<String, dynamic> data,
  ) async {
    try {
      final event = {
        'eventType': eventType,
        'timestamp': DateTime.now().toIso8601String(),
        'data': data,
      };

      // In a production app, this would send to a security monitoring system
      // For now, we'll store locally for debugging
      final existingLogs = await _storage.read(key: 'security_events') ?? '[]';
      final logs = List<Map<String, dynamic>>.from(
        (jsonDecode(existingLogs) as List).cast<Map<String, dynamic>>(),
      );

      logs.add(event);

      // Keep only the last 100 events to prevent storage bloat
      if (logs.length > 100) {
        logs.removeRange(0, logs.length - 100);
      }

      await _storage.write(key: 'security_events', value: jsonEncode(logs));
    } catch (e) {
      // Ignore logging errors to avoid affecting normal operation
    }
  }
}

/// Result of an authentication attempt
class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final Duration? remainingBackoffTime;
  final bool requiresReauth;

  const AuthResult._({
    required this.isSuccess,
    this.errorMessage,
    this.remainingBackoffTime,
    this.requiresReauth = false,
  });

  factory AuthResult.success() => const AuthResult._(isSuccess: true);

  factory AuthResult.failure({
    required String reason,
    bool requiresReauth = false,
  }) => AuthResult._(
    isSuccess: false,
    errorMessage: reason,
    requiresReauth: requiresReauth,
  );

  factory AuthResult.blocked({
    required String reason,
    Duration? remainingBackoffTime,
  }) => AuthResult._(
    isSuccess: false,
    errorMessage: reason,
    remainingBackoffTime: remainingBackoffTime,
  );
}

/// Backoff status for authentication attempts
class BackoffResult {
  final bool canAttempt;
  final Duration? remainingTime;

  BackoffResult({required this.canAttempt, this.remainingTime});
}

/// Authentication statistics for security monitoring
class AuthStats {
  final int failedAttempts;
  final DateTime? lastFailureTime;
  final DateTime? lastSuccessTime;

  AuthStats({
    required this.failedAttempts,
    this.lastFailureTime,
    this.lastSuccessTime,
  });
}
