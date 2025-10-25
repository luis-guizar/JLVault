import 'dart:async';
import 'dart:convert';
import 'security_audit_service.dart';
import 'security_monitoring_service.dart';
import 'security_alert_service.dart';
import 'secure_logging_service.dart';
import 'enhanced_auth_service.dart';

/// Comprehensive security service that integrates audit, monitoring, and alerting
class ComprehensiveSecurityService {
  static bool _initialized = false;
  static Timer? _periodicSecurityCheck;
  static StreamSubscription? _securityEventSubscription;
  static StreamSubscription? _alertSubscription;

  // Security check intervals
  static const Duration _securityCheckInterval = Duration(minutes: 30);

  /// Initialize the comprehensive security service
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await SecureLoggingService.logSecurityEvent(
        'comprehensive_security_service_initializing',
      );

      // Initialize all security components
      await _initializeSecurityComponents();

      // Start integrated security monitoring
      await _startIntegratedMonitoring();

      // Set up event processing
      _setupEventProcessing();

      _initialized = true;

      await SecureLoggingService.logSecurityEvent(
        'comprehensive_security_service_initialized',
        data: {
          'timestamp': DateTime.now().toIso8601String(),
          'components': [
            'audit_service',
            'monitoring_service',
            'alert_service',
            'enhanced_auth_service',
          ],
        },
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to initialize comprehensive security service',
        error: e,
      );
      throw Exception('Comprehensive security initialization failed: $e');
    }
  }

  /// Dispose of the comprehensive security service
  static Future<void> dispose() async {
    if (!_initialized) return;

    try {
      _periodicSecurityCheck?.cancel();
      await _securityEventSubscription?.cancel();
      await _alertSubscription?.cancel();

      // Dispose individual services
      await SecurityAuditService.dispose();
      await SecurityMonitoringService.dispose();
      await SecurityAlertService.dispose();
      await EnhancedAuthService.dispose();

      _initialized = false;

      await SecureLoggingService.logSecurityEvent(
        'comprehensive_security_service_disposed',
      );
    } catch (e) {
      // Ignore disposal errors
    }
  }

  /// Perform comprehensive security assessment
  static Future<ComprehensiveSecurityReport> performSecurityAssessment({
    Duration? timeWindow,
    bool includeDetails = false,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      await SecureLoggingService.logSecurityEvent(
        'comprehensive_security_assessment_started',
      );

      final assessmentStartTime = DateTime.now();

      // Perform security audit
      final auditResult =
          await SecurityAuditService.performComprehensiveAudit();

      // Get monitoring dashboard data
      final dashboardData = await SecurityMonitoringService.getDashboardData();

      // Analyze authentication patterns
      final authAnalysis =
          await SecurityMonitoringService.analyzeAuthenticationPatterns(
            timeWindow: timeWindow,
          );

      // Detect access anomalies
      final accessAnomalies =
          await SecurityMonitoringService.detectAccessAnomalies(
            timeWindow: timeWindow,
          );

      // Get alert statistics
      final alertStats = SecurityAlertService.getAlertStatistics();

      // Get threat indicators
      final threatIndicators =
          SecurityMonitoringService.getCurrentThreatIndicators();

      // Calculate overall security posture
      final securityPosture = _calculateSecurityPosture(
        auditResult,
        dashboardData,
        authAnalysis,
        accessAnomalies,
        alertStats,
        threatIndicators,
      );

      final report = ComprehensiveSecurityReport(
        generatedAt: assessmentStartTime,
        completedAt: DateTime.now(),
        timeWindow: timeWindow ?? const Duration(hours: 24),
        auditResult: auditResult,
        dashboardData: dashboardData,
        authenticationAnalysis: authAnalysis,
        accessAnomalies: accessAnomalies,
        alertStatistics: alertStats,
        threatIndicators: threatIndicators,
        securityPosture: securityPosture,
        includeDetails: includeDetails,
      );

      await SecureLoggingService.logSecurityEvent(
        'comprehensive_security_assessment_completed',
        data: {
          'duration': report.completedAt
              .difference(report.generatedAt)
              .inMilliseconds,
          'overallScore': securityPosture.overallScore,
          'threatLevel': securityPosture.threatLevel.name,
          'issueCount': auditResult.issues.length,
          'alertCount': alertStats.activeAlerts,
          'anomalyCount': accessAnomalies.length,
        },
      );

      return report;
    } catch (e) {
      await SecureLoggingService.logError(
        'Comprehensive security assessment failed',
        error: e,
      );
      rethrow;
    }
  }

  /// Record a security event across all monitoring systems
  static Future<void> recordSecurityEvent({
    required String eventType,
    required String description,
    SecuritySeverity severity = SecuritySeverity.low,
    Map<String, dynamic>? metadata,
    String? userId,
    String? resourceId,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // Record in audit service
      await SecurityAuditService.recordAccessEvent(
        resourceType: metadata?['resourceType'] ?? 'unknown',
        action: eventType,
        resourceId: resourceId,
        userId: userId,
        metadata: metadata,
      );

      // Record in monitoring service
      await SecurityMonitoringService.recordSecurityEvent(
        eventType: _mapEventType(eventType),
        description: description,
        severity: severity,
        metadata: metadata,
        userId: userId,
        resourceId: resourceId,
      );

      await SecureLoggingService.logSecurityEvent(
        'security_event_recorded_comprehensive',
        data: {
          'eventType': eventType,
          'severity': severity.name,
          'hasMetadata': metadata != null,
          'hasUserId': userId != null,
          'hasResourceId': resourceId != null,
        },
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to record comprehensive security event',
        error: e,
      );
    }
  }

  /// Get current security status summary
  static Future<SecurityStatusSummary> getSecurityStatus() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // Get monitoring stats
      final monitoringStats = await SecurityAuditService.getMonitoringStats();

      // Get dashboard data
      final dashboardData = await SecurityMonitoringService.getDashboardData();

      // Get alert statistics
      final alertStats = SecurityAlertService.getAlertStatistics();

      // Get authentication stats
      final authStats = await EnhancedAuthService.getAuthStats();

      return SecurityStatusSummary(
        timestamp: DateTime.now(),
        overallThreatLevel: dashboardData.threatLevel,
        securityScore: dashboardData.securityScore.toDouble(),
        activeAlerts: alertStats.activeAlerts,
        criticalAlerts: alertStats.criticalAlerts,
        recentEvents: dashboardData.recentEvents,
        authFailures: authStats.failedAttempts,
        integrityViolations: monitoringStats.integrityViolations,
        monitoredResources: monitoringStats.monitoredFiles,
        lastAuditTime: monitoringStats.lastAuditTime,
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to get security status',
        error: e,
      );

      return SecurityStatusSummary(
        timestamp: DateTime.now(),
        overallThreatLevel: ThreatLevel.unknown,
        securityScore: 0,
        activeAlerts: 0,
        criticalAlerts: 0,
        recentEvents: 0,
        authFailures: 0,
        integrityViolations: 0,
        monitoredResources: 0,
        lastAuditTime: null,
      );
    }
  }

  /// Trigger immediate security response for critical events
  static Future<void> triggerSecurityResponse({
    required String eventType,
    required String description,
    required SecuritySeverity severity,
    Map<String, dynamic>? details,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      await SecureLoggingService.logSecurityEvent(
        'security_response_triggered',
        data: {
          'eventType': eventType,
          'severity': severity.name,
          'description': description,
        },
      );

      // Create immediate alert
      await SecurityAlertService.createAlert(
        type: _mapAlertType(eventType),
        severity: severity,
        title: 'Security Response: $eventType',
        description: description,
        details: details ?? {},
        recommendations: _getSecurityResponseRecommendations(
          eventType,
          severity,
        ),
      );

      // Record security event
      await recordSecurityEvent(
        eventType: eventType,
        description: description,
        severity: severity,
        metadata: details,
      );

      // If critical, perform immediate audit
      if (severity == SecuritySeverity.critical) {
        await SecurityAuditService.performComprehensiveAudit();
      }
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to trigger security response',
        error: e,
      );
    }
  }

  /// Export comprehensive security logs for analysis
  static Future<String?> exportSecurityLogs({
    Duration? timeWindow,
    bool includeDetails = false,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // Get security report
      final report = await performSecurityAssessment(
        timeWindow: timeWindow,
        includeDetails: includeDetails,
      );

      // Get recent logs
      final logs = await SecureLoggingService.getRecentLogs(limit: 1000);

      // Get alert summary
      final alertSummary = await SecurityAlertService.generateAlertSummary(
        timeWindow: timeWindow,
      );

      final exportData = {
        'exportedAt': DateTime.now().toIso8601String(),
        'timeWindow': timeWindow?.inHours ?? 24,
        'securityReport': report.toJson(),
        'alertSummary': alertSummary.toJson(),
        'recentLogs': logs.map((log) => log.toJson()).toList(),
        'exportMetadata': {
          'includeDetails': includeDetails,
          'logCount': logs.length,
          'reportGenerated': true,
        },
      };

      await SecureLoggingService.logSecurityEvent(
        'security_logs_exported',
        data: {
          'timeWindow': timeWindow?.inHours ?? 24,
          'includeDetails': includeDetails,
          'logCount': logs.length,
        },
      );

      return jsonEncode(exportData);
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to export security logs',
        error: e,
      );
      return null;
    }
  }

  // Private helper methods

  static Future<void> _initializeSecurityComponents() async {
    // Initialize in dependency order
    await SecureLoggingService.initialize();
    await EnhancedAuthService.initialize();
    await SecurityAuditService.initialize();
    await SecurityMonitoringService.initialize();
    await SecurityAlertService.initialize();
  }

  static Future<void> _startIntegratedMonitoring() async {
    // Start periodic comprehensive security checks
    _periodicSecurityCheck = Timer.periodic(_securityCheckInterval, (
      timer,
    ) async {
      try {
        await _performPeriodicSecurityCheck();
      } catch (e) {
        await SecureLoggingService.logError(
          'Periodic security check failed',
          error: e,
        );
      }
    });
  }

  static void _setupEventProcessing() {
    // Listen to security events from monitoring service
    _securityEventSubscription = SecurityMonitoringService.securityEventStream
        .listen(
          (event) async {
            await _processSecurityEvent(event);
          },
          onError: (error) async {
            await SecureLoggingService.logError(
              'Error processing security event',
              error: error,
            );
          },
        );

    // Listen to alerts from alert service
    _alertSubscription = SecurityAlertService.alertStream.listen(
      (alert) async {
        await _processSecurityAlert(alert);
      },
      onError: (error) async {
        await SecureLoggingService.logError(
          'Error processing security alert',
          error: error,
        );
      },
    );
  }

  static Future<void> _performPeriodicSecurityCheck() async {
    // Get current security status
    final status = await getSecurityStatus();

    // Check for concerning trends
    if (status.overallThreatLevel == ThreatLevel.high ||
        status.overallThreatLevel == ThreatLevel.critical) {
      await triggerSecurityResponse(
        eventType: 'elevated_threat_level',
        description:
            'Elevated threat level detected: ${status.overallThreatLevel.name}',
        severity: status.overallThreatLevel == ThreatLevel.critical
            ? SecuritySeverity.critical
            : SecuritySeverity.high,
        details: {
          'threatLevel': status.overallThreatLevel.name,
          'securityScore': status.securityScore,
          'activeAlerts': status.activeAlerts,
          'authFailures': status.authFailures,
        },
      );
    }

    // Check for excessive authentication failures
    if (status.authFailures >= 10) {
      await triggerSecurityResponse(
        eventType: 'excessive_auth_failures',
        description:
            'Excessive authentication failures detected: ${status.authFailures}',
        severity: SecuritySeverity.high,
        details: {
          'failureCount': status.authFailures,
          'checkTime': DateTime.now().toIso8601String(),
        },
      );
    }

    // Check for integrity violations
    if (status.integrityViolations > 0) {
      await triggerSecurityResponse(
        eventType: 'integrity_violations',
        description:
            'File integrity violations detected: ${status.integrityViolations}',
        severity: SecuritySeverity.critical,
        details: {
          'violationCount': status.integrityViolations,
          'checkTime': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  static Future<void> _processSecurityEvent(SecurityEvent event) async {
    // Process high-severity events immediately
    if (event.severity == SecuritySeverity.high ||
        event.severity == SecuritySeverity.critical) {
      await SecurityAlertService.processSecurityEvent(event);
    }

    // Log significant events
    await SecureLoggingService.logSecurityEvent(
      'security_event_processed',
      data: {
        'eventId': event.id,
        'eventType': event.type.name,
        'severity': event.severity.name,
        'processed': true,
      },
    );
  }

  static Future<void> _processSecurityAlert(SecurityAlert alert) async {
    // Log alert processing
    await SecureLoggingService.logSecurityEvent(
      'security_alert_processed',
      data: {
        'alertId': alert.id,
        'alertType': alert.type.name,
        'severity': alert.severity.name,
        'status': alert.status.name,
      },
    );

    // For critical alerts, trigger additional monitoring
    if (alert.severity == SecuritySeverity.critical) {
      await SecurityMonitoringService.recordSecurityEvent(
        eventType: SecurityEventType.threatDetected,
        description: 'Critical alert generated: ${alert.title}',
        severity: SecuritySeverity.critical,
        metadata: {'alertId': alert.id, 'alertType': alert.type.name},
      );
    }
  }

  static SecurityPosture _calculateSecurityPosture(
    SecurityAuditResult auditResult,
    SecurityDashboardData dashboardData,
    AuthenticationAnalysisResult authAnalysis,
    List<AccessAnomalyResult> accessAnomalies,
    AlertStatistics alertStats,
    List<ThreatIndicator> threatIndicators,
  ) {
    double overallScore = auditResult.overallScore.toDouble();

    // Adjust score based on various factors
    if (authAnalysis.riskScore > 0.7) {
      overallScore -= 20.0;
    }

    if (accessAnomalies.isNotEmpty) {
      overallScore -= accessAnomalies.length * 5.0;
    }

    if (alertStats.criticalAlerts > 0) {
      overallScore -= alertStats.criticalAlerts * 10.0;
    }

    if (threatIndicators.isNotEmpty) {
      final highThreatCount = threatIndicators
          .where(
            (t) =>
                t.severity == SecuritySeverity.high ||
                t.severity == SecuritySeverity.critical,
          )
          .length;
      overallScore -= highThreatCount * 15.0;
    }

    // Ensure score is within bounds
    overallScore = overallScore.clamp(0.0, 100.0);

    // Determine threat level based on score and indicators
    ThreatLevel threatLevel;
    if (overallScore >= 80 && alertStats.criticalAlerts == 0) {
      threatLevel = ThreatLevel.low;
    } else if (overallScore >= 60 && alertStats.criticalAlerts <= 1) {
      threatLevel = ThreatLevel.medium;
    } else if (overallScore >= 40 || alertStats.criticalAlerts <= 3) {
      threatLevel = ThreatLevel.high;
    } else {
      threatLevel = ThreatLevel.critical;
    }

    return SecurityPosture(
      overallScore: overallScore,
      threatLevel: threatLevel,
      riskFactors: _identifyRiskFactors(
        auditResult,
        authAnalysis,
        accessAnomalies,
        alertStats,
        threatIndicators,
      ),
      recommendations: _generatePostureRecommendations(
        overallScore,
        threatLevel,
        auditResult,
        alertStats,
      ),
    );
  }

  static List<String> _identifyRiskFactors(
    SecurityAuditResult auditResult,
    AuthenticationAnalysisResult authAnalysis,
    List<AccessAnomalyResult> accessAnomalies,
    AlertStatistics alertStats,
    List<ThreatIndicator> threatIndicators,
  ) {
    final riskFactors = <String>[];

    if (auditResult.issues.isNotEmpty) {
      riskFactors.add(
        '${auditResult.issues.length} security issues identified',
      );
    }

    if (authAnalysis.riskScore > 0.5) {
      riskFactors.add(
        'High authentication risk score: ${(authAnalysis.riskScore * 100).toInt()}%',
      );
    }

    if (accessAnomalies.isNotEmpty) {
      riskFactors.add('${accessAnomalies.length} access anomalies detected');
    }

    if (alertStats.criticalAlerts > 0) {
      riskFactors.add('${alertStats.criticalAlerts} critical alerts active');
    }

    if (threatIndicators.isNotEmpty) {
      riskFactors.add('${threatIndicators.length} threat indicators detected');
    }

    return riskFactors;
  }

  static List<String> _generatePostureRecommendations(
    double overallScore,
    ThreatLevel threatLevel,
    SecurityAuditResult auditResult,
    AlertStatistics alertStats,
  ) {
    final recommendations = <String>[];

    if (overallScore < 50) {
      recommendations.add('Immediate security review and remediation required');
    }

    if (threatLevel == ThreatLevel.critical) {
      recommendations.add('Activate incident response procedures');
    }

    if (auditResult.issues.isNotEmpty) {
      recommendations.add(
        'Address ${auditResult.issues.length} identified security issues',
      );
    }

    if (alertStats.criticalAlerts > 0) {
      recommendations.add(
        'Resolve ${alertStats.criticalAlerts} critical security alerts',
      );
    }

    recommendations.addAll(auditResult.recommendations);

    return recommendations.take(10).toList(); // Limit to top 10 recommendations
  }

  static SecurityEventType _mapEventType(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'authentication':
      case 'auth_failure':
      case 'auth_success':
        return SecurityEventType.authentication;
      case 'data_access':
      case 'file_access':
        return SecurityEventType.dataAccess;
      case 'system_access':
      case 'admin_access':
        return SecurityEventType.systemAccess;
      case 'configuration_change':
      case 'config_change':
        return SecurityEventType.configurationChange;
      case 'integrity_violation':
      case 'file_tampering':
        return SecurityEventType.auditEvent;
      default:
        return SecurityEventType.systemAccess;
    }
  }

  static SecurityAlertType _mapAlertType(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'authentication':
      case 'auth_failure':
      case 'excessive_auth_failures':
        return SecurityAlertType.authenticationAnomaly;
      case 'access_anomaly':
      case 'unusual_access':
        return SecurityAlertType.accessAnomaly;
      case 'integrity_violation':
      case 'integrity_violations':
      case 'file_tampering':
        return SecurityAlertType.integrityViolation;
      case 'elevated_threat_level':
      case 'critical_event':
        return SecurityAlertType.criticalIssue;
      default:
        return SecurityAlertType.systemAlert;
    }
  }

  static List<String> _getSecurityResponseRecommendations(
    String eventType,
    SecuritySeverity severity,
  ) {
    final recommendations = <String>[];

    switch (eventType.toLowerCase()) {
      case 'excessive_auth_failures':
        recommendations.addAll([
          'Review authentication logs for patterns',
          'Consider implementing account lockout policies',
          'Check for brute force attack indicators',
        ]);
        break;
      case 'integrity_violations':
        recommendations.addAll([
          'Immediately investigate file tampering',
          'Restore files from known good backups',
          'Scan for malware or unauthorized modifications',
        ]);
        break;
      case 'elevated_threat_level':
        recommendations.addAll([
          'Review all active security alerts',
          'Perform comprehensive security audit',
          'Monitor system activity closely',
        ]);
        break;
      default:
        recommendations.addAll([
          'Investigate the security event thoroughly',
          'Review system logs for related activity',
          'Consider additional security measures',
        ]);
    }

    if (severity == SecuritySeverity.critical) {
      recommendations.insert(
        0,
        'Activate incident response procedures immediately',
      );
    }

    return recommendations;
  }
}

/// Comprehensive security report
class ComprehensiveSecurityReport {
  final DateTime generatedAt;
  final DateTime completedAt;
  final Duration timeWindow;
  final SecurityAuditResult auditResult;
  final SecurityDashboardData dashboardData;
  final AuthenticationAnalysisResult authenticationAnalysis;
  final List<AccessAnomalyResult> accessAnomalies;
  final AlertStatistics alertStatistics;
  final List<ThreatIndicator> threatIndicators;
  final SecurityPosture securityPosture;
  final bool includeDetails;

  ComprehensiveSecurityReport({
    required this.generatedAt,
    required this.completedAt,
    required this.timeWindow,
    required this.auditResult,
    required this.dashboardData,
    required this.authenticationAnalysis,
    required this.accessAnomalies,
    required this.alertStatistics,
    required this.threatIndicators,
    required this.securityPosture,
    required this.includeDetails,
  });

  Map<String, dynamic> toJson() => {
    'generatedAt': generatedAt.toIso8601String(),
    'completedAt': completedAt.toIso8601String(),
    'timeWindow': timeWindow.inHours,
    'auditResult': auditResult.toJson(),
    'dashboardData': dashboardData.toJson(),
    'authenticationAnalysis': authenticationAnalysis.toJson(),
    'accessAnomalies': accessAnomalies.map((a) => a.toJson()).toList(),
    'alertStatistics': alertStatistics.toJson(),
    'threatIndicators': threatIndicators.map((t) => t.toJson()).toList(),
    'securityPosture': securityPosture.toJson(),
    'includeDetails': includeDetails,
  };
}

/// Security posture assessment
class SecurityPosture {
  final double overallScore;
  final ThreatLevel threatLevel;
  final List<String> riskFactors;
  final List<String> recommendations;

  SecurityPosture({
    required this.overallScore,
    required this.threatLevel,
    required this.riskFactors,
    required this.recommendations,
  });

  Map<String, dynamic> toJson() => {
    'overallScore': overallScore,
    'threatLevel': threatLevel.name,
    'riskFactors': riskFactors,
    'recommendations': recommendations,
  };
}

/// Security status summary
class SecurityStatusSummary {
  final DateTime timestamp;
  final ThreatLevel overallThreatLevel;
  final double securityScore;
  final int activeAlerts;
  final int criticalAlerts;
  final int recentEvents;
  final int authFailures;
  final int integrityViolations;
  final int monitoredResources;
  final DateTime? lastAuditTime;

  SecurityStatusSummary({
    required this.timestamp,
    required this.overallThreatLevel,
    required this.securityScore,
    required this.activeAlerts,
    required this.criticalAlerts,
    required this.recentEvents,
    required this.authFailures,
    required this.integrityViolations,
    required this.monitoredResources,
    this.lastAuditTime,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'overallThreatLevel': overallThreatLevel.name,
    'securityScore': securityScore,
    'activeAlerts': activeAlerts,
    'criticalAlerts': criticalAlerts,
    'recentEvents': recentEvents,
    'authFailures': authFailures,
    'integrityViolations': integrityViolations,
    'monitoredResources': monitoredResources,
    'lastAuditTime': lastAuditTime?.toIso8601String(),
  };
}
