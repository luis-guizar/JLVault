import 'dart:convert';
import 'dart:typed_data';

/// Represents a sync manifest containing metadata about vault changes
class SyncManifest {
  final String deviceId;
  final String vaultId;
  final int version;
  final DateTime timestamp;
  final Map<String, SyncEntry> entries;
  final String checksum;

  SyncManifest({
    required this.deviceId,
    required this.vaultId,
    required this.version,
    required this.timestamp,
    required this.entries,
    required this.checksum,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'vaultId': vaultId,
      'version': version,
      'timestamp': timestamp.toIso8601String(),
      'entries': entries.map((key, value) => MapEntry(key, value.toJson())),
      'checksum': checksum,
    };
  }

  factory SyncManifest.fromJson(Map<String, dynamic> json) {
    final entriesMap = <String, SyncEntry>{};
    final entriesJson = json['entries'] as Map<String, dynamic>;

    for (final entry in entriesJson.entries) {
      entriesMap[entry.key] = SyncEntry.fromJson(entry.value);
    }

    return SyncManifest(
      deviceId: json['deviceId'],
      vaultId: json['vaultId'],
      version: json['version'],
      timestamp: DateTime.parse(json['timestamp']),
      entries: entriesMap,
      checksum: json['checksum'],
    );
  }

  /// Create a new manifest with updated entries
  SyncManifest copyWith({
    String? deviceId,
    String? vaultId,
    int? version,
    DateTime? timestamp,
    Map<String, SyncEntry>? entries,
    String? checksum,
  }) {
    return SyncManifest(
      deviceId: deviceId ?? this.deviceId,
      vaultId: vaultId ?? this.vaultId,
      version: version ?? this.version,
      timestamp: timestamp ?? this.timestamp,
      entries: entries ?? this.entries,
      checksum: checksum ?? this.checksum,
    );
  }
}

/// Represents a single entry in the sync manifest
class SyncEntry {
  final String id;
  final SyncAction action;
  final DateTime timestamp;
  final String? dataHash;
  final int? dataSize;
  final Map<String, dynamic>? metadata;

  SyncEntry({
    required this.id,
    required this.action,
    required this.timestamp,
    this.dataHash,
    this.dataSize,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action.toString(),
      'timestamp': timestamp.toIso8601String(),
      'dataHash': dataHash,
      'dataSize': dataSize,
      'metadata': metadata,
    };
  }

  factory SyncEntry.fromJson(Map<String, dynamic> json) {
    return SyncEntry(
      id: json['id'],
      action: SyncAction.values.firstWhere(
        (e) => e.toString() == json['action'],
      ),
      timestamp: DateTime.parse(json['timestamp']),
      dataHash: json['dataHash'],
      dataSize: json['dataSize'],
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }
}

/// Types of sync actions
enum SyncAction { create, update, delete, restore }

/// Sync request message
class SyncRequest {
  final String requestId;
  final String deviceId;
  final String vaultId;
  final SyncManifest manifest;
  final SyncRequestType type;
  final Map<String, dynamic>? parameters;

  SyncRequest({
    required this.requestId,
    required this.deviceId,
    required this.vaultId,
    required this.manifest,
    required this.type,
    this.parameters,
  });

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'deviceId': deviceId,
      'vaultId': vaultId,
      'manifest': manifest.toJson(),
      'type': type.toString(),
      'parameters': parameters,
    };
  }

  factory SyncRequest.fromJson(Map<String, dynamic> json) {
    return SyncRequest(
      requestId: json['requestId'],
      deviceId: json['deviceId'],
      vaultId: json['vaultId'],
      manifest: SyncManifest.fromJson(json['manifest']),
      type: SyncRequestType.values.firstWhere(
        (e) => e.toString() == json['type'],
      ),
      parameters: json['parameters'] != null
          ? Map<String, dynamic>.from(json['parameters'])
          : null,
    );
  }
}

/// Types of sync requests
enum SyncRequestType {
  fullSync,
  incrementalSync,
  conflictResolution,
  statusCheck,
}

/// Sync response message
class SyncResponse {
  final String requestId;
  final String deviceId;
  final SyncResponseStatus status;
  final SyncManifest? manifest;
  final List<SyncConflict>? conflicts;
  final Map<String, Uint8List>? data;
  final String? error;
  final Map<String, dynamic>? metadata;

  SyncResponse({
    required this.requestId,
    required this.deviceId,
    required this.status,
    this.manifest,
    this.conflicts,
    this.data,
    this.error,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'deviceId': deviceId,
      'status': status.toString(),
      'manifest': manifest?.toJson(),
      'conflicts': conflicts?.map((c) => c.toJson()).toList(),
      'data': data?.map((key, value) => MapEntry(key, base64Encode(value))),
      'error': error,
      'metadata': metadata,
    };
  }

  factory SyncResponse.fromJson(Map<String, dynamic> json) {
    Map<String, Uint8List>? dataMap;
    if (json['data'] != null) {
      final dataJson = json['data'] as Map<String, dynamic>;
      dataMap = dataJson.map(
        (key, value) => MapEntry(key, base64Decode(value as String)),
      );
    }

    List<SyncConflict>? conflictsList;
    if (json['conflicts'] != null) {
      final conflictsJson = json['conflicts'] as List;
      conflictsList = conflictsJson
          .map((c) => SyncConflict.fromJson(c))
          .toList();
    }

    return SyncResponse(
      requestId: json['requestId'],
      deviceId: json['deviceId'],
      status: SyncResponseStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
      ),
      manifest: json['manifest'] != null
          ? SyncManifest.fromJson(json['manifest'])
          : null,
      conflicts: conflictsList,
      data: dataMap,
      error: json['error'],
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }
}

/// Status of sync response
enum SyncResponseStatus {
  success,
  conflict,
  error,
  unauthorized,
  vaultNotFound,
  deviceNotPaired,
}

/// Represents a sync conflict between devices
class SyncConflict {
  final String entryId;
  final SyncEntry localEntry;
  final SyncEntry remoteEntry;
  final ConflictType type;
  final ConflictResolution? suggestedResolution;

  SyncConflict({
    required this.entryId,
    required this.localEntry,
    required this.remoteEntry,
    required this.type,
    this.suggestedResolution,
  });

  Map<String, dynamic> toJson() {
    return {
      'entryId': entryId,
      'localEntry': localEntry.toJson(),
      'remoteEntry': remoteEntry.toJson(),
      'type': type.toString(),
      'suggestedResolution': suggestedResolution?.toString(),
    };
  }

  factory SyncConflict.fromJson(Map<String, dynamic> json) {
    return SyncConflict(
      entryId: json['entryId'],
      localEntry: SyncEntry.fromJson(json['localEntry']),
      remoteEntry: SyncEntry.fromJson(json['remoteEntry']),
      type: ConflictType.values.firstWhere((e) => e.toString() == json['type']),
      suggestedResolution: json['suggestedResolution'] != null
          ? ConflictResolution.values.firstWhere(
              (e) => e.toString() == json['suggestedResolution'],
            )
          : null,
    );
  }
}

/// Types of sync conflicts
enum ConflictType { updateUpdate, updateDelete, deleteUpdate, createCreate }

/// Conflict resolution strategies
enum ConflictResolution {
  useLocal,
  useRemote,
  merge,
  userChoice,
  lastWriterWins,
}

/// Encrypted sync packet for transmission
class EncryptedSyncPacket {
  final String deviceId;
  final String nonce;
  final Uint8List encryptedData;
  final String signature;
  final DateTime timestamp;

  EncryptedSyncPacket({
    required this.deviceId,
    required this.nonce,
    required this.encryptedData,
    required this.signature,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'nonce': nonce,
      'encryptedData': base64Encode(encryptedData),
      'signature': signature,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory EncryptedSyncPacket.fromJson(Map<String, dynamic> json) {
    return EncryptedSyncPacket(
      deviceId: json['deviceId'],
      nonce: json['nonce'],
      encryptedData: base64Decode(json['encryptedData']),
      signature: json['signature'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
