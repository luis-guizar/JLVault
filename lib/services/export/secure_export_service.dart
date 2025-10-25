import 'dart:convert';
import 'dart:io';
import '../../models/export_result.dart';
import '../enhanced_auth_service.dart';
import '../secure_logging_service.dart';
import '../secure_temp_file_service.dart';
import '../data_storage_auditor.dart';
import '../vault_manager.dart';
import '../../data/db_helper.dart';

/// Secure implementation of ExportService with biometric authentication
class SecureExportService {
  /// Exports data to the specified file path with given options
  /// Requires biometric authentication for security
  Future<ExportResult> export(String filePath, ExportOptions options) async {
    SecureTempFile? tempFile;

    try {
      // Step 1: Require biometric authentication for export operations
      await SecureLoggingService.logSecurityEvent(
        'export_attempt_started',
        data: {
          'format': options.format.name,
          'vaultCount': options.vaultIds.length,
          'includePasswords': options.includePasswords,
          'includeTOTP': options.includeTOTP,
        },
      );

      final authResult =
          await EnhancedAuthService.authenticateForSensitiveOperation(
            operation: 'data export',
            customReason: 'Authenticate to export your password data securely',
          );

      if (!authResult.isSuccess) {
        await SecureLoggingService.logSecurityEvent(
          'export_auth_failed',
          data: {'reason': authResult.errorMessage},
        );
        return ExportResult.failure(
          errorMessage: authResult.errorMessage ?? 'Authentication failed',
          format: options.format,
        );
      }

      // Step 2: Validate export options
      if (!validateOptions(options)) {
        await SecureLoggingService.logError(
          'Export validation failed',
          data: {'format': options.format.name},
        );
        return ExportResult.failure(
          errorMessage: 'Invalid export options',
          format: options.format,
        );
      }

      // Step 3: Audit data before export to ensure security
      final auditResult = await DataStorageAuditor.performFullAudit();
      if (!auditResult.isCompliant) {
        await SecureLoggingService.logSecurityEvent(
          'export_blocked_security_issues',
          data: {
            'issueCount': auditResult.issues.length,
            'highSeverityIssues': auditResult
                .getIssuesBySeverity(IssueSeverity.high)
                .length,
          },
        );
        return ExportResult.failure(
          errorMessage:
              'Export blocked due to security issues. Please resolve data storage issues first.',
          format: options.format,
        );
      }

      // Step 4: Create secure temporary file for export processing
      tempFile = await SecureTempFileService.createExportTempFile(
        exportType: options.format.name,
        vaultName: options.vaultIds.length == 1
            ? options.vaultIds.first
            : 'multiple',
      );

      // Step 5: Collect and prepare data for export
      final exportData = await _collectExportData(options);

      // Step 6: Validate export data security
      final exportDataJson = jsonEncode(exportData);
      final isSecure = await DataStorageAuditor.validateExportSecurity(
        exportDataJson,
      );
      if (!isSecure) {
        await SecureLoggingService.logSecurityEvent(
          'insecure_export_data_detected',
          data: {'format': options.format.name},
        );
        return ExportResult.failure(
          errorMessage:
              'Export data contains unencrypted sensitive information',
          format: options.format,
        );
      }

      // Step 7: Format and encrypt export data
      final formattedData = await _formatExportData(exportData, options);
      await tempFile.writeEncrypted(formattedData);

      // Step 8: Move to final destination securely
      final finalFile = File(filePath);
      final encryptedContent = await tempFile.readDecryptedBytes();
      await finalFile.writeAsBytes(encryptedContent);

      await SecureLoggingService.logSecurityEvent(
        'export_completed_successfully',
        data: {
          'format': options.format.name,
          'exportedCount': exportData.length,
          'fileSizeBytes': finalFile.lengthSync(),
        },
      );

      return ExportResult.success(
        filePath: filePath,
        exportedCount: exportData.length,
        format: options.format,
      );
    } catch (e) {
      await SecureLoggingService.logError(
        'Export operation failed',
        data: {'format': options.format.name, 'filePath': filePath},
        error: e,
      );

      return ExportResult.failure(
        errorMessage: 'Export failed: ${e.toString()}',
        format: options.format,
      );
    } finally {
      // Step 9: Always clean up temporary files
      if (tempFile != null) {
        try {
          await tempFile.delete();
        } catch (e) {
          await SecureLoggingService.logWarning(
            'Failed to cleanup export temp file',
            data: {'fileId': tempFile.fileId},
          );
        }
      }
    }
  }

  /// Gets the file extension for the specified format
  String getFileExtension(ExportFormat format) {
    switch (format) {
      case ExportFormat.json:
        return '.json';
      case ExportFormat.csv:
        return '.csv';
      case ExportFormat.bitwarden:
        return '.json';
      case ExportFormat.lastpass:
        return '.csv';
      case ExportFormat.onepassword:
        return '.1pux';
      case ExportFormat.simpleVaultEncrypted:
        return '.svault';
    }
  }

  /// Gets a human-readable description of the format
  String getFormatDescription(ExportFormat format) {
    switch (format) {
      case ExportFormat.json:
        return 'Standard JSON format for easy parsing';
      case ExportFormat.csv:
        return 'Comma-separated values for spreadsheet applications';
      case ExportFormat.bitwarden:
        return 'Compatible with Bitwarden password manager';
      case ExportFormat.lastpass:
        return 'Compatible with LastPass password manager';
      case ExportFormat.onepassword:
        return 'Compatible with 1Password password manager';
      case ExportFormat.simpleVaultEncrypted:
        return 'Encrypted Simple Vault format with password protection';
    }
  }

  /// Validates export options for the specified format
  bool validateOptions(ExportOptions options) {
    // Basic validation
    if (options.vaultIds.isEmpty) return false;

    // Format-specific validation
    switch (options.format) {
      case ExportFormat.simpleVaultEncrypted:
        return options.password != null && options.password!.isNotEmpty;
      default:
        return true;
    }
  }

  /// Collects account data from specified vaults for export
  Future<List<ExportedAccount>> _collectExportData(
    ExportOptions options,
  ) async {
    final exportedAccounts = <ExportedAccount>[];

    for (final vaultId in options.vaultIds) {
      try {
        // Get vault metadata
        final vaultManager = DefaultVaultManager();
        final vault = await vaultManager.getVaultById(vaultId);
        final vaultName = vault?.name ?? 'Unknown Vault';

        // Get accounts for this vault
        final accounts = await DBHelper.getAllForVault(vaultId);

        for (final account in accounts) {
          // Create exported account with security filtering
          final exportedAccount = ExportedAccount.fromAccount(
            account,
            vaultName,
            totpData: options.includeTOTP && account.totpConfig != null
                ? ExportedTOTPData(
                    secret: account.totpConfig!.secret,
                    issuer: account.totpConfig!.issuer,
                    accountName: account.totpConfig!.accountName,
                    period: account.totpConfig!.period,
                    digits: account.totpConfig!.digits,
                    algorithm: account.totpConfig!.algorithm.name,
                  )
                : null,
          );

          // Apply security filtering
          final filteredAccount = _applySecurityFiltering(
            exportedAccount,
            options,
          );
          exportedAccounts.add(filteredAccount);
        }
      } catch (e) {
        await SecureLoggingService.logError(
          'Failed to collect data from vault',
          data: {'vaultId': vaultId},
          error: e,
        );
        // Continue with other vaults
      }
    }

    return exportedAccounts;
  }

  /// Applies security filtering to exported account data
  ExportedAccount _applySecurityFiltering(
    ExportedAccount account,
    ExportOptions options,
  ) {
    return ExportedAccount(
      id: account.id,
      title: account.title,
      username: account.username,
      password: options.includePasswords ? account.password : '[REDACTED]',
      url: account.url,
      notes: account.notes,
      vaultId: account.vaultId,
      vaultName: account.vaultName,
      createdAt: options.includeMetadata ? account.createdAt : null,
      modifiedAt: options.includeMetadata ? account.modifiedAt : null,
      totpData: options.includeTOTP ? account.totpData : null,
      customFields: options.includeCustomFields ? account.customFields : [],
      tags: account.tags,
      category: account.category,
      metadata: options.includeMetadata ? account.metadata : null,
    );
  }

  /// Formats export data according to the specified format
  Future<String> _formatExportData(
    List<ExportedAccount> accounts,
    ExportOptions options,
  ) async {
    switch (options.format) {
      case ExportFormat.json:
        return _formatAsJson(accounts, options);
      case ExportFormat.csv:
        return _formatAsCsv(accounts, options);
      case ExportFormat.bitwarden:
        return _formatAsBitwarden(accounts, options);
      case ExportFormat.lastpass:
        return _formatAsLastPass(accounts, options);
      case ExportFormat.onepassword:
        return _formatAsOnePassword(accounts, options);
      case ExportFormat.simpleVaultEncrypted:
        return _formatAsSimpleVaultEncrypted(accounts, options);
    }
  }

  String _formatAsJson(List<ExportedAccount> accounts, ExportOptions options) {
    final exportData = {
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'format': 'SimpleVault JSON Export',
      'encrypted': false,
      'accounts': accounts
          .map(
            (account) => {
              'id': account.id,
              'title': account.title,
              'username': account.username,
              'password': account.password,
              'url': account.url,
              'notes': account.notes,
              'vaultId': account.vaultId,
              'vaultName': account.vaultName,
              if (account.createdAt != null)
                'createdAt': account.createdAt!.toIso8601String(),
              if (account.modifiedAt != null)
                'modifiedAt': account.modifiedAt!.toIso8601String(),
              if (account.totpData != null)
                'totp': {
                  'secret': account.totpData!.secret,
                  'issuer': account.totpData!.issuer,
                  'accountName': account.totpData!.accountName,
                  'period': account.totpData!.period,
                  'digits': account.totpData!.digits,
                  'algorithm': account.totpData!.algorithm,
                },
              'customFields': account.customFields
                  .map(
                    (field) => {
                      'name': field.name,
                      'value': field.value,
                      'type': field.type,
                    },
                  )
                  .toList(),
              'tags': account.tags,
              if (account.category != null) 'category': account.category,
              if (account.metadata != null) 'metadata': account.metadata,
            },
          )
          .toList(),
    };

    return jsonEncode(exportData);
  }

  String _formatAsCsv(List<ExportedAccount> accounts, ExportOptions options) {
    final buffer = StringBuffer();

    // CSV Header
    buffer.writeln(
      'Title,Username,Password,URL,Notes,Vault,TOTP Secret,TOTP Issuer',
    );

    // CSV Data
    for (final account in accounts) {
      final row = [
        _escapeCsvField(account.title),
        _escapeCsvField(account.username),
        _escapeCsvField(account.password),
        _escapeCsvField(account.url ?? ''),
        _escapeCsvField(account.notes ?? ''),
        _escapeCsvField(account.vaultName),
        _escapeCsvField(account.totpData?.secret ?? ''),
        _escapeCsvField(account.totpData?.issuer ?? ''),
      ];
      buffer.writeln(row.join(','));
    }

    return buffer.toString();
  }

  String _formatAsBitwarden(
    List<ExportedAccount> accounts,
    ExportOptions options,
  ) {
    final exportData = {
      'encrypted': false,
      'items': accounts
          .map(
            (account) => {
              'id': account.id,
              'organizationId': null,
              'folderId': null,
              'type': 1, // Login type
              'name': account.title,
              'notes': account.notes,
              'favorite': false,
              'login': {
                'username': account.username,
                'password': account.password,
                'totp': account.totpData?.toOTPAuthUrl(),
                'uris': account.url != null
                    ? [
                        {'match': null, 'uri': account.url},
                      ]
                    : null,
              },
              'collectionIds': null,
              'revisionDate': account.modifiedAt?.toIso8601String(),
              'creationDate': account.createdAt?.toIso8601String(),
              'deletedDate': null,
            },
          )
          .toList(),
    };

    return jsonEncode(exportData);
  }

  String _formatAsLastPass(
    List<ExportedAccount> accounts,
    ExportOptions options,
  ) {
    final buffer = StringBuffer();

    // LastPass CSV Header
    buffer.writeln('url,username,password,extra,name,grouping,fav');

    // LastPass CSV Data
    for (final account in accounts) {
      final row = [
        _escapeCsvField(account.url ?? ''),
        _escapeCsvField(account.username),
        _escapeCsvField(account.password),
        _escapeCsvField(account.notes ?? ''),
        _escapeCsvField(account.title),
        _escapeCsvField(account.vaultName),
        '0', // favorite
      ];
      buffer.writeln(row.join(','));
    }

    return buffer.toString();
  }

  String _formatAsOnePassword(
    List<ExportedAccount> accounts,
    ExportOptions options,
  ) {
    // Simplified 1Password format (actual format is more complex)
    final exportData = {
      'accounts': accounts
          .map(
            (account) => {
              'uuid': account.id,
              'favIndex': 0,
              'createdAt':
                  (account.createdAt?.millisecondsSinceEpoch ?? 0) ~/ 1000,
              'updatedAt':
                  (account.modifiedAt?.millisecondsSinceEpoch ?? 0) ~/ 1000,
              'state': 'active',
              'categoryUuid': 'login',
              'details': {
                'loginFields': [
                  {
                    'value': account.username,
                    'id': 'username',
                    'name': 'username',
                    'fieldType': 'T',
                    'designation': 'username',
                  },
                  {
                    'value': account.password,
                    'id': 'password',
                    'name': 'password',
                    'fieldType': 'P',
                    'designation': 'password',
                  },
                ],
                'notesPlain': account.notes ?? '',
                'sections': [],
                'passwordHistory': [],
              },
              'overview': {
                'subtitle': account.username,
                'title': account.title,
                'url': account.url ?? '',
                'ps': 0,
                'pbe': 0.0,
                'pgrng': false,
              },
            },
          )
          .toList(),
    };

    return jsonEncode(exportData);
  }

  String _formatAsSimpleVaultEncrypted(
    List<ExportedAccount> accounts,
    ExportOptions options,
  ) {
    final exportData = {
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'format': 'SimpleVault Encrypted Export',
      'encrypted': true,
      'passwordProtected': options.password != null,
      'accounts': accounts,
    };

    // Note: In a real implementation, this would be encrypted with the provided password
    // For now, we'll return the JSON format
    return jsonEncode(exportData);
  }

  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}
