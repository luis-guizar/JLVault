import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'security_audit_service.dart';
import 'security_monitoring_service.dart';
import 'secure_logging_service.dart';

/// Service for managing security alerts and notifications
class SecurityAlertService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
  );

  static Timer? _alertProcessingTimer;
  static bool _initialized = false;
  static final List<SecurityAlert> _activeAlerts = [];
  static final List<AlertRule> _alertRules = [];
  static final StreamController<SecurityAlert> _alertController =
      StreamController.broadcast();

  // Alert processing configuration
  static const Duration _alertProcessingInterval = Duration(minutes: 1);
  static const int _maxActiveAlerts = 100;
  static const Duration _alertRetentionPeriod = Duration(days: 30);

  /// Initialize the security alert service
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await SecureLoggingService.logSecurityEvent(
        'security_alert_service_initializing',
      );

      // Load existing alerts and rules
      await _loadAlertsAndRules();

      // Initialize default alert rules
      await _initializeDefaultAlertRules();

      // Start alert processing
      await _startAlertProcessing();

      // Subscribe to security events
      _subscribeToSecurityEvents();

      _initialized = true;

      await SecureLoggingService.logSecurityEvent(
        'security_alert_service_initialized',
        data: {
          'activeAlerts': _activeAlerts.length,
          'alertRules': _alertRules.length,
        },
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to initialize security alert service',
        error: e,
      );
      throw SecurityAlertException('Security alert initialization failed: $e');
    }
  }

  /// Dispose of the security alert service
  static Future<void> dispose() async {
    if (!_initialized) return;

    try {
      _alertProcessingTimer?.cancel();
      await _alertController.close();

      // Save current state
      await _saveAlertsAndRules();

      _activeAlerts.clear();
      _alertRules.clear();
      _initialized = false;

      await SecureLoggingService.logSecurityEvent(
        'security_alert_service_disposed',
      );
    } catch (e) {
      // Ignore disposal errors
    }
  }

  /// Stream of security alerts
  static Stream<SecurityAlert> get alertStream => _alertController.stream;

  /// Creates a new security alert
  static Future<SecurityAlert> createAlert({
    required SecurityAlertType type,
    required SecuritySeverity severity,
    required String title,
    required String description,
    Map<String, dynamic>? details,
    List<String>? recommendations,
    Duration? autoResolveAfter,
  }) async {
    try {
      final alert = SecurityAlert(
        id: _generateAlertId(),
        type: type,
        severity: severity,
        title: title,
        description: description,
        details: details ?? {},
        recommendations: recommendations ?? [],
        createdAt: DateTime.now(),
        status: AlertStatus.active,
        autoResolveAfter: autoResolveAfter,
      );

      _activeAlerts.add(alert);

      // Maintain alert limit
      if (_activeAlerts.length > _maxActiveAlerts) {
        _activeAlerts.removeRange(0, _activeAlerts.length - _maxActiveAlerts);
      }

      // Add to stream
      _alertController.add(alert);

      await SecureLoggingService.logSecurityEvent(
        'security_alert_created',
        data: {
          'alertId': alert.id,
          'type': type.name,
          'severity': severity.name,
          'title': title,
        },
      );

      // Save state
      await _saveAlertsAndRules();

      return alert;
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to create security alert',
        error: e,
      );
      rethrow;
    }
  }

  /// Updates an existing alert
  static Future<void> updateAlert(
    String alertId, {
    AlertStatus? status,
    String? resolution,
    Map<String, dynamic>? additionalDetails,
  }) async {
    try {
      final alertIndex = _activeAlerts.indexWhere((a) => a.id == alertId);
      if (alertIndex == -1) {
        throw SecurityAlertException('Alert not found: $alertId');
      }

      final alert = _activeAlerts[alertIndex];
      final updatedAlert = SecurityAlert(
        id: alert.id,
        type: alert.type,
        severity: alert.severity,
        title: alert.title,
        description: alert.description,
        details: {...alert.details, ...?additionalDetails},
        recommendations: alert.recommendations,
        createdAt: alert.createdAt,
        status: status ?? alert.status,
        resolution: resolution ?? alert.resolution,
        resolvedAt: status == AlertStatus.resolved
            ? DateTime.now()
            : alert.resolvedAt,
        autoResolveAfter: alert.autoResolveAfter,
      );

      _activeAlerts[alertIndex] = updatedAlert;

      await SecureLoggingService.logSecurityEvent(
        'security_alert_updated',
        data: {
          'alertId': alertId,
          'newStatus': updatedAlert.status.name,
          'hasResolution': resolution != null,
        },
      );

      // Add to stream
      _alertController.add(updatedAlert);

      // Save state
      await _saveAlertsAndRules();
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to update security alert',
        data: {'alertId': alertId},
        error: e,
      );
      rethrow;
    }
  }

  /// Resolves a security alert
  static Future<void> resolveAlert(String alertId, String resolution) async {
    await updateAlert(
      alertId,
      status: AlertStatus.resolved,
      resolution: resolution,
    );
  }

  /// Dismisses a security alert
  static Future<void> dismissAlert(String alertId) async {
    await updateAlert(alertId, status: AlertStatus.dismissed);
  }

  /// Gets all active alerts
  static List<SecurityAlert> getActiveAlerts() {
    return _activeAlerts
        .where((alert) => alert.status == AlertStatus.active)
        .toList();
  }

  /// Gets alerts by severity
  static List<SecurityAlert> getAlertsBySeverity(SecuritySeverity severity) {
    return _activeAlerts.where((alert) => alert.severity == severity).toList();
  }

  /// Gets alerts by type
  static List<SecurityAlert> getAlertsByType(SecurityAlertType type) {
    return _activeAlerts.where((alert) => alert.type == type).toList();
  }

  /// Gets alert statistics
  static AlertStatistics getAlertStatistics() {
    final now = DateTime.now();
    final last24Hours = now.subtract(const Duration(hours: 24));
    final lastWeek = now.subtract(const Duration(days: 7));

    final recentAlerts = _activeAlerts
        .where((alert) => alert.createdAt.isAfter(last24Hours))
        .toList();

    final weeklyAlerts = _activeAlerts
        .where((alert) => alert.createdAt.isAfter(lastWeek))
        .toList();

    return AlertStatistics(
      totalAlerts: _activeAlerts.length,
      activeAlerts: getActiveAlerts().length,
      resolvedAlerts: _activeAlerts
          .where((alert) => alert.status == AlertStatus.resolved)
          .length,
      dismissedAlerts: _activeAlerts
          .where((alert) => alert.status == AlertStatus.dismissed)
          .length,
      recentAlerts: recentAlerts.length,
      weeklyAlerts: weeklyAlerts.length,
      criticalAlerts: getAlertsBySeverity(SecuritySeverity.critical).length,
      highSeverityAlerts: getAlertsBySeverity(SecuritySeverity.high).length,
      mediumSeverityAlerts: getAlertsBySeverity(SecuritySeverity.medium).length,
      lowSeverityAlerts: getAlertsBySeverity(SecuritySeverity.low).length,
    );
  }

  /// Adds a custom alert rule
  static Future<void> addAlertRule(AlertRule rule) async {
    try {
      _alertRules.add(rule);

      await SecureLoggingService.logSecurityEvent(
        'alert_rule_added',
        data: {'ruleId': rule.id, 'name': rule.name, 'enabled': rule.enabled},
      );

      await _saveAlertsAndRules();
    } catch (e) {
      await SecureLoggingService.logError('Failed to add alert rule', error: e);
      rethrow;
    }
  }

  /// Removes an alert rule
  static Future<void> removeAlertRule(String ruleId) async {
    try {
      _alertRules.removeWhere((rule) => rule.id == ruleId);

      await SecureLoggingService.logSecurityEvent(
        'alert_rule_removed',
        data: {'ruleId': ruleId},
      );

      await _saveAlertsAndRules();
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to remove alert rule',
        data: {'ruleId': ruleId},
        error: e,
      );
      rethrow;
    }
  }

  /// Gets all alert rules
  static List<AlertRule> getAlertRules() {
    return List.unmodifiable(_alertRules);
  }

  /// Processes security events against alert rules
  static Future<void> processSecurityEvent(SecurityEvent event) async {
    try {
      for (final rule in _alertRules.where((r) => r.enabled)) {
        if (await _evaluateAlertRule(rule, event)) {
          await _triggerAlert(rule, event);
        }
      }
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to process security event for alerts',
        error: e,
      );
    }
  }

  /// Generates an alert summary report
  static Future<AlertSummaryReport> generateAlertSummary({
    Duration? timeWindow,
  }) async {
    try {
      final window = timeWindow ?? const Duration(days: 7);
      final cutoffTime = DateTime.now().subtract(window);

      final relevantAlerts = _activeAlerts
          .where((alert) => alert.createdAt.isAfter(cutoffTime))
          .toList();

      // Group alerts by type
      final alertsByType = <SecurityAlertType, List<SecurityAlert>>{};
      for (final alert in relevantAlerts) {
        alertsByType[alert.type] = (alertsByType[alert.type] ?? [])..add(alert);
      }

      // Group alerts by severity
      final alertsBySeverity = <SecuritySeverity, List<SecurityAlert>>{};
      for (final alert in relevantAlerts) {
        alertsBySeverity[alert.severity] =
            (alertsBySeverity[alert.severity] ?? [])..add(alert);
      }

      // Calculate trends
      final trends = _calculateAlertTrends(relevantAlerts, window);

      return AlertSummaryReport(
        generatedAt: DateTime.now(),
        timeWindow: window,
        totalAlerts: relevantAlerts.length,
        alertsByType: alertsByType,
        alertsBySeverity: alertsBySeverity,
        trends: trends,
        topAlertTypes: _getTopAlertTypes(alertsByType),
        resolutionRate: _calculateResolutionRate(relevantAlerts),
        averageResolutionTime: _calculateAverageResolutionTime(relevantAlerts),
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to generate alert summary',
        error: e,
      );
      rethrow;
    }
  }

  // Private helper methods

  static Future<void> _startAlertProcessing() async {
    _alertProcessingTimer = Timer.periodic(_alertProcessingInterval, (
      timer,
    ) async {
      try {
        await _processAlerts();
      } catch (e) {
        await SecureLoggingService.logError(
          'Alert processing failed',
          error: e,
        );
      }
    });
  }

  static void _subscribeToSecurityEvents() {
    SecurityMonitoringService.securityEventStream.listen(
      (event) async {
        await processSecurityEvent(event);
      },
      onError: (error) async {
        await SecureLoggingService.logError(
          'Error processing security event for alerts',
          error: error,
        );
      },
    );
  }

  static Future<void> _processAlerts() async {
    final now = DateTime.now();

    // Auto-resolve alerts
    for (final alert in _activeAlerts.where(
      (a) => a.status == AlertStatus.active,
    )) {
      if (alert.autoResolveAfter != null) {
        final autoResolveTime = alert.createdAt.add(alert.autoResolveAfter!);
        if (now.isAfter(autoResolveTime)) {
          await updateAlert(
            alert.id,
            status: AlertStatus.resolved,
            resolution:
                'Auto-resolved after ${alert.autoResolveAfter!.inMinutes} minutes',
          );
        }
      }
    }

    // Clean up old alerts
    final cutoffTime = now.subtract(_alertRetentionPeriod);
    final removedCount = _activeAlerts.length;
    _activeAlerts.removeWhere((alert) => alert.createdAt.isBefore(cutoffTime));

    if (_activeAlerts.length < removedCount) {
      await SecureLoggingService.logSecurityEvent(
        'old_alerts_cleaned_up',
        data: {'removedCount': removedCount - _activeAlerts.length},
      );
    }
  }

  static Future<void> _initializeDefaultAlertRules() async {
    // Only add default rules if none exist
    if (_alertRules.isNotEmpty) return;

    final defaultRules = [
      AlertRule(
        id: 'auth_failure_rule',
        name: 'Authentication Failure Alert',
        description: 'Triggers when multiple authentication failures occur',
        enabled: true,
        conditions: {
          'eventType': 'authentication',
          'success': false,
          'threshold': 3,
          'timeWindow': 300, // 5 minutes
        },
        severity: SecuritySeverity.high,
        alertType: SecurityAlertType.authenticationAnomaly,
      ),
      AlertRule(
        id: 'rapid_access_rule',
        name: 'Rapid Access Alert',
        description: 'Triggers when rapid access patterns are detected',
        enabled: true,
        conditions: {
          'eventType': 'dataAccess',
          'threshold': 20,
          'timeWindow': 60, // 1 minute
        },
        severity: SecuritySeverity.medium,
        alertType: SecurityAlertType.accessAnomaly,
      ),
      AlertRule(
        id: 'integrity_violation_rule',
        name: 'File Integrity Violation Alert',
        description: 'Triggers when file integrity violations are detected',
        enabled: true,
        conditions: {
          'eventType': 'integrityViolation',
          'threshold': 1,
          'timeWindow': 0, // Immediate
        },
        severity: SecuritySeverity.critical,
        alertType: SecurityAlertType.integrityViolation,
      ),
      AlertRule(
        id: 'system_access_rule',
        name: 'Unauthorized System Access Alert',
        description: 'Triggers on unauthorized system access attempts',
        enabled: true,
        conditions: {
          'eventType': 'systemAccess',
          'severity': 'high',
          'threshold': 1,
          'timeWindow': 0, // Immediate
        },
        severity: SecuritySeverity.high,
        alertType: SecurityAlertType.systemAlert,
      ),
    ];

    for (final rule in defaultRules) {
      _alertRules.add(rule);
    }

    await SecureLoggingService.logSecurityEvent(
      'default_alert_rules_initialized',
      data: {'ruleCount': defaultRules.length},
    );
  }

  static Future<bool> _evaluateAlertRule(
    AlertRule rule,
    SecurityEvent event,
  ) async {
    try {
      final conditions = rule.conditions;

      // Check event type
      if (conditions.containsKey('eventType')) {
        if (event.type.name != conditions['eventType']) {
          return false;
        }
      }

      // Check success condition for authentication events
      if (conditions.containsKey('success')) {
        if (event.metadata['success'] != conditions['success']) {
          return false;
        }
      }

      // Check severity condition
      if (conditions.containsKey('severity')) {
        if (event.severity.name != conditions['severity']) {
          return false;
        }
      }

      // Check threshold and time window
      if (conditions.containsKey('threshold') &&
          conditions.containsKey('timeWindow')) {
        final threshold = conditions['threshold'] as int;
        final timeWindowSeconds = conditions['timeWindow'] as int;

        if (timeWindowSeconds > 0) {
          final timeWindow = Duration(seconds: timeWindowSeconds);
          final cutoffTime = DateTime.now().subtract(timeWindow);

          // Count matching events in time window
          final matchingEvents = await _countMatchingEvents(rule, cutoffTime);
          return matchingEvents >= threshold;
        } else {
          // Immediate trigger
          return true;
        }
      }

      return true;
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to evaluate alert rule',
        data: {'ruleId': rule.id},
        error: e,
      );
      return false;
    }
  }

  static Future<int> _countMatchingEvents(
    AlertRule rule,
    DateTime cutoffTime,
  ) async {
    // In a real implementation, this would query the event database
    // For now, we'll simulate by checking recent logs
    try {
      final recentLogs = await SecureLoggingService.getRecentLogs(limit: 1000);
      return recentLogs
          .where(
            (log) =>
                log.timestamp.isAfter(cutoffTime) && _logMatchesRule(log, rule),
          )
          .length;
    } catch (e) {
      return 0;
    }
  }

  static bool _logMatchesRule(LogEntry log, AlertRule rule) {
    final conditions = rule.conditions;

    // Simple matching based on log message content
    if (conditions.containsKey('eventType')) {
      final eventType = conditions['eventType'] as String;
      if (!log.message.toLowerCase().contains(eventType.toLowerCase())) {
        return false;
      }
    }

    return true;
  }

  static Future<void> _triggerAlert(AlertRule rule, SecurityEvent event) async {
    // Check if similar alert already exists
    final existingSimilarAlert = _activeAlerts
        .where(
          (alert) =>
              alert.type == rule.alertType &&
              alert.status == AlertStatus.active &&
              DateTime.now().difference(alert.createdAt) <
                  const Duration(minutes: 30),
        )
        .firstOrNull;

    if (existingSimilarAlert != null) {
      // Update existing alert instead of creating new one
      await updateAlert(
        existingSimilarAlert.id,
        additionalDetails: {
          'additionalTrigger': event.toJson(),
          'triggerCount':
              (existingSimilarAlert.details['triggerCount'] ?? 1) + 1,
        },
      );
      return;
    }

    // Create new alert
    await createAlert(
      type: rule.alertType,
      severity: rule.severity,
      title: rule.name,
      description: '${rule.description}\n\nTriggered by: ${event.description}',
      details: {
        'ruleId': rule.id,
        'triggeringEvent': event.toJson(),
        'triggerCount': 1,
      },
      recommendations: _getRecommendationsForAlertType(rule.alertType),
      autoResolveAfter: _getAutoResolveTimeForSeverity(rule.severity),
    );
  }

  static List<String> _getRecommendationsForAlertType(SecurityAlertType type) {
    switch (type) {
      case SecurityAlertType.authenticationAnomaly:
        return [
          'Review authentication logs for suspicious patterns',
          'Consider implementing additional authentication factors',
          'Check for compromised credentials',
        ];
      case SecurityAlertType.accessAnomaly:
        return [
          'Investigate access patterns for unusual behavior',
          'Review user permissions and access controls',
          'Monitor for data exfiltration attempts',
        ];
      case SecurityAlertType.integrityViolation:
        return [
          'Immediately investigate file tampering',
          'Restore files from known good backups',
          'Scan for malware or unauthorized modifications',
        ];
      case SecurityAlertType.criticalIssue:
        return [
          'Take immediate action to address critical security issue',
          'Isolate affected systems if necessary',
          'Contact security team or administrator',
        ];
      case SecurityAlertType.systemAlert:
        return [
          'Review system logs for unauthorized access',
          'Check system integrity and configuration',
          'Monitor for privilege escalation attempts',
        ];
    }
  }

  static Duration? _getAutoResolveTimeForSeverity(SecuritySeverity severity) {
    switch (severity) {
      case SecuritySeverity.low:
        return const Duration(hours: 24);
      case SecuritySeverity.medium:
        return const Duration(hours: 12);
      case SecuritySeverity.high:
        return const Duration(hours: 6);
      case SecuritySeverity.critical:
        return null; // Never auto-resolve critical alerts
    }
  }

  static AlertTrends _calculateAlertTrends(
    List<SecurityAlert> alerts,
    Duration timeWindow,
  ) {
    final now = DateTime.now();
    final halfWindow = Duration(milliseconds: timeWindow.inMilliseconds ~/ 2);
    final midPoint = now.subtract(halfWindow);

    final recentAlerts = alerts
        .where((a) => a.createdAt.isAfter(midPoint))
        .length;
    final olderAlerts = alerts
        .where((a) => a.createdAt.isBefore(midPoint))
        .length;

    final trend = recentAlerts > olderAlerts
        ? AlertTrend.increasing
        : recentAlerts < olderAlerts
        ? AlertTrend.decreasing
        : AlertTrend.stable;

    final changePercentage = olderAlerts > 0
        ? ((recentAlerts - olderAlerts) / olderAlerts * 100).round()
        : recentAlerts > 0
        ? 100
        : 0;

    return AlertTrends(
      trend: trend,
      changePercentage: changePercentage,
      recentCount: recentAlerts,
      previousCount: olderAlerts,
    );
  }

  static List<AlertTypeCount> _getTopAlertTypes(
    Map<SecurityAlertType, List<SecurityAlert>> alertsByType,
  ) {
    final typeCounts = alertsByType.entries
        .map(
          (entry) => AlertTypeCount(type: entry.key, count: entry.value.length),
        )
        .toList();

    typeCounts.sort((a, b) => b.count.compareTo(a.count));
    return typeCounts.take(5).toList();
  }

  static double _calculateResolutionRate(List<SecurityAlert> alerts) {
    if (alerts.isEmpty) return 0.0;

    final resolvedCount = alerts
        .where((alert) => alert.status == AlertStatus.resolved)
        .length;

    return resolvedCount / alerts.length;
  }

  static Duration? _calculateAverageResolutionTime(List<SecurityAlert> alerts) {
    final resolvedAlerts = alerts
        .where(
          (alert) =>
              alert.status == AlertStatus.resolved && alert.resolvedAt != null,
        )
        .toList();

    if (resolvedAlerts.isEmpty) return null;

    final totalResolutionTime = resolvedAlerts
        .map((alert) => alert.resolvedAt!.difference(alert.createdAt))
        .reduce(
          (a, b) => Duration(milliseconds: a.inMilliseconds + b.inMilliseconds),
        );

    return Duration(
      milliseconds: totalResolutionTime.inMilliseconds ~/ resolvedAlerts.length,
    );
  }

  static Future<void> _loadAlertsAndRules() async {
    try {
      // Load alerts
      final alertsData = await _storage.read(key: 'security_alerts');
      if (alertsData != null) {
        final alertsList = jsonDecode(alertsData) as List;
        _activeAlerts.clear();
        for (final alertData in alertsList) {
          _activeAlerts.add(SecurityAlert.fromJson(alertData));
        }
      }

      // Load rules
      final rulesData = await _storage.read(key: 'alert_rules');
      if (rulesData != null) {
        final rulesList = jsonDecode(rulesData) as List;
        _alertRules.clear();
        for (final ruleData in rulesList) {
          _alertRules.add(AlertRule.fromJson(ruleData));
        }
      }
    } catch (e) {
      // Ignore loading errors and start fresh
    }
  }

  static Future<void> _saveAlertsAndRules() async {
    try {
      // Save alerts
      final alertsJson = jsonEncode(
        _activeAlerts.map((a) => a.toJson()).toList(),
      );
      await _storage.write(key: 'security_alerts', value: alertsJson);

      // Save rules
      final rulesJson = jsonEncode(_alertRules.map((r) => r.toJson()).toList());
      await _storage.write(key: 'alert_rules', value: rulesJson);
    } catch (e) {
      // Ignore save errors
    }
  }

  static String _generateAlertId() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url.encode(bytes).substring(0, 16);
  }
}

// Data classes and enums

/// Security alert exception
class SecurityAlertException implements Exception {
  final String message;
  SecurityAlertException(this.message);
  @override
  String toString() => 'SecurityAlertException: $message';
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

/// Alert type count
class AlertTypeCount {
  final SecurityAlertType type;
  final int count;

  AlertTypeCount({required this.type, required this.count});

  Map<String, dynamic> toJson() => {'type': type.name, 'count': count};
}

// Enums
enum AlertTrend { increasing, decreasing, stable }

// Extension to add firstOrNull to Iterable
extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}
