import '../../models/export_result.dart';
import 'secure_export_service.dart';

/// Service for exporting password data in various formats
abstract class ExportService {
  /// Exports data to the specified file path with given options
  /// Requires biometric authentication for security
  Future<ExportResult> export(String filePath, ExportOptions options);

  /// Gets the file extension for the specified format
  String getFileExtension(ExportFormat format);

  /// Gets a human-readable description of the format
  String getFormatDescription(ExportFormat format);

  /// Validates export options for the specified format
  bool validateOptions(ExportOptions options);
}

/// Default implementation of ExportService using secure export
class DefaultExportService implements ExportService {
  final SecureExportService _secureService = SecureExportService();

  @override
  Future<ExportResult> export(String filePath, ExportOptions options) async {
    return await _secureService.export(filePath, options);
  }

  @override
  String getFileExtension(ExportFormat format) {
    return _secureService.getFileExtension(format);
  }

  @override
  String getFormatDescription(ExportFormat format) {
    return _secureService.getFormatDescription(format);
  }

  @override
  bool validateOptions(ExportOptions options) {
    return _secureService.validateOptions(options);
  }
}
