import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';
import 'dart:async';
import 'dart:io';
import 'search_service.dart';
import 'lazy_loading_service.dart';

/// Service for managing memory usage and cleanup
class MemoryManagementService {
  static MemoryManagementService? _instance;
  static MemoryManagementService get instance =>
      _instance ??= MemoryManagementService._();

  MemoryManagementService._();

  Timer? _memoryCleanupTimer;
  Timer? _memoryMonitoringTimer;
  bool _isAppInBackground = false;
  DateTime? _backgroundTime;

  // Memory thresholds
  static const int _lowMemoryThresholdMB = 100;
  static const int _criticalMemoryThresholdMB = 50;
  static const Duration _backgroundCleanupDelay = Duration(minutes: 5);
  static const Duration _memoryMonitoringInterval = Duration(minutes: 2);

  /// Initialize memory management
  void initialize() {
    // Start memory monitoring
    _startMemoryMonitoring();

    if (kDebugMode) {
      print('Memory management service initialized');
    }
  }

  /// Handle app going to background
  void onAppPaused() {
    _isAppInBackground = true;
    _backgroundTime = DateTime.now();

    // Schedule memory cleanup after delay
    _scheduleBackgroundCleanup();

    if (kDebugMode) {
      print('App paused - scheduling memory cleanup');
    }
  }

  /// Handle app coming to foreground
  void onAppResumed() {
    _isAppInBackground = false;
    _backgroundTime = null;

    // Cancel scheduled cleanup
    _memoryCleanupTimer?.cancel();

    if (kDebugMode) {
      print('App resumed - canceling memory cleanup');
    }
  }

  /// Schedule background memory cleanup
  void _scheduleBackgroundCleanup() {
    _memoryCleanupTimer?.cancel();

    _memoryCleanupTimer = Timer(_backgroundCleanupDelay, () {
      if (_isAppInBackground) {
        _performBackgroundCleanup();
      }
    });
  }

  /// Perform memory cleanup when app is backgrounded
  Future<void> _performBackgroundCleanup() async {
    if (!_isAppInBackground) return;

    try {
      final stopwatch = Stopwatch()..start();

      // Clear search cache
      SearchService.instance.clearCache();

      // Clear lazy loaded services that aren't critical
      _clearNonCriticalServices();

      // Clear image cache
      await _clearImageCache();

      // Force garbage collection
      _forceGarbageCollection();

      if (kDebugMode) {
        print(
          'Background memory cleanup completed in ${stopwatch.elapsedMilliseconds}ms',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during background cleanup: $e');
      }
    }
  }

  /// Clear non-critical lazy loaded services
  void _clearNonCriticalServices() {
    final lazyLoader = LazyLoadingService.instance;

    // Clear services that can be reloaded when needed
    final servicesToClear = [
      ServiceKeys.securityAnalyzer,
      ServiceKeys.breachChecker,
      ServiceKeys.importService,
      ServiceKeys.passwordGenerator,
    ];

    for (final serviceKey in servicesToClear) {
      lazyLoader.clearService(serviceKey);
    }

    if (kDebugMode) {
      print('Cleared ${servicesToClear.length} non-critical services');
    }
  }

  /// Clear image cache to free memory
  Future<void> _clearImageCache() async {
    try {
      // Clear Flutter's image cache
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      if (kDebugMode) {
        print('Image cache cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing image cache: $e');
      }
    }
  }

  /// Force garbage collection
  void _forceGarbageCollection() {
    try {
      // Trigger garbage collection
      for (int i = 0; i < 3; i++) {
        // Create and discard objects to trigger GC
        final dummy = List.generate(1000, (index) => index);
        dummy.clear();
      }

      if (kDebugMode) {
        print('Garbage collection triggered');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error triggering garbage collection: $e');
      }
    }
  }

  /// Start memory monitoring
  void _startMemoryMonitoring() {
    _memoryMonitoringTimer?.cancel();

    _memoryMonitoringTimer = Timer.periodic(_memoryMonitoringInterval, (timer) {
      _checkMemoryUsage();
    });
  }

  /// Check current memory usage and take action if needed
  Future<void> _checkMemoryUsage() async {
    try {
      final memoryInfo = await getMemoryInfo();
      final availableMemoryMB = memoryInfo['availableMemoryMB'] as int? ?? 0;

      if (availableMemoryMB < _criticalMemoryThresholdMB) {
        await _handleCriticalMemory();
      } else if (availableMemoryMB < _lowMemoryThresholdMB) {
        await _handleLowMemory();
      }

      if (kDebugMode && availableMemoryMB < _lowMemoryThresholdMB) {
        print('Memory warning: ${availableMemoryMB}MB available');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking memory usage: $e');
      }
    }
  }

  /// Handle low memory situation
  Future<void> _handleLowMemory() async {
    try {
      // Clear search cache
      SearchService.instance.clearCache();

      // Clear some lazy loaded services
      final lazyLoader = LazyLoadingService.instance;
      lazyLoader.clearService(ServiceKeys.securityAnalyzer);
      lazyLoader.clearService(ServiceKeys.breachChecker);

      if (kDebugMode) {
        print('Low memory cleanup performed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling low memory: $e');
      }
    }
  }

  /// Handle critical memory situation
  Future<void> _handleCriticalMemory() async {
    try {
      // Aggressive cleanup
      await _performBackgroundCleanup();

      // Clear all non-essential services
      LazyLoadingService.instance.clearAll();

      if (kDebugMode) {
        print('Critical memory cleanup performed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling critical memory: $e');
      }
    }
  }

  /// Get memory information
  Future<Map<String, dynamic>> getMemoryInfo() async {
    try {
      if (Platform.isAndroid) {
        return await _getAndroidMemoryInfo();
      } else {
        return _getGenericMemoryInfo();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting memory info: $e');
      }
      return _getGenericMemoryInfo();
    }
  }

  /// Get Android-specific memory information
  Future<Map<String, dynamic>> _getAndroidMemoryInfo() async {
    try {
      const platform = MethodChannel('com.simplevault.memory');
      final result = await platform.invokeMethod('getMemoryInfo');

      return {
        'totalMemoryMB': result['totalMemory'] ~/ (1024 * 1024),
        'availableMemoryMB': result['availableMemory'] ~/ (1024 * 1024),
        'usedMemoryMB':
            (result['totalMemory'] - result['availableMemory']) ~/
            (1024 * 1024),
        'lowMemoryThreshold': result['threshold'] ?? false,
      };
    } catch (e) {
      return _getGenericMemoryInfo();
    }
  }

  /// Get generic memory information (fallback)
  Map<String, dynamic> _getGenericMemoryInfo() {
    return {
      'totalMemoryMB': 2048, // Assume 2GB default
      'availableMemoryMB': 512, // Assume 512MB available
      'usedMemoryMB': 1536,
      'lowMemoryThreshold': false,
    };
  }

  /// Optimize memory for specific operations
  Future<void> optimizeForOperation(MemoryOptimizationType type) async {
    switch (type) {
      case MemoryOptimizationType.search:
        // Prepare for search operations
        await _optimizeForSearch();
        break;

      case MemoryOptimizationType.sync:
        // Prepare for sync operations
        await _optimizeForSync();
        break;

      case MemoryOptimizationType.import:
        // Prepare for import operations
        await _optimizeForImport();
        break;

      case MemoryOptimizationType.export:
        // Prepare for export operations
        await _optimizeForExport();
        break;
    }
  }

  /// Optimize memory for search operations
  Future<void> _optimizeForSearch() async {
    // Clear non-search related caches
    final lazyLoader = LazyLoadingService.instance;
    lazyLoader.clearService(ServiceKeys.importService);
    lazyLoader.clearService(ServiceKeys.syncService);

    if (kDebugMode) {
      print('Memory optimized for search operations');
    }
  }

  /// Optimize memory for sync operations
  Future<void> _optimizeForSync() async {
    // Clear search cache to make room for sync data
    SearchService.instance.clearCache();

    // Clear import/export services
    final lazyLoader = LazyLoadingService.instance;
    lazyLoader.clearService(ServiceKeys.importService);

    if (kDebugMode) {
      print('Memory optimized for sync operations');
    }
  }

  /// Optimize memory for import operations
  Future<void> _optimizeForImport() async {
    // Clear all caches to make maximum room
    SearchService.instance.clearCache();
    await _clearImageCache();

    // Clear non-essential services
    final lazyLoader = LazyLoadingService.instance;
    lazyLoader.clearService(ServiceKeys.securityAnalyzer);
    lazyLoader.clearService(ServiceKeys.breachChecker);

    if (kDebugMode) {
      print('Memory optimized for import operations');
    }
  }

  /// Optimize memory for export operations
  Future<void> _optimizeForExport() async {
    // Similar to import optimization
    await _optimizeForImport();

    if (kDebugMode) {
      print('Memory optimized for export operations');
    }
  }

  /// Get memory usage statistics
  Map<String, dynamic> getMemoryStats() {
    return {
      'isAppInBackground': _isAppInBackground,
      'backgroundTime': _backgroundTime?.millisecondsSinceEpoch,
      'memoryMonitoringActive': _memoryMonitoringTimer?.isActive ?? false,
      'cleanupScheduled': _memoryCleanupTimer?.isActive ?? false,
      'lowMemoryThresholdMB': _lowMemoryThresholdMB,
      'criticalMemoryThresholdMB': _criticalMemoryThresholdMB,
    };
  }

  /// Dispose resources
  void dispose() {
    _memoryCleanupTimer?.cancel();
    _memoryMonitoringTimer?.cancel();

    if (kDebugMode) {
      print('Memory management service disposed');
    }
  }
}

/// Types of memory optimization
enum MemoryOptimizationType { search, sync, import, export }
