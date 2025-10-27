class UserOverallStats {
  final int userId;
  final DateTime firstInstallDate;
  final int totalDays;
  final int totalSteps;
  final double totalDistance;
  final double totalCalories;
  final double avgSpeed;
  final DateTime lastUpdated;

  UserOverallStats({
    required this.userId,
    required this.firstInstallDate,
    required this.totalDays,
    required this.totalSteps,
    required this.totalDistance,
    required this.totalCalories,
    required this.avgSpeed,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  factory UserOverallStats.fromMap(Map<String, dynamic> map) {
    return UserOverallStats(
      userId: map['userId'] as int,
      firstInstallDate: DateTime.parse(map['firstInstallDate'] as String),
      totalDays: map['totalDays'] as int,
      totalSteps: map['totalSteps'] as int,
      totalDistance: (map['totalDistance'] as num).toDouble(),
      totalCalories: (map['totalCalories'] as num).toDouble(),
      avgSpeed: (map['avgSpeed'] as num).toDouble(),
      lastUpdated: DateTime.parse(map['lastUpdated'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'firstInstallDate': firstInstallDate.toIso8601String(),
      'totalDays': totalDays,
      'totalSteps': totalSteps,
      'totalDistance': totalDistance,
      'totalCalories': totalCalories,
      'avgSpeed': avgSpeed,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory UserOverallStats.initial({required int userId}) {
    final now = DateTime.now();
    return UserOverallStats(
      userId: userId,
      firstInstallDate: now,
      totalDays: 1,
      totalSteps: 0,
      totalDistance: 0.0,
      totalCalories: 0.0,
      avgSpeed: 0.0,
      lastUpdated: now,
    );
  }

  UserOverallStats copyWith({
    int? userId,
    DateTime? firstInstallDate,
    int? totalDays,
    int? totalSteps,
    double? totalDistance,
    double? totalCalories,
    double? avgSpeed,
    DateTime? lastUpdated,
  }) {
    return UserOverallStats(
      userId: userId ?? this.userId,
      firstInstallDate: firstInstallDate ?? this.firstInstallDate,
      totalDays: totalDays ?? this.totalDays,
      totalSteps: totalSteps ?? this.totalSteps,
      totalDistance: totalDistance ?? this.totalDistance,
      totalCalories: totalCalories ?? this.totalCalories,
      avgSpeed: avgSpeed ?? this.avgSpeed,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }

  // Calculate total days from first install date to now
  int get calculatedTotalDays {
    final now = DateTime.now();
    return now.difference(firstInstallDate).inDays + 1; // +1 to include first day
  }

  // Update stats with new daily data
  UserOverallStats updateWithDailyStats({
    required int dailySteps,
    required double dailyDistance,
    required double dailyCalories,
    required double dailyAvgSpeed,
  }) {
    final newTotalSteps = totalSteps + dailySteps;
    final newTotalDistance = totalDistance + dailyDistance;
    final newTotalCalories = totalCalories + dailyCalories;

    // Calculate new average speed (weighted average)
    double newAvgSpeed = avgSpeed;
    if (totalDays > 0) {
      newAvgSpeed = ((avgSpeed * totalDays) + dailyAvgSpeed) / (totalDays + 1);
    } else {
      newAvgSpeed = dailyAvgSpeed;
    }

    return copyWith(
      totalDays: calculatedTotalDays,
      totalSteps: newTotalSteps,
      totalDistance: newTotalDistance,
      totalCalories: newTotalCalories,
      avgSpeed: newAvgSpeed,
      lastUpdated: DateTime.now(),
    );
  }

  // Formatted getters for UI display
  String get formattedTotalSteps => totalSteps.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );

  String get formattedTotalDistance => '${totalDistance.toStringAsFixed(2)} km';

  String get formattedTotalCalories => '${totalCalories.toStringAsFixed(0)} cal';

  String get formattedAvgSpeed => '${avgSpeed.toStringAsFixed(1)} km/h';

  String get formattedTotalDays => totalDays.toString();

  // Calculate average steps per day
  double get avgStepsPerDay {
    if (totalDays > 0) {
      return totalSteps / totalDays;
    }
    return 0.0;
  }

  String get formattedAvgStepsPerDay => '${avgStepsPerDay.toStringAsFixed(0)}';

  // Calculate average distance per day
  double get avgDistancePerDay {
    if (totalDays > 0) {
      return totalDistance / totalDays;
    }
    return 0.0;
  }

  String get formattedAvgDistancePerDay => '${avgDistancePerDay.toStringAsFixed(2)} km';

  // Calculate average calories per day
  double get avgCaloriesPerDay {
    if (totalDays > 0) {
      return totalCalories / totalDays;
    }
    return 0.0;
  }

  String get formattedAvgCaloriesPerDay => '${avgCaloriesPerDay.toStringAsFixed(0)} cal';

  @override
  String toString() {
    return 'UserOverallStats(userId: $userId, totalDays: $totalDays, totalSteps: $totalSteps, totalDistance: ${totalDistance}km)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserOverallStats &&
      other.userId == userId &&
      other.firstInstallDate == firstInstallDate &&
      other.totalDays == totalDays &&
      other.totalSteps == totalSteps &&
      other.totalDistance == totalDistance &&
      other.totalCalories == totalCalories &&
      other.avgSpeed == avgSpeed;
  }

  @override
  int get hashCode {
    return userId.hashCode ^
      firstInstallDate.hashCode ^
      totalDays.hashCode ^
      totalSteps.hashCode ^
      totalDistance.hashCode ^
      totalCalories.hashCode ^
      avgSpeed.hashCode;
  }
}