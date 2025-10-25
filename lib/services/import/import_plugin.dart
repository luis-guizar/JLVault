import 'dart:io';
import '../../models/import_result.dart';

/// Abstract base class for import plugins
abstract class ImportPlugin {
  /// Unique identifier for this plugin
  String get pluginId;

  /// Human-readable name for this plugin
  String get displayName;

  /// Description of what this plugin imports
  String get description;

  /// Supported file extensions (e.g., ['.csv', '.json'])
  List<String> get supportedExtensions;

  /// MIME types supported by this plugin
  List<String> get supportedMimeTypes;

  /// Version of this plugin
  String get version;

  /// Whether this plugin supports TOTP import
  bool get supportsTOTP;

  /// Whether this plugin supports custom fields
  bool get supportsCustomFields;

  /// Validates if the file can be processed by this plugin
  Future<bool> canProcess(File file);

  /// Imports data from the specified file
  Future<ImportResult> import(File file, ImportOptions options);

  /// Gets default field mapping for this plugin
  FieldMapping getDefaultFieldMapping();

  /// Validates import options for this plugin
  bool validateOptions(ImportOptions options);

  /// Gets sample data format for documentation
  String getSampleFormat();
}

/// Registry for managing import plugins
class ImportPluginRegistry {
  static final ImportPluginRegistry _instance =
      ImportPluginRegistry._internal();
  factory ImportPluginRegistry() => _instance;
  ImportPluginRegistry._internal();

  final Map<String, ImportPlugin> _plugins = {};

  /// Registers a new import plugin
  void register(ImportPlugin plugin) {
    _plugins[plugin.pluginId] = plugin;
  }

  /// Unregisters an import plugin
  void unregister(String pluginId) {
    _plugins.remove(pluginId);
  }

  /// Gets all registered plugins
  List<ImportPlugin> getAllPlugins() {
    return _plugins.values.toList();
  }

  /// Gets plugin by ID
  ImportPlugin? getPlugin(String pluginId) {
    return _plugins[pluginId];
  }

  /// Finds plugins that can process the given file
  Future<List<ImportPlugin>> findCompatiblePlugins(File file) async {
    final compatible = <ImportPlugin>[];

    for (final plugin in _plugins.values) {
      if (await plugin.canProcess(file)) {
        compatible.add(plugin);
      }
    }

    return compatible;
  }

  /// Gets plugins that support specific file extension
  List<ImportPlugin> getPluginsByExtension(String extension) {
    return _plugins.values
        .where(
          (plugin) =>
              plugin.supportedExtensions.contains(extension.toLowerCase()),
        )
        .toList();
  }

  /// Gets plugins that support TOTP import
  List<ImportPlugin> getTOTPSupportedPlugins() {
    return _plugins.values.where((plugin) => plugin.supportsTOTP).toList();
  }
}

/// Exception thrown by import plugins
class ImportPluginException implements Exception {
  final String message;
  final String? pluginId;
  final dynamic originalError;

  ImportPluginException(this.message, {this.pluginId, this.originalError});

  @override
  String toString() {
    final prefix = pluginId != null ? '[$pluginId] ' : '';
    return 'ImportPluginException: $prefix$message';
  }
}
