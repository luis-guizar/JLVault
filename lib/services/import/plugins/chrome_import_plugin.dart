import 'dart:convert';
import 'dart:io';
import '../../../models/import_result.dart';
import '../base_import_plugin.dart';
import '../import_plugin.dart';

/// Import plugin for Chrome password exports
class ChromeImportPlugin extends BaseImportPlugin {
  @override
  String get pluginId => 'chrome';

  @override
  String get displayName => 'Google Chrome';

  @override
  String get description => 'Import from Chrome password export (JSON format)';

  @override
  List<String> get supportedExtensions => ['.json'];

  @override
  List<String> get supportedMimeTypes => ['application/json'];

  @override
  bool get supportsTOTP => false; // Chrome doesn't export TOTP

  @override
  bool get supportsCustomFields => false; // Chrome basic format

  @override
  Future<bool> validateFileFormat(List<int> fileBytes) async {
    try {
      final content = utf8.decode(fileBytes);
      final jsonData = jsonDecode(content);

      // Check if it's a Chrome password export
      if (jsonData is List) {
        // Direct array format
        return jsonData.isNotEmpty &&
            jsonData[0] is Map<String, dynamic> &&
            _hasChromeLikeFields(jsonData[0]);
      } else if (jsonData is Map<String, dynamic>) {
        // Wrapped format
        return jsonData.containsKey('passwords') ||
            jsonData.containsKey('logins') ||
            _hasChromeLikeFields(jsonData);
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<ImportResult> import(File file, ImportOptions options) async {
    return await processImport(file, options, () async {
      final content = await file.readAsString();
      final jsonData = jsonDecode(content);

      List<dynamic> items;

      if (jsonData is List) {
        items = jsonData;
      } else if (jsonData is Map<String, dynamic>) {
        // Try different possible keys
        items =
            (jsonData['passwords'] ??
                    jsonData['logins'] ??
                    jsonData['entries'] ??
                    [])
                as List;
      } else {
        throw ImportPluginException('Invalid Chrome export format');
      }

      final accounts = <ImportedAccount>[];

      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        if (item is! Map<String, dynamic>) continue;

        try {
          final account = _parseItem(item);
          if (account != null) {
            accounts.add(account);
          }
        } catch (e) {
          // Skip invalid items but continue processing
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
        'url': 'url',
        'username': 'username',
        'password': 'password',
      },
      requiredFields: ['username', 'password'],
    );
  }

  @override
  String getSampleFormat() {
    return '''
[
  {
    "name": "Example Site",
    "url": "https://example.com",
    "username": "user@example.com",
    "password": "password123"
  },
  {
    "name": "GitHub",
    "url": "https://github.com",
    "username": "myusername",
    "password": "mypassword"
  }
]
''';
  }

  /// Checks if the item has Chrome-like fields
  bool _hasChromeLikeFields(Map<String, dynamic> item) {
    return (item.containsKey('url') || item.containsKey('origin')) &&
        (item.containsKey('username') || item.containsKey('username_value')) &&
        (item.containsKey('password') || item.containsKey('password_value'));
  }

  /// Parses a Chrome item into ImportedAccount
  ImportedAccount? _parseItem(Map<String, dynamic> item) {
    // Chrome exports can have different field names
    String url = safeGetString(item, 'url');
    if (url.isEmpty) url = safeGetString(item, 'origin');
    if (url.isEmpty) url = safeGetString(item, 'signon_realm');

    String username = safeGetString(item, 'username');
    if (username.isEmpty) username = safeGetString(item, 'username_value');
    if (username.isEmpty) username = safeGetString(item, 'username_element');

    String password = safeGetString(item, 'password');
    if (password.isEmpty) password = safeGetString(item, 'password_value');
    if (password.isEmpty) password = safeGetString(item, 'password_element');

    // Skip items without essential data
    if (username.isEmpty && password.isEmpty) {
      return null;
    }

    // Generate title
    String title = safeGetString(item, 'name');
    if (title.isEmpty) title = safeGetString(item, 'title');

    if (title.isEmpty && url.isNotEmpty) {
      title = _extractDomainFromUrl(url);
    }

    if (title.isEmpty) {
      title = username.isNotEmpty ? 'Account for $username' : 'Chrome Import';
    }

    // Parse timestamps (Chrome uses microseconds since Windows epoch)
    DateTime? createdAt;
    DateTime? modifiedAt;

    final dateCreated = safeGetString(item, 'date_created');
    final dateLastUsed = safeGetString(item, 'date_last_used');
    final datePasswordModified = safeGetString(item, 'date_password_modified');

    if (dateCreated.isNotEmpty) {
      createdAt = _parseChromeDatetime(dateCreated);
    }

    if (datePasswordModified.isNotEmpty) {
      modifiedAt = _parseChromeDatetime(datePasswordModified);
    } else if (dateLastUsed.isNotEmpty) {
      modifiedAt = _parseChromeDatetime(dateLastUsed);
    }

    return createSafeAccount(
      title: title,
      username: username,
      password: password,
      url: url.isNotEmpty ? url : null,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      metadata: {
        'source': 'chrome',
        'times_used': safeGetString(item, 'times_used'),
        'form_data': safeGetString(item, 'form_data'),
      },
    );
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

  /// Parses Chrome datetime format (microseconds since Windows epoch)
  DateTime? _parseChromeDatetime(String dateString) {
    try {
      final microseconds = int.tryParse(dateString);
      if (microseconds == null) return null;

      // Chrome uses Windows epoch (January 1, 1601)
      // Convert to Unix epoch (January 1, 1970)
      const windowsEpochDifference = 11644473600000000; // microseconds
      final unixMicroseconds = microseconds - windowsEpochDifference;

      if (unixMicroseconds < 0) return null;

      return DateTime.fromMicrosecondsSinceEpoch(unixMicroseconds);
    } catch (e) {
      return null;
    }
  }
}
