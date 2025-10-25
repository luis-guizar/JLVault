import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/account.dart';
import '../models/vault_metadata.dart';

/// Service for optimizing P2P sync performance with compression and delta updates
class SyncPerformanceService {
  static SyncPerformanceService? _instance;
  static SyncPerformanceService get instance =>
      _instance ??= SyncPerformanceService._();

  SyncPerformanceService._();

  // Change tracking for incremental sync
  final Map<String, Map<String, dynamic>> _lastSyncState = {};
  final Map<String, DateTime> _lastSyncTimestamps = {};

  /// Create incremental sync payload with only changed data
  Future<SyncPayload> createIncrementalSyncPayload({
    required String vaultId,
    required List<Account> accounts,
    required VaultMetadata vaultMetadata,
    String? targetDeviceId,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Get last sync state for this vault and device
      final lastState = _getLastSyncState(vaultId, targetDeviceId);
      final lastSyncTime = _lastSyncTimestamps['${vaultId}_$targetDeviceId'];

      // Detect changes since last sync
      final changes = await _detectChanges(
        vaultId: vaultId,
        accounts: accounts,
        vaultMetadata: vaultMetadata,
        lastState: lastState,
        lastSyncTime: lastSyncTime,
      );

      // Create compressed payload
      final payload = SyncPayload(
        vaultId: vaultId,
        timestamp: DateTime.now(),
        isIncremental: lastState.isNotEmpty,
        changes: changes,
        compressionType: CompressionType.gzip,
      );

      // Compress the payload
      final compressedPayload = await _compressPayload(payload);

      if (kDebugMode) {
        final originalSize = _calculatePayloadSize(payload);
        final compressedSize = compressedPayload.compressedData?.length ?? 0;
        final compressionRatio = (1 - compressedSize / originalSize) * 100;

        print('Sync payload created in ${stopwatch.elapsedMilliseconds}ms');
        print(
          'Original size: ${originalSize} bytes, Compressed: ${compressedSize} bytes',
        );
        print('Compression ratio: ${compressionRatio.toStringAsFixed(1)}%');
        print('Changes detected: ${changes.length}');
      }

      return compressedPayload;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating sync payload: $e');
      }
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Detect changes since last sync
  Future<List<SyncChange>> _detectChanges({
    required String vaultId,
    required List<Account> accounts,
    required VaultMetadata vaultMetadata,
    required Map<String, dynamic> lastState,
    DateTime? lastSyncTime,
  }) async {
    final changes = <SyncChange>[];

    // Check vault metadata changes
    final vaultKey = 'vault_$vaultId';
    final lastVaultState = lastState[vaultKey] as Map<String, dynamic>?;

    if (lastVaultState == null ||
        _hasVaultChanged(vaultMetadata, lastVaultState)) {
      changes.add(
        SyncChange(
          type: SyncChangeType.vaultUpdate,
          entityId: vaultId,
          data: vaultMetadata.toMap(),
          timestamp: vaultMetadata.lastAccessedAt,
        ),
      );
    }

    // Check account changes
    final lastAccountStates =
        lastState['accounts'] as Map<String, dynamic>? ?? {};

    for (final account in accounts) {
      final accountKey = 'account_${account.id}';
      final lastAccountState =
          lastAccountStates[accountKey] as Map<String, dynamic>?;

      if (lastAccountState == null) {
        // New account
        changes.add(
          SyncChange(
            type: SyncChangeType.accountCreate,
            entityId: account.id.toString(),
            data: account.toMap(),
            timestamp: account.createdAt ?? DateTime.now(),
          ),
        );
      } else if (_hasAccountChanged(account, lastAccountState)) {
        // Modified account
        changes.add(
          SyncChange(
            type: SyncChangeType.accountUpdate,
            entityId: account.id.toString(),
            data: account.toMap(),
            timestamp: account.modifiedAt ?? DateTime.now(),
          ),
        );
      }
    }

    // Check for deleted accounts
    final currentAccountIds = accounts.map((a) => 'account_${a.id}').toSet();
    for (final lastAccountKey in lastAccountStates.keys) {
      if (!currentAccountIds.contains(lastAccountKey)) {
        changes.add(
          SyncChange(
            type: SyncChangeType.accountDelete,
            entityId: lastAccountKey.replaceFirst('account_', ''),
            data: null,
            timestamp: DateTime.now(),
          ),
        );
      }
    }

    return changes;
  }

  /// Check if vault metadata has changed
  bool _hasVaultChanged(VaultMetadata current, Map<String, dynamic> last) {
    return current.name != last['name'] ||
        current.iconName != last['icon_name'] ||
        current.color.value != last['color'] ||
        current.passwordCount != last['password_count'] ||
        current.securityScore != last['security_score'];
  }

  /// Check if account has changed
  bool _hasAccountChanged(Account current, Map<String, dynamic> last) {
    final currentMap = current.toMap();

    // Compare key fields that indicate changes
    return currentMap['name'] != last['name'] ||
        currentMap['username'] != last['username'] ||
        currentMap['password'] != last['password'] ||
        currentMap['url'] != last['url'] ||
        currentMap['notes'] != last['notes'] ||
        currentMap['totp_config'] != last['totp_config'] ||
        currentMap['modified_at'] != last['modified_at'];
  }

  /// Compress sync payload using gzip
  Future<SyncPayload> _compressPayload(SyncPayload payload) async {
    try {
      final jsonData = jsonEncode(payload.toMap());
      final bytes = utf8.encode(jsonData);
      final compressed = gzip.encode(bytes);

      return payload.copyWith(
        compressedData: Uint8List.fromList(compressed),
        originalSize: bytes.length,
        compressedSize: compressed.length,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error compressing payload: $e');
      }
      // Return uncompressed payload as fallback
      return payload.copyWith(compressionType: CompressionType.none);
    }
  }

  /// Decompress sync payload
  Future<SyncPayload> decompressPayload(SyncPayload compressedPayload) async {
    if (compressedPayload.compressionType == CompressionType.none ||
        compressedPayload.compressedData == null) {
      return compressedPayload;
    }

    try {
      final decompressed = gzip.decode(compressedPayload.compressedData!);
      final jsonString = utf8.decode(decompressed);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      return SyncPayload.fromMap(data);
    } catch (e) {
      if (kDebugMode) {
        print('Error decompressing payload: $e');
      }
      rethrow;
    }
  }

  /// Apply incremental changes to local data
  Future<SyncApplyResult> applyIncrementalChanges({
    required String vaultId,
    required SyncPayload payload,
    required List<Account> currentAccounts,
    required VaultMetadata currentVaultMetadata,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = SyncApplyResult();

      for (final change in payload.changes) {
        switch (change.type) {
          case SyncChangeType.vaultUpdate:
            result.vaultUpdated = true;
            result.updatedVaultMetadata = VaultMetadata.fromMap(change.data!);
            break;

          case SyncChangeType.accountCreate:
            result.accountsCreated.add(Account.fromMap(change.data!));
            break;

          case SyncChangeType.accountUpdate:
            result.accountsUpdated.add(Account.fromMap(change.data!));
            break;

          case SyncChangeType.accountDelete:
            result.accountsDeleted.add(int.parse(change.entityId));
            break;
        }
      }

      // Update sync state
      await _updateSyncState(vaultId, currentAccounts, currentVaultMetadata);

      if (kDebugMode) {
        print(
          'Applied ${payload.changes.length} changes in ${stopwatch.elapsedMilliseconds}ms',
        );
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Error applying incremental changes: $e');
      }
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Update sync state after successful sync
  Future<void> _updateSyncState(
    String vaultId,
    List<Account> accounts,
    VaultMetadata vaultMetadata, [
    String? deviceId,
  ]) async {
    final stateKey = '${vaultId}_$deviceId';

    final newState = <String, dynamic>{
      'vault_$vaultId': vaultMetadata.toMap(),
      'accounts': {
        for (final account in accounts)
          'account_${account.id}': account.toMap(),
      },
    };

    _lastSyncState[stateKey] = newState;
    _lastSyncTimestamps[stateKey] = DateTime.now();
  }

  /// Get last sync state for a vault and device
  Map<String, dynamic> _getLastSyncState(String vaultId, String? deviceId) {
    final stateKey = '${vaultId}_$deviceId';
    return _lastSyncState[stateKey] ?? {};
  }

  /// Calculate payload size in bytes
  int _calculatePayloadSize(SyncPayload payload) {
    final jsonData = jsonEncode(payload.toMap());
    return utf8.encode(jsonData).length;
  }

  /// Optimize sync for large vaults by chunking
  Future<List<SyncPayload>> createChunkedSyncPayload({
    required String vaultId,
    required List<Account> accounts,
    required VaultMetadata vaultMetadata,
    int maxChunkSize = 1024 * 1024, // 1MB chunks
    String? targetDeviceId,
  }) async {
    final chunks = <SyncPayload>[];

    // Create initial payload
    final fullPayload = await createIncrementalSyncPayload(
      vaultId: vaultId,
      accounts: accounts,
      vaultMetadata: vaultMetadata,
      targetDeviceId: targetDeviceId,
    );

    // If payload is small enough, return as single chunk
    if (_calculatePayloadSize(fullPayload) <= maxChunkSize) {
      return [fullPayload];
    }

    // Split changes into chunks
    final changes = fullPayload.changes;
    final chunkSize =
        (changes.length /
                ((_calculatePayloadSize(fullPayload) / maxChunkSize).ceil()))
            .ceil();

    for (int i = 0; i < changes.length; i += chunkSize) {
      final chunkChanges = changes.skip(i).take(chunkSize).toList();

      final chunkPayload = SyncPayload(
        vaultId: vaultId,
        timestamp: fullPayload.timestamp,
        isIncremental: fullPayload.isIncremental,
        changes: chunkChanges,
        compressionType: fullPayload.compressionType,
        chunkIndex: chunks.length,
        totalChunks: (changes.length / chunkSize).ceil(),
      );

      chunks.add(await _compressPayload(chunkPayload));
    }

    return chunks;
  }

  /// Get sync performance statistics
  Map<String, dynamic> getSyncStats() {
    return {
      'trackedVaults': _lastSyncState.length,
      'lastSyncTimestamps': _lastSyncTimestamps.length,
      'compressionEnabled': true,
      'incrementalSyncEnabled': true,
    };
  }

  /// Clear sync state (useful for testing or reset)
  void clearSyncState([String? vaultId]) {
    if (vaultId != null) {
      _lastSyncState.removeWhere((key, _) => key.startsWith('${vaultId}_'));
      _lastSyncTimestamps.removeWhere(
        (key, _) => key.startsWith('${vaultId}_'),
      );
    } else {
      _lastSyncState.clear();
      _lastSyncTimestamps.clear();
    }
  }
}

/// Sync payload with compression and change tracking
class SyncPayload {
  final String vaultId;
  final DateTime timestamp;
  final bool isIncremental;
  final List<SyncChange> changes;
  final CompressionType compressionType;
  final Uint8List? compressedData;
  final int? originalSize;
  final int? compressedSize;
  final int? chunkIndex;
  final int? totalChunks;

  const SyncPayload({
    required this.vaultId,
    required this.timestamp,
    required this.isIncremental,
    required this.changes,
    required this.compressionType,
    this.compressedData,
    this.originalSize,
    this.compressedSize,
    this.chunkIndex,
    this.totalChunks,
  });

  SyncPayload copyWith({
    String? vaultId,
    DateTime? timestamp,
    bool? isIncremental,
    List<SyncChange>? changes,
    CompressionType? compressionType,
    Uint8List? compressedData,
    int? originalSize,
    int? compressedSize,
    int? chunkIndex,
    int? totalChunks,
  }) {
    return SyncPayload(
      vaultId: vaultId ?? this.vaultId,
      timestamp: timestamp ?? this.timestamp,
      isIncremental: isIncremental ?? this.isIncremental,
      changes: changes ?? this.changes,
      compressionType: compressionType ?? this.compressionType,
      compressedData: compressedData ?? this.compressedData,
      originalSize: originalSize ?? this.originalSize,
      compressedSize: compressedSize ?? this.compressedSize,
      chunkIndex: chunkIndex ?? this.chunkIndex,
      totalChunks: totalChunks ?? this.totalChunks,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vaultId': vaultId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isIncremental': isIncremental,
      'changes': changes.map((c) => c.toMap()).toList(),
      'compressionType': compressionType.name,
      'originalSize': originalSize,
      'compressedSize': compressedSize,
      'chunkIndex': chunkIndex,
      'totalChunks': totalChunks,
    };
  }

  factory SyncPayload.fromMap(Map<String, dynamic> map) {
    return SyncPayload(
      vaultId: map['vaultId'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      isIncremental: map['isIncremental'],
      changes: (map['changes'] as List)
          .map((c) => SyncChange.fromMap(c))
          .toList(),
      compressionType: CompressionType.values.byName(map['compressionType']),
      originalSize: map['originalSize'],
      compressedSize: map['compressedSize'],
      chunkIndex: map['chunkIndex'],
      totalChunks: map['totalChunks'],
    );
  }
}

/// Individual sync change
class SyncChange {
  final SyncChangeType type;
  final String entityId;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  const SyncChange({
    required this.type,
    required this.entityId,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'entityId': entityId,
      'data': data,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory SyncChange.fromMap(Map<String, dynamic> map) {
    return SyncChange(
      type: SyncChangeType.values.byName(map['type']),
      entityId: map['entityId'],
      data: map['data'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }
}

/// Result of applying sync changes
class SyncApplyResult {
  bool vaultUpdated = false;
  VaultMetadata? updatedVaultMetadata;
  final List<Account> accountsCreated = [];
  final List<Account> accountsUpdated = [];
  final List<int> accountsDeleted = [];

  int get totalChanges =>
      (vaultUpdated ? 1 : 0) +
      accountsCreated.length +
      accountsUpdated.length +
      accountsDeleted.length;
}

/// Types of sync changes
enum SyncChangeType { vaultUpdate, accountCreate, accountUpdate, accountDelete }

/// Compression types for sync payloads
enum CompressionType { none, gzip }
