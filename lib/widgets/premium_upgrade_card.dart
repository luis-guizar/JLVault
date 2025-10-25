import 'package:flutter/material.dart';
import '../models/premium_feature.dart';

/// Widget that displays a premium upgrade prompt for locked features
class PremiumUpgradeCard extends StatelessWidget {
  final PremiumFeature feature;
  final String? customTitle;
  final String? customDescription;
  final VoidCallback? onUpgradePressed;

  const PremiumUpgradeCard({
    super.key,
    required this.feature,
    this.customTitle,
    this.customDescription,
    this.onUpgradePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.amber.shade50, Colors.orange.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.workspace_premium,
                size: 48,
                color: Colors.amber.shade700,
              ),
              const SizedBox(height: 16),
              Text(
                customTitle ?? _getFeatureTitle(feature),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                customDescription ?? _getFeatureDescription(feature),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildFeatureBenefits(feature),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onUpgradePressed ?? _showUpgradeDialog,
                  icon: const Icon(Icons.upgrade),
                  label: const Text('Upgrade to Premium'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _showFeatureDetails(context, feature),
                child: Text(
                  'Learn more about premium features',
                  style: TextStyle(color: Colors.amber.shade700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureBenefits(PremiumFeature feature) {
    final benefits = _getFeatureBenefits(feature);

    return Column(
      children: benefits
          .map(
            (benefit) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      benefit,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  String _getFeatureTitle(PremiumFeature feature) {
    switch (feature) {
      case PremiumFeature.breachChecking:
        return 'Breach Monitoring';
      case PremiumFeature.multipleVaults:
        return 'Multiple Vaults';
      case PremiumFeature.totpGenerator:
        return 'TOTP Authenticator';
      case PremiumFeature.securityHealth:
        return 'Security Health';
      case PremiumFeature.importExport:
        return 'Import/Export';
      case PremiumFeature.p2pSync:
        return 'Device Sync';
      case PremiumFeature.unlimitedPasswords:
        return 'Unlimited Passwords';
    }
  }

  String _getFeatureDescription(PremiumFeature feature) {
    switch (feature) {
      case PremiumFeature.breachChecking:
        return 'Monitor your passwords against known data breaches with offline checking using the HaveIBeenPwned database.';
      case PremiumFeature.multipleVaults:
        return 'Create multiple password vaults to organize your credentials by category, project, or team.';
      case PremiumFeature.totpGenerator:
        return 'Built-in two-factor authentication code generator with QR code scanning support.';
      case PremiumFeature.securityHealth:
        return 'Comprehensive security analysis including password strength, reuse detection, and health monitoring.';
      case PremiumFeature.importExport:
        return 'Import passwords from other password managers and export encrypted backups of your data.';
      case PremiumFeature.p2pSync:
        return 'Sync your passwords between devices securely without relying on cloud storage.';
      case PremiumFeature.unlimitedPasswords:
        return 'Store unlimited passwords without the 50-password limit of the free tier.';
    }
  }

  List<String> _getFeatureBenefits(PremiumFeature feature) {
    switch (feature) {
      case PremiumFeature.breachChecking:
        return [
          'Offline breach checking for complete privacy',
          'Real-time alerts for compromised passwords',
          'Detailed breach information and recommendations',
          'Automatic monitoring of all your passwords',
        ];
      case PremiumFeature.multipleVaults:
        return [
          'Create unlimited password vaults',
          'Organize by team, project, or category',
          'Individual vault encryption and access',
          'Advanced vault management features',
        ];
      case PremiumFeature.totpGenerator:
        return [
          'Built-in 2FA code generator',
          'QR code scanning for easy setup',
          'Time-based and counter-based codes',
          'Secure storage of TOTP secrets',
        ];
      case PremiumFeature.securityHealth:
        return [
          'Advanced password strength analysis',
          'Detailed security scoring and metrics',
          'Personalized security recommendations',
          'Password age and reuse detection',
        ];
      case PremiumFeature.importExport:
        return [
          'Import from 10+ password managers',
          'Encrypted backup exports',
          'Selective import/export by vault',
          'Advanced duplicate detection',
        ];
      case PremiumFeature.p2pSync:
        return [
          'Secure device-to-device sync',
          'No cloud storage required',
          'End-to-end encryption',
          'Automatic conflict resolution',
        ];
      case PremiumFeature.unlimitedPasswords:
        return [
          'Store unlimited passwords',
          'No 50-password limit',
          'Unlimited vault capacity',
          'Scale with your needs',
        ];
    }
  }

  void _showUpgradeDialog() {
    // This would typically navigate to a premium upgrade screen
    // For now, we'll show a simple dialog
  }

  void _showFeatureDetails(BuildContext context, PremiumFeature feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getFeatureTitle(feature)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_getFeatureDescription(feature)),
              const SizedBox(height: 16),
              const Text(
                'Premium Benefits:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._getFeatureBenefits(feature).map(
                (benefit) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(benefit)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to upgrade screen
            },
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }
}

/// Compact version of the premium upgrade card for smaller spaces
class PremiumUpgradeCompact extends StatelessWidget {
  final PremiumFeature feature;
  final String? customMessage;
  final VoidCallback? onUpgradePressed;

  const PremiumUpgradeCompact({
    super.key,
    required this.feature,
    this.customMessage,
    this.onUpgradePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.lock, color: Colors.amber.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  customMessage ?? 'This feature requires premium',
                  style: TextStyle(
                    color: Colors.amber.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onUpgradePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text('Upgrade to Premium'),
            ),
          ),
        ],
      ),
    );
  }
}
