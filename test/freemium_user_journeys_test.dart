import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_vault/models/premium_feature.dart';
import 'package:simple_vault/models/license_status.dart';
import 'package:simple_vault/models/account.dart';
import 'package:simple_vault/services/feature_gate.dart';
import 'package:simple_vault/services/license_manager.dart';
import 'package:simple_vault/widgets/feature_gate_wrapper.dart';
import 'package:simple_vault/widgets/upgrade_prompt_dialog.dart';

// Mock implementations for testing freemium user journeys
class MockLicenseManager extends LicenseManager {
  LicenseStatus _status = LicenseStatus.free;
  bool _purchaseSuccessful = true;
  bool _restoreSuccessful = true;
  int _graceDays = 0;
  int _trialDays = 0;

  void setStatus(LicenseStatus status) {
    _status = status;
  }

  void setPurchaseResult(bool successful) {
    _purchaseSuccessful = successful;
  }

  void setRestoreResult(bool successful) {
    _restoreSuccessful = successful;
  }

  void setGraceDays(int days) {
    _graceDays = days;
  }

  void setTrialDays(int days) {
    _trialDays = days;
  }

  @override
  Future<LicenseStatus> getCurrentStatus() async => _status;

  @override
  Future<bool> validatePurchase(String purchaseToken) async =>
      _purchaseSuccessful;

  @override
  Future<bool> restorePurchases() async {
    if (_restoreSuccessful) {
      _status = LicenseStatus.premium;
    }
    return _restoreSuccessful;
  }

  @override
  int getRemainingGraceDays() => _graceDays;

  @override
  Future<int> getRemainingTrialDays() async => _trialDays;

  @override
  Future<bool> isTrialEligible() async =>
      _status == LicenseStatus.free && _trialDays == 0;

  @override
  Future<bool> startTrial() async {
    if (await isTrialEligible()) {
      _status = LicenseStatus.trial;
      _trialDays = 14;
      return true;
    }
    return false;
  }
}

class MockFeatureGate extends FeatureGate {
  bool _purchaseInitiated = false;
  final MockLicenseManager _mockLicenseManager;

  MockFeatureGate(this._mockLicenseManager) : super(_mockLicenseManager);

  @override
  Future<bool> initiatePurchase() async {
    _purchaseInitiated = true;
    // Simulate successful purchase
    if (_mockLicenseManager._purchaseSuccessful) {
      _mockLicenseManager.setStatus(LicenseStatus.premium);
      return true;
    }
    return false;
  }

  bool get purchaseInitiated => _purchaseInitiated;
}

void main() {
  group('Freemium User Journeys Tests', () {
    late MockLicenseManager mockLicenseManager;
    late MockFeatureGate mockFeatureGate;

    setUp(() {
      mockLicenseManager = MockLicenseManager();
      mockFeatureGate = MockFeatureGate(mockLicenseManager);
    });

    group('Free User Onboarding and Limits', () {
      testWidgets('Free user can access basic features', (tester) async {
        mockLicenseManager.setStatus(LicenseStatus.free);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  // Basic features should be accessible
                  const Text('Home Screen'),
                  const Text('Settings'),
                  // Premium features should show upgrade prompts
                  FeatureGateWrapper(
                    feature: PremiumFeature.multipleVaults,
                    featureGate: mockFeatureGate,
                    child: const Text('Multiple Vaults Content'),
                  ),
                ],
              ),
            ),
          ),
        );

        // Basic content should be visible
        expect(find.text('Home Screen'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);

        // Premium content should be gated
        expect(find.text('Multiple Vaults Content'), findsNothing);
        expect(find.text('Multiple Vaults'), findsOneWidget);
        expect(find.text('Upgrade'), findsOneWidget);
      });

      test('Free user has 50 password limit', () {
        mockLicenseManager.setStatus(LicenseStatus.free);

        // Free users should not have unlimited passwords
        expect(
          mockFeatureGate.canAccess(PremiumFeature.unlimitedPasswords),
          false,
        );
      });

      testWidgets(
        'Password limit indicator shows correct count for free user',
        (tester) async {
          mockLicenseManager.setStatus(LicenseStatus.free);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: PasswordLimitIndicator(
                  featureGate: mockFeatureGate,
                  currentCount: 25,
                  showUpgradeButton: true,
                ),
              ),
            ),
          );

          // Should show password count with limit
          expect(find.text('25/50 passwords'), findsOneWidget);
        },
      );

      testWidgets('Password limit shows warning when approaching limit', (
        tester,
      ) async {
        mockLicenseManager.setStatus(LicenseStatus.free);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PasswordLimitIndicator(
                featureGate: mockFeatureGate,
                currentCount: 47,
                showUpgradeButton: true,
              ),
            ),
          ),
        );

        // Should show upgrade button when near limit
        expect(find.text('47/50 passwords'), findsOneWidget);
        expect(find.text('UPGRADE'), findsOneWidget);
      });

      test('Free user is eligible for trial', () async {
        mockLicenseManager.setStatus(LicenseStatus.free);
        mockLicenseManager.setTrialDays(0);

        expect(await mockFeatureGate.isTrialEligible(), true);
      });

      test('Free user can start trial', () async {
        mockLicenseManager.setStatus(LicenseStatus.free);
        mockLicenseManager.setTrialDays(0);

        final trialStarted = await mockFeatureGate.startTrial();
        expect(trialStarted, true);

        final status = await mockFeatureGate.getLicenseStatus();
        expect(status, LicenseStatus.trial);
      });
    });

    group('Premium Purchase Flow', () {
      testWidgets('Upgrade prompt shows purchase options', (tester) async {
        mockLicenseManager.setStatus(LicenseStatus.free);

        await tester.pumpWidget(
          MaterialApp(
            home: UpgradePromptDialog(
              feature: PremiumFeature.multipleVaults,
              featureGate: mockFeatureGate,
            ),
          ),
        );

        // Should show upgrade options
        expect(find.textContaining('Multiple Vaults'), findsAtLeastNWidgets(1));
        expect(find.textContaining('Upgrade'), findsAtLeastNWidgets(1));
        expect(find.textContaining('Restore'), findsOneWidget);
      });

      test('Successful purchase upgrades user to premium', () async {
        mockLicenseManager.setStatus(LicenseStatus.free);
        mockLicenseManager.setPurchaseResult(true);

        final purchaseResult = await mockFeatureGate.initiatePurchase();
        expect(purchaseResult, true);

        final status = await mockFeatureGate.getLicenseStatus();
        expect(status, LicenseStatus.premium);

        // Should now have access to all premium features
        expect(mockFeatureGate.canAccess(PremiumFeature.multipleVaults), true);
        expect(mockFeatureGate.canAccess(PremiumFeature.totpGenerator), true);
        expect(
          mockFeatureGate.canAccess(PremiumFeature.unlimitedPasswords),
          true,
        );
      });

      test('Failed purchase keeps user as free', () async {
        mockLicenseManager.setStatus(LicenseStatus.free);
        mockLicenseManager.setPurchaseResult(false);

        final purchaseResult = await mockFeatureGate.initiatePurchase();
        expect(purchaseResult, false);

        final status = await mockFeatureGate.getLicenseStatus();
        expect(status, LicenseStatus.free);

        // Should still not have access to premium features
        expect(mockFeatureGate.canAccess(PremiumFeature.multipleVaults), false);
      });

      testWidgets('Premium user sees unlimited password indicator', (
        tester,
      ) async {
        mockLicenseManager.setStatus(LicenseStatus.premium);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PasswordLimitIndicator(
                featureGate: mockFeatureGate,
                currentCount: 150,
                showUpgradeButton: true,
              ),
            ),
          ),
        );

        // Should show unlimited for premium users
        expect(find.textContaining('Premium: Unlimited'), findsOneWidget);
      });
    });

    group('License Restoration', () {
      test('Successful restore upgrades user to premium', () async {
        mockLicenseManager.setStatus(LicenseStatus.free);
        mockLicenseManager.setRestoreResult(true);

        final restoreResult = await mockFeatureGate.restorePurchases();
        expect(restoreResult, true);

        final status = await mockFeatureGate.getLicenseStatus();
        expect(status, LicenseStatus.premium);
      });

      test('Failed restore keeps user as free', () async {
        mockLicenseManager.setStatus(LicenseStatus.free);
        mockLicenseManager.setRestoreResult(false);

        final restoreResult = await mockFeatureGate.restorePurchases();
        expect(restoreResult, false);

        final status = await mockFeatureGate.getLicenseStatus();
        expect(status, LicenseStatus.free);
      });

      test('Restore works after app reinstall simulation', () async {
        // Simulate app reinstall - user starts as free but has previous purchase
        mockLicenseManager.setStatus(LicenseStatus.free);
        mockLicenseManager.setRestoreResult(true);

        // User tries to restore purchases
        final restoreResult = await mockFeatureGate.restorePurchases();
        expect(restoreResult, true);

        // Should be upgraded to premium
        final status = await mockFeatureGate.getLicenseStatus();
        expect(status, LicenseStatus.premium);

        // Should have access to all features
        expect(mockFeatureGate.canAccess(PremiumFeature.multipleVaults), true);
        expect(mockFeatureGate.canAccess(PremiumFeature.totpGenerator), true);
      });
    });

    group('License Validation Failures and Grace Period', () {
      test('Validation failure with grace period maintains access', () {
        mockLicenseManager.setStatus(LicenseStatus.validationFailed);
        mockLicenseManager.setGraceDays(5);

        // Should still have access during grace period
        expect(mockFeatureGate.canAccess(PremiumFeature.multipleVaults), true);
        expect(mockFeatureGate.canAccess(PremiumFeature.totpGenerator), true);
      });

      test('Validation failure without grace period removes access', () {
        mockLicenseManager.setStatus(LicenseStatus.validationFailed);
        mockLicenseManager.setGraceDays(0);

        // Should not have access when grace period expired
        expect(mockFeatureGate.canAccess(PremiumFeature.multipleVaults), false);
        expect(mockFeatureGate.canAccess(PremiumFeature.totpGenerator), false);
      });

      test('Grace period countdown works correctly', () {
        mockLicenseManager.setStatus(LicenseStatus.validationFailed);

        // Test different grace period scenarios
        mockLicenseManager.setGraceDays(7);
        expect(mockFeatureGate.getRemainingGraceDays(), 7);
        expect(mockFeatureGate.canAccess(PremiumFeature.multipleVaults), true);

        mockLicenseManager.setGraceDays(1);
        expect(mockFeatureGate.getRemainingGraceDays(), 1);
        expect(mockFeatureGate.canAccess(PremiumFeature.multipleVaults), true);

        mockLicenseManager.setGraceDays(0);
        expect(mockFeatureGate.getRemainingGraceDays(), 0);
        expect(mockFeatureGate.canAccess(PremiumFeature.multipleVaults), false);
      });

      testWidgets('Graceful degradation shows appropriate message', (
        tester,
      ) async {
        mockLicenseManager.setStatus(LicenseStatus.validationFailed);
        mockLicenseManager.setGraceDays(3);

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

        // During grace period, content should be accessible
        expect(find.text('Premium Content'), findsOneWidget);
      });

      testWidgets('Expired grace period shows upgrade prompt', (tester) async {
        mockLicenseManager.setStatus(LicenseStatus.validationFailed);
        mockLicenseManager.setGraceDays(0);

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

        // After grace period, should show upgrade prompt
        expect(find.text('Premium Content'), findsNothing);
        expect(find.text('Multiple Vaults'), findsOneWidget);
        expect(find.text('Upgrade'), findsOneWidget);
      });
    });

    group('Trial Period Functionality', () {
      test('Trial user has access to all premium features', () {
        mockLicenseManager.setStatus(LicenseStatus.trial);

        expect(mockFeatureGate.canAccess(PremiumFeature.multipleVaults), true);
        expect(mockFeatureGate.canAccess(PremiumFeature.totpGenerator), true);
        expect(mockFeatureGate.canAccess(PremiumFeature.securityHealth), true);
        expect(
          mockFeatureGate.canAccess(PremiumFeature.unlimitedPasswords),
          true,
        );
      });

      test('Trial expiration removes access', () {
        mockLicenseManager.setStatus(LicenseStatus.expired);

        expect(mockFeatureGate.canAccess(PremiumFeature.multipleVaults), false);
        expect(mockFeatureGate.canAccess(PremiumFeature.totpGenerator), false);
        expect(mockFeatureGate.canAccess(PremiumFeature.securityHealth), false);
        expect(
          mockFeatureGate.canAccess(PremiumFeature.unlimitedPasswords),
          false,
        );
      });

      testWidgets('Trial user sees trial indicator', (tester) async {
        mockLicenseManager.setStatus(LicenseStatus.trial);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PasswordLimitIndicator(
                featureGate: mockFeatureGate,
                currentCount: 75,
                showUpgradeButton: true,
              ),
            ),
          ),
        );

        // Should show trial status
        expect(find.textContaining('Trial: Unlimited'), findsOneWidget);
      });

      test('Trial countdown works correctly', () async {
        mockLicenseManager.setStatus(LicenseStatus.trial);
        mockLicenseManager.setTrialDays(7);

        final remainingDays = await mockFeatureGate.getRemainingTrialDays();
        expect(remainingDays, 7);
      });
    });

    group('Feature Access Consistency', () {
      test('Feature access is consistent across all premium features', () {
        // Test free user
        mockLicenseManager.setStatus(LicenseStatus.free);
        for (final feature in PremiumFeature.values) {
          expect(
            mockFeatureGate.canAccess(feature),
            false,
            reason: 'Free user should not access ${feature.displayName}',
          );
        }

        // Test premium user
        mockLicenseManager.setStatus(LicenseStatus.premium);
        for (final feature in PremiumFeature.values) {
          expect(
            mockFeatureGate.canAccess(feature),
            true,
            reason: 'Premium user should access ${feature.displayName}',
          );
        }

        // Test trial user
        mockLicenseManager.setStatus(LicenseStatus.trial);
        for (final feature in PremiumFeature.values) {
          expect(
            mockFeatureGate.canAccess(feature),
            true,
            reason: 'Trial user should access ${feature.displayName}',
          );
        }
      });

      test('Multiple feature access check works correctly', () {
        mockLicenseManager.setStatus(LicenseStatus.premium);

        final features = [
          PremiumFeature.multipleVaults,
          PremiumFeature.totpGenerator,
          PremiumFeature.securityHealth,
        ];

        final accessMap = mockFeatureGate.canAccessMultiple(features);

        for (final feature in features) {
          expect(accessMap[feature], true);
        }
      });
    });
  });
}
