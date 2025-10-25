import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service for detecting and managing time synchronization issues
class TimeSyncService {
  static const Duration _checkInterval = Duration(minutes: 5);
  static const Duration _networkTimeout = Duration(seconds: 10);

  static Timer? _periodicTimer;
  static final StreamController<TimeSyncStatus> _statusController =
      StreamController<TimeSyncStatus>.broadcast();

  static TimeSyncStatus _currentStatus = TimeSyncStatus.unknown;

  /// Get the current time sync status
  static TimeSyncStatus get currentStatus => _currentStatus;

  /// Stream of time sync status changes
  static Stream<TimeSyncStatus> get statusStream => _statusController.stream;

  /// Start monitoring time synchronization
  static void startMonitoring() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_checkInterval, (_) => checkTimeSync());

    // Initial check
    checkTimeSync();
  }

  /// Stop monitoring time synchronization
  static void stopMonitoring() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Check time synchronization status
  static Future<TimeSyncStatus> checkTimeSync() async {
    try {
      final status = await _performTimeSyncCheck();
      _updateStatus(status);
      return status;
    } catch (e) {
      _updateStatus(TimeSyncStatus.checkFailed);
      return TimeSyncStatus.checkFailed;
    }
  }

  /// Perform the actual time sync check
  static Future<TimeSyncStatus> _performTimeSyncCheck() async {
    // Basic checks first
    final basicStatus = _performBasicChecks();
    if (basicStatus != TimeSyncStatus.synchronized) {
      return basicStatus;
    }

    // Network-based check (if available)
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final networkStatus = await _checkNetworkTime();
        return networkStatus;
      } catch (e) {
        // Fall back to basic checks if network check fails
        return basicStatus;
      }
    }

    return basicStatus;
  }

  /// Perform basic time synchronization checks
  static TimeSyncStatus _performBasicChecks() {
    final now = DateTime.now();
    final utcNow = now.toUtc();

    // Check if the time zone offset is reasonable (within 24 hours)
    final offsetHours = now.timeZoneOffset.inHours.abs();
    if (offsetHours > 24) {
      return TimeSyncStatus.offsetTooLarge;
    }

    // Check if the current time seems reasonable (not too far in past/future)
    final currentYear = now.year;
    if (currentYear < 2020 || currentYear > 2050) {
      return TimeSyncStatus.timeUnrealistic;
    }

    // Check if UTC and local time relationship makes sense
    final expectedUtc = now.subtract(now.timeZoneOffset);
    final utcDifference = utcNow.difference(expectedUtc).inMinutes.abs();
    if (utcDifference > 2) {
      return TimeSyncStatus.utcMismatch;
    }

    return TimeSyncStatus.synchronized;
  }

  /// Check time against network time servers (simplified implementation)
  static Future<TimeSyncStatus> _checkNetworkTime() async {
    try {
      // This is a simplified check - in a production app, you might want to
      // use a proper NTP client or check against multiple time servers
      final socket = await Socket.connect(
        'time.google.com',
        80,
      ).timeout(_networkTimeout);

      socket.destroy();

      // If we can connect, assume time is reasonably synchronized
      // A more sophisticated implementation would actually query NTP
      return TimeSyncStatus.synchronized;
    } catch (e) {
      // Network unavailable or timeout
      return TimeSyncStatus.networkUnavailable;
    }
  }

  /// Update the current status and notify listeners
  static void _updateStatus(TimeSyncStatus newStatus) {
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _statusController.add(newStatus);
    }
  }

  /// Get a user-friendly warning message for the current status
  static String? getWarningMessage() {
    return getWarningMessageForStatus(_currentStatus);
  }

  /// Get a user-friendly warning message for a specific status
  static String? getWarningMessageForStatus(TimeSyncStatus status) {
    switch (status) {
      case TimeSyncStatus.synchronized:
      case TimeSyncStatus.unknown:
        return null;

      case TimeSyncStatus.offsetTooLarge:
        return 'Your device time zone appears to be incorrect. TOTP codes may not work properly.';

      case TimeSyncStatus.timeUnrealistic:
        return 'Your device time appears to be incorrect. Please check your date and time settings.';

      case TimeSyncStatus.utcMismatch:
        return 'There may be a time synchronization issue. TOTP codes might be inaccurate.';

      case TimeSyncStatus.networkUnavailable:
        return 'Cannot verify time synchronization due to network issues. TOTP codes may be inaccurate if your device time is wrong.';

      case TimeSyncStatus.checkFailed:
        return 'Unable to verify time synchronization. Please ensure your device time is correct.';
    }
  }

  /// Get detailed information about the time sync status
  static TimeSyncInfo getTimeSyncInfo() {
    final now = DateTime.now();
    final utcNow = now.toUtc();

    return TimeSyncInfo(
      status: _currentStatus,
      localTime: now,
      utcTime: utcNow,
      timeZoneOffset: now.timeZoneOffset,
      warningMessage: getWarningMessage(),
    );
  }

  /// Get recommendations for fixing time sync issues
  static List<String> getFixRecommendations(TimeSyncStatus status) {
    switch (status) {
      case TimeSyncStatus.synchronized:
      case TimeSyncStatus.unknown:
        return [];

      case TimeSyncStatus.offsetTooLarge:
        return [
          'Check your device time zone settings',
          'Ensure automatic time zone is enabled',
          'Restart your device if the issue persists',
        ];

      case TimeSyncStatus.timeUnrealistic:
        return [
          'Check your device date and time settings',
          'Enable automatic date and time',
          'Ensure your device has internet connectivity',
          'Restart your device',
        ];

      case TimeSyncStatus.utcMismatch:
      case TimeSyncStatus.networkUnavailable:
      case TimeSyncStatus.checkFailed:
        return [
          'Enable automatic date and time in settings',
          'Check your internet connection',
          'Try connecting to a different network',
          'Restart your device',
          'Contact your network administrator if on a corporate network',
        ];
    }
  }

  /// Check if TOTP codes are likely to be accurate
  static bool areTOTPCodesLikelyAccurate() {
    return _currentStatus == TimeSyncStatus.synchronized ||
        _currentStatus == TimeSyncStatus.unknown;
  }

  /// Dispose of resources
  static void dispose() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _statusController.close();
  }
}

/// Time synchronization status
enum TimeSyncStatus {
  /// Time appears to be synchronized
  synchronized,

  /// Time sync status is unknown
  unknown,

  /// Time zone offset is too large (>24 hours)
  offsetTooLarge,

  /// Device time appears unrealistic
  timeUnrealistic,

  /// UTC and local time don't match expected relationship
  utcMismatch,

  /// Network is unavailable for time check
  networkUnavailable,

  /// Time sync check failed
  checkFailed,
}

/// Detailed time synchronization information
class TimeSyncInfo {
  final TimeSyncStatus status;
  final DateTime localTime;
  final DateTime utcTime;
  final Duration timeZoneOffset;
  final String? warningMessage;

  const TimeSyncInfo({
    required this.status,
    required this.localTime,
    required this.utcTime,
    required this.timeZoneOffset,
    this.warningMessage,
  });

  /// Whether time sync is considered good
  bool get isGood => status == TimeSyncStatus.synchronized;

  /// Whether there's a warning to show
  bool get hasWarning => warningMessage != null;

  @override
  String toString() {
    return 'TimeSyncInfo(status: $status, localTime: $localTime, utcTime: $utcTime, offset: $timeZoneOffset)';
  }
}
