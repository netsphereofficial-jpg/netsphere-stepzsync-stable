import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';

/// Unified analytics service that logs events to both Firebase Analytics
/// and Facebook App Events for ad performance tracking.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _firebaseAnalytics = FirebaseAnalytics.instance;
  final FacebookAppEvents _facebookAppEvents = FacebookAppEvents();
  bool _initialized = false;

  /// Firebase Analytics observer for automatic route tracking
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _firebaseAnalytics);

  /// Initialize analytics services
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _firebaseAnalytics.setAnalyticsCollectionEnabled(true);
      _initialized = true;
      debugPrint('[Analytics] Initialized');
    } catch (e) {
      debugPrint('[Analytics] Init error: $e');
    }
  }

  /// Set user ID for both platforms
  Future<void> setUserId(String userId) async {
    try {
      await _firebaseAnalytics.setUserId(id: userId);
      debugPrint('[Analytics] User ID set');
    } catch (e) {
      debugPrint('[Analytics] setUserId error: $e');
    }
  }

  /// Log screen view
  Future<void> logScreenView(String screenName) async {
    try {
      await _firebaseAnalytics.logScreenView(screenName: screenName);
      await _facebookAppEvents.logViewContent(
        type: 'screen',
        id: screenName,
      );
    } catch (e) {
      debugPrint('[Analytics] logScreenView error: $e');
    }
  }

  /// Log successful registration
  Future<void> logCompleteRegistration({required String method}) async {
    try {
      await _firebaseAnalytics.logSignUp(signUpMethod: method);
      await _facebookAppEvents.logCompletedRegistration(
        registrationMethod: method,
      );
      debugPrint('[Analytics] CompleteRegistration: $method');
    } catch (e) {
      debugPrint('[Analytics] logCompleteRegistration error: $e');
    }
  }

  /// Log successful login (Firebase only)
  Future<void> logLogin({required String method}) async {
    try {
      await _firebaseAnalytics.logLogin(loginMethod: method);
      debugPrint('[Analytics] Login: $method');
    } catch (e) {
      debugPrint('[Analytics] logLogin error: $e');
    }
  }

  /// Log search query
  Future<void> logSearch({
    required String query,
    String contentType = 'race',
  }) async {
    try {
      await _firebaseAnalytics.logSearch(searchTerm: query);
      await _facebookAppEvents.logEvent(
        name: 'fb_mobile_search',
        parameters: {
          'fb_search_string': query,
          'fb_content_type': contentType,
        },
      );
      debugPrint('[Analytics] Search: $query');
    } catch (e) {
      debugPrint('[Analytics] logSearch error: $e');
    }
  }

  /// Log content view (race detail, subscription screen, etc.)
  Future<void> logViewContent({
    required String contentId,
    required String contentType,
  }) async {
    try {
      await _firebaseAnalytics.logViewItem(items: [
        AnalyticsEventItem(itemId: contentId, itemCategory: contentType),
      ]);
      await _facebookAppEvents.logViewContent(
        content: {'id': contentId, 'type': contentType},
        type: contentType,
      );
    } catch (e) {
      debugPrint('[Analytics] logViewContent error: $e');
    }
  }

  /// Log subscription purchase initiation (tap purchase button)
  Future<void> logInitiateCheckout({
    required String planId,
    required double price,
    String currency = 'USD',
  }) async {
    try {
      await _firebaseAnalytics.logBeginCheckout(
        value: price,
        currency: currency,
        items: [AnalyticsEventItem(itemId: planId, price: price)],
      );
      await _facebookAppEvents.logInitiatedCheckout(
        totalPrice: price,
        currency: currency,
        contentId: planId,
        contentType: 'subscription',
      );
      debugPrint('[Analytics] InitiateCheckout: $planId \$$price');
    } catch (e) {
      debugPrint('[Analytics] logInitiateCheckout error: $e');
    }
  }

  /// Log successful purchase
  Future<void> logPurchase({
    required String planId,
    required double price,
    String currency = 'USD',
  }) async {
    try {
      await _firebaseAnalytics.logPurchase(
        value: price,
        currency: currency,
        items: [AnalyticsEventItem(itemId: planId, price: price)],
      );
      await _facebookAppEvents.logPurchase(
        amount: price,
        currency: currency,
        parameters: {'fb_content_id': planId, 'fb_content_type': 'subscription'},
      );
      debugPrint('[Analytics] Purchase: $planId \$$price');
    } catch (e) {
      debugPrint('[Analytics] logPurchase error: $e');
    }
  }

  /// Log subscription activated
  Future<void> logSubscribe({
    required String planId,
    required double price,
    String currency = 'USD',
  }) async {
    try {
      await _firebaseAnalytics.logEvent(
        name: 'subscribe',
        parameters: {
          'plan_id': planId,
          'price': price,
          'currency': currency,
        },
      );
      await _facebookAppEvents.logSubscribe(
        orderId: planId,
        currency: currency,
        price: price,
      );
      debugPrint('[Analytics] Subscribe: $planId');
    } catch (e) {
      debugPrint('[Analytics] logSubscribe error: $e');
    }
  }

  /// Log payment info added
  Future<void> logAddPaymentInfo({required bool success}) async {
    try {
      await _firebaseAnalytics.logAddPaymentInfo();
      await _facebookAppEvents.logEvent(
        name: 'fb_mobile_add_payment_info',
        parameters: {
          'fb_success': success ? '1' : '0',
        },
      );
    } catch (e) {
      debugPrint('[Analytics] logAddPaymentInfo error: $e');
    }
  }

  /// Log tutorial/onboarding completion
  Future<void> logCompleteTutorial() async {
    try {
      await _firebaseAnalytics.logTutorialComplete();
      await _facebookAppEvents.logEvent(
        name: 'fb_mobile_tutorial_completion',
      );
    } catch (e) {
      debugPrint('[Analytics] logCompleteTutorial error: $e');
    }
  }

  /// Log XP level up
  Future<void> logAchieveLevel({required int level}) async {
    try {
      await _firebaseAnalytics.logLevelUp(level: level);
      await _facebookAppEvents.logEvent(
        name: 'fb_mobile_level_achieved',
        parameters: {'fb_level': level},
      );
    } catch (e) {
      debugPrint('[Analytics] logAchieveLevel error: $e');
    }
  }

  /// Log achievement earned
  Future<void> logUnlockAchievement({required String description}) async {
    try {
      await _firebaseAnalytics.logUnlockAchievement(id: description);
      await _facebookAppEvents.logEvent(
        name: 'fb_mobile_achievement_unlocked',
        parameters: {'fb_description': description},
      );
    } catch (e) {
      debugPrint('[Analytics] logUnlockAchievement error: $e');
    }
  }

  /// Log race scheduled/created
  Future<void> logSchedule() async {
    try {
      await _firebaseAnalytics.logEvent(name: 'race_created');
      await _facebookAppEvents.logEvent(name: 'fb_mobile_schedule');
    } catch (e) {
      debugPrint('[Analytics] logSchedule error: $e');
    }
  }
}
