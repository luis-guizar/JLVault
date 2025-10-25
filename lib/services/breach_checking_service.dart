import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import '../models/premium_feature.dart';
import '../services/feature_gate_factory.dart';
import '../services/license_manager_factory.dart';

class BreachCheckResult {
  final bool isBreached;
  final int breachCount;
  final DateTime checkedAt;
  final String? error;

  BreachCheckResult({
    required this.isBreached,
    required this.breachCount,
    required this.checkedAt,
    this.error,
  });

  BreachCheckResult.error(String errorMessage)
    : isBreached = false,
      breachCount = 0,
      checkedAt = DateTime.now(),
      error = errorMessage;

  Map<String, dynamic> toJson() {
    return {
      'isBreached': isBreached,
      'breachCount': breachCount,
      'checkedAt': checkedAt.millisecondsSinceEpoch,
      'error': error,
    };
  }

  factory BreachCheckResult.fromJson(Map<String, dynamic> json) {
    return BreachCheckResult(
      isBreached: json['isBreached'] ?? false,
      breachCount: json['breachCount'] ?? 0,
      checkedAt: DateTime.fromMillisecondsSinceEpoch(json['checkedAt']),
      error: json['error'],
    );
  }
}

class BreachCheckingService {
  static const String _hibpFileName = 'hibp_hashes.txt';
  static const Duration _cacheExpiry = Duration(hours: 24);

  // Cache for breach check results
  static final Map<String, BreachCheckResult> _cache = {};
  static bool _isDatasetLoaded = false;
  static final Set<String> _breachedHashes = <String>{};

  /// Checks if a password has been breached using offline HIBP dataset
  /// This is a premium feature that requires the HIBP dataset to be imported
  static Future<BreachCheckResult> checkPasswordBreach(String password) async {
    try {
      // Check if premium feature is available
      final licenseManager = LicenseManagerFactory.getInstance();
      final featureGate = FeatureGateFactory.create(licenseManager);
      final hasBreachChecking = featureGate.canAccess(
        PremiumFeature.breachChecking,
      );

      if (!hasBreachChecking) {
        return BreachCheckResult.error(
          'Breach checking is a premium feature. Upgrade to premium to access this functionality.',
        );
      }

      // Generate SHA-1 hash of the password
      final bytes = utf8.encode(password);
      final digest = sha1.convert(bytes);
      final hashString = digest.toString().toUpperCase();

      // Check cache first
      final cacheKey = hashString;
      if (_cache.containsKey(cacheKey)) {
        final cachedResult = _cache[cacheKey]!;
        final cacheAge = DateTime.now().difference(cachedResult.checkedAt);
        if (cacheAge < _cacheExpiry && cachedResult.error == null) {
          return cachedResult;
        }
      }

      // Load dataset if not already loaded
      if (!_isDatasetLoaded) {
        await _loadHIBPDataset();
      }

      // Check if dataset is available
      if (_breachedHashes.isEmpty) {
        return BreachCheckResult.error(
          'HIBP dataset not available. Please import the dataset first.',
        );
      }

      // Check if hash exists in breached passwords
      final isBreached = _breachedHashes.contains(hashString);

      final result = BreachCheckResult(
        isBreached: isBreached,
        breachCount: isBreached
            ? 1
            : 0, // We don't store breach counts in offline mode
        checkedAt: DateTime.now(),
      );

      // Cache the result
      _cache[cacheKey] = result;
      return result;
    } catch (e) {
      return BreachCheckResult.error('Error checking breach: ${e.toString()}');
    }
  }

  /// Loads the HIBP dataset from local storage
  static Future<void> _loadHIBPDataset() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_hibpFileName');

      if (!await file.exists()) {
        _isDatasetLoaded = true; // Mark as loaded even if file doesn't exist
        return;
      }

      final lines = await file.readAsLines();
      _breachedHashes.clear();

      for (final line in lines) {
        final trimmedLine = line.trim().toUpperCase();
        if (trimmedLine.isNotEmpty && trimmedLine.length == 40) {
          // SHA-1 hashes are 40 characters long
          _breachedHashes.add(trimmedLine);
        }
      }

      _isDatasetLoaded = true;
    } catch (e) {
      _isDatasetLoaded = true; // Mark as loaded to avoid repeated attempts
      throw Exception('Failed to load HIBP dataset: $e');
    }
  }

  /// Imports HIBP dataset from a file path
  /// This is used when users manually import the HIBP dataset
  static Future<bool> importHIBPDataset(String filePath) async {
    try {
      final sourceFile = File(filePath);
      if (!await sourceFile.exists()) {
        throw Exception('Source file does not exist');
      }

      final directory = await getApplicationDocumentsDirectory();
      final targetFile = File('${directory.path}/$_hibpFileName');

      // Copy the file to app documents directory
      await sourceFile.copy(targetFile.path);

      // Clear cache and reload dataset
      _cache.clear();
      _isDatasetLoaded = false;
      _breachedHashes.clear();

      await _loadHIBPDataset();

      return true;
    } catch (e) {
      throw Exception('Failed to import HIBP dataset: $e');
    }
  }

  /// Checks if HIBP dataset is available
  static Future<bool> isDatasetAvailable() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$_hibpFileName');
    return await file.exists();
  }

  /// Gets dataset information
  static Future<Map<String, dynamic>> getDatasetInfo() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_hibpFileName');

      if (!await file.exists()) {
        return {
          'available': false,
          'size': 0,
          'hashCount': 0,
          'lastModified': null,
        };
      }

      final stat = await file.stat();

      // Load dataset if not already loaded to get hash count
      if (!_isDatasetLoaded) {
        await _loadHIBPDataset();
      }

      return {
        'available': true,
        'size': stat.size,
        'hashCount': _breachedHashes.length,
        'lastModified': stat.modified,
      };
    } catch (e) {
      return {
        'available': false,
        'size': 0,
        'hashCount': 0,
        'lastModified': null,
        'error': e.toString(),
      };
    }
  }

  /// Removes the HIBP dataset
  static Future<void> removeDataset() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_hibpFileName');

      if (await file.exists()) {
        await file.delete();
      }

      // Clear cache and reset state
      _cache.clear();
      _isDatasetLoaded = false;
      _breachedHashes.clear();
    } catch (e) {
      throw Exception('Failed to remove HIBP dataset: $e');
    }
  }

  /// Checks multiple passwords for breaches
  static Future<Map<String, BreachCheckResult>> checkMultiplePasswords(
    List<String> passwords,
  ) async {
    final results = <String, BreachCheckResult>{};

    for (final password in passwords) {
      results[password] = await checkPasswordBreach(password);
    }

    return results;
  }

  /// Clears the breach check cache
  static void clearCache() {
    _cache.clear();
  }

  /// Gets cached breach check result if available and not expired
  static BreachCheckResult? getCachedResult(String password) {
    final bytes = utf8.encode(password);
    final digest = sha1.convert(bytes);
    final hashString = digest.toString().toUpperCase();

    final cachedResult = _cache[hashString];
    if (cachedResult != null) {
      final cacheAge = DateTime.now().difference(cachedResult.checkedAt);
      if (cacheAge < _cacheExpiry && cachedResult.error == null) {
        return cachedResult;
      }
    }
    return null;
  }

  /// Gets breach status description for UI display
  static String getBreachStatusDescription(BreachCheckResult result) {
    if (result.error != null) {
      return 'Unable to check breach status';
    }

    if (!result.isBreached) {
      return 'No known breaches';
    }

    return 'Found in data breach';
  }

  /// Gets breach priority based on breach status
  static String getBreachPriority(BreachCheckResult result) {
    if (!result.isBreached) return 'None';
    return 'High'; // All breached passwords are high priority in offline mode
  }

  /// Checks if breach check is needed (cache expired or no previous check)
  static bool needsBreachCheck(DateTime? lastCheck) {
    if (lastCheck == null) return true;

    final timeSinceCheck = DateTime.now().difference(lastCheck);
    return timeSinceCheck > _cacheExpiry;
  }
}
