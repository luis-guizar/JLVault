import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'security_audit_service.dart';
import 'secure_logging_service.dart';
import 'enhanced_auth_service.dart';

/// Real-time security monitoring service with threat detection
class SecurityMonitoringService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
  );

  static Timer? _monitoringTimer;
  static Timer? _threatAnalysisTimer;
  static bool _initialized = false;
  static final List<ThreatIndicator> _threatIndicators = [];
  static final List<SecurityMetric> _securityMetrics = [];
  static final StreamController<SecurityEvent> _eventController =
      StreamController.broadcast();

  // Monitoring thresholds
  static const Duration _monitoringInterval = Duration(minutes: 2);
  static const Duration _threatAnalysisInterval = Duration(minutes: 10);
  static const int _maxThreatIndicators = 1000;
  static const int _maxSecurityMetrics = 500;

  // Threat detection parameters
  static const int _rapidAccessThreshold = 15;
  static const int _authFailureThreshold = 3;
  static const Duration _suspiciousTimeWindow = Duration(minutes: 5);
  static const double _anomalyScoreThreshold = 0.7;

  /// Initialize the security monitoring service
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await SecureLoggingService.logSecurityEvent(
        'security_monitoring_service_initializing',
      );

      // Load historical data
      await _loadHistoricalData();

      // Start real-time monitoring
      await _startRealTimeMonitoring();

      // Start threat analysis
      await _startThreatAnalysis();

      _initialized = true;

      await SecureLoggingService.logSecurityEvent(
        'security_monitoring_service_initialized',
        data: {'timestamp': DateTime.now().toIso8601String()},
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to initialize security monitoring service',
        error: e,
      );
      throw SecurityMonitoringException(
        'Security monitoring initialization failed: $e',
      );
    }
  }

  /// Dispose of the security monitoring service
  static Future<void> dispose() async {
    if (!_initialized) return;

    try {
      _monitoringTimer?.cancel();
      _threatAnalysisTimer?.cancel();
      await _eventController.close();

      // Save current state
      await _saveMonitoringState();

      _threatIndicators.clear();
      _securityMetrics.clear();
      _initialized = false;

      await SecureLoggingService.logSecurityEvent(
        'security_monitoring_service_disposed',
      );
    } catch (e) {
      // Ignore disposal errors
    }
  }

  /// Stream of security events for real-time monitoring
  static Stream<SecurityEvent> get securityEventStream =>
      _eventController.stream;

  /// Records a security event for monitoring
  static Future<void> recordSecurityEvent({
    required SecurityEventType eventType,
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
      final event = SecurityEvent(
        id: _generateEventId(),
        type: eventType,
        description: description,
        severity: severity,
        timestamp: DateTime.now(),
        metadata: metadata ?? {},
        userId: userId,
        resourceId: resourceId,
      );

      // Add to event stream
      _eventController.add(event);

      // Log the event
      await SecureLoggingService.logSecurityEvent(
        'security_event_recorded',
        data: {
          'eventId': event.id,
          'eventType': eventType.name,
          'severity': severity.name,
          'description': description,
          'hasMetadata': metadata != null,
          'hasUserId': userId != null,
          'hasResourceId': resourceId != null,
        },
      );

      // Analyze for threats
      await _analyzeEventForThreats(event);

      // Update security metrics
      await _updateSecurityMetrics(event);
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to record security event',
        error: e,
      );
    }
  }

  /// Detects unusual access patterns
  static Future<List<AccessAnomalyResult>> detectAccessAnomalies({
    Duration? timeWindow,
    String? userId,
    String? resourceType,
  }) async {
    try {
      final window = timeWindow ?? const Duration(hours: 1);
      final cutoffTime = DateTime.now().subtract(window);

      final anomalies = <AccessAnomalyResult>[];

      // Get recent security events
      final recentEvents = _getRecentEvents(cutoffTime);

      // Filter by criteria
      var filteredEvents = recentEvents;
      if (userId != null) {
        filteredEvents = filteredEvents
            .where((e) => e.userId == userId)
            .toList();
      }
      if (resourceType != null) {
        filteredEvents = filteredEvents
            .where((e) => e.metadata['resourceType'] == resourceType)
            .toList();
      }

      // Detect rapid access patterns
      final rapidAccessAnomaly = _detectRapidAccess(filteredEvents, window);
      if (rapidAccessAnomaly != null) {
        anomalies.add(rapidAccessAnomaly);
      }

      // Detect unusual time patterns
      final timeAnomalies = _detectUnusualTimingPatterns(filteredEvents);
      anomalies.addAll(timeAnomalies);

      // Detect resource access anomalies
      final resourceAnomalies = _detectResourceAccessAnomalies(filteredEvents);
      anomalies.addAll(resourceAnomalies);

      await SecureLoggingService.logSecurityEvent(
        'access_anomaly_detection_completed',
        data: {
          'timeWindow': window.inMinutes,
          'eventCount': filteredEvents.length,
          'anomalyCount': anomalies.length,
          'hasUserFilter': userId != null,
          'hasResourceFilter': resourceType != null,
        },
      );

      return anomalies;
    } catch (e) {
      await SecureLoggingService.logError(
        'Access anomaly detection failed',
        error: e,
      );
      return [];
    }
  }

  /// Analyzes authentication patterns for suspicious activity
  static Future<AuthenticationAnalysisResult> analyzeAuthenticationPatterns({
    Duration? timeWindow,
    String? userId,
  }) async {
    try {
      final window = timeWindow ?? const Duration(hours: 24);
      final cutoffTime = DateTime.now().subtract(window);

      final authEvents = _getRecentEvents(
        cutoffTime,
      ).where((e) => e.type == SecurityEventType.authentication).toList();

      if (userId != null) {
        authEvents.removeWhere((e) => e.userId != userId);
      }

      final analysis = AuthenticationAnalysisResult(
        timeWindow: window,
        totalAttempts: authEvents.length,
        successfulAttempts: authEvents
            .where((e) => e.metadata['success'] == true)
            .length,
        failedAttempts: authEvents
            .where((e) => e.metadata['success'] == false)
            .length,
        uniqueUsers: authEvents
            .map((e) => e.userId)
            .where((id) => id != null)
            .toSet()
            .length,
        suspiciousPatterns: [],
        riskScore: 0.0,
      );

      // Calculate failure rate
      final failureRate = analysis.totalAttempts > 0
          ? analysis.failedAttempts / analysis.totalAttempts
          : 0.0;

      // Detect suspicious patterns
      if (analysis.failedAttempts >= _authFailureThreshold) {
        analysis.suspiciousPatterns.add('High authentication failure rate');
      }

      if (failureRate > 0.5) {
        analysis.suspiciousPatterns.add(
          'Excessive failure rate (${(failureRate * 100).toStringAsFixed(1)}%)',
        );
      }

      // Check for rapid authentication attempts
      final rapidAttempts = _detectRapidAuthenticationAttempts(authEvents);
      if (rapidAttempts.isNotEmpty) {
        analysis.suspiciousPatterns.add(
          'Rapid authentication attempts detected',
        );
      }

      // Calculate risk score
      analysis.riskScore = _calculateAuthenticationRiskScore(
        analysis,
        failureRate,
      );

      await SecureLoggingService.logSecurityEvent(
        'authentication_analysis_completed',
        data: {
          'timeWindow': window.inHours,
          'totalAttempts': analysis.totalAttempts,
          'failureRate': failureRate,
          'riskScore': analysis.riskScore,
          'suspiciousPatternCount': analysis.suspiciousPatterns.length,
        },
      );

      return analysis;
    } catch (e) {
      await SecureLoggingService.logError(
        'Authentication pattern analysis failed',
        error: e,
      );

      return AuthenticationAnalysisResult(
        timeWindow: timeWindow ?? const Duration(hours: 24),
        totalAttempts: 0,
        successfulAttempts: 0,
        failedAttempts: 0,
        uniqueUsers: 0,
        suspiciousPatterns: ['Analysis failed'],
        riskScore: 1.0,
      );
    }
  }

  /// Gets current threat indicators
  static List<ThreatIndicator> getCurrentThreatIndicators() {
    return List.unmodifiable(_threatIndicators);
  }

  /// Gets security monitoring dashboard data
  static Future<SecurityDashboardData> getDashboardData() async {
    try {
      final now = DateTime.now();
      final last24Hours = now.subtract(const Duration(hours: 24));

      // Get recent events
      final recentEvents = _getRecentEvents(last24Hours);

      // Get active alerts from audit service
      final activeAlerts = SecurityAuditService.getActiveAlerts();

      // Get authentication stats
      final authStats = await EnhancedAuthService.getAuthStats();

      // Get monitoring stats
      final monitoringStats = await SecurityAuditService.getMonitoringStats();

      // Calculate threat level
      final threatLevel = _calculateOverallThreatLevel();

      // Get recent anomalies
      final recentAnomalies = await detectAccessAnomalies(
        timeWindow: const Duration(hours: 6),
      );

      return SecurityDashboardData(
        timestamp: now,
        threatLevel: threatLevel,
        activeAlerts: activeAlerts.length,
        recentEvents: recentEvents.length,
        authFailures: authStats.failedAttempts,
        anomaliesDetected: recentAnomalies.length,
        monitoredResources: monitoringStats.monitoredFiles,
        integrityViolations: monitoringStats.integrityViolations,
        lastAuditTime: monitoringStats.lastAuditTime,
        securityScore: _calculateCurrentSecurityScore(),
        threatIndicators: _threatIndicators.take(10).toList(),
        recentAlerts: activeAlerts.take(5).toList(),
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to get dashboard data',
        error: e,
      );

      return SecurityDashboardData(
        timestamp: DateTime.now(),
        threatLevel: ThreatLevel.unknown,
        activeAlerts: 0,
        recentEvents: 0,
        authFailures: 0,
        anomaliesDetected: 0,
        monitoredResources: 0,
        integrityViolations: 0,
        lastAuditTime: null,
        securityScore: 0,
        threatIndicators: [],
        recentAlerts: [],
      );
    }
  }

  /// Generates a security report
  static Future<SecurityReport> generateSecurityReport({
    Duration? timeWindow,
    bool includeDetails = false,
  }) async {
    try {
      final window = timeWindow ?? const Duration(days: 7);
      final cutoffTime = DateTime.now().subtract(window);

      // Get comprehensive audit
      final auditResult =
          await SecurityAuditService.performComprehensiveAudit();

      // Get authentication analysis
      final authAnalysis = await analyzeAuthenticationPatterns(
        timeWindow: window,
      );

      // Get access anomalies
      final accessAnomalies = await detectAccessAnomalies(timeWindow: window);

      // Get dashboard data
      final dashboardData = await getDashboardData();

      final report = SecurityReport(
        generatedAt: DateTime.now(),
        timeWindow: window,
        auditResult: auditResult,
        authenticationAnalysis: authAnalysis,
        accessAnomalies: accessAnomalies,
        dashboardData: dashboardData,
        threatIndicators: _threatIndicators
            .where((t) => t.detectedAt.isAfter(cutoffTime))
            .toList(),
        includeDetails: includeDetails,
      );

      await SecureLoggingService.logSecurityEvent(
        'security_report_generated',
        data: {
          'timeWindow': window.inDays,
          'includeDetails': includeDetails,
          'issueCount': auditResult.issues.length,
          'anomalyCount': accessAnomalies.length,
          'threatCount': report.threatIndicators.length,
        },
      );

      return report;
    } catch (e) {
      await SecureLoggingService.logError(
        'Security report generation failed',
        error: e,
      );
      rethrow;
    }
  }

  // Private helper methods

  static Future<void> _startRealTimeMonitoring() async {
    _monitoringTimer = Timer.periodic(_monitoringInterval, (timer) async {
      try {
        await _performRealTimeCheck();
      } catch (e) {
        await SecureLoggingService.logError(
          'Real-time monitoring check failed',
          error: e,
        );
      }
    });
  }

  static Future<void> _startThreatAnalysis() async {
    _threatAnalysisTimer = Timer.periodic(_threatAnalysisInterval, (
      timer,
    ) async {
      try {
        await _performThreatAnalysis();
      } catch (e) {
        await SecureLoggingService.logError('Threat analysis failed', error: e);
      }
    });
  }

  static Future<void> _performRealTimeCheck() async {
    // Check for immediate threats
    final recentEvents = _getRecentEvents(
      DateTime.now().subtract(_suspiciousTimeWindow),
    );

    // Check for rapid access patterns
    if (recentEvents.length > _rapidAccessThreshold) {
      await _createThreatIndicator(
        type: ThreatType.rapidAccess,
        severity: SecuritySeverity.medium,
        description: 'Rapid access pattern detected',
        confidence: 0.8,
        metadata: {'eventCount': recentEvents.length},
      );
    }

    // Check for authentication anomalies
    final authEvents = recentEvents
        .where((e) => e.type == SecurityEventType.authentication)
        .toList();

    final failedAuthEvents = authEvents
        .where((e) => e.metadata['success'] == false)
        .toList();

    if (failedAuthEvents.length >= _authFailureThreshold) {
      await _createThreatIndicator(
        type: ThreatType.authenticationAnomaly,
        severity: SecuritySeverity.high,
        description: 'Multiple authentication failures detected',
        confidence: 0.9,
        metadata: {'failureCount': failedAuthEvents.length},
      );
    }
  }

  static Future<void> _performThreatAnalysis() async {
    // Analyze patterns over longer time periods
    final analysisWindow = DateTime.now().subtract(const Duration(hours: 2));
    final events = _getRecentEvents(analysisWindow);

    // Behavioral analysis
    await _performBehavioralAnalysis(events);

    // Pattern recognition
    await _performPatternRecognition(events);

    // Clean up old threat indicators
    _cleanupOldThreatIndicators();
  }

  static Future<void> _performBehavioralAnalysis(
    List<SecurityEvent> events,
  ) async {
    // Group events by user
    final userEvents = <String, List<SecurityEvent>>{};
    for (final event in events) {
      if (event.userId != null) {
        userEvents[event.userId!] = (userEvents[event.userId!] ?? [])
          ..add(event);
      }
    }

    // Analyze each user's behavior
    for (final entry in userEvents.entries) {
      final userId = entry.key;
      final userEventList = entry.value;

      // Check for unusual activity patterns
      final anomalyScore = _calculateUserAnomalyScore(userEventList);
      if (anomalyScore > _anomalyScoreThreshold) {
        await _createThreatIndicator(
          type: ThreatType.behavioralAnomaly,
          severity: SecuritySeverity.medium,
          description: 'Unusual user behavior detected for user $userId',
          confidence: anomalyScore,
          metadata: {
            'userId': userId,
            'eventCount': userEventList.length,
            'anomalyScore': anomalyScore,
          },
        );
      }
    }
  }

  static Future<void> _performPatternRecognition(
    List<SecurityEvent> events,
  ) async {
    // Time-based pattern analysis
    final hourlyDistribution = <int, int>{};
    for (final event in events) {
      final hour = event.timestamp.hour;
      hourlyDistribution[hour] = (hourlyDistribution[hour] ?? 0) + 1;
    }

    // Check for unusual time patterns
    final totalEvents = events.length;
    if (totalEvents > 0) {
      for (final entry in hourlyDistribution.entries) {
        final hour = entry.key;
        final count = entry.value;
        final percentage = count / totalEvents;

        // Flag unusual activity during off-hours (11 PM - 5 AM)
        if ((hour >= 23 || hour <= 5) && percentage > 0.3) {
          await _createThreatIndicator(
            type: ThreatType.unusualTiming,
            severity: SecuritySeverity.low,
            description: 'High activity during off-hours (${hour}:00)',
            confidence: 0.6,
            metadata: {
              'hour': hour,
              'eventCount': count,
              'percentage': percentage,
            },
          );
        }
      }
    }
  }

  static Future<void> _analyzeEventForThreats(SecurityEvent event) async {
    // Immediate threat analysis for new events
    switch (event.type) {
      case SecurityEventType.authentication:
        if (event.metadata['success'] == false) {
          await _analyzeAuthenticationFailure(event);
        }
        break;
      case SecurityEventType.dataAccess:
        await _analyzeDataAccess(event);
        break;
      case SecurityEventType.systemAccess:
        await _analyzeSystemAccess(event);
        break;
      case SecurityEventType.configurationChange:
        await _analyzeConfigurationChange(event);
        break;
      default:
        // No specific analysis for other event types
        break;
    }
  }

  static Future<void> _analyzeAuthenticationFailure(SecurityEvent event) async {
    // Check for rapid authentication failures from same source
    final recentFailures =
        _getRecentEvents(DateTime.now().subtract(const Duration(minutes: 5)))
            .where(
              (e) =>
                  e.type == SecurityEventType.authentication &&
                  e.metadata['success'] == false &&
                  e.userId == event.userId,
            )
            .length;

    if (recentFailures >= 3) {
      await _createThreatIndicator(
        type: ThreatType.bruteForceAttempt,
        severity: SecuritySeverity.high,
        description: 'Potential brute force attack detected',
        confidence: 0.85,
        metadata: {
          'userId': event.userId,
          'failureCount': recentFailures,
          'timeWindow': '5 minutes',
        },
      );
    }
  }

  static Future<void> _analyzeDataAccess(SecurityEvent event) async {
    // Check for unusual data access patterns
    final resourceId = event.resourceId;
    if (resourceId != null) {
      final recentAccess =
          _getRecentEvents(DateTime.now().subtract(const Duration(minutes: 10)))
              .where(
                (e) =>
                    e.type == SecurityEventType.dataAccess &&
                    e.resourceId == resourceId,
              )
              .length;

      if (recentAccess > 20) {
        await _createThreatIndicator(
          type: ThreatType.dataExfiltration,
          severity: SecuritySeverity.medium,
          description: 'Rapid data access pattern detected',
          confidence: 0.7,
          metadata: {
            'resourceId': resourceId,
            'accessCount': recentAccess,
            'timeWindow': '10 minutes',
          },
        );
      }
    }
  }

  static Future<void> _analyzeSystemAccess(SecurityEvent event) async {
    // Check for unauthorized system access attempts
    if (event.severity == SecuritySeverity.high) {
      await _createThreatIndicator(
        type: ThreatType.unauthorizedAccess,
        severity: SecuritySeverity.high,
        description: 'High-severity system access event detected',
        confidence: 0.8,
        metadata: {
          'eventDescription': event.description,
          'userId': event.userId,
        },
      );
    }
  }

  static Future<void> _analyzeConfigurationChange(SecurityEvent event) async {
    // Configuration changes are always significant
    await _createThreatIndicator(
      type: ThreatType.configurationTampering,
      severity: SecuritySeverity.medium,
      description: 'Configuration change detected',
      confidence: 0.9,
      metadata: {
        'changeDescription': event.description,
        'userId': event.userId,
      },
    );
  }

  static Future<void> _updateSecurityMetrics(SecurityEvent event) async {
    final metric = SecurityMetric(
      timestamp: event.timestamp,
      eventType: event.type,
      severity: event.severity,
      userId: event.userId,
      resourceId: event.resourceId,
    );

    _securityMetrics.add(metric);

    // Keep only recent metrics
    if (_securityMetrics.length > _maxSecurityMetrics) {
      _securityMetrics.removeRange(
        0,
        _securityMetrics.length - _maxSecurityMetrics,
      );
    }
  }

  static Future<void> _createThreatIndicator({
    required ThreatType type,
    required SecuritySeverity severity,
    required String description,
    required double confidence,
    Map<String, dynamic>? metadata,
  }) async {
    final indicator = ThreatIndicator(
      id: _generateThreatId(),
      type: type,
      severity: severity,
      description: description,
      confidence: confidence,
      detectedAt: DateTime.now(),
      metadata: metadata ?? {},
    );

    _threatIndicators.add(indicator);

    // Keep only recent indicators
    if (_threatIndicators.length > _maxThreatIndicators) {
      _threatIndicators.removeRange(
        0,
        _threatIndicators.length - _maxThreatIndicators,
      );
    }

    await SecureLoggingService.logSecurityEvent(
      'threat_indicator_created',
      data: {
        'indicatorId': indicator.id,
        'type': type.name,
        'severity': severity.name,
        'confidence': confidence,
        'description': description,
      },
    );

    // Add to event stream
    _eventController.add(
      SecurityEvent(
        id: _generateEventId(),
        type: SecurityEventType.threatDetected,
        description: 'Threat indicator created: $description',
        severity: severity,
        timestamp: DateTime.now(),
        metadata: {
          'threatType': type.name,
          'confidence': confidence,
          'indicatorId': indicator.id,
        },
      ),
    );
  }

  static List<SecurityEvent> _getRecentEvents(DateTime cutoffTime) {
    // In a real implementation, this would query a database
    // For now, we'll simulate with recent events from logs
    return [];
  }

  static AccessAnomalyResult? _detectRapidAccess(
    List<SecurityEvent> events,
    Duration window,
  ) {
    if (events.length > _rapidAccessThreshold) {
      return AccessAnomalyResult(
        type: AccessAnomalyType.rapidAccess,
        severity: SecuritySeverity.medium,
        description:
            'Rapid access pattern detected: ${events.length} events in ${window.inMinutes} minutes',
        eventCount: events.length,
        timeWindow: window,
        confidence: 0.8,
        detectedAt: DateTime.now(),
      );
    }
    return null;
  }

  static List<AccessAnomalyResult> _detectUnusualTimingPatterns(
    List<SecurityEvent> events,
  ) {
    final anomalies = <AccessAnomalyResult>[];

    // Check for off-hours activity
    final offHoursEvents = events.where((e) {
      final hour = e.timestamp.hour;
      return hour >= 22 || hour <= 6;
    }).toList();

    if (offHoursEvents.length > events.length * 0.5) {
      anomalies.add(
        AccessAnomalyResult(
          type: AccessAnomalyType.unusualTiming,
          severity: SecuritySeverity.low,
          description: 'High activity during off-hours',
          eventCount: offHoursEvents.length,
          timeWindow: const Duration(hours: 24),
          confidence: 0.6,
          detectedAt: DateTime.now(),
        ),
      );
    }

    return anomalies;
  }

  static List<AccessAnomalyResult> _detectResourceAccessAnomalies(
    List<SecurityEvent> events,
  ) {
    final anomalies = <AccessAnomalyResult>[];

    // Group by resource
    final resourceAccess = <String, int>{};
    for (final event in events) {
      if (event.resourceId != null) {
        resourceAccess[event.resourceId!] =
            (resourceAccess[event.resourceId!] ?? 0) + 1;
      }
    }

    // Check for excessive access to single resource
    for (final entry in resourceAccess.entries) {
      if (entry.value > 50) {
        // Threshold for excessive access
        anomalies.add(
          AccessAnomalyResult(
            type: AccessAnomalyType.excessiveResourceAccess,
            severity: SecuritySeverity.medium,
            description: 'Excessive access to resource ${entry.key}',
            eventCount: entry.value,
            timeWindow: const Duration(hours: 1),
            confidence: 0.7,
            detectedAt: DateTime.now(),
          ),
        );
      }
    }

    return anomalies;
  }

  static List<SecurityEvent> _detectRapidAuthenticationAttempts(
    List<SecurityEvent> authEvents,
  ) {
    final rapidAttempts = <SecurityEvent>[];

    for (int i = 0; i < authEvents.length - 2; i++) {
      final event1 = authEvents[i];
      final event2 = authEvents[i + 1];
      final event3 = authEvents[i + 2];

      // Check if 3 attempts within 1 minute
      if (event3.timestamp.difference(event1.timestamp) <
          const Duration(minutes: 1)) {
        rapidAttempts.addAll([event1, event2, event3]);
      }
    }

    return rapidAttempts;
  }

  static double _calculateAuthenticationRiskScore(
    AuthenticationAnalysisResult analysis,
    double failureRate,
  ) {
    double score = 0.0;

    // Base score from failure rate
    score += failureRate * 0.4;

    // Add score for suspicious patterns
    score += analysis.suspiciousPatterns.length * 0.2;

    // Add score for high failure count
    if (analysis.failedAttempts > 10) {
      score += 0.3;
    }

    return math.min(1.0, score);
  }

  static double _calculateUserAnomalyScore(List<SecurityEvent> userEvents) {
    double score = 0.0;

    // Check event frequency
    final timeSpan = userEvents.isNotEmpty
        ? userEvents.last.timestamp.difference(userEvents.first.timestamp)
        : Duration.zero;

    if (timeSpan.inMinutes > 0) {
      final eventsPerMinute = userEvents.length / timeSpan.inMinutes;
      if (eventsPerMinute > 2) {
        score += 0.3;
      }
    }

    // Check event diversity
    final eventTypes = userEvents.map((e) => e.type).toSet();
    if (eventTypes.length == 1 && userEvents.length > 10) {
      score += 0.2; // Repetitive behavior
    }

    // Check severity distribution
    final highSeverityEvents = userEvents
        .where(
          (e) =>
              e.severity == SecuritySeverity.high ||
              e.severity == SecuritySeverity.critical,
        )
        .length;

    if (highSeverityEvents > userEvents.length * 0.5) {
      score += 0.4;
    }

    return math.min(1.0, score);
  }

  static ThreatLevel _calculateOverallThreatLevel() {
    if (_threatIndicators.isEmpty) {
      return ThreatLevel.low;
    }

    final recentIndicators = _threatIndicators
        .where(
          (t) =>
              DateTime.now().difference(t.detectedAt) <
              const Duration(hours: 1),
        )
        .toList();

    if (recentIndicators.isEmpty) {
      return ThreatLevel.low;
    }

    final criticalCount = recentIndicators
        .where((t) => t.severity == SecuritySeverity.critical)
        .length;

    final highCount = recentIndicators
        .where((t) => t.severity == SecuritySeverity.high)
        .length;

    if (criticalCount > 0) {
      return ThreatLevel.critical;
    } else if (highCount >= 3) {
      return ThreatLevel.high;
    } else if (highCount > 0 || recentIndicators.length >= 5) {
      return ThreatLevel.medium;
    } else {
      return ThreatLevel.low;
    }
  }

  static int _calculateCurrentSecurityScore() {
    int score = 100;

    // Deduct points for active threats
    for (final indicator in _threatIndicators) {
      final age = DateTime.now().difference(indicator.detectedAt);
      if (age < const Duration(hours: 24)) {
        switch (indicator.severity) {
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
    }

    return math.max(0, score);
  }

  static void _cleanupOldThreatIndicators() {
    final cutoffTime = DateTime.now().subtract(const Duration(days: 7));
    _threatIndicators.removeWhere(
      (indicator) => indicator.detectedAt.isBefore(cutoffTime),
    );
  }

  static Future<void> _loadHistoricalData() async {
    try {
      final data = await _storage.read(key: 'security_monitoring_state');
      if (data != null) {
        final state = jsonDecode(data) as Map<String, dynamic>;

        // Load threat indicators
        final indicators = state['threatIndicators'] as List?;
        if (indicators != null) {
          _threatIndicators.clear();
          for (final indicatorData in indicators) {
            _threatIndicators.add(ThreatIndicator.fromJson(indicatorData));
          }
        }
      }
    } catch (e) {
      // Ignore loading errors and start fresh
    }
  }

  static Future<void> _saveMonitoringState() async {
    try {
      final state = {
        'threatIndicators': _threatIndicators.map((t) => t.toJson()).toList(),
        'lastSaved': DateTime.now().toIso8601String(),
      };

      await _storage.write(
        key: 'security_monitoring_state',
        value: jsonEncode(state),
      );
    } catch (e) {
      // Ignore save errors
    }
  }

  static String _generateEventId() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url.encode(bytes).substring(0, 16);
  }

  static String _generateThreatId() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url.encode(bytes).substring(0, 16);
  }
}

// Data classes and enums

/// Security monitoring exception
class SecurityMonitoringException implements Exception {
  final String message;
  SecurityMonitoringException(this.message);
  @override
  String toString() => 'SecurityMonitoringException: $message';
}

/// Security event for monitoring
class SecurityEvent {
  final String id;
  final SecurityEventType type;
  final String description;
  final SecuritySeverity severity;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final String? userId;
  final String? resourceId;

  SecurityEvent({
    required this.id,
    required this.type,
    required this.description,
    required this.severity,
    required this.timestamp,
    required this.metadata,
    this.userId,
    this.resourceId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'description': description,
    'severity': severity.name,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
    'userId': userId,
    'resourceId': resourceId,
  };

  factory SecurityEvent.fromJson(Map<String, dynamic> json) => SecurityEvent(
    id: json['id'],
    type: SecurityEventType.values.firstWhere((t) => t.name == json['type']),
    description: json['description'],
    severity: SecuritySeverity.values.firstWhere(
      (s) => s.name == json['severity'],
    ),
    timestamp: DateTime.parse(json['timestamp']),
    metadata: Map<String, dynamic>.from(json['metadata']),
    userId: json['userId'],
    resourceId: json['resourceId'],
  );
}

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

/// Security metric for analysis
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
}

/// Access anomaly detection result
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

/// Authentication pattern analysis result
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
  final int securityScore;
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
    required this.lastAuditTime,
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

/// Comprehensive security report
class SecurityReport {
  final DateTime generatedAt;
  final Duration timeWindow;
  final SecurityAuditResult auditResult;
  final AuthenticationAnalysisResult authenticationAnalysis;
  final List<AccessAnomalyResult> accessAnomalies;
  final SecurityDashboardData dashboardData;
  final List<ThreatIndicator> threatIndicators;
  final bool includeDetails;

  SecurityReport({
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

// Enums
enum SecurityEventType {
  authentication,
  dataAccess,
  systemAccess,
  configurationChange,
  threatDetected,
  auditEvent,
}

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

enum AccessAnomalyType {
  rapidAccess,
  unusualTiming,
  excessiveResourceAccess,
  suspiciousPattern,
}

enum ThreatLevel { low, medium, high, critical, unknown }
