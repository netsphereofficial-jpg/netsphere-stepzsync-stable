import 'package:cloud_firestore/cloud_firestore.dart';
import '../../screens/admin/dashboard/models/dashboard_metrics.dart';

/// Admin Analytics Service
/// Handles chart data aggregation for Syncfusion charts

class AdminAnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get user growth data for line chart (last 30 days)
  static Future<UserGrowthData> getUserGrowthData({int days = 30}) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      final usersSnapshot = await _firestore
          .collection('user_profiles')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(startDate))
          .orderBy('createdAt')
          .get();

      // Group users by day
      final Map<String, int> usersByDay = {};

      for (final doc in usersSnapshot.docs) {
        final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null) {
          final dateKey =
              '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
          usersByDay[dateKey] = (usersByDay[dateKey] ?? 0) + 1;
        }
      }

      // Create cumulative data points
      final List<ChartDataPoint> dataPoints = [];
      int cumulativeUsers = 0;

      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));
        final dateKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        cumulativeUsers += usersByDay[dateKey] ?? 0;

        dataPoints.add(ChartDataPoint(
          date: date,
          value: cumulativeUsers.toDouble(),
        ));
      }

      // Calculate growth rate
      final firstWeekUsers = dataPoints.length > 7
          ? dataPoints[6].value - dataPoints[0].value
          : 0;
      final lastWeekUsers = dataPoints.length > 7
          ? dataPoints.last.value - dataPoints[dataPoints.length - 7].value
          : 0;

      final growthRate = firstWeekUsers > 0
          ? ((lastWeekUsers - firstWeekUsers) / firstWeekUsers) * 100
          : 0.0;

      return UserGrowthData(
        dataPoints: dataPoints,
        growthRate: growthRate,
      );
    } catch (e) {
      print('Error fetching user growth data: $e');
      return UserGrowthData(
        dataPoints: [],
        growthRate: 0.0,
      );
    }
  }

  /// Get race activity data for column chart (last 30 days)
  static Future<RaceActivityData> getRaceActivityData({int days = 30}) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      final racesSnapshot = await _firestore
          .collection('races')
          .where('startTime', isGreaterThan: Timestamp.fromDate(startDate))
          .orderBy('startTime')
          .get();

      // Group races by day
      final Map<String, int> racesByDay = {};

      for (final doc in racesSnapshot.docs) {
        final startTime = (doc.data()['startTime'] as Timestamp?)?.toDate();
        if (startTime != null) {
          final dateKey =
              '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}';
          racesByDay[dateKey] = (racesByDay[dateKey] ?? 0) + 1;
        }
      }

      // Create data points
      final List<ChartDataPoint> dataPoints = [];

      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));
        final dateKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final racesCount = racesByDay[dateKey] ?? 0;

        dataPoints.add(ChartDataPoint(
          date: date,
          value: racesCount.toDouble(),
        ));
      }

      return RaceActivityData(
        dataPoints: dataPoints,
        totalRaces: racesSnapshot.docs.length,
      );
    } catch (e) {
      print('Error fetching race activity data: $e');
      return RaceActivityData(
        dataPoints: [],
        totalRaces: 0,
      );
    }
  }

  /// Get subscription distribution for doughnut chart
  static Future<SubscriptionDistribution> getSubscriptionDistribution() async {
    try {
      final usersSnapshot = await _firestore.collection('user_profiles').get();

      int freeUsers = 0;
      int premium1Users = 0;
      int premium2Users = 0;

      for (final doc in usersSnapshot.docs) {
        final subscriptionTier = doc.data()['subscriptionTier'] as String?;

        if (subscriptionTier == 'free' || subscriptionTier == null) {
          freeUsers++;
        } else if (subscriptionTier == 'premium_1' || subscriptionTier == 'premium1') {
          premium1Users++;
        } else if (subscriptionTier == 'premium_2' || subscriptionTier == 'premium2') {
          premium2Users++;
        }
      }

      return SubscriptionDistribution(
        freeUsers: freeUsers,
        premium1Users: premium1Users,
        premium2Users: premium2Users,
      );
    } catch (e) {
      print('Error fetching subscription distribution: $e');
      return SubscriptionDistribution(
        freeUsers: 0,
        premium1Users: 0,
        premium2Users: 0,
      );
    }
  }

  /// Get revenue history for area chart (last 12 months)
  static Future<RevenueHistoryData> getRevenueHistory({int months = 12}) async {
    try {
      final now = DateTime.now();
      final List<ChartDataPoint> dataPoints = [];
      double totalRevenue = 0;

      const premium1Price = 9.99;
      const premium2Price = 19.99;

      for (int i = months - 1; i >= 0; i--) {
        final monthDate = DateTime(now.year, now.month - i, 1);
        final nextMonthDate = DateTime(now.year, now.month - i + 1, 1);

        // Get subscriptions created in this month
        final subscriptionsSnapshot = await _firestore
            .collection('subscriptions')
            .where('createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(monthDate))
            .where('createdAt', isLessThan: Timestamp.fromDate(nextMonthDate))
            .where('status', isEqualTo: 'active')
            .get();

        double monthRevenue = 0;

        for (final doc in subscriptionsSnapshot.docs) {
          final tier = doc.data()['tier'] as String?;

          if (tier == 'premium_1' || tier == 'premium1') {
            monthRevenue += premium1Price;
          } else if (tier == 'premium_2' || tier == 'premium2') {
            monthRevenue += premium2Price;
          }
        }

        totalRevenue += monthRevenue;

        dataPoints.add(ChartDataPoint(
          date: monthDate,
          value: monthRevenue,
          label:
              '${_getMonthName(monthDate.month)} ${monthDate.year}',
        ));
      }

      final averageRevenue = dataPoints.isNotEmpty
          ? totalRevenue / dataPoints.length
          : 0.0;

      return RevenueHistoryData(
        dataPoints: dataPoints,
        totalRevenue: totalRevenue,
        averageRevenue: averageRevenue,
      );
    } catch (e) {
      print('Error fetching revenue history: $e');
      return RevenueHistoryData(
        dataPoints: [],
        totalRevenue: 0.0,
        averageRevenue: 0.0,
      );
    }
  }

  /// Get step activity data for area chart (last 30 days)
  static Future<List<ChartDataPoint>> getStepActivityData({int days = 30}) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      final stepsSnapshot = await _firestore
          .collection('daily_steps')
          .where('date', isGreaterThan: Timestamp.fromDate(startDate))
          .orderBy('date')
          .get();

      // Group steps by day
      final Map<String, int> stepsByDay = {};

      for (final doc in stepsSnapshot.docs) {
        final date = (doc.data()['date'] as Timestamp?)?.toDate();
        final steps = (doc.data()['steps'] as num?)?.toInt() ?? 0;

        if (date != null) {
          final dateKey =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          stepsByDay[dateKey] = (stepsByDay[dateKey] ?? 0) + steps;
        }
      }

      // Create data points
      final List<ChartDataPoint> dataPoints = [];

      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));
        final dateKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final totalSteps = stepsByDay[dateKey] ?? 0;

        dataPoints.add(ChartDataPoint(
          date: date,
          value: totalSteps.toDouble(),
        ));
      }

      return dataPoints;
    } catch (e) {
      print('Error fetching step activity data: $e');
      return [];
    }
  }

  /// Get active users over time (last 30 days)
  static Future<List<ChartDataPoint>> getActiveUsersData({int days = 30}) async {
    try {
      final now = DateTime.now();
      final List<ChartDataPoint> dataPoints = [];

      for (int i = days - 1; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dayStart = DateTime(date.year, date.month, date.day);
        final dayEnd = dayStart.add(const Duration(days: 1));

        // Get users active on this day
        final activeUsersSnapshot = await _firestore
            .collection('user_profiles')
            .where('lastActiveAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
            .where('lastActiveAt', isLessThan: Timestamp.fromDate(dayEnd))
            .get();

        dataPoints.add(ChartDataPoint(
          date: date,
          value: activeUsersSnapshot.docs.length.toDouble(),
        ));
      }

      return dataPoints;
    } catch (e) {
      print('Error fetching active users data: $e');
      return [];
    }
  }

  /// Get race completion rate data
  static Future<Map<String, int>> getRaceCompletionStats() async {
    try {
      final racesSnapshot = await _firestore.collection('races').get();

      int completed = 0;
      int inProgress = 0;
      int scheduled = 0;
      int cancelled = 0;

      for (final doc in racesSnapshot.docs) {
        final status = doc.data()['status'] as String?;

        switch (status) {
          case 'completed':
            completed++;
            break;
          case 'active':
          case 'in_progress':
            inProgress++;
            break;
          case 'scheduled':
            scheduled++;
            break;
          case 'cancelled':
            cancelled++;
            break;
        }
      }

      return {
        'completed': completed,
        'inProgress': inProgress,
        'scheduled': scheduled,
        'cancelled': cancelled,
      };
    } catch (e) {
      print('Error fetching race completion stats: $e');
      return {
        'completed': 0,
        'inProgress': 0,
        'scheduled': 0,
        'cancelled': 0,
      };
    }
  }

  /// Helper method to get month name
  static String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }
}
