import 'dart:io';
import '../../models/import_result.dart';
import '../../models/account.dart';
import '../../models/totp_config.dart';
import '../../data/db_helper.dart';
import 'import_plugin.dart';
import 'import_validator.dart';
import 'plugins/bitwarden_import_plugin.dart';
import 'plugins/lastpass_import_plugin.dart';
import 'plugins/onepassword_import_plugin.dart';
import 'plugins/chrome_import_plugin.dart';
import 'plugins/firefox_import_plugin.dart';
import 'plugins/safari_import_plugin.dart';
import '../vault_manager.dart';

/// Enhanced import service using plugin architecture
class ImportServiceV2 {
  final ImportPluginRegistry _registry = ImportPluginRegistry();
  final VaultManager
  _vaultManager; // Keep for future vault operations like statistics updates

  ImportServiceV2(this._vaultManager);

  /// Gets all available import plugins
  List<ImportPlugin> getAvailablePlugins() {
    return _registry.getAllPlugins();
  }

  /// Gets plugins that support specific file extension
  List<ImportPlugin> getPluginsByExtension(String extension) {
    return _registry.getPluginsByExtension(extension);
  }

  /// Finds compatible plugins for a file
  Future<List<ImportPlugin>> findCompatiblePlugins(File file) async {
    return await _registry.findCompatiblePlugins(file);
  }

  /// Imports data using specified plugin
  Future<ImportResult> importWithPlugin(
    String pluginId,
    File file,
    ImportOptions options,
  ) async {
    final plugin = _registry.getPlugin(pluginId);
    if (plugin == null) {
      throw ImportPluginException('Plugin not found: $pluginId');
    }

    // Validate options
    final optionErrors = ImportValidator.validateImportOptions(options);
    if (optionErrors.isNotEmpty) {
      return ImportResult(
        accounts: [],
        errors: optionErrors,
        duplicates: [],
        statistics: ImportStatistics(
          totalRecords: 0,
          successfulImports: 0,
          errors: optionErrors.length,
          duplicates: 0,
          skipped: 0,
          processingTime: Duration.zero,
        ),
      );
    }

    // Validate plugin can process file
    if (!await plugin.canProcess(file)) {
      throw ImportPluginException(
        'Plugin cannot process this file',
        pluginId: pluginId,
      );
    }

    final stopwatch = Stopwatch()..start();

    try {
      // Import using plugin
      final result = await plugin.import(file, options);

      // Validate imported accounts
      final validatedResult = await _validateAndSanitizeResult(result);

      // Detect duplicates if not skipping
      final finalResult = await _processDuplicates(validatedResult, options);

      stopwatch.stop();

      // Update statistics with processing time
      final updatedStats = ImportStatistics(
        totalRecords: finalResult.statistics.totalRecords,
        successfulImports: finalResult.statistics.successfulImports,
        errors: finalResult.statistics.errors,
        duplicates: finalResult.statistics.duplicates,
        skipped: finalResult.statistics.skipped,
        processingTime: stopwatch.elapsed,
      );

      return ImportResult(
        accounts: finalResult.accounts,
        errors: finalResult.errors,
        duplicates: finalResult.duplicates,
        statistics: updatedStats,
      );
    } catch (e) {
      stopwatch.stop();
      throw ImportPluginException(
        'Import failed: ${e.toString()}',
        pluginId: pluginId,
        originalError: e,
      );
    }
  }

  /// Auto-detects and imports using best matching plugin
  Future<ImportResult> autoImport(File file, ImportOptions options) async {
    final compatiblePlugins = await findCompatiblePlugins(file);

    if (compatiblePlugins.isEmpty) {
      throw ImportPluginException('No compatible plugins found for this file');
    }

    // Use the first compatible plugin
    // In the future, this could be enhanced with plugin priority/scoring
    final plugin = compatiblePlugins.first;
    return await importWithPlugin(plugin.pluginId, file, options);
  }

  /// Converts ImportedAccount to Account model
  Account convertToAccount(ImportedAccount imported, String vaultId) {
    return Account(
      name: imported.title,
      username: imported.username,
      password: imported.password,
      vaultId: vaultId,
      createdAt: imported.createdAt ?? DateTime.now(),
      modifiedAt: imported.modifiedAt ?? DateTime.now(),
      totpConfig: imported.totpData != null
          ? _convertTOTPData(imported.totpData!)
          : null,
    );
  }

  /// Saves imported accounts to vault
  Future<void> saveImportedAccounts(
    List<ImportedAccount> accounts,
    String vaultId,
  ) async {
    for (final imported in accounts) {
      final account = convertToAccount(imported, vaultId);
      await DBHelper.insert(account);
    }
  }

  /// Validates and sanitizes import result
  Future<ImportResult> _validateAndSanitizeResult(ImportResult result) async {
    final validatedAccounts = <ImportedAccount>[];
    final allErrors = List<ImportError>.from(result.errors);

    for (int i = 0; i < result.accounts.length; i++) {
      final account = result.accounts[i];

      // Validate account
      final validationErrors = ImportValidator.validateAccount(account, i + 1);
      allErrors.addAll(validationErrors);

      // Sanitize account if no critical errors
      if (validationErrors.isEmpty) {
        final sanitized = ImportValidator.sanitizeAccount(account);
        validatedAccounts.add(sanitized);
      }
    }

    return ImportResult(
      accounts: validatedAccounts,
      errors: allErrors,
      duplicates: result.duplicates,
      statistics: ImportStatistics(
        totalRecords: result.statistics.totalRecords,
        successfulImports: validatedAccounts.length,
        errors: allErrors.length,
        duplicates: result.statistics.duplicates,
        skipped: result.statistics.totalRecords - validatedAccounts.length,
        processingTime: result.statistics.processingTime,
      ),
    );
  }

  /// Processes duplicates based on options
  Future<ImportResult> _processDuplicates(
    ImportResult result,
    ImportOptions options,
  ) async {
    if (options.skipDuplicates || result.accounts.isEmpty) {
      return result;
    }

    // Get existing accounts from target vault
    final existingAccounts = await DBHelper.getAllForVault(
      options.targetVaultId,
    );

    // Detect duplicates
    final duplicates = await _detectDuplicates(
      result.accounts,
      existingAccounts,
    );

    // Filter out duplicates if skipDuplicates is true
    final filteredAccounts = options.skipDuplicates
        ? result.accounts
              .where(
                (account) => !duplicates.any((dup) => dup.imported == account),
              )
              .toList()
        : result.accounts;

    return ImportResult(
      accounts: filteredAccounts,
      errors: result.errors,
      duplicates: duplicates,
      statistics: ImportStatistics(
        totalRecords: result.statistics.totalRecords,
        successfulImports: filteredAccounts.length,
        errors: result.statistics.errors,
        duplicates: duplicates.length,
        skipped: result.statistics.totalRecords - filteredAccounts.length,
        processingTime: result.statistics.processingTime,
      ),
    );
  }

  /// Detects duplicate accounts
  Future<List<ImportDuplicate>> _detectDuplicates(
    List<ImportedAccount> importedAccounts,
    List<Account> existingAccounts,
  ) async {
    final duplicates = <ImportDuplicate>[];

    for (final imported in importedAccounts) {
      for (final existing in existingAccounts) {
        final duplicate = _checkForDuplicate(imported, existing);
        if (duplicate != null) {
          duplicates.add(duplicate);
          break; // Only match with first duplicate found
        }
      }
    }

    return duplicates;
  }

  /// Checks if imported account is duplicate of existing account
  ImportDuplicate? _checkForDuplicate(
    ImportedAccount imported,
    Account existing,
  ) {
    // Exact match (title, username, password)
    if (imported.title.toLowerCase().trim() ==
            existing.name.toLowerCase().trim() &&
        imported.username.toLowerCase().trim() ==
            existing.username.toLowerCase().trim() &&
        imported.password == existing.password) {
      return ImportDuplicate(
        imported: imported,
        existingAccountId: existing.id.toString(),
        matchType: DuplicateMatchType.exact,
        confidence: 1.0,
      );
    }

    // Title and username match
    if (imported.title.toLowerCase().trim() ==
            existing.name.toLowerCase().trim() &&
        imported.username.toLowerCase().trim() ==
            existing.username.toLowerCase().trim()) {
      return ImportDuplicate(
        imported: imported,
        existingAccountId: existing.id.toString(),
        matchType: DuplicateMatchType.titleAndUsername,
        confidence: 0.9,
      );
    }

    // Title only match (high confidence)
    if (imported.title.toLowerCase().trim() ==
            existing.name.toLowerCase().trim() &&
        imported.title.trim().isNotEmpty) {
      return ImportDuplicate(
        imported: imported,
        existingAccountId: existing.id.toString(),
        matchType: DuplicateMatchType.titleOnly,
        confidence: 0.7,
      );
    }

    // Username and URL match
    if (imported.username.toLowerCase().trim() ==
            existing.username.toLowerCase().trim() &&
        imported.url != null &&
        imported.url!.isNotEmpty &&
        imported.url!.toLowerCase().contains(existing.name.toLowerCase())) {
      return ImportDuplicate(
        imported: imported,
        existingAccountId: existing.id.toString(),
        matchType: DuplicateMatchType.usernameAndUrl,
        confidence: 0.8,
      );
    }

    return null;
  }

  /// Converts TOTPData to TOTPConfig
  TOTPConfig _convertTOTPData(TOTPData totpData) {
    return TOTPConfig(
      secret: totpData.secret,
      issuer: totpData.issuer ?? '',
      accountName: totpData.accountName ?? '',
      digits: totpData.digits,
      period: totpData.period,
      algorithm: TOTPAlgorithm.fromString(totpData.algorithm),
    );
  }

  /// Registers default plugins
  void registerDefaultPlugins() {
    // Register all available import plugins
    _registry.register(BitwardenImportPlugin());
    _registry.register(LastPassImportPlugin());
    _registry.register(OnePasswordImportPlugin());
    _registry.register(ChromeImportPlugin());
    _registry.register(FirefoxImportPlugin());
    _registry.register(SafariImportPlugin());
  }
}
