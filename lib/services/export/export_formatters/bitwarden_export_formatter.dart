import 'dart:convert';
import '../../../models/export_result.dart';
import 'export_formatter.dart';

/// Formatter for Bitwarden JSON export format
class BitwardenExportFormatter implements ExportFormatter {
  @override
  String get mimeType => 'application/json';

  @override
  String get fileExtension => '.json';

  @override
  String get description => 'Bitwarden JSON format';

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
      'encrypted': false,
      'folders': _createFolders(accounts),
      'items': accounts
          .map((account) => _formatAccount(account, options))
          .toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// Creates folder structure from vaults
  List<Map<String, dynamic>> _createFolders(List<ExportedAccount> accounts) {
    final vaults = <String, String>{};

    for (final account in accounts) {
      vaults[account.vaultId] = account.vaultName;
    }

    return vaults.entries
        .map((entry) => {'id': entry.key, 'name': entry.value})
        .toList();
  }

  /// Formats a single account for Bitwarden export
  Map<String, dynamic> _formatAccount(
    ExportedAccount account,
    ExportOptions options,
  ) {
    final item = <String, dynamic>{
      'id': account.id,
      'organizationId': null,
      'folderId': account.vaultId,
      'type': 1, // Login type
      'reprompt': 0,
      'name': account.title,
      'notes': account.notes,
      'favorite': false,
      'login': {
        'username': account.username,
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
    };

    // Include password if requested
    if (options.includePasswords) {
      item['login']['password'] = account.password;
    }

    // Include TOTP if requested and available
    if (options.includeTOTP && account.totpData != null) {
      item['login']['totp'] = account.totpData!.secret;
    }

    // Include custom fields if requested and available
    if (options.includeCustomFields && account.customFields.isNotEmpty) {
      item['fields'] = account.customFields
          .map(
            (field) => {
              'name': field.name,
              'value': field.value,
              'type': _mapCustomFieldType(field.type),
              'linkedId': null,
            },
          )
          .toList();
    }

    return item;
  }

  /// Maps custom field type to Bitwarden type
  int _mapCustomFieldType(String type) {
    switch (type.toLowerCase()) {
      case 'password':
        return 1; // Hidden
      case 'boolean':
        return 2; // Boolean
      default:
        return 0; // Text
    }
  }
}
