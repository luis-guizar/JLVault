import 'package:flutter/material.dart';
import '../services/haptic_feedback_service.dart';

/// Responsive navigation widget that adapts to different screen sizes
class ResponsiveNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onDestinationSelected;
  final List<NavigationDestination> destinations;
  final bool isTablet;

  const ResponsiveNavigation({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isTablet) {
      // Use navigation rail for tablets
      return NavigationRail(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) async {
          await HapticFeedbackService.selection();
          onDestinationSelected(index);
        },
        labelType: NavigationRailLabelType.all,
        destinations: destinations
            .map(
              (dest) => NavigationRailDestination(
                icon: dest.icon,
                selectedIcon: dest.selectedIcon,
                label: Text(dest.label),
              ),
            )
            .toList(),
      );
    } else {
      // Use bottom navigation bar for phones
      return NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) async {
          await HapticFeedbackService.selection();
          onDestinationSelected(index);
        },
        destinations: destinations,
      );
    }
  }
}

/// Navigation destinations for the app
class AppNavigationDestinations {
  static const List<NavigationDestination> destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Inicio',
    ),
    NavigationDestination(
      icon: Icon(Icons.security_outlined),
      selectedIcon: Icon(Icons.security),
      label: 'TOTP',
    ),
    NavigationDestination(
      icon: Icon(Icons.shield_outlined),
      selectedIcon: Icon(Icons.shield),
      label: 'Seguridad',
    ),
    NavigationDestination(
      icon: Icon(Icons.import_export_outlined),
      selectedIcon: Icon(Icons.import_export),
      label: 'Datos',
    ),
    NavigationDestination(
      icon: Icon(Icons.sync_outlined),
      selectedIcon: Icon(Icons.sync),
      label: 'Sync',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Ajustes',
    ),
  ];
}

/// Responsive layout helper
class ResponsiveLayout {
  static const double tabletBreakpoint = 600.0;
  static const double desktopBreakpoint = 1200.0;

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  static bool isPhone(BuildContext context) {
    return MediaQuery.of(context).size.width < tabletBreakpoint;
  }

  /// Get appropriate padding for different screen sizes
  static EdgeInsets getScreenPadding(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
    } else {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    }
  }

  /// Get appropriate card width for different screen sizes
  static double getCardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (isDesktop(context)) {
      return (screenWidth - 96) / 3; // 3 columns with padding
    } else if (isTablet(context)) {
      return (screenWidth - 72) / 2; // 2 columns with padding
    } else {
      return screenWidth - 32; // Full width with padding
    }
  }

  /// Get appropriate grid column count
  static int getGridColumns(BuildContext context) {
    if (isDesktop(context)) {
      return 3;
    } else if (isTablet(context)) {
      return 2;
    } else {
      return 1;
    }
  }

  /// Get appropriate app bar height
  static double getAppBarHeight(BuildContext context) {
    if (isTablet(context)) {
      return 72.0;
    } else {
      return 56.0;
    }
  }
}

/// Adaptive scaffold that handles different screen sizes
class AdaptiveScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final int currentNavigationIndex;
  final Function(int) onNavigationChanged;
  final List<NavigationDestination> navigationDestinations;
  final Widget? drawer;
  final Widget? endDrawer;

  const AdaptiveScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    required this.currentNavigationIndex,
    required this.onNavigationChanged,
    required this.navigationDestinations,
    this.drawer,
    this.endDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveLayout.isTablet(context);

    if (isTablet) {
      // Tablet layout with navigation rail
      return Scaffold(
        appBar: appBar,
        drawer: drawer,
        endDrawer: endDrawer,
        body: Row(
          children: [
            ResponsiveNavigation(
              currentIndex: currentNavigationIndex,
              onDestinationSelected: onNavigationChanged,
              destinations: navigationDestinations,
              isTablet: true,
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: body),
          ],
        ),
        floatingActionButton: floatingActionButton,
      );
    } else {
      // Phone layout with bottom navigation
      return Scaffold(
        appBar: appBar,
        drawer: drawer,
        endDrawer: endDrawer,
        body: body,
        bottomNavigationBar: ResponsiveNavigation(
          currentIndex: currentNavigationIndex,
          onDestinationSelected: onNavigationChanged,
          destinations: navigationDestinations,
          isTablet: false,
        ),
        floatingActionButton: floatingActionButton,
      );
    }
  }
}

/// Swipe gesture detector for navigation
class SwipeNavigationDetector extends StatelessWidget {
  final Widget child;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;

  const SwipeNavigationDetector({
    super.key,
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onSwipeUp,
    this.onSwipeDown,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanEnd: (details) async {
        final velocity = details.velocity.pixelsPerSecond;
        const threshold = 500.0;

        if (velocity.dx.abs() > velocity.dy.abs()) {
          // Horizontal swipe
          if (velocity.dx > threshold) {
            // Swipe right
            await HapticFeedbackService.swipe();
            onSwipeRight?.call();
          } else if (velocity.dx < -threshold) {
            // Swipe left
            await HapticFeedbackService.swipe();
            onSwipeLeft?.call();
          }
        } else {
          // Vertical swipe
          if (velocity.dy > threshold) {
            // Swipe down
            await HapticFeedbackService.swipe();
            onSwipeDown?.call();
          } else if (velocity.dy < -threshold) {
            // Swipe up
            await HapticFeedbackService.swipe();
            onSwipeUp?.call();
          }
        }
      },
      child: child,
    );
  }
}

/// Responsive grid view for different screen sizes
class ResponsiveGridView extends StatelessWidget {
  final List<Widget> children;
  final double childAspectRatio;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  const ResponsiveGridView({
    super.key,
    required this.children,
    this.childAspectRatio = 1.0,
    this.mainAxisSpacing = 8.0,
    this.crossAxisSpacing = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveLayout.getGridColumns(context);

    return GridView.count(
      crossAxisCount: columns,
      childAspectRatio: childAspectRatio,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      padding: ResponsiveLayout.getScreenPadding(context),
      children: children,
    );
  }
}

/// Responsive list view with appropriate padding
class ResponsiveListView extends StatelessWidget {
  final List<Widget> children;
  final ScrollController? controller;
  final bool shrinkWrap;

  const ResponsiveListView({
    super.key,
    required this.children,
    this.controller,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      shrinkWrap: shrinkWrap,
      padding: ResponsiveLayout.getScreenPadding(context),
      children: children,
    );
  }
}
