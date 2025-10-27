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

  /// Send race creation confirmation notification
  static Future<void> sendRaceCreationConfirmation({
    required String raceName,
    required String raceType,
    required double distance,
    required String scheduledTime,
    required int participantCount,
  }) async {
    final title = 'Race Created Successfully! 🎉';

    String message;
    if (raceType == 'Solo') {
      message = 'Your solo race "$raceName" is ready! Distance: ${distance.toStringAsFixed(1)}km. Start whenever you\'re ready!';
    } else {
      message = 'Your $raceType race "$raceName" is live! Distance: ${distance.toStringAsFixed(1)}km. Scheduled for $scheduledTime.';
    }

    final metadata = <String, dynamic>{
      'raceType': raceType,
      'distance': distance,
      'scheduledTime': scheduledTime,
      'participantCount': participantCount,
      'createdAt': DateTime.now().toIso8601String(),
    };

    await UnifiedNotificationService.createAndPushNotification(
      title: title,
      message: message,
      notificationType: 'RaceCreated',
      category: 'Race',
      icon: '🎉',
      raceName: raceName,
      metadata: metadata,
    );

    print('🎉 Race creation confirmation sent: $raceName ($raceType)');
  }

  /// Send race reminder notification (for upcoming races)
  static Future<void> sendRaceReminder({
    required String raceName,
    required String raceId,
    required String startTime,
    String reminderType = '15min', // 15min, 1hour, 1day
  }) async {
    String title;
    String message;

    switch (reminderType) {
      case '15min':
        title = 'Race Starting Soon! ⏰';
        message = '"$raceName" starts in 15 minutes. Get ready!';
        break;
      case '1hour':
        title = 'Race Reminder 🕐';
        message = '"$raceName" starts in 1 hour. Don\'t forget!';
        break;
      case '1day':
        title = 'Race Tomorrow 📅';
        message = '"$raceName" is scheduled for tomorrow at $startTime.';
        break;
      default:
        title = 'Race Reminder ⏰';
        message = '"$raceName" is coming up!';
    }

    final metadata = <String, dynamic>{
      'reminderType': reminderType,
      'startTime': startTime,
      'reminderSentAt': DateTime.now().toIso8601String(),
    };

    await UnifiedNotificationService.createAndPushNotification(
      title: title,
      message: message,
      notificationType: 'RaceReminder',
      category: 'Race',
      icon: '⏰',
      raceId: raceId,
      raceName: raceName,
      metadata: metadata,
    );

    print('⏰ Race reminder sent: $raceName ($reminderType)');
  }

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

  // MARK: - Achievement notifications

  /// Send milestone achievement notification
  static Future<void> sendMilestoneAchievement({
    required String achievementName,
    required String achievementDescription,
    required int xpEarned,
    String? achievementIcon,
    String? achievementImage,
    Map<String, dynamic>? milestoneData,
  }) async {
    final title = 'Achievement Unlocked! ${achievementIcon ?? '🏆'}';
    final message = 'You earned "$achievementName"! $achievementDescription';

    final metadata = <String, dynamic>{
      'achievementName': achievementName,
      'achievementDescription': achievementDescription,
      'unlockedAt': DateTime.now().toIso8601String(),
      ...?milestoneData,
    };

    await UnifiedNotificationService.sendAchievementNotification(
      title: title,
      message: message,
      type: 'Milestone',
      xpEarned: xpEarned,
      additionalMetadata: metadata,
    );

    print('🏆 Milestone achievement notification sent: $achievementName');
  }

  /// Send daily goal achievement notification
  static Future<void> sendDailyGoalCompleted({
    required String goalType, // steps, distance, calories
    required int goalValue,
    required int actualValue,
    int? xpEarned,
  }) async {
    String title;
    String message;
    String icon;

    switch (goalType.toLowerCase()) {
      case 'steps':
        title = 'Daily Steps Goal! 👟';
        message = 'You reached your daily goal of $goalValue steps!';
        icon = '👟';
        break;
      case 'distance':
        title = 'Distance Goal! 🏃‍♀️';
        message = 'You covered your daily goal of $goalValue km!';
        icon = '🏃‍♀️';
        break;
      case 'calories':
        title = 'Calorie Goal! 🔥';
        message = 'You burned your daily goal of $goalValue calories!';
        icon = '🔥';
        break;
      default:
        title = 'Daily Goal Completed! ⭐';
        message = 'You achieved your daily $goalType goal!';
        icon = '⭐';
    }

    final metadata = <String, dynamic>{
      'goalType': goalType,
      'goalValue': goalValue,
      'actualValue': actualValue,
      'completedAt': DateTime.now().toIso8601String(),
    };

    await UnifiedNotificationService.createAndPushNotification(
      title: title,
      message: message,
      notificationType: 'DailyGoal',
      category: 'Achievement',
      icon: icon,
      metadata: {
        'xpEarned': xpEarned,
        ...metadata,
      },
    );

    print('⭐ Daily goal notification sent: $goalType ($goalValue)');
  }

  /// Send hall of fame notification
  static Future<void> sendHallOfFameEntry({
    required String category, // weekly, monthly, all-time
    required int rank,
    required String metric, // steps, distance, races_won
    required String value,
    int? xpEarned,
  }) async {
    final title = 'Hall of Fame! 🌟';
    final message = 'You\'re #$rank in $category $metric with $value!';

    final metadata = <String, dynamic>{
      'category': category,
      'rank': rank,
      'metric': metric,
      'value': value,
      'enteredAt': DateTime.now().toIso8601String(),
    };

    await UnifiedNotificationService.sendAchievementNotification(
      title: title,
      message: message,
      type: 'HallOfFame',
      xpEarned: xpEarned,
      additionalMetadata: metadata,
    );

    print('🌟 Hall of Fame notification sent: #$rank in $category $metric');
  }

  // MARK: - Marathon notifications

  /// Send marathon event notification
  static Future<void> sendMarathonEvent({
    required String marathonName,
    required String eventType, // started, milestone, completed
    String? description,
    int? participantCount,
    String? timeRemaining,
    Map<String, dynamic>? marathonData,
  }) async {
    String title;
    String message;
    String icon;

    switch (eventType.toLowerCase()) {
      case 'started':
        title = 'Marathon Started! 🏃‍♀️';
        message = '$marathonName has begun! Join now!';
        icon = '🏃‍♀️';
        break;
      case 'milestone':
        title = 'Marathon Milestone! 🎯';
        message = description ?? 'Milestone reached in $marathonName!';
        icon = '🎯';
        break;
      case 'completed':
        title = 'Marathon Completed! 🏁';
        message = '$marathonName has ended. Check your results!';
        icon = '🏁';
        break;
      default:
        title = 'Marathon Update 🏃‍♀️';
        message = description ?? 'Update for $marathonName';
        icon = '🏃‍♀️';
    }

    final metadata = <String, dynamic>{
      'marathonName': marathonName,
      'eventType': eventType,
      if (participantCount != null) 'participantCount': participantCount,
      if (timeRemaining != null) 'timeRemaining': timeRemaining,
      'eventTime': DateTime.now().toIso8601String(),
      ...?marathonData,
    };

    await UnifiedNotificationService.createAndPushNotification(
      title: title,
      message: message,
      notificationType: eventType.toLowerCase() == 'completed' ? 'Marathon' : 'ActiveMarathon',
      category: 'Marathon',
      icon: icon,
      metadata: metadata,
    );

    print('🏃‍♀️ Marathon notification sent: $marathonName ($eventType)');
  }

  // MARK: - System notifications

  /// Send app update notification
  static Future<void> sendAppUpdate({
    required String version,
    required String updateDescription,
    bool isRequired = false,
  }) async {
    final title = isRequired ? 'App Update Required! ⚠️' : 'App Update Available! 🔄';
    final message = 'Version $version is now available. $updateDescription';

    await UnifiedNotificationService.sendGeneralNotification(
      title: title,
      message: message,
      icon: isRequired ? '⚠️' : '🔄',
      metadata: {
        'version': version,
        'description': updateDescription,
        'required': isRequired,
        'notifiedAt': DateTime.now().toIso8601String(),
      },
    );

    print('🔄 App update notification sent: $version (Required: $isRequired)');
  }

  /// Send maintenance notification
  static Future<void> sendMaintenanceNotification({
    required String maintenanceType, // scheduled, emergency, completed
    required DateTime scheduledTime,
    String? duration,
    String? description,
  }) async {
    String title;
    String message;

    switch (maintenanceType.toLowerCase()) {
      case 'scheduled':
        title = 'Scheduled Maintenance 🔧';
        message = 'App maintenance scheduled for ${_formatDateTime(scheduledTime)}';
        break;
      case 'emergency':
        title = 'Emergency Maintenance ⚠️';
        message = 'Emergency maintenance in progress. Service may be interrupted.';
        break;
      case 'completed':
        title = 'Maintenance Complete ✅';
        message = 'Maintenance has been completed. All services are restored.';
        break;
      default:
        title = 'Maintenance Notice 🔧';
        message = description ?? 'System maintenance notification';
    }

    await UnifiedNotificationService.sendGeneralNotification(
      title: title,
      message: message,
      icon: maintenanceType.toLowerCase() == 'emergency' ? '⚠️' : '🔧',
      metadata: {
        'maintenanceType': maintenanceType,
        'scheduledTime': scheduledTime.toIso8601String(),
        if (duration != null) 'duration': duration,
        if (description != null) 'description': description,
        'notifiedAt': DateTime.now().toIso8601String(),
      },
    );

    print('🔧 Maintenance notification sent: $maintenanceType');
  }

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

    // Test achievement
    await sendMilestoneAchievement(
      achievementName: 'First 5K',
      achievementDescription: 'Completed your first 5K run!',
      xpEarned: 100,
      achievementIcon: '🏃‍♂️',
    );

    await Future.delayed(Duration(milliseconds: 500));

    // Test friend request
    await sendFriendRequest(
      fromUserName: 'Sarah Johnson',
      fromUserId: 'user-456',
      mutualFriends: 3,
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