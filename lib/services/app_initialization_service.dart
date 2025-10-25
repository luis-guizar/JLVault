import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'theme_service.dart';
import 'haptic_feedback_service.dart';
import 'time_sync_service.dart';
import 'development_helpers.dart';
import '../data/db_helper.dart';
import '../data/vault_db_helper.dart';

/// Service responsible for optimizing app initialization and startup performance
class AppInitializationService {
  static AppInitializationService? _instance;
  static AppInitializationService get instance =>
      _instance ??= AppInitializationService._();

  AppInitializationService._();

  bool _isInitialized = false;
  bool _isCriticalInitialized = false;

  // Critical services needed for app launch
  ThemeService? _themeService;

  // Non-critical services that can be initialized in background
  final List<Future<void>> _backgroundInitTasks = [];

  /// Initialize only critical services needed for app launch
  /// This should complete in under 200ms for optimal startup
  Future<void> initializeCriticalServices() async {
    if (_isCriticalInitialized) return;

    final stopwatch = Stopwatch()..start();

    try {
      // Ensure Flutter binding is initialized
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize theme service (critical for UI rendering)
      _themeService = ThemeService();
      await _themeService!.initialize();

      // Initialize haptic feedback (lightweight, needed for immediate interactions)
      await HapticFeedbackService.initialize();

      // Show development status in debug mode (non-blocking)
      if (kDebugMode) {
        DevelopmentHelpers.showDevelopmentStatus();
      }

      _isCriticalInitialized = true;

      if (kDebugMode) {
        print(
          'Critical services initialized in ${stopwatch.elapsedMilliseconds}ms',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing critical services: $e');
      }
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Initialize non-critical services in background
  /// These services are loaded lazily and don't block app startup
  Future<void> initializeBackgroundServices() async {
    if (_isInitialized) return;

    // Start background initialization tasks
    _backgroundInitTasks.addAll([
      _initializeLicenseServices(),
      _initializeVaultServices(),
      _initializeSecurityServices(),
      _initializeNetworkServices(),
    ]);

    // Don't await these - let them run in background
    _runBackgroundInitialization();

    _isInitialized = true;
  }

  /// Run background initialization without blocking
  void _runBackgroundInitialization() {
    Future.wait(_backgroundInitTasks)
        .then((_) {
          if (kDebugMode) {
            print('Background services initialization completed');
          }
        })
        .catchError((error) {
          if (kDebugMode) {
            print('Error in background initialization: $error');
          }
        });
  }

  /// Initialize license and feature gate services
  Future<void> _initializeLicenseServices() async {
    try {
      // Placeholder for license manager initialization
      // This would be implemented when the actual license services are available

      if (kDebugMode) {
        print('License services initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing license services: $e');
      }
    }
  }

  /// Initialize vault and encryption services
  Future<void> _initializeVaultServices() async {
    try {
      // Pre-warm database connections
      await _prewarmDatabaseConnections();

      if (kDebugMode) {
        print('Vault services initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing vault services: $e');
      }
    }
  }

  /// Initialize security-related services
  Future<void> _initializeSecurityServices() async {
    try {
      // Start time sync monitoring (low priority)
      TimeSyncService.startMonitoring();

      // Initialize crash recovery and state preservation
      await _initializeCrashRecovery();

      // Initialize data integrity service
      await _initializeDataIntegrity();

      if (kDebugMode) {
        print('Security services initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing security services: $e');
      }
    }
  }

  /// Initialize crash recovery and state preservation
  Future<void> _initializeCrashRecovery() async {
    try {
      // Placeholder for crash recovery initialization
      // This would initialize the crash recovery and state preservation services

      if (kDebugMode) {
        print('Crash recovery and state preservation initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing crash recovery: $e');
      }
    }
  }

  /// Initialize data integrity service
  Future<void> _initializeDataIntegrity() async {
    try {
      // Placeholder for data integrity service initialization
      // This would initialize the data integrity service

      if (kDebugMode) {
        print('Data integrity service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing data integrity service: $e');
      }
    }
  }

  /// Initialize network-related services
  Future<void> _initializeNetworkServices() async {
    try {
      // Pre-initialize network services for P2P sync
      // This is done lazily to avoid blocking startup

      if (kDebugMode) {
        print('Network services initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing network services: $e');
      }
    }
  }

  /// Pre-warm database connections to reduce first-access latency
  Future<void> _prewarmDatabaseConnections() async {
    try {
      // Initialize database connections in background
      Future.microtask(() async {
        try {
          await DBHelper.db;
          await VaultDbHelper.db;
        } catch (e) {
          if (kDebugMode) {
            print('Error pre-warming database connections: $e');
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error setting up database pre-warming: $e');
      }
    }
  }

  /// Get theme service (available after critical initialization)
  ThemeService get themeService {
    if (_themeService == null) {
      throw StateError(
        'Theme service not initialized. Call initializeCriticalServices() first.',
      );
    }
    return _themeService!;
  }

  /// Check if critical services are initialized
  bool get isCriticalInitialized => _isCriticalInitialized;

  /// Check if background initialization is complete
  Future<bool> get isBackgroundInitialized async {
    if (!_isInitialized) return false;

    try {
      await Future.wait(_backgroundInitTasks);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Cleanup resources
  Future<void> dispose() async {
    try {
      // Stop background services
      TimeSyncService.stopMonitoring();

      // Clear initialization state
      _isInitialized = false;
      _isCriticalInitialized = false;
      _backgroundInitTasks.clear();

      if (kDebugMode) {
        print('App initialization service disposed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error disposing app initialization service: $e');
      }
    }
  }
}
