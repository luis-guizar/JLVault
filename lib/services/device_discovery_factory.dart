import 'device_discovery_service.dart';
import 'mdns_device_discovery_service.dart';

/// Factory for creating device discovery service instances
class DeviceDiscoveryFactory {
  static DeviceDiscoveryService? _instance;

  /// Get the singleton instance of the device discovery service
  static DeviceDiscoveryService getInstance({
    DiscoveryConfig? config,
    String? deviceId,
  }) {
    _instance ??= MdnsDeviceDiscoveryService(
      config: config,
      deviceId: deviceId,
    );
    return _instance!;
  }

  /// Create a new instance (for testing or special cases)
  static DeviceDiscoveryService createInstance({
    DiscoveryConfig? config,
    String? deviceId,
  }) {
    return MdnsDeviceDiscoveryService(config: config, deviceId: deviceId);
  }

  /// Reset the singleton instance
  static Future<void> reset() async {
    if (_instance != null) {
      await _instance!.dispose();
      _instance = null;
    }
  }
}
