/// Models for export system results and configuration

/// Configuration options for export operations
class ExportOptions {
  final List<String> vaultIds;
  final List<String> categories;
  final ExportFormat format;
  final bool includePasswords;
  final bool includeTOTP;
  final bool includeCustomFields;
  final bool includeMetadata;
  final String? password; // For encrypted exports
  final bool compressOutput;

  ExportOptions({
    required this.vaultIds,
    this.categories = const [],
    required this.format,
    this.includePasswords = true,
    this.includeTOTP = true,
    this.includeCustomFields = true,
    this.includeMetadata = false,
    this.password,
    this.compressOutput = false,
  });
}

/// Supported export formats
enum ExportFormat {
  simpleVaultEncrypted, // Native encrypted format
  json, // Plain JSON
  csv, // CSV format
  bitwarden, // Bitwarden JSON format
  lastpass, // LastPass CSV format
  onepassword, // 1Password 1PUX format
}

/// Result of an export operation
class ExportResult {
  final String filePath;
  final ExportStatistics statistics;
  final List<ExportError> errors;
  final ExportMetadata metadata;

  ExportResult({
    required this.filePath,
    required this.statistics,
    required this.errors,
    required this.metadata,
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get isSuccessful => !hasErrors;
}

/// Statistics about the export operation
class ExportStatistics {
  final int totalAccounts;
  final int exportedAccounts;
  final int skippedAccounts;
  final int vaultsExported;
  final int categoriesExported;
  final Duration processingTime;
  final int fileSizeBytes;

  ExportStatistics({
    required this.totalAccounts,
    required this.exportedAccounts,
    required this.skippedAccounts,
    required this.vaultsExported,
    required this.categoriesExported,
    required this.processingTime,
    required this.fileSizeBytes,
  });
}

/// Metadata about the exported file
class ExportMetadata {
  final DateTime exportedAt;
  final String exportedBy;
  final String appVersion;
  final ExportFormat format;
  final bool isEncrypted;
  final String checksum;
  final Map<String, dynamic> additionalData;

  ExportMetadata({
    required this.exportedAt,
    required this.exportedBy,
    required this.appVersion,
    required this.format,
    required this.isEncrypted,
    required this.checksum,
    this.additionalData = const {},
  });
}

/// Error that occurred during export
class ExportError {
  final String message;
  final ExportErrorType type;
  final String? accountId;
  final String? vaultId;
  final Map<String, dynamic>? context;

  ExportError({
    required this.message,
    required this.type,
    this.accountId,
    this.vaultId,
    this.context,
  });
}

/// Types of export errors
enum ExportErrorType {
  accessDenied,
  encryptionError,
  fileSystemError,
  validationError,
  formatError,
  compressionError,
}

/// Data structure for exported account
class ExportedAccount {
  final String id;
  final String title;
  final String username;
  final String password;
  final String? url;
  final String? notes;
  final List<ExportedCustomField> customFields;
  final ExportedTOTPData? totpData;
  final DateTime? createdAt;
  final DateTime? modifiedAt;
  final List<String> tags;
  final String? category;
  final String vaultId;
  final String vaultName;
  final Map<String, dynamic> metadata;

  ExportedAccount({
    required this.id,
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
    required this.vaultId,
    required this.vaultName,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'username': username,
      'password': password,
      'url': url,
      'notes': notes,
      'customFields': customFields.map((f) => f.toJson()).toList(),
      'totpData': totpData?.toJson(),
      'createdAt': createdAt?.toIso8601String(),
      'modifiedAt': modifiedAt?.toIso8601String(),
      'tags': tags,
      'category': category,
      'vaultId': vaultId,
      'vaultName': vaultName,
      'metadata': metadata,
    };
  }
}

/// Exported custom field data
class ExportedCustomField {
  final String name;
  final String value;
  final String type;

  ExportedCustomField({
    required this.name,
    required this.value,
    required this.type,
  });

  Map<String, dynamic> toJson() {
    return {'name': name, 'value': value, 'type': type};
  }
}

/// Exported TOTP data
class ExportedTOTPData {
  final String secret;
  final String? issuer;
  final String? accountName;
  final int digits;
  final int period;
  final String algorithm;

  ExportedTOTPData({
    required this.secret,
    this.issuer,
    this.accountName,
    this.digits = 6,
    this.period = 30,
    this.algorithm = 'SHA1',
  });

  Map<String, dynamic> toJson() {
    return {
      'secret': secret,
      'issuer': issuer,
      'accountName': accountName,
      'digits': digits,
      'period': period,
      'algorithm': algorithm,
    };
  }

  String toOTPAuthUrl() {
    final label = accountName ?? '';
    final issuerParam = issuer != null
        ? '&issuer=${Uri.encodeComponent(issuer!)}'
        : '';
    final digitsParam = digits != 6 ? '&digits=$digits' : '';
    final periodParam = period != 30 ? '&period=$period' : '';
    final algorithmParam = algorithm != 'SHA1' ? '&algorithm=$algorithm' : '';

    return 'otpauth://totp/$label?secret=$secret$issuerParam$digitsParam$periodParam$algorithmParam';
  }
}

/// Filter criteria for selective export
class ExportFilter {
  final List<String> includeVaultIds;
  final List<String> excludeVaultIds;
  final List<String> includeCategories;
  final List<String> excludeCategories;
  final List<String> includeTags;
  final List<String> excludeTags;
  final DateTime? createdAfter;
  final DateTime? createdBefore;
  final DateTime? modifiedAfter;
  final DateTime? modifiedBefore;
  final bool onlyWithTOTP;
  final bool onlyWithCustomFields;

  ExportFilter({
    this.includeVaultIds = const [],
    this.excludeVaultIds = const [],
    this.includeCategories = const [],
    this.excludeCategories = const [],
    this.includeTags = const [],
    this.excludeTags = const [],
    this.createdAfter,
    this.createdBefore,
    this.modifiedAfter,
    this.modifiedBefore,
    this.onlyWithTOTP = false,
    this.onlyWithCustomFields = false,
  });

  bool shouldIncludeAccount(ExportedAccount account) {
    // Vault filtering
    if (includeVaultIds.isNotEmpty &&
        !includeVaultIds.contains(account.vaultId)) {
      return false;
    }
    if (excludeVaultIds.contains(account.vaultId)) {
      return false;
    }

    // Category filtering
    if (includeCategories.isNotEmpty &&
        (account.category == null ||
            !includeCategories.contains(account.category))) {
      return false;
    }
    if (account.category != null &&
        excludeCategories.contains(account.category)) {
      return false;
    }

    // Tag filtering
    if (includeTags.isNotEmpty &&
        !account.tags.any((tag) => includeTags.contains(tag))) {
      return false;
    }
    if (account.tags.any((tag) => excludeTags.contains(tag))) {
      return false;
    }

    // Date filtering
    if (createdAfter != null &&
        (account.createdAt == null ||
            account.createdAt!.isBefore(createdAfter!))) {
      return false;
    }
    if (createdBefore != null &&
        (account.createdAt == null ||
            account.createdAt!.isAfter(createdBefore!))) {
      return false;
    }
    if (modifiedAfter != null &&
        (account.modifiedAt == null ||
            account.modifiedAt!.isBefore(modifiedAfter!))) {
      return false;
    }
    if (modifiedBefore != null &&
        (account.modifiedAt == null ||
            account.modifiedAt!.isAfter(modifiedBefore!))) {
      return false;
    }

    // Feature filtering
    if (onlyWithTOTP && account.totpData == null) {
      return false;
    }
    if (onlyWithCustomFields && account.customFields.isEmpty) {
      return false;
    }

    return true;
  }
}
