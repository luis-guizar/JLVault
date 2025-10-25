import 'package:flutter/material.dart';
import '../models/premium_feature.dart';
import '../models/license_status.dart';
import '../services/feature_gate.dart';
import 'upgrade_prompt_dialog.dart';
import 'feature_preview_screen.dart';
import 'premium_badge.dart';

/// Widget that wraps content with feature gating logic
class FeatureGateWrapper extends StatelessWidget {
  final PremiumFeature feature;
  final FeatureGate featureGate;
  final Widget child;
  final Widget? lockedChild;
  final String? customMessage;
  final bool showPreviewScreen;
  final VoidCallback? onAccessGranted;

  const FeatureGateWrapper({
    super.key,
    required this.feature,
    required this.featureGate,
    required this.child,
    this.lockedChild,
    this.customMessage,
    this.showPreviewScreen = false,
    this.onAccessGranted,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<PremiumFeature, bool>>(
      stream: featureGate.accessStream,
      initialData: featureGate.currentAccess,
      builder: (context, snapshot) {
        final hasAccess = snapshot.data?[feature] ?? false;

        if (hasAccess) {
          return child;
        }

        return lockedChild ?? _buildLockedContent(context);
      },
    );
  }

  Widget _buildLockedContent(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                _getIconData(feature.iconName),
                color: theme.colorScheme.primary,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          feature.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const PremiumBadge.small(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customMessage ?? feature.description,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (showPreviewScreen) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showPreviewScreen(context),
                    child: const Text('Learn More'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showUpgradeDialog(context),
                  child: const Text('Upgrade'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'folder_special':
        return Icons.folder_special;
      case 'security':
        return Icons.security;
      case 'health_and_safety':
        return Icons.health_and_safety;
      case 'import_export':
        return Icons.import_export;
      case 'sync':
        return Icons.sync;
      case 'all_inclusive':
        return Icons.all_inclusive;
      default:
        return Icons.star;
    }
  }

  void _showPreviewScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            FeaturePreviewScreen(feature: feature, featureGate: featureGate),
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => UpgradePromptDialog(
        feature: feature,
        featureGate: featureGate,
        onUpgradeSuccess: () {
          onAccessGranted?.call();
        },
      ),
    );
  }
}

/// Widget that shows a locked feature button
class LockedFeatureButton extends StatelessWidget {
  final PremiumFeature feature;
  final FeatureGate featureGate;
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final VoidCallback? onAccessGranted;

  const LockedFeatureButton({
    super.key,
    required this.feature,
    required this.featureGate,
    required this.label,
    this.icon,
    this.onPressed,
    this.onAccessGranted,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<PremiumFeature, bool>>(
      stream: featureGate.accessStream,
      initialData: featureGate.currentAccess,
      builder: (context, snapshot) {
        final hasAccess = snapshot.data?[feature] ?? false;

        if (hasAccess) {
          return ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          );
        }

        return OutlinedButton.icon(
          onPressed: () => _showUpgradeDialog(context),
          icon: Icon(icon),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              const SizedBox(width: 8),
              const PremiumBadge.small(),
            ],
          ),
        );
      },
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => UpgradePromptDialog(
        feature: feature,
        featureGate: featureGate,
        onUpgradeSuccess: () {
          onAccessGranted?.call();
        },
      ),
    );
  }
}

/// Widget that shows password limit information
class PasswordLimitIndicator extends StatelessWidget {
  final FeatureGate featureGate;
  final int currentCount;
  final bool showUpgradeButton;

  const PasswordLimitIndicator({
    super.key,
    required this.featureGate,
    required this.currentCount,
    this.showUpgradeButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<PremiumFeature, bool>>(
      stream: featureGate.accessStream,
      initialData: featureGate.currentAccess,
      builder: (context, snapshot) {
        final hasUnlimited =
            snapshot.data?[PremiumFeature.unlimitedPasswords] ?? false;

        if (hasUnlimited) {
          return _buildUnlimitedIndicator(context);
        }

        return _buildLimitedIndicator(context);
      },
    );
  }

  Widget _buildUnlimitedIndicator(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<LicenseStatus>(
      future: featureGate.getLicenseStatus(),
      builder: (context, snapshot) {
        final status = snapshot.data ?? LicenseStatus.free;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.all_inclusive, size: 16, color: Colors.green),
              const SizedBox(width: 4),
              Text(
                status == LicenseStatus.trial
                    ? 'Trial: Unlimited ($currentCount)'
                    : 'Premium: Unlimited ($currentCount)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLimitedIndicator(BuildContext context) {
    final theme = Theme.of(context);
    const limit = 50;
    final remaining = (limit - currentCount).clamp(0, limit);
    final isNearLimit = remaining <= 5;
    final hasReachedLimit = remaining == 0;

    Color indicatorColor = theme.colorScheme.primary;
    if (hasReachedLimit) {
      indicatorColor = Colors.red;
    } else if (isNearLimit) {
      indicatorColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: indicatorColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasReachedLimit ? Icons.warning : Icons.storage,
            size: 16,
            color: indicatorColor,
          ),
          const SizedBox(width: 4),
          Text(
            '$currentCount/$limit passwords',
            style: theme.textTheme.bodySmall?.copyWith(
              color: indicatorColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (showUpgradeButton && (hasReachedLimit || isNearLimit)) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showUpgradeDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: indicatorColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'UPGRADE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => UpgradePromptDialog(
        feature: PremiumFeature.unlimitedPasswords,
        featureGate: featureGate,
      ),
    );
  }
}
