import 'dart:convert';
import '../../../models/export_result.dart';
import 'export_formatter.dart';

/// Formatter for plain JSON export
class JsonExportFormatter implements ExportFormatter {
  @override
  String get mimeType => 'application/json';

  @override
  String get fileExtension => '.json';

  @override
  String get description => 'Plain JSON format (unencrypted)';

  @override
  bool get supportsEncryption => false;

  @override
  bool get supportsCustomFields => true;

  @override
  bool get supportsTOTP => true;

  @override
  Future<String> format(
    List<ExportedAccount> accounts,
    ExportOptions options,
  ) async {
    final exportData = {
      'metadata': {
        'exportedAt': DateTime.now().toIso8601String(),
        'exportedBy': 'Simple Vault',
        'version': '1.0.0',
        'format': 'json',
        'accountCount': accounts.length,
        'includePasswords': options.includePasswords,
        'includeTOTP': options.includeTOTP,
        'includeCustomFields': options.includeCustomFields,
      },
      'accounts': accounts
          .map((account) => _formatAccount(account, options))
          .toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// Formats a single account for JSON export
  Map<String, dynamic> _formatAccount(
    ExportedAccount account,
    ExportOptions options,
  ) {
    final accountData = <String, dynamic>{
      'id': account.id,
      'title': account.title,
      'username': account.username,
      'url': account.url,
      'notes': account.notes,
      'tags': account.tags,
      'category': account.category,
      'vaultId': account.vaultId,
      'vaultName': account.vaultName,
    };

    // Include password if requested
    if (options.includePasswords) {
      accountData['password'] = account.password;
    }

    // Include TOTP if requested and available
    if (options.includeTOTP && account.totpData != null) {
      accountData['totp'] = {
        'secret': account.totpData!.secret,
        'issuer': account.totpData!.issuer,
        'accountName': account.totpData!.accountName,
        'digits': account.totpData!.digits,
        'period': account.totpData!.period,
        'algorithm': account.totpData!.algorithm,
        'otpAuthUrl': account.totpData!.toOTPAuthUrl(),
      };
    }

    // Include custom fields if requested and available
    if (options.includeCustomFields && account.customFields.isNotEmpty) {
      accountData['customFields'] = account.customFields
          .map(
            (field) => {
              'name': field.name,
              'value': field.value,
              'type': field.type,
            },
          )
          .toList();
    }

    // Include metadata if requested
    if (options.includeMetadata) {
      accountData['metadata'] = {
        'createdAt': account.createdAt?.toIso8601String(),
        'modifiedAt': account.modifiedAt?.toIso8601String(),
        ...?account.metadata,
      };
    }

    return accountData;
  }
}
