import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../models/sync_protocol.dart';
import '../models/sync_device.dart';
import 'sync_encryption_service.dart';
import 'device_manager.dart';

/// Service for handling the sync protocol between devices
class SyncProtocolService {
  final DeviceManager _deviceManager;
  final SyncEncryptionService _encryptionService;
  final Map<String, SyncManifest> _vaultManifests = {};
  final Map<String, Timer> _syncTimers = {};

  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();
  final StreamController<SyncProgress> _progressController =
      StreamController<SyncProgress>.broadcast();

  HttpServer? _syncServer;
  int _syncPort = 0;
  bool _isRunning = false;

  SyncProtocolService({
    required DeviceManager deviceManager,
    required SyncEncryptionService encryptionService,
  }) : _deviceManager = deviceManager,
       _encryptionService = encryptionService;

  /// Stream of sync status changes
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Stream of sync progress updates
  Stream<SyncProgress> get progressStream => _progressController.stream;

  /// Start the sync protocol service
  Future<void> start({int port = 0}) async {
    if (_isRunning) return;

    try {
      _syncServer = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _syncPort = _syncServer!.port;
      _isRunning = true;

      _syncServer!.listen((HttpRequest request) {
        _handleSyncRequest(request);
      });

      _notifyStatus(SyncStatus.ready);
      print('Sync protocol service started on port $_syncPort');
    } catch (e) {
      throw SyncProtocolException(
        'Failed to start sync service: ${e.toString()}',
      );
    }
  }

  /// Stop the sync protocol service
  Future<void> stop() async {
    if (!_isRunning) return;

    await _syncServer?.close();
    _syncServer = null;
    _syncPort = 0;
    _isRunning = false;

    // Cancel all sync timers
    for (final timer in _syncTimers.values) {
      timer.cancel();
    }
    _syncTimers.clear();

    _notifyStatus(SyncStatus.stopped);
    print('Sync protocol service stopped');
  }

  /// Initiate sync with a paired device
  Future<SyncResult> syncWithDevice({
    required String deviceId,
    required String vaultId,
    SyncRequestType type = SyncRequestType.incrementalSync,
  }) async {
    final device = _deviceManager.getPairedDevice(deviceId);
    if (device == null) {
      return SyncResult.failure('Device not paired: $deviceId');
    }

    if (!_encryptionService.hasDeviceKey(deviceId)) {
      return SyncResult.failure('No encryption key for device: $deviceId');
    }

    try {
      _notifyStatus(SyncStatus.syncing);
      _notifyProgress(
        SyncProgress(
          deviceId: deviceId,
          vaultId: vaultId,
          phase: SyncPhase.preparing,
          progress: 0.0,
        ),
      );

      // Create sync request
      final manifest = await _createSyncManifest(vaultId);
      final request = SyncRequest(
        requestId: const Uuid().v4(),
        deviceId: _deviceManager.deviceId,
        vaultId: vaultId,
        manifest: manifest,
        type: type,
      );

      // Encrypt and send request
      final encryptedPacket = await _encryptionService.encryptSyncData(
        deviceId: deviceId,
        data: request.toJson(),
      );

      _notifyProgress(
        SyncProgress(
          deviceId: deviceId,
          vaultId: vaultId,
          phase: SyncPhase.connecting,
          progress: 0.2,
        ),
      );

      final response = await _sendSyncRequest(device, encryptedPacket);

      _notifyProgress(
        SyncProgress(
          deviceId: deviceId,
          vaultId: vaultId,
          phase: SyncPhase.exchanging,
          progress: 0.5,
        ),
      );

      final result = await _processSyncResponse(response, vaultId);

      _notifyProgress(
        SyncProgress(
          deviceId: deviceId,
          vaultId: vaultId,
          phase: SyncPhase.completing,
          progress: 0.9,
        ),
      );

      if (result.success) {
        _notifyStatus(SyncStatus.completed);
        _notifyProgress(
          SyncProgress(
            deviceId: deviceId,
            vaultId: vaultId,
            phase: SyncPhase.completed,
            progress: 1.0,
          ),
        );
      } else {
        _notifyStatus(SyncStatus.error);
      }

      return result;
    } catch (e) {
      _notifyStatus(SyncStatus.error);
      return SyncResult.failure('Sync failed: ${e.toString()}');
    }
  }

  /// Create a sync manifest for a vault
  Future<SyncManifest> _createSyncManifest(String vaultId) async {
    // This would typically read from the vault storage
    // For now, we'll create a basic manifest
    final entries = <String, SyncEntry>{};

    // Add sample entries (in real implementation, read from vault)
    final sampleEntry = SyncEntry(
      id: const Uuid().v4(),
      action: SyncAction.update,
      timestamp: DateTime.now(),
      dataHash: 'sample_hash',
      dataSize: 1024,
    );

    entries[sampleEntry.id] = sampleEntry;

    final manifest = SyncManifest(
      deviceId: _deviceManager.deviceId,
      vaultId: vaultId,
      version: 1,
      timestamp: DateTime.now(),
      entries: entries,
      checksum: _calculateManifestChecksum(entries),
    );

    _vaultManifests[vaultId] = manifest;
    return manifest;
  }

  /// Send sync request to remote device
  Future<SyncResponse> _sendSyncRequest(
    SyncDevice device,
    EncryptedSyncPacket packet,
  ) async {
    final client = HttpClient();

    try {
      final request = await client.postUrl(
        Uri.parse('http://${device.address}:${device.port}/sync'),
      );

      request.headers.contentType = ContentType.json;
      final requestData = jsonEncode(packet.toJson());
      request.write(requestData);

      final response = await request.close();
      final responseBody = await utf8.decoder.bind(response).join();

      if (response.statusCode == 200) {
        final responseData = jsonDecode(responseBody);
        final encryptedResponse = EncryptedSyncPacket.fromJson(responseData);

        final decryptedData = await _encryptionService.decryptSyncData(
          packet: encryptedResponse,
        );

        return SyncResponse.fromJson(decryptedData);
      } else {
        throw SyncProtocolException(
          'HTTP ${response.statusCode}: $responseBody',
        );
      }
    } finally {
      client.close();
    }
  }

  /// Process sync response from remote device
  Future<SyncResult> _processSyncResponse(
    SyncResponse response,
    String vaultId,
  ) async {
    switch (response.status) {
      case SyncResponseStatus.success:
        if (response.manifest != null) {
          await _applyRemoteChanges(response.manifest!, vaultId);
        }
        return SyncResult.success('Sync completed successfully');

      case SyncResponseStatus.conflict:
        if (response.conflicts != null) {
          return SyncResult.conflict(response.conflicts!);
        }
        return SyncResult.failure('Sync conflicts detected');

      case SyncResponseStatus.error:
        return SyncResult.failure(response.error ?? 'Unknown sync error');

      case SyncResponseStatus.unauthorized:
        return SyncResult.failure('Unauthorized - device not paired');

      case SyncResponseStatus.vaultNotFound:
        return SyncResult.failure('Vault not found on remote device');

      case SyncResponseStatus.deviceNotPaired:
        return SyncResult.failure('Device not paired on remote side');
    }
  }

  /// Apply remote changes to local vault
  Future<void> _applyRemoteChanges(
    SyncManifest remoteManifest,
    String vaultId,
  ) async {
    // This would typically update the local vault storage
    // For now, we'll just update our manifest
    _vaultManifests[vaultId] = remoteManifest;
    print(
      'Applied ${remoteManifest.entries.length} changes from remote device',
    );
  }

  /// Handle incoming sync requests
  void _handleSyncRequest(HttpRequest request) async {
    try {
      if (request.method == 'POST' && request.uri.path == '/sync') {
        final body = await utf8.decoder.bind(request).join();
        final data = jsonDecode(body);
        final encryptedPacket = EncryptedSyncPacket.fromJson(data);

        // Decrypt request
        final decryptedData = await _encryptionService.decryptSyncData(
          packet: encryptedPacket,
        );

        final syncRequest = SyncRequest.fromJson(decryptedData);

        // Process request
        final response = await _processSyncRequest(syncRequest);

        // Encrypt response
        final encryptedResponse = await _encryptionService.encryptSyncData(
          deviceId: syncRequest.deviceId,
          data: response.toJson(),
        );

        // Send response
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(encryptedResponse.toJson()));
        await request.response.close();
      } else {
        request.response.statusCode = 404;
        await request.response.close();
      }
    } catch (e) {
      request.response.statusCode = 500;
      request.response.write('Sync error: ${e.toString()}');
      await request.response.close();
    }
  }

  /// Process incoming sync request
  Future<SyncResponse> _processSyncRequest(SyncRequest request) async {
    // Verify device is paired
    if (!_deviceManager.isDevicePaired(request.deviceId)) {
      return SyncResponse(
        requestId: request.requestId,
        deviceId: _deviceManager.deviceId,
        status: SyncResponseStatus.deviceNotPaired,
      );
    }

    try {
      // Get local manifest
      final localManifest =
          _vaultManifests[request.vaultId] ??
          await _createSyncManifest(request.vaultId);

      // Detect conflicts
      final conflicts = _detectConflicts(localManifest, request.manifest);

      if (conflicts.isNotEmpty) {
        return SyncResponse(
          requestId: request.requestId,
          deviceId: _deviceManager.deviceId,
          status: SyncResponseStatus.conflict,
          conflicts: conflicts,
        );
      }

      // Apply changes and return updated manifest
      await _applyRemoteChanges(request.manifest, request.vaultId);

      return SyncResponse(
        requestId: request.requestId,
        deviceId: _deviceManager.deviceId,
        status: SyncResponseStatus.success,
        manifest: localManifest,
      );
    } catch (e) {
      return SyncResponse(
        requestId: request.requestId,
        deviceId: _deviceManager.deviceId,
        status: SyncResponseStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Detect conflicts between local and remote manifests
  List<SyncConflict> _detectConflicts(
    SyncManifest localManifest,
    SyncManifest remoteManifest,
  ) {
    final conflicts = <SyncConflict>[];

    for (final entry in remoteManifest.entries.entries) {
      final entryId = entry.key;
      final remoteEntry = entry.value;
      final localEntry = localManifest.entries[entryId];

      if (localEntry != null) {
        // Check for conflicts
        if (localEntry.timestamp.isAfter(remoteEntry.timestamp) &&
            remoteEntry.timestamp.isAfter(localEntry.timestamp)) {
          // Simultaneous updates
          conflicts.add(
            SyncConflict(
              entryId: entryId,
              localEntry: localEntry,
              remoteEntry: remoteEntry,
              type: ConflictType.updateUpdate,
              suggestedResolution: ConflictResolution.lastWriterWins,
            ),
          );
        }
      }
    }

    return conflicts;
  }

  /// Calculate checksum for manifest
  String _calculateManifestChecksum(Map<String, SyncEntry> entries) {
    final entriesJson = jsonEncode(
      entries.map((k, v) => MapEntry(k, v.toJson())),
    );
    final bytes = utf8.encode(entriesJson);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  void _notifyStatus(SyncStatus status) {
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  void _notifyProgress(SyncProgress progress) {
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await stop();
    await _statusController.close();
    await _progressController.close();
  }
}

/// Sync operation result
class SyncResult {
  final bool success;
  final String? message;
  final List<SyncConflict>? conflicts;

  const SyncResult({required this.success, this.message, this.conflicts});

  factory SyncResult.success(String message) {
    return SyncResult(success: true, message: message);
  }

  factory SyncResult.failure(String message) {
    return SyncResult(success: false, message: message);
  }

  factory SyncResult.conflict(List<SyncConflict> conflicts) {
    return SyncResult(success: false, conflicts: conflicts);
  }
}

/// Sync status enumeration
enum SyncStatus { stopped, ready, syncing, completed, error }

/// Sync progress information
class SyncProgress {
  final String deviceId;
  final String vaultId;
  final SyncPhase phase;
  final double progress; // 0.0 to 1.0
  final String? message;

  const SyncProgress({
    required this.deviceId,
    required this.vaultId,
    required this.phase,
    required this.progress,
    this.message,
  });
}

/// Sync phases
enum SyncPhase {
  preparing,
  connecting,
  exchanging,
  resolving,
  completing,
  completed,
}

/// Exception thrown when sync protocol operations fail
class SyncProtocolException implements Exception {
  final String message;
  final dynamic originalError;

  const SyncProtocolException(this.message, {this.originalError});

  @override
  String toString() {
    return 'SyncProtocolException: $message';
  }
}
