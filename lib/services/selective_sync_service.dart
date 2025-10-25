import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for managing selective vault sync configurations
class SelectiveSyncService {
  static const String _storageKeySyncConfig = 'selective_sync_config';
  static const String _storageKeyVaultPermissions = 'vault_permissions';

  final FlutterSecureStorage _storage;
  final Map<String, DeviceSyncConfig> _deviceConfigs = {};
  final Map<String, VaultSyncPermissions> _vaultPermissions = {};

  final StreamController<Map<String, DeviceSyncConfig>> _configController =
      StreamController<Map<String, DeviceSyncConfig>>.broadcast();

  SelectiveSyncService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// Stream of sync configuration changes
  Stream<Map<String, DeviceSyncConfig>> get configStream =>
      _configController.stream;

  /// Initialize the service
  Future<void> initialize() async {
    await _loadSyncConfigs();
    await _loadVaultPermissions();
  }

  /// Configure sync settings for a device
  Future<void> configureDeviceSync({
    required String deviceId,
    required List<String> enabledVaults,
    SyncFrequency frequency = SyncFrequency.automatic,
    List<String> excludedCategories = const [],
    bool enableBackgroundSync = true,
    bool enableConflictResolution = true,
  }) async {
    final config = DeviceSyncConfig(
      deviceId: deviceId,
      enabledVaults: enabledVaults,
      frequency: frequency,
      excludedCategories: excludedCategories,
      enableBackgroundSync: enableBackgroundSync,
      enableConflictResolution: enableConflictResolution,
      lastUpdated: DateTime.now(),
    );

    _deviceConfigs[deviceId] = config;
    await _saveSyncConfigs();
    _notifyConfigChanged();
  }

  /// Set vault permissions for a device
  Future<void> setVaultPermissions({
    required String vaultId,
    required String deviceId,
    required VaultPermissionLevel permission,
    List<String> allowedCategories = const [],
    List<String> excludedEntries = const [],
  }) async {
    final key = '${vaultId}_$deviceId';
    final permissions = VaultSyncPermissions(
      vaultId: vaultId,
      deviceId: deviceId,
      permission: permission,
      allowedCategories: allowedCategories,
      excludedEntries: excludedEntries,
      createdAt: DateTime.now(),
    );

    _vaultPermissions[key] = permissions;
    await _saveVaultPermissions();
  }

  /// Get sync configuration for a device
  DeviceSyncConfig? getDeviceConfig(String deviceId) {
    return _deviceConfigs[deviceId];
  }

  /// Get all device configurations
  Map<String, DeviceSyncConfig> getAllDeviceConfigs() {
    return Map.from(_deviceConfigs);
  }

  /// Get vault permissions for a device
  VaultSyncPermissions? getVaultPermissions(String vaultId, String deviceId) {
    final key = '${vaultId}_$deviceId';
    return _vaultPermissions[key];
  }

  /// Check if a vault is enabled for sync on a device
  bool isVaultEnabledForDevice(String vaultId, String deviceId) {
    final config = _deviceConfigs[deviceId];
    if (config == null) return false;

    return config.enabledVaults.contains(vaultId);
  }

  /// Check if a device has permission to sync a vault
  bool hasVaultPermission(String vaultId, String deviceId) {
    final permissions = getVaultPermissions(vaultId, deviceId);
    if (permissions == null) return false;

    return permissions.permission != VaultPermissionLevel.none;
  }

  /// Get vaults that a device can sync
  List<String> getEnabledVaultsForDevice(String deviceId) {
    final config = _deviceConfigs[deviceId];
    if (config == null) return [];

    return List.from(config.enabledVaults);
  }

  /// Get devices that can sync a vault
  List<String> getDevicesForVault(String vaultId) {
    return _deviceConfigs.entries
        .where((entry) => entry.value.enabledVaults.contains(vaultId))
        .map((entry) => entry.key)
        .toList();
  }

  /// Enable vault sync for a device
  Future<void> enableVaultForDevice(String vaultId, String deviceId) async {
    final config = _deviceConfigs[deviceId];
    if (config == null) {
      await configureDeviceSync(deviceId: deviceId, enabledVaults: [vaultId]);
    } else {
      final updatedVaults = List<String>.from(config.enabledVaults);
      if (!updatedVaults.contains(vaultId)) {
        updatedVaults.add(vaultId);
        await configureDeviceSync(
          deviceId: deviceId,
          enabledVaults: updatedVaults,
          frequency: config.frequency,
          excludedCategories: config.excludedCategories,
          enableBackgroundSync: config.enableBackgroundSync,
          enableConflictResolution: config.enableConflictResolution,
        );
      }
    }
  }

  /// Disable vault sync for a device
  Future<void> disableVaultForDevice(String vaultId, String deviceId) async {
    final config = _deviceConfigs[deviceId];
    if (config != null) {
      final updatedVaults = List<String>.from(config.enabledVaults);
      updatedVaults.remove(vaultId);

      await configureDeviceSync(
        deviceId: deviceId,
        enabledVaults: updatedVaults,
        frequency: config.frequency,
        excludedCategories: config.excludedCategories,
        enableBackgroundSync: config.enableBackgroundSync,
        enableConflictResolution: config.enableConflictResolution,
      );
    }
  }

  /// Get sync summary for all devices
  SelectiveSyncSummary getSyncSummary() {
    final totalDevices = _deviceConfigs.length;
    final activeDevices = _deviceConfigs.values
        .where((config) => config.enabledVaults.isNotEmpty)
        .length;

    final vaultSyncCounts = <String, int>{};
    for (final config in _deviceConfigs.values) {
      for (final vaultId in config.enabledVaults) {
        vaultSyncCounts[vaultId] = (vaultSyncCounts[vaultId] ?? 0) + 1;
      }
    }

    return SelectiveSyncSummary(
      totalDevices: totalDevices,
      activeDevices: activeDevices,
      vaultSyncCounts: vaultSyncCounts,
    );
  }

  /// Create sync filter for a device and vault
  SyncFilter createSyncFilter(String deviceId, String vaultId) {
    final config = _deviceConfigs[deviceId];
    final permissions = getVaultPermissions(vaultId, deviceId);

    return SyncFilter(
      deviceId: deviceId,
      vaultId: vaultId,
      isEnabled: config?.enabledVaults.contains(vaultId) ?? false,
      excludedCategories: config?.excludedCategories ?? [],
      allowedCategories: permissions?.allowedCategories ?? [],
      excludedEntries: permissions?.excludedEntries ?? [],
      permissionLevel: permissions?.permission ?? VaultPermissionLevel.none,
    );
  }

  /// Check if an entry should be synced based on filters
  bool shouldSyncEntry({
    required String deviceId,
    required String vaultId,
    required String entryId,
    String? category,
    Map<String, dynamic>? metadata,
  }) {
    final filter = createSyncFilter(deviceId, vaultId);

    // Check if vault sync is enabled
    if (!filter.isEnabled) return false;

    // Check permission level
    if (filter.permissionLevel == VaultPermissionLevel.none) return false;

    // Check if entry is explicitly excluded
    if (filter.excludedEntries.contains(entryId)) return false;

    // Check category filters
    if (category != null) {
      // If there are allowed categories, entry must be in one of them
      if (filter.allowedCategories.isNotEmpty &&
          !filter.allowedCategories.contains(category)) {
        return false;
      }

      // If category is excluded, don't sync
      if (filter.excludedCategories.contains(category)) return false;
    }

    // Check permission level restrictions
    switch (filter.permissionLevel) {
      case VaultPermissionLevel.readOnly:
        // Read-only devices can sync but not modify
        return true;
      case VaultPermissionLevel.readWrite:
        return true;
      case VaultPermissionLevel.limited:
        // Limited access based on categories and metadata
        return _checkLimitedAccess(filter, category, metadata);
      case VaultPermissionLevel.none:
        return false;
    }
  }

  /// Remove device configuration
  Future<void> removeDeviceConfig(String deviceId) async {
    _deviceConfigs.remove(deviceId);

    // Remove vault permissions for this device
    final keysToRemove = _vaultPermissions.keys
        .where((key) => key.endsWith('_$deviceId'))
        .toList();

    for (final key in keysToRemove) {
      _vaultPermissions.remove(key);
    }

    await _saveSyncConfigs();
    await _saveVaultPermissions();
    _notifyConfigChanged();
  }

  /// Export sync configuration
  Map<String, dynamic> exportSyncConfig() {
    return {
      'deviceConfigs': _deviceConfigs.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'vaultPermissions': _vaultPermissions.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Import sync configuration
  Future<void> importSyncConfig(Map<String, dynamic> config) async {
    try {
      // Import device configs
      if (config['deviceConfigs'] != null) {
        final deviceConfigsJson =
            config['deviceConfigs'] as Map<String, dynamic>;
        _deviceConfigs.clear();
        for (final entry in deviceConfigsJson.entries) {
          _deviceConfigs[entry.key] = DeviceSyncConfig.fromJson(entry.value);
        }
      }

      // Import vault permissions
      if (config['vaultPermissions'] != null) {
        final permissionsJson =
            config['vaultPermissions'] as Map<String, dynamic>;
        _vaultPermissions.clear();
        for (final entry in permissionsJson.entries) {
          _vaultPermissions[entry.key] = VaultSyncPermissions.fromJson(
            entry.value,
          );
        }
      }

      await _saveSyncConfigs();
      await _saveVaultPermissions();
      _notifyConfigChanged();
    } catch (e) {
      throw SelectiveSyncException(
        'Failed to import sync config: ${e.toString()}',
      );
    }
  }

  bool _checkLimitedAccess(
    SyncFilter filter,
    String? category,
    Map<String, dynamic>? metadata,
  ) {
    // Implement limited access logic based on metadata
    // This could include checks for sensitivity levels, tags, etc.
    return true; // Simplified for now
  }

  Future<void> _loadSyncConfigs() async {
    try {
      final configJson = await _storage.read(key: _storageKeySyncConfig);
      if (configJson != null) {
        final configMap = jsonDecode(configJson) as Map<String, dynamic>;
        _deviceConfigs.clear();
        for (final entry in configMap.entries) {
          _deviceConfigs[entry.key] = DeviceSyncConfig.fromJson(entry.value);
        }
      }
    } catch (e) {
      print('Error loading sync configs: $e');
    }
  }

  Future<void> _saveSyncConfigs() async {
    try {
      final configMap = _deviceConfigs.map(
        (key, value) => MapEntry(key, value.toJson()),
      );
      final configJson = jsonEncode(configMap);
      await _storage.write(key: _storageKeySyncConfig, value: configJson);
    } catch (e) {
      print('Error saving sync configs: $e');
    }
  }

  Future<void> _loadVaultPermissions() async {
    try {
      final permissionsJson = await _storage.read(
        key: _storageKeyVaultPermissions,
      );
      if (permissionsJson != null) {
        final permissionsMap =
            jsonDecode(permissionsJson) as Map<String, dynamic>;
        _vaultPermissions.clear();
        for (final entry in permissionsMap.entries) {
          _vaultPermissions[entry.key] = VaultSyncPermissions.fromJson(
            entry.value,
          );
        }
      }
    } catch (e) {
      print('Error loading vault permissions: $e');
    }
  }

  Future<void> _saveVaultPermissions() async {
    try {
      final permissionsMap = _vaultPermissions.map(
        (key, value) => MapEntry(key, value.toJson()),
      );
      final permissionsJson = jsonEncode(permissionsMap);
      await _storage.write(
        key: _storageKeyVaultPermissions,
        value: permissionsJson,
      );
    } catch (e) {
      print('Error saving vault permissions: $e');
    }
  }

  void _notifyConfigChanged() {
    if (!_configController.isClosed) {
      _configController.add(getAllDeviceConfigs());
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await _configController.close();
  }
}

/// Device sync configuration
class DeviceSyncConfig {
  final String deviceId;
  final List<String> enabledVaults;
  final SyncFrequency frequency;
  final List<String> excludedCategories;
  final bool enableBackgroundSync;
  final bool enableConflictResolution;
  final DateTime lastUpdated;

  const DeviceSyncConfig({
    required this.deviceId,
    required this.enabledVaults,
    required this.frequency,
    required this.excludedCategories,
    required this.enableBackgroundSync,
    required this.enableConflictResolution,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'enabledVaults': enabledVaults,
      'frequency': frequency.toString(),
      'excludedCategories': excludedCategories,
      'enableBackgroundSync': enableBackgroundSync,
      'enableConflictResolution': enableConflictResolution,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory DeviceSyncConfig.fromJson(Map<String, dynamic> json) {
    return DeviceSyncConfig(
      deviceId: json['deviceId'],
      enabledVaults: List<String>.from(json['enabledVaults']),
      frequency: SyncFrequency.values.firstWhere(
        (e) => e.toString() == json['frequency'],
        orElse: () => SyncFrequency.automatic,
      ),
      excludedCategories: List<String>.from(json['excludedCategories']),
      enableBackgroundSync: json['enableBackgroundSync'] ?? true,
      enableConflictResolution: json['enableConflictResolution'] ?? true,
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }
}

/// Vault sync permissions for a device
class VaultSyncPermissions {
  final String vaultId;
  final String deviceId;
  final VaultPermissionLevel permission;
  final List<String> allowedCategories;
  final List<String> excludedEntries;
  final DateTime createdAt;

  const VaultSyncPermissions({
    required this.vaultId,
    required this.deviceId,
    required this.permission,
    required this.allowedCategories,
    required this.excludedEntries,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'vaultId': vaultId,
      'deviceId': deviceId,
      'permission': permission.toString(),
      'allowedCategories': allowedCategories,
      'excludedEntries': excludedEntries,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory VaultSyncPermissions.fromJson(Map<String, dynamic> json) {
    return VaultSyncPermissions(
      vaultId: json['vaultId'],
      deviceId: json['deviceId'],
      permission: VaultPermissionLevel.values.firstWhere(
        (e) => e.toString() == json['permission'],
      ),
      allowedCategories: List<String>.from(json['allowedCategories']),
      excludedEntries: List<String>.from(json['excludedEntries']),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

/// Sync filter for determining what to sync
class SyncFilter {
  final String deviceId;
  final String vaultId;
  final bool isEnabled;
  final List<String> excludedCategories;
  final List<String> allowedCategories;
  final List<String> excludedEntries;
  final VaultPermissionLevel permissionLevel;

  const SyncFilter({
    required this.deviceId,
    required this.vaultId,
    required this.isEnabled,
    required this.excludedCategories,
    required this.allowedCategories,
    required this.excludedEntries,
    required this.permissionLevel,
  });
}

/// Sync frequency options
enum SyncFrequency { automatic, manual, scheduled, realtime }

/// Vault permission levels
enum VaultPermissionLevel { none, readOnly, readWrite, limited }

/// Summary of selective sync configuration
class SelectiveSyncSummary {
  final int totalDevices;
  final int activeDevices;
  final Map<String, int> vaultSyncCounts;

  const SelectiveSyncSummary({
    required this.totalDevices,
    required this.activeDevices,
    required this.vaultSyncCounts,
  });

  int get inactiveDevices => totalDevices - activeDevices;
  bool get hasActiveDevices => activeDevices > 0;
  List<String> get syncedVaults => vaultSyncCounts.keys.toList();
}

/// Exception thrown when selective sync operations fail
class SelectiveSyncException implements Exception {
  final String message;
  final dynamic originalError;

  const SelectiveSyncException(this.message, {this.originalError});

  @override
  String toString() {
    return 'SelectiveSyncException: $message';
  }
}
