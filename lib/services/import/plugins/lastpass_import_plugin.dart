import 'dart:io';
import 'package:csv/csv.dart';
import '../../../models/import_result.dart';
import '../base_import_plugin.dart';
import '../import_plugin.dart';

/// Import plugin for LastPass CSV exports
class LastPassImportPlugin extends BaseImportPlugin {
  @override
  String get pluginId => 'lastpass';

  @override
  String get displayName => 'LastPass';

  @override
  String get description => 'Import from LastPass CSV export files';

  @override
  List<String> get supportedExtensions => ['.csv'];

  @override
  List<String> get supportedMimeTypes => ['text/csv', 'application/csv'];

  @override
  bool get supportsTOTP => false; // LastPass CSV doesn't include TOTP

  @override
  bool get supportsCustomFields => false; // Basic CSV format

  @override
  Future<bool> validateFileFormat(List<int> fileBytes) async {
    try {
      final content = String.fromCharCodes(fileBytes);
      final lines = content.split('\n');

      if (lines.isEmpty) return false;

      // Check if first line looks like LastPass CSV header
      final firstLine = lines[0].toLowerCase();
      return firstLine.contains('url') &&
          firstLine.contains('username') &&
          firstLine.contains('password') &&
          firstLine.contains('name');
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

      if (fieldIndices['name'] == -1 ||
          fieldIndices['username'] == -1 ||
          fieldIndices['password'] == -1) {
        throw ImportPluginException(
          'Invalid LastPass CSV format: missing required columns',
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
        'name': 'title',
        'username': 'username',
        'password': 'password',
        'url': 'url',
        'extra': 'notes',
      },
      requiredFields: ['title', 'username', 'password'],
    );
  }

  @override
  String getSampleFormat() {
    return '''
url,username,password,extra,name,grouping,fav
https://example.com,user@example.com,password123,Additional notes,Example Site,Work,0
https://github.com,myusername,mypassword,,GitHub,Development,1
''';
  }

  /// Detects field indices from CSV header
  Map<String, int> _detectFieldIndices(List<String> header) {
    final indices = <String, int>{
      'url': -1,
      'username': -1,
      'password': -1,
      'name': -1,
      'extra': -1,
      'grouping': -1,
      'fav': -1,
    };

    for (int i = 0; i < header.length; i++) {
      final field = header[i];

      // Map common variations
      if (field.contains('url') || field.contains('site')) {
        indices['url'] = i;
      } else if (field.contains('username') ||
          field.contains('login') ||
          field.contains('email')) {
        indices['username'] = i;
      } else if (field.contains('password') || field.contains('pass')) {
        indices['password'] = i;
      } else if (field.contains('name') ||
          field.contains('title') ||
          field.contains('account')) {
        indices['name'] = i;
      } else if (field.contains('extra') ||
          field.contains('note') ||
          field.contains('comment')) {
        indices['extra'] = i;
      } else if (field.contains('group') ||
          field.contains('folder') ||
          field.contains('category')) {
        indices['grouping'] = i;
      } else if (field.contains('fav') ||
          field.contains('favorite') ||
          field.contains('star')) {
        indices['fav'] = i;
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
    final name = _getFieldValue(row, indices['name']);
    final extra = _getFieldValue(row, indices['extra']);
    final grouping = _getFieldValue(row, indices['grouping']);

    // Skip rows without essential data
    if (name.isEmpty && username.isEmpty && url.isEmpty) {
      return null;
    }

    // Generate title from available data
    String title = name;
    if (title.isEmpty) {
      if (url.isNotEmpty) {
        title = _extractDomainFromUrl(url);
      } else if (username.isNotEmpty) {
        title = 'Account for $username';
      } else {
        title = 'Imported Account';
      }
    }

    // Parse tags from grouping
    final tags = <String>[];
    if (grouping.isNotEmpty) {
      tags.add(grouping);
    }

    return createSafeAccount(
      title: title,
      username: username,
      password: password,
      url: url.isNotEmpty ? url : null,
      notes: extra.isNotEmpty ? extra : null,
      tags: tags,
      category: grouping.isNotEmpty ? grouping : null,
      metadata: {'source': 'lastpass', 'lineNumber': lineNumber},
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
}
