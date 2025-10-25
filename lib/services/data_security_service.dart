import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'data_storage_auditor.dart';
import 'secure_logging_service.dart';
import 'secure_temp_file_service.dart';

/// Comprehensive data security service that coordinates all security aspects
class DataSecurityService {
  static Timer? _periodicAuditTimer;
  static bool _initialized = false;

  /// Initialize the data security service
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize all security services
      await SecureLoggingService.initialize();
      await SecureTempFileService.initialize();

      // Start periodic security audits
      await _startPeriodicAudits();

      // Perform initial security audit
      await performSecurityAudit();

      _initialized = true;

      await SecureLoggingService.logSecurityEvent(
        'data_security_service_initialized',
        data: {'timestamp': DateTime.now().toIso8601String()},
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to initialize data security service',
        error: e,
      );
      throw Exception('Data security service initialization failed: $e');
    }
  }

  /// Dispose of the data security service
  static Future<void> dispose() async {
    if (!_initialized) return;

    try {
      _periodicAuditTimer?.cancel();
      await SecureTempFileService.deleteAllTempFiles();
      await SecureLoggingService.dispose();

      _initialized = false;

      await SecureLoggingService.logSecurityEvent(
        'data_security_service_disposed',
        data: {'timestamp': DateTime.now().toIso8601String()},
      );
    } catch (e) {
      // Ignore disposal errors
    }
  }

  /// Performs a comprehensive security audit of all data storage
  static Future<SecurityAuditReport> performSecurityAudit() async {
    if (!_initialized) {
      await initialize();
    }

    await SecureLoggingService.logSecurityEvent('security_audit_started');

    try {
      // Perform storage audit
      final storageAudit = await DataStorageAuditor.performFullAudit();

      // Check for temporary file leaks
      final tempFileIssues = await _auditTemporaryFiles();

      // Check for log file security
      final logFileIssues = await _auditLogFiles();

      // Check for database security
      final databaseIssues = await _auditDatabaseSecurity();

      // Compile comprehensive report
      final report = SecurityAuditReport(
        auditTime: DateTime.now(),
        storageAudit: storageAudit,
        tempFileIssues: tempFileIssues,
        logFileIssues: logFileIssues,
        databaseIssues: databaseIssues,
        overallCompliance: _calculateOverallCompliance([
          storageAudit.isCompliant,
          tempFileIssues.isEmpty,
          logFileIssues.isEmpty,
          databaseIssues.isEmpty,
        ]),
      );

      await SecureLoggingService.logSecurityEvent(
        'security_audit_completed',
        data: {
          'isCompliant': report.overallCompliance,
          'totalIssues': report.getTotalIssueCount(),
          'highSeverityIssues': report.getHighSeverityIssueCount(),
        },
      );

      return report;
    } catch (e) {
      await SecureLoggingService.logError('Security audit failed', error: e);

      return SecurityAuditReport(
        auditTime: DateTime.now(),
        storageAudit: StorageAuditResult(
          auditTime: DateTime.now(),
          checkedLocations: [],
          issues: [
            StorageIssue(
              type: IssueType.auditError,
              location: 'Security Audit System',
              description: 'Audit failed: ${e.toString()}',
              severity: IssueSeverity.high,
            ),
          ],
          isCompliant: false,
        ),
        tempFileIssues: [],
        logFileIssues: [],
        databaseIssues: [],
        overallCompliance: false,
      );
    }
  }

  /// Validates that import data is secure before processing
  static Future<bool> validateImportSecurity(String importData) async {
    try {
      await SecureLoggingService.logSecurityEvent(
        'import_security_validation_started',
        data: {'dataSize': importData.length},
      );

      final isValid = await DataStorageAuditor.validateImportSecurity(
        importData,
      );

      await SecureLoggingService.logSecurityEvent(
        'import_security_validation_completed',
        data: {'isValid': isValid},
      );

      return isValid;
    } catch (e) {
      await SecureLoggingService.logError(
        'Import security validation failed',
        error: e,
      );
      return false;
    }
  }

  /// Validates that export data is secure before writing
  static Future<bool> validateExportSecurity(String exportData) async {
    try {
      await SecureLoggingService.logSecurityEvent(
        'export_security_validation_started',
        data: {'dataSize': exportData.length},
      );

      final isValid = await DataStorageAuditor.validateExportSecurity(
        exportData,
      );

      await SecureLoggingService.logSecurityEvent(
        'export_security_validation_completed',
        data: {'isValid': isValid},
      );

      return isValid;
    } catch (e) {
      await SecureLoggingService.logError(
        'Export security validation failed',
        error: e,
      );
      return false;
    }
  }

  /// Securely cleans up all temporary data
  static Future<void> performSecurityCleanup() async {
    try {
      await SecureLoggingService.logSecurityEvent('security_cleanup_started');

      // Clean up temporary files
      await SecureTempFileService.deleteAllTempFiles();

      // Clean up any orphaned files
      await _cleanupOrphanedFiles();

      await SecureLoggingService.logSecurityEvent('security_cleanup_completed');
    } catch (e) {
      await SecureLoggingService.logError('Security cleanup failed', error: e);
    }
  }

  /// Gets security statistics for monitoring
  static Future<SecurityStats> getSecurityStats() async {
    try {
      final recentLogs = await SecureLoggingService.getRecentLogs(limit: 100);
      final tempFiles = SecureTempFileService.getActiveTempFiles();
      final lastAudit = await _getLastAuditTime();

      return SecurityStats(
        lastAuditTime: lastAudit,
        recentLogCount: recentLogs.length,
        activeTempFileCount: tempFiles.length,
        securityEventCount: recentLogs
            .where((log) => log.level == LogLevel.security)
            .length,
        errorCount: recentLogs
            .where((log) => log.level == LogLevel.error)
            .length,
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to get security stats',
        error: e,
      );
      return SecurityStats(
        lastAuditTime: null,
        recentLogCount: 0,
        activeTempFileCount: 0,
        securityEventCount: 0,
        errorCount: 1,
      );
    }
  }

  // Private helper methods

  static Future<void> _startPeriodicAudits() async {
    // Perform security audit every 24 hours
    _periodicAuditTimer = Timer.periodic(const Duration(hours: 24), (
      timer,
    ) async {
      try {
        await performSecurityAudit();
      } catch (e) {
        await SecureLoggingService.logError(
          'Periodic security audit failed',
          error: e,
        );
      }
    });
  }

  static Future<List<SecurityIssue>> _auditTemporaryFiles() async {
    final issues = <SecurityIssue>[];

    try {
      final tempFiles = SecureTempFileService.getActiveTempFiles();
      final now = DateTime.now();

      for (final tempFile in tempFiles) {
        // Check for old temporary files (older than 1 hour)
        if (now.difference(tempFile.createdAt) > const Duration(hours: 1)) {
          issues.add(
            SecurityIssue(
              type: 'stale_temp_file',
              severity: 'medium',
              description:
                  'Temporary file older than 1 hour: ${tempFile.fileName}',
              location: 'Temp File: ${tempFile.fileId}',
              recommendation: 'Clean up old temporary files',
            ),
          );
        }

        // Check for large temporary files (>10MB)
        if (tempFile.sizeBytes > 10 * 1024 * 1024) {
          issues.add(
            SecurityIssue(
              type: 'large_temp_file',
              severity: 'low',
              description:
                  'Large temporary file: ${tempFile.fileName} (${tempFile.sizeBytes} bytes)',
              location: 'Temp File: ${tempFile.fileId}',
              recommendation: 'Monitor temporary file sizes',
            ),
          );
        }
      }
    } catch (e) {
      issues.add(
        SecurityIssue(
          type: 'temp_file_audit_error',
          severity: 'medium',
          description: 'Failed to audit temporary files: ${e.toString()}',
          location: 'Temporary File System',
          recommendation: 'Check temporary file system integrity',
        ),
      );
    }

    return issues;
  }

  static Future<List<SecurityIssue>> _auditLogFiles() async {
    final issues = <SecurityIssue>[];

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final logFiles = Directory(appDir.path)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.contains('log'))
          .toList();

      for (final logFile in logFiles) {
        // Check for unencrypted log files
        if (!logFile.path.contains('.enc')) {
          final content = await logFile.readAsString();
          if (_containsSensitiveData(content)) {
            issues.add(
              SecurityIssue(
                type: 'unencrypted_sensitive_logs',
                severity: 'high',
                description: 'Unencrypted log file may contain sensitive data',
                location: 'Log File: ${logFile.path}',
                recommendation: 'Encrypt log files containing sensitive data',
              ),
            );
          }
        }

        // Check for large log files (>5MB)
        if (logFile.lengthSync() > 5 * 1024 * 1024) {
          issues.add(
            SecurityIssue(
              type: 'large_log_file',
              severity: 'low',
              description: 'Large log file may impact performance',
              location: 'Log File: ${logFile.path}',
              recommendation: 'Rotate or compress large log files',
            ),
          );
        }
      }
    } catch (e) {
      issues.add(
        SecurityIssue(
          type: 'log_file_audit_error',
          severity: 'medium',
          description: 'Failed to audit log files: ${e.toString()}',
          location: 'Log File System',
          recommendation: 'Check log file system integrity',
        ),
      );
    }

    return issues;
  }

  static Future<List<SecurityIssue>> _auditDatabaseSecurity() async {
    final issues = <SecurityIssue>[];

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dbFiles = Directory(appDir.path)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.db'))
          .toList();

      for (final dbFile in dbFiles) {
        // Audit each database file
        final dbIssues = await DataStorageAuditor.auditDatabase(dbFile.path);
        for (final issue in dbIssues) {
          issues.add(
            SecurityIssue(
              type: issue.type.name,
              severity: issue.severity.name,
              description: issue.description,
              location: issue.location,
              recommendation:
                  issue.recommendation ?? 'Review database security',
            ),
          );
        }
      }
    } catch (e) {
      issues.add(
        SecurityIssue(
          type: 'database_audit_error',
          severity: 'high',
          description: 'Failed to audit database security: ${e.toString()}',
          location: 'Database System',
          recommendation: 'Check database system integrity',
        ),
      );
    }

    return issues;
  }

  static Future<void> _cleanupOrphanedFiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final files = appDir.listSync(recursive: true).whereType<File>();

      for (final file in files) {
        final fileName = file.path.split('/').last.toLowerCase();

        // Look for temporary files that weren't cleaned up
        if (fileName.contains('temp') || fileName.contains('tmp')) {
          final stat = file.statSync();
          final age = DateTime.now().difference(stat.modified);

          // Delete temporary files older than 24 hours
          if (age > const Duration(hours: 24)) {
            try {
              await file.delete();
              await SecureLoggingService.logInfo(
                'Cleaned up orphaned temporary file',
                data: {'filePath': file.path, 'ageHours': age.inHours},
              );
            } catch (e) {
              await SecureLoggingService.logWarning(
                'Failed to delete orphaned file',
                data: {'filePath': file.path, 'error': e.toString()},
              );
            }
          }
        }
      }
    } catch (e) {
      await SecureLoggingService.logError(
        'Failed to cleanup orphaned files',
        error: e,
      );
    }
  }

  static bool _containsSensitiveData(String content) {
    final sensitivePatterns = [
      'password',
      'secret',
      'token',
      'key',
      'totp',
      'pin',
      'auth',
      'credential',
    ];

    final lowerContent = content.toLowerCase();
    return sensitivePatterns.any((pattern) => lowerContent.contains(pattern));
  }

  static bool _calculateOverallCompliance(List<bool> complianceResults) {
    return complianceResults.every((result) => result);
  }

  static Future<DateTime?> _getLastAuditTime() async {
    try {
      final logs = await SecureLoggingService.getRecentLogs(limit: 1000);
      final auditLogs = logs
          .where((log) => log.message.contains('security_audit_completed'))
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
}

/// Comprehensive security audit report
class SecurityAuditReport {
  final DateTime auditTime;
  final StorageAuditResult storageAudit;
  final List<SecurityIssue> tempFileIssues;
  final List<SecurityIssue> logFileIssues;
  final List<SecurityIssue> databaseIssues;
  final bool overallCompliance;

  SecurityAuditReport({
    required this.auditTime,
    required this.storageAudit,
    required this.tempFileIssues,
    required this.logFileIssues,
    required this.databaseIssues,
    required this.overallCompliance,
  });

  int getTotalIssueCount() {
    return storageAudit.issues.length +
        tempFileIssues.length +
        logFileIssues.length +
        databaseIssues.length;
  }

  int getHighSeverityIssueCount() {
    int count = storageAudit.getIssuesBySeverity(IssueSeverity.high).length;
    count += tempFileIssues.where((issue) => issue.severity == 'high').length;
    count += logFileIssues.where((issue) => issue.severity == 'high').length;
    count += databaseIssues.where((issue) => issue.severity == 'high').length;
    return count;
  }

  Map<String, dynamic> toJson() {
    return {
      'auditTime': auditTime.toIso8601String(),
      'overallCompliance': overallCompliance,
      'totalIssues': getTotalIssueCount(),
      'highSeverityIssues': getHighSeverityIssueCount(),
      'storageAudit': storageAudit.getSummary(),
      'tempFileIssues': tempFileIssues.map((issue) => issue.toJson()).toList(),
      'logFileIssues': logFileIssues.map((issue) => issue.toJson()).toList(),
      'databaseIssues': databaseIssues.map((issue) => issue.toJson()).toList(),
    };
  }
}

/// Individual security issue
class SecurityIssue {
  final String type;
  final String severity;
  final String description;
  final String location;
  final String recommendation;

  SecurityIssue({
    required this.type,
    required this.severity,
    required this.description,
    required this.location,
    required this.recommendation,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'severity': severity,
      'description': description,
      'location': location,
      'recommendation': recommendation,
    };
  }
}

/// Security statistics for monitoring
class SecurityStats {
  final DateTime? lastAuditTime;
  final int recentLogCount;
  final int activeTempFileCount;
  final int securityEventCount;
  final int errorCount;

  SecurityStats({
    required this.lastAuditTime,
    required this.recentLogCount,
    required this.activeTempFileCount,
    required this.securityEventCount,
    required this.errorCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'lastAuditTime': lastAuditTime?.toIso8601String(),
      'recentLogCount': recentLogCount,
      'activeTempFileCount': activeTempFileCount,
      'securityEventCount': securityEventCount,
      'errorCount': errorCount,
    };
  }
}
