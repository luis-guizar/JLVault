import 'dart:convert';
import 'dart:io';
import '../../../models/import_result.dart';
import '../base_import_plugin.dart';

/// Import plugin for 1Password exports (.1pux format)
class OnePasswordImportPlugin extends BaseImportPlugin {
  @override
  String get pluginId => '1password';

  @override
  String get displayName => '1Password';

  @override
  String get description => 'Import from 1Password .1pux export files';

  @override
  List<String> get supportedExtensions => ['.1pux'];

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

      // Check if it's a 1Password export format
      return jsonData is Map<String, dynamic> &&
          (jsonData.containsKey('accounts') || jsonData.containsKey('items'));
    } catch (e) {
      return false;
    }
  }

  @override
  Future<ImportResult> import(File file, ImportOptions options) async {
    return await processImport(file, options, () async {
      final content = await file.readAsString();
      final jsonData = jsonDecode(content) as Map<String, dynamic>;

      final accounts = <ImportedAccount>[];

      // Handle different 1Password export formats
      if (jsonData.containsKey('items')) {
        // Direct items array format
        final items = jsonData['items'] as List;
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final account = _parseItem(item);
            if (account != null) {
              accounts.add(account);
            }
          }
        }
      } else if (jsonData.containsKey('accounts')) {
        // Account-based format
        final accountsData = jsonData['accounts'] as List;
        for (final accountData in accountsData) {
          if (accountData is Map<String, dynamic> &&
              accountData.containsKey('items')) {
            final items = accountData['items'] as List;
            for (final item in items) {
              if (item is Map<String, dynamic>) {
                final account = _parseItem(item);
                if (account != null) {
                  accounts.add(account);
                }
              }
            }
          }
        }
      }

      return accounts;
    });
  }

  @override
  FieldMapping getDefaultFieldMapping() {
    return FieldMapping(
      fieldMap: {
        'title': 'title',
        'fields.username.value': 'username',
        'fields.password.value': 'password',
        'urls[0].href': 'url',
        'fields.notesPlain.value': 'notes',
      },
      requiredFields: ['title'],
    );
  }

  @override
  String getSampleFormat() {
    return '''
{
  "accounts": [
    {
      "items": [
        {
          "uuid": "item-uuid",
          "title": "Example Site",
          "category": "LOGIN",
          "fields": [
            {
              "id": "username",
              "type": "T",
              "label": "username",
              "value": "user@example.com"
            },
            {
              "id": "password",
              "type": "P",
              "label": "password",
              "value": "password123"
            }
          ],
          "urls": [
            {
              "href": "https://example.com"
            }
          ]
        }
      ]
    }
  ]
}
''';
  }

  /// Parses a 1Password item into ImportedAccount
  ImportedAccount? _parseItem(Map<String, dynamic> item) {
    final category = safeGetString(item, 'category').toUpperCase();

    // Only process login items
    if (category != 'LOGIN' && category != 'PASSWORD') {
      return null;
    }

    final title = safeGetString(item, 'title');
    if (title.isEmpty) return null;

    // Parse fields
    final fields = item['fields'] as List?;
    final fieldMap = <String, String>{};

    if (fields != null) {
      for (final field in fields) {
        if (field is Map<String, dynamic>) {
          final id = safeGetString(field, 'id');
          final value = safeGetString(field, 'value');
          final label = safeGetString(field, 'label');

          if (id.isNotEmpty && value.isNotEmpty) {
            fieldMap[id] = value;
            fieldMap[label.toLowerCase()] = value;
          }
        }
      }
    }

    // Extract standard fields
    final username =
        fieldMap['username'] ?? fieldMap['email'] ?? fieldMap['login'] ?? '';
    final password = fieldMap['password'] ?? '';

    // Skip items without password
    if (password.isEmpty) return null;

    // Extract URL
    String? url;
    final urls = item['urls'] as List?;
    if (urls != null && urls.isNotEmpty) {
      final firstUrl = urls[0] as Map<String, dynamic>?;
      if (firstUrl != null) {
        url = safeGetString(firstUrl, 'href');
      }
    }

    // Parse TOTP
    TOTPData? totpData;
    final totpSecret =
        fieldMap['one-time password'] ??
        fieldMap['totp'] ??
        fieldMap['otp'] ??
        '';
    if (totpSecret.isNotEmpty) {
      totpData = _parseTOTPSecret(totpSecret, title, username);
    }

    // Parse custom fields (exclude standard ones)
    final customFields = _parseCustomFields(fields, [
      'username',
      'password',
      'one-time password',
    ]);

    // Parse notes
    String notes = fieldMap['notesplain'] ?? '';
    if (notes.isEmpty) notes = safeGetString(item, 'notes');

    // Parse timestamps
    final createdAt = safeGetDateTime(item, 'createdAt');
    final updatedAt = safeGetDateTime(item, 'updatedAt');

    // Parse tags
    final tags = safeGetStringList(item, 'tags');

    return createSafeAccount(
      title: title,
      username: username,
      password: password,
      url: url,
      notes: notes.isNotEmpty ? notes : null,
      customFields: customFields,
      totpData: totpData,
      createdAt: createdAt,
      modifiedAt: updatedAt,
      tags: tags,
      metadata: {
        'source': '1password',
        'originalId': safeGetString(item, 'uuid'),
        'category': category,
      },
    );
  }

  /// Parses custom fields excluding standard ones
  List<CustomField> _parseCustomFields(List? fields, List<String> excludeIds) {
    if (fields == null) return [];

    final customFields = <CustomField>[];

    for (final field in fields) {
      if (field is! Map<String, dynamic>) continue;

      final id = safeGetString(field, 'id');
      final label = safeGetString(field, 'label');
      final value = safeGetString(field, 'value');
      final type = safeGetString(field, 'type');

      // Skip standard fields and empty values
      if (excludeIds.contains(id.toLowerCase()) ||
          excludeIds.contains(label.toLowerCase()) ||
          value.isEmpty) {
        continue;
      }

      // Map 1Password field types to our types
      CustomFieldType fieldType;
      switch (type.toUpperCase()) {
        case 'P': // Password
          fieldType = CustomFieldType.password;
          break;
        case 'E': // Email
          fieldType = CustomFieldType.email;
          break;
        case 'U': // URL
          fieldType = CustomFieldType.url;
          break;
        case 'N': // Number
          fieldType = CustomFieldType.number;
          break;
        case 'D': // Date
          fieldType = CustomFieldType.date;
          break;
        default: // Text
          fieldType = CustomFieldType.text;
          break;
      }

      final fieldName = label.isNotEmpty ? label : id;
      if (fieldName.isNotEmpty) {
        customFields.add(
          CustomField(name: fieldName, value: value, type: fieldType),
        );
      }
    }

    return customFields;
  }

  /// Parses TOTP secret from various formats
  TOTPData? _parseTOTPSecret(String totpSecret, String title, String username) {
    if (totpSecret.isEmpty) return null;

    // Handle otpauth:// URLs
    if (totpSecret.startsWith('otpauth://')) {
      return _parseOTPAuthUrl(totpSecret);
    }

    // Handle plain Base32 secrets
    if (_isBase32(totpSecret)) {
      return TOTPData(secret: totpSecret, issuer: title, accountName: username);
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
