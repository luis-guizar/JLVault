/// Result of an export operation
class ExportResult {
  final bool success;
  final String? filePath;
  final String? errorMessage;
  final int exportedCount;
  final ExportFormat format;
  final DateTime timestamp;

  const ExportResult({
    required this.success,
    this.filePath,
    this.errorMessage,
    this.exportedCount = 0,
    required this.format,
    required this.timestamp,
  });

  factory ExportResult.success({
    required String filePath,
    required int exportedCount,
    required ExportFormat format,
  }) {
    return ExportResult(
      success: true,
      filePath: filePath,
      exportedCount: exportedCount,
      format: format,
      timestamp: DateTime.now(),
    );
  }

  factory ExportResult.failure({
    required String errorMessage,
    required ExportFormat format,
  }) {
    return ExportResult(
      success: false,
      errorMessage: errorMessage,
      format: format,
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() {
    if (success) {
      return 'ExportResult(success: $success, exported: $exportedCount, file: $filePath)';
    } else {
      return 'ExportResult(success: $success, error: $errorMessage)';
    }
  }
}

/// Available export formats
enum ExportFormat {
  json,
  csv,
  bitwarden,
  lastpass,
  onepassword,
  simpleVaultEncrypted,
}

/// Export configuration options
class ExportOptions {
  final List<String> vaultIds;
  final ExportFormat format;
  final bool includePasswords;
  final bool includeTOTP;
  final bool includeCustomFields;
  final bool includeMetadata;
  final String? password;
  final bool compressOutput;

  const ExportOptions({
    required this.vaultIds,
    required this.format,
    this.includePasswords = true,
    this.includeTOTP = true,
    this.includeCustomFields = true,
    this.includeMetadata = false,
    this.password,
    this.compressOutput = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'vaultIds': vaultIds,
      'format': format.name,
      'includePasswords': includePasswords,
      'includeTOTP': includeTOTP,
      'includeCustomFields': includeCustomFields,
      'includeMetadata': includeMetadata,
      'compressOutput': compressOutput,
      // Note: password is intentionally excluded from JSON for security
    };
  }
}

/// Represents an account prepared for export
class ExportedAccount {
  final String id;
  final String title;
  final String username;
  final String password;
  final String? url;
  final String? notes;
  final String vaultId;
  final String vaultName;
  final DateTime? createdAt;
  final DateTime? modifiedAt;
  final ExportedTOTPData? totpData;
  final List<ExportedCustomField> customFields;
  final List<String> tags;
  final String? category;
  final Map<String, dynamic>? metadata;

  const ExportedAccount({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    this.url,
    this.notes,
    required this.vaultId,
    required this.vaultName,
    this.createdAt,
    this.modifiedAt,
    this.totpData,
    this.customFields = const [],
    this.tags = const [],
    this.category,
    this.metadata,
  });

  /// Creates an ExportedAccount from an Account and vault name
  factory ExportedAccount.fromAccount(
    dynamic account,
    String vaultName, {
    ExportedTOTPData? totpData,
    List<ExportedCustomField> customFields = const [],
    List<String> tags = const [],
    String? category,
    Map<String, dynamic>? metadata,
  }) {
    return ExportedAccount(
      id: account.id?.toString() ?? '',
      title: account.name,
      username: account.username,
      password: account.password,
      url: account.url,
      notes: account.notes,
      vaultId: account.vaultId,
      vaultName: vaultName,
      createdAt: account.createdAt,
      modifiedAt: account.modifiedAt,
      totpData: totpData,
      customFields: customFields,
      tags: tags,
      category: category,
      metadata: metadata,
    );
  }
}

/// TOTP data for export
class ExportedTOTPData {
  final String secret;
  final String? issuer;
  final String? accountName;
  final int period;
  final int digits;
  final String algorithm;

  const ExportedTOTPData({
    required this.secret,
    this.issuer,
    this.accountName,
    this.period = 30,
    this.digits = 6,
    this.algorithm = 'SHA1',
  });

  /// Converts TOTP data to OTP Auth URL format
  String toOTPAuthUrl() {
    final uri = Uri(
      scheme: 'otpauth',
      host: 'totp',
      path: '/${issuer ?? 'SimpleVault'}:${accountName ?? 'Account'}',
      queryParameters: {
        'secret': secret,
        'issuer': issuer ?? 'SimpleVault',
        'algorithm': algorithm,
        'digits': digits.toString(),
        'period': period.toString(),
      },
    );
    return uri.toString();
  }
}

/// Custom field for export
class ExportedCustomField {
  final String name;
  final String value;
  final String type;

  const ExportedCustomField({
    required this.name,
    required this.value,
    this.type = 'text',
  });
}
