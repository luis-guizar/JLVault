import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import '../models/account.dart';
import '../models/totp_config.dart';
import 'secure_logging_service.dart';
import 'secure_temp_file_service.dart';
import 'data_storage_auditor.dart';
import 'enhanced_auth_service.dart';

/// Secure service for importing password data from various formats
class SecureImportService {
  /// Securely imports accounts from a CSV file to a specific vault
  static Future<SecureImportResult> importFromCsv(
    String filePath,
    String targetVaultId, {
    bool hasHeader = true,
    String delimiter = ',',
    bool requireAuth = true,
  }) async {
    SecureTempFile? tempFile;

    try {
      await SecureLoggingService.logSecurityEvent(
        'import_attempt_started',
        data: {
          'format': 'csv',
          'targetVaultId': targetVaultId,
          'filePath': _sanitizeFilePath(filePath),
        },
      );

      // Step 1: Require authentication for import operations
      if (requireAuth) {
        final authResult =
            await EnhancedAuthService.authenticateForSensitiveOperation(
              operation: 'data import',
              customReason: 'Authenticate to import password data',
            );

        if (!authResult.isSuccess) {
          await SecureLoggingService.logSecurityEvent(
            'import_auth_failed',
            data: {'reason': authResult.errorMessage},
          );
          return SecureImportResult.failure(
            'Authentication failed: ${authResult.errorMessage}',
          );
        }
      }

      // Step 2: Create secure temporary file for processing
      tempFile = await SecureTempFileService.createImportTempFile(
        importType: 'csv',
      );

      // Step 3: Securely read and validate the source file
      final sourceFile = File(filePath);
      if (!await sourceFile.exists()) {
        throw ImportException('File not found: $filePath');
      }

      final content = await sourceFile.readAsString();

      // Step 4: Validate import data security
      final isSecure = await DataStorageAuditor.validateImportSecurity(content);
      if (!isSecure) {
        await SecureLoggingService.logSecurityEvent(
          'insecure_import_data_detected',
          data: {'format': 'csv'},
        );
        return SecureImportResult.failure(
          'Import data contains suspicious content',
        );
      }

      // Step 5: Write content to secure temporary file
      await tempFile.writeEncrypted(content);

      // Step 6: Process the CSV data
      final processedContent = await tempFile.readDecrypted();
      final rows = const CsvToListConverter().convert(
        processedContent,
        fieldDelimiter: delimiter,
      );

      if (rows.isEmpty) {
        throw ImportException('CSV file is empty');
      }

      final accounts = <Account>[];
      final startIndex = hasHeader ? 1 : 0;
      final errors = <String>[];

      for (int i = startIndex; i < rows.length; i++) {
        try {
          final row = rows[i];
          if (row.length < 3) {
            errors.add(
              'Row ${i + 1}: Insufficient columns (minimum 3 required)',
            );
            continue;
          }

          final account = Account(
            name:
                _sanitizeImportField(row[0]?.toString()) ??
                'Imported Account $i',
            username: _sanitizeImportField(row[1]?.toString()) ?? '',
            password: row[2]?.toString() ?? '',
            url: row.length > 3
                ? _sanitizeImportField(row[3]?.toString())
                : null,
            notes: row.length > 4
                ? _sanitizeImportField(row[4]?.toString())
                : null,
            vaultId: targetVaultId,
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
          );

          accounts.add(account);
        } catch (e) {
          errors.add('Row ${i + 1}: ${e.toString()}');
        }
      }

      await SecureLoggingService.logSecurityEvent(
        'import_completed_successfully',
        data: {
          'format': 'csv',
          'importedCount': accounts.length,
          'errorCount': errors.length,
        },
      );

      return SecureImportResult.success(
        accounts: accounts,
        importedCount: accounts.length,
        errors: errors,
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'CSV import failed',
        data: {
          'targetVaultId': targetVaultId,
          'filePath': _sanitizeFilePath(filePath),
        },
        error: e,
      );

      return SecureImportResult.failure('Import failed: ${e.toString()}');
    } finally {
      // Step 7: Always clean up temporary files
      if (tempFile != null) {
        try {
          await tempFile.delete();
        } catch (e) {
          await SecureLoggingService.logWarning(
            'Failed to cleanup import temp file',
            data: {'fileId': tempFile.fileId},
          );
        }
      }
    }
  }

  /// Securely imports accounts from a JSON file to a specific vault
  static Future<SecureImportResult> importFromJson(
    String filePath,
    String targetVaultId, {
    bool requireAuth = true,
  }) async {
    SecureTempFile? tempFile;

    try {
      await SecureLoggingService.logSecurityEvent(
        'import_attempt_started',
        data: {
          'format': 'json',
          'targetVaultId': targetVaultId,
          'filePath': _sanitizeFilePath(filePath),
        },
      );

      // Step 1: Require authentication for import operations
      if (requireAuth) {
        final authResult =
            await EnhancedAuthService.authenticateForSensitiveOperation(
              operation: 'data import',
              customReason: 'Authenticate to import password data',
            );

        if (!authResult.isSuccess) {
          await SecureLoggingService.logSecurityEvent(
            'import_auth_failed',
            data: {'reason': authResult.errorMessage},
          );
          return SecureImportResult.failure(
            'Authentication failed: ${authResult.errorMessage}',
          );
        }
      }

      // Step 2: Create secure temporary file for processing
      tempFile = await SecureTempFileService.createImportTempFile(
        importType: 'json',
      );

      // Step 3: Securely read and validate the source file
      final sourceFile = File(filePath);
      if (!await sourceFile.exists()) {
        throw ImportException('File not found: $filePath');
      }

      final content = await sourceFile.readAsString();

      // Step 4: Validate import data security
      final isSecure = await DataStorageAuditor.validateImportSecurity(content);
      if (!isSecure) {
        await SecureLoggingService.logSecurityEvent(
          'insecure_import_data_detected',
          data: {'format': 'json'},
        );
        return SecureImportResult.failure(
          'Import data contains suspicious content',
        );
      }

      // Step 5: Write content to secure temporary file
      await tempFile.writeEncrypted(content);

      // Step 6: Process the JSON data
      final processedContent = await tempFile.readDecrypted();
      final jsonData = jsonDecode(processedContent);

      if (jsonData is! List && jsonData is! Map<String, dynamic>) {
        throw ImportException(
          'JSON file must contain an array of accounts or a valid export object',
        );
      }

      final accounts = <Account>[];
      final errors = <String>[];
      List<dynamic> items;

      // Handle different JSON structures
      if (jsonData is List) {
        items = jsonData;
      } else if (jsonData is Map<String, dynamic> &&
          jsonData.containsKey('accounts')) {
        items = jsonData['accounts'] as List;
      } else {
        throw ImportException('Invalid JSON structure');
      }

      for (int i = 0; i < items.length; i++) {
        try {
          final item = items[i];
          if (item is! Map<String, dynamic>) {
            errors.add('Item ${i + 1}: Invalid item format');
            continue;
          }

          // Parse TOTP configuration if present
          TOTPConfig? totpConfig;
          if (item.containsKey('totp') &&
              item['totp'] is Map<String, dynamic>) {
            final totpData = item['totp'] as Map<String, dynamic>;
            totpConfig = TOTPConfig(
              secret: totpData['secret']?.toString() ?? '',
              issuer: totpData['issuer']?.toString() ?? '',
              accountName: totpData['accountName']?.toString() ?? '',
              digits: totpData['digits'] ?? 6,
              period: totpData['period'] ?? 30,
              algorithm: TOTPAlgorithm.fromString(
                totpData['algorithm']?.toString() ?? 'SHA1',
              ),
            );
          }

          final account = Account(
            name: _sanitizeImportField(
              item['name']?.toString() ??
                  item['title']?.toString() ??
                  'Imported Account ${i + 1}',
            )!,
            username: _sanitizeImportField(
              item['username']?.toString() ?? item['login']?.toString() ?? '',
            )!,
            password: item['password']?.toString() ?? '',
            url: _sanitizeImportField(item['url']?.toString()),
            notes: _sanitizeImportField(item['notes']?.toString()),
            vaultId: targetVaultId,
            totpConfig: totpConfig,
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
          );

          accounts.add(account);
        } catch (e) {
          errors.add('Item ${i + 1}: ${e.toString()}');
        }
      }

      await SecureLoggingService.logSecurityEvent(
        'import_completed_successfully',
        data: {
          'format': 'json',
          'importedCount': accounts.length,
          'errorCount': errors.length,
        },
      );

      return SecureImportResult.success(
        accounts: accounts,
        importedCount: accounts.length,
        errors: errors,
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'JSON import failed',
        data: {
          'targetVaultId': targetVaultId,
          'filePath': _sanitizeFilePath(filePath),
        },
        error: e,
      );

      return SecureImportResult.failure('Import failed: ${e.toString()}');
    } finally {
      // Step 7: Always clean up temporary files
      if (tempFile != null) {
        try {
          await tempFile.delete();
        } catch (e) {
          await SecureLoggingService.logWarning(
            'Failed to cleanup import temp file',
            data: {'fileId': tempFile.fileId},
          );
        }
      }
    }
  }

  /// Securely imports accounts from Bitwarden JSON export to a specific vault
  static Future<SecureImportResult> importFromBitwarden(
    String filePath,
    String targetVaultId, {
    bool requireAuth = true,
  }) async {
    SecureTempFile? tempFile;

    try {
      await SecureLoggingService.logSecurityEvent(
        'import_attempt_started',
        data: {
          'format': 'bitwarden',
          'targetVaultId': targetVaultId,
          'filePath': _sanitizeFilePath(filePath),
        },
      );

      // Step 1: Require authentication for import operations
      if (requireAuth) {
        final authResult =
            await EnhancedAuthService.authenticateForSensitiveOperation(
              operation: 'data import',
              customReason: 'Authenticate to import Bitwarden data',
            );

        if (!authResult.isSuccess) {
          return SecureImportResult.failure(
            'Authentication failed: ${authResult.errorMessage}',
          );
        }
      }

      // Step 2: Create secure temporary file for processing
      tempFile = await SecureTempFileService.createImportTempFile(
        importType: 'bitwarden',
      );

      // Step 3: Securely read and validate the source file
      final sourceFile = File(filePath);
      if (!await sourceFile.exists()) {
        throw ImportException('File not found: $filePath');
      }

      final content = await sourceFile.readAsString();

      // Step 4: Validate import data security
      final isSecure = await DataStorageAuditor.validateImportSecurity(content);
      if (!isSecure) {
        return SecureImportResult.failure(
          'Import data contains suspicious content',
        );
      }

      // Step 5: Write content to secure temporary file and process
      await tempFile.writeEncrypted(content);
      final processedContent = await tempFile.readDecrypted();
      final jsonData = jsonDecode(processedContent);

      if (jsonData is! Map<String, dynamic> || !jsonData.containsKey('items')) {
        throw ImportException('Invalid Bitwarden export format');
      }

      final items = jsonData['items'] as List;
      final accounts = <Account>[];
      final errors = <String>[];

      for (int i = 0; i < items.length; i++) {
        try {
          final item = items[i];
          if (item is! Map<String, dynamic>) {
            errors.add('Item ${i + 1}: Invalid item format');
            continue;
          }

          // Only import login items
          if (item['type'] != 1) continue;

          final login = item['login'] as Map<String, dynamic>?;
          if (login == null) {
            errors.add('Item ${i + 1}: No login data found');
            continue;
          }

          // Parse TOTP if present
          TOTPConfig? totpConfig;
          if (login['totp'] != null) {
            final totpUri = login['totp'].toString();
            totpConfig = TOTPConfig.fromUri(totpUri);
          }

          // Parse URL from URIs array
          String? url;
          if (login['uris'] is List && (login['uris'] as List).isNotEmpty) {
            final uris = login['uris'] as List;
            if (uris.first is Map<String, dynamic>) {
              url = (uris.first as Map<String, dynamic>)['uri']?.toString();
            }
          }

          final account = Account(
            name:
                _sanitizeImportField(item['name']?.toString()) ??
                'Imported Account ${i + 1}',
            username: _sanitizeImportField(login['username']?.toString()) ?? '',
            password: login['password']?.toString() ?? '',
            url: _sanitizeImportField(url),
            notes: _sanitizeImportField(item['notes']?.toString()),
            vaultId: targetVaultId,
            totpConfig: totpConfig,
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
          );

          accounts.add(account);
        } catch (e) {
          errors.add('Item ${i + 1}: ${e.toString()}');
        }
      }

      await SecureLoggingService.logSecurityEvent(
        'import_completed_successfully',
        data: {
          'format': 'bitwarden',
          'importedCount': accounts.length,
          'errorCount': errors.length,
        },
      );

      return SecureImportResult.success(
        accounts: accounts,
        importedCount: accounts.length,
        errors: errors,
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'Bitwarden import failed',
        data: {
          'targetVaultId': targetVaultId,
          'filePath': _sanitizeFilePath(filePath),
        },
        error: e,
      );

      return SecureImportResult.failure('Import failed: ${e.toString()}');
    } finally {
      if (tempFile != null) {
        try {
          await tempFile.delete();
        } catch (e) {
          await SecureLoggingService.logWarning(
            'Failed to cleanup import temp file',
            data: {'fileId': tempFile.fileId},
          );
        }
      }
    }
  }

  /// Securely imports accounts from LastPass CSV export to a specific vault
  static Future<SecureImportResult> importFromLastPass(
    String filePath,
    String targetVaultId, {
    bool requireAuth = true,
  }) async {
    SecureTempFile? tempFile;

    try {
      await SecureLoggingService.logSecurityEvent(
        'import_attempt_started',
        data: {
          'format': 'lastpass',
          'targetVaultId': targetVaultId,
          'filePath': _sanitizeFilePath(filePath),
        },
      );

      // Step 1: Require authentication for import operations
      if (requireAuth) {
        final authResult =
            await EnhancedAuthService.authenticateForSensitiveOperation(
              operation: 'data import',
              customReason: 'Authenticate to import LastPass data',
            );

        if (!authResult.isSuccess) {
          return SecureImportResult.failure(
            'Authentication failed: ${authResult.errorMessage}',
          );
        }
      }

      // Step 2: Create secure temporary file for processing
      tempFile = await SecureTempFileService.createImportTempFile(
        importType: 'lastpass',
      );

      // Step 3: Securely read and validate the source file
      final sourceFile = File(filePath);
      if (!await sourceFile.exists()) {
        throw ImportException('File not found: $filePath');
      }

      final content = await sourceFile.readAsString();

      // Step 4: Validate import data security
      final isSecure = await DataStorageAuditor.validateImportSecurity(content);
      if (!isSecure) {
        return SecureImportResult.failure(
          'Import data contains suspicious content',
        );
      }

      // Step 5: Write content to secure temporary file and process
      await tempFile.writeEncrypted(content);
      final processedContent = await tempFile.readDecrypted();
      final rows = const CsvToListConverter().convert(processedContent);

      if (rows.isEmpty) {
        throw ImportException('CSV file is empty');
      }

      // LastPass CSV format: url,username,password,extra,name,grouping,fav
      final accounts = <Account>[];
      final errors = <String>[];

      for (int i = 1; i < rows.length; i++) {
        try {
          final row = rows[i];
          if (row.length < 5) {
            errors.add(
              'Row ${i + 1}: Insufficient columns (minimum 5 required for LastPass format)',
            );
            continue;
          }

          final account = Account(
            name:
                _sanitizeImportField(row[4]?.toString()) ??
                'Imported Account $i',
            username: _sanitizeImportField(row[1]?.toString()) ?? '',
            password: row[2]?.toString() ?? '',
            url: _sanitizeImportField(row[0]?.toString()),
            notes: _sanitizeImportField(row[3]?.toString()),
            vaultId: targetVaultId,
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
          );

          accounts.add(account);
        } catch (e) {
          errors.add('Row ${i + 1}: ${e.toString()}');
        }
      }

      await SecureLoggingService.logSecurityEvent(
        'import_completed_successfully',
        data: {
          'format': 'lastpass',
          'importedCount': accounts.length,
          'errorCount': errors.length,
        },
      );

      return SecureImportResult.success(
        accounts: accounts,
        importedCount: accounts.length,
        errors: errors,
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'LastPass import failed',
        data: {
          'targetVaultId': targetVaultId,
          'filePath': _sanitizeFilePath(filePath),
        },
        error: e,
      );

      return SecureImportResult.failure('Import failed: ${e.toString()}');
    } finally {
      if (tempFile != null) {
        try {
          await tempFile.delete();
        } catch (e) {
          await SecureLoggingService.logWarning(
            'Failed to cleanup import temp file',
            data: {'fileId': tempFile.fileId},
          );
        }
      }
    }
  }

  /// Detects duplicate accounts based on name and username
  static List<ImportDuplicate> detectDuplicates(
    List<Account> importedAccounts,
    List<Account> existingAccounts,
  ) {
    final duplicates = <ImportDuplicate>[];

    for (final imported in importedAccounts) {
      for (final existing in existingAccounts) {
        if (_accountsMatch(imported, existing)) {
          duplicates.add(
            ImportDuplicate(imported: imported, existing: existing),
          );
          break;
        }
      }
    }

    return duplicates;
  }

  /// Checks if two accounts are considered duplicates
  static bool _accountsMatch(Account a, Account b) {
    return a.name.toLowerCase().trim() == b.name.toLowerCase().trim() &&
        a.username.toLowerCase().trim() == b.username.toLowerCase().trim();
  }

  /// Gets supported import file extensions
  static List<String> getSupportedExtensions() {
    return ['.csv', '.json', '.1pux'];
  }

  /// Gets import format description
  static String getFormatDescription(String extension) {
    switch (extension.toLowerCase()) {
      case '.csv':
        return 'CSV files (Generic, LastPass)';
      case '.json':
        return 'JSON files (Generic, Bitwarden)';
      case '.1pux':
        return '1Password export files';
      default:
        return 'Unknown format';
    }
  }

  // Private helper methods

  /// Sanitizes file paths for logging (removes sensitive information)
  static String _sanitizeFilePath(String filePath) {
    final parts = filePath.split('/');
    if (parts.length > 2) {
      return '.../${parts[parts.length - 2]}/${parts.last}';
    }
    return parts.last;
  }

  /// Sanitizes import field data to prevent injection attacks
  static String? _sanitizeImportField(String? field) {
    if (field == null || field.isEmpty) return field;

    // Remove potentially dangerous characters and patterns
    String sanitized = field
        .replaceAll(
          RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .trim();

    // Limit field length to prevent memory issues
    if (sanitized.length > 1000) {
      sanitized = sanitized.substring(0, 1000);
    }

    return sanitized;
  }
}

/// Legacy import service for backward compatibility
class ImportService {
  /// Legacy method - use SecureImportService.importFromCsv instead
  @Deprecated('Use SecureImportService.importFromCsv for enhanced security')
  static Future<List<Account>> importFromCsv(
    String filePath,
    String targetVaultId, {
    bool hasHeader = true,
    String delimiter = ',',
  }) async {
    final result = await SecureImportService.importFromCsv(
      filePath,
      targetVaultId,
      hasHeader: hasHeader,
      delimiter: delimiter,
      requireAuth: false, // Maintain backward compatibility
    );

    if (result.success) {
      return result.accounts;
    } else {
      throw ImportException(result.errorMessage ?? 'Import failed');
    }
  }

  /// Legacy method - use SecureImportService.importFromJson instead
  @Deprecated('Use SecureImportService.importFromJson for enhanced security')
  static Future<List<Account>> importFromJson(
    String filePath,
    String targetVaultId,
  ) async {
    final result = await SecureImportService.importFromJson(
      filePath,
      targetVaultId,
      requireAuth: false, // Maintain backward compatibility
    );

    if (result.success) {
      return result.accounts;
    } else {
      throw ImportException(result.errorMessage ?? 'Import failed');
    }
  }

  /// Legacy method - use SecureImportService.importFromBitwarden instead
  @Deprecated(
    'Use SecureImportService.importFromBitwarden for enhanced security',
  )
  static Future<List<Account>> importFromBitwarden(
    String filePath,
    String targetVaultId,
  ) async {
    final result = await SecureImportService.importFromBitwarden(
      filePath,
      targetVaultId,
      requireAuth: false, // Maintain backward compatibility
    );

    if (result.success) {
      return result.accounts;
    } else {
      throw ImportException(result.errorMessage ?? 'Import failed');
    }
  }

  /// Legacy method - use SecureImportService.importFromLastPass instead
  @Deprecated(
    'Use SecureImportService.importFromLastPass for enhanced security',
  )
  static Future<List<Account>> importFromLastPass(
    String filePath,
    String targetVaultId,
  ) async {
    final result = await SecureImportService.importFromLastPass(
      filePath,
      targetVaultId,
      requireAuth: false, // Maintain backward compatibility
    );

    if (result.success) {
      return result.accounts;
    } else {
      throw ImportException(result.errorMessage ?? 'Import failed');
    }
  }

  /// Detects duplicate accounts based on name and username
  static List<ImportDuplicate> detectDuplicates(
    List<Account> importedAccounts,
    List<Account> existingAccounts,
  ) {
    return SecureImportService.detectDuplicates(
      importedAccounts,
      existingAccounts,
    );
  }

  /// Gets supported import file extensions
  static List<String> getSupportedExtensions() {
    return SecureImportService.getSupportedExtensions();
  }

  /// Gets import format description
  static String getFormatDescription(String extension) {
    return SecureImportService.getFormatDescription(extension);
  }
}

/// Result of a secure import operation
class SecureImportResult {
  final bool success;
  final List<Account> accounts;
  final int importedCount;
  final List<String> errors;
  final String? errorMessage;
  final DateTime timestamp;

  const SecureImportResult({
    required this.success,
    this.accounts = const [],
    this.importedCount = 0,
    this.errors = const [],
    this.errorMessage,
    required this.timestamp,
  });

  factory SecureImportResult.success({
    required List<Account> accounts,
    required int importedCount,
    List<String> errors = const [],
  }) {
    return SecureImportResult(
      success: true,
      accounts: accounts,
      importedCount: importedCount,
      errors: errors,
      timestamp: DateTime.now(),
    );
  }

  factory SecureImportResult.failure(String errorMessage) {
    return SecureImportResult(
      success: false,
      errorMessage: errorMessage,
      timestamp: DateTime.now(),
    );
  }

  /// Gets a summary of the import operation
  Map<String, dynamic> getSummary() {
    return {
      'success': success,
      'importedCount': importedCount,
      'errorCount': errors.length,
      'hasErrors': errors.isNotEmpty,
      'timestamp': timestamp.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  @override
  String toString() {
    if (success) {
      return 'SecureImportResult(success: $success, imported: $importedCount, errors: ${errors.length})';
    } else {
      return 'SecureImportResult(success: $success, error: $errorMessage)';
    }
  }
}

/// Represents a duplicate account found during import
class ImportDuplicate {
  final Account imported;
  final Account existing;

  ImportDuplicate({required this.imported, required this.existing});

  /// Gets a description of the duplicate
  String getDescription() {
    return 'Duplicate found: "${imported.name}" (${imported.username}) matches existing account';
  }

  /// Gets resolution options for the duplicate
  List<String> getResolutionOptions() {
    return [
      'Skip import (keep existing)',
      'Replace existing with imported',
      'Import as new account',
      'Merge accounts',
    ];
  }
}

/// Exception thrown during import operations
class ImportException implements Exception {
  final String message;
  final String? details;

  const ImportException(this.message, {this.details});

  @override
  String toString() {
    if (details != null) {
      return 'ImportException: $message\nDetails: $details';
    }
    return 'ImportException: $message';
  }
}
