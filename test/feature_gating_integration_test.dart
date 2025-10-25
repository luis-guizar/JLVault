import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_vault/models/premium_feature.dart';
import 'package:simple_vault/models/license_status.dart';
import 'package:simple_vault/services/feature_gate.dart';
import 'package:simple_vault/services/license_manager.dart';
import 'package:simple_vault/widgets/feature_gate_wrapper.dart';
import 'package:simple_vault/widgets/upgrade_prompt_dialog.dart';

// Mock implementations for testing
class MockLicenseManager extends LicenseManager {
  LicenseStatus _status = LicenseStatus.free;

  void setStatus(LicenseStatus status) {
    _status = status;
  }

  @override
  Future<LicenseStatus> getCurrentStatus() async => _status;

  @override
  Future<bool> validatePurchase(String purchaseToken) async => true;

  @override
  Future<bool> restorePurchases() async => true;
}

class MockFeatureGate extends FeatureGate {
  MockFeatureGate(super.licenseManager);

  @override
  Future<bool> initiatePurchase() async => true;
}

void main() {
  group('Feature Gating Integration Tests', () {
    late MockLicenseManager mockLicenseManager;
    late MockFeatureGate mockFeatureGate;

    setUp(() {
      mockLicenseManager = MockLicenseManager();
      mockFeatureGate = MockFeatureGate(mockLicenseManager);
    });

    testWidgets('Free user sees upgrade prompt for premium features', (
      tester,
    ) async {
      mockLicenseManager.setStatus(LicenseStatus.free);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeatureGateWrapper(
              feature: PremiumFeature.multipleVaults,
              featureGate: mockFeatureGate,
              child: const Text('Premium Content'),
            ),
          ),
        ),
      );

      // Should show upgrade prompt instead of content
      expect(find.text('Premium Content'), findsNothing);
      expect(find.text('Multiple Vaults'), findsOneWidget);
      expect(find.text('Upgrade'), findsOneWidget);
    });

    testWidgets('Premium user sees content without upgrade prompt', (
      tester,
    ) async {
      mockLicenseManager.setStatus(LicenseStatus.premium);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeatureGateWrapper(
              feature: PremiumFeature.multipleVaults,
              featureGate: mockFeatureGate,
              child: const Text('Premium Content'),
            ),
          ),
        ),
      );

      // Should show content without upgrade prompt
      expect(find.text('Premium Content'), findsOneWidget);
      expect(find.text('Upgrade'), findsNothing);
    });

    testWidgets('Trial user has access to premium features', (tester) async {
      mockLicenseManager.setStatus(LicenseStatus.trial);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeatureGateWrapper(
              feature: PremiumFeature.totpGenerator,
              featureGate: mockFeatureGate,
              child: const Text('TOTP Content'),
            ),
          ),
        ),
      );

      // Should show content for trial users
      expect(find.text('TOTP Content'), findsOneWidget);
      expect(find.text('Upgrade'), findsNothing);
    });

    testWidgets('Password limit indicator shows correct status', (
      tester,
    ) async {
      mockLicenseManager.setStatus(LicenseStatus.free);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PasswordLimitIndicator(
              featureGate: mockFeatureGate,
              currentCount: 45,
              showUpgradeButton: true,
            ),
          ),
        ),
      );

      // Should show password count and limit
      expect(find.text('45/50 passwords'), findsOneWidget);
    });

    testWidgets('Password limit shows upgrade when near limit', (tester) async {
      mockLicenseManager.setStatus(LicenseStatus.free);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PasswordLimitIndicator(
              featureGate: mockFeatureGate,
              currentCount: 48,
              showUpgradeButton: true,
            ),
          ),
        ),
      );

      // Should show upgrade button when near limit
      expect(find.text('48/50 passwords'), findsOneWidget);
      expect(find.text('UPGRADE'), findsOneWidget);
    });

    testWidgets('Premium user shows unlimited passwords', (tester) async {
      mockLicenseManager.setStatus(LicenseStatus.premium);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PasswordLimitIndicator(
              featureGate: mockFeatureGate,
              currentCount: 100,
              showUpgradeButton: true,
            ),
          ),
        ),
      );

      // Should show unlimited for premium users
      expect(find.textContaining('Premium: Unlimited'), findsOneWidget);
    });

    group('Feature Access Tests', () {
      test('Free user cannot access premium features', () {
        mockLicenseManager.setStatus(LicenseStatus.free);

        expect(mockFeatureGate.canAccess(PremiumFeature.multipleVaults), false);
        expect(mockFeatureGate.canAccess(PremiumFeature.totpGenerator), false);
        expect(mockFeatureGate.canAccess(PremiumFeature.securityHealth), false);
        expect(mockFeatureGate.canAccess(PremiumFeature.importExport), false);
        expect(mockFeatureGate.canAccess(PremiumFeature.p2pSync), false);
        expect(
          mockFeatureGate.canAccess(PremiumFeature.unlimitedPasswords),
          false,
        );
      });

      test('Premium user can access all features', () {
        mockLicenseManager.setStatus(LicenseStatus.premium);

        expect(mockFeatureGate.canAccess(PremiumFeature.multipleVaults), true);
        expect(mockFeatureGate.canAccess(PremiumFeature.totpGenerator), true);
        expect(mockFeatureGate.canAccess(PremiumFeature.securityHealth), true);
        expect(mockFeatureGate.canAccess(PremiumFeature.importExport), true);
        expect(mockFeatureGate.canAccess(PremiumFeature.p2pSync), true);
        expect(
          mockFeatureGate.canAccess(PremiumFeature.unlimitedPasswords),
          true,
        );
      });

      test('Trial user can access all features', () {
        mockLicenseManager.setStatus(LicenseStatus.trial);

        expect(mockFeatureGate.canAccess(PremiumFeature.multipleVaults), true);
        expect(mockFeatureGate.canAccess(PremiumFeature.totpGenerator), true);
        expect(mockFeatureGate.canAccess(PremiumFeature.securityHealth), true);
        expect(mockFeatureGate.canAccess(PremiumFeature.importExport), true);
        expect(mockFeatureGate.canAccess(PremiumFeature.p2pSync), true);
        expect(
          mockFeatureGate.canAccess(PremiumFeature.unlimitedPasswords),
          true,
        );
      });

      test('Expired user cannot access premium features', () {
        mockLicenseManager.setStatus(LicenseStatus.expired);

        expect(mockFeatureGate.canAccess(PremiumFeature.multipleVaults), false);
        expect(mockFeatureGate.canAccess(PremiumFeature.totpGenerator), false);
        expect(mockFeatureGate.canAccess(PremiumFeature.securityHealth), false);
        expect(mockFeatureGate.canAccess(PremiumFeature.importExport), false);
        expect(mockFeatureGate.canAccess(PremiumFeature.p2pSync), false);
        expect(
          mockFeatureGate.canAccess(PremiumFeature.unlimitedPasswords),
          false,
        );
      });
    });

    group('Upgrade Prompt Tests', () {
      testWidgets('Upgrade prompt shows correct feature information', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: UpgradePromptDialog(
              feature: PremiumFeature.multipleVaults,
              featureGate: mockFeatureGate,
            ),
          ),
        );

        // Should show feature-specific information
        expect(find.text('Multiple Vaults'), findsOneWidget);
        expect(
          find.textContaining('Organize passwords into separate vaults'),
          findsOneWidget,
        );
      });

      testWidgets('Upgrade prompt shows purchase button', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: UpgradePromptDialog(
              feature: PremiumFeature.totpGenerator,
              featureGate: mockFeatureGate,
            ),
          ),
        );

        // Should show purchase options
        expect(find.textContaining('Upgrade'), findsAtLeastNWidgets(1));
        expect(find.textContaining('Restore'), findsOneWidget);
      });
    });
  });
}
