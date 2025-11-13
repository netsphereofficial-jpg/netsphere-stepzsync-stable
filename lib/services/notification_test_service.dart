import 'package:flutter/material.dart';
import 'local_notification_service.dart';

/// Comprehensive notification test service
/// Tests all notification types and deep linking functionality
class NotificationTestService {
  /// Test all notification types sequentially with delays
  static Future<void> testAllNotifications({int delaySeconds = 3}) async {
    print('🧪 ===== STARTING COMPREHENSIVE NOTIFICATION TEST =====');
    print('🧪 Testing all 24 notification types with deep linking');
    print('🧪 Delay between notifications: ${delaySeconds}s');
    print('');

    // Test Race Notifications (16 types)
    await _testRaceNotifications(delaySeconds);

    // Test Social/Friend Notifications (4 types)
    await _testSocialNotifications(delaySeconds);

    // Test Chat Notifications (2 types)
    await _testChatNotifications(delaySeconds);

    // Test Special Notifications
    await _testSpecialNotifications(delaySeconds);

    print('');
    print('🧪 ===== NOTIFICATION TEST COMPLETED =====');
    print('🧪 Total notifications sent: 24');
    print('🧪 Tap each notification to test deep linking!');
  }

  /// Test only race-related notifications
  static Future<void> testRaceNotificationsOnly() async {
    print('🧪 Testing Race Notifications Only...');
    await _testRaceNotifications(2);
    print('🧪 Race notifications test completed!');
  }

  /// Test only social/friend notifications
  static Future<void> testSocialNotificationsOnly() async {
    print('🧪 Testing Social Notifications Only...');
    await _testSocialNotifications(2);
    print('🧪 Social notifications test completed!');
  }

  // ===== RACE NOTIFICATIONS TEST (16 types) =====

  static Future<void> _testRaceNotifications(int delay) async {
    print('📍 === TESTING RACE NOTIFICATIONS (16 types) ===\n');

    // 1. Race Invitation
    await _sendTestNotification(
      title: '🏃‍♂️ Race Invitation',
      message: 'John invited you to "Morning 5K Run"',
      type: 'InviteRace',
      category: 'Race',
      icon: '🏃‍♂️',
      raceId: 'test_race_001',
      raceName: 'Morning 5K Run',
      expectedRoute: '/race',
    );
    await Future.delayed(Duration(seconds: delay));

    // 2. Race Started
    await _sendTestNotification(
      title: '🚀 Race Started!',
      message: '"Morning 5K Run" has begun! Good luck!',
      type: 'RaceBegin',
      category: 'Race',
      icon: '🚀',
      raceId: 'test_race_001',
      raceName: 'Morning 5K Run',
      expectedRoute: '/active-races',
    );
    await Future.delayed(Duration(seconds: delay));

    // 3. Race Completed
    await _sendTestNotification(
      title: '🏁 Race Completed!',
      message: 'You finished in 2nd place! +75 XP earned',
      type: 'RaceCompleted',
      category: 'Race',
      icon: '🏁',
      raceId: 'test_race_001',
      raceName: 'Morning 5K Run',
      expectedRoute: '/active-races (showResults)',
    );
    await Future.delayed(Duration(seconds: delay));

    // 4. Race Won
    await _sendTestNotification(
      title: '🏆 Victory!',
      message: 'You won "Morning 5K Run"! +100 XP',
      type: 'RaceWon',
      category: 'Achievement',
      icon: '🏆',
      raceId: 'test_race_001',
      raceName: 'Morning 5K Run',
      expectedRoute: '/active-races (showResults)',
    );
    await Future.delayed(Duration(seconds: delay));

    // 5. Invite Accepted
    await _sendTestNotification(
      title: '🎉 Invite Accepted',
      message: 'Sarah accepted your race invitation!',
      type: 'InviteAccepted',
      category: 'Race',
      icon: '🎉',
      raceId: 'test_race_001',
      raceName: 'Morning 5K Run',
      expectedRoute: '/race',
    );
    await Future.delayed(Duration(seconds: delay));

    // 6. Invite Declined
    await _sendTestNotification(
      title: '😔 Invite Declined',
      message: 'Mike declined your race invitation',
      type: 'InviteDeclined',
      category: 'Race',
      icon: '😔',
      raceId: 'test_race_001',
      raceName: 'Morning 5K Run',
      expectedRoute: '/race',
    );
    await Future.delayed(Duration(seconds: delay));

    // 7. Participant Joined
    await _sendTestNotification(
      title: '🎉 New Participant',
      message: 'Alex joined "Morning 5K Run"',
      type: 'RaceParticipantJoined',
      category: 'Race',
      icon: '🎉',
      raceId: 'test_race_001',
      raceName: 'Morning 5K Run',
      expectedRoute: '/race',
    );
    await Future.delayed(Duration(seconds: delay));

    // 8. Overtaking
    await _sendTestNotification(
      title: '🚀 You\'re Overtaking!',
      message: 'You passed Sarah! Now in 2nd place',
      type: 'RaceOvertaking',
      category: 'Achievement',
      icon: '🚀',
      raceId: 'test_race_001',
      raceName: 'Morning 5K Run',
      expectedRoute: '/active-races (leaderboard)',
    );
    await Future.delayed(Duration(seconds: delay));

    // 9. Overtaken
    await _sendTestNotification(
      title: '⚡ Overtaken!',
      message: 'John passed you! You\'re now in 3rd place',
      type: 'RaceOvertaken',
      category: 'Race',
      icon: '⚡',
      raceId: 'test_race_001',
      raceName: 'Morning 5K Run',
      expectedRoute: '/active-races (leaderboard)',
    );
    await Future.delayed(Duration(seconds: delay));

    // 10. Overtaking General
    await _sendTestNotification(
      title: '🏃‍♂️ Position Change',
      message: 'Sarah overtook Mike in the race!',
      type: 'RaceOvertakingGeneral',
      category: 'Race',
      icon: '🏃‍♂️',
      raceId: 'test_race_001',
      raceName: 'Morning 5K Run',
      expectedRoute: '/active-races (leaderboard)',
    );
    await Future.delayed(Duration(seconds: delay));

    // 11. Leader Change
    await _sendTestNotification(
      title: '👑 New Leader!',
      message: 'John is now leading the race!',
      type: 'RaceLeaderChange',
      category: 'Race',
      icon: '👑',
      raceId: 'test_race_001',
      raceName: 'Morning 5K Run',
      expectedRoute: '/active-races (leaderboard)',
    );
    await Future.delayed(Duration(seconds: delay));

    // 12. First Finisher
    await _sendTestNotification(
      title: '🏁 First to Finish!',
      message: 'You\'re the first to complete the race!',
      type: 'RaceFirstFinisher',
      category: 'Achievement',
      icon: '🏁',
      raceId: 'test_race_001',
      raceName: 'Morning 5K Run',
      expectedRoute: '/active-races (showResults)',
    );
    await Future.delayed(Duration(seconds: delay));

    // 13. Deadline Alert
    await _sendTestNotification(
      title: '⏰ Deadline Alert!',
      message: 'You have 30 minutes to complete the race!',
      type: 'RaceDeadlineAlert',
      category: 'Race',
      icon: '⏰',
      raceId: 'test_race_001',
      raceName: 'Morning 5K Run',
      expectedRoute: '/active-races',
    );
    await Future.delayed(Duration(seconds: delay));

    // 14. Countdown Timer
    await _sendTestNotification(
      title: '⏰ 5 Minutes Left!',
      message: 'Only 5 minutes remaining in the race!',
      type: 'RaceCountdownTimer',
      category: 'Race',
      icon: '⏰',
      raceId: 'test_race_001',
      raceName: 'Morning 5K Run',
      expectedRoute: '/active-races',
    );
    await Future.delayed(Duration(seconds: delay));

    // 15. Race Cancelled
    await _sendTestNotification(
      title: '❌ Race Cancelled',
      message: '"Evening Sprint" has been cancelled by organizer',
      type: 'RaceCancelled',
      category: 'Race',
      icon: '❌',
      raceId: 'test_race_002',
      raceName: 'Evening Sprint',
      expectedRoute: '/HomeScreen',
    );
    await Future.delayed(Duration(seconds: delay));

    // 16. Proximity Alert
    await _sendTestNotification(
      title: '🔥 Competitor Nearby!',
      message: 'Sarah is only 20m behind you!',
      type: 'RaceProximityAlert',
      category: 'Race',
      icon: '🔥',
      raceId: 'test_race_001',
      raceName: 'Morning 5K Run',
      expectedRoute: '/active-races',
    );
    await Future.delayed(Duration(seconds: delay));

    print('✅ Race notifications test completed!\n');
  }

  // ===== SOCIAL/FRIEND NOTIFICATIONS TEST (4 types) =====

  static Future<void> _testSocialNotifications(int delay) async {
    print('📍 === TESTING SOCIAL/FRIEND NOTIFICATIONS (4 types) ===\n');

    // 17. Friend Request
    await _sendTestNotification(
      title: '👥 New Friend Request',
      message: 'Emma wants to be your friend',
      type: 'FriendRequest',
      category: 'Social',
      icon: '👥',
      userId: 'test_user_001',
      userName: 'Emma Wilson',
      expectedRoute: '/friends (requests tab)',
    );
    await Future.delayed(Duration(seconds: delay));

    // 18. Friend Accepted
    await _sendTestNotification(
      title: '🎉 Friend Request Accepted',
      message: 'David accepted your friend request!',
      type: 'FriendAccepted',
      category: 'Social',
      icon: '🎉',
      userId: 'test_user_002',
      userName: 'David Chen',
      expectedRoute: '/friends',
    );
    await Future.delayed(Duration(seconds: delay));

    // 19. Friend Removed
    await _sendTestNotification(
      title: '💔 Friend Removed',
      message: 'Lisa removed you from their friends list',
      type: 'FriendRemoved',
      category: 'Social',
      icon: '💔',
      userId: 'test_user_003',
      userName: 'Lisa Martinez',
      expectedRoute: '/friends',
    );
    await Future.delayed(Duration(seconds: delay));

    // 20. Friend Declined
    await _sendTestNotification(
      title: '😔 Friend Request Declined',
      message: 'Tom declined your friend request',
      type: 'FriendDeclined',
      category: 'Social',
      icon: '😔',
      userId: 'test_user_004',
      userName: 'Tom Anderson',
      expectedRoute: '/friends',
    );
    await Future.delayed(Duration(seconds: delay));

    print('✅ Social notifications test completed!\n');
  }

  // ===== CHAT NOTIFICATIONS TEST (2 types) =====

  static Future<void> _testChatNotifications(int delay) async {
    print('📍 === TESTING CHAT NOTIFICATIONS (2 types) ===\n');

    // 21. Direct Chat Message
    await _sendTestNotification(
      title: '💬 New Message from Sarah',
      message: 'Hey! Are you ready for tomorrow\'s race?',
      type: 'ChatMessage',
      category: 'Chat',
      icon: '💬',
      userId: 'test_user_005',
      userName: 'Sarah Johnson',
      expectedRoute: '/friends (messages tab)',
    );
    await Future.delayed(Duration(seconds: delay));

    // 22. Race Chat Message
    await _sendTestNotification(
      title: '🏃 Race Chat: Morning 5K Run',
      message: 'Mike: Good luck everyone!',
      type: 'RaceChatMessage',
      category: 'RaceChat',
      icon: '🏃',
      raceId: 'test_race_001',
      raceName: 'Morning 5K Run',
      expectedRoute: '/race (with chat)',
    );
    await Future.delayed(Duration(seconds: delay));

    print('✅ Chat notifications test completed!\n');
  }

  // ===== SPECIAL NOTIFICATIONS TEST =====

  static Future<void> _testSpecialNotifications(int delay) async {
    print('📍 === TESTING SPECIAL NOTIFICATIONS (2 types) ===\n');

    // 23. Marathon
    await _sendTestNotification(
      title: '🏃‍♀️ Marathon Challenge',
      message: 'New monthly marathon is now active!',
      type: 'Marathon',
      category: 'Marathon',
      icon: '🏃‍♀️',
      expectedRoute: '/marathon',
    );
    await Future.delayed(Duration(seconds: delay));

    // 24. Hall of Fame
    await _sendTestNotification(
      title: '🌟 Hall of Fame Achievement!',
      message: 'You\'ve been added to the Hall of Fame! +200 XP',
      type: 'HallOfFame',
      category: 'Achievement',
      icon: '🌟',
      expectedRoute: '/hall-of-fame',
    );
    await Future.delayed(Duration(seconds: delay));

    print('✅ Special notifications test completed!\n');
  }

  // ===== INDIVIDUAL NOTIFICATION TYPE TESTS =====

  /// Test specific notification type
  static Future<void> testNotificationType(String type) async {
    switch (type) {
      case 'InviteRace':
        await _sendTestNotification(
          title: '🏃‍♂️ Race Invitation',
          message: 'Test race invitation notification',
          type: 'InviteRace',
          category: 'Race',
          icon: '🏃‍♂️',
          raceId: 'test_race_999',
          raceName: 'Test Race',
          expectedRoute: '/race',
        );
        break;

      case 'RaceBegin':
        await _sendTestNotification(
          title: '🚀 Race Started!',
          message: 'Test race has started!',
          type: 'RaceBegin',
          category: 'Race',
          icon: '🚀',
          raceId: 'test_race_999',
          expectedRoute: '/active-races',
        );
        break;

      case 'FriendRequest':
        await _sendTestNotification(
          title: '👥 Friend Request',
          message: 'Test user wants to be your friend',
          type: 'FriendRequest',
          category: 'Social',
          icon: '👥',
          userId: 'test_user_999',
          userName: 'Test User',
          expectedRoute: '/friends (requests)',
        );
        break;

      default:
        print('❌ Unknown notification type: $type');
    }
  }

  // ===== HELPER METHOD =====

  static Future<void> _sendTestNotification({
    required String title,
    required String message,
    required String type,
    required String category,
    required String icon,
    String? raceId,
    String? raceName,
    String? userId,
    String? userName,
    required String expectedRoute,
  }) async {
    print('📱 Sending: $type');
    print('   Title: $title');
    print('   Expected Route: $expectedRoute');

    await LocalNotificationService.sendNotificationAndStore(
      title: title,
      message: message,
      notificationType: type,
      category: category,
      icon: icon,
      raceId: raceId,
      raceName: raceName,
      userId: userId,
      userName: userName,
      sendLocalNotification: true,
      storeInLocal: true,
      storeInFirebase: false, // Don't spam Firestore with test data
    );

    print('   ✅ Sent successfully\n');
  }

  // ===== QUICK TEST METHODS =====

  /// Send one of each category quickly
  static Future<void> quickTest() async {
    print('🧪 Running Quick Test (one from each category)...\n');

    await _sendTestNotification(
      title: '🚀 Race Started!',
      message: 'Quick test race notification',
      type: 'RaceBegin',
      category: 'Race',
      icon: '🚀',
      raceId: 'quick_test_race',
      raceName: 'Quick Test',
      expectedRoute: '/active-races',
    );
    await Future.delayed(Duration(seconds: 2));

    await _sendTestNotification(
      title: '👥 Friend Request',
      message: 'Quick test friend notification',
      type: 'FriendRequest',
      category: 'Social',
      icon: '👥',
      userId: 'quick_test_user',
      userName: 'Quick Tester',
      expectedRoute: '/friends',
    );
    await Future.delayed(Duration(seconds: 2));

    await _sendTestNotification(
      title: '💬 New Message',
      message: 'Quick test chat notification',
      type: 'ChatMessage',
      category: 'Chat',
      icon: '💬',
      userId: 'quick_test_user',
      userName: 'Quick Tester',
      expectedRoute: '/friends (messages)',
    );

    print('\n✅ Quick test completed!');
  }

  /// Print all supported notification types
  static void printAllNotificationTypes() {
    print('📋 ===== ALL SUPPORTED NOTIFICATION TYPES =====\n');

    print('🏁 RACE NOTIFICATIONS (16):');
    print('1.  InviteRace - Race invitation');
    print('2.  RaceBegin - Race started');
    print('3.  RaceCompleted - Race finished (top 3)');
    print('4.  RaceWon - Race won (1st place)');
    print('5.  InviteAccepted - Invite accepted');
    print('6.  InviteDeclined - Invite declined');
    print('7.  RaceParticipantJoined - New participant');
    print('8.  RaceOvertaking - You overtook someone');
    print('9.  RaceOvertaken - Someone overtook you');
    print('10. RaceOvertakingGeneral - Other overtaking');
    print('11. RaceLeaderChange - New leader');
    print('12. RaceFirstFinisher - First to finish');
    print('13. RaceDeadlineAlert - Deadline warning');
    print('14. RaceCountdownTimer - Time remaining alert');
    print('15. RaceCancelled - Race cancelled');
    print('16. RaceProximityAlert - Competitor nearby\n');

    print('👥 SOCIAL NOTIFICATIONS (4):');
    print('17. FriendRequest - New friend request');
    print('18. FriendAccepted - Request accepted');
    print('19. FriendRemoved - Friend removed');
    print('20. FriendDeclined - Request declined\n');

    print('💬 CHAT NOTIFICATIONS (2):');
    print('21. ChatMessage - Direct message');
    print('22. RaceChatMessage - Race group message\n');

    print('🌟 SPECIAL NOTIFICATIONS (2):');
    print('23. Marathon - Marathon challenge');
    print('24. HallOfFame - Hall of Fame achievement\n');

    print('Total: 24 notification types');
    print('=========================================\n');
  }
}
