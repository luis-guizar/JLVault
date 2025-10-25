import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'crash_recovery_service.dart';

/// Service for preserving and restoring app state across sessions
class StatePreservationService {
  static StatePreservationService? _instance;
  static StatePreservationService get instance =>
      _instance ??= StatePreservationService._();

  StatePreservationService._();

  static const String _stateFile = 'app_state.json';
  static const Duration _autoSaveInterval = Duration(minutes: 1);

  Timer? _autoSaveTimer;
  Map<String, dynamic> _appState = {};
  bool _isInitialized = false;
  bool _hasUnsavedChanges = false;

  /// Initialize state preservation
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadPersistedState();
      _startAutoSave();
      _isInitialized = true;

      if (kDebugMode) {
        print('State preservation service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing state preservation: $e');
      }
    }
  }

  /// Load persisted state from storage
  Future<void> _loadPersistedState() async {
    try {
      final stateFile = await _getStateFile();

      if (await stateFile.exists()) {
        final stateContent = await stateFile.readAsString();
        _appState = jsonDecode(stateContent) as Map<String, dynamic>;

        if (kDebugMode) {
          print('Loaded persisted state with ${_appState.length} entries');
        }
      } else {
        _appState = _createDefaultState();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading persisted state: $e');
      }
      _appState = _createDefaultState();
    }
  }

  /// Create default app state
  Map<String, dynamic> _createDefaultState() {
    return {
      'version': '1.0.0',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'authentication': {
        'isAuthenticated': false,
        'lastAuthenticationTime': null,
        'biometricEnabled': false,
      },
      'vault': {
        'activeVaultId': null,
        'lastAccessedVaults': <String>[],
        'vaultSwitchHistory': <Map<String, dynamic>>[],
      },
      'ui': {
        'currentScreen': 'lock',
        'lastSearchQuery': '',
        'selectedAccountId': null,
        'sortPreference': 'name',
        'viewMode': 'list',
        'themeMode': 'system',
      },
      'preferences': {
        'autoLockTimeout': 300, // 5 minutes
        'showPasswordStrength': true,
        'enableHapticFeedback': true,
        'enableAnimations': true,
      },
      'security': {
        'lastSecurityCheck': null,
        'breachCheckEnabled': true,
        'passwordExpiryWarnings': true,
      },
      'sync': {
        'lastSyncTime': null,
        'syncEnabled': false,
        'pairedDevices': <String>[],
      },
    };
  }

  /// Start auto-save timer
  void _startAutoSave() {
    _autoSaveTimer?.cancel();

    _autoSaveTimer = Timer.periodic(_autoSaveInterval, (timer) {
      if (_hasUnsavedChanges) {
        _saveState();
      }
    });
  }

  /// Save current state to storage
  Future<void> _saveState() async {
    try {
      _appState['timestamp'] = DateTime.now().millisecondsSinceEpoch;

      final stateFile = await _getStateFile();
      final stateJson = jsonEncode(_appState);
      await stateFile.writeAsString(stateJson);

      _hasUnsavedChanges = false;

      // Also update crash recovery service
      _updateCrashRecoveryState();
    } catch (e) {
      if (kDebugMode) {
        print('Error saving state: $e');
      }
    }
  }

  /// Update crash recovery service with current state
  void _updateCrashRecoveryState() {
    final authState = _appState['authentication'] as Map<String, dynamic>?;
    final vaultState = _appState['vault'] as Map<String, dynamic>?;
    final uiState = _appState['ui'] as Map<String, dynamic>?;

    if (authState != null) {
      CrashRecoveryService.instance.updateAuthenticationState(
        isAuthenticated: authState['isAuthenticated'] ?? false,
        lastAuthenticationTime: authState['lastAuthenticationTime'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                authState['lastAuthenticationTime'],
              )
            : null,
      );
    }

    if (vaultState != null) {
      CrashRecoveryService.instance.updateVaultState(
        activeVaultId: vaultState['activeVaultId'],
        lastVaultAccess: DateTime.now(),
      );
    }

    if (uiState != null) {
      CrashRecoveryService.instance.updateUIState(
        currentScreen: uiState['currentScreen'],
        searchQuery: uiState['lastSearchQuery'],
        selectedAccountId: uiState['selectedAccountId'],
      );
    }
  }

  /// Update authentication state
  void updateAuthenticationState({
    bool? isAuthenticated,
    DateTime? lastAuthenticationTime,
    bool? biometricEnabled,
  }) {
    final authState = _appState['authentication'] as Map<String, dynamic>;

    if (isAuthenticated != null) {
      authState['isAuthenticated'] = isAuthenticated;
    }
    if (lastAuthenticationTime != null) {
      authState['lastAuthenticationTime'] =
          lastAuthenticationTime.millisecondsSinceEpoch;
    }
    if (biometricEnabled != null) {
      authState['biometricEnabled'] = biometricEnabled;
    }

    _hasUnsavedChanges = true;
  }

  /// Update vault state
  void updateVaultState({
    String? activeVaultId,
    List<String>? lastAccessedVaults,
  }) {
    final vaultState = _appState['vault'] as Map<String, dynamic>;

    if (activeVaultId != null) {
      vaultState['activeVaultId'] = activeVaultId;

      // Update vault access history
      final history = List<String>.from(vaultState['lastAccessedVaults'] ?? []);
      history.remove(activeVaultId); // Remove if already exists
      history.insert(0, activeVaultId); // Add to front

      // Keep only last 10 accessed vaults
      if (history.length > 10) {
        history.removeRange(10, history.length);
      }

      vaultState['lastAccessedVaults'] = history;

      // Add to switch history
      final switchHistory = List<Map<String, dynamic>>.from(
        vaultState['vaultSwitchHistory'] ?? [],
      );
      switchHistory.insert(0, {
        'vaultId': activeVaultId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Keep only last 50 switches
      if (switchHistory.length > 50) {
        switchHistory.removeRange(50, switchHistory.length);
      }

      vaultState['vaultSwitchHistory'] = switchHistory;
    }

    if (lastAccessedVaults != null) {
      vaultState['lastAccessedVaults'] = lastAccessedVaults;
    }

    _hasUnsavedChanges = true;
  }

  /// Update UI state
  void updateUIState({
    String? currentScreen,
    String? lastSearchQuery,
    int? selectedAccountId,
    String? sortPreference,
    String? viewMode,
    String? themeMode,
  }) {
    final uiState = _appState['ui'] as Map<String, dynamic>;

    if (currentScreen != null) {
      uiState['currentScreen'] = currentScreen;
    }
    if (lastSearchQuery != null) {
      uiState['lastSearchQuery'] = lastSearchQuery;
    }
    if (selectedAccountId != null) {
      uiState['selectedAccountId'] = selectedAccountId;
    }
    if (sortPreference != null) {
      uiState['sortPreference'] = sortPreference;
    }
    if (viewMode != null) {
      uiState['viewMode'] = viewMode;
    }
    if (themeMode != null) {
      uiState['themeMode'] = themeMode;
    }

    _hasUnsavedChanges = true;
  }

  /// Update user preferences
  void updatePreferences({
    int? autoLockTimeout,
    bool? showPasswordStrength,
    bool? enableHapticFeedback,
    bool? enableAnimations,
  }) {
    final preferences = _appState['preferences'] as Map<String, dynamic>;

    if (autoLockTimeout != null) {
      preferences['autoLockTimeout'] = autoLockTimeout;
    }
    if (showPasswordStrength != null) {
      preferences['showPasswordStrength'] = showPasswordStrength;
    }
    if (enableHapticFeedback != null) {
      preferences['enableHapticFeedback'] = enableHapticFeedback;
    }
    if (enableAnimations != null) {
      preferences['enableAnimations'] = enableAnimations;
    }

    _hasUnsavedChanges = true;
  }

  /// Update security state
  void updateSecurityState({
    DateTime? lastSecurityCheck,
    bool? breachCheckEnabled,
    bool? passwordExpiryWarnings,
  }) {
    final securityState = _appState['security'] as Map<String, dynamic>;

    if (lastSecurityCheck != null) {
      securityState['lastSecurityCheck'] =
          lastSecurityCheck.millisecondsSinceEpoch;
    }
    if (breachCheckEnabled != null) {
      securityState['breachCheckEnabled'] = breachCheckEnabled;
    }
    if (passwordExpiryWarnings != null) {
      securityState['passwordExpiryWarnings'] = passwordExpiryWarnings;
    }

    _hasUnsavedChanges = true;
  }

  /// Update sync state
  void updateSyncState({
    DateTime? lastSyncTime,
    bool? syncEnabled,
    List<String>? pairedDevices,
  }) {
    final syncState = _appState['sync'] as Map<String, dynamic>;

    if (lastSyncTime != null) {
      syncState['lastSyncTime'] = lastSyncTime.millisecondsSinceEpoch;
    }
    if (syncEnabled != null) {
      syncState['syncEnabled'] = syncEnabled;
    }
    if (pairedDevices != null) {
      syncState['pairedDevices'] = pairedDevices;
    }

    _hasUnsavedChanges = true;
  }

  /// Get authentication state
  Map<String, dynamic> getAuthenticationState() {
    return Map<String, dynamic>.from(_appState['authentication'] ?? {});
  }

  /// Get vault state
  Map<String, dynamic> getVaultState() {
    return Map<String, dynamic>.from(_appState['vault'] ?? {});
  }

  /// Get UI state
  Map<String, dynamic> getUIState() {
    return Map<String, dynamic>.from(_appState['ui'] ?? {});
  }

  /// Get user preferences
  Map<String, dynamic> getPreferences() {
    return Map<String, dynamic>.from(_appState['preferences'] ?? {});
  }

  /// Get security state
  Map<String, dynamic> getSecurityState() {
    return Map<String, dynamic>.from(_appState['security'] ?? {});
  }

  /// Get sync state
  Map<String, dynamic> getSyncState() {
    return Map<String, dynamic>.from(_appState['sync'] ?? {});
  }

  /// Get complete app state
  Map<String, dynamic> getCompleteState() {
    return Map<String, dynamic>.from(_appState);
  }

  /// Force save current state
  Future<void> forceSave() async {
    _hasUnsavedChanges = true;
    await _saveState();
  }

  /// Clear all state (useful for logout or reset)
  Future<void> clearState() async {
    _appState = _createDefaultState();
    _hasUnsavedChanges = true;
    await _saveState();

    if (kDebugMode) {
      print('App state cleared');
    }
  }

  /// Get state file
  Future<File> _getStateFile() async {
    final directory = await _getAppDocumentsDirectory();
    return File('${directory.path}/$_stateFile');
  }

  /// Get app documents directory
  Future<Directory> _getAppDocumentsDirectory() async {
    // This would use path_provider in a real implementation
    return Directory.systemTemp; // Simplified for now
  }

  /// Get state preservation statistics
  Map<String, dynamic> getStats() {
    return {
      'isInitialized': _isInitialized,
      'hasUnsavedChanges': _hasUnsavedChanges,
      'stateSize': _appState.length,
      'lastTimestamp': _appState['timestamp'],
      'autoSaveInterval': _autoSaveInterval.inSeconds,
      'autoSaveActive': _autoSaveTimer?.isActive ?? false,
    };
  }

  /// Dispose resources
  void dispose() {
    _autoSaveTimer?.cancel();

    // Force save before disposing
    if (_hasUnsavedChanges && _isInitialized) {
      _saveState();
    }

    if (kDebugMode) {
      print('State preservation service disposed');
    }
  }
}
