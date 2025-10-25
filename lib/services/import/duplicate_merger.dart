import '../../models/import_result.dart';
import '../../models/account.dart';
import '../../models/totp_config.dart';
import '../../data/db_helper.dart';
import 'duplicate_detector.dart';
import '../../widgets/import/duplicate_resolution_dialog.dart';

/// Service for merging duplicate accounts based on user resolution choices
class DuplicateMerger {
  DuplicateMerger();

  /// Processes duplicate resolutions and applies changes
  Future<DuplicateProcessingResult> processDuplicates(
    List<MergeSuggestion> suggestions,
    Map<String, DuplicateResolution> resolutions,
  ) async {
    final processedAccounts = <Account>[];
    final skippedAccounts = <ImportedAccount>[];
    final errors = <ImportError>[];

    for (final suggestion in suggestions) {
      final resolution = resolutions[suggestion.duplicate.existingAccountId];
      if (resolution == null) continue;

      try {
        final result = await _processSingleDuplicate(suggestion, resolution);
        if (result.processedAccount != null) {
          processedAccounts.add(result.processedAccount!);
        }
        if (result.skippedAccount != null) {
          skippedAccounts.add(result.skippedAccount!);
        }
        if (result.error != null) {
          errors.add(result.error!);
        }
      } catch (e) {
        errors.add(
          ImportError(
            message: 'Failed to process duplicate: ${e.toString()}',
            type: ImportErrorType.parseError,
            context: {
              'existingAccountId': suggestion.duplicate.existingAccountId,
              'importedTitle': suggestion.duplicate.imported.title,
            },
          ),
        );
      }
    }

    return DuplicateProcessingResult(
      processedAccounts: processedAccounts,
      skippedAccounts: skippedAccounts,
      errors: errors,
    );
  }

  /// Processes a single duplicate based on resolution choice
  Future<SingleDuplicateResult> _processSingleDuplicate(
    MergeSuggestion suggestion,
    DuplicateResolution resolution,
  ) async {
    switch (resolution.action) {
      case MergeAction.skip:
        return SingleDuplicateResult(
          skippedAccount: suggestion.duplicate.imported,
        );

      case MergeAction.replace:
        return await _replaceExisting(suggestion);

      case MergeAction.merge:
        return await _mergeAccounts(suggestion, resolution.mergeFields);

      case MergeAction.updatePassword:
        return await _updatePassword(suggestion);

      case MergeAction.askUser:
        // This should have been resolved to a specific action by the UI
        return SingleDuplicateResult(
          error: ImportError(
            message: 'User resolution required but not provided',
            type: ImportErrorType.validationError,
          ),
        );
    }
  }

  /// Replaces existing account with imported data
  Future<SingleDuplicateResult> _replaceExisting(
    MergeSuggestion suggestion,
  ) async {
    final existingId = int.tryParse(suggestion.duplicate.existingAccountId);
    if (existingId == null) {
      return SingleDuplicateResult(
        error: ImportError(
          message: 'Invalid existing account ID',
          type: ImportErrorType.validationError,
        ),
      );
    }

    // Create new account with imported data but keep existing ID
    final updatedAccount = Account(
      id: existingId,
      name: suggestion.duplicate.imported.title,
      username: suggestion.duplicate.imported.username,
      password: suggestion.duplicate.imported.password,
      vaultId: suggestion.existingAccount.vaultId,
      createdAt: suggestion.existingAccount.createdAt,
      modifiedAt: DateTime.now(),
      totpConfig: _convertTOTPData(suggestion.duplicate.imported.totpData),
    );

    await DBHelper.update(updatedAccount);

    return SingleDuplicateResult(processedAccount: updatedAccount);
  }

  /// Merges imported data with existing account based on field choices
  Future<SingleDuplicateResult> _mergeAccounts(
    MergeSuggestion suggestion,
    Map<String, bool> mergeFields,
  ) async {
    final existingId = int.tryParse(suggestion.duplicate.existingAccountId);
    if (existingId == null) {
      return SingleDuplicateResult(
        error: ImportError(
          message: 'Invalid existing account ID',
          type: ImportErrorType.validationError,
        ),
      );
    }

    final existing = suggestion.existingAccount;
    final imported = suggestion.duplicate.imported;

    // Merge fields based on user choices
    final mergedAccount = Account(
      id: existingId,
      name: mergeFields['title'] == true ? imported.title : existing.name,
      username: mergeFields['username'] == true
          ? imported.username
          : existing.username,
      password: mergeFields['password'] == true
          ? imported.password
          : existing.password,
      vaultId: existing.vaultId,
      createdAt: existing.createdAt,
      modifiedAt: DateTime.now(),
      totpConfig: _mergeTOTPConfig(
        existing.totpConfig,
        imported.totpData,
        mergeFields['totp'] == true,
      ),
    );

    await DBHelper.update(mergedAccount);

    return SingleDuplicateResult(processedAccount: mergedAccount);
  }

  /// Updates only the password of existing account
  Future<SingleDuplicateResult> _updatePassword(
    MergeSuggestion suggestion,
  ) async {
    final existingId = int.tryParse(suggestion.duplicate.existingAccountId);
    if (existingId == null) {
      return SingleDuplicateResult(
        error: ImportError(
          message: 'Invalid existing account ID',
          type: ImportErrorType.validationError,
        ),
      );
    }

    final updatedAccount = suggestion.existingAccount.copyWith(
      password: suggestion.duplicate.imported.password,
      modifiedAt: DateTime.now(),
    );

    await DBHelper.update(updatedAccount);

    return SingleDuplicateResult(processedAccount: updatedAccount);
  }

  /// Converts TOTPData to TOTPConfig
  TOTPConfig? _convertTOTPData(TOTPData? totpData) {
    if (totpData == null) return null;

    return TOTPConfig(
      secret: totpData.secret,
      issuer: totpData.issuer ?? '',
      accountName: totpData.accountName ?? '',
      digits: totpData.digits,
      period: totpData.period,
      algorithm: TOTPAlgorithm.fromString(totpData.algorithm),
    );
  }

  /// Merges TOTP configuration based on user choice
  TOTPConfig? _mergeTOTPConfig(
    TOTPConfig? existingTOTP,
    TOTPData? importedTOTP,
    bool useImported,
  ) {
    if (useImported && importedTOTP != null) {
      return _convertTOTPData(importedTOTP);
    }
    return existingTOTP;
  }

  /// Filters out accounts that were processed as duplicates
  List<ImportedAccount> filterProcessedDuplicates(
    List<ImportedAccount> importedAccounts,
    List<MergeSuggestion> suggestions,
    Map<String, DuplicateResolution> resolutions,
  ) {
    final processedImported = <ImportedAccount>{};

    for (final suggestion in suggestions) {
      final resolution = resolutions[suggestion.duplicate.existingAccountId];
      if (resolution != null && resolution.action != MergeAction.skip) {
        processedImported.add(suggestion.duplicate.imported);
      }
    }

    return importedAccounts
        .where((account) => !processedImported.contains(account))
        .toList();
  }
}

/// Result of processing all duplicates
class DuplicateProcessingResult {
  final List<Account> processedAccounts;
  final List<ImportedAccount> skippedAccounts;
  final List<ImportError> errors;

  DuplicateProcessingResult({
    required this.processedAccounts,
    required this.skippedAccounts,
    required this.errors,
  });
}

/// Result of processing a single duplicate
class SingleDuplicateResult {
  final Account? processedAccount;
  final ImportedAccount? skippedAccount;
  final ImportError? error;

  SingleDuplicateResult({
    this.processedAccount,
    this.skippedAccount,
    this.error,
  });
}
