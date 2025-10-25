import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../data/db_helper.dart';
import '../data/vault_db_helper.dart';
import '../models/account.dart';
import '../models/vault_metadata.dart';

/// Service for ensuring data integrity and consistency
class DataIntegrityService {
  static DataIntegrityService? _instance;
  static DataIntegrityService get instance =>
      _instance ??= DataIntegrityService._();

  DataIntegrityService._();

  static const Duration _integrityCheckInterval = Duration(hours: 6);
  Timer? _integrityCheckTimer;
  bool _isInitialized = false;

  /// Initialize data integrity service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Perform initial integrity check
      await performIntegrityCheck();

      // Start periodic integrity checks
      _startPeriodicIntegrityChecks();

      _isInitialized = true;

      if (kDebugMode) {
        print('Data integrity service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing data integrity service: $e');
      }
    }
  }

  /// Start periodic integrity checks
  void _startPeriodicIntegrityChecks() {
    _integrityCheckTimer?.cancel();

    _integrityCheckTimer = Timer.periodic(_integrityCheckInterval, (timer) {
      performIntegrityCheck().catchError((e) {
        if (kDebugMode) {
          print('Error in periodic integrity check: $e');
        }
      });
    });
  }

  /// Perform comprehensive data integrity check
  Future<IntegrityCheckResult> performIntegrityCheck() async {
    final stopwatch = Stopwatch()..start();
    final result = IntegrityCheckResult();

    try {
      if (kDebugMode) {
        print('Starting data integrity check');
      }

      // Check database integrity
      await _checkDatabaseIntegrity(result);

      // Check data consistency
      await _checkDataConsistency(result);

      // Check foreign key constraints
      await _checkForeignKeyConstraints(result);

      // Check for orphaned data
      await _checkOrphanedData(result);

      // Check data corruption
      await _checkDataCorruption(result);

      // Attempt to fix issues if found
      if (result.hasIssues) {
        await _attemptAutoFix(result);
      }

      result.completedAt = DateTime.now();
      result.duration = stopwatch.elapsed;

      if (kDebugMode) {
        print(
          'Data integrity check completed in ${stopwatch.elapsedMilliseconds}ms',
        );
        print('Issues found: ${result.issues.length}');
        print('Issues fixed: ${result.fixedIssues.length}');
      }

      return result;
    } catch (e) {
      result.fatalError = e.toString();
      if (kDebugMode) {
        print('Fatal error during integrity check: $e');
      }
      return result;
    } finally {
      stopwatch.stop();
    }
  }

  /// Check database integrity using SQLite PRAGMA commands
  Future<void> _checkDatabaseIntegrity(IntegrityCheckResult result) async {
    try {
      // Check main database
      final db = await DBHelper.db;
      final mainIntegrityResult = await db.rawQuery('PRAGMA integrity_check');

      for (final row in mainIntegrityResult) {
        final message = row.values.first.toString();
        if (message != 'ok') {
          result.addIssue(
            IntegrityIssue(
              type: IntegrityIssueType.databaseCorruption,
              severity: IntegrityIssueSeverity.critical,
              description: 'Main database integrity issue: $message',
              table: 'accounts',
            ),
          );
        }
      }

      // Check vault database
      final vaultDb = await VaultDbHelper.db;
      final vaultIntegrityResult = await vaultDb.rawQuery(
        'PRAGMA integrity_check',
      );

      for (final row in vaultIntegrityResult) {
        final message = row.values.first.toString();
        if (message != 'ok') {
          result.addIssue(
            IntegrityIssue(
              type: IntegrityIssueType.databaseCorruption,
              severity: IntegrityIssueSeverity.critical,
              description: 'Vault database integrity issue: $message',
              table: 'vault_metadata',
            ),
          );
        }
      }
    } catch (e) {
      result.addIssue(
        IntegrityIssue(
          type: IntegrityIssueType.databaseCorruption,
          severity: IntegrityIssueSeverity.critical,
          description: 'Error checking database integrity: $e',
        ),
      );
    }
  }

  /// Check data consistency between related tables
  Future<void> _checkDataConsistency(IntegrityCheckResult result) async {
    try {
      // Check account-vault consistency
      await _checkAccountVaultConsistency(result);

      // Check vault metadata consistency
      await _checkVaultMetadataConsistency(result);

      // Check TOTP configuration consistency
      await _checkTOTPConsistency(result);
    } catch (e) {
      result.addIssue(
        IntegrityIssue(
          type: IntegrityIssueType.dataInconsistency,
          severity: IntegrityIssueSeverity.high,
          description: 'Error checking data consistency: $e',
        ),
      );
    }
  }

  /// Check account-vault consistency
  Future<void> _checkAccountVaultConsistency(
    IntegrityCheckResult result,
  ) async {
    try {
      final db = await DBHelper.db;

      // Find accounts with invalid vault IDs
      final invalidVaultAccounts = await db.rawQuery('''
        SELECT a.id, a.name, a.vault_id
        FROM accounts a
        LEFT JOIN vault_metadata v ON a.vault_id = v.id
        WHERE v.id IS NULL AND a.vault_id != 'default'
      ''');

      for (final account in invalidVaultAccounts) {
        result.addIssue(
          IntegrityIssue(
            type: IntegrityIssueType.orphanedData,
            severity: IntegrityIssueSeverity.medium,
            description:
                'Account "${account['name']}" references non-existent vault "${account['vault_id']}"',
            table: 'accounts',
            recordId: account['id'].toString(),
            fixable: true,
          ),
        );
      }
    } catch (e) {
      result.addIssue(
        IntegrityIssue(
          type: IntegrityIssueType.dataInconsistency,
          severity: IntegrityIssueSeverity.high,
          description: 'Error checking account-vault consistency: $e',
        ),
      );
    }
  }

  /// Check vault metadata consistency
  Future<void> _checkVaultMetadataConsistency(
    IntegrityCheckResult result,
  ) async {
    try {
      final vaults = await VaultDbHelper.getAllVaults();

      for (final vault in vaults) {
        // Check if vault has valid data
        if (vault.name.isEmpty) {
          result.addIssue(
            IntegrityIssue(
              type: IntegrityIssueType.dataInconsistency,
              severity: IntegrityIssueSeverity.medium,
              description: 'Vault "${vault.id}" has empty name',
              table: 'vault_metadata',
              recordId: vault.id,
              fixable: true,
            ),
          );
        }

        // Check password count consistency
        final actualCount = await DBHelper.getAccountCountForVault(vault.id);
        if (vault.passwordCount != actualCount) {
          result.addIssue(
            IntegrityIssue(
              type: IntegrityIssueType.dataInconsistency,
              severity: IntegrityIssueSeverity.low,
              description:
                  'Vault "${vault.name}" password count mismatch: stored=${vault.passwordCount}, actual=$actualCount',
              table: 'vault_metadata',
              recordId: vault.id,
              fixable: true,
            ),
          );
        }
      }
    } catch (e) {
      result.addIssue(
        IntegrityIssue(
          type: IntegrityIssueType.dataInconsistency,
          severity: IntegrityIssueSeverity.high,
          description: 'Error checking vault metadata consistency: $e',
        ),
      );
    }
  }

  /// Check TOTP configuration consistency
  Future<void> _checkTOTPConsistency(IntegrityCheckResult result) async {
    try {
      final accounts = await DBHelper.getAll();

      for (final account in accounts) {
        if (account.totpConfig != null) {
          // Validate TOTP configuration
          final config = account.totpConfig!;

          if (config.secret.isEmpty) {
            result.addIssue(
              IntegrityIssue(
                type: IntegrityIssueType.dataCorruption,
                severity: IntegrityIssueSeverity.medium,
                description: 'Account "${account.name}" has empty TOTP secret',
                table: 'accounts',
                recordId: account.id.toString(),
                fixable: true,
              ),
            );
          }

          if (config.digits < 6 || config.digits > 8) {
            result.addIssue(
              IntegrityIssue(
                type: IntegrityIssueType.dataCorruption,
                severity: IntegrityIssueSeverity.low,
                description:
                    'Account "${account.name}" has invalid TOTP digits: ${config.digits}',
                table: 'accounts',
                recordId: account.id.toString(),
                fixable: true,
              ),
            );
          }
        }
      }
    } catch (e) {
      result.addIssue(
        IntegrityIssue(
          type: IntegrityIssueType.dataInconsistency,
          severity: IntegrityIssueSeverity.high,
          description: 'Error checking TOTP consistency: $e',
        ),
      );
    }
  }

  /// Check foreign key constraints
  Future<void> _checkForeignKeyConstraints(IntegrityCheckResult result) async {
    try {
      final db = await DBHelper.db;

      // Enable foreign key checking temporarily
      await db.execute('PRAGMA foreign_keys = ON');

      // Check for foreign key violations
      final violations = await db.rawQuery('PRAGMA foreign_key_check');

      for (final violation in violations) {
        result.addIssue(
          IntegrityIssue(
            type: IntegrityIssueType.constraintViolation,
            severity: IntegrityIssueSeverity.high,
            description: 'Foreign key violation: ${violation.toString()}',
            fixable: false,
          ),
        );
      }
    } catch (e) {
      result.addIssue(
        IntegrityIssue(
          type: IntegrityIssueType.constraintViolation,
          severity: IntegrityIssueSeverity.high,
          description: 'Error checking foreign key constraints: $e',
        ),
      );
    }
  }

  /// Check for orphaned data
  Future<void> _checkOrphanedData(IntegrityCheckResult result) async {
    try {
      // This is already covered in _checkAccountVaultConsistency
      // but could be extended for other types of orphaned data
    } catch (e) {
      result.addIssue(
        IntegrityIssue(
          type: IntegrityIssueType.orphanedData,
          severity: IntegrityIssueSeverity.medium,
          description: 'Error checking for orphaned data: $e',
        ),
      );
    }
  }

  /// Check for data corruption
  Future<void> _checkDataCorruption(IntegrityCheckResult result) async {
    try {
      final accounts = await DBHelper.getAll();

      for (final account in accounts) {
        // Check for corrupted account data
        if (account.name.isEmpty && account.username.isEmpty) {
          result.addIssue(
            IntegrityIssue(
              type: IntegrityIssueType.dataCorruption,
              severity: IntegrityIssueSeverity.high,
              description:
                  'Account ${account.id} has both empty name and username',
              table: 'accounts',
              recordId: account.id.toString(),
              fixable: false,
            ),
          );
        }

        // Check for invalid timestamps
        if (account.createdAt != null && account.modifiedAt != null) {
          if (account.createdAt!.isAfter(account.modifiedAt!)) {
            result.addIssue(
              IntegrityIssue(
                type: IntegrityIssueType.dataCorruption,
                severity: IntegrityIssueSeverity.low,
                description:
                    'Account "${account.name}" has created date after modified date',
                table: 'accounts',
                recordId: account.id.toString(),
                fixable: true,
              ),
            );
          }
        }
      }
    } catch (e) {
      result.addIssue(
        IntegrityIssue(
          type: IntegrityIssueType.dataCorruption,
          severity: IntegrityIssueSeverity.high,
          description: 'Error checking for data corruption: $e',
        ),
      );
    }
  }

  /// Attempt to automatically fix issues
  Future<void> _attemptAutoFix(IntegrityCheckResult result) async {
    final fixableIssues = result.issues
        .where((issue) => issue.fixable)
        .toList();

    for (final issue in fixableIssues) {
      try {
        final fixed = await _fixIssue(issue);
        if (fixed) {
          result.fixedIssues.add(issue);
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error fixing issue: ${issue.description} - $e');
        }
      }
    }
  }

  /// Fix a specific integrity issue
  Future<bool> _fixIssue(IntegrityIssue issue) async {
    switch (issue.type) {
      case IntegrityIssueType.orphanedData:
        return await _fixOrphanedData(issue);

      case IntegrityIssueType.dataInconsistency:
        return await _fixDataInconsistency(issue);

      case IntegrityIssueType.dataCorruption:
        return await _fixDataCorruption(issue);

      default:
        return false;
    }
  }

  /// Fix orphaned data issues
  Future<bool> _fixOrphanedData(IntegrityIssue issue) async {
    try {
      if (issue.table == 'accounts' && issue.recordId != null) {
        // Move orphaned accounts to default vault
        final db = await DBHelper.db;
        await db.update(
          'accounts',
          {'vault_id': 'default'},
          where: 'id = ?',
          whereArgs: [int.parse(issue.recordId!)],
        );
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fixing orphaned data: $e');
      }
    }
    return false;
  }

  /// Fix data inconsistency issues
  Future<bool> _fixDataInconsistency(IntegrityIssue issue) async {
    try {
      if (issue.table == 'vault_metadata' &&
          issue.description.contains('password count mismatch')) {
        // Fix vault password count
        final vaultId = issue.recordId!;
        final actualCount = await DBHelper.getAccountCountForVault(vaultId);
        await VaultDbHelper.updateVaultStatistics(
          vaultId,
          passwordCount: actualCount,
        );
        return true;
      }

      if (issue.table == 'vault_metadata' &&
          issue.description.contains('empty name')) {
        // Fix empty vault name
        final vaultId = issue.recordId!;
        final vault = await VaultDbHelper.getVaultById(vaultId);
        if (vault != null) {
          final updatedVault = vault.copyWith(name: 'Unnamed Vault');
          await VaultDbHelper.updateVault(updatedVault);
          return true;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fixing data inconsistency: $e');
      }
    }
    return false;
  }

  /// Fix data corruption issues
  Future<bool> _fixDataCorruption(IntegrityIssue issue) async {
    try {
      if (issue.table == 'accounts' &&
          issue.description.contains('created date after modified date')) {
        // Fix timestamp inconsistency
        final accountId = int.parse(issue.recordId!);
        final db = await DBHelper.db;
        await db.update(
          'accounts',
          {'modified_at': DateTime.now().millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [accountId],
        );
        return true;
      }

      if (issue.table == 'accounts' &&
          issue.description.contains('empty TOTP secret')) {
        // Remove invalid TOTP configuration
        final accountId = int.parse(issue.recordId!);
        final db = await DBHelper.db;
        await db.update(
          'accounts',
          {'totp_config': null},
          where: 'id = ?',
          whereArgs: [accountId],
        );
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fixing data corruption: $e');
      }
    }
    return false;
  }

  /// Create backup before performing fixes
  Future<String?> createBackup() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupData = {
        'timestamp': timestamp,
        'accounts': await _exportAccounts(),
        'vaults': await _exportVaults(),
      };

      final backupFile = await _getBackupFile(timestamp);
      await backupFile.writeAsString(jsonEncode(backupData));

      return backupFile.path;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating backup: $e');
      }
      return null;
    }
  }

  /// Export all accounts for backup
  Future<List<Map<String, dynamic>>> _exportAccounts() async {
    final accounts = await DBHelper.getAll();
    return accounts.map((account) => account.toMap()).toList();
  }

  /// Export all vaults for backup
  Future<List<Map<String, dynamic>>> _exportVaults() async {
    final vaults = await VaultDbHelper.getAllVaults();
    return vaults.map((vault) => vault.toMap()).toList();
  }

  /// Get backup file
  Future<File> _getBackupFile(int timestamp) async {
    final directory = await _getAppDocumentsDirectory();
    return File('${directory.path}/backup_$timestamp.json');
  }

  /// Get app documents directory
  Future<Directory> _getAppDocumentsDirectory() async {
    // This would use path_provider in a real implementation
    return Directory.systemTemp; // Simplified for now
  }

  /// Get data integrity statistics
  Map<String, dynamic> getStats() {
    return {
      'isInitialized': _isInitialized,
      'integrityCheckInterval': _integrityCheckInterval.inHours,
      'periodicChecksActive': _integrityCheckTimer?.isActive ?? false,
    };
  }

  /// Dispose resources
  void dispose() {
    _integrityCheckTimer?.cancel();

    if (kDebugMode) {
      print('Data integrity service disposed');
    }
  }
}

/// Result of an integrity check
class IntegrityCheckResult {
  final List<IntegrityIssue> issues = [];
  final List<IntegrityIssue> fixedIssues = [];
  DateTime? completedAt;
  Duration? duration;
  String? fatalError;

  bool get hasIssues => issues.isNotEmpty;
  bool get hasUnfixedIssues =>
      issues.any((issue) => !fixedIssues.contains(issue));
  bool get hasCriticalIssues =>
      issues.any((issue) => issue.severity == IntegrityIssueSeverity.critical);

  void addIssue(IntegrityIssue issue) {
    issues.add(issue);
  }
}

/// Individual integrity issue
class IntegrityIssue {
  final IntegrityIssueType type;
  final IntegrityIssueSeverity severity;
  final String description;
  final String? table;
  final String? recordId;
  final bool fixable;

  const IntegrityIssue({
    required this.type,
    required this.severity,
    required this.description,
    this.table,
    this.recordId,
    this.fixable = false,
  });
}

/// Types of integrity issues
enum IntegrityIssueType {
  databaseCorruption,
  dataInconsistency,
  dataCorruption,
  orphanedData,
  constraintViolation,
}

/// Severity levels for integrity issues
enum IntegrityIssueSeverity { low, medium, high, critical }
