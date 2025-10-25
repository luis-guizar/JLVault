import 'package:uuid/uuid.dart';

/// Represents a device that can participate in P2P sync
class SyncDevice {
  final String id;
  final String name;
  final String type;
  final String address;
  final int port;
  final Map<String, String> capabilities;
  final DateTime discoveredAt;
  final DeviceStatus status;
  final String? publicKey;

  SyncDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.port,
    required this.capabilities,
    required this.discoveredAt,
    required this.status,
    this.publicKey,
  });

  factory SyncDevice.fromServiceInfo(Map<String, dynamic> serviceInfo) {
    return SyncDevice(
      id: serviceInfo['id'] ?? const Uuid().v4(),
      name: serviceInfo['name'] ?? 'Unknown Device',
      type: serviceInfo['type'] ?? 'simple_vault',
      address: serviceInfo['address'] ?? '',
      port: serviceInfo['port'] ?? 0,
      capabilities: Map<String, String>.from(serviceInfo['capabilities'] ?? {}),
      discoveredAt: DateTime.now(),
      status: DeviceStatus.discovered,
      publicKey: serviceInfo['publicKey'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'address': address,
      'port': port,
      'capabilities': capabilities,
      'discoveredAt': discoveredAt.toIso8601String(),
      'status': status.toString(),
      'publicKey': publicKey,
    };
  }

  factory SyncDevice.fromJson(Map<String, dynamic> json) {
    return SyncDevice(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      address: json['address'],
      port: json['port'],
      capabilities: Map<String, String>.from(json['capabilities']),
      discoveredAt: DateTime.parse(json['discoveredAt']),
      status: DeviceStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => DeviceStatus.discovered,
      ),
      publicKey: json['publicKey'],
    );
  }

  SyncDevice copyWith({
    String? id,
    String? name,
    String? type,
    String? address,
    int? port,
    Map<String, String>? capabilities,
    DateTime? discoveredAt,
    DeviceStatus? status,
    String? publicKey,
  }) {
    return SyncDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      address: address ?? this.address,
      port: port ?? this.port,
      capabilities: capabilities ?? this.capabilities,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      status: status ?? this.status,
      publicKey: publicKey ?? this.publicKey,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncDevice && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SyncDevice(id: $id, name: $name, address: $address:$port, status: $status)';
  }
}

enum DeviceStatus {
  discovered,
  connecting,
  connected,
  paired,
  syncing,
  offline,
  error,
}

/// Device capabilities that can be advertised during discovery
class DeviceCapabilities {
  static const String syncProtocolVersion = 'sync_protocol_version';
  static const String supportedVaultFormats = 'supported_vault_formats';
  static const String encryptionMethods = 'encryption_methods';
  static const String maxVaultSize = 'max_vault_size';
  static const String deviceType = 'device_type';
  static const String appVersion = 'app_version';

  static Map<String, String> getLocalCapabilities() {
    return {
      syncProtocolVersion: '1.0',
      supportedVaultFormats: 'simple_vault_v1',
      encryptionMethods: 'aes256_gcm,chacha20_poly1305',
      maxVaultSize: '100MB',
      deviceType: 'android',
      appVersion: '1.0.0',
    };
  }
}
