import 'package:flutter/material.dart';
import '../models/premium_feature.dart';
import '../services/feature_gate.dart';
import 'premium_badge.dart';
import 'upgrade_prompt_dialog.dart';

/// Screen that shows a preview of a premium feature
class FeaturePreviewScreen extends StatelessWidget {
  final PremiumFeature feature;
  final FeatureGate featureGate;
  final Widget? previewContent;
  final List<String>? benefits;

  const FeaturePreviewScreen({
    super.key,
    required this.feature,
    required this.featureGate,
    this.previewContent,
    this.benefits,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(feature.displayName),
            const SizedBox(width: 8),
            const PremiumBadge.small(),
          ],
        ),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFeatureHeader(theme),
                  const SizedBox(height: 24),
                  if (previewContent != null) ...[
                    _buildPreviewSection(theme),
                    const SizedBox(height: 24),
                  ],
                  _buildBenefitsSection(theme),
                  const SizedBox(height: 24),
                  _buildTrialInfo(theme),
                ],
              ),
            ),
          ),
          _buildBottomActions(context, theme),
        ],
      ),
    );
  }

  Widget _buildFeatureHeader(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.1),
            theme.colorScheme.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            _getIconData(feature.iconName),
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            feature.displayName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            feature.description,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: previewContent!,
        ),
      ],
    );
  }

  Widget _buildBenefitsSection(ThemeData theme) {
    final featureBenefits = benefits ?? _getDefaultBenefits(feature);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What you\'ll get:',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...featureBenefits.map(
          (benefit) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    size: 16,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(benefit, style: theme.textTheme.bodyLarge),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrialInfo(ThemeData theme) {
    return FutureBuilder<bool>(
      future: featureGate.isTrialEligible(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.timer, color: Colors.green, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Free 14-day trial available!',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      'Try all premium features risk-free',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomActions(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: FutureBuilder<bool>(
                future: featureGate.isTrialEligible(),
                builder: (context, snapshot) {
                  final isTrialEligible = snapshot.data ?? false;

                  if (isTrialEligible) {
                    return OutlinedButton(
                      onPressed: () => _startTrial(context),
                      child: const Text('Start Free Trial'),
                    );
                  } else {
                    return OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Maybe Later'),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _showUpgradeDialog(context),
                child: const Text('Upgrade Now'),
              ),
            ),
          ],
        ),
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

  List<String> _getDefaultBenefits(PremiumFeature feature) {
    switch (feature) {
      case PremiumFeature.multipleVaults:
        return [
          'Create unlimited separate vaults',
          'Organize passwords by category (Personal, Work, Family)',
          'Custom vault names, icons, and colors',
          'Independent security for each vault',
        ];
      case PremiumFeature.totpGenerator:
        return [
          'Built-in 2FA code generator',
          'QR code scanning for easy setup',
          'Real-time code updates with countdown',
          'Secure encrypted storage of TOTP secrets',
        ];
      case PremiumFeature.securityHealth:
        return [
          'Password strength analysis',
          'Duplicate password detection',
          'Breach monitoring with HaveIBeenPwned',
          'Security score and recommendations',
        ];
      case PremiumFeature.importExport:
        return [
          'Import from 1Password, Bitwarden, LastPass',
          'Browser password import support',
          'Encrypted backup exports',
          'Duplicate detection and merging',
        ];
      case PremiumFeature.p2pSync:
        return [
          'Sync between devices without cloud',
          'End-to-end encryption',
          'QR code device pairing',
          'Selective vault synchronization',
        ];
      case PremiumFeature.unlimitedPasswords:
        return [
          'Store unlimited passwords',
          'No 50-password limit',
          'Full access to all features',
          'Future premium features included',
        ];
      case PremiumFeature.breachChecking:
        return [
          'Offline breach checking with HIBP dataset',
          'Complete privacy - no passwords sent online',
          'Check against millions of breached passwords',
          'Fast local database lookups',
        ];
    }
  }

  Future<void> _startTrial(BuildContext context) async {
    final success = await featureGate.startTrial();
    if (success && context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('14-day free trial started! Enjoy premium features!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start trial. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => UpgradePromptDialog(
        feature: feature,
        featureGate: featureGate,
        onUpgradeSuccess: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
