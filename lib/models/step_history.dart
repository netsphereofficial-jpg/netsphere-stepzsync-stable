import 'package:intl/intl.dart';
import 'package:stepzsync/models/step_metrics.dart';

class StepHistory {
  final int? id; // Auto-increment primary key
  final int userId;
  final DateTime date;
  final int steps;
  final double distance;
  final int calories;
  final int activeTime; // in minutes
  final double avgSpeed;
  final DateTime createdAt;

  StepHistory({
    this.id,
    required this.userId,
    required this.date,
    required this.steps,
    required this.distance,
    required this.calories,
    required this.activeTime,
    required this.avgSpeed,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory StepHistory.fromMap(Map<String, dynamic> map) {
    return StepHistory(
      id: map['id'] as int?,
      userId: map['userId'] as int,
      date: DateFormat('yyyy-MM-dd').parse(map['date'] as String),
      steps: map['steps'] as int,
      distance: (map['distance'] as num).toDouble(),
      calories: map['calories'] as int,
      activeTime: map['activeTime'] as int,
      avgSpeed: (map['avgSpeed'] as num).toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'userId': userId,
      'date': DateFormat('yyyy-MM-dd').format(date),
      'steps': steps,
      'distance': distance,
      'calories': calories,
      'activeTime': activeTime,
      'avgSpeed': avgSpeed,
      'createdAt': createdAt.toIso8601String(),
    };

    if (id != null) {
      map['id'] = id;
    }

    return map;
  }

  factory StepHistory.fromStepMetrics(StepMetrics stepMetrics) {
    return StepHistory(
      userId: stepMetrics.userId,
      date: stepMetrics.date,
      steps: stepMetrics.steps,
      distance: stepMetrics.distance,
      calories: stepMetrics.calories.round(),
      activeTime: stepMetrics.activeTime,
      avgSpeed: stepMetrics.avgSpeed,
      createdAt: stepMetrics.createdAt,
    );
  }

  StepHistory copyWith({
    int? id,
    int? userId,
    DateTime? date,
    int? steps,
    double? distance,
    int? calories,
    int? activeTime,
    double? avgSpeed,
    DateTime? createdAt,
  }) {
    return StepHistory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      steps: steps ?? this.steps,
      distance: distance ?? this.distance,
      calories: calories ?? this.calories,
      activeTime: activeTime ?? this.activeTime,
      avgSpeed: avgSpeed ?? this.avgSpeed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Formatted getters for UI display
  String get formattedSteps => steps.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );

  String get formattedDistance => '${distance.toStringAsFixed(2)} km';

  String get formattedActiveTime {
    final hours = activeTime ~/ 60;
    final minutes = activeTime % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get formattedAvgSpeed => '${avgSpeed.toStringAsFixed(1)} km/h';

  String get formattedCalories => '$calories cal';

  String get formattedDate => DateFormat('MMM dd, yyyy').format(date);

  String get shortDate => DateFormat('MMM dd').format(date);

  String get dayOfWeek => DateFormat('EEEE').format(date);

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  String get relativeDateString {
    if (isToday) return 'Today';
    if (isYesterday) return 'Yesterday';
    return formattedDate;
  }

  @override
  String toString() {
    return 'StepHistory(id: $id, userId: $userId, date: ${DateFormat('yyyy-MM-dd').format(date)}, steps: $steps)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is StepHistory &&
        other.id == id &&
        other.userId == userId &&
        other.date == date &&
        other.steps == steps &&
        other.distance == distance &&
        other.calories == calories &&
        other.activeTime == activeTime &&
        other.avgSpeed == avgSpeed;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        date.hashCode ^
        steps.hashCode ^
        distance.hashCode ^
        calories.hashCode ^
        activeTime.hashCode ^
        avgSpeed.hashCode;
  }
}

// Helper class for aggregating step history data
class StepHistoryAggregation {
  final List<StepHistory> history;
  final DateTime startDate;
  final DateTime endDate;
  final String period;

  StepHistoryAggregation({
    required this.history,
    required this.startDate,
    required this.endDate,
    required this.period,
  });

  int get totalSteps => history.fold(0, (sum, h) => sum + h.steps);

  double get totalDistance => history.fold(0.0, (sum, h) => sum + h.distance);

  int get totalCalories => history.fold(0, (sum, h) => sum + h.calories);

  int get totalActiveTime => history.fold(0, (sum, h) => sum + h.activeTime);

  double get avgSpeed {
    if (history.isEmpty) return 0.0;
    return history.fold(0.0, (sum, h) => sum + h.avgSpeed) / history.length;
  }

  double get avgStepsPerDay {
    if (history.isEmpty) return 0.0;
    return totalSteps / history.length;
  }

  double get avgDistancePerDay {
    if (history.isEmpty) return 0.0;
    return totalDistance / history.length;
  }

  double get avgCaloriesPerDay {
    if (history.isEmpty) return 0.0;
    return totalCalories / history.length;
  }

  int get activeDays => history.where((h) => h.steps > 0).length;

  // Formatted getters
  String get formattedTotalSteps => totalSteps.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );

  String get formattedTotalDistance => '${totalDistance.toStringAsFixed(2)} km';

  String get formattedTotalCalories => '$totalCalories cal';

  String get formattedAvgSpeed => '${avgSpeed.toStringAsFixed(1)} km/h';

  String get formattedAvgStepsPerDay => '${avgStepsPerDay.toStringAsFixed(0)}';
}
