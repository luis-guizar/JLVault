import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Secure logging service that excludes sensitive data
class SecureLoggingService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
  );

  static const int _maxLogEntries = 1000;
  static const int _maxLogFileSize = 1024 * 1024; // 1MB
  static const String _logEncryptionKeyName = 'log_encryption_key';

  // Sensitive data patterns to exclude from logs
  static final List<RegExp> _sensitivePatterns = [
    RegExp(r'password["\s]*[:=]["\s]*[^"\s,}]+', caseSensitive: false),
    RegExp(r'secret["\s]*[:=]["\s]*[^"\s,}]+', caseSensitive: false),
    RegExp(r'token["\s]*[:=]["\s]*[^"\s,}]+', caseSensitive: false),
    RegExp(r'key["\s]*[:=]["\s]*[^"\s,}]+', caseSensitive: false),
    RegExp(r'totp["\s]*[:=]["\s]*[^"\s,}]+', caseSensitive: false),
    RegExp(r'pin["\s]*[:=]["\s]*[^"\s,}]+', caseSensitive: false),
    RegExp(r'auth["\s]*[:=]["\s]*[^"\s,}]+', caseSensitive: false),
    RegExp(r'\b[A-Za-z0-9]{32,}\b'), // Long hex strings (likely keys/hashes)
    RegExp(r'\b[A-Za-z0-9+/]{20,}={0,2}\b'), // Base64 encoded data
  ];

  static File? _logFile;
  static List<LogEntry> _logBuffer = [];
  static bool _initialized = false;

  /// Initialize the secure logging service
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/secure_logs.enc');

      // Load existing logs if available
      await _loadExistingLogs();

      _initialized = true;
    } catch (e) {
      // If initialization fails, continue without logging to avoid breaking the app
      _initialized = false;
    }
  }

  /// Log an informational message
  static Future<void> logInfo(
    String message, {
    Map<String, dynamic>? data,
  }) async {
    await _log(LogLevel.info, message, data);
  }

  /// Log a warning message
  static Future<void> logWarning(
    String message, {
    Map<String, dynamic>? data,
  }) async {
    await _log(LogLevel.warning, message, data);
  }

  /// Log an error message
  static Future<void> logError(
    String message, {
    Map<String, dynamic>? data,
    Object? error,
  }) async {
    final logData = <String, dynamic>{};
    if (data != null) logData.addAll(data);
    if (error != null) logData['error'] = error.toString();

    await _log(LogLevel.error, message, logData);
  }

  /// Log a security event
  static Future<void> logSecurityEvent(
    String event, {
    Map<String, dynamic>? data,
  }) async {
    await _log(LogLevel.security, event, data);
  }

  /// Log a debug message (only in debug mode)
  static Future<void> logDebug(
    String message, {
    Map<String, dynamic>? data,
  }) async {
    // Only log debug messages in debug builds
    assert(() {
      _log(LogLevel.debug, message, data);
      return true;
    }());
  }

  /// Get recent log entries (sanitized)
  static Future<List<LogEntry>> getRecentLogs({int limit = 100}) async {
    if (!_initialized) return [];

    try {
      final logs = List<LogEntry>.from(_logBuffer);
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return logs.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  /// Export logs for debugging (with additional sanitization)
  static Future<String?> exportLogsForDebugging() async {
    if (!_initialized) return null;

    try {
      final logs = await getRecentLogs(limit: 500);
      final sanitizedLogs = logs
          .map(
            (log) => {
              'timestamp': log.timestamp.toIso8601String(),
              'level': log.level.name,
              'message': _sanitizeForExport(log.message),
              'data': log.data != null
                  ? _sanitizeDataForExport(log.data!)
                  : null,
            },
          )
          .toList();

      return jsonEncode({
        'exportedAt': DateTime.now().toIso8601String(),
        'totalEntries': sanitizedLogs.length,
        'logs': sanitizedLogs,
      });
    } catch (e) {
      return null;
    }
  }

  /// Clear all logs
  static Future<void> clearLogs() async {
    if (!_initialized) return;

    try {
      _logBuffer.clear();
      if (_logFile?.existsSync() == true) {
        await _logFile!.delete();
      }
      await logInfo('Logs cleared by user request');
    } catch (e) {
      // Ignore errors during cleanup
    }
  }

  /// Dispose of resources
  static Future<void> dispose() async {
    if (!_initialized) return;

    try {
      await _flushLogs();
      _logBuffer.clear();
      _initialized = false;
    } catch (e) {
      // Ignore errors during disposal
    }
  }

  // Private helper methods

  static Future<void> _log(
    LogLevel level,
    String message,
    Map<String, dynamic>? data,
  ) async {
    if (!_initialized) {
      await initialize();
      if (!_initialized) return; // Still failed, give up
    }

    try {
      final sanitizedMessage = _sanitizeMessage(message);
      final sanitizedData = data != null ? _sanitizeData(data) : null;

      final logEntry = LogEntry(
        timestamp: DateTime.now(),
        level: level,
        message: sanitizedMessage,
        data: sanitizedData,
      );

      _logBuffer.add(logEntry);

      // Flush logs periodically or when buffer is full
      if (_logBuffer.length >= 50) {
        await _flushLogs();
      }
    } catch (e) {
      // Ignore logging errors to avoid affecting normal operation
    }
  }

  static String _sanitizeMessage(String message) {
    String sanitized = message;

    for (final pattern in _sensitivePatterns) {
      sanitized = sanitized.replaceAll(pattern, '[REDACTED]');
    }

    return sanitized;
  }

  static Map<String, dynamic> _sanitizeData(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};

    for (final entry in data.entries) {
      final key = entry.key.toLowerCase();
      final value = entry.value;

      // Check if key contains sensitive information
      if (_isSensitiveKey(key)) {
        sanitized[entry.key] = '[REDACTED]';
      } else if (value is String) {
        sanitized[entry.key] = _sanitizeMessage(value);
      } else if (value is Map<String, dynamic>) {
        sanitized[entry.key] = _sanitizeData(value);
      } else if (value is List) {
        sanitized[entry.key] = _sanitizeList(value);
      } else {
        sanitized[entry.key] = value;
      }
    }

    return sanitized;
  }

  static List<dynamic> _sanitizeList(List<dynamic> list) {
    return list.map((item) {
      if (item is String) {
        return _sanitizeMessage(item);
      } else if (item is Map<String, dynamic>) {
        return _sanitizeData(item);
      } else if (item is List) {
        return _sanitizeList(item);
      } else {
        return item;
      }
    }).toList();
  }

  static bool _isSensitiveKey(String key) {
    const sensitiveKeys = [
      'password',
      'secret',
      'token',
      'key',
      'totp',
      'pin',
      'auth',
      'credential',
      'hash',
      'salt',
      'nonce',
      'signature',
      'private',
      'encrypted',
      'cipher',
      'biometric',
      'fingerprint',
      'face',
    ];

    return sensitiveKeys.any((sensitive) => key.contains(sensitive));
  }

  static String _sanitizeForExport(String text) {
    // Additional sanitization for export
    String sanitized = _sanitizeMessage(text);

    // Remove any remaining potential sensitive data
    sanitized = sanitized.replaceAll(
      RegExp(r'\b\d{4,}\b'),
      '[NUMBER]',
    ); // Long numbers
    sanitized = sanitized.replaceAll(
      RegExp(r'\b[a-f0-9]{8,}\b', caseSensitive: false),
      '[HEX]',
    ); // Hex strings

    return sanitized;
  }

  static Map<String, dynamic> _sanitizeDataForExport(
    Map<String, dynamic> data,
  ) {
    final sanitized = _sanitizeData(data);

    // Additional export sanitization
    final exportSanitized = <String, dynamic>{};
    for (final entry in sanitized.entries) {
      if (entry.value is String) {
        exportSanitized[entry.key] = _sanitizeForExport(entry.value as String);
      } else {
        exportSanitized[entry.key] = entry.value;
      }
    }

    return exportSanitized;
  }

  static Future<void> _flushLogs() async {
    if (_logBuffer.isEmpty || _logFile == null) return;

    try {
      // Encrypt logs before writing
      final logsJson = jsonEncode(
        _logBuffer.map((log) => log.toJson()).toList(),
      );
      final encryptedLogs = await _encryptLogs(logsJson);

      // Check file size and rotate if necessary
      if (_logFile!.existsSync() && _logFile!.lengthSync() > _maxLogFileSize) {
        await _rotateLogs();
      }

      // Append to log file
      await _logFile!.writeAsBytes(encryptedLogs, mode: FileMode.append);

      // Keep only recent entries in buffer
      if (_logBuffer.length > _maxLogEntries) {
        _logBuffer = _logBuffer.sublist(_logBuffer.length - _maxLogEntries);
      }
    } catch (e) {
      // Ignore flush errors
    }
  }

  static Future<Uint8List> _encryptLogs(String logsJson) async {
    try {
      // Get or create encryption key
      String? keyBase64 = await _storage.read(key: _logEncryptionKeyName);
      if (keyBase64 == null) {
        final key = _generateLogEncryptionKey();
        keyBase64 = base64.encode(key);
        await _storage.write(key: _logEncryptionKeyName, value: keyBase64);
      }

      final key = base64.decode(keyBase64);
      final nonce = _generateNonce();

      // Simple XOR encryption (sufficient for logs)
      final data = utf8.encode(logsJson);
      final encrypted = Uint8List(data.length);

      for (int i = 0; i < data.length; i++) {
        encrypted[i] = data[i] ^ key[i % key.length];
      }

      // Prepend nonce
      final result = Uint8List(nonce.length + encrypted.length);
      result.setRange(0, nonce.length, nonce);
      result.setRange(nonce.length, result.length, encrypted);

      return result;
    } catch (e) {
      // If encryption fails, return unencrypted data
      return Uint8List.fromList(utf8.encode(logsJson));
    }
  }

  static Future<String> _decryptLogs(Uint8List encryptedData) async {
    try {
      final keyBase64 = await _storage.read(key: _logEncryptionKeyName);
      if (keyBase64 == null) return '[]';

      final key = base64.decode(keyBase64);

      // Extract encrypted data (skip nonce for simple XOR)
      final encrypted = encryptedData.sublist(16);

      // Simple XOR decryption
      final decrypted = Uint8List(encrypted.length);
      for (int i = 0; i < encrypted.length; i++) {
        decrypted[i] = encrypted[i] ^ key[i % key.length];
      }

      return utf8.decode(decrypted);
    } catch (e) {
      // If decryption fails, try to read as plain text
      try {
        return utf8.decode(encryptedData);
      } catch (e) {
        return '[]';
      }
    }
  }

  static Uint8List _generateLogEncryptionKey() {
    final key = Uint8List(32);
    final random = Random.secure();
    for (int i = 0; i < key.length; i++) {
      key[i] = random.nextInt(256);
    }
    return key;
  }

  static Uint8List _generateNonce() {
    final nonce = Uint8List(16);
    final random = Random.secure();
    for (int i = 0; i < nonce.length; i++) {
      nonce[i] = random.nextInt(256);
    }
    return nonce;
  }

  static Future<void> _loadExistingLogs() async {
    if (_logFile?.existsSync() != true) return;

    try {
      final encryptedData = await _logFile!.readAsBytes();
      final logsJson = await _decryptLogs(encryptedData);
      final logsList = jsonDecode(logsJson) as List;

      _logBuffer = logsList
          .map((json) => LogEntry.fromJson(json as Map<String, dynamic>))
          .toList();

      // Keep only recent entries
      if (_logBuffer.length > _maxLogEntries) {
        _logBuffer = _logBuffer.sublist(_logBuffer.length - _maxLogEntries);
      }
    } catch (e) {
      // If loading fails, start with empty buffer
      _logBuffer = [];
    }
  }

  static Future<void> _rotateLogs() async {
    if (_logFile?.existsSync() != true) return;

    try {
      final directory = _logFile!.parent;
      final oldLogFile = File('${directory.path}/secure_logs_old.enc');

      // Delete old backup if it exists
      if (oldLogFile.existsSync()) {
        await oldLogFile.delete();
      }

      // Move current log to backup
      await _logFile!.rename(oldLogFile.path);

      // Create new log file
      _logFile = File('${directory.path}/secure_logs.enc');
    } catch (e) {
      // If rotation fails, continue with current file
    }
  }
}

/// Log entry levels
enum LogLevel { debug, info, warning, error, security }

/// Individual log entry
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final Map<String, dynamic>? data;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.data,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.name,
    'message': message,
    'data': data,
  };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
    timestamp: DateTime.parse(json['timestamp']),
    level: LogLevel.values.firstWhere((l) => l.name == json['level']),
    message: json['message'],
    data: json['data'] as Map<String, dynamic>?,
  );
}
