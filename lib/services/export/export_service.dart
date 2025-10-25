import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:archive/archive.dart';
import '../../models/export_result.dart';
import '../../models/account.dart';
import '../../models/vault_metadata.dart';
import '../../data/db_helper.dart';
import '../vault_manager.dart';
import '../vault_crypto_manager.dart';
import 'export_formatters/export_formatter.dart';
import 'export_formatters/json_export_formatter.dart';
import 'export_formatters/csv_export_formatter.dart';
import 'export_formatters/bitwarden_export_formatter.dart';
import 'export_formatters/lastpass_export_formatter.dart';
import 'export_formatters/encrypted_export_formatter.dart';

/// Service for exporting password data to various formats
class ExportService {
  final VaultManager _vaultManager;
  final VaultCryptoManager _cryptoManager;
  final Map<ExportFormat, ExportFormatter> _formatters = {};

  ExportService(this._vaultManager, this._cryptoManager) {
    _initializeFormatters();
  }

  /// Initializes export formatters for different formats
  void _initializeFormatters() {
    _formatters[ExportFormat.json] = JsonExportFormatter();
    _formatters[ExportFormat.csv] = CsvExportFormatter();
    _formatters[ExportFormat.bitwarden] = BitwardenExportFormatter();
    _formatters[ExportFormat.lastpass] = LastPassExportFormatter();
    _formatters[ExportFormat.simpleVaultEncrypted] = EncryptedExportFormatter();
  }

  /// Exports data based on the provided options
  Future<ExportResult> export(
    String outputPath,
    ExportOptions options, {
    ExportFilter? filter,
  }) async {
    final stopwatch = Stopwatch()..start();
    final errors = <ExportError>[];

    try {
      // Validate options
      final validationErrors = _validateOptions(options);
      if (validationErrors.isNotEmpty) {
        return ExportResult(
          filePath: '',
          statistics: ExportStatistics(
            totalAccounts: 0,
            exportedAccounts: 0,
            skippedAccounts: 0,
            vaultsExported: 0,
            categoriesExported: 0,
            processingTime: stopwatch.elapsed,
            fileSizeBytes: 0,
          ),
          errors: validationErrors,
          metadata: _createMetadata(options, false, ''),
        );
      }

      // Collect accounts to export
      final accountsToExport = await _collectAccounts(options, filter);

      if (accountsToExport.isEmpty) {
        errors.add(
          ExportError(
            message: 'No accounts found matching export criteria',
            type: ExportErrorType.validationError,
          ),
        );
      }

      // Get formatter for the specified format
      final formatter = _formatters[options.format];
      if (formatter == null) {
        errors.add(
          ExportError(
            message: 'Unsupported export format: ${options.format}',
            type: ExportErrorType.formatError,
          ),
        );

        return ExportResult(
          filePath: '',
          statistics: ExportStatistics(
            totalAccounts: accountsToExport.length,
            exportedAccounts: 0,
            skippedAccounts: accountsToExport.length,
            vaultsExported: 0,
            categoriesExported: 0,
            processingTime: stopwatch.elapsed,
            fileSizeBytes: 0,
          ),
          errors: errors,
          metadata: _createMetadata(options, false, ''),
        );
      }

      // Format the data
      final formattedData = await formatter.format(accountsToExport, options);

      // Write to file
      final finalPath = await _writeToFile(outputPath, formattedData, options);

      // Calculate file size and checksum
      final file = File(finalPath);
      final fileSize = await file.length();
      final checksum = await _calculateChecksum(file);

      stopwatch.stop();

      // Create statistics
      final vaultIds = accountsToExport.map((a) => a.vaultId).toSet();
      final categories = accountsToExport
          .where((a) => a.category != null)
          .map((a) => a.category!)
          .toSet();

      return ExportResult(
        filePath: finalPath,
        statistics: ExportStatistics(
          totalAccounts: accountsToExport.length,
          exportedAccounts: accountsToExport.length,
          skippedAccounts: 0,
          vaultsExported: vaultIds.length,
          categoriesExported: categories.length,
          processingTime: stopwatch.elapsed,
          fileSizeBytes: fileSize,
        ),
        errors: errors,
        metadata: _createMetadata(options, options.password != null, checksum),
      );
    } catch (e) {
      stopwatch.stop();
      errors.add(
        ExportError(
          message: 'Export failed: ${e.toString()}',
          type: ExportErrorType.fileSystemError,
        ),
      );

      return ExportResult(
        filePath: '',
        statistics: ExportStatistics(
          totalAccounts: 0,
          exportedAccounts: 0,
          skippedAccounts: 0,
          vaultsExported: 0,
          categoriesExported: 0,
          processingTime: stopwatch.elapsed,
          fileSizeBytes: 0,
        ),
        errors: errors,
        metadata: _createMetadata(options, false, ''),
      );
    }
  }

  /// Validates export options
  List<ExportError> _validateOptions(ExportOptions options) {
    final errors = <ExportError>[];

    // Validate vault IDs
    if (options.vaultIds.isEmpty) {
      errors.add(
        ExportError(
          message: 'At least one vault must be selected for export',
          type: ExportErrorType.validationError,
        ),
      );
    }

    // Validate password for encrypted formats
    if (options.format == ExportFormat.simpleVaultEncrypted &&
        (options.password == null || options.password!.isEmpty)) {
      errors.add(
        ExportError(
          message: 'Password is required for encrypted export',
          type: ExportErrorType.validationError,
        ),
      );
    }

    // Validate password strength for encrypted exports
    if (options.password != null && options.password!.length < 8) {
      errors.add(
        ExportError(
          message: 'Export password must be at least 8 characters long',
          type: ExportErrorType.validationError,
        ),
      );
    }

    return errors;
  }

  /// Collects accounts to export based on options and filter
  Future<List<ExportedAccount>> _collectAccounts(
    ExportOptions options,
    ExportFilter? filter,
  ) async {
    final allAccounts = <ExportedAccount>[];

    // Get vault metadata for names
    final vaultMetadata = <String, VaultMetadata>{};
    for (final vaultId in options.vaultIds) {
      try {
        final metadata = await _vaultManager.getVaultById(vaultId);
        if (metadata != null) {
          vaultMetadata[vaultId] = metadata;
        }
      } catch (e) {
        // Continue with other vaults if one fails
        continue;
      }
    }

    // Collect accounts from each vault
    for (final vaultId in options.vaultIds) {
      try {
        final accounts = await DBHelper.getAllForVault(vaultId);
        final vaultName = vaultMetadata[vaultId]?.name ?? 'Unknown Vault';

        for (final account in accounts) {
          final exportedAccount = _convertToExportedAccount(account, vaultName);

          // Apply filter if provided
          if (filter == null || filter.shouldIncludeAccount(exportedAccount)) {
            allAccounts.add(exportedAccount);
          }
        }
      } catch (e) {
        // Continue with other vaults if one fails
        continue;
      }
    }

    return allAccounts;
  }

  /// Converts Account to ExportedAccount
  ExportedAccount _convertToExportedAccount(Account account, String vaultName) {
    return ExportedAccount(
      id: account.id?.toString() ?? '',
      title: account.name,
      username: account.username,
      password: account.password,
      vaultId: account.vaultId,
      vaultName: vaultName,
      createdAt: account.createdAt,
      modifiedAt: account.modifiedAt,
      totpData: account.totpConfig != null
          ? ExportedTOTPData(
              secret: account.totpConfig!.secret,
              issuer: account.totpConfig!.issuer,
              accountName: account.totpConfig!.accountName,
              digits: account.totpConfig!.digits,
              period: account.totpConfig!.period,
              algorithm: account.totpConfig!.algorithm.name,
            )
          : null,
    );
  }

  /// Writes formatted data to file
  Future<String> _writeToFile(
    String outputPath,
    dynamic formattedData,
    ExportOptions options,
  ) async {
    final file = File(outputPath);

    // Ensure directory exists
    await file.parent.create(recursive: true);

    if (formattedData is String) {
      // Text data
      await file.writeAsString(formattedData, encoding: utf8);
    } else if (formattedData is Uint8List) {
      // Binary data
      await file.writeAsBytes(formattedData);
    } else {
      throw ArgumentError('Unsupported data type for file writing');
    }

    // Compress if requested
    if (options.compressOutput) {
      return await _compressFile(file);
    }

    return file.path;
  }

  /// Compresses a file using gzip
  Future<String> _compressFile(File file) async {
    final data = await file.readAsBytes();
    final compressed = GZipEncoder().encode(data);

    final compressedPath = '${file.path}.gz';
    final compressedFile = File(compressedPath);
    await compressedFile.writeAsBytes(compressed);

    // Remove original file
    await file.delete();

    return compressedPath;
  }

  /// Calculates SHA-256 checksum of a file
  Future<String> _calculateChecksum(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Creates export metadata
  ExportMetadata _createMetadata(
    ExportOptions options,
    bool isEncrypted,
    String checksum,
  ) {
    return ExportMetadata(
      exportedAt: DateTime.now(),
      exportedBy: 'Simple Vault',
      appVersion: '1.0.0', // This should come from app configuration
      format: options.format,
      isEncrypted: isEncrypted,
      checksum: checksum,
      additionalData: {
        'includePasswords': options.includePasswords,
        'includeTOTP': options.includeTOTP,
        'includeCustomFields': options.includeCustomFields,
        'includeMetadata': options.includeMetadata,
        'compressOutput': options.compressOutput,
        'vaultCount': options.vaultIds.length,
        'categoryCount': options.categories.length,
      },
    );
  }

  /// Gets supported export formats
  List<ExportFormat> getSupportedFormats() {
    return _formatters.keys.toList();
  }

  /// Gets file extension for export format
  String getFileExtension(ExportFormat format) {
    switch (format) {
      case ExportFormat.json:
      case ExportFormat.bitwarden:
        return '.json';
      case ExportFormat.csv:
      case ExportFormat.lastpass:
        return '.csv';
      case ExportFormat.simpleVaultEncrypted:
        return '.svault';
      case ExportFormat.onepassword:
        return '.1pux';
    }
  }

  /// Gets format description
  String getFormatDescription(ExportFormat format) {
    switch (format) {
      case ExportFormat.json:
        return 'JSON format (unencrypted)';
      case ExportFormat.csv:
        return 'CSV format (unencrypted)';
      case ExportFormat.bitwarden:
        return 'Bitwarden JSON format';
      case ExportFormat.lastpass:
        return 'LastPass CSV format';
      case ExportFormat.simpleVaultEncrypted:
        return 'Simple Vault encrypted backup';
      case ExportFormat.onepassword:
        return '1Password 1PUX format';
    }
  }

  /// Validates export integrity
  Future<bool> validateExportIntegrity(
    String filePath,
    String expectedChecksum,
  ) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final actualChecksum = await _calculateChecksum(file);
      return actualChecksum == expectedChecksum;
    } catch (e) {
      return false;
    }
  }
}
