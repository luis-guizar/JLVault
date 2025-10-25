import 'package:csv/csv.dart';
import '../../../models/export_result.dart';
import 'export_formatter.dart';

/// Formatter for CSV export
class CsvExportFormatter implements ExportFormatter {
  @override
  String get mimeType => 'text/csv';

  @override
  String get fileExtension => '.csv';

  @override
  String get description => 'CSV format (unencrypted)';

  @override
  bool get supportsEncryption => false;

  @override
  bool get supportsCustomFields => false; // Limited support in CSV

  @override
  bool get supportsTOTP => true;

  @override
  Future<String> format(
    List<ExportedAccount> accounts,
    ExportOptions options,
  ) async {
    final rows = <List<String>>[];

    // Create header row
    final headers = [
      'Title',
      'Username',
      'URL',
      'Notes',
      'Tags',
      'Category',
      'Vault',
    ];

    if (options.includePasswords) {
      headers.insert(2, 'Password'); // Insert after Username
    }

    if (options.includeTOTP) {
      headers.addAll(['TOTP Secret', 'TOTP Issuer', 'OTP Auth URL']);
    }

    if (options.includeMetadata) {
      headers.addAll(['Created At', 'Modified At']);
    }

    rows.add(headers);

    // Add account rows
    for (final account in accounts) {
      final row = <String>[
        account.title,
        account.username,
        account.url ?? '',
        account.notes ?? '',
        account.tags.join(', '),
        account.category ?? '',
        account.vaultName,
      ];

      if (options.includePasswords) {
        row.insert(2, account.password); // Insert after Username
      }

      if (options.includeTOTP) {
        if (account.totpData != null) {
          row.addAll([
            account.totpData!.secret,
            account.totpData!.issuer ?? '',
            account.totpData!.toOTPAuthUrl(),
          ]);
        } else {
          row.addAll(['', '', '']);
        }
      }

      if (options.includeMetadata) {
        row.addAll([
          account.createdAt?.toIso8601String() ?? '',
          account.modifiedAt?.toIso8601String() ?? '',
        ]);
      }

      rows.add(row);
    }

    return const ListToCsvConverter().convert(rows);
  }
}
