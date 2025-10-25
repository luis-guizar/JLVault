import 'package:flutter/foundation.dart';
import 'dart:async';

/// Service for lazy loading non-critical components and services
class LazyLoadingService {
  static LazyLoadingService? _instance;
  static LazyLoadingService get instance =>
      _instance ??= LazyLoadingService._();

  LazyLoadingService._();

  final Map<String, Completer<dynamic>> _loadingCompleters = {};
  final Map<String, dynamic> _loadedServices = {};
  final Map<String, Future<dynamic> Function()> _loaders = {};

  /// Register a lazy loader for a service
  void registerLoader<T>(String key, Future<T> Function() loader) {
    _loaders[key] = loader;
  }

  /// Get a service, loading it lazily if not already loaded
  Future<T> getService<T>(String key) async {
    // Return cached service if already loaded
    if (_loadedServices.containsKey(key)) {
      return _loadedServices[key] as T;
    }

    // Return existing loading future if already in progress
    if (_loadingCompleters.containsKey(key)) {
      return await _loadingCompleters[key]!.future as T;
    }

    // Start loading the service
    final completer = Completer<T>();
    _loadingCompleters[key] = completer;

    try {
      final loader = _loaders[key];
      if (loader == null) {
        throw StateError('No loader registered for key: $key');
      }

      final service = await loader() as T;
      _loadedServices[key] = service;
      completer.complete(service);

      if (kDebugMode) {
        print('Lazy loaded service: $key');
      }

      return service;
    } catch (e) {
      completer.completeError(e);
      if (kDebugMode) {
        print('Error lazy loading service $key: $e');
      }
      rethrow;
    } finally {
      _loadingCompleters.remove(key);
    }
  }

  /// Check if a service is already loaded
  bool isLoaded(String key) {
    return _loadedServices.containsKey(key);
  }

  /// Preload a service in background without waiting
  void preloadService(String key) {
    if (!isLoaded(key) && !_loadingCompleters.containsKey(key)) {
      getService(key).catchError((e) {
        if (kDebugMode) {
          print('Error preloading service $key: $e');
        }
      });
    }
  }

  /// Preload multiple services in background
  void preloadServices(List<String> keys) {
    for (final key in keys) {
      preloadService(key);
    }
  }

  /// Get a service synchronously if already loaded, null otherwise
  T? getServiceIfLoaded<T>(String key) {
    return _loadedServices[key] as T?;
  }

  /// Clear all loaded services (useful for testing or memory cleanup)
  void clearAll() {
    _loadedServices.clear();
    _loadingCompleters.clear();
    _loaders.clear();
  }

  /// Clear a specific service
  void clearService(String key) {
    _loadedServices.remove(key);
    _loadingCompleters.remove(key);
  }

  /// Get memory usage information
  Map<String, dynamic> getMemoryInfo() {
    return {
      'loadedServices': _loadedServices.length,
      'loadingServices': _loadingCompleters.length,
      'registeredLoaders': _loaders.length,
    };
  }
}

/// Common service keys for lazy loading
class ServiceKeys {
  static const String securityAnalyzer = 'security_analyzer';
  static const String breachChecker = 'breach_checker';
  static const String importService = 'import_service';
  static const String exportService = 'export_service';
  static const String syncService = 'sync_service';
  static const String deviceDiscovery = 'device_discovery';
  static const String totpGenerator = 'totp_generator';
  static const String passwordGenerator = 'password_generator';
  static const String encryptionService = 'encryption_service';
}
