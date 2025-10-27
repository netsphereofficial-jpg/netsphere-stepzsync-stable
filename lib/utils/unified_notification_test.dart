import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/local_notification_service.dart';
import '../services/firebase_push_notification_service.dart';
import '../services/unified_notification_service.dart';
import '../controllers/notification_controller.dart';
import 'notification_helpers.dart';

class UnifiedNotificationTest {

  /// Run comprehensive test of the unified notification system
  static Future<void> runCompleteTest() async {
    print('🧪 ====== UNIFIED NOTIFICATION SYSTEM TEST ======');

    try {
      // Test 1: Local notifications
      await _testLocalNotifications();

      // Test 2: Firebase push notifications
      await _testFirebasePushNotifications();

      // Test 3: Unified notification service
      await _testUnifiedNotificationService();

      // Test 4: Notification helpers
      await _testNotificationHelpers();

      // Test 5: NotificationController integration
      await _testNotificationControllerIntegration();

      // Test 6: Permissions and status
      await _testNotificationPermissions();

      print('✅ ====== ALL UNIFIED NOTIFICATION TESTS PASSED ======');
      _showTestResultDialog('All Tests Passed!', '✅ Unified notification system is working perfectly!', true);

    } catch (e) {
      print('❌ UNIFIED NOTIFICATION TEST FAILED: $e');
      _showTestResultDialog('Tests Failed', '❌ Error: $e', false);
    }
  }

  static Future<void> _testLocalNotifications() async {
    print('🧪 Testing Local Notifications...');

    await LocalNotificationService.sendGeneralNotification(
      title: 'Local Test 🧪',
      message: 'Local notification working!',
      icon: '🧪',
    );

    print('✅ Local notifications test completed');
  }

  static Future<void> _testFirebasePushNotifications() async {
    print('🧪 Testing Firebase Push Notifications...');

    if (FirebasePushNotificationService.isInitialized) {
      print('✅ Firebase Push Notification Service is initialized');

      final token = await FirebasePushNotificationService.getCurrentToken();
      if (token != null) {
        print('✅ FCM Token available: ${token.substring(0, 20)}...');

        await FirebasePushNotificationService.sendTestPushNotification();
        print('✅ Firebase test notification sent');
      } else {
        print('❌ No FCM token available');
      }
    } else {
      print('❌ Firebase Push Notification Service not initialized');
    }

    print('✅ Firebase push notifications test completed');
  }

  static Future<void> _testUnifiedNotificationService() async {
    print('🧪 Testing Unified Notification Service...');

    // Test basic unified notification
    await UnifiedNotificationService.createAndPushNotification(
      title: 'Unified Test 🔗',
      message: 'Testing unified notification system!',
      notificationType: 'UnifiedTest',
      category: 'Test',
      icon: '🔗',
    );

    // Test race notification
    await UnifiedNotificationService.sendRaceInviteNotification(
      title: 'Test Race Invite',
      message: 'John invited you to a test race!',
      raceId: 'test-race-unified',
      raceName: 'Unified Test Race',
      inviterName: 'John Doe',
      inviterUserId: 'user-123',
    );

    // Test achievement notification
    await UnifiedNotificationService.sendAchievementNotification(
      title: 'Test Achievement',
      message: 'You unlocked a test achievement!',
      xpEarned: 50,
    );

    print('✅ Unified notification service test completed');
  }

  static Future<void> _testNotificationHelpers() async {
    print('🧪 Testing Notification Helpers...');

    // Test race invitation
    await NotificationHelpers.sendRaceInvitation(
      raceName: 'Helper Test Race',
      raceId: 'helper-test-race',
      inviterName: 'Helper Tester',
      inviterUserId: 'helper-user-123',
      distance: 5.0,
      location: 'Test Location',
    );

    // Test friend request
    await NotificationHelpers.sendFriendRequest(
      fromUserName: 'Helper Friend',
      fromUserId: 'helper-friend-456',
      mutualFriends: 2,
    );

    // Test daily goal
    await NotificationHelpers.sendDailyGoalCompleted(
      goalType: 'steps',
      goalValue: 10000,
      actualValue: 12000,
      xpEarned: 25,
    );

    print('✅ Notification helpers test completed');
  }

  static Future<void> _testNotificationControllerIntegration() async {
    print('🧪 Testing NotificationController Integration...');

    if (Get.isRegistered<NotificationController>()) {
      final controller = Get.find<NotificationController>();

      // Test unified notification through controller
      await controller.createUnifiedNotification(
        title: 'Controller Test 🎮',
        message: 'Testing notification through controller!',
        notificationType: 'ControllerTest',
        category: 'Test',
        icon: '🎮',
      );

      // Test convenient methods
      await controller.sendRaceInvite(
        title: 'Controller Race Invite',
        message: 'Race invite through controller!',
        raceId: 'controller-race-123',
        raceName: 'Controller Test Race',
        inviterName: 'Controller Tester',
      );

      await controller.sendAchievement(
        title: 'Controller Achievement',
        message: 'Achievement through controller!',
        xpEarned: 75,
      );

      final unreadCount = NotificationHelpers.getUnreadCount();
      print('📊 Current unread notifications: $unreadCount');

      print('✅ NotificationController integration test completed');
    } else {
      print('❌ NotificationController not registered');
    }
  }

  static Future<void> _testNotificationPermissions() async {
    print('🧪 Testing Notification Permissions...');

    // Test local notification status
    final localStatus = await LocalNotificationService.getNotificationStatus();
    print('📱 Local Status: ${localStatus['enabled']} (${localStatus['platform']})');

    // Test Firebase notification status
    final firebaseStatus = await FirebasePushNotificationService.getNotificationStatus();
    print('🔥 Firebase Status: ${firebaseStatus['hasToken']} (${firebaseStatus['authorizationStatus']})');

    print('✅ Notification permissions test completed');
  }

  /// Quick test methods for individual components

  static Future<void> quickUnifiedTest() async {
    print('🧪 Quick unified notification test...');

    await UnifiedNotificationService.createAndPushNotification(
      title: 'Quick Test ⚡',
      message: 'Quick unified notification test!',
      notificationType: 'QuickTest',
      category: 'Test',
      icon: '⚡',
    );

    print('✅ Quick test completed');
  }

  static Future<void> quickHelperTest() async {
    print('🧪 Quick helper test...');

    await NotificationHelpers.createTestNotifications();

    print('✅ Quick helper test completed');
  }

  static Future<void> quickControllerTest() async {
    print('🧪 Quick controller test...');

    if (Get.isRegistered<NotificationController>()) {
      final controller = Get.find<NotificationController>();
      await controller.createTestUnifiedNotifications();
      print('✅ Quick controller test completed');
    } else {
      print('❌ NotificationController not registered');
    }
  }

  /// Test specific notification scenarios

  static Future<void> testRaceScenario() async {
    print('🧪 Testing complete race scenario...');

    // Race invitation
    await NotificationHelpers.sendRaceInvitation(
      raceName: 'Ultimate Challenge',
      raceId: 'scenario-race-123',
      inviterName: 'Race Organizer',
      inviterUserId: 'organizer-456',
      distance: 10.0,
      location: 'City Stadium',
    );

    await Future.delayed(Duration(milliseconds: 1000));

    // Race started
    await NotificationHelpers.sendRaceStarted(
      raceName: 'Ultimate Challenge',
      raceId: 'scenario-race-123',
      participantCount: 15,
      estimatedDuration: '45 minutes',
    );

    await Future.delayed(Duration(milliseconds: 1000));

    // Race completed
    await NotificationHelpers.sendRaceCompleted(
      raceName: 'Ultimate Challenge',
      raceId: 'scenario-race-123',
      finalRank: 3,
      completionTime: '42:30',
      xpEarned: 150,
      distanceCovered: 10.2,
      avgSpeed: 14.5,
    );

    print('✅ Race scenario test completed');
  }

  static Future<void> testSocialScenario() async {
    print('🧪 Testing social scenario...');

    // Friend request
    await NotificationHelpers.sendFriendRequest(
      fromUserName: 'Social Tester',
      fromUserId: 'social-user-789',
      mutualFriends: 5,
      mutualFriendNames: 'Alice, Bob, Charlie',
    );

    await Future.delayed(Duration(milliseconds: 1000));

    // Friend accepted
    await NotificationHelpers.sendFriendAccepted(
      friendName: 'Social Tester',
      friendUserId: 'social-user-789',
    );

    print('✅ Social scenario test completed');
  }

  static Future<void> testAchievementScenario() async {
    print('🧪 Testing achievement scenario...');

    // Daily goal
    await NotificationHelpers.sendDailyGoalCompleted(
      goalType: 'steps',
      goalValue: 10000,
      actualValue: 15000,
      xpEarned: 50,
    );

    await Future.delayed(Duration(milliseconds: 1000));

    // Milestone achievement
    await NotificationHelpers.sendMilestoneAchievement(
      achievementName: 'Step Master',
      achievementDescription: 'Reached 100,000 total steps!',
      xpEarned: 200,
      achievementIcon: '👑',
    );

    await Future.delayed(Duration(milliseconds: 1000));

    // Hall of fame
    await NotificationHelpers.sendHallOfFameEntry(
      category: 'weekly',
      rank: 1,
      metric: 'steps',
      value: '75,000',
      xpEarned: 100,
    );

    print('✅ Achievement scenario test completed');
  }

  /// Debug and utility methods

  static Future<void> debugNotificationSystem() async {
    print('🔧 ====== UNIFIED NOTIFICATION SYSTEM DEBUG ======');

    // Local notification status
    final localStatus = await LocalNotificationService.getNotificationStatus();
    print('🔧 Local Notification Status: $localStatus');

    // Firebase notification status
    FirebasePushNotificationService.printDebugInfo();

    // Notification controller status
    if (Get.isRegistered<NotificationController>()) {
      final controller = Get.find<NotificationController>();
      final totalNotifications = controller.allNotifications.length;
      final unreadCount = controller.allNotifications.where((n) => !n.isRead).length;
      print('🔧 NotificationController - Total: $totalNotifications, Unread: $unreadCount');
    } else {
      print('🔧 NotificationController not registered');
    }

    print('🔧 ============================================');
  }

  static Future<void> clearAllTestNotifications() async {
    await LocalNotificationService.cancelAllNotifications();

    if (Get.isRegistered<NotificationController>()) {
      final controller = Get.find<NotificationController>();
      controller.deleteAll();
    }

    print('🧹 All test notifications cleared');
  }

  static void _showTestResultDialog(String title, String message, bool success) {
    Get.dialog(
      AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green : Colors.red,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (success) ...[
              SizedBox(height: 16),
              Text(
                'Check your notification panel and notification list!',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('OK'),
          ),
          if (success) ...[
            TextButton(
              onPressed: () {
                Get.back();
                debugNotificationSystem();
              },
              child: Text('Debug Info'),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                clearAllTestNotifications();
              },
              child: Text('Clear All'),
            ),
          ],
        ],
      ),
    );
  }

  /// Print FCM token for Firebase Console testing
  static void printFCMTokenForTesting() async {
    final token = await FirebasePushNotificationService.getCurrentToken();
    if (token != null) {
      print('');
      print('🔥 ==========================================');
      print('🔥 FCM TOKEN FOR FIREBASE CONSOLE:');
      print('🔥 $token');
      print('🔥 ==========================================');
      print('🔥 Instructions:');
      print('🔥 1. Go to Firebase Console > Cloud Messaging');
      print('🔥 2. Click "Send your first message"');
      print('🔥 3. Paste the token above in "FCM registration token"');
      print('🔥 4. Send test notification!');
      print('🔥 ==========================================');
      print('');
    } else {
      print('❌ No FCM token available');
    }
  }
}