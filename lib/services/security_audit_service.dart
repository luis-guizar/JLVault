import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'secure_logging_service.dart';
import 'enhanced_auth_service.dart';

/// Comprehensive security audit and monitoring service
class SecurityAuditService {
  static Timer? _monitoringTimer;
  static Timer? _integrityCheckTimer;
  static bool _initialized = false;
  static final List<SecurityAlert> _activeAlerts = [];
  static final List<AccessPattern> _accessPatterns = [];
  static final Map<String, FileIntegrityInfo> _fileIntegrityMap = {};

  // Monitoring thresholds
  static const int _maxAuthFailuresPerHour = 10;
  static const int _maxAccessAttemptsPerMinute = 20;
  static const Duration _suspiciousPatternWindow = Duration(minutes: 15);
  static const Duration _integrityCheckInterval = Duration(hours: 6);
  static const Duration _monitoringInterval = Duration(minutes: 5);

  /// Initialize the security audit service
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await SecureLoggingService.logSecurityEvent(
        'security_audit_service_initializing',
      );

      // Start continuous monitoring
      await _startSecurityMonitoring();

      // Start integrity checking
      await _startIntegrityChecking();

      // Perform initial security audit
      await performComprehensiveAudit();

      _initialized = true;

      await SecureLoggingService.logSecurityEvent(
        'security_audit_service_initialized',
        data: {'timestamp': DateTime.now().toIso8601String()},
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to initialize security audit service',
        error: e,
      );
      throw SecurityAuditException('Security audit initialization failed: $e');
    }
  }

  /// Dispose of the security audit service
  static Future<void> dispose() async {
    if (!_initialized) return;

    try {
      _monitoringTimer?.cancel();
      _integrityCheckTimer?.cancel();
      _activeAlerts.clear();
      _accessPatterns.clear();
      _fileIntegrityMap.clear();

      _initialized = false;

      await SecureLoggingService.logSecurityEvent(
        'security_audit_service_disposed',
      );
    } catch (e) {
      // Ignore disposal errors
    }
  }

  /// Performs a comprehensive security audit
  static Future<SecurityAuditResult> performComprehensiveAudit() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      await SecureLoggingService.logSecurityEvent(
        'comprehensive_audit_started',
      );

      final auditStartTime = DateTime.now();
      final issues = <SecurityIssue>[];
      final warnings = <SecurityWarning>[];

      // 1. Authentication security audit
      final authAudit = await _auditAuthenticationSecurity();
      issues.addAll(authAudit.issues);
      warnings.addAll(authAudit.warnings);

      // 2. File integrity audit
      final integrityAudit = await _auditFileIntegrity();
      issues.addAll(integrityAudit.issues);
      warnings.addAll(integrityAudit.warnings);

      // 3. Access pattern audit
      final accessAudit = await _auditAccessPatterns();
      issues.addAll(accessAudit.issues);
      warnings.addAll(accessAudit.warnings);

      // 4. Configuration security audit
      final configAudit = await _auditConfigurationSecurity();
      issues.addAll(configAudit.issues);
      warnings.addAll(configAudit.warnings);

      // 5. System security audit
      final systemAudit = await _auditSystemSecurity();
      issues.addAll(systemAudit.issues);
      warnings.addAll(systemAudit.warnings);

      final auditResult = SecurityAuditResult(
        auditTime: auditStartTime,
        completionTime: DateTime.now(),
        issues: issues,
        warnings: warnings,
        overallScore: _calculateSecurityScore(issues, warnings),
        recommendations: _generateRecommendations(issues, warnings),
      );

      await SecureLoggingService.logSecurityEvent(
        'comprehensive_audit_completed',
        data: {
          'duration': auditResult.completionTime
              .difference(auditResult.auditTime)
              .inMilliseconds,
          'issueCount': issues.length,
          'warningCount': warnings.length,
          'overallScore': auditResult.overallScore,
        },
      );

      // Generate alerts for critical issues
      await _processAuditResults(auditResult);

      return auditResult;
    } catch (e) {
      await SecureLoggingService.logError(
        'Comprehensive security audit failed',
        error: e,
      );

      return SecurityAuditResult(
        auditTime: DateTime.now(),
        completionTime: DateTime.now(),
        issues: [
          SecurityIssue(
            type: SecurityIssueType.auditFailure,
            severity: SecuritySeverity.critical,
            description: 'Security audit failed: ${e.toString()}',
            location: 'Security Audit System',
            recommendation: 'Investigate audit system integrity',
            detectedAt: DateTime.now(),
          ),
        ],
        warnings: [],
        overallScore: 0,
        recommendations: ['Investigate and fix audit system failure'],
      );
    }
  }

  /// Records an authentication event for monitoring
  static Future<void> recordAuthenticationEvent({
    required String eventType,
    required bool success,
    String? userId,
    String? deviceInfo,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final event = AuthenticationEvent(
        eventType: eventType,
        success: success,
        timestamp: DateTime.now(),
        userId: userId,
        deviceInfo: deviceInfo,
        additionalData: additionalData,
      );

      await SecureLoggingService.logSecurityEvent(
        'authentication_event_recorded',
        data: {
          'eventType': eventType,
          'success': success,
          'timestamp': event.timestamp.toIso8601String(),
          'hasUserId': userId != null,
          'hasDeviceInfo': deviceInfo != null,
        },
      );

      // Check for suspicious authentication patterns
      await _analyzeAuthenticationPattern(event);
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to record authentication event',
        error: e,
      );
    }
  }

  /// Records an access event for pattern analysis
  static Future<void> recordAccessEvent({
    required String resourceType,
    required String action,
    String? resourceId,
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final accessEvent = AccessPattern(
        resourceType: resourceType,
        action: action,
        timestamp: DateTime.now(),
        resourceId: resourceId,
        userId: userId,
        metadata: metadata,
      );

      _accessPatterns.add(accessEvent);

      // Keep only recent patterns (last 24 hours)
      final cutoffTime = DateTime.now().subtract(const Duration(hours: 24));
      _accessPatterns.removeWhere(
        (pattern) => pattern.timestamp.isBefore(cutoffTime),
      );

      await SecureLoggingService.logSecurityEvent(
        'access_event_recorded',
        data: {
          'resourceType': resourceType,
          'action': action,
          'timestamp': accessEvent.timestamp.toIso8601String(),
          'hasResourceId': resourceId != null,
          'hasUserId': userId != null,
        },
      );

      // Analyze for suspicious patterns
      await _analyzeAccessPattern(accessEvent);
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to record access event',
        error: e,
      );
    }
  }

  /// Checks integrity of a specific file
  static Future<FileIntegrityResult> checkFileIntegrity(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return FileIntegrityResult(
          filePath: filePath,
          isValid: false,
          issue: 'File does not exist',
          checkedAt: DateTime.now(),
        );
      }

      final fileBytes = await file.readAsBytes();
      final currentHash = sha256.convert(fileBytes).toString();
      final fileSize = fileBytes.length;
      final lastModified = file.lastModifiedSync();

      // Check against stored integrity info
      final storedInfo = _fileIntegrityMap[filePath];
      if (storedInfo != null) {
        if (storedInfo.hash != currentHash) {
          await SecureLoggingService.logSecurityEvent(
            'file_integrity_violation',
            data: {
              'filePath': filePath,
              'expectedHash': storedInfo.hash,
              'actualHash': currentHash,
              'lastModified': lastModified.toIso8601String(),
            },
          );

          return FileIntegrityResult(
            filePath: filePath,
            isValid: false,
            issue: 'File hash mismatch - possible tampering detected',
            checkedAt: DateTime.now(),
            expectedHash: storedInfo.hash,
            actualHash: currentHash,
          );
        }
      } else {
        // First time checking this file - store baseline
        _fileIntegrityMap[filePath] = FileIntegrityInfo(
          hash: currentHash,
          size: fileSize,
          lastModified: lastModified,
          firstChecked: DateTime.now(),
        );
      }

      return FileIntegrityResult(
        filePath: filePath,
        isValid: true,
        checkedAt: DateTime.now(),
        actualHash: currentHash,
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'File integrity check failed',
        data: {'filePath': filePath},
        error: e,
      );

      return FileIntegrityResult(
        filePath: filePath,
        isValid: false,
        issue: 'Integrity check failed: ${e.toString()}',
        checkedAt: DateTime.now(),
      );
    }
  }

  /// Gets current security alerts
  static List<SecurityAlert> getActiveAlerts() {
    return List.unmodifiable(_activeAlerts);
  }

  /// Dismisses a security alert
  static Future<void> dismissAlert(String alertId) async {
    try {
      _activeAlerts.removeWhere((alert) => alert.id == alertId);

      await SecureLoggingService.logSecurityEvent(
        'security_alert_dismissed',
        data: {
          'alertId': alertId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to dismiss security alert',
        data: {'alertId': alertId},
        error: e,
      );
    }
  }

  /// Gets security monitoring statistics
  static Future<SecurityMonitoringStats> getMonitoringStats() async {
    try {
      final now = DateTime.now();
      final last24Hours = now.subtract(const Duration(hours: 24));

      final recentAccessPatterns = _accessPatterns
          .where((pattern) => pattern.timestamp.isAfter(last24Hours))
          .length;

      final recentAlerts = _activeAlerts
          .where((alert) => alert.createdAt.isAfter(last24Hours))
          .length;

      final authStats = await EnhancedAuthService.getAuthStats();

      return SecurityMonitoringStats(
        activeAlerts: _activeAlerts.length,
        recentAccessPatterns: recentAccessPatterns,
        recentAlerts: recentAlerts,
        authFailures: authStats.failedAttempts,
        lastAuditTime: await _getLastAuditTime(),
        monitoredFiles: _fileIntegrityMap.length,
        integrityViolations: await _getIntegrityViolationCount(),
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to get monitoring stats',
        error: e,
      );

      return SecurityMonitoringStats(
        activeAlerts: 0,
        recentAccessPatterns: 0,
        recentAlerts: 0,
        authFailures: 0,
        lastAuditTime: null,
        monitoredFiles: 0,
        integrityViolations: 0,
      );
    }
  }

  // Private helper methods

  static Future<void> _startSecurityMonitoring() async {
    _monitoringTimer = Timer.periodic(_monitoringInterval, (timer) async {
      try {
        await _performRoutineSecurityCheck();
      } catch (e) {
        await SecureLoggingService.logError(
          'Routine security check failed',
          error: e,
        );
      }
    });
  }

  static Future<void> _startIntegrityChecking() async {
    _integrityCheckTimer = Timer.periodic(_integrityCheckInterval, (
      timer,
    ) async {
      try {
        await _performIntegrityChecks();
      } catch (e) {
        await SecureLoggingService.logError('Integrity check failed', error: e);
      }
    });
  }

  static Future<void> _performRoutineSecurityCheck() async {
    // Check for suspicious access patterns
    await _checkForSuspiciousAccessPatterns();

    // Check authentication anomalies
    await _checkAuthenticationAnomalies();

    // Clean up old data
    await _cleanupOldData();
  }

  static Future<void> _performIntegrityChecks() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final criticalFiles = [
        '${appDir.path}/vault.db',
        '${appDir.path}/config.json',
        '${appDir.path}/settings.json',
      ];

      for (final filePath in criticalFiles) {
        final result = await checkFileIntegrity(filePath);
        if (!result.isValid) {
          await _createSecurityAlert(
            type: SecurityAlertType.integrityViolation,
            severity: SecuritySeverity.high,
            title: 'File Integrity Violation',
            description:
                'Critical file integrity check failed: ${result.issue}',
            details: {
              'filePath': filePath,
              'issue': result.issue,
              'checkedAt': result.checkedAt.toIso8601String(),
            },
          );
        }
      }
    } catch (e) {
      await SecureLoggingService.logError('Integrity checks failed', error: e);
    }
  }

  static Future<AuthenticationAuditResult>
  _auditAuthenticationSecurity() async {
    final issues = <SecurityIssue>[];
    final warnings = <SecurityWarning>[];

    try {
      final authStats = await EnhancedAuthService.getAuthStats();

      // Check for excessive authentication failures
      if (authStats.failedAttempts >= 5) {
        issues.add(
          SecurityIssue(
            type: SecurityIssueType.authenticationAnomaly,
            severity: SecuritySeverity.high,
            description:
                'Excessive authentication failures detected (${authStats.failedAttempts})',
            location: 'Authentication System',
            recommendation:
                'Review authentication logs and consider account lockout',
            detectedAt: DateTime.now(),
          ),
        );
      } else if (authStats.failedAttempts >= 3) {
        warnings.add(
          SecurityWarning(
            type: 'authentication_failures',
            description:
                'Multiple authentication failures detected (${authStats.failedAttempts})',
            recommendation: 'Monitor authentication attempts',
            detectedAt: DateTime.now(),
          ),
        );
      }

      // Check for stale authentication
      if (authStats.lastSuccessTime != null) {
        final timeSinceLastAuth = DateTime.now().difference(
          authStats.lastSuccessTime!,
        );
        if (timeSinceLastAuth > const Duration(days: 30)) {
          warnings.add(
            SecurityWarning(
              type: 'stale_authentication',
              description:
                  'No successful authentication in ${timeSinceLastAuth.inDays} days',
              recommendation:
                  'Verify user activity and authentication requirements',
              detectedAt: DateTime.now(),
            ),
          );
        }
      }
    } catch (e) {
      issues.add(
        SecurityIssue(
          type: SecurityIssueType.auditFailure,
          severity: SecuritySeverity.medium,
          description: 'Authentication audit failed: ${e.toString()}',
          location: 'Authentication Audit',
          recommendation: 'Investigate authentication audit system',
          detectedAt: DateTime.now(),
        ),
      );
    }

    return AuthenticationAuditResult(issues: issues, warnings: warnings);
  }

  static Future<FileIntegrityAuditResult> _auditFileIntegrity() async {
    final issues = <SecurityIssue>[];
    final warnings = <SecurityWarning>[];

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final criticalFiles = [
        '${appDir.path}/vault.db',
        '${appDir.path}/config.json',
        '${appDir.path}/settings.json',
      ];

      for (final filePath in criticalFiles) {
        final result = await checkFileIntegrity(filePath);
        if (!result.isValid) {
          issues.add(
            SecurityIssue(
              type: SecurityIssueType.integrityViolation,
              severity: SecuritySeverity.critical,
              description: 'File integrity violation: ${result.issue}',
              location: filePath,
              recommendation:
                  'Investigate file tampering and restore from backup if necessary',
              detectedAt: DateTime.now(),
            ),
          );
        }
      }

      // Check for unexpected files
      final allFiles = appDir.listSync(recursive: true).whereType<File>();
      for (final file in allFiles) {
        final fileName = file.path.split('/').last.toLowerCase();
        if (_isSuspiciousFile(fileName)) {
          warnings.add(
            SecurityWarning(
              type: 'suspicious_file',
              description: 'Suspicious file detected: ${file.path}',
              recommendation: 'Review file origin and purpose',
              detectedAt: DateTime.now(),
            ),
          );
        }
      }
    } catch (e) {
      issues.add(
        SecurityIssue(
          type: SecurityIssueType.auditFailure,
          severity: SecuritySeverity.medium,
          description: 'File integrity audit failed: ${e.toString()}',
          location: 'File Integrity Audit',
          recommendation: 'Investigate file system access',
          detectedAt: DateTime.now(),
        ),
      );
    }

    return FileIntegrityAuditResult(issues: issues, warnings: warnings);
  }

  static Future<AccessPatternAuditResult> _auditAccessPatterns() async {
    final issues = <SecurityIssue>[];
    final warnings = <SecurityWarning>[];

    try {
      final now = DateTime.now();
      final lastHour = now.subtract(const Duration(hours: 1));
      final last24Hours = now.subtract(const Duration(hours: 24));

      // Check for excessive access attempts
      final recentAccess = _accessPatterns
          .where((pattern) => pattern.timestamp.isAfter(lastHour))
          .length;

      if (recentAccess > _maxAccessAttemptsPerMinute) {
        issues.add(
          SecurityIssue(
            type: SecurityIssueType.accessAnomaly,
            severity: SecuritySeverity.high,
            description:
                'Excessive access attempts detected ($recentAccess in last hour)',
            location: 'Access Pattern Monitor',
            recommendation: 'Investigate potential automated attacks',
            detectedAt: DateTime.now(),
          ),
        );
      }

      // Check for unusual access patterns
      final accessByType = <String, int>{};
      for (final pattern in _accessPatterns.where(
        (p) => p.timestamp.isAfter(last24Hours),
      )) {
        accessByType[pattern.resourceType] =
            (accessByType[pattern.resourceType] ?? 0) + 1;
      }

      for (final entry in accessByType.entries) {
        if (entry.value > 100) {
          // Threshold for unusual activity
          warnings.add(
            SecurityWarning(
              type: 'unusual_access_pattern',
              description:
                  'High access frequency for ${entry.key}: ${entry.value} times in 24 hours',
              recommendation: 'Review access patterns for ${entry.key}',
              detectedAt: DateTime.now(),
            ),
          );
        }
      }
    } catch (e) {
      issues.add(
        SecurityIssue(
          type: SecurityIssueType.auditFailure,
          severity: SecuritySeverity.medium,
          description: 'Access pattern audit failed: ${e.toString()}',
          location: 'Access Pattern Audit',
          recommendation: 'Investigate access monitoring system',
          detectedAt: DateTime.now(),
        ),
      );
    }

    return AccessPatternAuditResult(issues: issues, warnings: warnings);
  }

  static Future<ConfigurationAuditResult> _auditConfigurationSecurity() async {
    final issues = <SecurityIssue>[];
    final warnings = <SecurityWarning>[];

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final configFile = File('${appDir.path}/config.json');

      if (configFile.existsSync()) {
        final configContent = await configFile.readAsString();
        final config = jsonDecode(configContent) as Map<String, dynamic>;

        // Check for insecure configuration
        if (config['debug'] == true) {
          warnings.add(
            SecurityWarning(
              type: 'debug_mode_enabled',
              description: 'Debug mode is enabled in production',
              recommendation: 'Disable debug mode for production builds',
              detectedAt: DateTime.now(),
            ),
          );
        }

        if (config['logging_level'] == 'debug') {
          warnings.add(
            SecurityWarning(
              type: 'verbose_logging',
              description: 'Verbose logging is enabled',
              recommendation: 'Use appropriate logging level for production',
              detectedAt: DateTime.now(),
            ),
          );
        }
      }
    } catch (e) {
      issues.add(
        SecurityIssue(
          type: SecurityIssueType.auditFailure,
          severity: SecuritySeverity.low,
          description: 'Configuration audit failed: ${e.toString()}',
          location: 'Configuration Audit',
          recommendation: 'Review configuration file access',
          detectedAt: DateTime.now(),
        ),
      );
    }

    return ConfigurationAuditResult(issues: issues, warnings: warnings);
  }

  static Future<SystemAuditResult> _auditSystemSecurity() async {
    final issues = <SecurityIssue>[];
    final warnings = <SecurityWarning>[];

    try {
      // Check available biometrics
      final canCheckBiometrics = await EnhancedAuthService.canCheckBiometrics();
      if (!canCheckBiometrics) {
        warnings.add(
          SecurityWarning(
            type: 'biometrics_unavailable',
            description: 'Biometric authentication is not available',
            recommendation:
                'Enable biometric authentication for enhanced security',
            detectedAt: DateTime.now(),
          ),
        );
      }

      // Check device support
      final isDeviceSupported = await EnhancedAuthService.isDeviceSupported();
      if (!isDeviceSupported) {
        issues.add(
          SecurityIssue(
            type: SecurityIssueType.systemVulnerability,
            severity: SecuritySeverity.medium,
            description: 'Device does not support secure authentication',
            location: 'System Security',
            recommendation: 'Use alternative security measures',
            detectedAt: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      issues.add(
        SecurityIssue(
          type: SecurityIssueType.auditFailure,
          severity: SecuritySeverity.low,
          description: 'System audit failed: ${e.toString()}',
          location: 'System Audit',
          recommendation: 'Investigate system security capabilities',
          detectedAt: DateTime.now(),
        ),
      );
    }

    return SystemAuditResult(issues: issues, warnings: warnings);
  }

  static Future<void> _analyzeAuthenticationPattern(
    AuthenticationEvent event,
  ) async {
    if (!event.success) {
      // Check for rapid authentication failures
      final recentLogs = await SecureLoggingService.getRecentLogs(limit: 50);
      final recentFailures = recentLogs
          .where(
            (log) =>
                log.message.contains('auth_failure') &&
                DateTime.now().difference(log.timestamp) <
                    const Duration(minutes: 15),
          )
          .length;

      if (recentFailures >= 5) {
        await _createSecurityAlert(
          type: SecurityAlertType.authenticationAnomaly,
          severity: SecuritySeverity.high,
          title: 'Rapid Authentication Failures',
          description:
              'Multiple authentication failures detected in short time period',
          details: {
            'failureCount': recentFailures,
            'timeWindow': '15 minutes',
            'eventType': event.eventType,
          },
        );
      }
    }
  }

  static Future<void> _analyzeAccessPattern(AccessPattern pattern) async {
    // Check for rapid access attempts
    final recentSimilarAccess = _accessPatterns
        .where(
          (p) =>
              p.resourceType == pattern.resourceType &&
              p.action == pattern.action &&
              DateTime.now().difference(p.timestamp) <
                  const Duration(minutes: 1),
        )
        .length;

    if (recentSimilarAccess > 10) {
      await _createSecurityAlert(
        type: SecurityAlertType.accessAnomaly,
        severity: SecuritySeverity.medium,
        title: 'Rapid Access Pattern',
        description: 'Unusually high access frequency detected',
        details: {
          'resourceType': pattern.resourceType,
          'action': pattern.action,
          'accessCount': recentSimilarAccess,
          'timeWindow': '1 minute',
        },
      );
    }
  }

  static Future<void> _checkForSuspiciousAccessPatterns() async {
    final now = DateTime.now();
    final suspiciousWindow = now.subtract(_suspiciousPatternWindow);

    // Group access patterns by resource type and action
    final patternGroups = <String, List<AccessPattern>>{};
    for (final pattern in _accessPatterns.where(
      (p) => p.timestamp.isAfter(suspiciousWindow),
    )) {
      final key = '${pattern.resourceType}:${pattern.action}';
      patternGroups[key] = (patternGroups[key] ?? [])..add(pattern);
    }

    // Check for suspicious patterns
    for (final entry in patternGroups.entries) {
      if (entry.value.length > 20) {
        // Threshold for suspicious activity
        await _createSecurityAlert(
          type: SecurityAlertType.accessAnomaly,
          severity: SecuritySeverity.medium,
          title: 'Suspicious Access Pattern',
          description: 'High frequency access pattern detected',
          details: {
            'pattern': entry.key,
            'count': entry.value.length,
            'timeWindow': _suspiciousPatternWindow.inMinutes,
          },
        );
      }
    }
  }

  static Future<void> _checkAuthenticationAnomalies() async {
    try {
      final authStats = await EnhancedAuthService.getAuthStats();

      // Check for authentication anomalies
      if (authStats.failedAttempts >= _maxAuthFailuresPerHour) {
        await _createSecurityAlert(
          type: SecurityAlertType.authenticationAnomaly,
          severity: SecuritySeverity.high,
          title: 'Excessive Authentication Failures',
          description: 'High number of authentication failures detected',
          details: {
            'failureCount': authStats.failedAttempts,
            'lastFailure': authStats.lastFailureTime?.toIso8601String(),
          },
        );
      }
    } catch (e) {
      await SecureLoggingService.logError(
        'Authentication anomaly check failed',
        error: e,
      );
    }
  }

  static Future<void> _cleanupOldData() async {
    final cutoffTime = DateTime.now().subtract(const Duration(days: 7));

    // Clean up old access patterns
    _accessPatterns.removeWhere(
      (pattern) => pattern.timestamp.isBefore(cutoffTime),
    );

    // Clean up old alerts
    _activeAlerts.removeWhere((alert) => alert.createdAt.isBefore(cutoffTime));
  }

  static Future<void> _createSecurityAlert({
    required SecurityAlertType type,
    required SecuritySeverity severity,
    required String title,
    required String description,
    Map<String, dynamic>? details,
  }) async {
    final alert = SecurityAlert(
      id: _generateAlertId(),
      type: type,
      severity: severity,
      title: title,
      description: description,
      details: details ?? {},
      createdAt: DateTime.now(),
    );

    _activeAlerts.add(alert);

    await SecureLoggingService.logSecurityEvent(
      'security_alert_created',
      data: {
        'alertId': alert.id,
        'type': type.name,
        'severity': severity.name,
        'title': title,
        'description': description,
      },
    );
  }

  static Future<void> _processAuditResults(SecurityAuditResult result) async {
    // Create alerts for critical issues
    for (final issue in result.issues) {
      if (issue.severity == SecuritySeverity.critical) {
        await _createSecurityAlert(
          type: SecurityAlertType.criticalIssue,
          severity: issue.severity,
          title: 'Critical Security Issue',
          description: issue.description,
          details: {
            'issueType': issue.type.name,
            'location': issue.location,
            'recommendation': issue.recommendation,
          },
        );
      }
    }
  }

  static int _calculateSecurityScore(
    List<SecurityIssue> issues,
    List<SecurityWarning> warnings,
  ) {
    int score = 100;

    for (final issue in issues) {
      switch (issue.severity) {
        case SecuritySeverity.critical:
          score -= 25;
          break;
        case SecuritySeverity.high:
          score -= 15;
          break;
        case SecuritySeverity.medium:
          score -= 10;
          break;
        case SecuritySeverity.low:
          score -= 5;
          break;
      }
    }

    score -= warnings.length * 2;

    return math.max(0, score);
  }

  static List<String> _generateRecommendations(
    List<SecurityIssue> issues,
    List<SecurityWarning> warnings,
  ) {
    final recommendations = <String>[];

    // Add issue recommendations
    for (final issue in issues) {
      if (!recommendations.contains(issue.recommendation)) {
        recommendations.add(issue.recommendation);
      }
    }

    // Add warning recommendations
    for (final warning in warnings) {
      if (!recommendations.contains(warning.recommendation)) {
        recommendations.add(warning.recommendation);
      }
    }

    // Add general recommendations based on score
    final score = _calculateSecurityScore(issues, warnings);
    if (score < 50) {
      recommendations.add('Immediate security review required');
    } else if (score < 75) {
      recommendations.add('Address security issues promptly');
    }

    return recommendations;
  }

  static bool _isSuspiciousFile(String fileName) {
    final suspiciousPatterns = [
      'temp',
      'tmp',
      'backup',
      'old',
      'copy',
      'debug',
      'test',
      'dump',
    ];

    return suspiciousPatterns.any((pattern) => fileName.contains(pattern));
  }

  static String _generateAlertId() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url.encode(bytes).substring(0, 16);
  }

  static Future<DateTime?> _getLastAuditTime() async {
    try {
      final logs = await SecureLoggingService.getRecentLogs(limit: 1000);
      final auditLogs = logs
          .where((log) => log.message.contains('comprehensive_audit_completed'))
          .toList();

      if (auditLogs.isNotEmpty) {
        auditLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return auditLogs.first.timestamp;
      }
    } catch (e) {
      // Ignore errors
    }
    return null;
  }

  static Future<int> _getIntegrityViolationCount() async {
    try {
      final logs = await SecureLoggingService.getRecentLogs(limit: 1000);
      return logs
          .where((log) => log.message.contains('file_integrity_violation'))
          .length;
    } catch (e) {
      return 0;
    }
  }
}

// Data classes and enums

/// Security audit exception
class SecurityAuditException implements Exception {
  final String message;
  SecurityAuditException(this.message);
  @override
  String toString() => 'SecurityAuditException: $message';
}

/// Security audit result
class SecurityAuditResult {
  final DateTime auditTime;
  final DateTime completionTime;
  final List<SecurityIssue> issues;
  final List<SecurityWarning> warnings;
  final int overallScore;
  final List<String> recommendations;

  SecurityAuditResult({
    required this.auditTime,
    required this.completionTime,
    required this.issues,
    required this.warnings,
    required this.overallScore,
    required this.recommendations,
  });

  Duration get auditDuration => completionTime.difference(auditTime);

  Map<String, dynamic> toJson() => {
    'auditTime': auditTime.toIso8601String(),
    'completionTime': completionTime.toIso8601String(),
    'auditDuration': auditDuration.inMilliseconds,
    'issues': issues.map((i) => i.toJson()).toList(),
    'warnings': warnings.map((w) => w.toJson()).toList(),
    'overallScore': overallScore,
    'recommendations': recommendations,
  };
}

/// Security issue
class SecurityIssue {
  final SecurityIssueType type;
  final SecuritySeverity severity;
  final String description;
  final String location;
  final String recommendation;
  final DateTime detectedAt;

  SecurityIssue({
    required this.type,
    required this.severity,
    required this.description,
    required this.location,
    required this.recommendation,
    required this.detectedAt,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'severity': severity.name,
    'description': description,
    'location': location,
    'recommendation': recommendation,
    'detectedAt': detectedAt.toIso8601String(),
  };
}

/// Security warning
class SecurityWarning {
  final String type;
  final String description;
  final String recommendation;
  final DateTime detectedAt;

  SecurityWarning({
    required this.type,
    required this.description,
    required this.recommendation,
    required this.detectedAt,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'description': description,
    'recommendation': recommendation,
    'detectedAt': detectedAt.toIso8601String(),
  };
}

/// Security alert
class SecurityAlert {
  final String id;
  final SecurityAlertType type;
  final SecuritySeverity severity;
  final String title;
  final String description;
  final Map<String, dynamic> details;
  final DateTime createdAt;
  final List<String> recommendations;
  final AlertStatus status;
  final String? resolution;
  final DateTime? resolvedAt;
  final Duration? autoResolveAfter;

  SecurityAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.details,
    required this.createdAt,
    this.recommendations = const [],
    this.status = AlertStatus.active,
    this.resolution,
    this.resolvedAt,
    this.autoResolveAfter,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'severity': severity.name,
    'title': title,
    'description': description,
    'details': details,
    'createdAt': createdAt.toIso8601String(),
    'recommendations': recommendations,
    'status': status.name,
    'resolution': resolution,
    'resolvedAt': resolvedAt?.toIso8601String(),
    'autoResolveAfter': autoResolveAfter?.inMinutes,
  };

  factory SecurityAlert.fromJson(Map<String, dynamic> json) => SecurityAlert(
    id: json['id'],
    type: SecurityAlertType.values.firstWhere((t) => t.name == json['type']),
    severity: SecuritySeverity.values.firstWhere(
      (s) => s.name == json['severity'],
    ),
    title: json['title'],
    description: json['description'],
    details: Map<String, dynamic>.from(json['details']),
    createdAt: DateTime.parse(json['createdAt']),
    recommendations: List<String>.from(json['recommendations'] ?? []),
    status: AlertStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => AlertStatus.active,
    ),
    resolution: json['resolution'],
    resolvedAt: json['resolvedAt'] != null
        ? DateTime.parse(json['resolvedAt'])
        : null,
    autoResolveAfter: json['autoResolveAfter'] != null
        ? Duration(minutes: json['autoResolveAfter'])
        : null,
  );
}

/// Authentication event
class AuthenticationEvent {
  final String eventType;
  final bool success;
  final DateTime timestamp;
  final String? userId;
  final String? deviceInfo;
  final Map<String, dynamic>? additionalData;

  AuthenticationEvent({
    required this.eventType,
    required this.success,
    required this.timestamp,
    this.userId,
    this.deviceInfo,
    this.additionalData,
  });
}

/// Access pattern
class AccessPattern {
  final String resourceType;
  final String action;
  final DateTime timestamp;
  final String? resourceId;
  final String? userId;
  final Map<String, dynamic>? metadata;

  AccessPattern({
    required this.resourceType,
    required this.action,
    required this.timestamp,
    this.resourceId,
    this.userId,
    this.metadata,
  });
}

/// File integrity information
class FileIntegrityInfo {
  final String hash;
  final int size;
  final DateTime lastModified;
  final DateTime firstChecked;

  FileIntegrityInfo({
    required this.hash,
    required this.size,
    required this.lastModified,
    required this.firstChecked,
  });
}

/// File integrity check result
class FileIntegrityResult {
  final String filePath;
  final bool isValid;
  final String? issue;
  final DateTime checkedAt;
  final String? expectedHash;
  final String? actualHash;

  FileIntegrityResult({
    required this.filePath,
    required this.isValid,
    this.issue,
    required this.checkedAt,
    this.expectedHash,
    this.actualHash,
  });
}

/// Security monitoring statistics
class SecurityMonitoringStats {
  final int activeAlerts;
  final int recentAccessPatterns;
  final int recentAlerts;
  final int authFailures;
  final DateTime? lastAuditTime;
  final int monitoredFiles;
  final int integrityViolations;

  SecurityMonitoringStats({
    required this.activeAlerts,
    required this.recentAccessPatterns,
    required this.recentAlerts,
    required this.authFailures,
    required this.lastAuditTime,
    required this.monitoredFiles,
    required this.integrityViolations,
  });

  Map<String, dynamic> toJson() => {
    'activeAlerts': activeAlerts,
    'recentAccessPatterns': recentAccessPatterns,
    'recentAlerts': recentAlerts,
    'authFailures': authFailures,
    'lastAuditTime': lastAuditTime?.toIso8601String(),
    'monitoredFiles': monitoredFiles,
    'integrityViolations': integrityViolations,
  };
}

// Audit result classes
class AuthenticationAuditResult {
  final List<SecurityIssue> issues;
  final List<SecurityWarning> warnings;
  AuthenticationAuditResult({required this.issues, required this.warnings});
}

class FileIntegrityAuditResult {
  final List<SecurityIssue> issues;
  final List<SecurityWarning> warnings;
  FileIntegrityAuditResult({required this.issues, required this.warnings});
}

class AccessPatternAuditResult {
  final List<SecurityIssue> issues;
  final List<SecurityWarning> warnings;
  AccessPatternAuditResult({required this.issues, required this.warnings});
}

class ConfigurationAuditResult {
  final List<SecurityIssue> issues;
  final List<SecurityWarning> warnings;
  ConfigurationAuditResult({required this.issues, required this.warnings});
}

class SystemAuditResult {
  final List<SecurityIssue> issues;
  final List<SecurityWarning> warnings;
  SystemAuditResult({required this.issues, required this.warnings});
}

// Enums
enum SecurityIssueType {
  authenticationAnomaly,
  integrityViolation,
  accessAnomaly,
  systemVulnerability,
  configurationIssue,
  auditFailure,
}

enum SecuritySeverity { low, medium, high, critical }

enum SecurityAlertType {
  authenticationAnomaly,
  accessAnomaly,
  integrityViolation,
  criticalIssue,
  systemAlert,
}

enum AlertStatus { active, resolved, dismissed }
