import '../../../models/export_result.dart';

/// Abstract base class for export formatters
abstract class ExportFormatter {
  /// Formats the exported accounts into the target format
  Future<dynamic> format(List<ExportedAccount> accounts, ExportOptions options);

  /// Gets the MIME type for this format
  String get mimeType;

  /// Gets the file extension for this format
  String get fileExtension;

  /// Gets a human-readable description of this format
  String get description;

  /// Whether this format supports encryption
  bool get supportsEncryption;

  /// Whether this format supports custom fields
  bool get supportsCustomFields;

  /// Whether this format supports TOTP data
  bool get supportsTOTP;
}
