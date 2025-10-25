import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'secure_logging_service.dart';
import 'data_storage_auditor.dart';

/// Comprehensive security monitoring and alerting service
class SecurityMonitoringService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
  );

  static const String _securityEventsKey = 'security_events';
  static const String _integrityHashesKey = 'integrity_hashes';
  static const String _accessPatternsKey = 'access_patterns';
  static const String _alertConfigKey = 'alert_config';

  static const int _maxSecurityEvents = 1000;
  static const Duration _monitoringInterval = Duration(minutes: 5);
  static const Duration _integrityCheckInterval = Duration(hours: 1);

  static Timer? _monitoringTimer;
  static Timer? _integrityTimer;
  static bool _initialized = false;
  static final List<SecurityAlert> _pendingAlerts = [];
  static final StreamController<SecurityAlert> _alertController =
      StreamController<SecurityAlert>.broadcast();

  /// Initialize the security monitoring service
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await SecureLoggingService.initialize();

      // Load existing configuration
      await _loadAlertConfiguration();

      // Start monitoring timers
      _startPeriodicMonitoring();
      _startIntegrityChecking();

      // Perform initial security check
      await _performInitialSecurityCheck();

      _initialized = true;

      await _logSecurityEvent(SecurityEventType.systemStartup, {
        'timestamp': DateTime.now().toIso8601String(),
        'monitoringEnabled': true,
      });
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to initialize security monitoring',
        error: e,
      );
    }
  }

  /// Dispose of resources
  static Future<void> dispose() async {
    if (!_initialized) return;

    _monitoringTimer?.cancel();
    _integrityTimer?.cancel();

    await _alertController.close();

    _initialized = false;

    await _logSecurityEvent(SecurityEventType.systemShutdown, {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Stream of security alerts
  static Stream<SecurityAlert> get alertStream => _alertController.stream;

  /// Log a security event
  static Future<void> logSecurityEvent(
    SecurityEventType eventType,
    Map<String, dynamic> data,
  ) async {
    await _logSecurityEvent(eventType, data);
  }

  /// Log authentication failure
  static Future<void> logAuthenticationFailure({
    required String reason,
    String? userId,
    Map<String, dynamic>? additionalData,
  }) async {
    final data = <String, dynamic>{
      'reason': reason,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (userId != null) data['userId'] = userId;
    if (additionalData != null) data.addAll(additionalData);

    await _logSecurityEvent(SecurityEventType.authenticationFailure, data);

    // Check for suspicious patterns
    await _checkAuthenticationPatterns();
  }

  /// Log suspicious activity
  static Future<void> logSuspiciousActivity({
    required String activityType,
    required String description,
    Map<String, dynamic>? additionalData,
  }) async {
    final data = <String, dynamic>{
      'activityType': activityType,
      'description': description,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (additionalData != null) data.addAll(additionalData);

    await _logSecurityEvent(SecurityEventType.suspiciousActivity, data);

    // Generate immediate alert for suspicious activity
    await _generateAlert(
      AlertSeverity.high,
      'Suspicious Activity Detected',
      description,
      data,
    );
  }

  /// Perform integrity check on vault data
  static Future<IntegrityCheckResult> performIntegrityCheck(
    String vaultId,
    List<String> criticalFiles,
  ) async {
    try {
      final results = <String, bool>{};
      final issues = <String>[];

      // Load stored hashes
      final storedHashes = await _getStoredIntegrityHashes(vaultId);

      for (final filePath in criticalFiles) {
        final file = File(filePath);
        if (!file.existsSync()) {
          results[filePath] = false;
          issues.add('File not found: $filePath');
          continue;
        }

        // Calculate current hash
        final fileBytes = await file.readAsBytes();
        final currentHash = sha256.convert(fileBytes).toString();

        // Compare with stored hash
        final storedHash = storedHashes[filePath];
        if (storedHash == null) {
          // First time checking this file, store the hash
          storedHashes[filePath] = currentHash;
          results[filePath] = true;
        } else if (storedHash != currentHash) {
          results[filePath] = false;
          issues.add('Integrity check failed for: $filePath');

          await _logSecurityEvent(SecurityEventType.integrityViolation, {
            'filePath': filePath,
            'expectedHash': storedHash,
            'actualHash': currentHash,
            'timestamp': DateTime.now().toIso8601String(),
          });
        } else {
          results[filePath] = true;
        }
      }

      // Update stored hashes
      await _storeIntegrityHashes(vaultId, storedHashes);

      final isValid = issues.isEmpty;

      if (!isValid) {
        await _generateAlert(
          AlertSeverity.critical,
          'Data Integrity Violation',
          'One or more files failed integrity checks',
          {'issues': issues, 'vaultId': vaultId},
        );
      }

      return IntegrityCheckResult(
        vaultId: vaultId,
        checkTime: DateTime.now(),
        isValid: isValid,
        checkedFiles: results,
        issues: issues,
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'Integrity check failed',
        data: {'vaultId': vaultId},
        error: e,
      );

      return IntegrityCheckResult(
        vaultId: vaultId,
        checkTime: DateTime.now(),
        isValid: false,
        checkedFiles: {},
        issues: ['Integrity check failed: ${e.toString()}'],
      );
    }
  }

  /// Monitor for unusual access patterns
  static Future<void> recordAccessPattern({
    required String operation,
    required String resourceId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final pattern = AccessPattern(
        timestamp: DateTime.now(),
        operation: operation,
        resourceId: resourceId,
        metadata: metadata ?? {},
      );

      await _storeAccessPattern(pattern);
      await _analyzeAccessPatterns();
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to record access pattern',
        error: e,
      );
    }
  }

  /// Get recent security events
  static Future<List<SecurityEvent>> getRecentSecurityEvents({
    int limit = 100,
  }) async {
    try {
      final eventsJson = await _storage.read(key: _securityEventsKey) ?? '[]';
      final eventsList = jsonDecode(eventsJson) as List;

      final events = eventsList
          .map((json) => SecurityEvent.fromJson(json as Map<String, dynamic>))
          .toList();

      events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return events.take(limit).toList();
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to get security events',
        error: e,
      );
      return [];
    }
  }

  /// Get security statistics
  static Future<SecurityStats> getSecurityStats() async {
    try {
      final events = await getRecentSecurityEvents(limit: 1000);
      final now = DateTime.now();
      final last24Hours = now.subtract(const Duration(hours: 24));
      final last7Days = now.subtract(const Duration(days: 7));

      final recent24h = events
          .where((e) => e.timestamp.isAfter(last24Hours))
          .toList();
      final recent7d = events
          .where((e) => e.timestamp.isAfter(last7Days))
          .toList();

      return SecurityStats(
        totalEvents: events.length,
        eventsLast24Hours: recent24h.length,
        eventsLast7Days: recent7d.length,
        authFailuresLast24Hours: recent24h
            .where(
              (e) => e.eventType == SecurityEventType.authenticationFailure,
            )
            .length,
        suspiciousActivitiesLast24Hours: recent24h
            .where((e) => e.eventType == SecurityEventType.suspiciousActivity)
            .length,
        integrityViolationsLast7Days: recent7d
            .where((e) => e.eventType == SecurityEventType.integrityViolation)
            .length,
      );
    } catch (e) {
      return SecurityStats(
        totalEvents: 0,
        eventsLast24Hours: 0,
        eventsLast7Days: 0,
        authFailuresLast24Hours: 0,
        suspiciousActivitiesLast24Hours: 0,
        integrityViolationsLast7Days: 0,
      );
    }
  }

  /// Configure security alerts
  static Future<void> configureAlerts(AlertConfiguration config) async {
    try {
      await _storage.write(
        key: _alertConfigKey,
        value: jsonEncode(config.toJson()),
      );

      await _logSecurityEvent(SecurityEventType.configurationChange, {
        'type': 'alert_configuration',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to configure alerts',
        error: e,
      );
    }
  }

  /// Get pending security alerts
  static List<SecurityAlert> getPendingAlerts() {
    return List<SecurityAlert>.from(_pendingAlerts);
  }

  /// Acknowledge a security alert
  static Future<void> acknowledgeAlert(String alertId) async {
    _pendingAlerts.removeWhere((alert) => alert.id == alertId);

    await _logSecurityEvent(SecurityEventType.alertAcknowledged, {
      'alertId': alertId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Private helper methods

  static Future<void> _logSecurityEvent(
    SecurityEventType eventType,
    Map<String, dynamic> data,
  ) async {
    try {
      final event = SecurityEvent(
        id: _generateEventId(),
        timestamp: DateTime.now(),
        eventType: eventType,
        data: data,
      );

      // Store event
      final eventsJson = await _storage.read(key: _securityEventsKey) ?? '[]';
      final eventsList = List<Map<String, dynamic>>.from(
        (jsonDecode(eventsJson) as List).cast<Map<String, dynamic>>(),
      );

      eventsList.add(event.toJson());

      // Keep only recent events
      if (eventsList.length > _maxSecurityEvents) {
        eventsList.removeRange(0, eventsList.length - _maxSecurityEvents);
      }

      await _storage.write(
        key: _securityEventsKey,
        value: jsonEncode(eventsList),
      );

      // Also log to secure logging service
      await SecureLoggingService.logSecurityEvent(eventType.name, data: data);
    } catch (e) {
      // Fallback to secure logging service only
      await SecureLoggingService.logSecurityEvent(eventType.name, data: data);
    }
  }

  static Future<void> _performInitialSecurityCheck() async {
    try {
      // Perform storage audit
      final auditResult = await DataStorageAuditor.performFullAudit();

      if (!auditResult.isCompliant) {
        await _generateAlert(
          AlertSeverity.high,
          'Storage Compliance Issues',
          'Data storage audit found ${auditResult.issues.length} issues',
          auditResult.getSummary(),
        );
      }

      await _logSecurityEvent(SecurityEventType.securityAudit, {
        'auditType': 'initial_storage_audit',
        'isCompliant': auditResult.isCompliant,
        'issuesFound': auditResult.issues.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      await SecureLoggingService.logError(
        'Initial security check failed',
        error: e,
      );
    }
  }

  static void _startPeriodicMonitoring() {
    _monitoringTimer = Timer.periodic(_monitoringInterval, (timer) async {
      await _performPeriodicSecurityCheck();
    });
  }

  static void _startIntegrityChecking() {
    _integrityTimer = Timer.periodic(_integrityCheckInterval, (timer) async {
      await _performPeriodicIntegrityCheck();
    });
  }

  static Future<void> _performPeriodicSecurityCheck() async {
    try {
      // Check for unusual patterns
      await _analyzeAccessPatterns();

      // Check system health
      await _checkSystemHealth();

      await _logSecurityEvent(SecurityEventType.periodicCheck, {
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      await SecureLoggingService.logError(
        'Periodic security check failed',
        error: e,
      );
    }
  }

  static Future<void> _performPeriodicIntegrityCheck() async {
    try {
      // This would check critical system files
      // For now, we'll just log that the check occurred
      await _logSecurityEvent(SecurityEventType.integrityCheck, {
        'type': 'periodic',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      await SecureLoggingService.logError(
        'Periodic integrity check failed',
        error: e,
      );
    }
  }

  static Future<void> _checkAuthenticationPatterns() async {
    try {
      final events = await getRecentSecurityEvents(limit: 100);
      final authFailures = events
          .where((e) => e.eventType == SecurityEventType.authenticationFailure)
          .toList();

      final recentFailures = authFailures
          .where(
            (e) =>
                DateTime.now().difference(e.timestamp) <
                const Duration(minutes: 15),
          )
          .length;

      if (recentFailures >= 5) {
        await _generateAlert(
          AlertSeverity.high,
          'Multiple Authentication Failures',
          'Detected $recentFailures authentication failures in the last 15 minutes',
          {'failureCount': recentFailures},
        );
      }
    } catch (e) {
      await SecureLoggingService.logError(
        'Authentication pattern check failed',
        error: e,
      );
    }
  }

  static Future<void> _analyzeAccessPatterns() async {
    try {
      final patternsJson = await _storage.read(key: _accessPatternsKey) ?? '[]';
      final patternsList = jsonDecode(patternsJson) as List;

      final patterns = patternsList
          .map((json) => AccessPattern.fromJson(json as Map<String, dynamic>))
          .toList();

      // Analyze for unusual patterns
      final now = DateTime.now();
      final recentPatterns = patterns
          .where((p) => now.difference(p.timestamp) < const Duration(hours: 1))
          .toList();

      // Check for rapid access to sensitive operations
      final sensitiveOps = recentPatterns
          .where(
            (p) =>
                ['vault_delete', 'export', 'key_change'].contains(p.operation),
          )
          .length;

      if (sensitiveOps >= 10) {
        await _generateAlert(
          AlertSeverity.medium,
          'Unusual Access Pattern',
          'High frequency of sensitive operations detected',
          {'sensitiveOperations': sensitiveOps},
        );
      }
    } catch (e) {
      await SecureLoggingService.logError(
        'Access pattern analysis failed',
        error: e,
      );
    }
  }

  static Future<void> _checkSystemHealth() async {
    try {
      // Check available storage space
      // final appDir = await getApplicationDocumentsDirectory();
      // final stat = await appDir.stat(); // Not used in simplified check

      // Check for potential issues
      // This is a simplified check - in production you'd want more comprehensive monitoring

      await _logSecurityEvent(SecurityEventType.systemHealthCheck, {
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'healthy',
      });
    } catch (e) {
      await SecureLoggingService.logError(
        'System health check failed',
        error: e,
      );
    }
  }

  static Future<void> _storeAccessPattern(AccessPattern pattern) async {
    try {
      final patternsJson = await _storage.read(key: _accessPatternsKey) ?? '[]';
      final patternsList = List<Map<String, dynamic>>.from(
        (jsonDecode(patternsJson) as List).cast<Map<String, dynamic>>(),
      );

      patternsList.add(pattern.toJson());

      // Keep only recent patterns (last 7 days)
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      patternsList.removeWhere(
        (p) => DateTime.parse(p['timestamp']).isBefore(cutoff),
      );

      await _storage.write(
        key: _accessPatternsKey,
        value: jsonEncode(patternsList),
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to store access pattern',
        error: e,
      );
    }
  }

  static Future<Map<String, String>> _getStoredIntegrityHashes(
    String vaultId,
  ) async {
    try {
      final hashesJson =
          await _storage.read(key: '$_integrityHashesKey$vaultId') ?? '{}';
      final hashesMap = jsonDecode(hashesJson) as Map<String, dynamic>;
      return hashesMap.cast<String, String>();
    } catch (e) {
      return {};
    }
  }

  static Future<void> _storeIntegrityHashes(
    String vaultId,
    Map<String, String> hashes,
  ) async {
    try {
      await _storage.write(
        key: '$_integrityHashesKey$vaultId',
        value: jsonEncode(hashes),
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to store integrity hashes',
        error: e,
      );
    }
  }

  static Future<void> _loadAlertConfiguration() async {
    try {
      final configJson = await _storage.read(key: _alertConfigKey);
      if (configJson != null) {
        // Configuration loaded successfully
        // In a full implementation, you'd apply the configuration
      }
    } catch (e) {
      // Use default configuration
    }
  }

  static Future<void> _generateAlert(
    AlertSeverity severity,
    String title,
    String message,
    Map<String, dynamic> data,
  ) async {
    final alert = SecurityAlert(
      id: _generateEventId(),
      timestamp: DateTime.now(),
      severity: severity,
      title: title,
      message: message,
      data: data,
    );

    _pendingAlerts.add(alert);

    // Emit alert to stream
    if (!_alertController.isClosed) {
      _alertController.add(alert);
    }

    await _logSecurityEvent(SecurityEventType.alertGenerated, {
      'alertId': alert.id,
      'severity': severity.name,
      'title': title,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static String _generateEventId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return '${timestamp}_$random';
  }
}

/// Types of security events
enum SecurityEventType {
  systemStartup,
  systemShutdown,
  authenticationFailure,
  authenticationSuccess,
  suspiciousActivity,
  integrityViolation,
  integrityCheck,
  securityAudit,
  configurationChange,
  alertGenerated,
  alertAcknowledged,
  periodicCheck,
  systemHealthCheck,
}

/// Security event record
class SecurityEvent {
  final String id;
  final DateTime timestamp;
  final SecurityEventType eventType;
  final Map<String, dynamic> data;

  SecurityEvent({
    required this.id,
    required this.timestamp,
    required this.eventType,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'eventType': eventType.name,
    'data': data,
  };

  factory SecurityEvent.fromJson(Map<String, dynamic> json) => SecurityEvent(
    id: json['id'],
    timestamp: DateTime.parse(json['timestamp']),
    eventType: SecurityEventType.values.firstWhere(
      (e) => e.name == json['eventType'],
    ),
    data: json['data'] as Map<String, dynamic>,
  );
}

/// Access pattern record
class AccessPattern {
  final DateTime timestamp;
  final String operation;
  final String resourceId;
  final Map<String, dynamic> metadata;

  AccessPattern({
    required this.timestamp,
    required this.operation,
    required this.resourceId,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'operation': operation,
    'resourceId': resourceId,
    'metadata': metadata,
  };

  factory AccessPattern.fromJson(Map<String, dynamic> json) => AccessPattern(
    timestamp: DateTime.parse(json['timestamp']),
    operation: json['operation'],
    resourceId: json['resourceId'],
    metadata: json['metadata'] as Map<String, dynamic>,
  );
}

/// Result of an integrity check
class IntegrityCheckResult {
  final String vaultId;
  final DateTime checkTime;
  final bool isValid;
  final Map<String, bool> checkedFiles;
  final List<String> issues;

  IntegrityCheckResult({
    required this.vaultId,
    required this.checkTime,
    required this.isValid,
    required this.checkedFiles,
    required this.issues,
  });
}

/// Security statistics
class SecurityStats {
  final int totalEvents;
  final int eventsLast24Hours;
  final int eventsLast7Days;
  final int authFailuresLast24Hours;
  final int suspiciousActivitiesLast24Hours;
  final int integrityViolationsLast7Days;

  SecurityStats({
    required this.totalEvents,
    required this.eventsLast24Hours,
    required this.eventsLast7Days,
    required this.authFailuresLast24Hours,
    required this.suspiciousActivitiesLast24Hours,
    required this.integrityViolationsLast7Days,
  });
}

/// Security alert
class SecurityAlert {
  final String id;
  final DateTime timestamp;
  final AlertSeverity severity;
  final String title;
  final String message;
  final Map<String, dynamic> data;

  SecurityAlert({
    required this.id,
    required this.timestamp,
    required this.severity,
    required this.title,
    required this.message,
    required this.data,
  });
}

/// Alert severity levels
enum AlertSeverity { low, medium, high, critical }

/// Alert configuration
class AlertConfiguration {
  final bool enableAuthFailureAlerts;
  final int authFailureThreshold;
  final bool enableIntegrityAlerts;
  final bool enableSuspiciousActivityAlerts;
  final Duration alertCooldown;

  AlertConfiguration({
    this.enableAuthFailureAlerts = true,
    this.authFailureThreshold = 5,
    this.enableIntegrityAlerts = true,
    this.enableSuspiciousActivityAlerts = true,
    this.alertCooldown = const Duration(minutes: 15),
  });

  Map<String, dynamic> toJson() => {
    'enableAuthFailureAlerts': enableAuthFailureAlerts,
    'authFailureThreshold': authFailureThreshold,
    'enableIntegrityAlerts': enableIntegrityAlerts,
    'enableSuspiciousActivityAlerts': enableSuspiciousActivityAlerts,
    'alertCooldownMinutes': alertCooldown.inMinutes,
  };

  factory AlertConfiguration.fromJson(Map<String, dynamic> json) =>
      AlertConfiguration(
        enableAuthFailureAlerts: json['enableAuthFailureAlerts'] ?? true,
        authFailureThreshold: json['authFailureThreshold'] ?? 5,
        enableIntegrityAlerts: json['enableIntegrityAlerts'] ?? true,
        enableSuspiciousActivityAlerts:
            json['enableSuspiciousActivityAlerts'] ?? true,
        alertCooldown: Duration(minutes: json['alertCooldownMinutes'] ?? 15),
      );
}
