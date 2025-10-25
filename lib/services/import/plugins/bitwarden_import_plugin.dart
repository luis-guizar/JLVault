import 'dart:convert';
import 'dart:io';
import '../../../models/import_result.dart';
import '../base_import_plugin.dart';
import '../import_plugin.dart';

/// Import plugin for Bitwarden JSON exports
class BitwardenImportPlugin extends BaseImportPlugin {
  @override
  String get pluginId => 'bitwarden';

  @override
  String get displayName => 'Bitwarden';

  @override
  String get description => 'Import from Bitwarden JSON export files';

  @override
  List<String> get supportedExtensions => ['.json'];

  @override
  List<String> get supportedMimeTypes => ['application/json'];

  @override
  bool get supportsTOTP => true;

  @override
  bool get supportsCustomFields => true;

  @override
  Future<bool> validateFileFormat(List<int> fileBytes) async {
    try {
      final content = utf8.decode(fileBytes);
      final jsonData = jsonDecode(content);

      // Check if it's a Bitwarden export format
      return jsonData is Map<String, dynamic> &&
          jsonData.containsKey('items') &&
          jsonData['items'] is List;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<ImportResult> import(File file, ImportOptions options) async {
    return await processImport(file, options, () async {
      final content = await file.readAsString();
      final jsonData = jsonDecode(content) as Map<String, dynamic>;

      if (!jsonData.containsKey('items')) {
        throw ImportPluginException(
          'Invalid Bitwarden export format: missing items',
        );
      }

      final items = jsonData['items'] as List;
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
        'login.username': 'username',
        'login.password': 'password',
        'login.uris[0].uri': 'url',
        'notes': 'notes',
      },
      requiredFields: ['title', 'username', 'password'],
    );
  }

  @override
  String getSampleFormat() {
    return '''
{
  "items": [
    {
      "id": "item-id",
      "name": "Example Site",
      "type": 1,
      "login": {
        "username": "user@example.com",
        "password": "password123",
        "uris": [{"uri": "https://example.com"}],
        "totp": "JBSWY3DPEHPK3PXP"
      },
      "notes": "Additional notes",
      "fields": [
        {
          "name": "Custom Field",
          "value": "Custom Value",
          "type": 0
        }
      ]
    }
  ]
}
''';
  }

  /// Parses a Bitwarden item into ImportedAccount
  ImportedAccount? _parseItem(Map<String, dynamic> item) {
    // Only process login items (type 1)
    final type = safeGetInt(item, 'type');
    if (type != 1) return null;

    final login = item['login'] as Map<String, dynamic>?;
    if (login == null) return null;

    final name = safeGetString(item, 'name');
    final username = safeGetString(login, 'username');
    final password = safeGetString(login, 'password');

    // Skip items without essential data
    if (name.isEmpty && username.isEmpty) return null;

    // Extract URL from URIs array
    String? url;
    final uris = login['uris'] as List?;
    if (uris != null && uris.isNotEmpty) {
      final firstUri = uris[0] as Map<String, dynamic>?;
      if (firstUri != null) {
        url = safeGetString(firstUri, 'uri');
      }
    }

    // Parse TOTP if present
    TOTPData? totpData;
    final totpSecret = safeGetString(login, 'totp');
    if (totpSecret.isNotEmpty) {
      totpData = TOTPData(
        secret: totpSecret,
        issuer: name.isNotEmpty ? name : null,
        accountName: username.isNotEmpty ? username : null,
      );
    }

    // Parse custom fields
    final customFields = _parseCustomFields(item['fields'] as List?);

    // Parse timestamps
    final createdAt = safeGetDateTime(item, 'creationDate');
    final modifiedAt = safeGetDateTime(item, 'revisionDate');

    return createSafeAccount(
      title: name.isNotEmpty ? name : 'Imported from Bitwarden',
      username: username,
      password: password,
      url: url,
      notes: safeGetString(item, 'notes'),
      customFields: customFields,
      totpData: totpData,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      metadata: {
        'source': 'bitwarden',
        'originalId': safeGetString(item, 'id'),
        'organizationId': safeGetString(item, 'organizationId'),
        'folderId': safeGetString(item, 'folderId'),
      },
    );
  }

  /// Parses Bitwarden custom fields
  List<CustomField> _parseCustomFields(List? fields) {
    if (fields == null) return [];

    final customFields = <CustomField>[];

    for (final field in fields) {
      if (field is! Map<String, dynamic>) continue;

      final name = safeGetString(field, 'name');
      final value = safeGetString(field, 'value');
      final type = safeGetInt(field, 'type');

      if (name.isEmpty) continue;

      // Map Bitwarden field types to our types
      CustomFieldType fieldType;
      switch (type) {
        case 1: // Hidden/Password
          fieldType = CustomFieldType.password;
          break;
        case 2: // Boolean
          fieldType = CustomFieldType.text;
          break;
        default: // Text
          fieldType = CustomFieldType.text;
          break;
      }

      customFields.add(CustomField(name: name, value: value, type: fieldType));
    }

    return customFields;
  }
}
