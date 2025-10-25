import 'package:flutter/material.dart';
import '../services/animation_service.dart';
import '../services/haptic_feedback_service.dart';

/// Animated button with haptic feedback and Material Design motion
class AnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final bool isPrimary;

  const AnimatedButton({
    super.key,
    required this.child,
    this.onPressed,
    this.style,
    this.isPrimary = false,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimationService.getDuration(AnimationType.short),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AnimationService.getCurve(CurveType.standard),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  void _handleTap() async {
    await HapticFeedbackService.buttonPress();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: widget.isPrimary
                ? FilledButton(
                    onPressed: null, // Handled by GestureDetector
                    style: widget.style,
                    child: widget.child,
                  )
                : OutlinedButton(
                    onPressed: null, // Handled by GestureDetector
                    style: widget.style,
                    child: widget.child,
                  ),
          );
        },
      ),
    );
  }
}

/// Animated list tile with Material Design motion
class AnimatedListTile extends StatefulWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const AnimatedListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<AnimatedListTile> createState() => _AnimatedListTileState();
}

class _AnimatedListTileState extends State<AnimatedListTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimationService.getDuration(AnimationType.short),
      vsync: this,
    );
    _elevationAnimation = Tween<double>(begin: 0.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AnimationService.getCurve(CurveType.standard),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  void _handleTap() async {
    await HapticFeedbackService.selection();
    widget.onTap?.call();
  }

  void _handleLongPress() async {
    await HapticFeedbackService.longPress();
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      onLongPress: _handleLongPress,
      child: AnimatedBuilder(
        animation: _elevationAnimation,
        builder: (context, child) {
          return Card(
            elevation: _elevationAnimation.value,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: widget.leading,
              title: widget.title,
              subtitle: widget.subtitle,
              trailing: widget.trailing,
            ),
          );
        },
      ),
    );
  }
}

/// Animated page transition wrapper
class AnimatedPageTransition extends StatelessWidget {
  final Widget child;
  final SharedAxisTransitionType transitionType;

  const AnimatedPageTransition({
    super.key,
    required this.child,
    this.transitionType = SharedAxisTransitionType.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    // Simple fade transition for now
    return AnimatedSwitcher(
      duration: AnimationService.getDuration(AnimationType.medium),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: child,
    );
  }
}

/// Animated vault card with switching animation
class AnimatedVaultCard extends StatefulWidget {
  final String vaultName;
  final String vaultIcon;
  final Color vaultColor;
  final int passwordCount;
  final double securityScore;
  final bool isActive;
  final VoidCallback? onTap;

  const AnimatedVaultCard({
    super.key,
    required this.vaultName,
    required this.vaultIcon,
    required this.vaultColor,
    required this.passwordCount,
    required this.securityScore,
    this.isActive = false,
    this.onTap,
  });

  @override
  State<AnimatedVaultCard> createState() => _AnimatedVaultCardState();
}

class _AnimatedVaultCardState extends State<AnimatedVaultCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimationService.getDuration(AnimationType.medium),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AnimationService.getCurve(CurveType.emphasized),
      ),
    );
    _elevationAnimation = Tween<double>(begin: 1.0, end: 8.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AnimationService.getCurve(CurveType.standard),
      ),
    );

    if (widget.isActive) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(AnimatedVaultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() async {
    await HapticFeedbackService.vaultSwitch();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Card(
              elevation: _elevationAnimation.value,
              color: widget.isActive
                  ? widget.vaultColor.withOpacity(0.1)
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: widget.vaultColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getIconData(widget.vaultIcon),
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.vaultName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${widget.passwordCount} contraseñas',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (widget.isActive)
                          Icon(Icons.check_circle, color: widget.vaultColor),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: widget.securityScore / 100,
                      backgroundColor: Colors.grey.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getSecurityColor(widget.securityScore),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Seguridad: ${widget.securityScore.toInt()}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'work':
        return Icons.work;
      case 'home':
        return Icons.home;
      case 'family':
        return Icons.family_restroom;
      case 'school':
        return Icons.school;
      case 'shopping':
        return Icons.shopping_cart;
      default:
        return Icons.folder;
    }
  }

  Color _getSecurityColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
}

/// Animated TOTP code display with countdown
class AnimatedTOTPCode extends StatefulWidget {
  final String code;
  final int remainingSeconds;
  final VoidCallback? onCopy;

  const AnimatedTOTPCode({
    super.key,
    required this.code,
    required this.remainingSeconds,
    this.onCopy,
  });

  @override
  State<AnimatedTOTPCode> createState() => _AnimatedTOTPCodeState();
}

class _AnimatedTOTPCodeState extends State<AnimatedTOTPCode>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _countdownController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _countdownController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _updateAnimations();
  }

  @override
  void didUpdateWidget(AnimatedTOTPCode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.remainingSeconds != oldWidget.remainingSeconds) {
      _updateAnimations();
    }
  }

  void _updateAnimations() {
    if (widget.remainingSeconds <= 10) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownController.dispose();
    super.dispose();
  }

  void _handleCopy() async {
    await HapticFeedbackService.copyToClipboard();
    widget.onCopy?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isExpiring = widget.remainingSeconds <= 10;

    return GestureDetector(
      onTap: _handleCopy,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: isExpiring ? _pulseAnimation.value : 1.0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isExpiring
                    ? Colors.red.withOpacity(0.1)
                    : Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isExpiring
                      ? Colors.red
                      : Theme.of(context).colorScheme.outline,
                  width: isExpiring ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    widget.code,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontFamily: 'monospace',
                      color: isExpiring ? Colors.red : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${widget.remainingSeconds}s restantes',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isExpiring ? Colors.red : null,
                        ),
                      ),
                      Icon(
                        Icons.copy,
                        size: 16,
                        color: isExpiring ? Colors.red : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: widget.remainingSeconds / 30,
                    backgroundColor: Colors.grey.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isExpiring
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
