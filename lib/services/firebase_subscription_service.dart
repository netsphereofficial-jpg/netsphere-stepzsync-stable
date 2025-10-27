import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/subscription_models.dart';
import 'firebase_service.dart';

class FirebaseSubscriptionService extends GetxService {
  static FirebaseSubscriptionService get instance => Get.find<FirebaseSubscriptionService>();

  final FirebaseService _firebaseService = FirebaseService();
  StreamSubscription<UserSubscription>? _subscriptionListener;

  // Observable current subscription
  final Rx<UserSubscription> currentSubscription = UserSubscription.free().obs;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _firebaseService.ensureInitialized();
  }

  @override
  void onClose() {
    _subscriptionListener?.cancel();
    super.onClose();
  }

  /// Save subscription data to user_profiles/{userId}/subscription
  Future<void> saveSubscription({
    required String userId,
    required UserSubscription subscription,
    required String transactionId,
    required String platform,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await _firebaseService.ensureInitialized();

      final userProfileRef = _firebaseService.firestore
          .collection('user_profiles')
          .doc(userId);

      final subscriptionData = subscription.toFirebaseMap();
      subscriptionData.addAll({
        'transactionId': transactionId,
        'platform': platform,
        'lastUpdated': FieldValue.serverTimestamp(),
        ...?additionalData,
      });

      // Update subscription in user profile
      await userProfileRef.update({
        'subscription': subscriptionData,
      });

      // Add to subscription history
      await _addToSubscriptionHistory(
        userId: userId,
        action: 'purchased',
        plan: subscription.currentPlan.name,
        transactionId: transactionId,
      );

      debugPrint('✅ Subscription saved to Firebase for user: $userId');

      // Update local observable
      currentSubscription.value = subscription;

    } catch (e) {
      debugPrint('❌ Failed to save subscription to Firebase: $e');
      throw FirebaseSubscriptionException(
        'Failed to save subscription',
        details: e.toString(),
      );
    }
  }

  /// Get subscription data from user_profiles/{userId}
  Future<UserSubscription> getSubscription(String userId) async {
    try {
      await _firebaseService.ensureInitialized();

      final userProfileDoc = await _firebaseService.firestore
          .collection('user_profiles')
          .doc(userId)
          .get();

      if (!userProfileDoc.exists) {
        debugPrint('⚠️ User profile not found, returning free subscription');
        return UserSubscription.free();
      }

      final data = userProfileDoc.data();
      final subscriptionData = data?['subscription'] as Map<String, dynamic>?;

      if (subscriptionData == null) {
        debugPrint('⚠️ No subscription data found, returning free subscription');
        return UserSubscription.free();
      }

      final subscription = UserSubscription.fromFirebaseMap(subscriptionData);

      // Update local observable
      currentSubscription.value = subscription;

      debugPrint('✅ Subscription loaded from Firebase for user: $userId');
      return subscription;

    } catch (e) {
      debugPrint('❌ Failed to get subscription from Firebase: $e');
      return UserSubscription.free();
    }
  }

  /// Listen to subscription changes in real-time
  Stream<UserSubscription> subscriptionStream(String userId) {
    return _firebaseService.firestore
        .collection('user_profiles')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return UserSubscription.free();
      }

      final data = snapshot.data();
      final subscriptionData = data?['subscription'] as Map<String, dynamic>?;

      if (subscriptionData == null) {
        return UserSubscription.free();
      }

      final subscription = UserSubscription.fromFirebaseMap(subscriptionData);

      // Update local observable
      currentSubscription.value = subscription;

      return subscription;
    }).handleError((error) {
      debugPrint('❌ Subscription stream error: $error');
      return UserSubscription.free();
    });
  }

  /// Start listening to subscription changes
  void startSubscriptionListener(String userId) {
    _subscriptionListener?.cancel();

    _subscriptionListener = subscriptionStream(userId).listen(
      (subscription) {
        currentSubscription.value = subscription;
        debugPrint('🔄 Subscription updated via stream: ${subscription.currentPlan.name}');
      },
      onError: (error) {
        debugPrint('❌ Subscription listener error: $error');
      },
    );
  }

  /// Stop listening to subscription changes
  void stopSubscriptionListener() {
    _subscriptionListener?.cancel();
    _subscriptionListener = null;
  }

  /// Update subscription status (for renewals, cancellations, etc.)
  Future<void> updateSubscriptionStatus({
    required String userId,
    required SubscriptionStatus status,
    DateTime? expiryDate,
    bool? autoRenew,
    String? action,
  }) async {
    try {
      await _firebaseService.ensureInitialized();

      final updateData = <String, dynamic>{
        'status': status.name,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (expiryDate != null) {
        updateData['expiryDate'] = Timestamp.fromDate(expiryDate);
      }

      if (autoRenew != null) {
        updateData['autoRenew'] = autoRenew;
      }

      await _firebaseService.firestore
          .collection('user_profiles')
          .doc(userId)
          .update({
        'subscription': updateData,
      });

      if (action != null) {
        await _addToSubscriptionHistory(
          userId: userId,
          action: action,
          plan: currentSubscription.value.currentPlan.name,
          transactionId: currentSubscription.value.transactionId ?? '',
        );
      }

      debugPrint('✅ Subscription status updated: $status');

    } catch (e) {
      debugPrint('❌ Failed to update subscription status: $e');
      throw FirebaseSubscriptionException(
        'Failed to update subscription status',
        details: e.toString(),
      );
    }
  }

  /// Get subscription history for a user
  Future<List<SubscriptionHistoryEntry>> getSubscriptionHistory(String userId) async {
    try {
      await _firebaseService.ensureInitialized();

      final userProfileDoc = await _firebaseService.firestore
          .collection('user_profiles')
          .doc(userId)
          .get();

      if (!userProfileDoc.exists) {
        return [];
      }

      final data = userProfileDoc.data();
      final historyData = data?['subscriptionHistory'] as List<dynamic>? ?? [];

      return historyData
          .cast<Map<String, dynamic>>()
          .map((entry) => SubscriptionHistoryEntry.fromFirebaseMap(entry))
          .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    } catch (e) {
      debugPrint('❌ Failed to get subscription history: $e');
      return [];
    }
  }

  /// Add entry to subscription history
  Future<void> _addToSubscriptionHistory({
    required String userId,
    required String action,
    required String plan,
    required String transactionId,
  }) async {
    try {
      final historyEntry = {
        'action': action,
        'plan': plan,
        'transactionId': transactionId,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firebaseService.firestore
          .collection('user_profiles')
          .doc(userId)
          .update({
        'subscriptionHistory': FieldValue.arrayUnion([historyEntry]),
      });

    } catch (e) {
      debugPrint('❌ Failed to add subscription history entry: $e');
      // Don't throw - history is not critical
    }
  }

  /// Check if user has specific feature access
  bool hasFeatureAccess(FeatureType feature) {
    return FeatureManager.hasAccess(feature, currentSubscription.value.currentPlan);
  }

  /// Get feature limits for current subscription
  int getFeatureLimit(FeatureType feature) {
    return FeatureManager.getLimit(feature, currentSubscription.value.currentPlan);
  }

  /// Validate subscription and update if needed
  Future<void> validateAndRefreshSubscription(String userId) async {
    try {
      // This would typically call your server to validate receipts
      // For now, just refresh from Firebase
      await getSubscription(userId);

      debugPrint('✅ Subscription validation completed');

    } catch (e) {
      debugPrint('❌ Subscription validation failed: $e');
    }
  }

  /// Reset to free subscription (for testing or downgrades)
  Future<void> resetToFreeSubscription(String userId) async {
    try {
      await _firebaseService.ensureInitialized();

      final freeSubscription = UserSubscription.free();

      await _firebaseService.firestore
          .collection('user_profiles')
          .doc(userId)
          .update({
        'subscription': freeSubscription.toFirebaseMap(),
      });

      await _addToSubscriptionHistory(
        userId: userId,
        action: 'reset_to_free',
        plan: 'free',
        transactionId: '',
      );

      currentSubscription.value = freeSubscription;

      debugPrint('✅ Reset to free subscription completed');

    } catch (e) {
      debugPrint('❌ Failed to reset subscription: $e');
      throw FirebaseSubscriptionException(
        'Failed to reset subscription',
        details: e.toString(),
      );
    }
  }
}

/// Feature management system
class FeatureManager {
  static const Map<SubscriptionPlanType, Map<FeatureType, dynamic>> _featureMatrix = {
    SubscriptionPlanType.free: {
      FeatureType.globalRaces: false,
      FeatureType.countryRaces: true,
      FeatureType.joinRaces: 3,
      FeatureType.createRaces: 2,
      FeatureType.marathons: false,
      FeatureType.advancedStats: false,
      FeatureType.heartRateZones: false,
      FeatureType.leaderboards: false,
      FeatureType.hallOfFame: false,
      FeatureType.groupChat: false,
    },
    SubscriptionPlanType.premium1: {
      FeatureType.globalRaces: false,
      FeatureType.countryRaces: true,
      FeatureType.joinRaces: 7,
      FeatureType.createRaces: 7,
      FeatureType.marathons: true,
      FeatureType.advancedStats: true,
      FeatureType.heartRateZones: true,
      FeatureType.leaderboards: true,
      FeatureType.hallOfFame: false,
      FeatureType.groupChat: false,
    },
    SubscriptionPlanType.premium2: {
      FeatureType.globalRaces: true,
      FeatureType.countryRaces: true,
      FeatureType.joinRaces: 20,
      FeatureType.createRaces: 20,
      FeatureType.marathons: true,
      FeatureType.advancedStats: true,
      FeatureType.heartRateZones: true,
      FeatureType.leaderboards: true,
      FeatureType.hallOfFame: true,
      FeatureType.groupChat: true,
    },
  };

  static bool hasAccess(FeatureType feature, SubscriptionPlanType plan) {
    final planFeatures = _featureMatrix[plan] ?? {};
    final featureValue = planFeatures[feature];

    if (featureValue is bool) return featureValue;
    if (featureValue is int) return featureValue > 0;

    return false;
  }

  static int getLimit(FeatureType feature, SubscriptionPlanType plan) {
    final planFeatures = _featureMatrix[plan] ?? {};
    final featureValue = planFeatures[feature];

    if (featureValue is int) return featureValue;
    if (featureValue is bool) return featureValue ? -1 : 0; // -1 = unlimited

    return 0;
  }
}

/// Feature types enum
enum FeatureType {
  globalRaces,
  countryRaces,
  joinRaces,
  createRaces,
  marathons,
  advancedStats,
  heartRateZones,
  leaderboards,
  hallOfFame,
  groupChat,
}

/// Subscription history entry model
class SubscriptionHistoryEntry {
  final String action;
  final String plan;
  final String transactionId;
  final DateTime timestamp;

  const SubscriptionHistoryEntry({
    required this.action,
    required this.plan,
    required this.transactionId,
    required this.timestamp,
  });

  factory SubscriptionHistoryEntry.fromFirebaseMap(Map<String, dynamic> map) {
    return SubscriptionHistoryEntry(
      action: map['action'] as String? ?? '',
      plan: map['plan'] as String? ?? '',
      transactionId: map['transactionId'] as String? ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirebaseMap() {
    return {
      'action': action,
      'plan': plan,
      'transactionId': transactionId,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

/// Custom exception for Firebase subscription operations
class FirebaseSubscriptionException implements Exception {
  final String message;
  final String? details;

  const FirebaseSubscriptionException(this.message, {this.details});

  @override
  String toString() => 'FirebaseSubscriptionException: $message${details != null ? ' ($details)' : ''}';
}