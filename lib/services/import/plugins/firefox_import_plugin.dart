import 'dart:io';
import 'package:csv/csv.dart';
import '../../../models/import_result.dart';
import '../base_import_plugin.dart';
import '../import_plugin.dart';

/// Import plugin for Firefox password exports
class FirefoxImportPlugin extends BaseImportPlugin {
  @override
  String get pluginId => 'firefox';

  @override
  String get displayName => 'Mozilla Firefox';

  @override
  String get description => 'Import from Firefox password export (CSV format)';

  @override
  List<String> get supportedExtensions => ['.csv'];

  @override
  List<String> get supportedMimeTypes => ['text/csv', 'application/csv'];

  @override
  bool get supportsTOTP => false; // Firefox CSV doesn't include TOTP

  @override
  bool get supportsCustomFields => false; // Basic CSV format

  @override
  Future<bool> validateFileFormat(List<int> fileBytes) async {
    try {
      final content = String.fromCharCodes(fileBytes);
      final lines = content.split('\n');

      if (lines.isEmpty) return false;

      // Check if first line looks like Firefox CSV header
      final firstLine = lines[0].toLowerCase();
      return firstLine.contains('url') &&
          firstLine.contains('username') &&
          firstLine.contains('password') &&
          (firstLine.contains('hostname') ||
              firstLine.contains('formactionorigin'));
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
          'Invalid Firefox CSV format: missing required columns',
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
        'url': 'url',
        'username': 'username',
        'password': 'password',
        'httpRealm': 'notes',
        'formActionOrigin': 'url',
        'timeCreated': 'createdAt',
        'timeLastUsed': 'modifiedAt',
      },
      requiredFields: ['username', 'password'],
    );
  }

  @override
  String getSampleFormat() {
    return '''
"url","username","password","httpRealm","formActionOrigin","guid","timeCreated","timeLastUsed","timePasswordChanged"
"https://example.com","user@example.com","password123","","https://example.com","{guid}","1640995200000","1640995200000","1640995200000"
"https://github.com","myusername","mypassword","","https://github.com","{guid}","1640995200000","1640995200000","1640995200000"
''';
  }

  /// Detects field indices from CSV header
  Map<String, int> _detectFieldIndices(List<String> header) {
    final indices = <String, int>{
      'url': -1,
      'username': -1,
      'password': -1,
      'httpRealm': -1,
      'formActionOrigin': -1,
      'guid': -1,
      'timeCreated': -1,
      'timeLastUsed': -1,
      'timePasswordChanged': -1,
    };

    for (int i = 0; i < header.length; i++) {
      final field = header[i];

      // Map Firefox-specific field names
      if (field.contains('url') && !field.contains('formaction')) {
        indices['url'] = i;
      } else if (field.contains('username') || field.contains('login')) {
        indices['username'] = i;
      } else if (field.contains('password')) {
        indices['password'] = i;
      } else if (field.contains('httprealm')) {
        indices['httpRealm'] = i;
      } else if (field.contains('formactionorigin')) {
        indices['formActionOrigin'] = i;
      } else if (field.contains('guid') || field.contains('id')) {
        indices['guid'] = i;
      } else if (field.contains('timecreated') || field.contains('created')) {
        indices['timeCreated'] = i;
      } else if (field.contains('timelastused') || field.contains('lastused')) {
        indices['timeLastUsed'] = i;
      } else if (field.contains('timepasswordchanged') ||
          field.contains('passwordchanged')) {
        indices['timePasswordChanged'] = i;
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
    final url = _getFieldValue(row, indices['url']);
    final username = _getFieldValue(row, indices['username']);
    final password = _getFieldValue(row, indices['password']);
    final httpRealm = _getFieldValue(row, indices['httpRealm']);
    final formActionOrigin = _getFieldValue(row, indices['formActionOrigin']);
    final guid = _getFieldValue(row, indices['guid']);
    final timeCreated = _getFieldValue(row, indices['timeCreated']);
    final timeLastUsed = _getFieldValue(row, indices['timeLastUsed']);
    final timePasswordChanged = _getFieldValue(
      row,
      indices['timePasswordChanged'],
    );

    // Skip rows without essential data
    if (username.isEmpty && password.isEmpty) {
      return null;
    }

    // Determine the best URL to use
    String finalUrl = url;
    if (finalUrl.isEmpty && formActionOrigin.isNotEmpty) {
      finalUrl = formActionOrigin;
    }

    // Generate title from URL or username
    String title;
    if (finalUrl.isNotEmpty) {
      title = _extractDomainFromUrl(finalUrl);
    } else if (username.isNotEmpty) {
      title = 'Account for $username';
    } else {
      title = 'Firefox Import';
    }

    // Parse timestamps (Firefox uses milliseconds since Unix epoch)
    DateTime? createdAt;
    DateTime? modifiedAt;

    if (timeCreated.isNotEmpty) {
      createdAt = _parseFirefoxDatetime(timeCreated);
    }

    if (timePasswordChanged.isNotEmpty) {
      modifiedAt = _parseFirefoxDatetime(timePasswordChanged);
    } else if (timeLastUsed.isNotEmpty) {
      modifiedAt = _parseFirefoxDatetime(timeLastUsed);
    }

    // Build notes from additional fields
    final notes = <String>[];
    if (httpRealm.isNotEmpty) {
      notes.add('HTTP Realm: $httpRealm');
    }
    if (guid.isNotEmpty) {
      notes.add('Original ID: $guid');
    }

    return createSafeAccount(
      title: title,
      username: username,
      password: password,
      url: finalUrl.isNotEmpty ? finalUrl : null,
      notes: notes.isNotEmpty ? notes.join('\n') : null,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      metadata: {
        'source': 'firefox',
        'lineNumber': lineNumber,
        'guid': guid,
        'httpRealm': httpRealm,
        'formActionOrigin': formActionOrigin,
      },
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

  /// Parses Firefox datetime format (milliseconds since Unix epoch)
  DateTime? _parseFirefoxDatetime(String dateString) {
    try {
      final milliseconds = int.tryParse(dateString);
      if (milliseconds == null || milliseconds <= 0) return null;

      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    } catch (e) {
      return null;
    }
  }
}
