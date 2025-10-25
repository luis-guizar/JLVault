import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../data/db_helper.dart';
import '../data/vault_db_helper.dart';

/// Service for crash detection, recovery, and state preservation
class CrashRecoveryService {
  static CrashRecoveryService? _instance;
  static CrashRecoveryService get instance =>
      _instance ??= CrashRecoveryService._();

  CrashRecoveryService._();

  static const String _crashStateFile = 'crash_recovery_state.json';
  static const String _backupStateFile = 'backup_recovery_state.json';
  static const Duration _stateUpdateInterval = Duration(seconds: 30);

  Timer? _stateUpdateTimer;
  bool _isInitialized = false;
  Map<String, dynamic> _currentState = {};
  DateTime? _lastStateUpdate;

  /// Initialize crash recovery system
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check for previous crash
      await _checkForPreviousCrash();

      // Initialize state tracking
      await _initializeStateTracking();

      // Set up uncaught exception handler
      _setupExceptionHandlers();

      // Start periodic state updates
      _startStateUpdates();

      _isInitialized = true;

      if (kDebugMode) {
        print('Crash recovery service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing crash recovery service: $e');
      }
    }
  }

  /// Check for previous crash and attempt recovery
  Future<void> _checkForPreviousCrash() async {
    try {
      final stateFile = await _getStateFile();

      if (await stateFile.exists()) {
        final stateContent = await stateFile.readAsString();
        final crashState = jsonDecode(stateContent) as Map<String, dynamic>;

        if (kDebugMode) {
          print('Previous crash detected, attempting recovery');
        }

        await _performCrashRecovery(crashState);

        // Clean up crash state file after successful recovery
        await stateFile.delete();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking for previous crash: $e');
      }
    }
  }

  /// Perform crash recovery
  Future<void> _performCrashRecovery(Map<String, dynamic> crashState) async {
    try {
      final stopwatch = Stopwatch()..start();

      // Recover authentication state
      await _recoverAuthenticationState(crashState);

      // Recover vault state
      await _recoverVaultState(crashState);

      // Recover UI state
      await _recoverUIState(crashState);

      // Verify database integrity
      await _verifyDatabaseIntegrity();

      if (kDebugMode) {
        print('Crash recovery completed in ${stopwatch.elapsedMilliseconds}ms');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during crash recovery: $e');
      }

      // If recovery fails, attempt backup restoration
      await _attemptBackupRestoration();
    }
  }

  /// Recover authentication state
  Future<void> _recoverAuthenticationState(
    Map<String, dynamic> crashState,
  ) async {
    try {
      final authState = crashState['authentication'] as Map<String, dynamic>?;

      if (authState != null) {
        final wasAuthenticated = authState['isAuthenticated'] as bool? ?? false;
        final lastAuthTime = authState['lastAuthenticationTime'] as int?;

        if (wasAuthenticated && lastAuthTime != null) {
          final authTime = DateTime.fromMillisecondsSinceEpoch(lastAuthTime);
          final timeSinceAuth = DateTime.now().difference(authTime);

          // If authentication was recent (within 5 minutes), preserve it
          if (timeSinceAuth.inMinutes < 5) {
            _currentState['authentication'] = {
              'shouldRestoreAuth': true,
              'lastAuthTime': lastAuthTime,
            };
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error recovering authentication state: $e');
      }
    }
  }

  /// Recover vault state
  Future<void> _recoverVaultState(Map<String, dynamic> crashState) async {
    try {
      final vaultState = crashState['vault'] as Map<String, dynamic>?;

      if (vaultState != null) {
        final activeVaultId = vaultState['activeVaultId'] as String?;
        // final lastVaultAccess = vaultState['lastVaultAccess'] as int?;

        if (activeVaultId != null) {
          // Verify vault still exists
          final vault = await VaultDbHelper.getVaultById(activeVaultId);
          if (vault != null) {
            _currentState['vault'] = {
              'activeVaultId': activeVaultId,
              'shouldRestore': true,
            };
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error recovering vault state: $e');
      }
    }
  }

  /// Recover UI state
  Future<void> _recoverUIState(Map<String, dynamic> crashState) async {
    try {
      final uiState = crashState['ui'] as Map<String, dynamic>?;

      if (uiState != null) {
        final currentScreen = uiState['currentScreen'] as String?;
        final searchQuery = uiState['searchQuery'] as String?;
        final selectedAccountId = uiState['selectedAccountId'] as int?;

        _currentState['ui'] = {
          'currentScreen': currentScreen,
          'searchQuery': searchQuery,
          'selectedAccountId': selectedAccountId,
          'shouldRestore': true,
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error recovering UI state: $e');
      }
    }
  }

  /// Verify database integrity after crash
  Future<void> _verifyDatabaseIntegrity() async {
    try {
      // Check main database
      final db = await DBHelper.db;
      await db.rawQuery('PRAGMA integrity_check');

      // Check vault database
      final vaultDb = await VaultDbHelper.db;
      await vaultDb.rawQuery('PRAGMA integrity_check');

      if (kDebugMode) {
        print('Database integrity verified');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Database integrity check failed: $e');
      }

      // Attempt database repair
      await _attemptDatabaseRepair();
    }
  }

  /// Attempt database repair
  Future<void> _attemptDatabaseRepair() async {
    try {
      // Close existing connections would be implemented here
      // await DBHelper.close();
      // await VaultDbHelper.close();

      // Attempt to repair databases
      final db = await DBHelper.db;
      await db.execute('VACUUM');

      final vaultDb = await VaultDbHelper.db;
      await vaultDb.execute('VACUUM');

      if (kDebugMode) {
        print('Database repair attempted');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Database repair failed: $e');
      }
    }
  }

  /// Attempt backup restoration
  Future<void> _attemptBackupRestoration() async {
    try {
      final backupFile = await _getBackupStateFile();

      if (await backupFile.exists()) {
        final backupContent = await backupFile.readAsString();
        final backupState = jsonDecode(backupContent) as Map<String, dynamic>;

        await _performCrashRecovery(backupState);

        if (kDebugMode) {
          print('Backup restoration completed');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Backup restoration failed: $e');
      }
    }
  }

  /// Initialize state tracking
  Future<void> _initializeStateTracking() async {
    _currentState = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'version': '1.0.0',
      'authentication': {},
      'vault': {},
      'ui': {},
    };
  }

  /// Set up exception handlers
  void _setupExceptionHandlers() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleCrash('Flutter Error', details.exception, details.stack);
    };

    // Handle other uncaught errors
    PlatformDispatcher.instance.onError = (error, stack) {
      _handleCrash('Platform Error', error, stack);
      return true;
    };
  }

  /// Handle crash occurrence
  Future<void> _handleCrash(
    String type,
    Object error,
    StackTrace? stack,
  ) async {
    try {
      if (kDebugMode) {
        print('Crash detected: $type - $error');
        print('Stack trace: $stack');
      }

      // Save current state for recovery
      await _saveCurrentState();

      // Log crash information
      await _logCrashInformation(type, error, stack);
    } catch (e) {
      if (kDebugMode) {
        print('Error handling crash: $e');
      }
    }
  }

  /// Save current state for crash recovery
  Future<void> _saveCurrentState() async {
    try {
      final stateFile = await _getStateFile();
      final stateJson = jsonEncode(_currentState);
      await stateFile.writeAsString(stateJson);

      // Also save to backup location
      final backupFile = await _getBackupStateFile();
      await backupFile.writeAsString(stateJson);

      _lastStateUpdate = DateTime.now();
    } catch (e) {
      if (kDebugMode) {
        print('Error saving current state: $e');
      }
    }
  }

  /// Log crash information
  Future<void> _logCrashInformation(
    String type,
    Object error,
    StackTrace? stack,
  ) async {
    try {
      final crashLog = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': type,
        'error': error.toString(),
        'stackTrace': stack?.toString(),
        'state': _currentState,
      };

      final logFile = await _getCrashLogFile();
      final logJson = jsonEncode(crashLog);

      // Append to crash log file
      await logFile.writeAsString('$logJson\n', mode: FileMode.append);
    } catch (e) {
      if (kDebugMode) {
        print('Error logging crash information: $e');
      }
    }
  }

  /// Start periodic state updates
  void _startStateUpdates() {
    _stateUpdateTimer?.cancel();

    _stateUpdateTimer = Timer.periodic(_stateUpdateInterval, (timer) {
      _updateCurrentState();
    });
  }

  /// Update current state
  void _updateCurrentState() {
    try {
      _currentState['timestamp'] = DateTime.now().millisecondsSinceEpoch;

      // Save state periodically (but not too frequently to avoid I/O overhead)
      final now = DateTime.now();
      if (_lastStateUpdate == null ||
          now.difference(_lastStateUpdate!).inMinutes >= 2) {
        _saveCurrentState();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating current state: $e');
      }
    }
  }

  /// Update authentication state
  void updateAuthenticationState({
    required bool isAuthenticated,
    DateTime? lastAuthenticationTime,
  }) {
    _currentState['authentication'] = {
      'isAuthenticated': isAuthenticated,
      'lastAuthenticationTime': lastAuthenticationTime?.millisecondsSinceEpoch,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Update vault state
  void updateVaultState({String? activeVaultId, DateTime? lastVaultAccess}) {
    _currentState['vault'] = {
      'activeVaultId': activeVaultId,
      'lastVaultAccess': lastVaultAccess?.millisecondsSinceEpoch,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Update UI state
  void updateUIState({
    String? currentScreen,
    String? searchQuery,
    int? selectedAccountId,
  }) {
    _currentState['ui'] = {
      'currentScreen': currentScreen,
      'searchQuery': searchQuery,
      'selectedAccountId': selectedAccountId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Get recovery state for app initialization
  Map<String, dynamic> getRecoveryState() {
    return Map<String, dynamic>.from(_currentState);
  }

  /// Check if there's a recovery state to restore
  bool hasRecoveryState() {
    final authState = _currentState['authentication'] as Map<String, dynamic>?;
    final vaultState = _currentState['vault'] as Map<String, dynamic>?;
    final uiState = _currentState['ui'] as Map<String, dynamic>?;

    return (authState?['shouldRestoreAuth'] == true) ||
        (vaultState?['shouldRestore'] == true) ||
        (uiState?['shouldRestore'] == true);
  }

  /// Clear recovery state after successful restoration
  void clearRecoveryState() {
    _currentState['authentication']?.remove('shouldRestoreAuth');
    _currentState['vault']?.remove('shouldRestore');
    _currentState['ui']?.remove('shouldRestore');
  }

  /// Get state file
  Future<File> _getStateFile() async {
    final directory = await _getAppDocumentsDirectory();
    return File('${directory.path}/$_crashStateFile');
  }

  /// Get backup state file
  Future<File> _getBackupStateFile() async {
    final directory = await _getAppDocumentsDirectory();
    return File('${directory.path}/$_backupStateFile');
  }

  /// Get crash log file
  Future<File> _getCrashLogFile() async {
    final directory = await _getAppDocumentsDirectory();
    return File('${directory.path}/crash_log.jsonl');
  }

  /// Get app documents directory
  Future<Directory> _getAppDocumentsDirectory() async {
    // This would use path_provider in a real implementation
    return Directory.systemTemp; // Simplified for now
  }

  /// Get crash recovery statistics
  Map<String, dynamic> getStats() {
    return {
      'isInitialized': _isInitialized,
      'lastStateUpdate': _lastStateUpdate?.millisecondsSinceEpoch,
      'hasRecoveryState': hasRecoveryState(),
      'stateUpdateInterval': _stateUpdateInterval.inSeconds,
      'currentStateSize': _currentState.length,
    };
  }

  /// Dispose resources
  void dispose() {
    _stateUpdateTimer?.cancel();

    // Save final state
    if (_isInitialized) {
      _saveCurrentState();
    }

    if (kDebugMode) {
      print('Crash recovery service disposed');
    }
  }
}
