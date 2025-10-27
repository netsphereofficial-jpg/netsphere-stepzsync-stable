import 'package:get/get.dart';
import '../controllers/notification_controller.dart';
import '../models/notification_model.dart';
import 'local_notification_service.dart';
import 'notification_repository.dart';

class UnifiedNotificationService {
  static final NotificationRepository _repository = NotificationRepository();

  /// Main method to create notifications that save to list AND trigger push notifications
  static Future<void> createAndPushNotification({
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
    bool sendLocalPush = true,
    bool saveToFirestore = true,
    bool updateController = true,
  }) async {
    try {
      print('🔄 UnifiedNotificationService: Creating unified notification');
      print('📋 Title: $title');
      print('📋 Type: $notificationType');
      print('📋 Category: $category');

      // Step 1: Save to Firestore if requested
      String? firestoreId;
      if (saveToFirestore) {
        print('💾 Saving notification to Firestore...');
        final result = await _repository.createNotification(
          title: title,
          message: message,
          category: category,
          notificationType: notificationType,
          icon: icon,
          thumbnail: thumbnail,
          userId: userId,
          userName: userName,
          raceId: raceId,
          raceName: raceName,
          metadata: metadata,
        );

        if (result?['status'] == 200) {
          firestoreId = result?['data']?['id'];
          print('✅ Saved to Firestore with ID: $firestoreId');
        } else {
          print('❌ Failed to save to Firestore: ${result?['message']}');
        }
      }

      // Step 2: Send local push notification if requested
      if (sendLocalPush) {
        print('📱 Sending local push notification...');
        await LocalNotificationService.sendNotificationAndStore(
          title: title,
          message: message,
          notificationType: notificationType,
          category: category,
          icon: icon,
          thumbnail: thumbnail,
          userId: userId,
          userName: userName,
          raceId: raceId,
          raceName: raceName,
          metadata: metadata,
          sendLocalNotification: true,
          storeInLocal: false, // Don't duplicate in local list since we're using Firestore
          storeInFirebase: false, // Already saved above
        );
        print('✅ Local push notification sent');
      }

      // Step 3: Update NotificationController in real-time if requested
      if (updateController && Get.isRegistered<NotificationController>()) {
        print('🔄 Updating NotificationController...');
        final controller = Get.find<NotificationController>();

        // Create notification model for the controller
        final notificationModel = NotificationModel(
          id: firestoreId?.hashCode.abs() ?? DateTime.now().millisecondsSinceEpoch,
          firebaseId: firestoreId,
          title: title,
          message: message,
          category: category,
          notificationType: notificationType,
          icon: icon,
          time: 'Just now',
          thumbnail: thumbnail,
          userId: userId,
          userName: userName,
          raceId: raceId,
          raceName: raceName,
          metadata: metadata,
          isRead: false,
        );

        // Add to the beginning of the list (most recent first)
        controller.allNotifications.insert(0, notificationModel);
        controller.allNotifications.refresh();
        print('✅ NotificationController updated with new notification');
      }

      print('🎉 Unified notification created successfully!');
    } catch (e, stackTrace) {
      print('❌ Error in createAndPushNotification: $e');
      print('📍 Stack trace: $stackTrace');
    }
  }

  /// Push notification for existing Firestore notification
  static Future<void> pushExistingNotification(NotificationModel notification) async {
    try {
      print('📤 Pushing existing notification: ${notification.title}');

      await LocalNotificationService.sendNotificationAndStore(
        title: notification.title,
        message: notification.message,
        notificationType: notification.notificationType,
        category: notification.category,
        icon: notification.icon,
        thumbnail: notification.thumbnail,
        userId: notification.userId,
        userName: notification.userName,
        raceId: notification.raceId,
        raceName: notification.raceName,
        metadata: notification.metadata,
        sendLocalNotification: true,
        storeInLocal: false,
        storeInFirebase: false,
      );

      print('✅ Existing notification pushed successfully');
    } catch (e) {
      print('❌ Error pushing existing notification: $e');
    }
  }

  /// Refresh notifications in controller and optionally push recent ones
  static Future<void> refreshNotificationsWithPush({bool pushRecent = false}) async {
    try {
      print('🔄 Refreshing notifications with push option: $pushRecent');

      if (Get.isRegistered<NotificationController>()) {
        final controller = Get.find<NotificationController>();

        // Store current count to detect new notifications
        final currentCount = controller.allNotifications.length;

        // Refresh the notification list
        await controller.getNotificationList(null);

        // If there are new notifications and pushRecent is true, push the latest unread ones
        if (pushRecent && controller.allNotifications.length > currentCount) {
          final newNotifications = controller.allNotifications
              .take(controller.allNotifications.length - currentCount)
              .where((n) => !n.isRead);

          for (final notification in newNotifications) {
            await pushExistingNotification(notification);
          }

          print('✅ Pushed ${newNotifications.length} recent notifications');
        }
      }
    } catch (e) {
      print('❌ Error refreshing notifications with push: $e');
    }
  }

  // MARK: - Convenience methods for common notification types

  /// Send race invite notification (saves to list + pushes)
  static Future<void> sendRaceInviteNotification({
    required String title,
    required String message,
    required String raceId,
    required String raceName,
    String? inviterName,
    String? inviterUserId,
    Map<String, dynamic>? raceMetadata,
  }) async {
    await createAndPushNotification(
      title: title,
      message: message,
      notificationType: 'InviteRace',
      category: 'Race',
      icon: '🏃‍♂️',
      raceId: raceId,
      raceName: raceName,
      userName: inviterName,
      userId: inviterUserId,
      metadata: raceMetadata,
    );
  }

  /// Send race start notification (saves to list + pushes)
  static Future<void> sendRaceStartNotification({
    required String title,
    required String message,
    required String raceId,
    required String raceName,
    Map<String, dynamic>? raceMetadata,
  }) async {
    await createAndPushNotification(
      title: title,
      message: message,
      notificationType: 'RaceBegin',
      category: 'Race',
      icon: '🚀',
      raceId: raceId,
      raceName: raceName,
      metadata: raceMetadata,
    );
  }

  /// Send race won notification (saves to list + pushes)
  static Future<void> sendRaceWonNotification({
    required String title,
    required String message,
    required String raceId,
    required String raceName,
    required int rank,
    int? xpEarned,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    final metadata = {
      'rank': rank,
      if (xpEarned != null) 'xpEarned': xpEarned,
      ...?additionalMetadata,
    };

    await createAndPushNotification(
      title: title,
      message: message,
      notificationType: 'RaceWon',
      category: 'Achievement',
      icon: '🏆',
      raceId: raceId,
      raceName: raceName,
      metadata: metadata,
    );
  }

  /// Send friend request notification (saves to list + pushes)
  static Future<void> sendFriendRequestNotification({
    required String title,
    required String message,
    required String fromUserId,
    required String fromUserName,
    String? thumbnail,
    int? mutualFriends,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    final metadata = {
      if (mutualFriends != null) 'mutualFriends': mutualFriends,
      ...?additionalMetadata,
    };

    await createAndPushNotification(
      title: title,
      message: message,
      notificationType: 'FriendRequest',
      category: 'Social',
      icon: '👥',
      userId: fromUserId,
      userName: fromUserName,
      thumbnail: thumbnail,
      metadata: metadata,
    );
  }

  /// Send achievement notification (saves to list + pushes)
  static Future<void> sendAchievementNotification({
    required String title,
    required String message,
    String type = 'HallOfFame',
    int? xpEarned,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    final metadata = {
      if (xpEarned != null) 'xpEarned': xpEarned,
      ...?additionalMetadata,
    };

    await createAndPushNotification(
      title: title,
      message: message,
      notificationType: type,
      category: 'Achievement',
      icon: '🌟',
      metadata: metadata,
    );
  }

  /// Send marathon notification (saves to list + pushes)
  static Future<void> sendMarathonNotification({
    required String title,
    required String message,
    bool isActive = false,
    Map<String, dynamic>? marathonMetadata,
  }) async {
    await createAndPushNotification(
      title: title,
      message: message,
      notificationType: isActive ? 'ActiveMarathon' : 'Marathon',
      category: 'Marathon',
      icon: '🏃‍♀️',
      metadata: marathonMetadata,
    );
  }

  /// Send general notification (saves to list + pushes)
  static Future<void> sendGeneralNotification({
    required String title,
    required String message,
    String icon = '🔔',
    Map<String, dynamic>? metadata,
  }) async {
    await createAndPushNotification(
      title: title,
      message: message,
      notificationType: 'General',
      category: 'General',
      icon: icon,
      metadata: metadata,
    );
  }

  // MARK: - Utility methods

  /// Only save to notification list (no push notification)
  static Future<void> saveNotificationOnly({
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
  }) async {
    await createAndPushNotification(
      title: title,
      message: message,
      notificationType: notificationType,
      category: category,
      icon: icon,
      thumbnail: thumbnail,
      userId: userId,
      userName: userName,
      raceId: raceId,
      raceName: raceName,
      metadata: metadata,
      sendLocalPush: false,
      saveToFirestore: true,
      updateController: true,
    );
  }

  /// Only send push notification (don't save to list)
  static Future<void> pushNotificationOnly({
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
  }) async {
    await createAndPushNotification(
      title: title,
      message: message,
      notificationType: notificationType,
      category: category,
      icon: icon,
      thumbnail: thumbnail,
      userId: userId,
      userName: userName,
      raceId: raceId,
      raceName: raceName,
      metadata: metadata,
      sendLocalPush: true,
      saveToFirestore: false,
      updateController: false,
    );
  }

  /// Test method to create sample unified notifications
  static Future<void> createTestNotifications() async {
    print('🧪 Creating test unified notifications...');

    // Test race invite
    await sendRaceInviteNotification(
      title: 'Race Invite Test!',
      message: 'John Doe invited you to join "Morning Run Challenge"',
      raceId: 'test-race-123',
      raceName: 'Morning Run Challenge',
      inviterName: 'John Doe',
      inviterUserId: 'user-123',
    );

    await Future.delayed(Duration(milliseconds: 500));

    // Test achievement
    await sendAchievementNotification(
      title: 'Achievement Unlocked!',
      message: 'You completed your first 5K run!',
      xpEarned: 100,
    );

    await Future.delayed(Duration(milliseconds: 500));

    // Test friend request
    await sendFriendRequestNotification(
      title: 'New Friend Request',
      message: 'Sarah wants to be your friend!',
      fromUserId: 'user-456',
      fromUserName: 'Sarah',
      mutualFriends: 3,
    );

    print('✅ Test unified notifications created!');
  }
}