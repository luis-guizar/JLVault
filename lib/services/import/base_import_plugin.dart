import 'dart:io';
import '../../models/import_result.dart';
import 'import_plugin.dart';
import 'field_mapper.dart';

/// Base implementation for import plugins with common functionality
abstract class BaseImportPlugin implements ImportPlugin {
  @override
  String get version => '1.0.0';

  @override
  bool get supportsTOTP => false;

  @override
  bool get supportsCustomFields => false;

  @override
  List<String> get supportedMimeTypes => [];

  @override
  Future<bool> canProcess(File file) async {
    // Check file extension
    final extension = _getFileExtension(file.path);
    if (!supportedExtensions.contains(extension)) {
      return false;
    }

    // Check if file exists and is readable
    if (!await file.exists()) {
      return false;
    }

    try {
      // Try to read first few bytes to validate format
      final bytes = await file.openRead(0, 1024).toList();
      return await validateFileFormat(bytes.expand((x) => x).toList());
    } catch (e) {
      return false;
    }
  }

  @override
  bool validateOptions(ImportOptions options) {
    // Basic validation - can be overridden by specific plugins
    return options.targetVaultId.isNotEmpty;
  }

  @override
  String getSampleFormat() {
    return 'No sample format available';
  }

  /// Validates file format by examining file content
  Future<bool> validateFileFormat(List<int> fileBytes) async {
    // Default implementation - override in specific plugins
    return true;
  }

  /// Processes import with error handling and statistics tracking
  Future<ImportResult> processImport(
    File file,
    ImportOptions options,
    Future<List<ImportedAccount>> Function() importFunction,
  ) async {
    final stopwatch = Stopwatch()..start();
    final errors = <ImportError>[];
    List<ImportedAccount> accounts = [];

    try {
      accounts = await importFunction();
    } catch (e) {
      errors.add(
        ImportError(
          message: 'Failed to parse file: ${e.toString()}',
          type: ImportErrorType.parseError,
        ),
      );
    }

    stopwatch.stop();

    return ImportResult(
      accounts: accounts,
      errors: errors,
      duplicates: [], // Will be handled by ImportServiceV2
      statistics: ImportStatistics(
        totalRecords: accounts.length + errors.length,
        successfulImports: accounts.length,
        errors: errors.length,
        duplicates: 0,
        skipped: 0,
        processingTime: stopwatch.elapsed,
      ),
    );
  }

  /// Creates a safe ImportedAccount with error handling
  ImportedAccount createSafeAccount({
    required String title,
    required String username,
    required String password,
    String? url,
    String? notes,
    List<CustomField>? customFields,
    TOTPData? totpData,
    DateTime? createdAt,
    DateTime? modifiedAt,
    List<String>? tags,
    String? category,
    Map<String, dynamic>? metadata,
  }) {
    return ImportedAccount(
      title: title.trim().isEmpty ? 'Untitled Account' : title.trim(),
      username: username.trim(),
      password: password,
      url: url?.trim().isEmpty == true ? null : url?.trim(),
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      customFields: customFields ?? [],
      totpData: totpData,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      tags: tags ?? [],
      category: category?.trim().isEmpty == true ? null : category?.trim(),
      metadata: metadata ?? {},
    );
  }

  /// Safely extracts string value from map
  String safeGetString(
    Map<String, dynamic> data,
    String key, [
    String defaultValue = '',
  ]) {
    final value = data[key];
    if (value == null) return defaultValue;
    return value.toString().trim();
  }

  /// Safely extracts integer value from map
  int safeGetInt(
    Map<String, dynamic> data,
    String key, [
    int defaultValue = 0,
  ]) {
    final value = data[key];
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Safely extracts boolean value from map
  bool safeGetBool(
    Map<String, dynamic> data,
    String key, [
    bool defaultValue = false,
  ]) {
    final value = data[key];
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1' || lower == 'yes';
    }
    if (value is int) return value != 0;
    return defaultValue;
  }

  /// Safely extracts DateTime value from map
  DateTime? safeGetDateTime(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;

    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Safely extracts list of strings from map
  List<String> safeGetStringList(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return [];

    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (value is String && value.isNotEmpty) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return [];
  }

  /// Gets file extension from path
  String _getFileExtension(String filePath) {
    final lastDot = filePath.lastIndexOf('.');
    if (lastDot == -1) return '';
    return filePath.substring(lastDot).toLowerCase();
  }

  /// Creates import error with context
  ImportError createError({
    int? lineNumber,
    required String message,
    required ImportErrorType type,
    Map<String, dynamic>? context,
  }) {
    return ImportError(
      lineNumber: lineNumber,
      message: message,
      type: type,
      context: context,
    );
  }

  /// Validates required fields in data map
  List<ImportError> validateRequiredFields(
    Map<String, dynamic> data,
    List<String> requiredFields,
    int? lineNumber,
  ) {
    final errors = <ImportError>[];

    for (final field in requiredFields) {
      if (!data.containsKey(field) ||
          data[field] == null ||
          data[field].toString().trim().isEmpty) {
        errors.add(
          createError(
            lineNumber: lineNumber,
            message: 'Required field missing or empty: $field',
            type: ImportErrorType.validationError,
            context: {'field': field, 'data': data},
          ),
        );
      }
    }

    return errors;
  }
}
