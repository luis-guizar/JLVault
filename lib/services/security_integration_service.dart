import 'dart:async';
import 'data_security_service.dart';
import 'secure_logging_service.dart';
import 'secure_temp_file_service.dart';
import 'data_storage_auditor.dart';
import 'enhanced_auth_service.dart';

/// Service that integrates all security components and ensures they work together
class SecurityIntegrationService {
  static bool _initialized = false;
  static Timer? _monitoringTimer;

  /// Initialize all security services in the correct order
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await SecureLoggingService.logInfo(
        'Security integration service initializing',
      );

      // Step 1: Initialize core security services
      await SecureLoggingService.initialize();
      await SecureTempFileService.initialize();
      await EnhancedAuthService.initialize();

      // Step 2: Initialize data security service (depends on others)
      await DataSecurityService.initialize();

      // Step 3: Start security monitoring
      await _startSecurityMonitoring();

      // Step 4: Perform initial security check
      await _performInitialSecurityCheck();

      _initialized = true;

      await SecureLoggingService.logSecurityEvent(
        'security_integration_service_initialized',
        data: {'timestamp': DateTime.now().toIso8601String(), 'version': '1.0'},
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to initialize security integration service',
        error: e,
      );
      throw SecurityInitializationException(
        'Security initialization failed: $e',
      );
    }
  }

  /// Dispose of all security services
  static Future<void> dispose() async {
    if (!_initialized) return;

    try {
      await SecureLoggingService.logSecurityEvent(
        'security_integration_service_disposing',
      );

      // Stop monitoring
      _monitoringTimer?.cancel();

      // Dispose services in reverse order
      await DataSecurityService.dispose();
      await EnhancedAuthService.dispose();
      await SecureTempFileService.deleteAllTempFiles();
      await SecureLoggingService.dispose();

      _initialized = false;

      // Final log (may not be written if logging is disposed)
      await SecureLoggingService.logSecurityEvent(
        'security_integration_service_disposed',
      );
    } catch (e) {
      // Ignore disposal errors to prevent blocking app shutdown
    }
  }

  /// Performs a comprehensive security health check
  static Future<SecurityHealthReport> performSecurityHealthCheck() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      await SecureLoggingService.logSecurityEvent(
        'security_health_check_started',
      );

      // Perform comprehensive audit
      final auditReport = await DataSecurityService.performSecurityAudit();

      // Get authentication statistics
      final authStats = await EnhancedAuthService.getAuthStats();

      // Get security service statistics
      final securityStats = await DataSecurityService.getSecurityStats();

      // Check for active security threats
      final threats = await _checkForActiveThreats();

      // Compile health report
      final healthReport = SecurityHealthReport(
        timestamp: DateTime.now(),
        auditReport: auditReport,
        authStats: authStats,
        securityStats: securityStats,
        activeThreats: threats,
        overallHealth: _calculateOverallHealth(auditReport, authStats, threats),
      );

      await SecureLoggingService.logSecurityEvent(
        'security_health_check_completed',
        data: {
          'overallHealth': healthReport.overallHealth.name,
          'threatCount': threats.length,
          'auditCompliance': auditReport.overallCompliance,
        },
      );

      return healthReport;
    } catch (e) {
      await SecureLoggingService.logError(
        'Security health check failed',
        error: e,
      );

      return SecurityHealthReport(
        timestamp: DateTime.now(),
        auditReport: SecurityAuditReport(
          auditTime: DateTime.now(),
          storageAudit: StorageAuditResult(
            auditTime: DateTime.now(),
            checkedLocations: [],
            issues: [],
            isCompliant: false,
          ),
          tempFileIssues: [],
          logFileIssues: [],
          databaseIssues: [],
          overallCompliance: false,
        ),
        authStats: AuthStats(failedAttempts: 0),
        securityStats: SecurityStats(
          lastAuditTime: null,
          recentLogCount: 0,
          activeTempFileCount: 0,
          securityEventCount: 0,
          errorCount: 1,
        ),
        activeThreats: [
          SecurityThreat(
            type: 'system_error',
            severity: ThreatSeverity.high,
            description: 'Security health check failed: ${e.toString()}',
            recommendation: 'Investigate system integrity',
          ),
        ],
        overallHealth: SecurityHealth.critical,
      );
    }
  }

  /// Validates that a sensitive operation can be performed securely
  static Future<SecurityValidationResult> validateSensitiveOperation(
    String operation, {
    Map<String, dynamic>? context,
  }) async {
    try {
      await SecureLoggingService.logSecurityEvent(
        'sensitive_operation_validation_started',
        data: {'operation': operation, 'context': context},
      );

      final issues = <String>[];
      final warnings = <String>[];

      // Check if security services are initialized
      if (!_initialized) {
        issues.add('Security services not initialized');
      }

      // Check for recent security audit
      final securityStats = await DataSecurityService.getSecurityStats();
      if (securityStats.lastAuditTime == null ||
          DateTime.now().difference(securityStats.lastAuditTime!) >
              const Duration(days: 7)) {
        warnings.add('Security audit is overdue');
      }

      // Check authentication status
      final authStats = await EnhancedAuthService.getAuthStats();
      if (authStats.failedAttempts > 3) {
        issues.add('Multiple recent authentication failures detected');
      }

      // Check for active temporary files
      if (securityStats.activeTempFileCount > 10) {
        warnings.add('High number of active temporary files');
      }

      // Check for recent errors
      if (securityStats.errorCount > 5) {
        warnings.add('Multiple recent security errors detected');
      }

      final canProceed = issues.isEmpty;
      final result = SecurityValidationResult(
        canProceed: canProceed,
        issues: issues,
        warnings: warnings,
        operation: operation,
        timestamp: DateTime.now(),
      );

      await SecureLoggingService.logSecurityEvent(
        'sensitive_operation_validation_completed',
        data: {
          'operation': operation,
          'canProceed': canProceed,
          'issueCount': issues.length,
          'warningCount': warnings.length,
        },
      );

      return result;
    } catch (e) {
      await SecureLoggingService.logError(
        'Sensitive operation validation failed',
        data: {'operation': operation},
        error: e,
      );

      return SecurityValidationResult(
        canProceed: false,
        issues: ['Validation failed: ${e.toString()}'],
        warnings: [],
        operation: operation,
        timestamp: DateTime.now(),
      );
    }
  }

  /// Handles security incidents and takes appropriate action
  static Future<void> handleSecurityIncident(
    String incidentType,
    String description, {
    Map<String, dynamic>? details,
    ThreatSeverity severity = ThreatSeverity.medium,
  }) async {
    try {
      await SecureLoggingService.logSecurityEvent(
        'security_incident_detected',
        data: {
          'incidentType': incidentType,
          'description': description,
          'severity': severity.name,
          'details': details,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Take automatic actions based on severity
      switch (severity) {
        case ThreatSeverity.critical:
          await _handleCriticalIncident(incidentType, description, details);
          break;
        case ThreatSeverity.high:
          await _handleHighSeverityIncident(incidentType, description, details);
          break;
        case ThreatSeverity.medium:
          await _handleMediumSeverityIncident(
            incidentType,
            description,
            details,
          );
          break;
        case ThreatSeverity.low:
          await _handleLowSeverityIncident(incidentType, description, details);
          break;
      }

      await SecureLoggingService.logSecurityEvent(
        'security_incident_handled',
        data: {'incidentType': incidentType, 'severity': severity.name},
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to handle security incident',
        data: {
          'incidentType': incidentType,
          'originalDescription': description,
        },
        error: e,
      );
    }
  }

  /// Gets the current security status
  static Future<SecurityStatus> getSecurityStatus() async {
    try {
      final healthReport = await performSecurityHealthCheck();

      return SecurityStatus(
        isInitialized: _initialized,
        overallHealth: healthReport.overallHealth,
        lastAuditTime: healthReport.securityStats.lastAuditTime,
        activeThreats: healthReport.activeThreats.length,
        recentErrors: healthReport.securityStats.errorCount,
        authFailures: healthReport.authStats.failedAttempts,
      );
    } catch (e) {
      return SecurityStatus(
        isInitialized: _initialized,
        overallHealth: SecurityHealth.critical,
        lastAuditTime: null,
        activeThreats: 1,
        recentErrors: 1,
        authFailures: 0,
      );
    }
  }

  // Private helper methods

  static Future<void> _startSecurityMonitoring() async {
    // Monitor security health every 30 minutes
    _monitoringTimer = Timer.periodic(const Duration(minutes: 30), (
      timer,
    ) async {
      try {
        final healthReport = await performSecurityHealthCheck();

        // Check for critical issues
        if (healthReport.overallHealth == SecurityHealth.critical) {
          await handleSecurityIncident(
            'critical_security_health',
            'Critical security health detected during monitoring',
            severity: ThreatSeverity.critical,
          );
        }

        // Check for high-severity threats
        final highSeverityThreats = healthReport.activeThreats
            .where((threat) => threat.severity == ThreatSeverity.high)
            .toList();

        if (highSeverityThreats.isNotEmpty) {
          await handleSecurityIncident(
            'high_severity_threats_detected',
            'Multiple high-severity threats detected: ${highSeverityThreats.length}',
            details: {
              'threatCount': highSeverityThreats.length,
              'threats': highSeverityThreats.map((t) => t.type).toList(),
            },
            severity: ThreatSeverity.high,
          );
        }
      } catch (e) {
        await SecureLoggingService.logError(
          'Security monitoring check failed',
          error: e,
        );
      }
    });
  }

  static Future<void> _performInitialSecurityCheck() async {
    try {
      // Perform initial audit
      final auditReport = await DataSecurityService.performSecurityAudit();

      if (!auditReport.overallCompliance) {
        await handleSecurityIncident(
          'initial_audit_non_compliance',
          'Initial security audit found compliance issues',
          details: {
            'totalIssues': auditReport.getTotalIssueCount(),
            'highSeverityIssues': auditReport.getHighSeverityIssueCount(),
          },
          severity: auditReport.getHighSeverityIssueCount() > 0
              ? ThreatSeverity.high
              : ThreatSeverity.medium,
        );
      }

      // Clean up any leftover temporary files
      await DataSecurityService.performSecurityCleanup();
    } catch (e) {
      await SecureLoggingService.logError(
        'Initial security check failed',
        error: e,
      );
    }
  }

  static Future<List<SecurityThreat>> _checkForActiveThreats() async {
    final threats = <SecurityThreat>[];

    try {
      // Check for authentication threats
      final authStats = await EnhancedAuthService.getAuthStats();
      if (authStats.failedAttempts >= 5) {
        threats.add(
          SecurityThreat(
            type: 'excessive_auth_failures',
            severity: ThreatSeverity.high,
            description:
                'Excessive authentication failures detected (${authStats.failedAttempts})',
            recommendation:
                'Review authentication logs and consider account lockout',
          ),
        );
      }

      // Check for temporary file threats
      final securityStats = await DataSecurityService.getSecurityStats();
      if (securityStats.activeTempFileCount > 20) {
        threats.add(
          SecurityThreat(
            type: 'temp_file_accumulation',
            severity: ThreatSeverity.medium,
            description:
                'High number of active temporary files (${securityStats.activeTempFileCount})',
            recommendation: 'Clean up temporary files and check for file leaks',
          ),
        );
      }

      // Check for error accumulation
      if (securityStats.errorCount > 10) {
        threats.add(
          SecurityThreat(
            type: 'error_accumulation',
            severity: ThreatSeverity.medium,
            description:
                'High number of recent errors (${securityStats.errorCount})',
            recommendation: 'Review error logs and address underlying issues',
          ),
        );
      }

      // Check for stale audits
      if (securityStats.lastAuditTime == null ||
          DateTime.now().difference(securityStats.lastAuditTime!) >
              const Duration(days: 7)) {
        threats.add(
          SecurityThreat(
            type: 'stale_security_audit',
            severity: ThreatSeverity.low,
            description: 'Security audit is overdue',
            recommendation: 'Perform security audit to ensure system integrity',
          ),
        );
      }
    } catch (e) {
      threats.add(
        SecurityThreat(
          type: 'threat_detection_error',
          severity: ThreatSeverity.medium,
          description: 'Failed to check for active threats: ${e.toString()}',
          recommendation: 'Investigate threat detection system',
        ),
      );
    }

    return threats;
  }

  static SecurityHealth _calculateOverallHealth(
    SecurityAuditReport auditReport,
    AuthStats authStats,
    List<SecurityThreat> threats,
  ) {
    // Critical if audit is non-compliant or critical threats exist
    if (!auditReport.overallCompliance ||
        threats.any((t) => t.severity == ThreatSeverity.critical)) {
      return SecurityHealth.critical;
    }

    // Poor if high-severity threats or many auth failures
    if (threats.any((t) => t.severity == ThreatSeverity.high) ||
        authStats.failedAttempts >= 5) {
      return SecurityHealth.poor;
    }

    // Fair if medium-severity threats or some auth failures
    if (threats.any((t) => t.severity == ThreatSeverity.medium) ||
        authStats.failedAttempts >= 3) {
      return SecurityHealth.fair;
    }

    // Good if only low-severity threats
    if (threats.any((t) => t.severity == ThreatSeverity.low)) {
      return SecurityHealth.good;
    }

    // Excellent if no threats
    return SecurityHealth.excellent;
  }

  static Future<void> _handleCriticalIncident(
    String incidentType,
    String description,
    Map<String, dynamic>? details,
  ) async {
    // For critical incidents, perform immediate security cleanup
    await DataSecurityService.performSecurityCleanup();

    // Clear sensitive data from memory
    await EnhancedAuthService.onAppPaused();

    // Log critical incident
    await SecureLoggingService.logError(
      'CRITICAL SECURITY INCIDENT: $description',
      data: {
        'incidentType': incidentType,
        'details': details,
        'automaticActions': [
          'security_cleanup_performed',
          'sensitive_data_cleared',
        ],
      },
    );
  }

  static Future<void> _handleHighSeverityIncident(
    String incidentType,
    String description,
    Map<String, dynamic>? details,
  ) async {
    // For high-severity incidents, perform security audit
    await DataSecurityService.performSecurityAudit();

    // Clean up temporary files
    await SecureTempFileService.deleteAllTempFiles();

    await SecureLoggingService.logWarning(
      'HIGH SEVERITY SECURITY INCIDENT: $description',
      data: {
        'incidentType': incidentType,
        'details': details,
        'automaticActions': ['security_audit_performed', 'temp_files_cleaned'],
      },
    );
  }

  static Future<void> _handleMediumSeverityIncident(
    String incidentType,
    String description,
    Map<String, dynamic>? details,
  ) async {
    // For medium-severity incidents, log and monitor
    await SecureLoggingService.logWarning(
      'MEDIUM SEVERITY SECURITY INCIDENT: $description',
      data: {
        'incidentType': incidentType,
        'details': details,
        'automaticActions': ['logged_for_monitoring'],
      },
    );
  }

  static Future<void> _handleLowSeverityIncident(
    String incidentType,
    String description,
    Map<String, dynamic>? details,
  ) async {
    // For low-severity incidents, just log
    await SecureLoggingService.logInfo(
      'LOW SEVERITY SECURITY INCIDENT: $description',
      data: {'incidentType': incidentType, 'details': details},
    );
  }
}

/// Comprehensive security health report
class SecurityHealthReport {
  final DateTime timestamp;
  final SecurityAuditReport auditReport;
  final AuthStats authStats;
  final SecurityStats securityStats;
  final List<SecurityThreat> activeThreats;
  final SecurityHealth overallHealth;

  SecurityHealthReport({
    required this.timestamp,
    required this.auditReport,
    required this.authStats,
    required this.securityStats,
    required this.activeThreats,
    required this.overallHealth,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'overallHealth': overallHealth.name,
      'auditReport': auditReport.toJson(),
      'authStats': authStats,
      'securityStats': securityStats.toJson(),
      'activeThreats': activeThreats.map((t) => t.toJson()).toList(),
    };
  }
}

/// Security threat information
class SecurityThreat {
  final String type;
  final ThreatSeverity severity;
  final String description;
  final String recommendation;

  SecurityThreat({
    required this.type,
    required this.severity,
    required this.description,
    required this.recommendation,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'severity': severity.name,
      'description': description,
      'recommendation': recommendation,
    };
  }
}

/// Security validation result
class SecurityValidationResult {
  final bool canProceed;
  final List<String> issues;
  final List<String> warnings;
  final String operation;
  final DateTime timestamp;

  SecurityValidationResult({
    required this.canProceed,
    required this.issues,
    required this.warnings,
    required this.operation,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'canProceed': canProceed,
      'issues': issues,
      'warnings': warnings,
      'operation': operation,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Current security status
class SecurityStatus {
  final bool isInitialized;
  final SecurityHealth overallHealth;
  final DateTime? lastAuditTime;
  final int activeThreats;
  final int recentErrors;
  final int authFailures;

  SecurityStatus({
    required this.isInitialized,
    required this.overallHealth,
    required this.lastAuditTime,
    required this.activeThreats,
    required this.recentErrors,
    required this.authFailures,
  });

  Map<String, dynamic> toJson() {
    return {
      'isInitialized': isInitialized,
      'overallHealth': overallHealth.name,
      'lastAuditTime': lastAuditTime?.toIso8601String(),
      'activeThreats': activeThreats,
      'recentErrors': recentErrors,
      'authFailures': authFailures,
    };
  }
}

/// Security health levels
enum SecurityHealth { excellent, good, fair, poor, critical }

/// Threat severity levels
enum ThreatSeverity { low, medium, high, critical }

/// Exception thrown during security initialization
class SecurityInitializationException implements Exception {
  final String message;

  SecurityInitializationException(this.message);

  @override
  String toString() => 'SecurityInitializationException: $message';
}
