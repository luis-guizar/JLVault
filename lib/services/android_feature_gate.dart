import 'package:in_app_purchase/in_app_purchase.dart';
import 'feature_gate.dart';

/// Android-specific implementation of FeatureGate
/// Integrates with Google Play Billing for purchase flows
class AndroidFeatureGate extends FeatureGate {
  static const String _premiumProductId = 'simple_vault_premium';

  final InAppPurchase _inAppPurchase;

  AndroidFeatureGate(super.licenseManager, {InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  @override
  Future<bool> initiatePurchase() async {
    try {
      // Check if billing is available
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        return false;
      }

      // Get product details
      const Set<String> productIds = {_premiumProductId};
      final ProductDetailsResponse response = await _inAppPurchase
          .queryProductDetails(productIds);

      if (response.error != null) {
        return false;
      }

      final productDetails = response.productDetails
          .where((product) => product.id == _premiumProductId)
          .firstOrNull;

      if (productDetails == null) {
        return false;
      }

      // Create purchase param
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
      );

      // Initiate purchase
      final bool success = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      return success;
    } catch (e) {
      return false;
    }
  }

  /// Get premium product details for display in upgrade prompts
  Future<ProductDetails?> getPremiumProductDetails() async {
    try {
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) return null;

      const Set<String> productIds = {_premiumProductId};
      final ProductDetailsResponse response = await _inAppPurchase
          .queryProductDetails(productIds);

      if (response.error != null) return null;

      return response.productDetails
          .where((product) => product.id == _premiumProductId)
          .firstOrNull;
    } catch (e) {
      return null;
    }
  }

  /// Get formatted price for the premium product
  Future<String?> getPremiumPrice() async {
    final productDetails = await getPremiumProductDetails();
    return productDetails?.price;
  }
}
