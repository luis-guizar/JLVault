/// Models for import/export system results and metadata

/// Result of an import operation
class ImportResult {
  final List<ImportedAccount> accounts;
  final List<ImportError> errors;
  final List<ImportDuplicate> duplicates;
  final ImportStatistics statistics;

  ImportResult({
    required this.accounts,
    required this.errors,
    required this.duplicates,
    required this.statistics,
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get hasDuplicates => duplicates.isNotEmpty;
  bool get isSuccessful => accounts.isNotEmpty && !hasErrors;
}

/// An account imported from external source
class ImportedAccount {
  final String title;
  final String username;
  final String password;
  final String? url;
  final String? notes;
  final List<CustomField> customFields;
  final TOTPData? totpData;
  final DateTime? createdAt;
  final DateTime? modifiedAt;
  final List<String> tags;
  final String? category;
  final Map<String, dynamic> metadata;

  ImportedAccount({
    required this.title,
    required this.username,
    required this.password,
    this.url,
    this.notes,
    this.customFields = const [],
    this.totpData,
    this.createdAt,
    this.modifiedAt,
    this.tags = const [],
    this.category,
    this.metadata = const {},
  });
}

/// Custom field data from import
class CustomField {
  final String name;
  final String value;
  final CustomFieldType type;

  CustomField({required this.name, required this.value, required this.type});
}

enum CustomFieldType { text, password, email, url, number, date }

/// TOTP data from import
class TOTPData {
  final String secret;
  final String? issuer;
  final String? accountName;
  final int digits;
  final int period;
  final String algorithm;

  TOTPData({
    required this.secret,
    this.issuer,
    this.accountName,
    this.digits = 6,
    this.period = 30,
    this.algorithm = 'SHA1',
  });
}

/// Import error information
class ImportError {
  final int? lineNumber;
  final String message;
  final ImportErrorType type;
  final Map<String, dynamic>? context;

  ImportError({
    this.lineNumber,
    required this.message,
    required this.type,
    this.context,
  });
}

enum ImportErrorType {
  parseError,
  validationError,
  encryptionError,
  formatError,
  fileError,
}

/// Duplicate account detection result
class ImportDuplicate {
  final ImportedAccount imported;
  final String existingAccountId;
  final DuplicateMatchType matchType;
  final double confidence;

  ImportDuplicate({
    required this.imported,
    required this.existingAccountId,
    required this.matchType,
    required this.confidence,
  });
}

enum DuplicateMatchType {
  exact,
  titleAndUsername,
  titleOnly,
  usernameAndUrl,
  fuzzy,
}

/// Import operation statistics
class ImportStatistics {
  final int totalRecords;
  final int successfulImports;
  final int errors;
  final int duplicates;
  final int skipped;
  final Duration processingTime;

  ImportStatistics({
    required this.totalRecords,
    required this.successfulImports,
    required this.errors,
    required this.duplicates,
    required this.skipped,
    required this.processingTime,
  });
}

/// Field mapping configuration for import plugins
class FieldMapping {
  final Map<String, String> fieldMap;
  final Map<String, dynamic> defaultValues;
  final List<String> requiredFields;

  FieldMapping({
    required this.fieldMap,
    this.defaultValues = const {},
    this.requiredFields = const [],
  });
}

/// Import configuration options
class ImportOptions {
  final String targetVaultId;
  final bool skipDuplicates;
  final bool mergeWithExisting;
  final FieldMapping? customFieldMapping;
  final bool validateData;
  final bool preserveTimestamps;

  ImportOptions({
    required this.targetVaultId,
    this.skipDuplicates = false,
    this.mergeWithExisting = false,
    this.customFieldMapping,
    this.validateData = true,
    this.preserveTimestamps = true,
  });
}
