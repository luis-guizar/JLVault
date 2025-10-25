import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sync_device.dart';
import '../services/selective_sync_service.dart';

/// Widget for configuring selective vault sync settings
class SelectiveSyncWidget extends StatefulWidget {
  final List<SyncDevice> pairedDevices;
  final List<String> availableVaults;
  final SelectiveSyncService selectiveSyncService;

  const SelectiveSyncWidget({
    super.key,
    required this.pairedDevices,
    required this.availableVaults,
    required this.selectiveSyncService,
  });

  @override
  State<SelectiveSyncWidget> createState() => _SelectiveSyncWidgetState();
}

class _SelectiveSyncWidgetState extends State<SelectiveSyncWidget> {
  Map<String, DeviceSyncConfig> _deviceConfigs = {};
  StreamSubscription? _configSubscription;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
    _setupListeners();
  }

  void _loadConfigs() {
    setState(() {
      _deviceConfigs = widget.selectiveSyncService.getAllDeviceConfigs();
    });
  }

  void _setupListeners() {
    _configSubscription = widget.selectiveSyncService.configStream.listen((
      configs,
    ) {
      if (mounted) {
        setState(() {
          _deviceConfigs = configs;
        });
      }
    });
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildSyncSummary(),
        const SizedBox(height: 16),
        _buildDevicesList(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Selective Sync Settings',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        IconButton(
          onPressed: _showGlobalSettings,
          icon: const Icon(Icons.settings),
          tooltip: 'Global Settings',
        ),
      ],
    );
  }

  Widget _buildSyncSummary() {
    final summary = widget.selectiveSyncService.getSyncSummary();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sync Overview',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  'Active Devices',
                  '${summary.activeDevices}/${summary.totalDevices}',
                  Icons.devices,
                  summary.hasActiveDevices ? Colors.green : Colors.grey,
                ),
                _buildSummaryItem(
                  'Synced Vaults',
                  '${summary.syncedVaults.length}',
                  Icons.folder_shared,
                  summary.syncedVaults.isNotEmpty ? Colors.blue : Colors.grey,
                ),
                _buildSummaryItem(
                  'Inactive',
                  '${summary.inactiveDevices}',
                  Icons.devices_other,
                  summary.inactiveDevices > 0 ? Colors.orange : Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildDevicesList() {
    if (widget.pairedDevices.isEmpty) {
      return _buildEmptyState();
    }

    return Expanded(
      child: ListView.builder(
        itemCount: widget.pairedDevices.length,
        itemBuilder: (context, index) {
          final device = widget.pairedDevices[index];
          final config = _deviceConfigs[device.id];
          return _buildDeviceCard(device, config);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sync_disabled, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Paired Devices',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Pair devices to configure selective sync',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(SyncDevice device, DeviceSyncConfig? config) {
    final enabledVaults = config?.enabledVaults ?? [];
    final isActive = enabledVaults.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.green : Colors.grey,
          child: Icon(_getDeviceIcon(device.type), color: Colors.white),
        ),
        title: Text(
          device.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          isActive ? '${enabledVaults.length} vaults syncing' : 'Sync disabled',
        ),
        trailing: Switch(
          value: isActive,
          onChanged: (enabled) => _toggleDeviceSync(device, enabled),
        ),
        children: [_buildDeviceSettings(device, config)],
      ),
    );
  }

  Widget _buildDeviceSettings(SyncDevice device, DeviceSyncConfig? config) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vault Selection',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildVaultSelection(device, config),
          const SizedBox(height: 16),
          Text(
            'Sync Settings',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildSyncSettings(device, config),
          const SizedBox(height: 16),
          _buildActionButtons(device),
        ],
      ),
    );
  }

  Widget _buildVaultSelection(SyncDevice device, DeviceSyncConfig? config) {
    final enabledVaults = config?.enabledVaults ?? [];

    return Column(
      children: widget.availableVaults.map((vaultId) {
        final isEnabled = enabledVaults.contains(vaultId);
        return CheckboxListTile(
          title: Text(_getVaultDisplayName(vaultId)),
          subtitle: Text(_getVaultDescription(vaultId)),
          value: isEnabled,
          onChanged: (enabled) =>
              _toggleVaultSync(device, vaultId, enabled ?? false),
          secondary: Icon(
            Icons.folder,
            color: isEnabled ? Colors.blue : Colors.grey,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSyncSettings(SyncDevice device, DeviceSyncConfig? config) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.schedule),
          title: const Text('Sync Frequency'),
          subtitle: Text(
            _getFrequencyText(config?.frequency ?? SyncFrequency.automatic),
          ),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => _showFrequencySettings(device, config),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.cloud_sync),
          title: const Text('Background Sync'),
          subtitle: const Text('Sync when app is in background'),
          value: config?.enableBackgroundSync ?? true,
          onChanged: (enabled) => _updateBackgroundSync(device, enabled),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.merge_type),
          title: const Text('Auto Conflict Resolution'),
          subtitle: const Text('Automatically resolve sync conflicts'),
          value: config?.enableConflictResolution ?? true,
          onChanged: (enabled) => _updateConflictResolution(device, enabled),
        ),
      ],
    );
  }

  Widget _buildActionButtons(SyncDevice device) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton.icon(
          onPressed: () => _showAdvancedSettings(device),
          icon: const Icon(Icons.tune),
          label: const Text('Advanced'),
        ),
        TextButton.icon(
          onPressed: () => _resetDeviceConfig(device),
          icon: const Icon(Icons.refresh),
          label: const Text('Reset'),
        ),
      ],
    );
  }

  void _toggleDeviceSync(SyncDevice device, bool enabled) async {
    if (enabled) {
      // Enable sync with default settings
      await widget.selectiveSyncService.configureDeviceSync(
        deviceId: device.id,
        enabledVaults: widget.availableVaults,
      );
    } else {
      // Disable sync by removing all vaults
      await widget.selectiveSyncService.configureDeviceSync(
        deviceId: device.id,
        enabledVaults: [],
      );
    }
  }

  void _toggleVaultSync(SyncDevice device, String vaultId, bool enabled) async {
    if (enabled) {
      await widget.selectiveSyncService.enableVaultForDevice(
        vaultId,
        device.id,
      );
    } else {
      await widget.selectiveSyncService.disableVaultForDevice(
        vaultId,
        device.id,
      );
    }
  }

  void _updateBackgroundSync(SyncDevice device, bool enabled) async {
    final config = _deviceConfigs[device.id];
    if (config != null) {
      await widget.selectiveSyncService.configureDeviceSync(
        deviceId: device.id,
        enabledVaults: config.enabledVaults,
        frequency: config.frequency,
        excludedCategories: config.excludedCategories,
        enableBackgroundSync: enabled,
        enableConflictResolution: config.enableConflictResolution,
      );
    }
  }

  void _updateConflictResolution(SyncDevice device, bool enabled) async {
    final config = _deviceConfigs[device.id];
    if (config != null) {
      await widget.selectiveSyncService.configureDeviceSync(
        deviceId: device.id,
        enabledVaults: config.enabledVaults,
        frequency: config.frequency,
        excludedCategories: config.excludedCategories,
        enableBackgroundSync: config.enableBackgroundSync,
        enableConflictResolution: enabled,
      );
    }
  }

  void _showFrequencySettings(SyncDevice device, DeviceSyncConfig? config) {
    showDialog(
      context: context,
      builder: (context) => _FrequencySettingsDialog(
        device: device,
        currentFrequency: config?.frequency ?? SyncFrequency.automatic,
        onFrequencyChanged: (frequency) =>
            _updateSyncFrequency(device, frequency),
      ),
    );
  }

  void _updateSyncFrequency(SyncDevice device, SyncFrequency frequency) async {
    final config = _deviceConfigs[device.id];
    if (config != null) {
      await widget.selectiveSyncService.configureDeviceSync(
        deviceId: device.id,
        enabledVaults: config.enabledVaults,
        frequency: frequency,
        excludedCategories: config.excludedCategories,
        enableBackgroundSync: config.enableBackgroundSync,
        enableConflictResolution: config.enableConflictResolution,
      );
    }
  }

  void _showAdvancedSettings(SyncDevice device) {
    showDialog(
      context: context,
      builder: (context) => _AdvancedSyncSettingsDialog(
        device: device,
        selectiveSyncService: widget.selectiveSyncService,
        availableVaults: widget.availableVaults,
      ),
    );
  }

  void _resetDeviceConfig(SyncDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Sync Settings'),
        content: Text('Reset all sync settings for "${device.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.selectiveSyncService.removeDeviceConfig(device.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset sync settings for ${device.name}')),
      );
    }
  }

  void _showGlobalSettings() {
    showDialog(
      context: context,
      builder: (context) => _GlobalSyncSettingsDialog(
        selectiveSyncService: widget.selectiveSyncService,
      ),
    );
  }

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'android':
        return Icons.android;
      case 'ios':
        return Icons.phone_iphone;
      case 'desktop':
        return Icons.desktop_windows;
      default:
        return Icons.devices;
    }
  }

  String _getVaultDisplayName(String vaultId) {
    // In a real app, this would fetch the actual vault name
    return 'Vault ${vaultId.substring(0, 8)}...';
  }

  String _getVaultDescription(String vaultId) {
    // In a real app, this would show vault statistics
    return 'Personal vault with passwords';
  }

  String _getFrequencyText(SyncFrequency frequency) {
    switch (frequency) {
      case SyncFrequency.automatic:
        return 'Automatic';
      case SyncFrequency.manual:
        return 'Manual only';
      case SyncFrequency.scheduled:
        return 'Scheduled';
      case SyncFrequency.realtime:
        return 'Real-time';
    }
  }
}

/// Dialog for configuring sync frequency
class _FrequencySettingsDialog extends StatefulWidget {
  final SyncDevice device;
  final SyncFrequency currentFrequency;
  final Function(SyncFrequency) onFrequencyChanged;

  const _FrequencySettingsDialog({
    required this.device,
    required this.currentFrequency,
    required this.onFrequencyChanged,
  });

  @override
  State<_FrequencySettingsDialog> createState() =>
      _FrequencySettingsDialogState();
}

class _FrequencySettingsDialogState extends State<_FrequencySettingsDialog> {
  late SyncFrequency _selectedFrequency;

  @override
  void initState() {
    super.initState();
    _selectedFrequency = widget.currentFrequency;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Sync Frequency - ${widget.device.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: SyncFrequency.values.map((frequency) {
          return RadioListTile<SyncFrequency>(
            title: Text(_getFrequencyTitle(frequency)),
            subtitle: Text(_getFrequencyDescription(frequency)),
            value: frequency,
            groupValue: _selectedFrequency,
            onChanged: (value) {
              setState(() {
                _selectedFrequency = value!;
              });
            },
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onFrequencyChanged(_selectedFrequency);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  String _getFrequencyTitle(SyncFrequency frequency) {
    switch (frequency) {
      case SyncFrequency.automatic:
        return 'Automatic';
      case SyncFrequency.manual:
        return 'Manual Only';
      case SyncFrequency.scheduled:
        return 'Scheduled';
      case SyncFrequency.realtime:
        return 'Real-time';
    }
  }

  String _getFrequencyDescription(SyncFrequency frequency) {
    switch (frequency) {
      case SyncFrequency.automatic:
        return 'Sync when changes are detected';
      case SyncFrequency.manual:
        return 'Only sync when manually triggered';
      case SyncFrequency.scheduled:
        return 'Sync at regular intervals';
      case SyncFrequency.realtime:
        return 'Sync immediately on changes';
    }
  }
}

/// Dialog for advanced sync settings
class _AdvancedSyncSettingsDialog extends StatelessWidget {
  final SyncDevice device;
  final SelectiveSyncService selectiveSyncService;
  final List<String> availableVaults;

  const _AdvancedSyncSettingsDialog({
    required this.device,
    required this.selectiveSyncService,
    required this.availableVaults,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Advanced Settings - ${device.name}'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.category),
            title: Text('Category Filters'),
            subtitle: Text('Configure which categories to sync'),
          ),
          ListTile(
            leading: Icon(Icons.security),
            title: Text('Permission Levels'),
            subtitle: Text('Set vault access permissions'),
          ),
          ListTile(
            leading: Icon(Icons.schedule),
            title: Text('Sync Schedule'),
            subtitle: Text('Configure sync timing'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Dialog for global sync settings
class _GlobalSyncSettingsDialog extends StatelessWidget {
  final SelectiveSyncService selectiveSyncService;

  const _GlobalSyncSettingsDialog({required this.selectiveSyncService});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Global Sync Settings'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.import_export),
            title: Text('Export Configuration'),
            subtitle: Text('Export sync settings to file'),
          ),
          ListTile(
            leading: Icon(Icons.file_download),
            title: Text('Import Configuration'),
            subtitle: Text('Import sync settings from file'),
          ),
          ListTile(
            leading: Icon(Icons.refresh),
            title: Text('Reset All Settings'),
            subtitle: Text('Reset all device sync configurations'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
