import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_notification_service.dart';
import 'profile/profile_service.dart';

class FirebasePushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static String? _fcmToken;
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    print('🔥 Initializing Firebase Push Notification Service...');

    try {
      // Request notification permissions first
      final NotificationSettings settings = await _requestPermissions();
      print('🔥 FCM permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get FCM token
        await _getFCMToken();

        // Setup message handlers
        await _setupMessageHandlers();

        // Setup token refresh handler
        _setupTokenRefreshHandler();

        _isInitialized = true;
        print('✅ Firebase Push Notification Service initialized successfully');
      } else {
        print('❌ FCM permissions not granted');
      }
    } catch (e) {
      print('❌ Error initializing Firebase Push Notification Service: $e');
    }
  }

  static Future<NotificationSettings> _requestPermissions() async {
    print('🔥 Requesting FCM permissions...');

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      ).timeout(
        Duration(seconds: 20),
        onTimeout: () {
          print('⏰ FCM permission request timed out');
          return NotificationSettings(
            authorizationStatus: AuthorizationStatus.denied,
            alert: AppleNotificationSetting.disabled,
            announcement: AppleNotificationSetting.disabled,
            badge: AppleNotificationSetting.disabled,
            carPlay: AppleNotificationSetting.disabled,
            lockScreen: AppleNotificationSetting.disabled,
            notificationCenter: AppleNotificationSetting.disabled,
            showPreviews: AppleShowPreviewSetting.never,
            timeSensitive: AppleNotificationSetting.disabled,
            criticalAlert: AppleNotificationSetting.disabled,
            sound: AppleNotificationSetting.disabled,
            providesAppNotificationSettings: AppleNotificationSetting.disabled,
          );
        },
      );

      print('🔥 FCM Permission settings: ${settings.authorizationStatus}');
      return settings;
    } catch (e) {
      print('❌ Error requesting FCM permissions: $e');
      return NotificationSettings(
        authorizationStatus: AuthorizationStatus.denied,
        alert: AppleNotificationSetting.disabled,
        announcement: AppleNotificationSetting.disabled,
        badge: AppleNotificationSetting.disabled,
        carPlay: AppleNotificationSetting.disabled,
        lockScreen: AppleNotificationSetting.disabled,
        notificationCenter: AppleNotificationSetting.disabled,
        showPreviews: AppleShowPreviewSetting.never,
        timeSensitive: AppleNotificationSetting.disabled,
        criticalAlert: AppleNotificationSetting.disabled,
        sound: AppleNotificationSetting.disabled,
        providesAppNotificationSettings: AppleNotificationSetting.disabled,
      );
    }
  }

  static Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _messaging.getToken().timeout(
        Duration(seconds: 15),
        onTimeout: () {
          print('⏰ FCM token request timed out');
          return null;
        },
      );

      if (_fcmToken != null && _fcmToken!.isNotEmpty) {
        print('🔥 FCM Token obtained: ${_fcmToken!.substring(0, 20)}...');

        // Save token to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);

        // Save token to Firestore user_profile collection
        await _saveTokenToFirestore(_fcmToken!);
      } else {
        print('❌ Failed to get FCM token (likely running on simulator)');
      }
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      if (e.toString().contains('apns-token-not-set')) {
        print('ℹ️  APNS token not available - this is normal on iOS Simulator');
        print('ℹ️  FCM tokens will work on real iOS devices');
      }
    }
  }

  /// Save FCM token to Firestore user_profile collection
  static Future<void> _saveTokenToFirestore(String token) async {
    try {
      print('💾 Saving FCM token to Firestore...');
      final result = await ProfileService.updateFCMToken(token);

      if (result.success) {
        print('✅ FCM token saved to Firestore successfully');
      } else {
        print('⚠️ Failed to save FCM token to Firestore: ${result.error}');
      }
    } catch (e) {
      print('❌ Error saving FCM token to Firestore: $e');
      // Don't throw - we don't want FCM initialization to fail if Firestore save fails
    }
  }

  static Future<void> _setupMessageHandlers() async {
    print('🔥 Setting up FCM message handlers...');

    try {
      // Handle messages when app is in foreground (show notification only, no navigation)
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Deep linking disabled - notification taps will not trigger navigation
      // onMessageOpenedApp and getInitialMessage handlers removed

      print('✅ FCM message handlers setup completed');
    } catch (e) {
      print('❌ Error setting up FCM message handlers: $e');
    }
  }

  static void _setupTokenRefreshHandler() {
    print('🔥 Setting up FCM token refresh handler...');

    _messaging.onTokenRefresh
        .listen((fcmToken) async {
          print('🔥 FCM Token refreshed: ${fcmToken.substring(0, 20)}...');
          _fcmToken = fcmToken;

          // Save new token to SharedPreferences
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('fcm_token', fcmToken);
          });

          // Save new token to Firestore
          await _saveTokenToFirestore(fcmToken);
        })
        .onError((err) {
          print('❌ FCM Token refresh error: $err');
        });
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('🔥 Received foreground message: ${message.messageId}');
    print('🔥 Title: ${message.notification?.title}');
    print('🔥 Body: ${message.notification?.body}');
    print('🔥 Data: ${message.data}');

    // Show local notification when app is in foreground
    await _showLocalNotificationFromFCM(message);
  }

  // Deep linking disabled - notification taps will not trigger navigation

  static Future<void> _showLocalNotificationFromFCM(
    RemoteMessage message,
  ) async {
    final notification = message.notification;
    if (notification != null) {
      // Determine notification type from data
      final notificationType = message.data['type'] ?? 'General';
      final raceId = message.data['raceId'];
      final category = message.data['category'] ?? 'General';
      final icon = message.data['icon'] ?? '🔔';

      await LocalNotificationService.sendNotificationAndStore(
        title: notification.title ?? 'StepzSync',
        message: notification.body ?? 'You have a new notification',
        notificationType: notificationType,
        category: category,
        icon: icon,
        raceId: raceId,
        userId: message.data['userId'],
        userName: message.data['userName'],
        raceName: message.data['raceName'],
        metadata: message.data,
        sendLocalNotification: true,
        storeInLocal: true,
        storeInFirebase: true,
      );
    }
  }

  // Deep linking disabled - all navigation methods removed

  // Background message handler (must be top-level function)
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    print('🔥 Handling background message: ${message.messageId}');
    print('🔥 Background Title: ${message.notification?.title}');
    print('🔥 Background Body: ${message.notification?.body}');
    print('🔥 Background Data: ${message.data}');

    // Process the message data and store if needed
    // Note: Can't show local notifications in background handler
  }

  // Utility methods

  static String? get fcmToken => _fcmToken;

  static bool get isInitialized => _isInitialized;

  static Future<String?> getCurrentToken() async {
    try {
      if (_fcmToken == null) {
        _fcmToken = await _messaging.getToken();
      }
      return _fcmToken;
    } catch (e) {
      print('❌ Error getting current FCM token: $e');
      return null;
    }
  }

  static Future<String?> getStoredToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('fcm_token');
    } catch (e) {
      print('❌ Error getting stored FCM token: $e');
      return null;
    }
  }

  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      print('🔥 Subscribed to topic: $topic');
    } catch (e) {
      print('❌ Error subscribing to topic $topic: $e');
    }
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      print('🔥 Unsubscribed from topic: $topic');
    } catch (e) {
      print('❌ Error unsubscribing from topic $topic: $e');
    }
  }

  static Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      _fcmToken = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token');

      print('🔥 FCM token deleted');
    } catch (e) {
      print('❌ Error deleting FCM token: $e');
    }
  }

  /// Save current FCM token to Firestore for authenticated user
  /// Call this after user signs in/signs up to save the token
  static Future<void> saveCurrentTokenToFirestore() async {
    try {
      // First try to get cached token
      String? token = _fcmToken;

      // If no cached token, try to get from SharedPreferences
      if (token == null || token.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('fcm_token');
      }

      // If still no token, try to get fresh token from FCM
      if (token == null || token.isEmpty) {
        token = await getCurrentToken();
      }

      // Save token to Firestore if we have one
      if (token != null && token.isNotEmpty) {
        print('📤 Saving FCM token to Firestore for authenticated user...');
        await _saveTokenToFirestore(token);
      } else {
        print('ℹ️ No FCM token available to save (may be running on simulator)');
      }
    } catch (e) {
      print('❌ Error saving current token to Firestore: $e');
    }
  }

  // Quick notification methods for Firebase

  static Future<void> sendTestPushNotification() async {
    print('🧪 Testing Firebase push notification functionality...');

    final token = await getCurrentToken();
    if (token != null) {
      print('🧪 FCM Token for testing: ${token.substring(0, 50)}...');
      print('🧪 Use this token in Firebase Console to send test notifications');

      // Show a local notification to simulate FCM
      await LocalNotificationService.sendNotificationAndStore(
        title: 'FCM Test 🔥',
        message:
            'Firebase messaging is configured! Token: ${token.substring(0, 20)}...',
        notificationType: 'FCMTest',
        category: 'Test',
        icon: '🔥',
        sendLocalNotification: true,
        storeInLocal: false,
        storeInFirebase: false,
      );

      return;
    }

    print('❌ No FCM token available for testing');
  }

  // Race-specific push notification helpers (to be called from backend)

  static Map<String, dynamic> createRaceInvitePayload({
    required String title,
    required String body,
    required String raceId,
    required String raceName,
    String? inviterName,
    Map<String, dynamic>? additionalData,
  }) {
    return {
      'notification': {'title': title, 'body': body},
      'data': {
        'type': 'InviteRace',
        'category': 'Race',
        'icon': '🏃‍♂️',
        'raceId': raceId,
        'raceName': raceName,
        if (inviterName != null) 'userName': inviterName,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        ...?additionalData,
      },
    };
  }

  static Map<String, dynamic> createRaceStartPayload({
    required String title,
    required String body,
    required String raceId,
    required String raceName,
  }) {
    return {
      'notification': {'title': title, 'body': body},
      'data': {
        'type': 'RaceBegin',
        'category': 'Race',
        'icon': '🚀',
        'raceId': raceId,
        'raceName': raceName,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      },
    };
  }

  static Map<String, dynamic> createAchievementPayload({
    required String title,
    required String body,
    String type = 'HallOfFame',
    Map<String, dynamic>? additionalData,
  }) {
    return {
      'notification': {'title': title, 'body': body},
      'data': {
        'type': type,
        'category': 'Achievement',
        'icon': '🏆',
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        ...?additionalData,
      },
    };
  }

  // Debugging and status methods

  static Future<Map<String, dynamic>> getNotificationStatus() async {
    final settings = await _messaging.getNotificationSettings();
    final token = await getCurrentToken();

    return {
      'isInitialized': _isInitialized,
      'authorizationStatus': settings.authorizationStatus.toString(),
      'hasToken': token != null,
      'tokenPreview': token != null ? '${token.substring(0, 20)}...' : null,
      'platform': Platform.isIOS ? 'iOS' : 'Android',
      'settingsDetails': {
        'alert': settings.alert.toString(),
        'badge': settings.badge.toString(),
        'sound': settings.sound.toString(),

        'criticalAlert': settings.criticalAlert.toString(),
        'lockScreen': settings.lockScreen.toString(),
        'notificationCenter': settings.notificationCenter.toString(),
      },
    };
  }

  static void printDebugInfo() async {
    print('🔥 === Firebase Push Notification Debug Info ===');
    final status = await getNotificationStatus();
    status.forEach((key, value) {
      print('🔥 $key: $value');
    });
    print('🔥 ===============================================');
  }
}
