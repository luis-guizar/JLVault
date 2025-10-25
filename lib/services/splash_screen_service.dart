import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app_initialization_service.dart';
import 'vault_manager.dart';
import '../data/vault_db_helper.dart';

/// Service for managing splash screen and preloading essential data
class SplashScreenService {
  static SplashScreenService? _instance;
  static SplashScreenService get instance =>
      _instance ??= SplashScreenService._();

  SplashScreenService._();

  bool _isPreloadComplete = false;
  String? _activeVaultId;
  int _totalVaultCount = 0;

  /// Preload essential data during splash screen
  /// This runs in parallel with UI initialization
  Future<void> preloadEssentialData() async {
    if (_isPreloadComplete) return;

    final stopwatch = Stopwatch()..start();

    try {
      // Run preload tasks in parallel for better performance
      await Future.wait([
        _preloadVaultMetadata(),
        _preloadUserPreferences(),
        _preloadSecuritySettings(),
      ]);

      _isPreloadComplete = true;

      if (kDebugMode) {
        print('Essential data preloaded in ${stopwatch.elapsedMilliseconds}ms');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error preloading essential data: $e');
      }
      // Don't rethrow - app should still work without preloaded data
    } finally {
      stopwatch.stop();
    }
  }

  /// Preload vault metadata for faster vault switching
  Future<void> _preloadVaultMetadata() async {
    try {
      // Get active vault ID
      _activeVaultId = await VaultDbHelper.getActiveVaultId();

      // Get total vault count for UI decisions
      _totalVaultCount = await VaultDbHelper.getVaultCount();

      if (kDebugMode) {
        print(
          'Vault metadata preloaded: active=$_activeVaultId, count=$_totalVaultCount',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error preloading vault metadata: $e');
      }
    }
  }

  /// Preload user preferences
  Future<void> _preloadUserPreferences() async {
    try {
      // Preload theme preferences (already handled by ThemeService)
      // Preload other user preferences here

      if (kDebugMode) {
        print('User preferences preloaded');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error preloading user preferences: $e');
      }
    }
  }

  /// Preload security settings
  Future<void> _preloadSecuritySettings() async {
    try {
      // Preload security-related settings
      // This could include biometric availability, security policies, etc.

      if (kDebugMode) {
        print('Security settings preloaded');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error preloading security settings: $e');
      }
    }
  }

  /// Get the minimum splash screen duration
  /// This ensures splash screen is visible long enough for smooth transition
  Duration get minimumSplashDuration => const Duration(milliseconds: 800);

  /// Get the maximum splash screen duration
  /// After this time, app should proceed even if preloading isn't complete
  Duration get maximumSplashDuration => const Duration(milliseconds: 2000);

  /// Check if preloading is complete
  bool get isPreloadComplete => _isPreloadComplete;

  /// Get preloaded active vault ID
  String? get activeVaultId => _activeVaultId;

  /// Get preloaded vault count
  int get totalVaultCount => _totalVaultCount;

  /// Wait for preload with timeout
  Future<void> waitForPreload({Duration? timeout}) async {
    timeout ??= maximumSplashDuration;

    try {
      await Future.any([Future.delayed(timeout), _waitForPreloadCompletion()]);
    } catch (e) {
      if (kDebugMode) {
        print('Preload wait interrupted: $e');
      }
    }
  }

  /// Wait for preload completion
  Future<void> _waitForPreloadCompletion() async {
    while (!_isPreloadComplete) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Reset preload state (useful for testing)
  void reset() {
    _isPreloadComplete = false;
    _activeVaultId = null;
    _totalVaultCount = 0;
  }
}
