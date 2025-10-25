import '../../models/import_result.dart';

/// Service for validating imported data
class ImportValidator {
  /// Validates an imported account
  static List<ImportError> validateAccount(
    ImportedAccount account,
    int? lineNumber,
  ) {
    final errors = <ImportError>[];

    // Validate title
    if (account.title.trim().isEmpty) {
      errors.add(
        ImportError(
          lineNumber: lineNumber,
          message: 'Account title cannot be empty',
          type: ImportErrorType.validationError,
        ),
      );
    }

    // Validate username
    if (account.username.trim().isEmpty) {
      errors.add(
        ImportError(
          lineNumber: lineNumber,
          message: 'Username cannot be empty',
          type: ImportErrorType.validationError,
        ),
      );
    }

    // Validate password
    if (account.password.trim().isEmpty) {
      errors.add(
        ImportError(
          lineNumber: lineNumber,
          message: 'Password cannot be empty',
          type: ImportErrorType.validationError,
        ),
      );
    }

    // Validate password strength (basic check)
    if (account.password.length < 4) {
      errors.add(
        ImportError(
          lineNumber: lineNumber,
          message: 'Password is too short (minimum 4 characters)',
          type: ImportErrorType.validationError,
        ),
      );
    }

    // Validate URL format if provided
    if (account.url != null && account.url!.isNotEmpty) {
      if (!_isValidUrl(account.url!)) {
        errors.add(
          ImportError(
            lineNumber: lineNumber,
            message: 'Invalid URL format: ${account.url}',
            type: ImportErrorType.validationError,
          ),
        );
      }
    }

    // Validate TOTP data if provided
    if (account.totpData != null) {
      errors.addAll(_validateTOTPData(account.totpData!, lineNumber));
    }

    // Validate custom fields
    for (final field in account.customFields) {
      errors.addAll(_validateCustomField(field, lineNumber));
    }

    return errors;
  }

  /// Validates TOTP data
  static List<ImportError> _validateTOTPData(
    TOTPData totpData,
    int? lineNumber,
  ) {
    final errors = <ImportError>[];

    // Validate secret
    if (totpData.secret.trim().isEmpty) {
      errors.add(
        ImportError(
          lineNumber: lineNumber,
          message: 'TOTP secret cannot be empty',
          type: ImportErrorType.validationError,
        ),
      );
    } else if (!_isValidBase32(totpData.secret)) {
      errors.add(
        ImportError(
          lineNumber: lineNumber,
          message: 'TOTP secret must be valid Base32',
          type: ImportErrorType.validationError,
        ),
      );
    }

    // Validate digits
    if (totpData.digits < 4 || totpData.digits > 10) {
      errors.add(
        ImportError(
          lineNumber: lineNumber,
          message: 'TOTP digits must be between 4 and 10',
          type: ImportErrorType.validationError,
        ),
      );
    }

    // Validate period
    if (totpData.period < 15 || totpData.period > 300) {
      errors.add(
        ImportError(
          lineNumber: lineNumber,
          message: 'TOTP period must be between 15 and 300 seconds',
          type: ImportErrorType.validationError,
        ),
      );
    }

    // Validate algorithm
    final validAlgorithms = ['SHA1', 'SHA256', 'SHA512'];
    if (!validAlgorithms.contains(totpData.algorithm.toUpperCase())) {
      errors.add(
        ImportError(
          lineNumber: lineNumber,
          message:
              'TOTP algorithm must be one of: ${validAlgorithms.join(', ')}',
          type: ImportErrorType.validationError,
        ),
      );
    }

    return errors;
  }

  /// Validates custom field
  static List<ImportError> _validateCustomField(
    CustomField field,
    int? lineNumber,
  ) {
    final errors = <ImportError>[];

    // Validate field name
    if (field.name.trim().isEmpty) {
      errors.add(
        ImportError(
          lineNumber: lineNumber,
          message: 'Custom field name cannot be empty',
          type: ImportErrorType.validationError,
        ),
      );
    }

    // Validate field value based on type
    switch (field.type) {
      case CustomFieldType.email:
        if (field.value.isNotEmpty && !_isValidEmail(field.value)) {
          errors.add(
            ImportError(
              lineNumber: lineNumber,
              message:
                  'Invalid email format in custom field "${field.name}": ${field.value}',
              type: ImportErrorType.validationError,
            ),
          );
        }
        break;
      case CustomFieldType.url:
        if (field.value.isNotEmpty && !_isValidUrl(field.value)) {
          errors.add(
            ImportError(
              lineNumber: lineNumber,
              message:
                  'Invalid URL format in custom field "${field.name}": ${field.value}',
              type: ImportErrorType.validationError,
            ),
          );
        }
        break;
      case CustomFieldType.number:
        if (field.value.isNotEmpty && double.tryParse(field.value) == null) {
          errors.add(
            ImportError(
              lineNumber: lineNumber,
              message:
                  'Invalid number format in custom field "${field.name}": ${field.value}',
              type: ImportErrorType.validationError,
            ),
          );
        }
        break;
      case CustomFieldType.date:
        if (field.value.isNotEmpty && DateTime.tryParse(field.value) == null) {
          errors.add(
            ImportError(
              lineNumber: lineNumber,
              message:
                  'Invalid date format in custom field "${field.name}": ${field.value}',
              type: ImportErrorType.validationError,
            ),
          );
        }
        break;
      default:
        // No specific validation for text and password types
        break;
    }

    return errors;
  }

  /// Validates URL format
  static bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Validates email format
  static bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Validates Base32 format for TOTP secrets
  static bool _isValidBase32(String secret) {
    final base32Regex = RegExp(r'^[A-Z2-7]+=*$');
    return base32Regex.hasMatch(secret.toUpperCase());
  }

  /// Validates import options
  static List<ImportError> validateImportOptions(ImportOptions options) {
    final errors = <ImportError>[];

    // Validate target vault ID
    if (options.targetVaultId.trim().isEmpty) {
      errors.add(
        ImportError(
          message: 'Target vault ID cannot be empty',
          type: ImportErrorType.validationError,
        ),
      );
    }

    // Validate custom field mapping if provided
    if (options.customFieldMapping != null) {
      final mapping = options.customFieldMapping!;

      // Check for empty field mappings
      for (final entry in mapping.fieldMap.entries) {
        if (entry.key.trim().isEmpty || entry.value.trim().isEmpty) {
          errors.add(
            ImportError(
              message: 'Field mapping cannot have empty keys or values',
              type: ImportErrorType.validationError,
            ),
          );
        }
      }

      // Check for required fields in mapping
      for (final requiredField in mapping.requiredFields) {
        if (!mapping.fieldMap.containsValue(requiredField)) {
          errors.add(
            ImportError(
              message:
                  'Required field "$requiredField" not found in field mapping',
              type: ImportErrorType.validationError,
            ),
          );
        }
      }
    }

    return errors;
  }

  /// Sanitizes imported data to prevent security issues
  static ImportedAccount sanitizeAccount(ImportedAccount account) {
    return ImportedAccount(
      title: _sanitizeString(account.title),
      username: _sanitizeString(account.username),
      password: account.password, // Don't sanitize passwords
      url: account.url != null ? _sanitizeUrl(account.url!) : null,
      notes: account.notes != null ? _sanitizeString(account.notes!) : null,
      customFields: account.customFields.map(_sanitizeCustomField).toList(),
      totpData: account.totpData,
      createdAt: account.createdAt,
      modifiedAt: account.modifiedAt,
      tags: account.tags.map(_sanitizeString).toList(),
      category: account.category != null
          ? _sanitizeString(account.category!)
          : null,
      metadata: account.metadata,
    );
  }

  /// Sanitizes string input
  static String _sanitizeString(String input) {
    return input.trim().replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  /// Sanitizes URL input
  static String _sanitizeUrl(String url) {
    final sanitized = _sanitizeString(url);
    // Ensure URL starts with http:// or https://
    if (!sanitized.startsWith('http://') && !sanitized.startsWith('https://')) {
      return 'https://$sanitized';
    }
    return sanitized;
  }

  /// Sanitizes custom field
  static CustomField _sanitizeCustomField(CustomField field) {
    return CustomField(
      name: _sanitizeString(field.name),
      value: field.type == CustomFieldType.password
          ? field.value
          : _sanitizeString(field.value),
      type: field.type,
    );
  }
}
