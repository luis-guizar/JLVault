import 'dart:io';
import 'package:csv/csv.dart';
import '../../../models/import_result.dart';
import '../base_import_plugin.dart';
import '../import_plugin.dart';

/// Import plugin for Safari password exports
class SafariImportPlugin extends BaseImportPlugin {
  @override
  String get pluginId => 'safari';

  @override
  String get displayName => 'Safari';

  @override
  String get description => 'Import from Safari password export (CSV format)';

  @override
  List<String> get supportedExtensions => ['.csv'];

  @override
  List<String> get supportedMimeTypes => ['text/csv', 'application/csv'];

  @override
  bool get supportsTOTP => false; // Safari CSV doesn't include TOTP

  @override
  bool get supportsCustomFields => false; // Basic CSV format

  @override
  Future<bool> validateFileFormat(List<int> fileBytes) async {
    try {
      final content = String.fromCharCodes(fileBytes);
      final lines = content.split('\n');

      if (lines.isEmpty) return false;

      // Check if first line looks like Safari CSV header
      final firstLine = lines[0].toLowerCase();
      return firstLine.contains('title') &&
          firstLine.contains('url') &&
          firstLine.contains('username') &&
          firstLine.contains('password');
    } catch (e) {
      return false;
    }
  }

  @override
  Future<ImportResult> import(File file, ImportOptions options) async {
    return await processImport(file, options, () async {
      final content = await file.readAsString();
      final rows = const CsvToListConverter().convert(content);

      if (rows.isEmpty) {
        throw ImportPluginException('CSV file is empty');
      }

      // Detect header format
      final header = rows[0]
          .map((e) => e.toString().toLowerCase().trim())
          .toList();
      final fieldIndices = _detectFieldIndices(header);

      if (fieldIndices['username'] == -1 || fieldIndices['password'] == -1) {
        throw ImportPluginException(
          'Invalid Safari CSV format: missing required columns',
        );
      }

      final accounts = <ImportedAccount>[];

      // Process data rows (skip header)
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 3) continue; // Skip incomplete rows

        try {
          final account = _parseRow(row, fieldIndices, i + 1);
          if (account != null) {
            accounts.add(account);
          }
        } catch (e) {
          // Skip invalid rows but continue processing
          continue;
        }
      }

      return accounts;
    });
  }

  @override
  FieldMapping getDefaultFieldMapping() {
    return FieldMapping(
      fieldMap: {
        'Title': 'title',
        'URL': 'url',
        'Username': 'username',
        'Password': 'password',
        'Notes': 'notes',
        'OTPAuth': 'totp',
      },
      requiredFields: ['title', 'username', 'password'],
    );
  }

  @override
  String getSampleFormat() {
    return '''
Title,URL,Username,Password,Notes,OTPAuth
Example Site,https://example.com,user@example.com,password123,"Additional notes",
GitHub,https://github.com,myusername,mypassword,,
Banking,https://bank.com,customer123,bankpass,"Important account",
''';
  }

  /// Detects field indices from CSV header
  Map<String, int> _detectFieldIndices(List<String> header) {
    final indices = <String, int>{
      'title': -1,
      'url': -1,
      'username': -1,
      'password': -1,
      'notes': -1,
      'otpauth': -1,
    };

    for (int i = 0; i < header.length; i++) {
      final field = header[i];

      // Map Safari-specific field names
      if (field.contains('title') || field.contains('name')) {
        indices['title'] = i;
      } else if (field.contains('url') ||
          field.contains('website') ||
          field.contains('site')) {
        indices['url'] = i;
      } else if (field.contains('username') ||
          field.contains('user') ||
          field.contains('login')) {
        indices['username'] = i;
      } else if (field.contains('password') || field.contains('pass')) {
        indices['password'] = i;
      } else if (field.contains('notes') ||
          field.contains('note') ||
          field.contains('comment')) {
        indices['notes'] = i;
      } else if (field.contains('otpauth') ||
          field.contains('otp') ||
          field.contains('totp')) {
        indices['otpauth'] = i;
      }
    }

    return indices;
  }

  /// Parses a CSV row into ImportedAccount
  ImportedAccount? _parseRow(
    List<dynamic> row,
    Map<String, int> indices,
    int lineNumber,
  ) {
    final title = _getFieldValue(row, indices['title']);
    final url = _getFieldValue(row, indices['url']);
    final username = _getFieldValue(row, indices['username']);
    final password = _getFieldValue(row, indices['password']);
    final notes = _getFieldValue(row, indices['notes']);
    final otpauth = _getFieldValue(row, indices['otpauth']);

    // Skip rows without essential data
    if (username.isEmpty && password.isEmpty && title.isEmpty) {
      return null;
    }

    // Generate title if missing
    String finalTitle = title;
    if (finalTitle.isEmpty) {
      if (url.isNotEmpty) {
        finalTitle = _extractDomainFromUrl(url);
      } else if (username.isNotEmpty) {
        finalTitle = 'Account for $username';
      } else {
        finalTitle = 'Safari Import';
      }
    }

    // Parse TOTP if present
    TOTPData? totpData;
    if (otpauth.isNotEmpty) {
      totpData = _parseTOTPData(otpauth, finalTitle, username);
    }

    return createSafeAccount(
      title: finalTitle,
      username: username,
      password: password,
      url: url.isNotEmpty ? url : null,
      notes: notes.isNotEmpty ? notes : null,
      totpData: totpData,
      metadata: {'source': 'safari', 'lineNumber': lineNumber},
    );
  }

  /// Safely gets field value from row
  String _getFieldValue(List<dynamic> row, int? index) {
    if (index == null || index == -1 || index >= row.length) {
      return '';
    }
    return row[index]?.toString().trim() ?? '';
  }

  /// Extracts domain name from URL for title generation
  String _extractDomainFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      String domain = uri.host;

      // Remove www. prefix
      if (domain.startsWith('www.')) {
        domain = domain.substring(4);
      }

      // Capitalize first letter
      if (domain.isNotEmpty) {
        domain = domain[0].toUpperCase() + domain.substring(1);
      }

      return domain;
    } catch (e) {
      return url;
    }
  }

  /// Parses TOTP data from various formats
  TOTPData? _parseTOTPData(String totpData, String title, String username) {
    if (totpData.isEmpty) return null;

    // Handle otpauth:// URLs
    if (totpData.startsWith('otpauth://')) {
      return _parseOTPAuthUrl(totpData);
    }

    // Handle plain Base32 secrets
    if (_isBase32(totpData)) {
      return TOTPData(secret: totpData, issuer: title, accountName: username);
    }

    return null;
  }

  /// Parses otpauth:// URL format
  TOTPData? _parseOTPAuthUrl(String otpAuthUrl) {
    try {
      final uri = Uri.parse(otpAuthUrl);

      if (uri.scheme != 'otpauth' || uri.host != 'totp') {
        return null;
      }

      final secret = uri.queryParameters['secret'];
      if (secret == null || secret.isEmpty) return null;

      final issuer = uri.queryParameters['issuer'];
      final digits = int.tryParse(uri.queryParameters['digits'] ?? '6') ?? 6;
      final period = int.tryParse(uri.queryParameters['period'] ?? '30') ?? 30;
      final algorithm = uri.queryParameters['algorithm'] ?? 'SHA1';

      // Extract account name from path
      String? accountName;
      if (uri.path.isNotEmpty) {
        accountName = Uri.decodeComponent(uri.path.substring(1));
        // Remove issuer prefix if present
        if (issuer != null && accountName.startsWith('$issuer:')) {
          accountName = accountName.substring(issuer.length + 1);
        }
      }

      return TOTPData(
        secret: secret,
        issuer: issuer,
        accountName: accountName,
        digits: digits,
        period: period,
        algorithm: algorithm,
      );
    } catch (e) {
      return null;
    }
  }

  /// Checks if string is valid Base32
  bool _isBase32(String value) {
    final base32Regex = RegExp(r'^[A-Z2-7]+=*$');
    return base32Regex.hasMatch(value.toUpperCase());
  }
}
