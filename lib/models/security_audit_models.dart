import 'package:simple_vault/services/security_audit_service.dart';

/// Security event types for monitoring and auditing
enum SecurityEventType {
  authentication,
  dataAccess,
  systemAccess,
  configurationChange,
  threatDetected,
  integrityViolation,
}

/// Threat types for threat indicators
enum ThreatType {
  rapidAccess,
  authenticationAnomaly,
  behavioralAnomaly,
  unusualTiming,
  bruteForceAttempt,
  dataExfiltration,
  unauthorizedAccess,
  configurationTampering,
}

/// Threat levels
enum ThreatLevel { low, medium, high, critical, unknown }

/// Access anomaly types
enum AccessAnomalyType { rapidAccess, unusualTiming, excessiveResourceAccess }

/// Alert trends
enum AlertTrend { increasing, decreasing, stable }

/// Threat indicator
class ThreatIndicator {
  final String id;
  final ThreatType type;
  final SecuritySeverity severity;
  final String description;
  final double confidence;
  final DateTime detectedAt;
  final Map<String, dynamic> metadata;

  ThreatIndicator({
    required this.id,
    required this.type,
    required this.severity,
    required this.description,
    required this.confidence,
    required this.detectedAt,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'severity': severity.name,
    'description': description,
    'confidence': confidence,
    'detectedAt': detectedAt.toIso8601String(),
    'metadata': metadata,
  };

  factory ThreatIndicator.fromJson(Map<String, dynamic> json) =>
      ThreatIndicator(
        id: json['id'],
        type: ThreatType.values.firstWhere((t) => t.name == json['type']),
        severity: SecuritySeverity.values.firstWhere(
          (s) => s.name == json['severity'],
        ),
        description: json['description'],
        confidence: json['confidence'].toDouble(),
        detectedAt: DateTime.parse(json['detectedAt']),
        metadata: Map<String, dynamic>.from(json['metadata']),
      );
}

/// Access anomaly result
class AccessAnomalyResult {
  final AccessAnomalyType type;
  final SecuritySeverity severity;
  final String description;
  final int eventCount;
  final Duration timeWindow;
  final double confidence;
  final DateTime detectedAt;

  AccessAnomalyResult({
    required this.type,
    required this.severity,
    required this.description,
    required this.eventCount,
    required this.timeWindow,
    required this.confidence,
    required this.detectedAt,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'severity': severity.name,
    'description': description,
    'eventCount': eventCount,
    'timeWindow': timeWindow.inMinutes,
    'confidence': confidence,
    'detectedAt': detectedAt.toIso8601String(),
  };
}

/// Authentication analysis result
class AuthenticationAnalysisResult {
  final Duration timeWindow;
  final int totalAttempts;
  final int successfulAttempts;
  final int failedAttempts;
  final int uniqueUsers;
  final List<String> suspiciousPatterns;
  double riskScore;

  AuthenticationAnalysisResult({
    required this.timeWindow,
    required this.totalAttempts,
    required this.successfulAttempts,
    required this.failedAttempts,
    required this.uniqueUsers,
    required this.suspiciousPatterns,
    required this.riskScore,
  });

  Map<String, dynamic> toJson() => {
    'timeWindow': timeWindow.inHours,
    'totalAttempts': totalAttempts,
    'successfulAttempts': successfulAttempts,
    'failedAttempts': failedAttempts,
    'uniqueUsers': uniqueUsers,
    'suspiciousPatterns': suspiciousPatterns,
    'riskScore': riskScore,
  };
}

/// Security dashboard data
class SecurityDashboardData {
  final DateTime timestamp;
  final ThreatLevel threatLevel;
  final int activeAlerts;
  final int recentEvents;
  final int authFailures;
  final int anomaliesDetected;
  final int monitoredResources;
  final int integrityViolations;
  final DateTime? lastAuditTime;
  final double securityScore;
  final List<ThreatIndicator> threatIndicators;
  final List<SecurityAlert> recentAlerts;

  SecurityDashboardData({
    required this.timestamp,
    required this.threatLevel,
    required this.activeAlerts,
    required this.recentEvents,
    required this.authFailures,
    required this.anomaliesDetected,
    required this.monitoredResources,
    required this.integrityViolations,
    this.lastAuditTime,
    required this.securityScore,
    required this.threatIndicators,
    required this.recentAlerts,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'threatLevel': threatLevel.name,
    'activeAlerts': activeAlerts,
    'recentEvents': recentEvents,
    'authFailures': authFailures,
    'anomaliesDetected': anomaliesDetected,
    'monitoredResources': monitoredResources,
    'integrityViolations': integrityViolations,
    'lastAuditTime': lastAuditTime?.toIso8601String(),
    'securityScore': securityScore,
    'threatIndicators': threatIndicators.map((t) => t.toJson()).toList(),
    'recentAlerts': recentAlerts.map((a) => a.toJson()).toList(),
  };
}

/// Security metric for monitoring
class SecurityMetric {
  final DateTime timestamp;
  final SecurityEventType eventType;
  final SecuritySeverity severity;
  final String? userId;
  final String? resourceId;

  SecurityMetric({
    required this.timestamp,
    required this.eventType,
    required this.severity,
    this.userId,
    this.resourceId,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'eventType': eventType.name,
    'severity': severity.name,
    'userId': userId,
    'resourceId': resourceId,
  };
}

/// Security report for comprehensive analysis
class SecurityReportComprehensive {
  final DateTime generatedAt;
  final Duration timeWindow;
  final SecurityAuditResult auditResult;
  final AuthenticationAnalysisResult authenticationAnalysis;
  final List<AccessAnomalyResult> accessAnomalies;
  final SecurityDashboardData dashboardData;
  final List<ThreatIndicator> threatIndicators;
  final bool includeDetails;

  SecurityReportComprehensive({
    required this.generatedAt,
    required this.timeWindow,
    required this.auditResult,
    required this.authenticationAnalysis,
    required this.accessAnomalies,
    required this.dashboardData,
    required this.threatIndicators,
    required this.includeDetails,
  });

  Map<String, dynamic> toJson() => {
    'generatedAt': generatedAt.toIso8601String(),
    'timeWindow': timeWindow.inDays,
    'auditResult': auditResult.toJson(),
    'authenticationAnalysis': authenticationAnalysis.toJson(),
    'accessAnomalies': accessAnomalies.map((a) => a.toJson()).toList(),
    'dashboardData': dashboardData.toJson(),
    'threatIndicators': threatIndicators.map((t) => t.toJson()).toList(),
    'includeDetails': includeDetails,
  };
}

/// Alert rule for automated alert generation
class AlertRule {
  final String id;
  final String name;
  final String description;
  final bool enabled;
  final Map<String, dynamic> conditions;
  final SecuritySeverity severity;
  final SecurityAlertType alertType;

  AlertRule({
    required this.id,
    required this.name,
    required this.description,
    required this.enabled,
    required this.conditions,
    required this.severity,
    required this.alertType,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'enabled': enabled,
    'conditions': conditions,
    'severity': severity.name,
    'alertType': alertType.name,
  };

  factory AlertRule.fromJson(Map<String, dynamic> json) => AlertRule(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    enabled: json['enabled'],
    conditions: Map<String, dynamic>.from(json['conditions']),
    severity: SecuritySeverity.values.firstWhere(
      (s) => s.name == json['severity'],
    ),
    alertType: SecurityAlertType.values.firstWhere(
      (t) => t.name == json['alertType'],
    ),
  );
}

/// Alert statistics
class AlertStatistics {
  final int totalAlerts;
  final int activeAlerts;
  final int resolvedAlerts;
  final int dismissedAlerts;
  final int recentAlerts;
  final int weeklyAlerts;
  final int criticalAlerts;
  final int highSeverityAlerts;
  final int mediumSeverityAlerts;
  final int lowSeverityAlerts;

  AlertStatistics({
    required this.totalAlerts,
    required this.activeAlerts,
    required this.resolvedAlerts,
    required this.dismissedAlerts,
    required this.recentAlerts,
    required this.weeklyAlerts,
    required this.criticalAlerts,
    required this.highSeverityAlerts,
    required this.mediumSeverityAlerts,
    required this.lowSeverityAlerts,
  });

  Map<String, dynamic> toJson() => {
    'totalAlerts': totalAlerts,
    'activeAlerts': activeAlerts,
    'resolvedAlerts': resolvedAlerts,
    'dismissedAlerts': dismissedAlerts,
    'recentAlerts': recentAlerts,
    'weeklyAlerts': weeklyAlerts,
    'criticalAlerts': criticalAlerts,
    'highSeverityAlerts': highSeverityAlerts,
    'mediumSeverityAlerts': mediumSeverityAlerts,
    'lowSeverityAlerts': lowSeverityAlerts,
  };
}

/// Alert summary report
class AlertSummaryReport {
  final DateTime generatedAt;
  final Duration timeWindow;
  final int totalAlerts;
  final Map<SecurityAlertType, List<SecurityAlert>> alertsByType;
  final Map<SecuritySeverity, List<SecurityAlert>> alertsBySeverity;
  final AlertTrends trends;
  final List<AlertTypeCount> topAlertTypes;
  final double resolutionRate;
  final Duration? averageResolutionTime;

  AlertSummaryReport({
    required this.generatedAt,
    required this.timeWindow,
    required this.totalAlerts,
    required this.alertsByType,
    required this.alertsBySeverity,
    required this.trends,
    required this.topAlertTypes,
    required this.resolutionRate,
    required this.averageResolutionTime,
  });

  Map<String, dynamic> toJson() => {
    'generatedAt': generatedAt.toIso8601String(),
    'timeWindow': timeWindow.inDays,
    'totalAlerts': totalAlerts,
    'alertsByType': alertsByType.map((k, v) => MapEntry(k.name, v.length)),
    'alertsBySeverity': alertsBySeverity.map(
      (k, v) => MapEntry(k.name, v.length),
    ),
    'trends': trends.toJson(),
    'topAlertTypes': topAlertTypes.map((t) => t.toJson()).toList(),
    'resolutionRate': resolutionRate,
    'averageResolutionTime': averageResolutionTime?.inMinutes,
  };
}

/// Alert trends information
class AlertTrends {
  final AlertTrend trend;
  final int changePercentage;
  final int recentCount;
  final int previousCount;

  AlertTrends({
    required this.trend,
    required this.changePercentage,
    required this.recentCount,
    required this.previousCount,
  });

  Map<String, dynamic> toJson() => {
    'trend': trend.name,
    'changePercentage': changePercentage,
    'recentCount': recentCount,
    'previousCount': previousCount,
  };
}

/// Alert type count for statistics
class AlertTypeCount {
  final SecurityAlertType type;
  final int count;

  AlertTypeCount({required this.type, required this.count});

  Map<String, dynamic> toJson() => {'type': type.name, 'count': count};
}

/// Exception classes
class SecurityMonitoringException implements Exception {
  final String message;
  SecurityMonitoringException(this.message);
  @override
  String toString() => 'SecurityMonitoringException: $message';
}

class SecurityAlertException implements Exception {
  final String message;
  SecurityAlertException(this.message);
  @override
  String toString() => 'SecurityAlertException: $message';
}

/// Security monitoring status
enum SecurityMonitoringStatus { active, paused, inactive, error }

/// Alert severity for monitoring
enum AlertSeverity { critical, high, medium, low }

/// Alert type for monitoring
enum AlertType { breach, weakPassword, duplicate, suspicious, system }

/// Security audit report
class SecurityAuditReport {
  final String vaultId;
  final DateTime generatedAt;
  final double overallScore;
  final int totalPasswords;
  final int securePasswords;
  final double passwordStrengthScore;
  final double uniquenessScore;
  final double freshnessScore;
  final double twoFactorScore;
  final List<PasswordInfo> weakPasswords;
  final List<PasswordInfo> compromisedPasswords;
  final List<PasswordInfo> duplicatePasswords;
  final List<PasswordInfo> oldPasswords;

  SecurityAuditReport({
    required this.vaultId,
    required this.generatedAt,
    required this.overallScore,
    required this.totalPasswords,
    required this.securePasswords,
    required this.passwordStrengthScore,
    required this.uniquenessScore,
    required this.freshnessScore,
    required this.twoFactorScore,
    required this.weakPasswords,
    required this.compromisedPasswords,
    required this.duplicatePasswords,
    required this.oldPasswords,
  });

  Map<String, dynamic> toJson() => {
    'vaultId': vaultId,
    'generatedAt': generatedAt.toIso8601String(),
    'overallScore': overallScore,
    'totalPasswords': totalPasswords,
    'securePasswords': securePasswords,
    'passwordStrengthScore': passwordStrengthScore,
    'uniquenessScore': uniquenessScore,
    'freshnessScore': freshnessScore,
    'twoFactorScore': twoFactorScore,
    'weakPasswords': weakPasswords.map((p) => p.toJson()).toList(),
    'compromisedPasswords': compromisedPasswords
        .map((p) => p.toJson())
        .toList(),
    'duplicatePasswords': duplicatePasswords.map((p) => p.toJson()).toList(),
    'oldPasswords': oldPasswords.map((p) => p.toJson()).toList(),
  };
}

/// Password information for audit reports
class PasswordInfo {
  final String accountId;
  final String accountName;
  final String username;
  final DateTime? lastModified;
  final double? strengthScore;
  final bool isCompromised;
  final bool hasTwoFactor;

  PasswordInfo({
    required this.accountId,
    required this.accountName,
    required this.username,
    this.lastModified,
    this.strengthScore,
    this.isCompromised = false,
    this.hasTwoFactor = false,
  });

  Map<String, dynamic> toJson() => {
    'accountId': accountId,
    'accountName': accountName,
    'username': username,
    'lastModified': lastModified?.toIso8601String(),
    'strengthScore': strengthScore,
    'isCompromised': isCompromised,
    'hasTwoFactor': hasTwoFactor,
  };
}

/// Security alert for monitoring
class SecurityAlert {
  final String id;
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String description;
  final DateTime timestamp;
  final bool isActive;
  final List<String> affectedAccounts;

  SecurityAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.timestamp,
    this.isActive = true,
    this.affectedAccounts = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'severity': severity.name,
    'title': title,
    'description': description,
    'timestamp': timestamp.toIso8601String(),
    'isActive': isActive,
    'affectedAccounts': affectedAccounts,
  };
}

// Import the existing classes from security services
// These are defined in the security audit service:
// - SecuritySeverity
// - SecurityAlertType  
// - AlertStatus
// - SecurityAuditResult
// - SecurityIssue
// - SecurityWarning
// - AuthenticationEvent
// - AccessPattern
// - FileIntegrityInfo
// - FileIntegrityResult
// - SecurityMonitoringStats
// - AuthenticationAuditResult
// - FileIntegrityAuditResult
// - AccessPatternAuditResult
// - ConfigurationAuditResult
// - SystemAuditResult
// - SecurityAuditException