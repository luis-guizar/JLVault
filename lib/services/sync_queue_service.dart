import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Service for managing offline sync operations and queuing
class SyncQueueService {
  static const String _storageKeyQueue = 'sync_queue';
  static const String _storageKeyStatus = 'sync_status';

  final FlutterSecureStorage _storage;
  final List<QueuedSyncOperation> _queue = [];
  final Map<String, SyncOperationStatus> _operationStatus = {};

  final StreamController<List<QueuedSyncOperation>> _queueController =
      StreamController<List<QueuedSyncOperation>>.broadcast();
  final StreamController<SyncOperationStatus> _statusController =
      StreamController<SyncOperationStatus>.broadcast();

  Timer? _retryTimer;
  bool _isProcessing = false;

  SyncQueueService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// Stream of queue changes
  Stream<List<QueuedSyncOperation>> get queueStream => _queueController.stream;

  /// Stream of operation status changes
  Stream<SyncOperationStatus> get statusStream => _statusController.stream;

  /// Initialize the service and load persisted queue
  Future<void> initialize() async {
    await _loadQueue();
    await _loadOperationStatus();
    _startRetryTimer();
  }

  /// Add a sync operation to the queue
  Future<String> queueSyncOperation({
    required String deviceId,
    required String vaultId,
    required SyncOperationType operationType,
    required Map<String, dynamic> data,
    int priority = 5,
    Duration? delay,
  }) async {
    final operation = QueuedSyncOperation(
      id: const Uuid().v4(),
      deviceId: deviceId,
      vaultId: vaultId,
      operationType: operationType,
      data: data,
      priority: priority,
      createdAt: DateTime.now(),
      scheduledAt: delay != null ? DateTime.now().add(delay) : DateTime.now(),
      retryCount: 0,
      maxRetries: 3,
    );

    _queue.add(operation);
    _queue.sort((a, b) => a.priority.compareTo(b.priority));

    await _saveQueue();
    _notifyQueueChanged();

    _updateOperationStatus(operation.id, SyncOperationState.queued);

    // Start processing if not already running
    if (!_isProcessing) {
      _processQueue();
    }

    return operation.id;
  }

  /// Remove a sync operation from the queue
  Future<bool> removeSyncOperation(String operationId) async {
    final index = _queue.indexWhere((op) => op.id == operationId);
    if (index != -1) {
      _queue.removeAt(index);
      await _saveQueue();
      _notifyQueueChanged();

      _updateOperationStatus(operationId, SyncOperationState.cancelled);
      return true;
    }
    return false;
  }

  /// Clear all queued operations
  Future<void> clearQueue() async {
    for (final operation in _queue) {
      _updateOperationStatus(operation.id, SyncOperationState.cancelled);
    }

    _queue.clear();
    await _saveQueue();
    _notifyQueueChanged();
  }

  /// Get current queue status
  QueueStatus getQueueStatus() {
    final pending = _queue
        .where((op) => op.scheduledAt.isAfter(DateTime.now()))
        .length;
    final ready = _queue
        .where((op) => op.scheduledAt.isBefore(DateTime.now()))
        .length;
    final failed = _operationStatus.values
        .where((status) => status.state == SyncOperationState.failed)
        .length;

    return QueueStatus(
      totalOperations: _queue.length,
      pendingOperations: pending,
      readyOperations: ready,
      failedOperations: failed,
      isProcessing: _isProcessing,
    );
  }

  /// Get operations for a specific device
  List<QueuedSyncOperation> getOperationsForDevice(String deviceId) {
    return _queue.where((op) => op.deviceId == deviceId).toList();
  }

  /// Get operations for a specific vault
  List<QueuedSyncOperation> getOperationsForVault(String vaultId) {
    return _queue.where((op) => op.vaultId == vaultId).toList();
  }

  /// Retry a failed operation
  Future<void> retryOperation(String operationId) async {
    final operation = _queue.firstWhere(
      (op) => op.id == operationId,
      orElse: () => throw ArgumentError('Operation not found: $operationId'),
    );

    if (operation.retryCount < operation.maxRetries) {
      operation.retryCount++;
      operation.scheduledAt = DateTime.now();

      await _saveQueue();
      _notifyQueueChanged();

      _updateOperationStatus(operationId, SyncOperationState.queued);

      if (!_isProcessing) {
        _processQueue();
      }
    }
  }

  /// Process the sync queue
  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final now = DateTime.now();
      final readyOperations = _queue
          .where((op) => op.scheduledAt.isBefore(now))
          .toList();

      for (final operation in readyOperations) {
        await _processOperation(operation);
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Process a single sync operation
  Future<void> _processOperation(QueuedSyncOperation operation) async {
    _updateOperationStatus(operation.id, SyncOperationState.processing);

    try {
      // Simulate sync operation processing
      // In a real implementation, this would call the actual sync service
      await _simulateSyncOperation(operation);

      // Remove successful operation from queue
      _queue.removeWhere((op) => op.id == operation.id);
      await _saveQueue();
      _notifyQueueChanged();

      _updateOperationStatus(operation.id, SyncOperationState.completed);
    } catch (e) {
      if (operation.retryCount < operation.maxRetries) {
        // Schedule retry with exponential backoff
        final backoffDelay = Duration(
          seconds: (2 << operation.retryCount) * 30, // 30s, 1m, 2m, 4m...
        );

        operation.retryCount++;
        operation.scheduledAt = DateTime.now().add(backoffDelay);
        operation.lastError = e.toString();

        await _saveQueue();
        _notifyQueueChanged();

        _updateOperationStatus(
          operation.id,
          SyncOperationState.retrying,
          error: e.toString(),
        );
      } else {
        // Max retries reached, mark as failed
        operation.lastError = e.toString();
        await _saveQueue();
        _notifyQueueChanged();

        _updateOperationStatus(
          operation.id,
          SyncOperationState.failed,
          error: e.toString(),
        );
      }
    }
  }

  /// Simulate sync operation (placeholder for actual sync logic)
  Future<void> _simulateSyncOperation(QueuedSyncOperation operation) async {
    // Simulate network delay and potential failure
    await Future.delayed(const Duration(seconds: 1));

    // Simulate 20% failure rate for testing
    if (DateTime.now().millisecond % 5 == 0) {
      throw Exception('Simulated sync failure');
    }

    print(
      'Processed sync operation: ${operation.operationType} for ${operation.deviceId}',
    );
  }

  /// Start retry timer for failed operations
  void _startRetryTimer() {
    _retryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!_isProcessing) {
        _processQueue();
      }
    });
  }

  /// Load queue from persistent storage
  Future<void> _loadQueue() async {
    try {
      final queueJson = await _storage.read(key: _storageKeyQueue);
      if (queueJson != null) {
        final queueList = jsonDecode(queueJson) as List;
        _queue.clear();
        for (final operationData in queueList) {
          _queue.add(QueuedSyncOperation.fromJson(operationData));
        }
        _queue.sort((a, b) => a.priority.compareTo(b.priority));
      }
    } catch (e) {
      print('Error loading sync queue: $e');
    }
  }

  /// Save queue to persistent storage
  Future<void> _saveQueue() async {
    try {
      final queueList = _queue.map((op) => op.toJson()).toList();
      final queueJson = jsonEncode(queueList);
      await _storage.write(key: _storageKeyQueue, value: queueJson);
    } catch (e) {
      print('Error saving sync queue: $e');
    }
  }

  /// Load operation status from persistent storage
  Future<void> _loadOperationStatus() async {
    try {
      final statusJson = await _storage.read(key: _storageKeyStatus);
      if (statusJson != null) {
        final statusMap = jsonDecode(statusJson) as Map<String, dynamic>;
        _operationStatus.clear();
        for (final entry in statusMap.entries) {
          _operationStatus[entry.key] = SyncOperationStatus.fromJson(
            entry.value,
          );
        }
      }
    } catch (e) {
      print('Error loading operation status: $e');
    }
  }

  /// Save operation status to persistent storage
  Future<void> _saveOperationStatus() async {
    try {
      final statusMap = _operationStatus.map(
        (key, value) => MapEntry(key, value.toJson()),
      );
      final statusJson = jsonEncode(statusMap);
      await _storage.write(key: _storageKeyStatus, value: statusJson);
    } catch (e) {
      print('Error saving operation status: $e');
    }
  }

  /// Update operation status and notify listeners
  void _updateOperationStatus(
    String operationId,
    SyncOperationState state, {
    String? error,
    double? progress,
  }) {
    final status = SyncOperationStatus(
      operationId: operationId,
      state: state,
      timestamp: DateTime.now(),
      error: error,
      progress: progress,
    );

    _operationStatus[operationId] = status;
    _saveOperationStatus();

    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  /// Notify queue change listeners
  void _notifyQueueChanged() {
    if (!_queueController.isClosed) {
      _queueController.add(List.from(_queue));
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    _retryTimer?.cancel();
    await _queueController.close();
    await _statusController.close();
  }
}

/// Represents a queued sync operation
class QueuedSyncOperation {
  final String id;
  final String deviceId;
  final String vaultId;
  final SyncOperationType operationType;
  final Map<String, dynamic> data;
  final int priority;
  final DateTime createdAt;
  DateTime scheduledAt;
  int retryCount;
  final int maxRetries;
  String? lastError;

  QueuedSyncOperation({
    required this.id,
    required this.deviceId,
    required this.vaultId,
    required this.operationType,
    required this.data,
    required this.priority,
    required this.createdAt,
    required this.scheduledAt,
    required this.retryCount,
    required this.maxRetries,
    this.lastError,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'vaultId': vaultId,
      'operationType': operationType.toString(),
      'data': data,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'scheduledAt': scheduledAt.toIso8601String(),
      'retryCount': retryCount,
      'maxRetries': maxRetries,
      'lastError': lastError,
    };
  }

  factory QueuedSyncOperation.fromJson(Map<String, dynamic> json) {
    return QueuedSyncOperation(
      id: json['id'],
      deviceId: json['deviceId'],
      vaultId: json['vaultId'],
      operationType: SyncOperationType.values.firstWhere(
        (e) => e.toString() == json['operationType'],
      ),
      data: Map<String, dynamic>.from(json['data']),
      priority: json['priority'],
      createdAt: DateTime.parse(json['createdAt']),
      scheduledAt: DateTime.parse(json['scheduledAt']),
      retryCount: json['retryCount'],
      maxRetries: json['maxRetries'],
      lastError: json['lastError'],
    );
  }

  bool get isReady => DateTime.now().isAfter(scheduledAt);
  bool get canRetry => retryCount < maxRetries;
}

/// Types of sync operations
enum SyncOperationType {
  fullSync,
  incrementalSync,
  entryCreate,
  entryUpdate,
  entryDelete,
  vaultCreate,
  vaultUpdate,
  vaultDelete,
}

/// Status of a sync operation
class SyncOperationStatus {
  final String operationId;
  final SyncOperationState state;
  final DateTime timestamp;
  final String? error;
  final double? progress;

  const SyncOperationStatus({
    required this.operationId,
    required this.state,
    required this.timestamp,
    this.error,
    this.progress,
  });

  Map<String, dynamic> toJson() {
    return {
      'operationId': operationId,
      'state': state.toString(),
      'timestamp': timestamp.toIso8601String(),
      'error': error,
      'progress': progress,
    };
  }

  factory SyncOperationStatus.fromJson(Map<String, dynamic> json) {
    return SyncOperationStatus(
      operationId: json['operationId'],
      state: SyncOperationState.values.firstWhere(
        (e) => e.toString() == json['state'],
      ),
      timestamp: DateTime.parse(json['timestamp']),
      error: json['error'],
      progress: json['progress']?.toDouble(),
    );
  }
}

/// States of sync operations
enum SyncOperationState {
  queued,
  processing,
  completed,
  failed,
  retrying,
  cancelled,
}

/// Queue status summary
class QueueStatus {
  final int totalOperations;
  final int pendingOperations;
  final int readyOperations;
  final int failedOperations;
  final bool isProcessing;

  const QueueStatus({
    required this.totalOperations,
    required this.pendingOperations,
    required this.readyOperations,
    required this.failedOperations,
    required this.isProcessing,
  });

  bool get hasOperations => totalOperations > 0;
  bool get hasFailedOperations => failedOperations > 0;
  bool get hasReadyOperations => readyOperations > 0;
}
