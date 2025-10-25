import 'package:csv/csv.dart';
import '../../../models/export_result.dart';
import 'export_formatter.dart';

/// Formatter for LastPass CSV export format
class LastPassExportFormatter implements ExportFormatter {
  @override
  String get mimeType => 'text/csv';

  @override
  String get fileExtension => '.csv';

  @override
  String get description => 'LastPass CSV format';

  @override
  bool get supportsEncryption => false;

  @override
  bool get supportsCustomFields => false; // LastPass CSV has limited custom field support

  @override
  bool get supportsTOTP => false; // LastPass CSV doesn't include TOTP

  @override
  Future<String> format(
    List<ExportedAccount> accounts,
    ExportOptions options,
  ) async {
    final rows = <List<String>>[];

    // LastPass CSV header: url,username,password,extra,name,grouping,fav
    final headers = [
      'url',
      'username',
      'password',
      'extra',
      'name',
      'grouping',
      'fav',
    ];

    rows.add(headers);

    // Add account rows
    for (final account in accounts) {
      final extra = _buildExtraField(account, options);

      final row = [
        account.url ?? '',
        account.username,
        options.includePasswords ? account.password : '',
        extra,
        account.title,
        account.vaultName, // Use vault name as grouping
        '0', // Not favorite by default
      ];

      rows.add(row);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Builds the extra field containing notes and additional data
  String _buildExtraField(ExportedAccount account, ExportOptions options) {
    final extraParts = <String>[];

    // Add notes if available
    if (account.notes != null && account.notes!.isNotEmpty) {
      extraParts.add('Notes: ${account.notes}');
    }

    // Add tags if available
    if (account.tags.isNotEmpty) {
      extraParts.add('Tags: ${account.tags.join(', ')}');
    }

    // Add category if available
    if (account.category != null && account.category!.isNotEmpty) {
      extraParts.add('Category: ${account.category}');
    }

    // Add TOTP info if requested and available
    if (options.includeTOTP && account.totpData != null) {
      extraParts.add('TOTP: ${account.totpData!.toOTPAuthUrl()}');
    }

    // Add custom fields if requested and available
    if (options.includeCustomFields && account.customFields.isNotEmpty) {
      for (final field in account.customFields) {
        extraParts.add('${field.name}: ${field.value}');
      }
    }

    // Add metadata if requested
    if (options.includeMetadata) {
      if (account.createdAt != null) {
        extraParts.add('Created: ${account.createdAt!.toIso8601String()}');
      }
      if (account.modifiedAt != null) {
        extraParts.add('Modified: ${account.modifiedAt!.toIso8601String()}');
      }
    }

    return extraParts.join('\n');
  }
}
