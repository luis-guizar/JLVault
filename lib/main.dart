import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'screens/lock_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/splash_screen.dart';
import 'services/vault_manager.dart';
import 'services/vault_encryption_service.dart';
import 'services/platform_crypto_service.dart';
import 'services/time_sync_service.dart';
import 'services/animation_service.dart';
import 'services/app_initialization_service.dart';
import 'services/splash_screen_service.dart';
import 'services/lazy_loading_service.dart';
import 'services/enhanced_auth_service.dart';

void main() async {
  final stopwatch = Stopwatch()..start();

  try {
    // Initialize only critical services for fast startup
    await AppInitializationService.instance.initializeCriticalServices();

    // Initialize enhanced authentication service
    await EnhancedAuthService.initialize();

    // Initialize platform crypto service
    try {
      await PlatformCryptoService.initialize();
      if (kDebugMode) {
        print('Platform crypto service initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Platform crypto service initialization failed: $e');
        print('Will fallback to Dart-based crypto');
      }
    }

    // Start background initialization (non-blocking)
    AppInitializationService.instance.initializeBackgroundServices();

    // Register lazy loaders for non-critical services
    _registerLazyLoaders();

    if (kDebugMode) {
      print('App startup completed in ${stopwatch.elapsedMilliseconds}ms');
    }

    runApp(const PasswordManagerApp());
  } catch (e) {
    if (kDebugMode) {
      print('Error during app startup: $e');
    }
    // Fallback to basic initialization
    runApp(const PasswordManagerApp());
  } finally {
    stopwatch.stop();
  }
}

/// Register lazy loaders for non-critical services
void _registerLazyLoaders() {
  final lazyLoader = LazyLoadingService.instance;

  // Register loaders for services that can be loaded on-demand
  lazyLoader.registerLoader(ServiceKeys.securityAnalyzer, () async {
    // Placeholder - would create actual security analyzer service
    return Future.value(null);
  });

  lazyLoader.registerLoader(ServiceKeys.breachChecker, () async {
    // Placeholder - would create actual breach checker service
    return Future.value(null);
  });

  lazyLoader.registerLoader(ServiceKeys.importService, () async {
    // Placeholder - would create actual import service
    return Future.value(null);
  });

  lazyLoader.registerLoader(ServiceKeys.totpGenerator, () async {
    // Placeholder - would create actual TOTP generator service
    return Future.value(null);
  });

  lazyLoader.registerLoader(ServiceKeys.passwordGenerator, () async {
    // Placeholder - would create actual password generator service
    return Future.value(null);
  });
}

class PasswordManagerApp extends StatefulWidget {
  const PasswordManagerApp({super.key});

  @override
  State<PasswordManagerApp> createState() => _PasswordManagerAppState();
}

class _PasswordManagerAppState extends State<PasswordManagerApp>
    with WidgetsBindingObserver {
  bool _isAuthenticated = false;
  bool _isInitialized = false;
  DateTime? _lastBackgroundTime;
  DateTime? _lastAuthenticationTime;
  VaultManager? _vaultManager;
  VaultEncryptionService? _encryptionService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  /// Initialize app with splash screen and preloading
  Future<void> _initializeApp() async {
    try {
      // Start preloading essential data
      SplashScreenService.instance.preloadEssentialData();

      // Wait for minimum splash duration and preload completion
      await Future.wait([
        Future.delayed(SplashScreenService.instance.minimumSplashDuration),
        SplashScreenService.instance.waitForPreload(),
      ]);

      // Initialize core services
      _vaultManager = DefaultVaultManager();
      _encryptionService = VaultEncryptionService();

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error during app initialization: $e');
      }
      // Fallback initialization
      _vaultManager = DefaultVaultManager();
      _encryptionService = VaultEncryptionService();
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // Clean up services
    try {
      TimeSyncService.stopMonitoring();
      AppInitializationService.instance.dispose();
      EnhancedAuthService.dispose();
    } catch (e) {
      if (kDebugMode) {
        print('Error disposing services: $e');
      }
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        // App is going to background - record the time and clear sensitive data
        _lastBackgroundTime = DateTime.now();
        EnhancedAuthService.onAppPaused();
        break;
      case AppLifecycleState.resumed:
        if (_isAuthenticated && _lastBackgroundTime != null) {
          // Check if authentication just happened (within last 5 seconds)
          final now = DateTime.now();
          final justAuthenticated =
              _lastAuthenticationTime != null &&
              now.difference(_lastAuthenticationTime!).inSeconds < 5;

          if (!justAuthenticated) {
            setState(() {
              _isAuthenticated = false;
            });
          }
        }
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.hidden:
        // App is hidden - clear sensitive data
        EnhancedAuthService.onAppBackgrounded();
        break;
    }
  }

  void _onAuthenticated() {
    _lastAuthenticationTime = DateTime.now();
    // Set a dummy master password for encryption service
    // In a real app, this would be the user's actual master password
    VaultEncryptionService.setMasterPassword('user_master_password');
    setState(() {
      _isAuthenticated = true;
    });
  }

  void _onLogout() {
    VaultEncryptionService.clearMasterPassword();
    setState(() {
      _isAuthenticated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show splash screen while initializing
    if (!_isInitialized) {
      return MaterialApp(
        title: 'Simple Vault',
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
      );
    }

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return ListenableBuilder(
          listenable: AppInitializationService.instance.themeService,
          builder: (context, child) {
            final themeService = AppInitializationService.instance.themeService;

            // Update theme service with dynamic colors if available
            themeService.updateDynamicColors(lightDynamic, darkDynamic);

            return MaterialApp(
              title: 'Simple Vault',
              theme: themeService.getLightTheme().copyWith(
                pageTransitionsTheme: PageTransitionsTheme(
                  builders: {
                    TargetPlatform.android:
                        AnimationService.androidPageTransition,
                  },
                ),
              ),
              darkTheme: themeService.getDarkTheme().copyWith(
                pageTransitionsTheme: PageTransitionsTheme(
                  builders: {
                    TargetPlatform.android:
                        AnimationService.androidPageTransition,
                  },
                ),
              ),
              themeMode: themeService.themeMode,
              debugShowCheckedModeBanner: false,
              home: _isAuthenticated
                  ? MainNavigationScreen(
                      onLogout: _onLogout,
                      vaultManager: _vaultManager!,
                      encryptionService: _encryptionService!,
                      themeService: themeService,
                    )
                  : LockScreen(onAuthenticated: _onAuthenticated),
            );
          },
        );
      },
    );
  }
}
