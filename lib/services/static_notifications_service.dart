import '../models/notification_model.dart';

class StaticNotificationsService {
  static List<NotificationModel> getAllNotifications() {
    return [
      // Race Invite Notifications
      NotificationModel(
        id: 1,
        title: 'Race Invitation',
        message: 'Alex Johnson invited you to join "Morning Sprint 5K" race',
        category: 'Race Invites',
        notificationType: 'InviteRace',
        icon: '🏃‍♂️',
        time: '2 min ago',
        thumbnail: 'assets/icons/user_placeholder.svg',
        userId: 'user_alex_123',
        userName: 'Alex Johnson',
        raceId: 'race_morning_5k',
        raceName: 'Morning Sprint 5K',
        metadata: {
          'distance': '5.0',
          'startTime': '08:00 AM',
          'participants': 12,
        },
        isRead: false,
      ),

      NotificationModel(
        id: 2,
        title: 'Race Invitation',
        message: 'Sarah Miller wants you to join "Evening Jog" tomorrow',
        category: 'Race Invites',
        notificationType: 'InviteRace',
        icon: '🏃‍♀️',
        time: '15 min ago',
        thumbnail: 'assets/icons/user_placeholder.svg',
        userId: 'user_sarah_456',
        userName: 'Sarah Miller',
        raceId: 'race_evening_jog',
        raceName: 'Evening Jog',
        metadata: {
          'distance': '3.2',
          'startTime': '06:30 PM',
          'participants': 8,
        },
        isRead: true,
      ),

      // Race Participant Notifications
      NotificationModel(
        id: 3,
        title: 'New Participant',
        message: 'Mike Davis joined your "Weekend Challenge" race',
        category: 'Race Updates',
        notificationType: 'RaceParticipant',
        icon: '👥',
        time: '5 min ago',
        thumbnail: 'assets/icons/user_placeholder.svg',
        userId: 'user_mike_789',
        userName: 'Mike Davis',
        raceId: 'race_weekend_challenge',
        raceName: 'Weekend Challenge',
        metadata: {
          'totalParticipants': 15,
          'rank': 15,
        },
        isRead: false,
      ),

      // Race Begin Notifications
      NotificationModel(
        id: 4,
        title: 'Race Started!',
        message: '"City Marathon 2024" has begun. Good luck!',
        category: 'Race Updates',
        notificationType: 'RaceBegin',
        icon: '🚀',
        time: '1 min ago',
        thumbnail: 'assets/icons/race_invite.svg',
        raceId: 'race_city_marathon',
        raceName: 'City Marathon 2024',
        metadata: {
          'distance': '42.2',
          'participants': 156,
          'yourRank': 45,
        },
        isRead: false,
      ),

      // Overtaking Notifications
      NotificationModel(
        id: 5,
        title: 'You\'ve Been Overtaken!',
        message: 'Jessica Brown passed you in "Morning Sprint 5K"',
        category: 'Race Updates',
        notificationType: 'OvertakingParticipant',
        icon: '💨',
        time: '3 min ago',
        thumbnail: 'assets/icons/user_placeholder.svg',
        userId: 'user_jessica_321',
        userName: 'Jessica Brown',
        raceId: 'race_morning_5k',
        raceName: 'Morning Sprint 5K',
        metadata: {
          'yourRank': 8,
          'previousRank': 7,
          'totalParticipants': 12,
        },
        isRead: false,
      ),

      NotificationModel(
        id: 6,
        title: 'Great Overtaking!',
        message: 'You overtook Tom Wilson in "Evening Jog"',
        category: 'Race Updates',
        notificationType: 'OvertakingParticipant',
        icon: '⚡',
        time: '8 min ago',
        thumbnail: 'assets/icons/user_placeholder.svg',
        userId: 'user_tom_654',
        userName: 'Tom Wilson',
        raceId: 'race_evening_jog',
        raceName: 'Evening Jog',
        metadata: {
          'yourRank': 3,
          'previousRank': 4,
          'totalParticipants': 8,
        },
        isRead: true,
      ),

      // Race Won Notifications
      NotificationModel(
        id: 7,
        title: 'Congratulations! 🎉',
        message: 'You won the "Quick Sprint Challenge"!',
        category: 'Achievements',
        notificationType: 'RaceWon',
        icon: '🏆',
        time: '30 min ago',
        thumbnail: 'assets/icons/winner_cup.svg',
        raceId: 'race_quick_sprint',
        raceName: 'Quick Sprint Challenge',
        metadata: {
          'rank': 1,
          'totalParticipants': 20,
          'time': '24:35',
          'distance': '5.0',
          'xpEarned': 150,
        },
        isRead: false,
      ),

      // Race Winner Crossing Finish Line
      NotificationModel(
        id: 8,
        title: 'Race Winner!',
        message: 'Carlos Rodriguez finished first in "City Marathon 2024"',
        category: 'Race Updates',
        notificationType: 'RaceWinnerCrossing',
        icon: '🥇',
        time: '45 min ago',
        thumbnail: 'assets/icons/user_placeholder.svg',
        userId: 'user_carlos_987',
        userName: 'Carlos Rodriguez',
        raceId: 'race_city_marathon',
        raceName: 'City Marathon 2024',
        metadata: {
          'finishTime': '2:15:43',
          'distance': '42.2',
          'totalParticipants': 156,
        },
        isRead: true,
      ),

      // End Timer Notifications
      NotificationModel(
        id: 9,
        title: 'Race Ending Soon!',
        message: '"Weekend Challenge" will end in 10 minutes',
        category: 'Race Updates',
        notificationType: 'EndTimer',
        icon: '⏰',
        time: '2 min ago',
        thumbnail: 'assets/icons/timer_icon.svg',
        raceId: 'race_weekend_challenge',
        raceName: 'Weekend Challenge',
        metadata: {
          'timeRemaining': '10 minutes',
          'yourRank': 5,
          'totalParticipants': 15,
        },
        isRead: false,
      ),

      // Friend Request Notifications
      NotificationModel(
        id: 10,
        title: 'Friend Request',
        message: 'Emma Thompson wants to be your friend',
        category: 'Friends',
        notificationType: 'FriendRequest',
        icon: '👋',
        time: '1 hour ago',
        thumbnail: 'assets/icons/user_placeholder.svg',
        userId: 'user_emma_555',
        userName: 'Emma Thompson',
        metadata: {
          'mutualFriends': 3,
          'totalRaces': 25,
        },
        isRead: false,
      ),

      NotificationModel(
        id: 11,
        title: 'Friend Request Accepted',
        message: 'David Chen accepted your friend request',
        category: 'Friends',
        notificationType: 'FriendRequest',
        icon: '✅',
        time: '2 hours ago',
        thumbnail: 'assets/icons/user_placeholder.svg',
        userId: 'user_david_777',
        userName: 'David Chen',
        metadata: {
          'status': 'accepted',
        },
        isRead: true,
      ),

      // Race Over Notifications
      NotificationModel(
        id: 12,
        title: 'Race Completed',
        message: '"Morning Sprint 5K" has ended. Check your results!',
        category: 'Race Updates',
        notificationType: 'RaceOver',
        icon: '🏁',
        time: '1 hour ago',
        thumbnail: 'assets/icons/race_invite.svg',
        raceId: 'race_morning_5k',
        raceName: 'Morning Sprint 5K',
        metadata: {
          'yourRank': 8,
          'totalParticipants': 12,
          'distance': '5.0',
          'time': '28:45',
          'xpEarned': 75,
        },
        isRead: true,
      ),

      // Marathon Notifications
      NotificationModel(
        id: 13,
        title: 'Marathon Starting Soon!',
        message: '"City Marathon 2024" starts in 30 minutes',
        category: 'Marathon',
        notificationType: 'Marathon',
        icon: '🏃‍♂️',
        time: '30 min ago',
        thumbnail: 'assets/icons/race_invite.svg',
        raceId: 'race_city_marathon',
        raceName: 'City Marathon 2024',
        metadata: {
          'distance': '42.2',
          'startTime': '07:00 AM',
          'participants': 156,
          'weather': 'Sunny, 18°C',
        },
        isRead: false,
      ),

      NotificationModel(
        id: 14,
        title: 'Active Marathon',
        message: 'You\'re currently 45th in "City Marathon 2024"',
        category: 'Marathon',
        notificationType: 'ActiveMarathon',
        icon: '🏃‍♂️',
        time: '5 min ago',
        thumbnail: 'assets/icons/race_invite.svg',
        raceId: 'race_city_marathon',
        raceName: 'City Marathon 2024',
        metadata: {
          'currentRank': 45,
          'totalParticipants': 156,
          'distanceCovered': '15.2',
          'totalDistance': '42.2',
          'pace': '5:45 /km',
        },
        isRead: false,
      ),

      // Hall of Fame Notifications
      NotificationModel(
        id: 15,
        title: 'Hall of Fame Achievement!',
        message: 'You\'ve earned the "Speed Demon" badge for completing 10 races under 25 minutes',
        category: 'Hall of Fame',
        notificationType: 'HallOfFame',
        icon: '🌟',
        time: '3 hours ago',
        thumbnail: 'assets/icons/hall_of_fame.svg',
        metadata: {
          'badgeName': 'Speed Demon',
          'requirement': '10 races under 25 minutes',
          'xpEarned': 200,
          'currentXP': 1250,
        },
        isRead: true,
      ),

      NotificationModel(
        id: 16,
        title: 'Leaderboard Update',
        message: 'You\'ve moved up to #3 in the weekly leaderboard!',
        category: 'Hall of Fame',
        notificationType: 'HallOfFame',
        icon: '📈',
        time: '4 hours ago',
        thumbnail: 'assets/icons/hall_of_fame.svg',
        metadata: {
          'newRank': 3,
          'previousRank': 7,
          'totalSteps': 45230,
          'weeklyXP': 450,
        },
        isRead: false,
      ),

      // General Notifications
      NotificationModel(
        id: 17,
        title: 'Welcome to StepzSync!',
        message: 'Complete your profile to start your fitness journey',
        category: 'General',
        notificationType: 'General',
        icon: '🎉',
        time: '1 day ago',
        isRead: true,
      ),

      NotificationModel(
        id: 18,
        title: 'Daily Goal Achieved!',
        message: 'Congratulations! You\'ve reached your 10,000 steps goal today',
        category: 'General',
        notificationType: 'General',
        icon: '🎯',
        time: '5 hours ago',
        metadata: {
          'steps': 10000,
          'distance': '7.2',
          'calories': 420,
        },
        isRead: true,
      ),
    ];
  }

  // Filter notifications by read status
  static List<NotificationModel> getFilteredNotifications(bool? isRead) {
    final allNotifications = getAllNotifications();
    if (isRead == null) return allNotifications;
    return allNotifications.where((n) => n.isRead == isRead).toList();
  }

  // Get notifications by type
  static List<NotificationModel> getNotificationsByType(String type) {
    return getAllNotifications().where((n) => n.notificationType == type).toList();
  }

  // Get notifications by category
  static List<NotificationModel> getNotificationsByCategory(String category) {
    return getAllNotifications().where((n) => n.category == category).toList();
  }
}