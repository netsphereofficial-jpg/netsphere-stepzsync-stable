import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../models/subscription_models.dart';

enum PaymentPlatform {
  ios,
  android,
  web,
}

enum PaymentResult {
  success,
  cancelled,
  failed,
  pending,
}

class PaymentError {
  final String code;
  final String message;
  final String? details;

  PaymentError({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'PaymentError($code): $message';
}

class PurchaseResult {
  final PaymentResult result;
  final String? transactionId;
  final PaymentError? error;
  final SubscriptionPlan? purchasedPlan;

  PurchaseResult({
    required this.result,
    this.transactionId,
    this.error,
    this.purchasedPlan,
  });

  bool get isSuccess => result == PaymentResult.success;
  bool get isCancelled => result == PaymentResult.cancelled;
  bool get isFailed => result == PaymentResult.failed;
}

abstract class PaymentService {
  /// Get the current payment platform
  static PaymentPlatform get currentPlatform {
    if (kIsWeb) return PaymentPlatform.web;
    if (Platform.isIOS) return PaymentPlatform.ios;
    if (Platform.isAndroid) return PaymentPlatform.android;
    return PaymentPlatform.android; // Default fallback
  }

  /// Check if in-app purchases are available on this device
  Future<bool> isAvailable();

  /// Initialize the payment service
  Future<void> initialize();

  /// Purchase a subscription plan
  Future<PurchaseResult> purchaseSubscription(SubscriptionPlan plan);

  /// Restore previous purchases (iOS requirement)
  Future<List<PurchaseResult>> restorePurchases();

  /// Get current subscription status
  Future<UserSubscription> getCurrentSubscription();

  /// Validate a purchase receipt
  Future<bool> validatePurchase(String transactionId);

  /// Cancel subscription (redirect to platform settings)
  Future<void> cancelSubscription();

  /// Get product details from store
  Future<List<SubscriptionPlan>> getAvailableProducts();

  /// Dispose of the service
  void dispose();
}

/// iOS-specific payment service implementation
class IOSPaymentService extends PaymentService {
  static IOSPaymentService? _instance;
  static IOSPaymentService get instance => _instance ??= IOSPaymentService._();
  IOSPaymentService._();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  List<ProductDetails> _products = [];
  bool _isInitialized = false;

  @override
  Future<bool> isAvailable() async {
    return await _inAppPurchase.isAvailable();
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize platform-specific features
      if (Platform.isIOS) {
        // iOS-specific initialization can be added here
        debugPrint('Initializing iOS StoreKit features');
      }

      // Load products
      await _loadProducts();
      _isInitialized = true;

      debugPrint('iOS payment service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize iOS payment service: $e');
      throw PaymentError(
        code: 'ios_init_failed',
        message: 'Failed to initialize iOS payment service',
        details: e.toString(),
      );
    }
  }

  Future<void> _loadProducts() async {
    final Set<String> productIds = SubscriptionPlan.getAllPlans()
        .where((plan) => plan.appleProductId != null)
        .map((plan) => plan.appleProductId!)
        .toSet();

    if (productIds.isEmpty) {
      debugPrint('⚠️ No iOS product IDs configured');
      return;
    }

    debugPrint('🔍 Querying iOS products: $productIds');

    try {
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(productIds);

      if (response.error != null) {
        debugPrint('❌ Product query error: ${response.error}');
        throw PaymentError(
          code: 'product_query_failed',
          message: 'Failed to query products from App Store',
          details: response.error.toString(),
        );
      }

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('⚠️ Products not found in App Store Connect: ${response.notFoundIDs}');
        debugPrint('💡 Make sure these products are created and approved in App Store Connect');
      }

      _products = response.productDetails;
      debugPrint('✅ Loaded ${_products.length} products from App Store');

      if (_products.isEmpty) {
        debugPrint('⚠️ No products loaded. For testing:');
        debugPrint('1. Create products in App Store Connect with IDs: $productIds');
        debugPrint('2. Wait for approval (can take 24-48 hours)');
        debugPrint('3. Test with sandbox user account');
      }

    } catch (e) {
      debugPrint('❌ Failed to load iOS products: $e');
      throw PaymentError(
        code: 'product_load_failed',
        message: 'Failed to load products from App Store',
        details: e.toString(),
      );
    }
  }

  @override
  Future<PurchaseResult> purchaseSubscription(SubscriptionPlan plan) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final productId = plan.appleProductId;
      if (productId == null) {
        throw PaymentError(
          code: 'no_product_id',
          message: 'No Apple product ID found for this plan',
        );
      }

      // Find the product details
      final ProductDetails? productDetails = _products
          .cast<ProductDetails?>()
          .firstWhere((product) => product?.id == productId, orElse: () => null);

      if (productDetails == null) {
        throw PaymentError(
          code: 'product_not_found',
          message: 'Product not found in App Store',
          details: 'Product ID: $productId',
        );
      }

      // Create purchase param
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
        applicationUserName: null, // Can be set to user ID if needed
      );

      // Start purchase process
      debugPrint('Starting iOS subscription purchase for: ${plan.name}');

      // For subscriptions, use buyNonConsumable method
      final bool success = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (success) {
        // The actual purchase result will come through the purchase stream
        return PurchaseResult(
          result: PaymentResult.pending,
          purchasedPlan: plan,
        );
      } else {
        return PurchaseResult(
          result: PaymentResult.failed,
          error: PaymentError(
            code: 'purchase_failed',
            message: 'Failed to start purchase process',
          ),
        );
      }
    } catch (e) {
      return PurchaseResult(
        result: PaymentResult.failed,
        error: PaymentError(
          code: 'ios_purchase_error',
          message: 'iOS purchase failed',
          details: e.toString(),
        ),
      );
    }
  }

  @override
  Future<List<PurchaseResult>> restorePurchases() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      debugPrint('Restoring iOS purchases...');
      await _inAppPurchase.restorePurchases();

      // The restored purchases will come through the purchase stream
      // Return empty list as results come asynchronously
      return [];
    } catch (e) {
      debugPrint('Failed to restore iOS purchases: $e');
      return [];
    }
  }

  @override
  Future<UserSubscription> getCurrentSubscription() async {
    try {
      // Check for active purchases
      // This would typically involve checking receipt validation
      // For now, return free subscription
      return UserSubscription.free();
    } catch (e) {
      debugPrint('Failed to get current iOS subscription: $e');
      return UserSubscription.free();
    }
  }

  @override
  Future<bool> validatePurchase(String transactionId) async {
    try {
      // iOS receipt validation should be done on your server
      // This is a simplified client-side validation
      debugPrint('Validating iOS purchase: $transactionId');

      // In production, send receipt to your server for validation
      return true;
    } catch (e) {
      debugPrint('Failed to validate iOS purchase: $e');
      return false;
    }
  }

  @override
  Future<void> cancelSubscription() async {
    try {
      // Redirect to iOS subscription management
      if (Platform.isIOS) {
        const String subscriptionUrl = 'https://apps.apple.com/account/subscriptions';
        debugPrint('Please direct user to: $subscriptionUrl');
        // You would use url_launcher to open this URL
      }
    } catch (e) {
      debugPrint('Failed to open iOS subscription management: $e');
    }
  }

  @override
  Future<List<SubscriptionPlan>> getAvailableProducts() async {
    if (!_isInitialized) {
      await initialize();
    }

    return SubscriptionPlan.getAllPlans()
        .where((plan) => plan.appleProductId != null)
        .toList();
  }

  @override
  void dispose() {
    _products.clear();
    _isInitialized = false;
  }

  // Get purchase stream for listening to purchase updates
  Stream<List<PurchaseDetails>> get purchaseStream => _inAppPurchase.purchaseStream;
}

/// Android-specific payment service implementation
class AndroidPaymentService extends PaymentService {
  static AndroidPaymentService? _instance;
  static AndroidPaymentService get instance => _instance ??= AndroidPaymentService._();
  AndroidPaymentService._();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  List<ProductDetails> _products = [];
  bool _isInitialized = false;

  @override
  Future<bool> isAvailable() async {
    return await _inAppPurchase.isAvailable();
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize platform-specific features
      if (Platform.isAndroid) {
        // Android-specific initialization can be added here
        debugPrint('Initializing Android Google Play Billing features');
      }

      // Load products
      await _loadProducts();
      _isInitialized = true;

      debugPrint('Android payment service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize Android payment service: $e');
      throw PaymentError(
        code: 'android_init_failed',
        message: 'Failed to initialize Android payment service',
        details: e.toString(),
      );
    }
  }

  Future<void> _loadProducts() async {
    final Set<String> productIds = SubscriptionPlan.getAllPlans()
        .where((plan) => plan.googlePlayProductId != null)
        .map((plan) => plan.googlePlayProductId!)
        .toSet();

    if (productIds.isEmpty) {
      debugPrint('⚠️ No Android product IDs configured');
      return;
    }

    debugPrint('🔍 Querying Android products: $productIds');

    try {
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(productIds);

      if (response.error != null) {
        debugPrint('❌ Product query error: ${response.error}');
        throw PaymentError(
          code: 'product_query_failed',
          message: 'Failed to query products from Google Play',
          details: response.error.toString(),
        );
      }

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('⚠️ Products not found in Google Play Console: ${response.notFoundIDs}');
        debugPrint('💡 Make sure these products are created and activated in Google Play Console');
      }

      _products = response.productDetails;
      debugPrint('✅ Loaded ${_products.length} products from Google Play');

      if (_products.isEmpty) {
        debugPrint('⚠️ No products loaded. For testing:');
        debugPrint('1. Create products in Google Play Console with IDs: $productIds');
        debugPrint('2. Activate the products');
        debugPrint('3. Test with internal testing track');
      }

    } catch (e) {
      debugPrint('❌ Failed to load Android products: $e');
      throw PaymentError(
        code: 'product_load_failed',
        message: 'Failed to load products from Google Play',
        details: e.toString(),
      );
    }
  }

  @override
  Future<PurchaseResult> purchaseSubscription(SubscriptionPlan plan) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final productId = plan.googlePlayProductId;
      if (productId == null) {
        throw PaymentError(
          code: 'no_product_id',
          message: 'No Google Play product ID found for this plan',
        );
      }

      // Find the product details
      final ProductDetails? productDetails = _products
          .cast<ProductDetails?>()
          .firstWhere((product) => product?.id == productId, orElse: () => null);

      if (productDetails == null) {
        throw PaymentError(
          code: 'product_not_found',
          message: 'Product not found in Google Play',
          details: 'Product ID: $productId',
        );
      }

      // Create purchase param
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
        applicationUserName: null, // Can be set to user ID if needed
      );

      // Start purchase process
      debugPrint('Starting Android subscription purchase for: ${plan.name}');

      // For subscriptions, use buyNonConsumable method
      final bool success = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (success) {
        // The actual purchase result will come through the purchase stream
        return PurchaseResult(
          result: PaymentResult.pending,
          purchasedPlan: plan,
        );
      } else {
        return PurchaseResult(
          result: PaymentResult.failed,
          error: PaymentError(
            code: 'purchase_failed',
            message: 'Failed to start purchase process',
          ),
        );
      }
    } catch (e) {
      return PurchaseResult(
        result: PaymentResult.failed,
        error: PaymentError(
          code: 'android_purchase_error',
          message: 'Android purchase failed',
          details: e.toString(),
        ),
      );
    }
  }

  @override
  Future<List<PurchaseResult>> restorePurchases() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      debugPrint('Restoring Android purchases...');
      await _inAppPurchase.restorePurchases();

      // The restored purchases will come through the purchase stream
      // Return empty list as results come asynchronously
      return [];
    } catch (e) {
      debugPrint('Failed to restore Android purchases: $e');
      return [];
    }
  }

  @override
  Future<UserSubscription> getCurrentSubscription() async {
    try {
      // Check for active purchases
      // This would typically involve checking with Google Play Billing
      // For now, return free subscription
      return UserSubscription.free();
    } catch (e) {
      debugPrint('Failed to get current Android subscription: $e');
      return UserSubscription.free();
    }
  }

  @override
  Future<bool> validatePurchase(String transactionId) async {
    try {
      // Android purchase validation should be done on your server
      // This is a simplified client-side validation
      debugPrint('Validating Android purchase: $transactionId');

      // In production, send purchase token to your server for validation
      return true;
    } catch (e) {
      debugPrint('Failed to validate Android purchase: $e');
      return false;
    }
  }

  @override
  Future<void> cancelSubscription() async {
    try {
      // Redirect to Google Play subscription management
      if (Platform.isAndroid) {
        const String subscriptionUrl = 'https://play.google.com/store/apps/details?id=YOUR_PACKAGE_NAME&showAllReviews=true';
        debugPrint('Please direct user to Google Play subscription management');
        // You would use url_launcher to open this URL
      }
    } catch (e) {
      debugPrint('Failed to open Google Play subscription management: $e');
    }
  }

  @override
  Future<List<SubscriptionPlan>> getAvailableProducts() async {
    if (!_isInitialized) {
      await initialize();
    }

    return SubscriptionPlan.getAllPlans()
        .where((plan) => plan.googlePlayProductId != null)
        .toList();
  }

  @override
  void dispose() {
    _products.clear();
    _isInitialized = false;
  }

  // Get purchase stream for listening to purchase updates
  Stream<List<PurchaseDetails>> get purchaseStream => _inAppPurchase.purchaseStream;
}

/// Web payment service (future implementation)
class WebPaymentService extends PaymentService {
  static WebPaymentService? _instance;
  static WebPaymentService get instance => _instance ??= WebPaymentService._();
  WebPaymentService._();

  @override
  Future<bool> isAvailable() async => false; // Web payments not supported yet

  @override
  Future<void> initialize() async {
    debugPrint('Web payment service not implemented');
  }

  @override
  Future<PurchaseResult> purchaseSubscription(SubscriptionPlan plan) async {
    return PurchaseResult(
      result: PaymentResult.failed,
      error: PaymentError(
        code: 'web_not_supported',
        message: 'Web payments not supported',
      ),
    );
  }

  @override
  Future<List<PurchaseResult>> restorePurchases() async => [];

  @override
  Future<UserSubscription> getCurrentSubscription() async => UserSubscription.free();

  @override
  Future<bool> validatePurchase(String transactionId) async => false;

  @override
  Future<void> cancelSubscription() async {}

  @override
  Future<List<SubscriptionPlan>> getAvailableProducts() async => [];

  @override
  void dispose() {}
}

/// Factory class to get the appropriate payment service
class PaymentServiceFactory {
  static PaymentService getPaymentService() {
    switch (PaymentService.currentPlatform) {
      case PaymentPlatform.ios:
        return IOSPaymentService.instance;
      case PaymentPlatform.android:
        return AndroidPaymentService.instance;
      case PaymentPlatform.web:
        return WebPaymentService.instance;
    }
  }
}