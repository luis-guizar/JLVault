import 'package:flutter/material.dart';
import '../models/premium_feature.dart';
import '../services/feature_gate.dart';
import '../services/android_feature_gate.dart';

import 'premium_badge.dart';
import 'translated_text.dart';

/// Dialog that prompts users to upgrade to premium
class UpgradePromptDialog extends StatefulWidget {
  final PremiumFeature? feature;
  final FeatureGate featureGate;
  final VoidCallback? onUpgradeSuccess;

  const UpgradePromptDialog({
    super.key,
    this.feature,
    required this.featureGate,
    this.onUpgradeSuccess,
  });

  @override
  State<UpgradePromptDialog> createState() => _UpgradePromptDialogState();
}

class _UpgradePromptDialogState extends State<UpgradePromptDialog> {
  bool _isLoading = false;
  String? _price;

  @override
  void initState() {
    super.initState();
    _loadPrice();
  }

  Future<void> _loadPrice() async {
    if (widget.featureGate is AndroidFeatureGate) {
      final androidGate = widget.featureGate as AndroidFeatureGate;
      final price = await androidGate.getPremiumPrice();
      if (mounted) {
        setState(() {
          _price = price;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feature = widget.feature;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.star, color: theme.colorScheme.primary, size: 28),
          const SizedBox(width: 8),
          const TranslatedText('upgradetoPremium'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (feature != null) ...[
              _buildFeatureHeader(feature, theme),
              const SizedBox(height: 16),
            ],
            _buildFeaturesList(theme),
            const SizedBox(height: 16),
            _buildPriceInfo(theme),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const TranslatedText('maybelater'),
        ),
        TextButton(
          onPressed: _isLoading ? null : _restorePurchases,
          child: const TranslatedText('restore'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _purchasePremium,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_price != null ? 'Buy $_price' : 'Buy Premium'),
        ),
      ],
    );
  }

  Widget _buildFeatureHeader(PremiumFeature feature, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            _getIconData(feature.iconName),
            color: theme.colorScheme.primary,
            size: 24,
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
                Text(feature.description, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList(ThemeData theme) {
    final features = PremiumFeature.values.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Premium Features:',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...features.map(
          (feature) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.displayName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        feature.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(
                            0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'One-time purchase',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Unlock all premium features forever with a single purchase. No subscriptions, no recurring fees.',
            style: theme.textTheme.bodySmall,
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

  Future<void> _purchasePremium() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await widget.featureGate.initiatePurchase();
      if (success && mounted) {
        Navigator.of(context).pop();
        widget.onUpgradeSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Premium features unlocked! Welcome to Premium!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await widget.featureGate.restorePurchases();
      if (success && mounted) {
        Navigator.of(context).pop();
        widget.onUpgradeSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchases restored successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No purchases found to restore.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
