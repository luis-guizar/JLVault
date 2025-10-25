import 'package:flutter/material.dart';
import '../services/vault_manager.dart';
import '../services/vault_encryption_service.dart';
import '../services/theme_service.dart';
import '../widgets/responsive_navigation.dart';
import '../widgets/animated_widgets.dart';
import '../services/animation_service.dart';
import 'home_screen.dart';
import 'totp_management_screen.dart';
import 'security_dashboard_screen.dart';
import 'p2p_sync_screen.dart';
import 'settings_screen.dart';

/// Main navigation screen that handles bottom navigation and screen switching
class MainNavigationScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  final VaultManager vaultManager;
  final VaultEncryptionService encryptionService;
  final ThemeService themeService;

  const MainNavigationScreen({
    super.key,
    this.onLogout,
    required this.vaultManager,
    required this.encryptionService,
    required this.themeService,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavigationChanged(int index) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });

      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return HomeScreen(
          onLogout: widget.onLogout,
          vaultManager: widget.vaultManager,
          encryptionService: widget.encryptionService,
          themeService: widget.themeService,
        );
      case 1:
        return TOTPManagementScreen(
          accounts: [], // Will be loaded by the screen itself
          onAccountUpdated: (account) {
            // Handle account updates if needed
          },
        );
      case 2:
        return SecurityDashboardScreen(
          vaultId: null, // Will use active vault
        );
      case 3:
        return const P2PSyncScreen();
      case 4:
        return SettingsScreen(themeService: widget.themeService);
      default:
        return HomeScreen(
          onLogout: widget.onLogout,
          vaultManager: widget.vaultManager,
          encryptionService: widget.encryptionService,
          themeService: widget.themeService,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwipeNavigationDetector(
      onSwipeLeft: () {
        if (_currentIndex < AppNavigationDestinations.destinations.length - 1) {
          _onNavigationChanged(_currentIndex + 1);
        }
      },
      onSwipeRight: () {
        if (_currentIndex > 0) {
          _onNavigationChanged(_currentIndex - 1);
        }
      },
      child: AdaptiveScaffold(
        currentNavigationIndex: _currentIndex,
        onNavigationChanged: _onNavigationChanged,
        navigationDestinations: AppNavigationDestinations.destinations,
        body: PageView.builder(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          itemCount: AppNavigationDestinations.destinations.length,
          itemBuilder: (context, index) {
            return AnimatedPageTransition(
              key: ValueKey(index),
              transitionType: SharedAxisTransitionType.horizontal,
              child: _buildScreen(index),
            );
          },
        ),
      ),
    );
  }
}

/// Navigation helper for deep linking and state management
class NavigationHelper {
  static const String homeRoute = '/home';
  static const String totpRoute = '/totp';
  static const String securityRoute = '/security';
  static const String syncRoute = '/sync';
  static const String settingsRoute = '/settings';

  static final Map<String, int> _routeToIndex = {
    homeRoute: 0,
    totpRoute: 1,
    securityRoute: 2,
    syncRoute: 3,
    settingsRoute: 4,
  };

  static final Map<int, String> _indexToRoute = {
    0: homeRoute,
    1: totpRoute,
    2: securityRoute,
    3: syncRoute,
    4: settingsRoute,
  };

  static int getIndexFromRoute(String route) {
    return _routeToIndex[route] ?? 0;
  }

  static String getRouteFromIndex(int index) {
    return _indexToRoute[index] ?? homeRoute;
  }

  /// Handle deep link navigation
  static void navigateToRoute(BuildContext context, String route) {
    final index = getIndexFromRoute(route);
    // This would be implemented with a state management solution
    // For now, we'll use a simple approach
  }

  /// Get appropriate app bar for each screen
  static PreferredSizeWidget? getAppBarForIndex(
    int index,
    BuildContext context,
    VoidCallback? onLogout,
  ) {
    switch (index) {
      case 0:
        return null; // HomeScreen handles its own app bar
      case 1:
        return AppBar(title: const Text('Autenticador TOTP'), elevation: 0);
      case 2:
        return AppBar(title: const Text('Panel de Seguridad'), elevation: 0);
      case 3:
        return AppBar(title: const Text('Sincronización P2P'), elevation: 0);
      case 4:
        return AppBar(
          title: const Text('Configuración'),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.lock_outline),
              onPressed: onLogout,
              tooltip: 'Bloquear aplicación',
            ),
          ],
        );
      default:
        return null;
    }
  }
}

/// Screen transition animations for navigation
class ScreenTransitions {
  static Widget slideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
      child: child,
    );
  }

  static Widget fadeTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(opacity: animation, child: child);
  }

  static Widget scaleTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.8,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
      child: FadeTransition(opacity: animation, child: child),
    );
  }
}
