import 'package:flutter/material.dart';
import '../services/device_manager.dart';
import '../services/device_pairing_service.dart';
import '../services/sync_status_service.dart';
import '../services/selective_sync_service.dart';
import '../services/sync_conflict_resolver.dart';
import '../widgets/device_management_widget.dart';
import '../widgets/qr_pairing_widget.dart';
import '../widgets/selective_sync_widget.dart';

/// Main screen for P2P sync functionality
class P2PSyncScreen extends StatefulWidget {
  const P2PSyncScreen({super.key});

  @override
  State<P2PSyncScreen> createState() => _P2PSyncScreenState();
}

class _P2PSyncScreenState extends State<P2PSyncScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DeviceManager _deviceManager;
  late DevicePairingService _pairingService;
  late SyncStatusService _syncStatusService;
  late SelectiveSyncService _selectiveSyncService;
  late SyncConflictResolver _conflictResolver;

  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeServices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _disposeServices();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize services
      _deviceManager = await DeviceManager.create();
      _pairingService = DevicePairingService(_deviceManager);
      _syncStatusService = SyncStatusService();
      _selectiveSyncService = SelectiveSyncService();
      _conflictResolver = SyncConflictResolver();

      // Initialize services
      await _syncStatusService.initialize();
      await _selectiveSyncService.initialize();

      // Check if widget is still mounted before calling setState
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      // Check if widget is still mounted before calling setState
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _disposeServices() async {
    if (_isInitialized) {
      await _deviceManager.dispose();
      await _pairingService.dispose();
      await _syncStatusService.dispose();
      await _selectiveSyncService.dispose();
      await _conflictResolver.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('P2P Sync'),
        bottom: _isInitialized
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.devices), text: 'Devices'),
                  Tab(icon: Icon(Icons.qr_code), text: 'Pair'),
                  Tab(icon: Icon(Icons.sync), text: 'Settings'),
                ],
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _buildErrorState();
    }

    if (!_isInitialized) {
      return _buildLoadingState();
    }

    return TabBarView(
      controller: _tabController,
      children: [_buildDevicesTab(), _buildPairingTab(), _buildSettingsTab()],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Initializing P2P Sync...'),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Failed to initialize P2P Sync',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (mounted) {
                setState(() {
                  _error = null;
                  _isInitialized = false;
                });
                _initializeServices();
              }
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: DeviceManagementWidget(
        deviceManager: _deviceManager,
        syncStatusService: _syncStatusService,
      ),
    );
  }

  Widget _buildPairingTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.qr_code), text: 'Generate QR'),
                      Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan QR'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(
                          child: QrPairingGeneratorWidget(
                            pairingService: _pairingService,
                            onPairingComplete: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Device paired successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            onError: (error) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Pairing error: $error'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            },
                          ),
                        ),
                        QrPairingScannerWidget(
                          pairingService: _pairingService,
                          onPairingComplete: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Device paired successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          onError: (error) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Pairing error: $error'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SelectiveSyncWidget(
        pairedDevices: _deviceManager.getPairedDevices(),
        availableVaults: ['vault1', 'vault2', 'vault3'], // Mock vault IDs
        selectiveSyncService: _selectiveSyncService,
      ),
    );
  }
}
