import '../../models/import_result.dart';

/// Service for mapping fields between different import formats
class FieldMapper {
  /// Maps raw import data to ImportedAccount using field mapping
  static ImportedAccount mapFields(
    Map<String, dynamic> rawData,
    FieldMapping mapping,
  ) {
    final mappedData = <String, dynamic>{};

    // Apply field mappings
    for (final entry in mapping.fieldMap.entries) {
      final sourceField = entry.key;
      final targetField = entry.value;

      if (rawData.containsKey(sourceField)) {
        mappedData[targetField] = rawData[sourceField];
      }
    }

    // Apply default values for missing fields
    for (final entry in mapping.defaultValues.entries) {
      if (!mappedData.containsKey(entry.key)) {
        mappedData[entry.key] = entry.value;
      }
    }

    // Validate required fields
    for (final requiredField in mapping.requiredFields) {
      if (!mappedData.containsKey(requiredField) ||
          mappedData[requiredField] == null ||
          mappedData[requiredField].toString().trim().isEmpty) {
        throw FieldMappingException('Required field missing: $requiredField');
      }
    }

    return _buildImportedAccount(mappedData);
  }

  /// Builds ImportedAccount from mapped data
  static ImportedAccount _buildImportedAccount(Map<String, dynamic> data) {
    return ImportedAccount(
      title: _getString(data, 'title') ?? 'Untitled',
      username: _getString(data, 'username') ?? '',
      password: _getString(data, 'password') ?? '',
      url: _getString(data, 'url'),
      notes: _getString(data, 'notes'),
      customFields: _parseCustomFields(data['customFields']),
      totpData: _parseTOTPData(data['totp']),
      createdAt: _parseDateTime(data['createdAt']),
      modifiedAt: _parseDateTime(data['modifiedAt']),
      tags: _parseStringList(data['tags']),
      category: _getString(data, 'category'),
      metadata: data['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Safely extracts string value from data
  static String? _getString(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value?.toString().trim().isEmpty == true ? null : value?.toString();
  }

  /// Parses custom fields from various formats
  static List<CustomField> _parseCustomFields(dynamic customFieldsData) {
    if (customFieldsData == null) return [];

    final fields = <CustomField>[];

    if (customFieldsData is List) {
      for (final field in customFieldsData) {
        if (field is Map<String, dynamic>) {
          fields.add(
            CustomField(
              name: field['name']?.toString() ?? '',
              value: field['value']?.toString() ?? '',
              type: _parseCustomFieldType(field['type']),
            ),
          );
        }
      }
    } else if (customFieldsData is Map<String, dynamic>) {
      for (final entry in customFieldsData.entries) {
        fields.add(
          CustomField(
            name: entry.key,
            value: entry.value?.toString() ?? '',
            type: CustomFieldType.text,
          ),
        );
      }
    }

    return fields;
  }

  /// Parses custom field type from string
  static CustomFieldType _parseCustomFieldType(dynamic typeData) {
    if (typeData == null) return CustomFieldType.text;

    final typeString = typeData.toString().toLowerCase();
    switch (typeString) {
      case 'password':
        return CustomFieldType.password;
      case 'email':
        return CustomFieldType.email;
      case 'url':
        return CustomFieldType.url;
      case 'number':
        return CustomFieldType.number;
      case 'date':
        return CustomFieldType.date;
      default:
        return CustomFieldType.text;
    }
  }

  /// Parses TOTP data from various formats
  static TOTPData? _parseTOTPData(dynamic totpData) {
    if (totpData == null) return null;

    if (totpData is Map<String, dynamic>) {
      final secret = totpData['secret']?.toString();
      if (secret == null || secret.isEmpty) return null;

      return TOTPData(
        secret: secret,
        issuer: totpData['issuer']?.toString(),
        accountName: totpData['accountName']?.toString(),
        digits: _parseInt(totpData['digits']) ?? 6,
        period: _parseInt(totpData['period']) ?? 30,
        algorithm: totpData['algorithm']?.toString() ?? 'SHA1',
      );
    }

    return null;
  }

  /// Parses DateTime from various formats
  static DateTime? _parseDateTime(dynamic dateData) {
    if (dateData == null) return null;

    if (dateData is DateTime) return dateData;
    if (dateData is int) return DateTime.fromMillisecondsSinceEpoch(dateData);
    if (dateData is String) {
      try {
        return DateTime.parse(dateData);
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  /// Parses string list from various formats
  static List<String> _parseStringList(dynamic listData) {
    if (listData == null) return [];

    if (listData is List) {
      return listData.map((e) => e.toString()).toList();
    }

    if (listData is String) {
      // Handle comma-separated values
      return listData
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return [];
  }

  /// Safely parses integer from dynamic value
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  /// Creates standard field mappings for common formats
  static FieldMapping createStandardMapping({
    String titleField = 'title',
    String usernameField = 'username',
    String passwordField = 'password',
    String urlField = 'url',
    String notesField = 'notes',
    Map<String, String> additionalMappings = const {},
  }) {
    final fieldMap = <String, String>{
      titleField: 'title',
      usernameField: 'username',
      passwordField: 'password',
      urlField: 'url',
      notesField: 'notes',
      ...additionalMappings,
    };

    return FieldMapping(
      fieldMap: fieldMap,
      requiredFields: ['title', 'username', 'password'],
    );
  }
}

/// Exception thrown during field mapping
class FieldMappingException implements Exception {
  final String message;

  FieldMappingException(this.message);

  @override
  String toString() => 'FieldMappingException: $message';
}
