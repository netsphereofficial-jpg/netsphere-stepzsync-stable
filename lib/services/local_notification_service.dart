import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math';
import '../models/notification_model.dart';
import '../controllers/notification_controller.dart';
import 'notification_repository.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final NotificationRepository _notificationRepository = NotificationRepository();

  static Future<void> initialize() async {
    print('🔔 Initializing LocalNotificationService...');

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    final initialized = await _notificationsPlugin.initialize(
      initializationSettings,
      // Deep linking disabled - users should not navigate from notifications
      onDidReceiveNotificationResponse: null,
    );

    print('🔔 LocalNotificationService initialized: $initialized');

    // Create notification channels for Android
    await createNotificationChannels();

    // Request permissions
    final permissionGranted = await requestPermissions();
    print('🔔 Notification permissions granted: $permissionGranted');
  }

  // Deep linking disabled - notification taps will not trigger navigation
  // Users must manually navigate to relevant screens

  /// Main method to send local notification and store in both local list and Firebase
  static Future<void> sendNotificationAndStore({
    required String title,
    required String message,
    required String notificationType,
    String category = 'General',
    String icon = '🔔',
    String? thumbnail,
    String? userId,
    String? userName,
    String? raceId,
    String? raceName,
    Map<String, dynamic>? metadata,
    bool sendLocalNotification = true,
    bool storeInLocal = true,
    bool storeInFirebase = true,
  }) async {
    try {
      // Generate unique notification ID (32-bit safe)
      final notificationId = _generateSafeNotificationId();

      // Create notification model
      final notificationModel = NotificationModel(
        id: notificationId,
        title: title,
        message: message,
        category: category,
        notificationType: notificationType,
        icon: icon,
        time: _formatNotificationTime(DateTime.now()),
        thumbnail: thumbnail,
        userId: userId,
        userName: userName,
        raceId: raceId,
        raceName: raceName,
        metadata: metadata,
        isRead: false,
      );

      // Send local notification if enabled
      if (sendLocalNotification) {
        await _sendLocalNotification(
          id: notificationId,
          title: title,
          message: message,
          notificationType: notificationType,
          raceId: raceId,
        );
      }

      // Add to local notification list if enabled
      if (storeInLocal) {
        await _addToLocalNotificationList(notificationModel);
      }

      // Store in Firebase if enabled
      if (storeInFirebase) {
        await _storeInFirebase(notificationModel);
      }

    } catch (e) {
      debugPrint('Error in sendNotificationAndStore: $e');
    }
  }

  /// Send local push notification
  static Future<void> _sendLocalNotification({
    required int id,
    required String title,
    required String message,
    required String notificationType,
    String? raceId,
  }) async {
    try {
      print('📱 Sending local notification: ID=$id, Title=$title');

      // Check if we have permission to show notifications
      final hasPermission = await _checkNotificationPermissions();
      if (!hasPermission) {
        print('❌ No notification permission - notification not shown');
        return;
      }

      // Payload is not used for navigation (deep linking disabled)
      String payload = notificationType;

    // Determine channel based on notification type
    String channelId = 'stepzsync_channel';
    if (notificationType.contains('Race') || notificationType.contains('Invite')) {
      channelId = 'stepzsync_race_channel';
    } else if (notificationType.contains('Achievement') || notificationType.contains('HallOfFame') || notificationType.contains('Won')) {
      channelId = 'stepzsync_achievement_channel';
    }

    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      channelId,
      channelId == 'stepzsync_race_channel' ? 'Race Notifications' :
      channelId == 'stepzsync_achievement_channel' ? 'Achievement Notifications' : 'StepzSync Notifications',
      channelDescription: channelId == 'stepzsync_race_channel' ? 'Notifications for race invites and updates' :
      channelId == 'stepzsync_achievement_channel' ? 'Notifications for achievements and milestones' : 'Notifications for StepzSync app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      autoCancel: true,
    );

    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      message,
      notificationDetails,
      payload: payload,
    );

    print('✅ Local notification sent successfully with ID: $id');
    print('📱 Notification details: $title - $message');
    print('📱 Channel used: ${androidNotificationDetails.channelId}');
    } catch (e) {
      print('❌ Failed to send local notification: $e');
      print('❌ Notification details: ID=$id, Title=$title, Type=$notificationType');

      // Try to get more details about the error
      if (e.toString().contains('permission')) {
        print('❌ Error seems to be permission-related');
        final hasPermission = await _checkNotificationPermissions();
        print('❌ Current permission status: $hasPermission');
      }
    }
  }

  /// Add notification to local controller list
  static Future<void> _addToLocalNotificationList(NotificationModel notification) async {
    try {
      // Get notification controller if it exists
      if (Get.isRegistered<NotificationController>()) {
        final controller = Get.find<NotificationController>();

        // Check if notification already exists to avoid duplicates
        final existsAlready = controller.allNotifications.any((n) =>
          n.title == notification.title &&
          n.message == notification.message &&
          n.notificationType == notification.notificationType
        );

        if (!existsAlready) {
          // Add to beginning of list (most recent first)
          controller.allNotifications.insert(0, notification);
          controller.allNotifications.refresh();
          print('📱 Added notification to controller list: ${notification.title}');
        } else {
          print('📱 Notification already exists in controller list, skipping duplicate');
        }
      }
    } catch (e) {
      debugPrint('Error adding to local notification list: $e');
    }
  }

  /// Store notification in Firebase
  static Future<void> _storeInFirebase(NotificationModel notification) async {
    try {
      await _notificationRepository.createNotification(
        title: notification.title,
        message: notification.message,
        category: notification.category,
        notificationType: notification.notificationType,
        icon: notification.icon,
        thumbnail: notification.thumbnail,
        userId: notification.userId,
        userName: notification.userName,
        raceId: notification.raceId,
        raceName: notification.raceName,
        metadata: notification.metadata,
      );
    } catch (e) {
      debugPrint('Error storing notification in Firebase: $e');
    }
  }

  /// Generate a 32-bit safe notification ID
  static int _generateSafeNotificationId() {
    // Use current time in seconds plus a random component to ensure uniqueness
    // This keeps the ID within 32-bit integer range
    final timeComponent = (DateTime.now().millisecondsSinceEpoch ~/ 1000) % 1000000; // Last 6 digits of seconds
    final randomComponent = Random().nextInt(1000); // 0-999
    return timeComponent * 1000 + randomComponent; // Combines both for uniqueness
  }

  /// Format notification time similar to the repository
  static String _formatNotificationTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  /// Quick methods for common notification types

  // Race notifications
  static Future<void> sendRaceInviteNotification({
    required String title,
    required String message,
    required String raceId,
    required String raceName,
    String? inviterName,
    Map<String, dynamic>? raceMetadata,
  }) async {
    await sendNotificationAndStore(
      title: title,
      message: message,
      notificationType: 'InviteRace',
      category: 'Race',
      icon: '🏃‍♂️',
      raceId: raceId,
      raceName: raceName,
      userName: inviterName,
      metadata: raceMetadata,
    );
  }

  static Future<void> sendRaceStartNotification({
    required String title,
    required String message,
    required String raceId,
    required String raceName,
  }) async {
    await sendNotificationAndStore(
      title: title,
      message: message,
      notificationType: 'RaceBegin',
      category: 'Race',
      icon: '🚀',
      raceId: raceId,
      raceName: raceName,
    );
  }

  static Future<void> sendRaceWonNotification({
    required String title,
    required String message,
    required String raceId,
    required String raceName,
    required int rank,
    int? xpEarned,
  }) async {
    await sendNotificationAndStore(
      title: title,
      message: message,
      notificationType: 'RaceWon',
      category: 'Achievement',
      icon: '🏆',
      raceId: raceId,
      raceName: raceName,
      metadata: {
        'rank': rank,
        if (xpEarned != null) 'xpEarned': xpEarned,
      },
    );
  }

  // Friend notifications
  static Future<void> sendFriendRequestNotification({
    required String title,
    required String message,
    required String fromUserId,
    required String fromUserName,
    String? thumbnail,
    int? mutualFriends,
  }) async {
    await sendNotificationAndStore(
      title: title,
      message: message,
      notificationType: 'FriendRequest',
      category: 'Social',
      icon: '👥',
      userId: fromUserId,
      userName: fromUserName,
      thumbnail: thumbnail,
      metadata: {
        if (mutualFriends != null) 'mutualFriends': mutualFriends,
      },
    );
  }

  // Achievement notifications
  static Future<void> sendHallOfFameNotification({
    required String title,
    required String message,
    int? xpEarned,
  }) async {
    await sendNotificationAndStore(
      title: title,
      message: message,
      notificationType: 'HallOfFame',
      category: 'Achievement',
      icon: '🌟',
      metadata: {
        if (xpEarned != null) 'xpEarned': xpEarned,
      },
    );
  }

  // Marathon notifications
  static Future<void> sendMarathonNotification({
    required String title,
    required String message,
    bool isActive = false,
  }) async {
    await sendNotificationAndStore(
      title: title,
      message: message,
      notificationType: isActive ? 'ActiveMarathon' : 'Marathon',
      category: 'Marathon',
      icon: '🏃‍♀️',
    );
  }

  // General notifications
  static Future<void> sendGeneralNotification({
    required String title,
    required String message,
    String icon = '🔔',
  }) async {
    await sendNotificationAndStore(
      title: title,
      message: message,
      notificationType: 'General',
      category: 'General',
      icon: icon,
    );
  }

  /// Check notification permissions with detailed logging
  static Future<bool> _checkNotificationPermissions() async {
    print('🔍 Checking notification permissions...');

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final IOSFlutterLocalNotificationsPlugin? iosImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final granted = await androidImplementation.areNotificationsEnabled();
      print('📱 Android notifications enabled: $granted');
      return granted ?? false;
    }

    if (iosImplementation != null) {
      final permissions = await iosImplementation.checkPermissions();
      final isEnabled = permissions?.isEnabled == true;
      print('🍎 iOS notifications enabled: $isEnabled');
      print('🍎 iOS permissions details: ${permissions?.toString()}');
      return isEnabled;
    }

    print('❌ No platform implementation found');
    return false;
  }

  /// Create notification channels for Android
  static Future<void> createNotificationChannels() async {
    print('🔔 Creating notification channels...');

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      // Main StepzSync channel
      const AndroidNotificationChannel mainChannel = AndroidNotificationChannel(
        'stepzsync_channel',
        'StepzSync Notifications',
        description: 'Notifications for StepzSync app',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      // Race notifications channel
      const AndroidNotificationChannel raceChannel = AndroidNotificationChannel(
        'stepzsync_race_channel',
        'Race Notifications',
        description: 'Notifications for race invites and updates',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      // Achievement notifications channel
      const AndroidNotificationChannel achievementChannel = AndroidNotificationChannel(
        'stepzsync_achievement_channel',
        'Achievement Notifications',
        description: 'Notifications for achievements and milestones',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      // Create channels
      await androidImplementation.createNotificationChannel(mainChannel);
      await androidImplementation.createNotificationChannel(raceChannel);
      await androidImplementation.createNotificationChannel(achievementChannel);

      print('✅ Android notification channels created successfully');
    } else {
      print('ℹ️ Android implementation not available - skipping channel creation');
    }
  }

  /// Request notification permissions with detailed logging
  static Future<bool> requestPermissions() async {
    print('🔔 Requesting notification permissions...');

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final IOSFlutterLocalNotificationsPlugin? iosImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    bool granted = false;

    if (androidImplementation != null) {
      print('📱 Requesting Android notification permissions...');
      granted = await androidImplementation.requestNotificationsPermission() ?? false;
      print('📱 Android notification permission result: $granted');

      // Check if notifications are enabled
      final enabled = await androidImplementation.areNotificationsEnabled() ?? false;
      print('📱 Android notifications enabled: $enabled');
    }

    if (iosImplementation != null) {
      print('🍎 Requesting iOS notification permissions...');

      // First try to get provisional authorization
      final provisional = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
      ) ?? false;
      print('🍎 iOS provisional permission result: $provisional');

      // Then request full permissions
      granted = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      ) ?? false;
      print('🍎 iOS notification permission result: $granted');

      // Check current permissions
      final permissions = await iosImplementation.checkPermissions();
      print('🍎 iOS current permissions: ${permissions?.toString()}');
    }

    print('🔔 Final permission status: $granted');
    return granted;
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Cancel specific notification
  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Get notification permission status with detailed info
  static Future<Map<String, dynamic>> getNotificationStatus() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final IOSFlutterLocalNotificationsPlugin? iosImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    Map<String, dynamic> status = {
      'platform': 'unknown',
      'enabled': false,
      'details': 'No implementation found'
    };

    if (androidImplementation != null) {
      final enabled = await androidImplementation.areNotificationsEnabled() ?? false;
      status = {
        'platform': 'android',
        'enabled': enabled,
        'details': enabled ? 'Notifications are enabled' : 'Notifications are disabled'
      };
    }

    if (iosImplementation != null) {
      final permissions = await iosImplementation.checkPermissions();
      final isEnabled = permissions?.isEnabled ?? false;
      status = {
        'platform': 'ios',
        'enabled': isEnabled,
        'details': permissions?.toString() ?? 'No permission details available'
      };
    }

    return status;
  }

  /// Test notification with immediate feedback
  static Future<Map<String, dynamic>> sendTestNotification() async {
    print('🧪 Sending test notification...');

    try {
      // Check permissions first
      final hasPermission = await _checkNotificationPermissions();
      if (!hasPermission) {
        return {
          'success': false,
          'error': 'No notification permissions',
          'details': 'Please enable notifications in device settings'
        };
      }

      // Send test notification
      await sendNotificationAndStore(
        title: 'Test Notification 🧪',
        message: 'If you see this, local notifications are working! Tap to test navigation.',
        notificationType: 'TestNotification',
        category: 'Test',
        icon: '🧪',
        sendLocalNotification: true,
        storeInLocal: false,
        storeInFirebase: false,
      );

      return {
        'success': true,
        'message': 'Test notification sent successfully',
        'timestamp': DateTime.now().toIso8601String()
      };
    } catch (e) {
      print('❌ Test notification failed: $e');
      return {
        'success': false,
        'error': e.toString(),
        'details': 'Failed to send test notification'
      };
    }
  }

  /// Debug notification with detailed info
  static Future<void> sendDebugNotification() async {
    print('🔧 Sending debug notification...');

    final status = await getNotificationStatus();
    final timeStr = DateTime.now().toString().split('.')[0];

    await sendNotificationAndStore(
      title: 'Debug Info 🔧',
      message: 'Platform: ${status['platform']}, Enabled: ${status['enabled']}, Time: $timeStr',
      notificationType: 'Debug',
      category: 'Debug',
      icon: '🔧',
      sendLocalNotification: true,
      storeInLocal: false,
      storeInFirebase: false,
    );
  }
}