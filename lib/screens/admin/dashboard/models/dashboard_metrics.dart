import 'package:cloud_firestore/cloud_firestore.dart';

/// Dashboard Metrics Models
/// Used for displaying key statistics on admin dashboard

class DashboardMetrics {
  final UserMetrics userMetrics;
  final RaceMetrics raceMetrics;
  final RevenueMetrics revenueMetrics;
  final EngagementMetrics engagementMetrics;

  DashboardMetrics({
    required this.userMetrics,
    required this.raceMetrics,
    required this.revenueMetrics,
    required this.engagementMetrics,
  });
}

class UserMetrics {
  final int totalUsers;
  final int activeUsers;
  final int newUsersToday;
  final int newUsersThisWeek;
  final int newUsersThisMonth;
  final double growthRate; // Percentage
  final int verifiedUsers;
  final int unverifiedUsers;

  UserMetrics({
    required this.totalUsers,
    required this.activeUsers,
    required this.newUsersToday,
    required this.newUsersThisWeek,
    required this.newUsersThisMonth,
    required this.growthRate,
    required this.verifiedUsers,
    required this.unverifiedUsers,
  });

  factory UserMetrics.empty() {
    return UserMetrics(
      totalUsers: 0,
      activeUsers: 0,
      newUsersToday: 0,
      newUsersThisWeek: 0,
      newUsersThisMonth: 0,
      growthRate: 0.0,
      verifiedUsers: 0,
      unverifiedUsers: 0,
    );
  }
}

class RaceMetrics {
  final int totalRaces;
  final int activeRaces;
  final int completedRaces;
  final int scheduledRaces;
  final int totalParticipants;
  final int racesToday;
  final int racesThisWeek;
  final int racesThisMonth;
  final double averageParticipantsPerRace;

  RaceMetrics({
    required this.totalRaces,
    required this.activeRaces,
    required this.completedRaces,
    required this.scheduledRaces,
    required this.totalParticipants,
    required this.racesToday,
    required this.racesThisWeek,
    required this.racesThisMonth,
    required this.averageParticipantsPerRace,
  });

  factory RaceMetrics.empty() {
    return RaceMetrics(
      totalRaces: 0,
      activeRaces: 0,
      completedRaces: 0,
      scheduledRaces: 0,
      totalParticipants: 0,
      racesToday: 0,
      racesThisWeek: 0,
      racesThisMonth: 0,
      averageParticipantsPerRace: 0.0,
    );
  }
}

class RevenueMetrics {
  final double totalRevenue;
  final double monthlyRevenue;
  final double todayRevenue;
  final double averageRevenuePerUser;
  final int totalSubscriptions;
  final int activeSubscriptions;
  final Map<String, int> subscriptionBreakdown; // Free, Premium1, Premium2
  final double growthRate; // Monthly percentage

  RevenueMetrics({
    required this.totalRevenue,
    required this.monthlyRevenue,
    required this.todayRevenue,
    required this.averageRevenuePerUser,
    required this.totalSubscriptions,
    required this.activeSubscriptions,
    required this.subscriptionBreakdown,
    required this.growthRate,
  });

  factory RevenueMetrics.empty() {
    return RevenueMetrics(
      totalRevenue: 0.0,
      monthlyRevenue: 0.0,
      todayRevenue: 0.0,
      averageRevenuePerUser: 0.0,
      totalSubscriptions: 0,
      activeSubscriptions: 0,
      subscriptionBreakdown: {
        'Free': 0,
        'Premium 1': 0,
        'Premium 2': 0,
      },
      growthRate: 0.0,
    );
  }
}

class EngagementMetrics {
  final int dailyActiveUsers;
  final int monthlyActiveUsers;
  final double dau; // DAU/MAU ratio
  final int totalStepsToday;
  final int totalStepsThisWeek;
  final int totalStepsThisMonth;
  final double averageStepsPerUser;
  final int totalSocialInteractions; // Likes, comments, etc.

  EngagementMetrics({
    required this.dailyActiveUsers,
    required this.monthlyActiveUsers,
    required this.dau,
    required this.totalStepsToday,
    required this.totalStepsThisWeek,
    required this.totalStepsThisMonth,
    required this.averageStepsPerUser,
    required this.totalSocialInteractions,
  });

  factory EngagementMetrics.empty() {
    return EngagementMetrics(
      dailyActiveUsers: 0,
      monthlyActiveUsers: 0,
      dau: 0.0,
      totalStepsToday: 0,
      totalStepsThisWeek: 0,
      totalStepsThisMonth: 0,
      averageStepsPerUser: 0.0,
      totalSocialInteractions: 0,
    );
  }
}

/// Chart Data Models

class ChartDataPoint {
  final DateTime date;
  final double value;
  final String? label;

  ChartDataPoint({
    required this.date,
    required this.value,
    this.label,
  });
}

class UserGrowthData {
  final List<ChartDataPoint> dataPoints;
  final double growthRate;

  UserGrowthData({
    required this.dataPoints,
    required this.growthRate,
  });
}

class RaceActivityData {
  final List<ChartDataPoint> dataPoints;
  final int totalRaces;

  RaceActivityData({
    required this.dataPoints,
    required this.totalRaces,
  });
}

class SubscriptionDistribution {
  final int freeUsers;
  final int premium1Users;
  final int premium2Users;

  SubscriptionDistribution({
    required this.freeUsers,
    required this.premium1Users,
    required this.premium2Users,
  });

  int get totalUsers => freeUsers + premium1Users + premium2Users;

  double get freePercentage =>
      totalUsers > 0 ? (freeUsers / totalUsers) * 100 : 0;
  double get premium1Percentage =>
      totalUsers > 0 ? (premium1Users / totalUsers) * 100 : 0;
  double get premium2Percentage =>
      totalUsers > 0 ? (premium2Users / totalUsers) * 100 : 0;
}

class RevenueHistoryData {
  final List<ChartDataPoint> dataPoints;
  final double totalRevenue;
  final double averageRevenue;

  RevenueHistoryData({
    required this.dataPoints,
    required this.totalRevenue,
    required this.averageRevenue,
  });
}

/// Activity Feed Models

class ActivityFeedItem {
  final String id;
  final ActivityType type;
  final String title;
  final String description;
  final DateTime timestamp;
  final String? userId;
  final String? userName;
  final String? raceId;
  final String? raceName;
  final Map<String, dynamic>? metadata;

  ActivityFeedItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.userId,
    this.userName,
    this.raceId,
    this.raceName,
    this.metadata,
  });

  factory ActivityFeedItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivityFeedItem(
      id: doc.id,
      type: ActivityType.fromString(data['type'] ?? 'other'),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: data['userId'],
      userName: data['userName'],
      raceId: data['raceId'],
      raceName: data['raceName'],
      metadata: data['metadata'],
    );
  }
}

enum ActivityType {
  newUser,
  raceCreated,
  raceStarted,
  raceCompleted,
  subscriptionPurchased,
  subscriptionCancelled,
  reportSubmitted,
  other;

  static ActivityType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'new_user':
      case 'newuser':
        return ActivityType.newUser;
      case 'race_created':
      case 'racecreated':
        return ActivityType.raceCreated;
      case 'race_started':
      case 'racestarted':
        return ActivityType.raceStarted;
      case 'race_completed':
      case 'racecompleted':
        return ActivityType.raceCompleted;
      case 'subscription_purchased':
      case 'subscriptionpurchased':
        return ActivityType.subscriptionPurchased;
      case 'subscription_cancelled':
      case 'subscriptioncancelled':
        return ActivityType.subscriptionCancelled;
      case 'report_submitted':
      case 'reportsubmitted':
        return ActivityType.reportSubmitted;
      default:
        return ActivityType.other;
    }
  }

  String get displayName {
    switch (this) {
      case ActivityType.newUser:
        return 'New User';
      case ActivityType.raceCreated:
        return 'Race Created';
      case ActivityType.raceStarted:
        return 'Race Started';
      case ActivityType.raceCompleted:
        return 'Race Completed';
      case ActivityType.subscriptionPurchased:
        return 'Subscription Purchased';
      case ActivityType.subscriptionCancelled:
        return 'Subscription Cancelled';
      case ActivityType.reportSubmitted:
        return 'Report Submitted';
      case ActivityType.other:
        return 'Activity';
    }
  }
}
