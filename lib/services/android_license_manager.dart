import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'license_manager.dart';
import '../models/license_data.dart';

/// Android-specific license manager using Google Play Billing
class AndroidLicenseManager extends LicenseManager {
  static const String _premiumProductId = 'simple_vault_premium';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;
  final Completer<bool> _restoreCompleter = Completer<bool>();
  bool _isRestoring = false;

  AndroidLicenseManager() : super() {
    _initializePurchaseStream();
  }

  /// Initializes the purchase stream to listen for purchase updates
  void _initializePurchaseStream() {
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        if (_isRestoring && !_restoreCompleter.isCompleted) {
          _restoreCompleter.complete(false);
          _isRestoring = false;
        }
      },
    );
  }

  @override
  Future<bool> validatePurchase(String purchaseToken) async {
    try {
      // Check if the service is available
      final isAvailable = await _inAppPurchase.isAvailable();
      if (!isAvailable) return false;

      // For validation, we'll restore purchases and check in the stream
      return await restorePurchases();
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> restorePurchases() async {
    try {
      final isAvailable = await _inAppPurchase.isAvailable();
      if (!isAvailable) return false;

      // Set up restore state
      _isRestoring = true;
      final completer = Completer<bool>();

      // Start restore process
      await _inAppPurchase.restorePurchases();

      // Wait for purchases to be processed or timeout after 10 seconds
      Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          completer.complete(false);
          _isRestoring = false;
        }
      });

      return await completer.future;
    } catch (e) {
      _isRestoring = false;
      return false;
    }
  }

  /// Initiates a premium purchase
  Future<bool> purchasePremium() async {
    try {
      final isAvailable = await _inAppPurchase.isAvailable();
      if (!isAvailable) return false;

      // Query product details
      final response = await _inAppPurchase.queryProductDetails({
        _premiumProductId,
      });
      if (response.error != null || response.productDetails.isEmpty) {
        return false;
      }

      final productDetails = response.productDetails.first;
      final purchaseParam = PurchaseParam(productDetails: productDetails);

      return await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
    } catch (e) {
      return false;
    }
  }

  /// Handles purchase stream updates
  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    bool foundPremium = false;

    for (final purchase in purchases) {
      if (purchase.productID == _premiumProductId) {
        _processPurchase(purchase);

        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          foundPremium = true;
        }
      }
    }

    // Complete restore operation if in progress
    if (_isRestoring && !_restoreCompleter.isCompleted) {
      _restoreCompleter.complete(foundPremium);
      _isRestoring = false;
    }
  }

  /// Processes a purchase update
  Future<void> _processPurchase(PurchaseDetails purchase) async {
    switch (purchase.status) {
      case PurchaseStatus.purchased:
        await _storePurchaseAsLicense(purchase);
        break;
      case PurchaseStatus.error:
        // Handle purchase error
        break;
      case PurchaseStatus.pending:
        // Handle pending purchase
        break;
      case PurchaseStatus.canceled:
        // Handle canceled purchase
        break;
      case PurchaseStatus.restored:
        await _storePurchaseAsLicense(purchase);
        break;
    }

    // Complete the purchase
    if (purchase.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchase);
    }
  }

  /// Stores a purchase as license data
  Future<void> _storePurchaseAsLicense(PurchaseDetails purchase) async {
    final licenseData = LicenseData(
      licenseKey: purchase.purchaseID ?? '',
      purchaseDate: DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(purchase.transactionDate ?? '0') ?? 0,
      ),
      expirationDate: null, // Lifetime license
      type: LicenseType.lifetime,
      platformPurchaseId: purchase.purchaseID ?? '',
      lastValidated: DateTime.now(),
      platformSpecificData: {
        'productId': purchase.productID,
        'purchaseToken': _extractPurchaseToken(purchase),
        'orderId': _extractOrderId(purchase),
      },
    );

    // Call the protected method from base class
    await storeLicenseData(licenseData);
  }

  /// Extracts purchase token from Android purchase details
  String _extractPurchaseToken(PurchaseDetails purchase) {
    if (purchase is GooglePlayPurchaseDetails) {
      return purchase.billingClientPurchase.purchaseToken;
    }
    return purchase.purchaseID ?? '';
  }

  /// Extracts order ID from Android purchase details
  String _extractOrderId(PurchaseDetails purchase) {
    if (purchase is GooglePlayPurchaseDetails) {
      return purchase.billingClientPurchase.orderId;
    }
    return '';
  }

  @override
  void dispose() {
    _purchaseSubscription.cancel();
    super.dispose();
  }
}
