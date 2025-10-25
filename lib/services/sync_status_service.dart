import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for tracking sync status and progress across devices
class SyncStatusService {
  static const String _storageKeySyncHistory = 'sync_history';
  static const String _storageKeyDeviceStatus = 'device_sync_status';

  final FlutterSecureStorage _storage;
  final Map<String, DeviceSyncStatus> _deviceStatus = {};
  final List<SyncHistoryEntry> _syncHistory = [];

  final StreamController<Map<String, DeviceSyncStatus>> _statusController =
      StreamController<Map<String, DeviceSyncStatus>>.broadcast();
  final StreamController<SyncHistoryEntry> _historyController =
      StreamController<SyncHistoryEntry>.broadcast();

  Timer? _statusUpdateTimer;

  SyncStatusService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// Stream of device sync status changes
  Stream<Map<String, DeviceSyncStatus>> get statusStream =>
      _statusController.stream;

  /// Stream of sync history entries
  Stream<SyncHistoryEntry> get historyStream => _historyController.stream;

  /// Initialize the service
  Future<void> initialize() async {
    await _loadDeviceStatus();
    await _loadSyncHistory();
    _startStatusUpdateTimer();
  }

  /// Update sync status for a device
  Future<void> updateDeviceStatus({
    required String deviceId,
    required SyncState state,
    String? vaultId,
    double? progress,
    String? message,
    String? error,
  }) async {
    final currentStatus = _deviceStatus[deviceId];
    final newStatus = DeviceSyncStatus(
      deviceId: deviceId,
      state: state,
      vaultId: vaultId,
      progress: progress ?? 0.0,
      message: message,
      error: error,
      lastUpdated: DateTime.now(),
      lastSuccessfulSync: state == SyncState.completed
          ? DateTime.now()
          : currentStatus?.lastSuccessfulSync,
    );

    _deviceStatus[deviceId] = newStatus;
    await _saveDeviceStatus();
    _notifyStatusChanged();

    // Add to history if it's a significant state change
    if (_isSignificantStateChange(currentStatus?.state, state)) {
      await _addHistoryEntry(
        SyncHistoryEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          deviceId: deviceId,
          vaultId: vaultId,
          state: state,
          timestamp: DateTime.now(),
          message: message,
          error: error,
          duration: _calculateSyncDuration(deviceId, state),
        ),
      );
    }
  }

  /// Get sync status for a specific device
  DeviceSyncStatus? getDeviceStatus(String deviceId) {
    return _deviceStatus[deviceId];
  }

  /// Get sync status for all devices
  Map<String, DeviceSyncStatus> getAllDeviceStatus() {
    return Map.from(_deviceStatus);
  }

  /// Get sync history
  List<SyncHistoryEntry> getSyncHistory({
    String? deviceId,
    String? vaultId,
    int? limit,
  }) {
    var history = _syncHistory.where((entry) {
      if (deviceId != null && entry.deviceId != deviceId) return false;
      if (vaultId != null && entry.vaultId != vaultId) return false;
      return true;
    }).toList();

    // Sort by timestamp (most recent first)
    history.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (limit != null && history.length > limit) {
      history = history.take(limit).toList();
    }

    return history;
  }

  /// Get sync statistics for a device
  SyncStatistics getDeviceStatistics(String deviceId) {
    final history = getSyncHistory(deviceId: deviceId);
    final successful = history
        .where((e) => e.state == SyncState.completed)
        .length;
    final failed = history.where((e) => e.state == SyncState.failed).length;
    final lastSync = history.isNotEmpty ? history.first.timestamp : null;

    final durations = history
        .where((e) => e.duration != null)
        .map((e) => e.duration!)
        .toList();

    final averageDuration = durations.isNotEmpty
        ? durations.reduce((a, b) => a + b) ~/ durations.length
        : 0;

    return SyncStatistics(
      deviceId: deviceId,
      totalSyncs: history.length,
      successfulSyncs: successful,
      failedSyncs: failed,
      lastSyncTime: lastSync,
      averageSyncDuration: Duration(milliseconds: averageDuration),
      successRate: history.isNotEmpty ? successful / history.length : 0.0,
    );
  }

  /// Get overall sync health
  SyncHealth getOverallSyncHealth() {
    final allDevices = _deviceStatus.keys.toList();
    final onlineDevices = _deviceStatus.values
        .where((status) => _isDeviceOnline(status))
        .length;

    final recentFailures = _syncHistory
        .where(
          (entry) =>
              entry.state == SyncState.failed &&
              DateTime.now().difference(entry.timestamp).inHours < 24,
        )
        .length;

    final oldestPendingSync = _deviceStatus.values
        .where((status) => status.state == SyncState.queued)
        .map((status) => status.lastUpdated)
        .fold<DateTime?>(
          null,
          (oldest, current) =>
              oldest == null || current.isBefore(oldest) ? current : oldest,
        );

    SyncHealthLevel healthLevel;
    if (recentFailures == 0 && onlineDevices == allDevices.length) {
      healthLevel = SyncHealthLevel.excellent;
    } else if (recentFailures < 3 && onlineDevices > allDevices.length * 0.7) {
      healthLevel = SyncHealthLevel.good;
    } else if (recentFailures < 10 && onlineDevices > allDevices.length * 0.5) {
      healthLevel = SyncHealthLevel.fair;
    } else {
      healthLevel = SyncHealthLevel.poor;
    }

    return SyncHealth(
      healthLevel: healthLevel,
      totalDevices: allDevices.length,
      onlineDevices: onlineDevices,
      recentFailures: recentFailures,
      oldestPendingSync: oldestPendingSync,
    );
  }

  /// Clear sync history older than specified duration
  Future<void> clearOldHistory({Duration? olderThan}) async {
    final cutoff = DateTime.now().subtract(
      olderThan ?? const Duration(days: 30),
    );
    _syncHistory.removeWhere((entry) => entry.timestamp.isBefore(cutoff));
    await _saveSyncHistory();
  }

  /// Reset sync status for a device
  Future<void> resetDeviceStatus(String deviceId) async {
    _deviceStatus.remove(deviceId);
    await _saveDeviceStatus();
    _notifyStatusChanged();
  }

  /// Add a sync history entry
  Future<void> _addHistoryEntry(SyncHistoryEntry entry) async {
    _syncHistory.add(entry);

    // Keep only the last 1000 entries
    if (_syncHistory.length > 1000) {
      _syncHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _syncHistory.removeRange(1000, _syncHistory.length);
    }

    await _saveSyncHistory();

    if (!_historyController.isClosed) {
      _historyController.add(entry);
    }
  }

  /// Check if a state change is significant enough to log
  bool _isSignificantStateChange(SyncState? oldState, SyncState newState) {
    if (oldState == null) return true;

    // Log all state changes except progress updates
    return oldState != newState && newState != SyncState.syncing;
  }

  /// Calculate sync duration for completed syncs
  int? _calculateSyncDuration(String deviceId, SyncState state) {
    if (state != SyncState.completed) return null;

    final status = _deviceStatus[deviceId];
    if (status == null) return null;

    // Find the last time this device started syncing
    final startEntry = _syncHistory
        .where(
          (entry) =>
              entry.deviceId == deviceId && entry.state == SyncState.syncing,
        )
        .lastOrNull;

    if (startEntry != null) {
      return DateTime.now().difference(startEntry.timestamp).inMilliseconds;
    }

    return null;
  }

  /// Check if a device is considered online
  bool _isDeviceOnline(DeviceSyncStatus status) {
    final timeSinceUpdate = DateTime.now().difference(status.lastUpdated);
    return timeSinceUpdate.inMinutes < 5 &&
        status.state != SyncState.failed &&
        status.state != SyncState.offline;
  }

  /// Start timer for periodic status updates
  void _startStatusUpdateTimer() {
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateOfflineDevices();
    });
  }

  /// Mark devices as offline if they haven't updated recently
  void _updateOfflineDevices() {
    final now = DateTime.now();
    bool hasChanges = false;

    for (final entry in _deviceStatus.entries) {
      final status = entry.value;
      final timeSinceUpdate = now.difference(status.lastUpdated);

      if (timeSinceUpdate.inMinutes > 5 && status.state != SyncState.offline) {
        _deviceStatus[entry.key] = status.copyWith(
          state: SyncState.offline,
          message: 'Device offline',
        );
        hasChanges = true;
      }
    }

    if (hasChanges) {
      _saveDeviceStatus();
      _notifyStatusChanged();
    }
  }

  /// Load device status from storage
  Future<void> _loadDeviceStatus() async {
    try {
      final statusJson = await _storage.read(key: _storageKeyDeviceStatus);
      if (statusJson != null) {
        final statusMap = jsonDecode(statusJson) as Map<String, dynamic>;
        _deviceStatus.clear();
        for (final entry in statusMap.entries) {
          _deviceStatus[entry.key] = DeviceSyncStatus.fromJson(entry.value);
        }
      }
    } catch (e) {
      print('Error loading device sync status: $e');
    }
  }

  /// Save device status to storage
  Future<void> _saveDeviceStatus() async {
    try {
      final statusMap = _deviceStatus.map(
        (key, value) => MapEntry(key, value.toJson()),
      );
      final statusJson = jsonEncode(statusMap);
      await _storage.write(key: _storageKeyDeviceStatus, value: statusJson);
    } catch (e) {
      print('Error saving device sync status: $e');
    }
  }

  /// Load sync history from storage
  Future<void> _loadSyncHistory() async {
    try {
      final historyJson = await _storage.read(key: _storageKeySyncHistory);
      if (historyJson != null) {
        final historyList = jsonDecode(historyJson) as List;
        _syncHistory.clear();
        for (final entryData in historyList) {
          _syncHistory.add(SyncHistoryEntry.fromJson(entryData));
        }
      }
    } catch (e) {
      print('Error loading sync history: $e');
    }
  }

  /// Save sync history to storage
  Future<void> _saveSyncHistory() async {
    try {
      final historyList = _syncHistory.map((entry) => entry.toJson()).toList();
      final historyJson = jsonEncode(historyList);
      await _storage.write(key: _storageKeySyncHistory, value: historyJson);
    } catch (e) {
      print('Error saving sync history: $e');
    }
  }

  /// Notify status change listeners
  void _notifyStatusChanged() {
    if (!_statusController.isClosed) {
      _statusController.add(getAllDeviceStatus());
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    _statusUpdateTimer?.cancel();
    await _statusController.close();
    await _historyController.close();
  }
}

/// Sync status for a device
class DeviceSyncStatus {
  final String deviceId;
  final SyncState state;
  final String? vaultId;
  final double progress;
  final String? message;
  final String? error;
  final DateTime lastUpdated;
  final DateTime? lastSuccessfulSync;

  const DeviceSyncStatus({
    required this.deviceId,
    required this.state,
    this.vaultId,
    required this.progress,
    this.message,
    this.error,
    required this.lastUpdated,
    this.lastSuccessfulSync,
  });

  DeviceSyncStatus copyWith({
    String? deviceId,
    SyncState? state,
    String? vaultId,
    double? progress,
    String? message,
    String? error,
    DateTime? lastUpdated,
    DateTime? lastSuccessfulSync,
  }) {
    return DeviceSyncStatus(
      deviceId: deviceId ?? this.deviceId,
      state: state ?? this.state,
      vaultId: vaultId ?? this.vaultId,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      error: error ?? this.error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lastSuccessfulSync: lastSuccessfulSync ?? this.lastSuccessfulSync,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'state': state.toString(),
      'vaultId': vaultId,
      'progress': progress,
      'message': message,
      'error': error,
      'lastUpdated': lastUpdated.toIso8601String(),
      'lastSuccessfulSync': lastSuccessfulSync?.toIso8601String(),
    };
  }

  factory DeviceSyncStatus.fromJson(Map<String, dynamic> json) {
    return DeviceSyncStatus(
      deviceId: json['deviceId'],
      state: SyncState.values.firstWhere((e) => e.toString() == json['state']),
      vaultId: json['vaultId'],
      progress: json['progress']?.toDouble() ?? 0.0,
      message: json['message'],
      error: json['error'],
      lastUpdated: DateTime.parse(json['lastUpdated']),
      lastSuccessfulSync: json['lastSuccessfulSync'] != null
          ? DateTime.parse(json['lastSuccessfulSync'])
          : null,
    );
  }
}

/// Sync history entry
class SyncHistoryEntry {
  final String id;
  final String deviceId;
  final String? vaultId;
  final SyncState state;
  final DateTime timestamp;
  final String? message;
  final String? error;
  final int? duration; // in milliseconds

  const SyncHistoryEntry({
    required this.id,
    required this.deviceId,
    this.vaultId,
    required this.state,
    required this.timestamp,
    this.message,
    this.error,
    this.duration,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'vaultId': vaultId,
      'state': state.toString(),
      'timestamp': timestamp.toIso8601String(),
      'message': message,
      'error': error,
      'duration': duration,
    };
  }

  factory SyncHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SyncHistoryEntry(
      id: json['id'],
      deviceId: json['deviceId'],
      vaultId: json['vaultId'],
      state: SyncState.values.firstWhere((e) => e.toString() == json['state']),
      timestamp: DateTime.parse(json['timestamp']),
      message: json['message'],
      error: json['error'],
      duration: json['duration'],
    );
  }
}

/// Sync states
enum SyncState { idle, queued, syncing, completed, failed, offline, cancelled }

/// Sync statistics for a device
class SyncStatistics {
  final String deviceId;
  final int totalSyncs;
  final int successfulSyncs;
  final int failedSyncs;
  final DateTime? lastSyncTime;
  final Duration averageSyncDuration;
  final double successRate;

  const SyncStatistics({
    required this.deviceId,
    required this.totalSyncs,
    required this.successfulSyncs,
    required this.failedSyncs,
    this.lastSyncTime,
    required this.averageSyncDuration,
    required this.successRate,
  });
}

/// Overall sync health
class SyncHealth {
  final SyncHealthLevel healthLevel;
  final int totalDevices;
  final int onlineDevices;
  final int recentFailures;
  final DateTime? oldestPendingSync;

  const SyncHealth({
    required this.healthLevel,
    required this.totalDevices,
    required this.onlineDevices,
    required this.recentFailures,
    this.oldestPendingSync,
  });
}

/// Sync health levels
enum SyncHealthLevel { excellent, good, fair, poor }

extension on Iterable<SyncHistoryEntry> {
  SyncHistoryEntry? get lastOrNull {
    return isEmpty ? null : last;
  }
}
