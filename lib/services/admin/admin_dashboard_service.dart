import 'package:cloud_firestore/cloud_firestore.dart';
import '../../screens/admin/dashboard/models/dashboard_metrics.dart';

/// Admin Dashboard Service
/// Handles fetching and aggregating dashboard data from Firestore

class AdminDashboardService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch all dashboard metrics
  static Future<DashboardMetrics> getDashboardMetrics() async {
    final userMetrics = await getUserMetrics();
    final raceMetrics = await getRaceMetrics();
    final revenueMetrics = await getRevenueMetrics();
    final engagementMetrics = await getEngagementMetrics();

    return DashboardMetrics(
      userMetrics: userMetrics,
      raceMetrics: raceMetrics,
      revenueMetrics: revenueMetrics,
      engagementMetrics: engagementMetrics,
    );
  }

  /// Get user statistics
  static Future<UserMetrics> getUserMetrics() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);

      // Get all users
      final usersSnapshot = await _firestore.collection('user_profiles').get();
      final totalUsers = usersSnapshot.docs.length;

      // Count verified users
      final verifiedUsers = usersSnapshot.docs
          .where((doc) => doc.data()['emailVerified'] == true)
          .length;

      // Count new users today
      final newUsersToday = usersSnapshot.docs.where((doc) {
        final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null && createdAt.isAfter(todayStart);
      }).length;

      // Count new users this week
      final newUsersThisWeek = usersSnapshot.docs.where((doc) {
        final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null && createdAt.isAfter(weekStart);
      }).length;

      // Count new users this month
      final newUsersThisMonth = usersSnapshot.docs.where((doc) {
        final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null && createdAt.isAfter(monthStart);
      }).length;

      // Count new users last month
      final newUsersLastMonth = usersSnapshot.docs.where((doc) {
        final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null &&
            createdAt.isAfter(lastMonthStart) &&
            createdAt.isBefore(monthStart);
      }).length;

      // Calculate growth rate
      final growthRate = newUsersLastMonth > 0
          ? ((newUsersThisMonth - newUsersLastMonth) / newUsersLastMonth) * 100
          : 0.0;

      // Count active users (users with activity in last 7 days)
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      final activeUsers = usersSnapshot.docs.where((doc) {
        final lastActive =
            (doc.data()['lastActiveAt'] as Timestamp?)?.toDate();
        return lastActive != null && lastActive.isAfter(sevenDaysAgo);
      }).length;

      return UserMetrics(
        totalUsers: totalUsers,
        activeUsers: activeUsers,
        newUsersToday: newUsersToday,
        newUsersThisWeek: newUsersThisWeek,
        newUsersThisMonth: newUsersThisMonth,
        growthRate: growthRate,
        verifiedUsers: verifiedUsers,
        unverifiedUsers: totalUsers - verifiedUsers,
      );
    } catch (e) {
      print('Error fetching user metrics: $e');
      return UserMetrics.empty();
    }
  }

  /// Get race statistics
  static Future<RaceMetrics> getRaceMetrics() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      // Get all races
      final racesSnapshot = await _firestore.collection('races').get();
      final totalRaces = racesSnapshot.docs.length;

      // Count races by status
      int activeRaces = 0;
      int completedRaces = 0;
      int scheduledRaces = 0;
      int racesToday = 0;
      int racesThisWeek = 0;
      int racesThisMonth = 0;
      int totalParticipants = 0;

      for (final doc in racesSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        final startTime = (data['startTime'] as Timestamp?)?.toDate();
        final participants = (data['participants'] as List?)?.length ?? 0;

        totalParticipants += participants;

        // Count by status
        if (status == 'active' || status == 'in_progress') {
          activeRaces++;
        } else if (status == 'completed') {
          completedRaces++;
        } else if (status == 'scheduled') {
          scheduledRaces++;
        }

        // Count by date
        if (startTime != null) {
          if (startTime.isAfter(todayStart)) {
            racesToday++;
          }
          if (startTime.isAfter(weekStart)) {
            racesThisWeek++;
          }
          if (startTime.isAfter(monthStart)) {
            racesThisMonth++;
          }
        }
      }

      final averageParticipants =
          totalRaces > 0 ? totalParticipants / totalRaces : 0.0;

      return RaceMetrics(
        totalRaces: totalRaces,
        activeRaces: activeRaces,
        completedRaces: completedRaces,
        scheduledRaces: scheduledRaces,
        totalParticipants: totalParticipants,
        racesToday: racesToday,
        racesThisWeek: racesThisWeek,
        racesThisMonth: racesThisMonth,
        averageParticipantsPerRace: averageParticipants,
      );
    } catch (e) {
      print('Error fetching race metrics: $e');
      return RaceMetrics.empty();
    }
  }

  /// Get revenue and subscription statistics
  static Future<RevenueMetrics> getRevenueMetrics() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final monthStart = DateTime(now.year, now.month, 1);
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);

      // Subscription prices
      const premium1Price = 9.99;
      const premium2Price = 19.99;

      // Get all subscriptions
      final subscriptionsSnapshot =
          await _firestore.collection('subscriptions').get();
      final totalSubscriptions = subscriptionsSnapshot.docs.length;

      int freeUsers = 0;
      int premium1Users = 0;
      int premium2Users = 0;
      int activeSubscriptions = 0;
      double totalRevenue = 0;
      double monthlyRevenue = 0;
      double todayRevenue = 0;

      for (final doc in subscriptionsSnapshot.docs) {
        final data = doc.data();
        final tier = data['tier'] as String?;
        final status = data['status'] as String?;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        if (status == 'active') {
          activeSubscriptions++;
        }

        // Count by tier
        if (tier == 'free' || tier == null) {
          freeUsers++;
        } else if (tier == 'premium_1' || tier == 'premium1') {
          premium1Users++;
          if (status == 'active') {
            totalRevenue += premium1Price;
            if (createdAt != null && createdAt.isAfter(monthStart)) {
              monthlyRevenue += premium1Price;
            }
            if (createdAt != null && createdAt.isAfter(todayStart)) {
              todayRevenue += premium1Price;
            }
          }
        } else if (tier == 'premium_2' || tier == 'premium2') {
          premium2Users++;
          if (status == 'active') {
            totalRevenue += premium2Price;
            if (createdAt != null && createdAt.isAfter(monthStart)) {
              monthlyRevenue += premium2Price;
            }
            if (createdAt != null && createdAt.isAfter(todayStart)) {
              todayRevenue += premium2Price;
            }
          }
        }
      }

      // Get last month revenue for growth calculation
      final lastMonthSubs = subscriptionsSnapshot.docs.where((doc) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null &&
            createdAt.isAfter(lastMonthStart) &&
            createdAt.isBefore(monthStart);
      }).length;

      final lastMonthRevenue = lastMonthSubs *
          ((premium1Price + premium2Price) / 2); // Approximate

      final growthRate = lastMonthRevenue > 0
          ? ((monthlyRevenue - lastMonthRevenue) / lastMonthRevenue) * 100
          : 0.0;

      final usersSnapshot = await _firestore.collection('user_profiles').get();
      final totalUsers = usersSnapshot.docs.length;
      final averageRevenuePerUser =
          totalUsers > 0 ? totalRevenue / totalUsers : 0.0;

      return RevenueMetrics(
        totalRevenue: totalRevenue,
        monthlyRevenue: monthlyRevenue,
        todayRevenue: todayRevenue,
        averageRevenuePerUser: averageRevenuePerUser,
        totalSubscriptions: totalSubscriptions,
        activeSubscriptions: activeSubscriptions,
        subscriptionBreakdown: {
          'Free': freeUsers,
          'Premium 1': premium1Users,
          'Premium 2': premium2Users,
        },
        growthRate: growthRate,
      );
    } catch (e) {
      print('Error fetching revenue metrics: $e');
      return RevenueMetrics.empty();
    }
  }

  /// Get engagement statistics
  static Future<EngagementMetrics> getEngagementMetrics() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);
      final oneDayAgo = now.subtract(const Duration(days: 1));
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      // Get users
      final usersSnapshot = await _firestore.collection('user_profiles').get();

      // Count daily active users
      final dailyActiveUsers = usersSnapshot.docs.where((doc) {
        final lastActive =
            (doc.data()['lastActiveAt'] as Timestamp?)?.toDate();
        return lastActive != null && lastActive.isAfter(oneDayAgo);
      }).length;

      // Count monthly active users
      final monthlyActiveUsers = usersSnapshot.docs.where((doc) {
        final lastActive =
            (doc.data()['lastActiveAt'] as Timestamp?)?.toDate();
        return lastActive != null && lastActive.isAfter(thirtyDaysAgo);
      }).length;

      // Calculate DAU/MAU ratio
      final dau = monthlyActiveUsers > 0
          ? (dailyActiveUsers / monthlyActiveUsers) * 100
          : 0.0;

      // Get step data
      final stepsSnapshot = await _firestore.collection('daily_steps').get();

      int totalStepsToday = 0;
      int totalStepsThisWeek = 0;
      int totalStepsThisMonth = 0;

      for (final doc in stepsSnapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp?)?.toDate();
        final steps = (data['steps'] as num?)?.toInt() ?? 0;

        if (date != null) {
          if (date.isAfter(todayStart)) {
            totalStepsToday += steps;
          }
          if (date.isAfter(weekStart)) {
            totalStepsThisWeek += steps;
          }
          if (date.isAfter(monthStart)) {
            totalStepsThisMonth += steps;
          }
        }
      }

      final averageStepsPerUser = usersSnapshot.docs.length > 0
          ? totalStepsThisMonth / usersSnapshot.docs.length
          : 0.0;

      // Get social interactions (likes, comments, etc.)
      int totalInteractions = 0;
      try {
        final likesSnapshot = await _firestore.collection('post_likes').get();
        final commentsSnapshot =
            await _firestore.collection('post_comments').get();
        totalInteractions = likesSnapshot.docs.length + commentsSnapshot.docs.length;
      } catch (e) {
        print('Error fetching social interactions: $e');
      }

      return EngagementMetrics(
        dailyActiveUsers: dailyActiveUsers,
        monthlyActiveUsers: monthlyActiveUsers,
        dau: dau,
        totalStepsToday: totalStepsToday,
        totalStepsThisWeek: totalStepsThisWeek,
        totalStepsThisMonth: totalStepsThisMonth,
        averageStepsPerUser: averageStepsPerUser,
        totalSocialInteractions: totalInteractions,
      );
    } catch (e) {
      print('Error fetching engagement metrics: $e');
      return EngagementMetrics.empty();
    }
  }

  /// Get activity feed (real-time stream)
  static Stream<List<ActivityFeedItem>> getActivityFeedStream({int limit = 20}) {
    return _firestore
        .collection('activity_feed')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ActivityFeedItem.fromFirestore(doc))
            .toList());
  }

  /// Log activity to feed
  static Future<void> logActivity({
    required ActivityType type,
    required String title,
    required String description,
    String? userId,
    String? userName,
    String? raceId,
    String? raceName,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('activity_feed').add({
        'type': type.name,
        'title': title,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userId,
        'userName': userName,
        'raceId': raceId,
        'raceName': raceName,
        'metadata': metadata,
      });
    } catch (e) {
      print('Error logging activity: $e');
    }
  }
}
