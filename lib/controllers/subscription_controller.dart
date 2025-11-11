import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../models/subscription_models.dart';
import '../services/payment_service.dart';
import '../services/firebase_subscription_service.dart';
import '../services/firebase_service.dart';
import '../core/utils/snackbar_utils.dart';

class SubscriptionController extends GetxController {
  // Observable variables
  final RxBool isLoading = false.obs;
  final RxBool isInitializing = true.obs;
  final RxBool isPurchasing = false.obs;
  final RxBool isRestoring = false.obs;
  final Rx<UserSubscription> currentSubscription = UserSubscription.free().obs;
  final RxList<SubscriptionPlan> availablePlans = <SubscriptionPlan>[].obs;
  final Rx<SubscriptionPlan?> selectedPlan = Rx<SubscriptionPlan?>(null);

  // Service instances
  late PaymentService _paymentService;
  final FirebaseSubscriptionService _firebaseService = Get.find<FirebaseSubscriptionService>();
  final FirebaseService _firebaseCore = FirebaseService();

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  StreamSubscription<UserSubscription>? _subscriptionStreamSubscription;

  // Current user ID
  String? _currentUserId;

  // Platform detection
  bool get isIOS => Platform.isIOS;
  bool get isAndroid => Platform.isAndroid;
  String get platformName => isIOS ? 'iOS' : 'Android';

  @override
  void onInit() {
    super.onInit();
    _initializeServices();
  }

  @override
  void onReady() {
    super.onReady();
    _initializeUserAndLoadData();
  }

  @override
  void onClose() {
    _purchaseSubscription?.cancel();
    _subscriptionStreamSubscription?.cancel();
    _paymentService.dispose();
    super.onClose();
  }

  /// Initialize all services
  Future<void> _initializeServices() async {
    try {
      isInitializing.value = true;

      // Initialize Firebase services
      await _firebaseCore.ensureInitialized();

      // Initialize payment service
      _paymentService = PaymentServiceFactory.getPaymentService();
      await _paymentService.initialize();

      // Check if payment service is available
      final isAvailable = await _paymentService.isAvailable();
      if (!isAvailable) {
      }

      // Set up purchase stream listener
      _setupPurchaseListener();


    } catch (e) {
      // SnackbarUtils.showError(
      //   'Initialization Error',
      //   'Failed to initialize subscription services',
      // );
    } finally {
      isInitializing.value = false;
    }
  }

  /// Initialize user and load subscription data
  Future<void> _initializeUserAndLoadData() async {
    try {
      // Get current user
      final user = await _firebaseCore.getCurrentUser();
      if (user != null) {
        _currentUserId = user.uid;

        // Start listening to subscription changes
        _startSubscriptionListener();

        // Load initial subscription data
        await loadSubscriptionData();
      } else {
        // Set default free subscription for non-authenticated users
        currentSubscription.value = UserSubscription.free();
      }
    } catch (e) {
      currentSubscription.value = UserSubscription.free();
    }
  }

  /// Start listening to Firebase subscription changes
  void _startSubscriptionListener() {
    if (_currentUserId == null) return;

    _subscriptionStreamSubscription?.cancel();

    _subscriptionStreamSubscription = _firebaseService
        .subscriptionStream(_currentUserId!)
        .listen(
      (subscription) {
        currentSubscription.value = subscription;
      },
      onError: (error) {
      },
    );
  }

  /// Load subscription data including current subscription and available plans
  Future<void> loadSubscriptionData() async {
    try {
      isLoading.value = true;

      // Load current subscription from Firebase
      await loadCurrentSubscription();

      // Load available plans from the store
      await loadAvailablePlans();

    } catch (e) {
      // SnackbarUtils.showError(
      //   'Loading Error',
      //   'Failed to load subscription data',
      // );
    } finally {
      isLoading.value = false;
    }
  }

  /// Load the user's current subscription status from Firebase
  Future<void> loadCurrentSubscription() async {
    try {
      if (_currentUserId == null) {
        currentSubscription.value = UserSubscription.free();
        return;
      }

      // Load from Firebase
      final subscription = await _firebaseService.getSubscription(_currentUserId!);
      currentSubscription.value = subscription;


    } catch (e) {
      debugPrint('❌ Failed to load subscription: $e');
      // Default to free plan if loading fails
      currentSubscription.value = UserSubscription.free();
    }
  }

  /// Load available subscription plans from the store
  Future<void> loadAvailablePlans() async {
    try {
      final plans = await _paymentService.getAvailableProducts();
      availablePlans.value = plans;
    } catch (e) {
      // Fallback to static plans if store loading fails
      availablePlans.value = SubscriptionPlan.getAllPlans();
    }
  }

  /// Set up purchase stream listener
  void _setupPurchaseListener() {
    Stream<List<PurchaseDetails>>? purchaseStream;

    // Get purchase stream based on platform
    if (_paymentService is IOSPaymentService) {
      purchaseStream = (_paymentService as IOSPaymentService).purchaseStream;
    } else if (_paymentService is AndroidPaymentService) {
      purchaseStream = (_paymentService as AndroidPaymentService).purchaseStream;
    }

    if (purchaseStream != null) {
      _purchaseSubscription = purchaseStream.listen(
        _handlePurchaseUpdate,
        onError: (error) {
          debugPrint('Purchase stream error: $error');
          _handlePurchaseError(error);
        },
      );
    }
  }

  /// Handle purchase updates from the stream
  void _handlePurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      await _processPurchase(purchase);
    }
  }

  /// Process individual purchase
  Future<void> _processPurchase(PurchaseDetails purchase) async {
    try {
      if (purchase.status == PurchaseStatus.pending) {
        // Purchase is pending, show loading state
        debugPrint('Purchase pending: ${purchase.productID}');

      } else if (purchase.status == PurchaseStatus.purchased) {
        // Purchase successful
        debugPrint('Purchase successful: ${purchase.productID}');

        // Find the purchased plan
        final purchasedPlan = SubscriptionPlan.getAllPlans()
            .cast<SubscriptionPlan?>()
            .firstWhere(
              (plan) => plan?.appleProductId == purchase.productID ||
                        plan?.googlePlayProductId == purchase.productID,
              orElse: () => null,
            );

        if (purchasedPlan != null) {
          // Save subscription to Firebase
          await _saveSubscriptionToFirebase(purchase, purchasedPlan);

          // Show success message
          SnackbarUtils.showSuccess(
            'Purchase Successful!',
            'Welcome to ${purchasedPlan.name}! Your premium features are now active.',
          );

          // Navigate back if we're in the subscription screen
          if (Get.currentRoute.contains('subscription')) {
            Get.back();
          }
        }

        // Complete the purchase (required for both platforms)
        await InAppPurchase.instance.completePurchase(purchase);

      } else if (purchase.status == PurchaseStatus.error) {
        // Purchase failed
        debugPrint('Purchase failed: ${purchase.error?.message}');

        // SnackbarUtils.showError(
        //   'Purchase Failed',
        //   purchase.error?.message ?? 'Purchase failed. Please try again.',
        // );

      } else if (purchase.status == PurchaseStatus.canceled) {
        // Purchase cancelled
        debugPrint('Purchase cancelled: ${purchase.productID}');

        SnackbarUtils.showInfo(
          'Purchase Cancelled',
          'No worries! You can upgrade anytime.',
        );
      }

      // Update UI state
      isPurchasing.value = false;
      selectedPlan.value = null;

    } catch (e) {
      debugPrint('Error processing purchase: $e');
      // SnackbarUtils.showError(
      //   'Purchase Error',
      //   'Failed to process purchase: ${e.toString()}',
      // );

      isPurchasing.value = false;
      selectedPlan.value = null;
    }
  }

  /// Handle purchase stream errors
  void _handlePurchaseError(dynamic error) {
    debugPrint('Purchase stream error: $error');
    // SnackbarUtils.showError(
    //   'Payment Error',
    //   'Payment service encountered an error. Please try again.',
    // );

    isPurchasing.value = false;
    selectedPlan.value = null;
  }

  /// Purchase a subscription plan
  Future<void> purchaseSubscription(SubscriptionPlan plan) async {
    try {
      // Show loading state
      isPurchasing.value = true;
      selectedPlan.value = plan;

      // Haptic feedback for purchase action
      HapticFeedback.mediumImpact();

      // Show confirmation dialog for premium plans
      if (plan.type != SubscriptionPlanType.free) {
        final confirmed = await _showPurchaseConfirmation(plan);
        if (!confirmed) {
          isPurchasing.value = false;
          selectedPlan.value = null;
          return;
        }
      }

      // Process the purchase (result will come through the stream)
      final result = await _paymentService.purchaseSubscription(plan);

      if (result.result == PaymentResult.pending) {
        // Purchase initiated successfully, waiting for stream update
        debugPrint('Purchase initiated, waiting for completion...');

      } else if (result.result == PaymentResult.failed) {
        // Immediate failure
        final errorMessage = result.error?.message ?? 'Failed to start purchase process.';
        // SnackbarUtils.showError('Purchase Failed', errorMessage);

        isPurchasing.value = false;
        selectedPlan.value = null;
      }

    } catch (e) {
      // SnackbarUtils.showError(
      //   'Purchase Error',
      //   'An unexpected error occurred: ${e.toString()}',
      // );

      isPurchasing.value = false;
      selectedPlan.value = null;
    }
  }

  /// Restore previous purchases (mainly for iOS)
  Future<void> restorePurchases() async {
    try {
      isRestoring.value = true;
      HapticFeedback.lightImpact();

      final results = await _paymentService.restorePurchases();

      if (results.isNotEmpty) {
        await loadCurrentSubscription();
        SnackbarUtils.showSuccess(
          'Purchases Restored',
          'Your previous purchases have been restored successfully.',
        );
      } else {
        SnackbarUtils.showInfo(
          'No Purchases Found',
          'No previous purchases were found to restore.',
        );
      }

    } catch (e) {
      // SnackbarUtils.showError(
      //   'Restore Failed',
      //   'Failed to restore purchases: ${e.toString()}',
      // );
    } finally {
      isRestoring.value = false;
    }
  }

  /// Cancel subscription (redirect to platform settings)
  Future<void> cancelSubscription() async {
    try {
      final confirmed = await _showCancellationConfirmation();
      if (!confirmed) return;

      await _paymentService.cancelSubscription();

      SnackbarUtils.showInfo(
        'Subscription Management',
        'You\'ve been redirected to manage your subscription in your $platformName settings.',
      );

    } catch (e) {
      // SnackbarUtils.showError(
      //   'Error',
      //   'Failed to open subscription management: ${e.toString()}',
      // );
    }
  }

  /// Show purchase confirmation dialog
  Future<bool> _showPurchaseConfirmation(SubscriptionPlan plan) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Text(plan.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Upgrade to ${plan.name}?',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'re about to purchase:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  if (plan.price != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          plan.price!,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue,
                          ),
                        ),
                        if (plan.billingPeriod != null) ...[
                          Text(
                            plan.billingPeriod!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your subscription will be processed through ${platformName == 'iOS' ? 'Apple App Store' : 'Google Play Store'}.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Purchase'),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    return result ?? false;
  }

  /// Show subscription cancellation confirmation
  Future<bool> _showCancellationConfirmation() async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Manage Subscription',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Text(
          'You\'ll be redirected to your $platformName settings where you can manage or cancel your subscription.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              'Stay Here',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Refresh subscription data
  Future<void> refreshData() async {
    await loadSubscriptionData();
  }

  /// Check if a plan is currently active
  bool isPlanActive(SubscriptionPlanType planType) {
    return currentSubscription.value.currentPlan == planType &&
           currentSubscription.value.isActive;
  }

  /// Check if user has premium access
  /// TODO: REMOVE THIS OVERRIDE AFTER TESTING - ALWAYS RETURNS TRUE FOR TESTING
  bool get hasPremiumAccess => true; // Temporarily always true for testing
  // bool get hasPremiumAccess => currentSubscription.value.isPremium; // Original code

  /// Save successful purchase to Firebase
  Future<void> _saveSubscriptionToFirebase(PurchaseDetails purchase, SubscriptionPlan plan) async {
    try {
      if (_currentUserId == null) {
        debugPrint('⚠️ Cannot save subscription: No authenticated user');
        return;
      }

      // Calculate subscription dates
      final now = DateTime.now();
      final expiryDate = now.add(const Duration(days: 30)); // Monthly subscription

      // Create subscription with features based on plan
      final subscription = _createSubscriptionFromPlan(
        plan: plan,
        purchaseDate: now,
        expiryDate: expiryDate,
        transactionId: purchase.purchaseID ?? purchase.verificationData.localVerificationData,
        originalTransactionId: Platform.isIOS ? purchase.purchaseID : null,
        purchaseToken: Platform.isAndroid ? purchase.purchaseID : null,
      );

      // Save to Firebase
      await _firebaseService.saveSubscription(
        userId: _currentUserId!,
        subscription: subscription,
        transactionId: purchase.purchaseID ?? '',
        platform: Platform.isIOS ? 'ios' : 'android',
        additionalData: {
          'productId': purchase.productID,
          'verificationData': purchase.verificationData.localVerificationData,
        },
      );

      debugPrint('✅ Subscription saved to Firebase successfully');

    } catch (e) {
      debugPrint('❌ Failed to save subscription to Firebase: $e');
      // Don't throw - the purchase was successful, Firebase sync can be retried
    }
  }

  /// Create UserSubscription from SubscriptionPlan with features
  UserSubscription _createSubscriptionFromPlan({
    required SubscriptionPlan plan,
    required DateTime purchaseDate,
    required DateTime expiryDate,
    required String transactionId,
    String? originalTransactionId,
    String? purchaseToken,
  }) {
    // Define features based on plan type
    Map<String, dynamic> features;

    switch (plan.type) {
      case SubscriptionPlanType.free:
        features = {
          'hasGlobalAccess': false,
          'maxRaces': 3,
          'maxCreateRaces': 2,
          'hasLeaderboards': false,
          'hasHallOfFame': false,
          'hasAdvancedStats': false,
          'hasHeartRateZones': false,
          'hasMarathons': false,
          'hasGroupChat': false,
        };
        break;

      case SubscriptionPlanType.premium1:
        features = {
          'hasGlobalAccess': false,
          'maxRaces': 7,
          'maxCreateRaces': 7,
          'hasLeaderboards': true,
          'hasHallOfFame': false,
          'hasAdvancedStats': true,
          'hasHeartRateZones': true,
          'hasMarathons': true,
          'hasGroupChat': false,
        };
        break;

      case SubscriptionPlanType.premium2:
        features = {
          'hasGlobalAccess': true,
          'maxRaces': 20,
          'maxCreateRaces': 20,
          'hasLeaderboards': true,
          'hasHallOfFame': true,
          'hasAdvancedStats': true,
          'hasHeartRateZones': true,
          'hasMarathons': true,
          'hasGroupChat': true,
        };
        break;

      case SubscriptionPlanType.lifetime:
        // Lifetime has all Premium 2 features + unlimited
        features = {
          'hasGlobalAccess': true,
          'maxRaces': 999,
          'maxCreateRaces': 999,
          'hasLeaderboards': true,
          'hasHallOfFame': true,
          'hasAdvancedStats': true,
          'hasHeartRateZones': true,
          'hasMarathons': true,
          'hasGroupChat': true,
        };
        break;
    }

    return UserSubscription(
      currentPlan: plan.type,
      status: SubscriptionStatus.active,
      purchaseDate: purchaseDate,
      expiryDate: expiryDate,
      transactionId: transactionId,
      originalTransactionId: originalTransactionId,
      purchaseToken: purchaseToken,
      platform: Platform.isIOS ? 'ios' : 'android',
      autoRenew: true,
      lastValidated: DateTime.now(),
      features: features,
    );
  }

  /// Feature access methods
  /// TODO: REMOVE THIS OVERRIDE AFTER TESTING - ALWAYS RETURNS TRUE FOR TESTING
  bool hasFeatureAccess(String featureKey) {
    return true; // Temporarily always true for testing
    // return currentSubscription.value.hasFeature(featureKey); // Original code
  }

  T? getFeature<T>(String featureKey) {
    return currentSubscription.value.getFeature<T>(featureKey);
  }

  /// TODO: REMOVE THIS OVERRIDE AFTER TESTING - ALWAYS RETURNS 999 FOR TESTING
  int getFeatureLimit(String featureKey) {
    return 999; // Temporarily unlimited for testing
    // return currentSubscription.value.getFeature<int>(featureKey) ?? 0; // Original code
  }

  /// Check specific features
  bool get hasGlobalAccess => hasFeatureAccess('hasGlobalAccess');
  bool get hasAdvancedStats => hasFeatureAccess('hasAdvancedStats');
  bool get hasLeaderboards => hasFeatureAccess('hasLeaderboards');
  bool get hasHallOfFame => hasFeatureAccess('hasHallOfFame');
  bool get hasHeartRateZones => hasFeatureAccess('hasHeartRateZones');
  bool get hasMarathons => hasFeatureAccess('hasMarathons');
  bool get hasGroupChat => hasFeatureAccess('hasGroupChat');

  int get maxRaces => getFeatureLimit('maxRaces');
  int get maxCreateRaces => getFeatureLimit('maxCreateRaces');

  /// Get the display name for the current subscription
  String get currentPlanDisplayName {
    switch (currentSubscription.value.currentPlan) {
      case SubscriptionPlanType.free:
        return 'Free Plan';
      case SubscriptionPlanType.premium1:
        return 'Premium 1';
      case SubscriptionPlanType.premium2:
        return 'Premium 2';
      case SubscriptionPlanType.lifetime:
        return 'Lifetime Premium';
    }
  }
}