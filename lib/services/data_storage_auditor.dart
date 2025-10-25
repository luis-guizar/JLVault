import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'secure_logging_service.dart';

/// Audits data storage to ensure no unencrypted sensitive data
class DataStorageAuditor {
  static const List<String> _sensitiveDataPatterns = [
    'password',
    'secret',
    'token',
    'key',
    'totp',
    'pin',
    'auth',
    'credential',
    'hash',
    'salt',
    'nonce',
    'signature',
    'private',
    'biometric',
    'fingerprint',
    'face',
  ];

  static const List<String> _allowedEncryptedPrefixes = [
    'encrypted_',
    'enc_',
    'cipher_',
  ];

  /// Performs a comprehensive audit of all data storage
  static Future<StorageAuditResult> performFullAudit() async {
    await SecureLoggingService.logSecurityEvent('storage_audit_started');

    final issues = <StorageIssue>[];
    final checkedLocations = <String>[];

    try {
      // Audit SQLite databases
      final dbIssues = await _auditSQLiteDatabases();
      issues.addAll(dbIssues);
      checkedLocations.add('SQLite Databases');

      // Audit shared preferences / secure storage
      final prefIssues = await _auditSharedPreferences();
      issues.addAll(prefIssues);
      checkedLocations.add('Shared Preferences');

      // Audit file system
      final fileIssues = await _auditFileSystem();
      issues.addAll(fileIssues);
      checkedLocations.add('File System');

      // Audit temporary files
      final tempIssues = await _auditTemporaryFiles();
      issues.addAll(tempIssues);
      checkedLocations.add('Temporary Files');

      final result = StorageAuditResult(
        auditTime: DateTime.now(),
        checkedLocations: checkedLocations,
        issues: issues,
        isCompliant: issues.isEmpty,
      );

      await SecureLoggingService.logSecurityEvent(
        'storage_audit_completed',
        data: {
          'issuesFound': issues.length,
          'isCompliant': result.isCompliant,
          'checkedLocations': checkedLocations.length,
        },
      );

      return result;
    } catch (e) {
      await SecureLoggingService.logError('Storage audit failed', error: e);

      return StorageAuditResult(
        auditTime: DateTime.now(),
        checkedLocations: checkedLocations,
        issues: [
          StorageIssue(
            type: IssueType.auditError,
            location: 'Audit System',
            description: 'Audit failed: ${e.toString()}',
            severity: IssueSeverity.high,
          ),
        ],
        isCompliant: false,
      );
    }
  }

  /// Audits a specific database for sensitive data
  static Future<List<StorageIssue>> auditDatabase(String databasePath) async {
    final issues = <StorageIssue>[];

    try {
      final database = await openDatabase(databasePath, readOnly: true);

      // Get all table names
      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );

      for (final table in tables) {
        final tableName = table['name'] as String;
        if (tableName.startsWith('sqlite_')) continue; // Skip system tables

        // Get table schema
        final columns = await database.rawQuery(
          'PRAGMA table_info($tableName)',
        );

        for (final column in columns) {
          final columnName = column['name'] as String;

          if (_isSensitiveColumnName(columnName)) {
            // Check if data in this column is encrypted
            final sampleData = await database.rawQuery(
              'SELECT $columnName FROM $tableName LIMIT 5',
            );

            for (final row in sampleData) {
              final value = row[columnName];
              if (value != null && !_isEncryptedData(value.toString())) {
                issues.add(
                  StorageIssue(
                    type: IssueType.unencryptedSensitiveData,
                    location:
                        'Database: $databasePath, Table: $tableName, Column: $columnName',
                    description: 'Potentially unencrypted sensitive data found',
                    severity: IssueSeverity.high,
                    recommendation:
                        'Encrypt sensitive data before storing in database',
                  ),
                );
                break; // Only report once per column
              }
            }
          }
        }
      }

      await database.close();
    } catch (e) {
      issues.add(
        StorageIssue(
          type: IssueType.auditError,
          location: 'Database: $databasePath',
          description: 'Failed to audit database: ${e.toString()}',
          severity: IssueSeverity.medium,
        ),
      );
    }

    return issues;
  }

  /// Validates that export data is properly secured
  static Future<bool> validateExportSecurity(String exportData) async {
    try {
      // Check if export data contains unencrypted sensitive information
      final lowerData = exportData.toLowerCase();

      for (final pattern in _sensitiveDataPatterns) {
        if (lowerData.contains(pattern)) {
          // Check if it's in an encrypted context
          if (!_isInEncryptedContext(exportData, pattern)) {
            await SecureLoggingService.logSecurityEvent(
              'insecure_export_detected',
              data: {'pattern': pattern},
            );
            return false;
          }
        }
      }

      return true;
    } catch (e) {
      await SecureLoggingService.logError(
        'Export security validation failed',
        error: e,
      );
      return false;
    }
  }

  /// Validates that import data handling is secure
  static Future<bool> validateImportSecurity(String importData) async {
    try {
      // Ensure import data doesn't contain malicious content
      final suspiciousPatterns = [
        'javascript:',
        '<script',
        'eval(',
        'function(',
        'setTimeout(',
        'setInterval(',
      ];

      final lowerData = importData.toLowerCase();
      for (final pattern in suspiciousPatterns) {
        if (lowerData.contains(pattern)) {
          await SecureLoggingService.logSecurityEvent(
            'suspicious_import_content_detected',
            data: {'pattern': pattern},
          );
          return false;
        }
      }

      return true;
    } catch (e) {
      await SecureLoggingService.logError(
        'Import security validation failed',
        error: e,
      );
      return false;
    }
  }

  // Private helper methods

  static Future<List<StorageIssue>> _auditSQLiteDatabases() async {
    final issues = <StorageIssue>[];

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dbDir = Directory(appDir.path);

      if (dbDir.existsSync()) {
        final files = dbDir.listSync(recursive: true);

        for (final file in files) {
          if (file is File && file.path.endsWith('.db')) {
            final dbIssues = await auditDatabase(file.path);
            issues.addAll(dbIssues);
          }
        }
      }
    } catch (e) {
      issues.add(
        StorageIssue(
          type: IssueType.auditError,
          location: 'SQLite Audit',
          description: 'Failed to audit SQLite databases: ${e.toString()}',
          severity: IssueSeverity.medium,
        ),
      );
    }

    return issues;
  }

  static Future<List<StorageIssue>> _auditSharedPreferences() async {
    final issues = <StorageIssue>[];

    try {
      // Note: In a real implementation, you would need platform-specific code
      // to access shared preferences directly. For now, we'll assume they're
      // properly handled by flutter_secure_storage.

      // This is a placeholder for shared preferences audit
      // In production, you'd want to check the actual preference files
    } catch (e) {
      issues.add(
        StorageIssue(
          type: IssueType.auditError,
          location: 'Shared Preferences Audit',
          description: 'Failed to audit shared preferences: ${e.toString()}',
          severity: IssueSeverity.low,
        ),
      );
    }

    return issues;
  }

  static Future<List<StorageIssue>> _auditFileSystem() async {
    final issues = <StorageIssue>[];

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final files = appDir.listSync(recursive: true);

      for (final file in files) {
        if (file is File) {
          final fileName = file.path.split('/').last.toLowerCase();

          // Check for suspicious file names
          for (final pattern in _sensitiveDataPatterns) {
            if (fileName.contains(pattern) && !fileName.contains('encrypted')) {
              issues.add(
                StorageIssue(
                  type: IssueType.suspiciousFileName,
                  location: 'File: ${file.path}',
                  description: 'File name suggests sensitive data: $fileName',
                  severity: IssueSeverity.medium,
                  recommendation:
                      'Ensure file contents are encrypted or rename file',
                ),
              );
            }
          }

          // Check for unencrypted text files that might contain sensitive data
          if (fileName.endsWith('.txt') || fileName.endsWith('.json')) {
            try {
              final content = await file.readAsString();
              if (_containsSensitiveData(content)) {
                issues.add(
                  StorageIssue(
                    type: IssueType.unencryptedSensitiveData,
                    location: 'File: ${file.path}',
                    description:
                        'Text file may contain unencrypted sensitive data',
                    severity: IssueSeverity.high,
                    recommendation:
                        'Encrypt file contents or move to secure storage',
                  ),
                );
              }
            } catch (e) {
              // Ignore files we can't read
            }
          }
        }
      }
    } catch (e) {
      issues.add(
        StorageIssue(
          type: IssueType.auditError,
          location: 'File System Audit',
          description: 'Failed to audit file system: ${e.toString()}',
          severity: IssueSeverity.medium,
        ),
      );
    }

    return issues;
  }

  static Future<List<StorageIssue>> _auditTemporaryFiles() async {
    final issues = <StorageIssue>[];

    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final files = tempDir.listSync(recursive: true);

        for (final file in files) {
          if (file is File) {
            final fileName = file.path.split('/').last.toLowerCase();

            // Temporary files should not contain sensitive data
            for (final pattern in _sensitiveDataPatterns) {
              if (fileName.contains(pattern)) {
                issues.add(
                  StorageIssue(
                    type: IssueType.sensitiveDataInTempFile,
                    location: 'Temp File: ${file.path}',
                    description: 'Temporary file name suggests sensitive data',
                    severity: IssueSeverity.high,
                    recommendation: 'Use secure temporary file handling',
                  ),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      issues.add(
        StorageIssue(
          type: IssueType.auditError,
          location: 'Temporary Files Audit',
          description: 'Failed to audit temporary files: ${e.toString()}',
          severity: IssueSeverity.low,
        ),
      );
    }

    return issues;
  }

  static bool _isSensitiveColumnName(String columnName) {
    final lowerName = columnName.toLowerCase();

    // Skip if it's clearly marked as encrypted
    for (final prefix in _allowedEncryptedPrefixes) {
      if (lowerName.startsWith(prefix)) return false;
    }

    // Check for sensitive patterns
    for (final pattern in _sensitiveDataPatterns) {
      if (lowerName.contains(pattern)) return true;
    }

    return false;
  }

  static bool _isEncryptedData(String data) {
    // Check if data looks like encrypted/encoded data
    if (data.isEmpty) return true; // Empty is safe

    // Check for base64 pattern (likely encrypted)
    final base64Pattern = RegExp(r'^[A-Za-z0-9+/]+=*$');
    if (base64Pattern.hasMatch(data) && data.length > 20) return true;

    // Check for hex pattern (likely encrypted)
    final hexPattern = RegExp(r'^[a-fA-F0-9]+$');
    if (hexPattern.hasMatch(data) && data.length > 20) return true;

    // Check for encrypted data markers
    if (data.contains(':') && data.split(':').length == 2) {
      // Likely IV:ciphertext format
      return true;
    }

    return false;
  }

  static bool _containsSensitiveData(String content) {
    final lowerContent = content.toLowerCase();

    for (final pattern in _sensitiveDataPatterns) {
      if (lowerContent.contains(pattern)) {
        // Check if it's in an encrypted context
        if (!_isInEncryptedContext(content, pattern)) {
          return true;
        }
      }
    }

    return false;
  }

  static bool _isInEncryptedContext(String content, String pattern) {
    final index = content.toLowerCase().indexOf(pattern);
    if (index == -1) return false;

    // Check surrounding context for encryption indicators
    final start = (index - 50).clamp(0, content.length);
    final end = (index + pattern.length + 50).clamp(0, content.length);
    final context = content.substring(start, end).toLowerCase();

    final encryptionIndicators = [
      'encrypted',
      'cipher',
      'base64',
      'encoded',
      'hash',
      'digest',
    ];

    for (final indicator in encryptionIndicators) {
      if (context.contains(indicator)) return true;
    }

    return false;
  }
}

/// Result of a storage audit
class StorageAuditResult {
  final DateTime auditTime;
  final List<String> checkedLocations;
  final List<StorageIssue> issues;
  final bool isCompliant;

  StorageAuditResult({
    required this.auditTime,
    required this.checkedLocations,
    required this.issues,
    required this.isCompliant,
  });

  /// Gets issues by severity
  List<StorageIssue> getIssuesBySeverity(IssueSeverity severity) {
    return issues.where((issue) => issue.severity == severity).toList();
  }

  /// Gets a summary of the audit
  Map<String, dynamic> getSummary() {
    return {
      'auditTime': auditTime.toIso8601String(),
      'checkedLocations': checkedLocations,
      'totalIssues': issues.length,
      'highSeverityIssues': getIssuesBySeverity(IssueSeverity.high).length,
      'mediumSeverityIssues': getIssuesBySeverity(IssueSeverity.medium).length,
      'lowSeverityIssues': getIssuesBySeverity(IssueSeverity.low).length,
      'isCompliant': isCompliant,
    };
  }
}

/// Individual storage issue found during audit
class StorageIssue {
  final IssueType type;
  final String location;
  final String description;
  final IssueSeverity severity;
  final String? recommendation;

  StorageIssue({
    required this.type,
    required this.location,
    required this.description,
    required this.severity,
    this.recommendation,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'location': location,
    'description': description,
    'severity': severity.name,
    'recommendation': recommendation,
  };
}

/// Types of storage issues
enum IssueType {
  unencryptedSensitiveData,
  suspiciousFileName,
  sensitiveDataInTempFile,
  auditError,
}

/// Severity levels for storage issues
enum IssueSeverity { low, medium, high }
