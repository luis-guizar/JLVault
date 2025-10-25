import 'package:flutter/material.dart';

/// Service providing Material Design 3 motion specifications and animations
class AnimationService {
  // Material Design 3 duration constants
  static const Duration _shortDuration = Duration(milliseconds: 200);
  static const Duration _mediumDuration = Duration(milliseconds: 300);
  static const Duration _longDuration = Duration(milliseconds: 500);
  static const Duration _extraLongDuration = Duration(milliseconds: 700);

  // Material Design 3 easing curves
  static const Curve _standardCurve = Curves.easeInOut;
  static const Curve _emphasizedCurve = Curves.easeOutBack;
  static const Curve _deceleratedCurve = Curves.easeOut;
  static const Curve _acceleratedCurve = Curves.easeIn;

  /// Standard page transition for Android
  static PageTransitionsBuilder get androidPageTransition {
    return const PredictiveBackPageTransitionsBuilder();
  }

  /// Fade through transition for content changes
  static Widget fadeThrough({
    required Widget child,
    required Animation<double> animation,
    Duration duration = _mediumDuration,
  }) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: _standardCurve),
      child: child,
    );
  }

  /// Shared axis transition for navigation between related content
  static Widget sharedAxisTransition({
    required Widget child,
    required Animation<double> animation,
    SharedAxisTransitionType transitionType =
        SharedAxisTransitionType.horizontal,
    Duration duration = _mediumDuration,
  }) {
    late Animation<Offset> slideAnimation;

    switch (transitionType) {
      case SharedAxisTransitionType.horizontal:
        slideAnimation = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: _emphasizedCurve));
        break;
      case SharedAxisTransitionType.vertical:
        slideAnimation = Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: _emphasizedCurve));
        break;
      case SharedAxisTransitionType.scaled:
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: _emphasizedCurve),
          child: FadeTransition(opacity: animation, child: child),
        );
    }

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  /// Container transform for morphing between UI elements
  static Widget containerTransform({
    required Widget child,
    required Animation<double> animation,
    Duration duration = _longDuration,
  }) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: animation, curve: _emphasizedCurve),
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  /// Vault switching animation with smooth transition
  static Widget vaultSwitchTransition({
    required Widget child,
    required Animation<double> animation,
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: _emphasizedCurve)),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: _standardCurve),
        child: child,
      ),
    );
  }

  /// Feature access animation for premium features
  static Widget featureAccessTransition({
    required Widget child,
    required Animation<double> animation,
  }) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.8,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animation, curve: _emphasizedCurve)),
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  /// List item animation for adding/removing items
  static Widget listItemTransition({
    required Widget child,
    required Animation<double> animation,
    bool isRemoving = false,
  }) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: animation,
        curve: isRemoving ? _acceleratedCurve : _deceleratedCurve,
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: isRemoving ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: _standardCurve)),
        child: FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  /// Bottom sheet animation
  static Widget bottomSheetTransition({
    required Widget child,
    required Animation<double> animation,
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 1.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: _deceleratedCurve)),
      child: child,
    );
  }

  /// Dialog animation
  static Widget dialogTransition({
    required Widget child,
    required Animation<double> animation,
  }) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.7,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animation, curve: _emphasizedCurve)),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: _standardCurve),
        child: child,
      ),
    );
  }

  /// Floating Action Button animation
  static Widget fabTransition({
    required Widget child,
    required Animation<double> animation,
  }) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: animation, curve: _emphasizedCurve),
      child: child,
    );
  }

  /// Search bar expand/collapse animation
  static Widget searchBarTransition({
    required Widget child,
    required Animation<double> animation,
  }) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: _standardCurve),
      axis: Axis.horizontal,
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  /// TOTP countdown animation
  static Widget totpCountdownTransition({
    required Widget child,
    required Animation<double> animation,
    required bool isExpiring,
  }) {
    if (isExpiring) {
      // Pulsing animation when TOTP is about to expire
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (animation.value * 0.1),
            child: child,
          );
        },
        child: child,
      );
    }

    return FadeTransition(opacity: animation, child: child);
  }

  /// Security alert animation
  static Widget securityAlertTransition({
    required Widget child,
    required Animation<double> animation,
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, -0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: _emphasizedCurve)),
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 0.8,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: _emphasizedCurve)),
        child: child,
      ),
    );
  }

  /// Get animation duration based on type
  static Duration getDuration(AnimationType type) {
    switch (type) {
      case AnimationType.short:
        return _shortDuration;
      case AnimationType.medium:
        return _mediumDuration;
      case AnimationType.long:
        return _longDuration;
      case AnimationType.extraLong:
        return _extraLongDuration;
    }
  }

  /// Get animation curve based on type
  static Curve getCurve(CurveType type) {
    switch (type) {
      case CurveType.standard:
        return _standardCurve;
      case CurveType.emphasized:
        return _emphasizedCurve;
      case CurveType.decelerated:
        return _deceleratedCurve;
      case CurveType.accelerated:
        return _acceleratedCurve;
    }
  }
}

/// Animation duration types
enum AnimationType { short, medium, long, extraLong }

/// Animation curve types
enum CurveType { standard, emphasized, decelerated, accelerated }

/// Shared axis transition types
enum SharedAxisTransitionType { horizontal, vertical, scaled }
