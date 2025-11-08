import 'package:get/get.dart';
import '../controllers/notification_controller.dart';
import '../services/unified_notification_service.dart';

/// Helper class for common notification scenarios in StepzSync
class NotificationHelpers {

  // Get notification controller
  static NotificationController? get _controller =>
    Get.isRegistered<NotificationController>() ? Get.find<NotificationController>() : null;

  // MARK: - Race-related notifications

  /// Send race invitation notification
  static Future<void> sendRaceInvitation({
    required String raceName,
    required String raceId,
    required String inviterName,
    required String inviterUserId,
    String? startTime,
    double? distance,
    String? location,
  }) async {
    final title = 'Race Invitation 🏃‍♂️';
    final message = '$inviterName invited you to join "$raceName"';

    final metadata = <String, dynamic>{
      'inviterName': inviterName,
      'inviterUserId': inviterUserId,
      if (startTime != null) 'startTime': startTime,
      if (distance != null) 'distance': distance,
      if (location != null) 'location': location,
    };

    await UnifiedNotificationService.sendRaceInviteNotification(
      title: title,
      message: message,
      raceId: raceId,
      raceName: raceName,
      inviterName: inviterName,
      inviterUserId: inviterUserId,
      raceMetadata: metadata,
    );

    print('🏃‍♂️ Race invitation sent: $raceName from $inviterName');
  }

  /// Send race started notification
  static Future<void> sendRaceStarted({
    required String raceName,
    required String raceId,
    int? participantCount,
    String? estimatedDuration,
  }) async {
    final title = 'Race Started! 🚀';
    final message = '"$raceName" has begun! Good luck!';

    final metadata = <String, dynamic>{
      if (participantCount != null) 'participantCount': participantCount,
      if (estimatedDuration != null) 'estimatedDuration': estimatedDuration,
      'startedAt': DateTime.now().toIso8601String(),
    };

    await UnifiedNotificationService.sendRaceStartNotification(
      title: title,
      message: message,
      raceId: raceId,
      raceName: raceName,
      raceMetadata: metadata,
    );

    print('🚀 Race started notification sent: $raceName');
  }

  /// Send race completion notification
  static Future<void> sendRaceCompleted({
    required String raceName,
    required String raceId,
    required int finalRank,
    required String completionTime,
    int? xpEarned,
    double? distanceCovered,
    double? avgSpeed,
  }) async {
    String title;
    String message;

    // Customize message based on rank
    switch (finalRank) {
      case 1:
        title = 'Congratulations! 🥇';
        message = 'You won "$raceName"! Amazing performance!';
        break;
      case 2:
        title = 'Great Job! 🥈';
        message = 'You finished 2nd in "$raceName"! Well done!';
        break;
      case 3:
        title = 'Excellent! 🥉';
        message = 'You finished 3rd in "$raceName"! Great effort!';
        break;
      default:
        title = 'Race Completed! 🏃‍♂️';
        message = 'You finished "$raceName" in ${_ordinal(finalRank)} place!';
    }

    final metadata = <String, dynamic>{
      'completionTime': completionTime,
      'completedAt': DateTime.now().toIso8601String(),
      if (distanceCovered != null) 'distanceCovered': distanceCovered,
      if (avgSpeed != null) 'avgSpeed': avgSpeed,
    };

    await UnifiedNotificationService.sendRaceWonNotification(
      title: title,
      message: message,
      raceId: raceId,
      raceName: raceName,
      rank: finalRank,
      xpEarned: xpEarned,
      additionalMetadata: metadata,
    );

    print('🏃‍♂️ Race completion notification sent: $raceName (Rank: $finalRank)');
  }

  /// ❌ REMOVED: Send race creation confirmation notification
  /// Race creation notifications are no longer sent per requirements
  // static Future<void> sendRaceCreationConfirmation - REMOVED

  /// ❌ REMOVED: Send race reminder notification (for upcoming races)
  /// Race reminder notifications are no longer sent per requirements
  // static Future<void> sendRaceReminder - REMOVED

  // MARK: - Social notifications

  /// Send friend request notification
  static Future<void> sendFriendRequest({
    required String fromUserName,
    required String fromUserId,
    String? fromUserProfilePic,
    int? mutualFriends,
    String? mutualFriendNames,
  }) async {
    final title = 'New Friend Request 👥';
    final message = '$fromUserName wants to be your friend!';

    final metadata = <String, dynamic>{
      if (mutualFriends != null) 'mutualFriends': mutualFriends,
      if (mutualFriendNames != null) 'mutualFriendNames': mutualFriendNames,
      'requestSentAt': DateTime.now().toIso8601String(),
    };

    await UnifiedNotificationService.sendFriendRequestNotification(
      title: title,
      message: message,
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      thumbnail: fromUserProfilePic,
      mutualFriends: mutualFriends,
      additionalMetadata: metadata,
    );

    print('👥 Friend request notification sent from: $fromUserName');
  }

  /// Send friend acceptance notification
  static Future<void> sendFriendAccepted({
    required String friendName,
    required String friendUserId,
    String? friendProfilePic,
  }) async {
    final title = 'Friend Request Accepted! 🎉';
    final message = '$friendName accepted your friend request!';

    await UnifiedNotificationService.createAndPushNotification(
      title: title,
      message: message,
      notificationType: 'FriendAccepted',
      category: 'Social',
      icon: '🎉',
      userId: friendUserId,
      userName: friendName,
      thumbnail: friendProfilePic,
      metadata: {
        'acceptedAt': DateTime.now().toIso8601String(),
      },
    );

    print('🎉 Friend acceptance notification sent: $friendName');
  }

  // ❌ REMOVED: Achievement notifications section
  // Milestone, daily goal, and hall of fame notifications are no longer sent

  // ❌ REMOVED: Marathon notifications section
  // Marathon event notifications are no longer sent

  // ❌ REMOVED: System notifications section
  // App update and maintenance notifications are no longer sent

  // MARK: - Utility methods

  /// Get current unread notification count
  static int getUnreadCount() {
    return _controller?.allNotifications.where((n) => !n.isRead).length ?? 0;
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead() async {
    _controller?.markAllRead();
  }

  /// Create test notifications for debugging
  static Future<void> createTestNotifications() async {
    print('🧪 Creating test notifications...');

    // Test race invitation
    await sendRaceInvitation(
      raceName: 'Morning Run Challenge',
      raceId: 'test-race-123',
      inviterName: 'John Doe',
      inviterUserId: 'user-123',
      distance: 5.0,
      location: 'Central Park',
    );

    await Future.delayed(Duration(milliseconds: 500));

    // Test friend request
    await sendFriendRequest(
      fromUserName: 'Sarah Johnson',
      fromUserId: 'user-456',
      mutualFriends: 3,
    );

    await Future.delayed(Duration(milliseconds: 500));

    // Test friend accepted
    await sendFriendAccepted(
      friendName: 'Mike Wilson',
      friendUserId: 'user-789',
    );

    print('✅ Test notifications created successfully!');
  }

  // MARK: - Helper functions

  /// Convert number to ordinal (1st, 2nd, 3rd, etc.)
  static String _ordinal(int number) {
    if (number >= 11 && number <= 13) {
      return '${number}th';
    }

    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  /// Format DateTime for notifications
  static String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(Duration(days: 1));
    final targetDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (targetDate == today) {
      dateStr = 'today';
    } else if (targetDate == tomorrow) {
      dateStr = 'tomorrow';
    } else {
      dateStr = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }

    final timeStr = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$dateStr at $timeStr';
  }
}