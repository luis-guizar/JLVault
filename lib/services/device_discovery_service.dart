import 'dart:async';
import '../models/sync_device.dart';

/// Abstract interface for device discovery functionality
abstract class DeviceDiscoveryService {
  /// Stream of discovered devices
  Stream<List<SyncDevice>> get discoveredDevices;

  /// Stream of device status changes
  Stream<SyncDevice> get deviceStatusChanges;

  /// Start advertising this device for discovery
  Future<void> startAdvertising({
    required String deviceName,
    required int port,
    Map<String, String>? customCapabilities,
  });

  /// Stop advertising this device
  Future<void> stopAdvertising();

  /// Start scanning for other devices
  Future<void> startScanning();

  /// Stop scanning for devices
  Future<void> stopScanning();

  /// Get the current list of discovered devices
  List<SyncDevice> getDiscoveredDevices();

  /// Check if a specific device is currently reachable
  Future<bool> isDeviceReachable(SyncDevice device);

  /// Get detailed information about a device
  Future<SyncDevice?> getDeviceInfo(String deviceId);

  /// Remove a device from the discovered list
  Future<void> removeDevice(String deviceId);

  /// Clear all discovered devices
  Future<void> clearDiscoveredDevices();

  /// Check if discovery is currently active
  bool get isScanning;

  /// Check if advertising is currently active
  bool get isAdvertising;

  /// Dispose of resources
  Future<void> dispose();
}

/// Exception thrown when device discovery operations fail
class DeviceDiscoveryException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const DeviceDiscoveryException(this.message, {this.code, this.originalError});

  @override
  String toString() {
    return 'DeviceDiscoveryException: $message${code != null ? ' (code: $code)' : ''}';
  }
}

/// Configuration for device discovery
class DiscoveryConfig {
  final String serviceName;
  final String serviceType;
  final Duration scanTimeout;
  final Duration advertiseTimeout;
  final int maxDevices;
  final bool autoRemoveOfflineDevices;
  final Duration offlineTimeout;

  const DiscoveryConfig({
    this.serviceName = 'Simple Vault',
    this.serviceType = '_simplevault._tcp',
    this.scanTimeout = const Duration(seconds: 30),
    this.advertiseTimeout = const Duration(hours: 24),
    this.maxDevices = 10,
    this.autoRemoveOfflineDevices = true,
    this.offlineTimeout = const Duration(minutes: 5),
  });
}
