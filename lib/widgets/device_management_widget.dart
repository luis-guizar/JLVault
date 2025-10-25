import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sync_device.dart';
import '../services/device_manager.dart';
import '../services/sync_status_service.dart';

/// Widget for managing paired devices and sync status
class DeviceManagementWidget extends StatefulWidget {
  final DeviceManager deviceManager;
  final SyncStatusService syncStatusService;

  const DeviceManagementWidget({
    super.key,
    required this.deviceManager,
    required this.syncStatusService,
  });

  @override
  State<DeviceManagementWidget> createState() => _DeviceManagementWidgetState();
}

class _DeviceManagementWidgetState extends State<DeviceManagementWidget> {
  List<SyncDevice> _pairedDevices = [];
  Map<String, DeviceSyncStatus> _deviceStatus = {};

  StreamSubscription? _devicesSubscription;
  StreamSubscription? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _setupListeners();
  }

  void _loadDevices() {
    setState(() {
      _pairedDevices = widget.deviceManager.getPairedDevices();
      _deviceStatus = widget.syncStatusService.getAllDeviceStatus();
    });
  }

  void _setupListeners() {
    _devicesSubscription = widget.deviceManager.pairedDevices.listen((devices) {
      if (mounted) {
        setState(() {
          _pairedDevices = devices;
        });
      }
    });

    _statusSubscription = widget.syncStatusService.statusStream.listen((
      status,
    ) {
      if (mounted) {
        setState(() {
          _deviceStatus = status;
        });
      }
    });
  }

  @override
  void dispose() {
    _devicesSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildSyncHealth(),
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
          'Paired Devices',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          '${_pairedDevices.length} devices',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSyncHealth() {
    final health = widget.syncStatusService.getOverallSyncHealth();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getHealthIcon(health.healthLevel),
                  color: _getHealthColor(health.healthLevel),
                ),
                const SizedBox(width: 8),
                Text(
                  'Sync Health: ${_getHealthText(health.healthLevel)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _getHealthColor(health.healthLevel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHealthStat(
                  'Online',
                  '${health.onlineDevices}/${health.totalDevices}',
                  Icons.devices,
                  Colors.green,
                ),
                _buildHealthStat(
                  'Recent Failures',
                  '${health.recentFailures}',
                  Icons.error,
                  health.recentFailures > 0 ? Colors.red : Colors.grey,
                ),
                _buildHealthStat(
                  'Pending',
                  health.oldestPendingSync != null ? '1+' : '0',
                  Icons.schedule,
                  health.oldestPendingSync != null
                      ? Colors.orange
                      : Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildDevicesList() {
    if (_pairedDevices.isEmpty) {
      return _buildEmptyState();
    }

    return Expanded(
      child: ListView.builder(
        itemCount: _pairedDevices.length,
        itemBuilder: (context, index) {
          final device = _pairedDevices[index];
          final status = _deviceStatus[device.id];
          return _buildDeviceCard(device, status);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.devices_other, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Paired Devices',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Pair with other devices to enable sync',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(SyncDevice device, DeviceSyncStatus? status) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getDeviceStatusColor(status?.state),
          child: Icon(_getDeviceIcon(device.type), color: Colors.white),
        ),
        title: Text(
          device.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${device.address}:${device.port}'),
            if (status != null) ...[
              const SizedBox(height: 4),
              _buildStatusRow(status),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleDeviceAction(device, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'sync',
              child: ListTile(
                leading: Icon(Icons.sync),
                title: Text('Sync Now'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'rename',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Rename'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'history',
              child: ListTile(
                leading: Icon(Icons.history),
                title: Text('Sync History'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'unpair',
              child: ListTile(
                leading: Icon(Icons.link_off, color: Colors.red),
                title: Text('Unpair', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        onTap: () => _showDeviceDetails(device, status),
      ),
    );
  }

  Widget _buildStatusRow(DeviceSyncStatus status) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _getDeviceStatusColor(status.state),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _getStatusText(status),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _getDeviceStatusColor(status.state),
            ),
          ),
        ),
        if (status.progress > 0 && status.progress < 1) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            height: 4,
            child: LinearProgressIndicator(
              value: status.progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getDeviceStatusColor(status.state) ?? Colors.blue,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _handleDeviceAction(SyncDevice device, String action) {
    switch (action) {
      case 'sync':
        _syncDevice(device);
        break;
      case 'rename':
        _renameDevice(device);
        break;
      case 'history':
        _showSyncHistory(device);
        break;
      case 'unpair':
        _unpairDevice(device);
        break;
    }
  }

  void _syncDevice(SyncDevice device) {
    // This would trigger a sync with the device
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Starting sync with ${device.name}...')),
    );
  }

  void _renameDevice(SyncDevice device) {
    showDialog(
      context: context,
      builder: (context) => _RenameDeviceDialog(
        device: device,
        onRenamed: (newName) {
          widget.deviceManager.renameDevice(device.id, newName);
        },
      ),
    );
  }

  void _showSyncHistory(SyncDevice device) {
    showDialog(
      context: context,
      builder: (context) => _SyncHistoryDialog(
        device: device,
        syncStatusService: widget.syncStatusService,
      ),
    );
  }

  void _unpairDevice(SyncDevice device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpair Device'),
        content: Text('Are you sure you want to unpair "${device.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.deviceManager.unpairDevice(device.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Unpaired ${device.name}')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );
  }

  void _showDeviceDetails(SyncDevice device, DeviceSyncStatus? status) {
    showDialog(
      context: context,
      builder: (context) => _DeviceDetailsDialog(
        device: device,
        status: status,
        syncStatusService: widget.syncStatusService,
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

  Color? _getDeviceStatusColor(SyncState? state) {
    switch (state) {
      case SyncState.syncing:
        return Colors.blue;
      case SyncState.completed:
        return Colors.green;
      case SyncState.failed:
        return Colors.red;
      case SyncState.offline:
        return Colors.grey;
      case SyncState.queued:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(DeviceSyncStatus status) {
    switch (status.state) {
      case SyncState.idle:
        return 'Ready';
      case SyncState.queued:
        return 'Queued for sync';
      case SyncState.syncing:
        return status.message ?? 'Syncing...';
      case SyncState.completed:
        return 'Last sync: ${_formatTimestamp(status.lastUpdated)}';
      case SyncState.failed:
        return status.error ?? 'Sync failed';
      case SyncState.offline:
        return 'Offline';
      case SyncState.cancelled:
        return 'Sync cancelled';
    }
  }

  IconData _getHealthIcon(SyncHealthLevel level) {
    switch (level) {
      case SyncHealthLevel.excellent:
        return Icons.check_circle;
      case SyncHealthLevel.good:
        return Icons.check_circle_outline;
      case SyncHealthLevel.fair:
        return Icons.warning;
      case SyncHealthLevel.poor:
        return Icons.error;
    }
  }

  Color _getHealthColor(SyncHealthLevel level) {
    switch (level) {
      case SyncHealthLevel.excellent:
        return Colors.green;
      case SyncHealthLevel.good:
        return Colors.lightGreen;
      case SyncHealthLevel.fair:
        return Colors.orange;
      case SyncHealthLevel.poor:
        return Colors.red;
    }
  }

  String _getHealthText(SyncHealthLevel level) {
    switch (level) {
      case SyncHealthLevel.excellent:
        return 'Excellent';
      case SyncHealthLevel.good:
        return 'Good';
      case SyncHealthLevel.fair:
        return 'Fair';
      case SyncHealthLevel.poor:
        return 'Poor';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

/// Dialog for renaming a device
class _RenameDeviceDialog extends StatefulWidget {
  final SyncDevice device;
  final Function(String) onRenamed;

  const _RenameDeviceDialog({required this.device, required this.onRenamed});

  @override
  State<_RenameDeviceDialog> createState() => _RenameDeviceDialogState();
}

class _RenameDeviceDialogState extends State<_RenameDeviceDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.device.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Device'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Device Name',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final newName = _controller.text.trim();
            if (newName.isNotEmpty && newName != widget.device.name) {
              widget.onRenamed(newName);
            }
            Navigator.of(context).pop();
          },
          child: const Text('Rename'),
        ),
      ],
    );
  }
}

/// Dialog for showing sync history
class _SyncHistoryDialog extends StatelessWidget {
  final SyncDevice device;
  final SyncStatusService syncStatusService;

  const _SyncHistoryDialog({
    required this.device,
    required this.syncStatusService,
  });

  @override
  Widget build(BuildContext context) {
    final history = syncStatusService.getSyncHistory(
      deviceId: device.id,
      limit: 50,
    );
    final statistics = syncStatusService.getDeviceStatistics(device.id);

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sync History - ${device.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildStatistics(context, statistics),
            const SizedBox(height: 16),
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: history.isEmpty
                  ? const Center(child: Text('No sync history'))
                  : ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final entry = history[index];
                        return _buildHistoryEntry(context, entry);
                      },
                    ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics(BuildContext context, SyncStatistics stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(context, 'Total', '${stats.totalSyncs}', Icons.sync),
            _buildStatItem(
              context,
              'Success',
              '${stats.successfulSyncs}',
              Icons.check_circle,
              Colors.green,
            ),
            _buildStatItem(
              context,
              'Failed',
              '${stats.failedSyncs}',
              Icons.error,
              Colors.red,
            ),
            _buildStatItem(
              context,
              'Success Rate',
              '${(stats.successRate * 100).toInt()}%',
              Icons.trending_up,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon, [
    Color? color,
  ]) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.grey[600], size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildHistoryEntry(BuildContext context, SyncHistoryEntry entry) {
    return ListTile(
      leading: Icon(
        _getStateIcon(entry.state),
        color: _getStateColor(entry.state),
      ),
      title: Text(_getStateText(entry.state)),
      subtitle: Text(_formatTimestamp(entry.timestamp)),
      trailing: entry.duration != null
          ? Text('${entry.duration! ~/ 1000}s')
          : null,
    );
  }

  IconData _getStateIcon(SyncState state) {
    switch (state) {
      case SyncState.completed:
        return Icons.check_circle;
      case SyncState.failed:
        return Icons.error;
      case SyncState.syncing:
        return Icons.sync;
      default:
        return Icons.circle;
    }
  }

  Color _getStateColor(SyncState state) {
    switch (state) {
      case SyncState.completed:
        return Colors.green;
      case SyncState.failed:
        return Colors.red;
      case SyncState.syncing:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStateText(SyncState state) {
    switch (state) {
      case SyncState.completed:
        return 'Sync completed';
      case SyncState.failed:
        return 'Sync failed';
      case SyncState.syncing:
        return 'Sync started';
      default:
        return state.toString();
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

/// Dialog for showing device details
class _DeviceDetailsDialog extends StatelessWidget {
  final SyncDevice device;
  final DeviceSyncStatus? status;
  final SyncStatusService syncStatusService;

  const _DeviceDetailsDialog({
    required this.device,
    this.status,
    required this.syncStatusService,
  });

  @override
  Widget build(BuildContext context) {
    final statistics = syncStatusService.getDeviceStatistics(device.id);

    return AlertDialog(
      title: Text(device.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Device ID', device.id),
          _buildDetailRow('Address', '${device.address}:${device.port}'),
          _buildDetailRow('Type', device.type),
          _buildDetailRow('Discovered', _formatDate(device.discoveredAt)),
          if (status != null) ...[
            const SizedBox(height: 16),
            Text(
              'Current Status',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildDetailRow('State', status!.state.toString()),
            _buildDetailRow('Last Updated', _formatDate(status!.lastUpdated)),
            if (status!.lastSuccessfulSync != null)
              _buildDetailRow(
                'Last Sync',
                _formatDate(status!.lastSuccessfulSync!),
              ),
          ],
          const SizedBox(height: 16),
          Text(
            'Statistics',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildDetailRow('Total Syncs', '${statistics.totalSyncs}'),
          _buildDetailRow(
            'Success Rate',
            '${(statistics.successRate * 100).toInt()}%',
          ),
          _buildDetailRow(
            'Avg Duration',
            '${statistics.averageSyncDuration.inSeconds}s',
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
