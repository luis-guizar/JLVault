import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/sync_device.dart';
import 'device_discovery_service.dart';
import 'device_discovery_factory.dart';

/// Manages device discovery, pairing, and persistent device storage
class DeviceManager {
  static const String _storageKeyDevices = 'paired_devices';
  static const String _storageKeyDeviceId = 'device_id';
  static const String _storageKeyDeviceName = 'device_name';

  final FlutterSecureStorage _storage;
  final DeviceDiscoveryService _discoveryService;
  final String _deviceId;
  final Map<String, SyncDevice> _pairedDevices = {};

  final StreamController<List<SyncDevice>> _pairedDevicesController =
      StreamController<List<SyncDevice>>.broadcast();
  final StreamController<List<SyncDevice>> _discoveredDevicesController =
      StreamController<List<SyncDevice>>.broadcast();

  StreamSubscription? _discoverySubscription;
  StreamSubscription? _statusSubscription;

  DeviceManager._({
    required FlutterSecureStorage storage,
    required DeviceDiscoveryService discoveryService,
    required String deviceId,
  }) : _storage = storage,
       _discoveryService = discoveryService,
       _deviceId = deviceId;

  /// Create a new DeviceManager instance
  static Future<DeviceManager> create({
    FlutterSecureStorage? storage,
    DeviceDiscoveryService? discoveryService,
  }) async {
    final secureStorage = storage ?? const FlutterSecureStorage();

    // Get or create device ID
    String? deviceId = await secureStorage.read(key: _storageKeyDeviceId);
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await secureStorage.write(key: _storageKeyDeviceId, value: deviceId);
    }

    final discovery = discoveryService ?? DeviceDiscoveryFactory.getInstance();
    final manager = DeviceManager._(
      storage: secureStorage,
      discoveryService: discovery,
      deviceId: deviceId,
    );

    await manager._initialize();
    return manager;
  }

  /// Stream of paired devices
  Stream<List<SyncDevice>> get pairedDevices => _pairedDevicesController.stream;

  /// Stream of discovered devices (not yet paired)
  Stream<List<SyncDevice>> get discoveredDevices =>
      _discoveredDevicesController.stream;

  /// Get the current device ID
  String get deviceId => _deviceId;

  /// Get the current device name
  Future<String> getDeviceName() async {
    final name = await _storage.read(key: _storageKeyDeviceName);
    return name ?? 'My Device';
  }

  /// Set the device name
  Future<void> setDeviceName(String name) async {
    await _storage.write(key: _storageKeyDeviceName, value: name);
  }

  /// Get list of paired devices
  List<SyncDevice> getPairedDevices() {
    return _pairedDevices.values.toList();
  }

  /// Get list of discovered devices (excluding paired ones)
  List<SyncDevice> getDiscoveredDevices() {
    final discovered = _discoveryService.getDiscoveredDevices();
    return discovered
        .where((device) => !_pairedDevices.containsKey(device.id))
        .toList();
  }

  /// Start advertising this device for discovery
  Future<void> startAdvertising({int port = 8080}) async {
    final deviceName = await getDeviceName();
    await _discoveryService.startAdvertising(
      deviceName: deviceName,
      port: port,
    );
  }

  /// Stop advertising this device
  Future<void> stopAdvertising() async {
    await _discoveryService.stopAdvertising();
  }

  /// Start scanning for other devices
  Future<void> startScanning() async {
    await _discoveryService.startScanning();
  }

  /// Stop scanning for devices
  Future<void> stopScanning() async {
    await _discoveryService.stopScanning();
  }

  /// Pair with a discovered device
  Future<void> pairDevice(SyncDevice device) async {
    if (_pairedDevices.containsKey(device.id)) {
      throw DeviceDiscoveryException('Device already paired: ${device.name}');
    }

    final pairedDevice = device.copyWith(status: DeviceStatus.paired);
    _pairedDevices[device.id] = pairedDevice;

    await _savePairedDevices();
    _notifyPairedDevicesChanged();
    _notifyDiscoveredDevicesChanged();
  }

  /// Unpair a device
  Future<void> unpairDevice(String deviceId) async {
    final device = _pairedDevices.remove(deviceId);
    if (device != null) {
      await _savePairedDevices();
      _notifyPairedDevicesChanged();
      _notifyDiscoveredDevicesChanged();
    }
  }

  /// Rename a paired device
  Future<void> renameDevice(String deviceId, String newName) async {
    final device = _pairedDevices[deviceId];
    if (device != null) {
      _pairedDevices[deviceId] = device.copyWith(name: newName);
      await _savePairedDevices();
      _notifyPairedDevicesChanged();
    }
  }

  /// Check if a device is paired
  bool isDevicePaired(String deviceId) {
    return _pairedDevices.containsKey(deviceId);
  }

  /// Get a paired device by ID
  SyncDevice? getPairedDevice(String deviceId) {
    return _pairedDevices[deviceId];
  }

  /// Update device status
  Future<void> updateDeviceStatus(String deviceId, DeviceStatus status) async {
    final device = _pairedDevices[deviceId];
    if (device != null) {
      _pairedDevices[deviceId] = device.copyWith(status: status);
      _notifyPairedDevicesChanged();
    }
  }

  /// Check if any devices are currently online
  bool hasOnlineDevices() {
    return _pairedDevices.values.any(
      (device) =>
          device.status == DeviceStatus.connected ||
          device.status == DeviceStatus.syncing,
    );
  }

  /// Get online devices
  List<SyncDevice> getOnlineDevices() {
    return _pairedDevices.values
        .where(
          (device) =>
              device.status == DeviceStatus.connected ||
              device.status == DeviceStatus.syncing,
        )
        .toList();
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await _discoverySubscription?.cancel();
    await _statusSubscription?.cancel();
    await _pairedDevicesController.close();
    await _discoveredDevicesController.close();
    await _discoveryService.dispose();
  }

  Future<void> _initialize() async {
    await _loadPairedDevices();
    _setupDiscoveryListeners();
  }

  Future<void> _loadPairedDevices() async {
    try {
      final devicesJson = await _storage.read(key: _storageKeyDevices);
      if (devicesJson != null) {
        final devicesList = jsonDecode(devicesJson) as List;
        for (final deviceData in devicesList) {
          final device = SyncDevice.fromJson(deviceData);
          _pairedDevices[device.id] = device;
        }
      }
    } catch (e) {
      print('Error loading paired devices: $e');
    }
  }

  Future<void> _savePairedDevices() async {
    try {
      final devicesList = _pairedDevices.values
          .map((device) => device.toJson())
          .toList();
      final devicesJson = jsonEncode(devicesList);
      await _storage.write(key: _storageKeyDevices, value: devicesJson);
    } catch (e) {
      print('Error saving paired devices: $e');
    }
  }

  void _setupDiscoveryListeners() {
    _discoverySubscription = _discoveryService.discoveredDevices.listen((_) {
      _notifyDiscoveredDevicesChanged();
    });

    _statusSubscription = _discoveryService.deviceStatusChanges.listen((
      device,
    ) {
      // Update paired device status if it's in our paired list
      if (_pairedDevices.containsKey(device.id)) {
        _pairedDevices[device.id] = device;
        _notifyPairedDevicesChanged();
      }
    });
  }

  void _notifyPairedDevicesChanged() {
    if (!_pairedDevicesController.isClosed) {
      _pairedDevicesController.add(getPairedDevices());
    }
  }

  void _notifyDiscoveredDevicesChanged() {
    if (!_discoveredDevicesController.isClosed) {
      _discoveredDevicesController.add(getDiscoveredDevices());
    }
  }
}
