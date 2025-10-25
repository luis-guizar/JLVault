import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/sync_device.dart';
import 'device_discovery_service.dart';

/// Simplified device discovery service (HTTP-based implementation)
class MdnsDeviceDiscoveryService implements DeviceDiscoveryService {
  final DiscoveryConfig _config;
  final String _deviceId;
  final Map<String, SyncDevice> _discoveredDevices = {};

  final StreamController<List<SyncDevice>> _devicesController =
      StreamController<List<SyncDevice>>.broadcast();
  final StreamController<SyncDevice> _deviceStatusController =
      StreamController<SyncDevice>.broadcast();

  HttpServer? _advertisingServer;
  Timer? _discoveryTimer;
  Timer? _scanTimer;
  Timer? _advertiseTimer;
  Timer? _cleanupTimer;

  bool _isScanning = false;
  bool _isAdvertising = false;
  bool _disposed = false;

  MdnsDeviceDiscoveryService({DiscoveryConfig? config, String? deviceId})
    : _config = config ?? const DiscoveryConfig(),
      _deviceId = deviceId ?? const Uuid().v4() {
    _startCleanupTimer();
  }

  @override
  Stream<List<SyncDevice>> get discoveredDevices => _devicesController.stream;

  @override
  Stream<SyncDevice> get deviceStatusChanges => _deviceStatusController.stream;

  @override
  bool get isScanning => _isScanning;

  @override
  bool get isAdvertising => _isAdvertising;

  @override
  Future<void> startAdvertising({
    required String deviceName,
    required int port,
    Map<String, String>? customCapabilities,
  }) async {
    if (_disposed) throw const DeviceDiscoveryException('Service disposed');
    if (_isAdvertising) return;

    try {
      // Start HTTP server for device discovery
      _advertisingServer = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _isAdvertising = true;

      _advertisingServer!.listen((HttpRequest request) {
        if (request.uri.path == '/discover') {
          final capabilities = {
            ...DeviceCapabilities.getLocalCapabilities(),
            ...?customCapabilities,
          };

          final deviceInfo = {
            'id': _deviceId,
            'name': deviceName,
            'capabilities': capabilities,
            'version': '1.0',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          };

          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(deviceInfo));
          request.response.close();
        } else {
          request.response.statusCode = 404;
          request.response.close();
        }
      });

      // Set advertise timeout
      _advertiseTimer?.cancel();
      _advertiseTimer = Timer(_config.advertiseTimeout, () {
        stopAdvertising();
      });

      print('Started advertising as: $deviceName on port $port');
    } catch (e) {
      throw DeviceDiscoveryException(
        'Failed to start advertising: ${e.toString()}',
        originalError: e,
      );
    }
  }

  @override
  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;

    try {
      await _advertisingServer?.close();
      _advertisingServer = null;
      _isAdvertising = false;
      _advertiseTimer?.cancel();
      print('Stopped advertising');
    } catch (e) {
      throw DeviceDiscoveryException(
        'Failed to stop advertising: ${e.toString()}',
        originalError: e,
      );
    }
  }

  @override
  Future<void> startScanning() async {
    if (_disposed) throw const DeviceDiscoveryException('Service disposed');
    if (_isScanning) return;

    try {
      _isScanning = true;

      // Start periodic network scanning
      _discoveryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _scanLocalNetwork();
      });

      // Set scan timeout
      _scanTimer?.cancel();
      _scanTimer = Timer(_config.scanTimeout, () {
        stopScanning();
      });

      print('Started scanning for devices');
    } catch (e) {
      throw DeviceDiscoveryException(
        'Failed to start scanning: ${e.toString()}',
        originalError: e,
      );
    }
  }

  @override
  Future<void> stopScanning() async {
    if (!_isScanning) return;

    try {
      _discoveryTimer?.cancel();
      _discoveryTimer = null;
      _isScanning = false;
      _scanTimer?.cancel();
      print('Stopped scanning');
    } catch (e) {
      throw DeviceDiscoveryException(
        'Failed to stop scanning: ${e.toString()}',
        originalError: e,
      );
    }
  }

  @override
  List<SyncDevice> getDiscoveredDevices() {
    return _discoveredDevices.values.toList();
  }

  @override
  Future<bool> isDeviceReachable(SyncDevice device) async {
    try {
      final socket = await Socket.connect(
        device.address,
        device.port,
        timeout: const Duration(seconds: 5),
      );
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<SyncDevice?> getDeviceInfo(String deviceId) async {
    return _discoveredDevices[deviceId];
  }

  @override
  Future<void> removeDevice(String deviceId) async {
    final device = _discoveredDevices.remove(deviceId);
    if (device != null) {
      _notifyDevicesChanged();
      _deviceStatusController.add(
        device.copyWith(status: DeviceStatus.offline),
      );
    }
  }

  @override
  Future<void> clearDiscoveredDevices() async {
    _discoveredDevices.clear();
    _notifyDevicesChanged();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    await stopScanning();
    await stopAdvertising();

    _scanTimer?.cancel();
    _advertiseTimer?.cancel();
    _cleanupTimer?.cancel();

    await _devicesController.close();
    await _deviceStatusController.close();
  }

  void _scanLocalNetwork() async {
    try {
      // Get local network interfaces
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 &&
              !address.isLoopback &&
              !address.isLinkLocal) {
            await _scanNetworkRange(address.address);
          }
        }
      }
    } catch (e) {
      print('Error scanning local network: $e');
    }
  }

  Future<void> _scanNetworkRange(String baseAddress) async {
    // Simple network range scanning (192.168.1.1-254)
    final parts = baseAddress.split('.');
    if (parts.length != 4) return;

    final baseNetwork = '${parts[0]}.${parts[1]}.${parts[2]}';

    // Scan a few common ports
    final ports = [8080, 8081, 8082, 8083, 8084];

    for (int i = 1; i <= 254; i++) {
      final targetAddress = '$baseNetwork.$i';
      if (targetAddress == baseAddress) continue; // Skip our own address

      for (final port in ports) {
        try {
          final client = HttpClient();
          client.connectionTimeout = const Duration(seconds: 1);

          final request = await client.getUrl(
            Uri.parse('http://$targetAddress:$port/discover'),
          );

          final response = await request.close().timeout(
            const Duration(seconds: 2),
          );

          if (response.statusCode == 200) {
            final responseBody = await utf8.decoder.bind(response).join();
            try {
              final deviceInfo = jsonDecode(responseBody);
              _handleDeviceFound(targetAddress, port, deviceInfo);
            } catch (e) {
              // Not a valid JSON response
            }
          }

          client.close();
        } catch (e) {
          // Connection failed or timeout - device not available
        }
      }
    }
  }

  void _handleDeviceFound(
    String address,
    int port,
    Map<String, dynamic> deviceInfo,
  ) {
    try {
      final deviceId = deviceInfo['id'];
      if (deviceId == null || deviceId == _deviceId) {
        return; // Skip our own device or devices without ID
      }

      final capabilities =
          deviceInfo['capabilities'] as Map<String, dynamic>? ?? {};

      final device = SyncDevice(
        id: deviceId,
        name: deviceInfo['name'] ?? 'Unknown Device',
        type: 'simple_vault',
        address: address,
        port: port,
        capabilities: Map<String, String>.from(capabilities),
        discoveredAt: DateTime.now(),
        status: DeviceStatus.discovered,
      );

      final existingDevice = _discoveredDevices[deviceId];
      if (existingDevice == null || existingDevice != device) {
        _discoveredDevices[deviceId] = device;
        _notifyDevicesChanged();
        _deviceStatusController.add(device);
        print('Discovered device: ${device.name} ($address:$port)');
      }
    } catch (e) {
      print('Error handling device found: $e');
    }
  }

  void _notifyDevicesChanged() {
    if (!_devicesController.isClosed) {
      _devicesController.add(getDiscoveredDevices());
    }
  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _cleanupOfflineDevices();
    });
  }

  void _cleanupOfflineDevices() {
    if (!_config.autoRemoveOfflineDevices) return;

    final now = DateTime.now();
    final devicesToRemove = <String>[];

    for (final entry in _discoveredDevices.entries) {
      final device = entry.value;
      if (device.status == DeviceStatus.offline) {
        final timeSinceDiscovered = now.difference(device.discoveredAt);
        if (timeSinceDiscovered > _config.offlineTimeout) {
          devicesToRemove.add(entry.key);
        }
      }
    }

    for (final deviceId in devicesToRemove) {
      _discoveredDevices.remove(deviceId);
    }

    if (devicesToRemove.isNotEmpty) {
      _notifyDevicesChanged();
      print('Cleaned up ${devicesToRemove.length} offline devices');
    }
  }
}
