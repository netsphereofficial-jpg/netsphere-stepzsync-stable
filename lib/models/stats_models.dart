import 'package:cloud_firestore/cloud_firestore.dart';

class DailyStatsModel {
  final String date;
  final int steps;
  final double distance;
  final int activeTime;
  final double avgSpeed;
  final int calories;
  final DateTime timestamp;

  DailyStatsModel({
    required this.date,
    required this.steps,
    required this.distance,
    required this.activeTime,
    required this.avgSpeed,
    required this.calories,
    required this.timestamp,
  });

  factory DailyStatsModel.fromMap(Map<String, dynamic> map) {
    return DailyStatsModel(
      date: map['date'] ?? '',
      steps: map['steps'] ?? 0,
      distance: (map['distance'] ?? 0.0).toDouble(),
      activeTime: map['activeTime'] ?? 0,
      avgSpeed: (map['avgSpeed'] ?? 0.0).toDouble(),
      calories: map['calories'] ?? 0,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'steps': steps,
      'distance': distance,
      'activeTime': activeTime,
      'avgSpeed': avgSpeed,
      'calories': calories,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  DailyStatsModel copyWith({
    String? date,
    int? steps,
    double? distance,
    int? activeTime,
    double? avgSpeed,
    int? calories,
    DateTime? timestamp,
  }) {
    return DailyStatsModel(
      date: date ?? this.date,
      steps: steps ?? this.steps,
      distance: distance ?? this.distance,
      activeTime: activeTime ?? this.activeTime,
      avgSpeed: avgSpeed ?? this.avgSpeed,
      calories: calories ?? this.calories,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class ActivitySessionModel {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final int steps;
  final double distance;
  final double avgSpeed;
  final int calories;
  final bool isActive;

  ActivitySessionModel({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.steps,
    required this.distance,
    required this.avgSpeed,
    required this.calories,
    this.isActive = true,
  });

  factory ActivitySessionModel.fromMap(Map<String, dynamic> map) {
    return ActivitySessionModel(
      id: map['id'] ?? '',
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: map['endTime'] != null ? (map['endTime'] as Timestamp).toDate() : null,
      steps: map['steps'] ?? 0,
      distance: (map['distance'] ?? 0.0).toDouble(),
      avgSpeed: (map['avgSpeed'] ?? 0.0).toDouble(),
      calories: map['calories'] ?? 0,
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'steps': steps,
      'distance': distance,
      'avgSpeed': avgSpeed,
      'calories': calories,
      'isActive': isActive,
    };
  }

  int get durationMinutes {
    if (endTime == null) return 0;
    return endTime!.difference(startTime).inMinutes;
  }

  ActivitySessionModel copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    int? steps,
    double? distance,
    double? avgSpeed,
    int? calories,
    bool? isActive,
  }) {
    return ActivitySessionModel(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      steps: steps ?? this.steps,
      distance: distance ?? this.distance,
      avgSpeed: avgSpeed ?? this.avgSpeed,
      calories: calories ?? this.calories,
      isActive: isActive ?? this.isActive,
    );
  }
}

class TotalStatsModel {
  final int totalSteps;
  final double totalDistance;
  final int totalActiveTime;
  final DateTime lastUpdated;

  TotalStatsModel({
    required this.totalSteps,
    required this.totalDistance,
    required this.totalActiveTime,
    required this.lastUpdated,
  });

  factory TotalStatsModel.fromMap(Map<String, dynamic> map) {
    return TotalStatsModel(
      totalSteps: map['totalSteps'] ?? 0,
      totalDistance: (map['totalDistance'] ?? 0.0).toDouble(),
      totalActiveTime: map['totalActiveTime'] ?? 0,
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalSteps': totalSteps,
      'totalDistance': totalDistance,
      'totalActiveTime': totalActiveTime,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  TotalStatsModel copyWith({
    int? totalSteps,
    double? totalDistance,
    int? totalActiveTime,
    DateTime? lastUpdated,
  }) {
    return TotalStatsModel(
      totalSteps: totalSteps ?? this.totalSteps,
      totalDistance: totalDistance ?? this.totalDistance,
      totalActiveTime: totalActiveTime ?? this.totalActiveTime,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class UserStatsModel {
  final String userId;
  final DailyStatsModel? todayStats;
  final TotalStatsModel? totalStats;
  final List<DailyStatsModel> weeklyStats;
  final List<DailyStatsModel> monthlyStats;

  UserStatsModel({
    required this.userId,
    this.todayStats,
    this.totalStats,
    this.weeklyStats = const [],
    this.monthlyStats = const [],
  });

  factory UserStatsModel.fromMaps({
    required String userId,
    Map<String, dynamic>? todayData,
    Map<String, dynamic>? totalData,
    List<Map<String, dynamic>>? weeklyData,
    List<Map<String, dynamic>>? monthlyData,
  }) {
    return UserStatsModel(
      userId: userId,
      todayStats: todayData != null ? DailyStatsModel.fromMap(todayData) : null,
      totalStats: totalData != null ? TotalStatsModel.fromMap(totalData) : null,
      weeklyStats: weeklyData?.map((data) => DailyStatsModel.fromMap(data)).toList() ?? [],
      monthlyStats: monthlyData?.map((data) => DailyStatsModel.fromMap(data)).toList() ?? [],
    );
  }
}

class StatsAggregationModel {
  final int totalSteps;
  final double totalDistance;
  final int totalActiveTime;
  final double avgSpeed;
  final int totalCalories;
  final String period;
  final DateTime startDate;
  final DateTime endDate;

  StatsAggregationModel({
    required this.totalSteps,
    required this.totalDistance,
    required this.totalActiveTime,
    required this.avgSpeed,
    required this.totalCalories,
    required this.period,
    required this.startDate,
    required this.endDate,
  });

  factory StatsAggregationModel.fromDailyStats(
    List<DailyStatsModel> dailyStats,
    String period,
    DateTime startDate,
    DateTime endDate,
  ) {
    if (dailyStats.isEmpty) {
      return StatsAggregationModel(
        totalSteps: 0,
        totalDistance: 0.0,
        totalActiveTime: 0,
        avgSpeed: 0.0,
        totalCalories: 0,
        period: period,
        startDate: startDate,
        endDate: endDate,
      );
    }

    final totalSteps = dailyStats.fold<int>(0, (sum, stat) => sum + stat.steps);
    final totalDistance = dailyStats.fold<double>(0.0, (sum, stat) => sum + stat.distance);
    final totalActiveTime = dailyStats.fold<int>(0, (sum, stat) => sum + stat.activeTime);
    final totalCalories = dailyStats.fold<int>(0, (sum, stat) => sum + stat.calories);
    
    double avgSpeed = 0.0;
    if (totalActiveTime > 0) {
      avgSpeed = totalDistance / (totalActiveTime / 60.0);
    }

    return StatsAggregationModel(
      totalSteps: totalSteps,
      totalDistance: totalDistance,
      totalActiveTime: totalActiveTime,
      avgSpeed: avgSpeed,
      totalCalories: totalCalories,
      period: period,
      startDate: startDate,
      endDate: endDate,
    );
  }

  String get formattedSteps => totalSteps.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );

  String get formattedDistance => '${totalDistance.toStringAsFixed(2)} km';
  
  String get formattedActiveTime {
    final hours = totalActiveTime ~/ 60;
    final minutes = totalActiveTime % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get formattedAvgSpeed => '${avgSpeed.toStringAsFixed(1)} km/h';
  
  String get formattedCalories => '$totalCalories cal';
}