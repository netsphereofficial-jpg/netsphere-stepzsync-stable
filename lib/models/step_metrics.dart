import 'package:intl/intl.dart';

class StepMetrics {
  final int userId;
  final DateTime date;
  final int steps;
  final double calories;
  final double distance;
  final double avgSpeed;
  final int activeTime; // in minutes
  final String duration; // Format: HH:mm
  final DateTime createdAt;
  final DateTime updatedAt;

  StepMetrics({
    required this.userId,
    required this.date,
    required this.steps,
    required this.calories,
    required this.distance,
    required this.avgSpeed,
    required this.activeTime,
    required this.duration,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory StepMetrics.fromMap(Map<String, dynamic> map) {
    return StepMetrics(
      userId: map['userId'] as int,
      date: DateFormat('yyyy-MM-dd').parse(map['date'] as String),
      steps: map['steps'] as int,
      calories: (map['calories'] as num).toDouble(),
      distance: (map['distance'] as num).toDouble(),
      avgSpeed: (map['avgSpeed'] as num).toDouble(),
      activeTime: map['activeTime'] as int,
      duration: map['duration'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': DateFormat('yyyy-MM-dd').format(date),
      'steps': steps,
      'calories': calories,
      'distance': distance,
      'avgSpeed': avgSpeed,
      'activeTime': activeTime,
      'duration': duration,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory StepMetrics.empty({required int userId}) {
    final now = DateTime.now();
    return StepMetrics(
      userId: userId,
      date: now,
      steps: 0,
      calories: 0.0,
      distance: 0.0,
      avgSpeed: 0.0,
      activeTime: 0,
      duration: "00:00",
      createdAt: now,
      updatedAt: now,
    );
  }

  StepMetrics copyWith({
    int? userId,
    DateTime? date,
    int? steps,
    double? calories,
    double? distance,
    double? avgSpeed,
    int? activeTime,
    String? duration,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StepMetrics(
      userId: userId ?? this.userId,
      date: date ?? this.date,
      steps: steps ?? this.steps,
      calories: calories ?? this.calories,
      distance: distance ?? this.distance,
      avgSpeed: avgSpeed ?? this.avgSpeed,
      activeTime: activeTime ?? this.activeTime,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
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

  String get formattedCalories => '${calories.toStringAsFixed(0)} cal';

  String get formattedDate => DateFormat('MMM dd, yyyy').format(date);

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }

  @override
  String toString() {
    return 'StepMetrics(userId: $userId, date: ${DateFormat('yyyy-MM-dd').format(date)}, steps: $steps, distance: ${distance}km)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is StepMetrics &&
      other.userId == userId &&
      other.date == date &&
      other.steps == steps &&
      other.calories == calories &&
      other.distance == distance &&
      other.avgSpeed == avgSpeed &&
      other.activeTime == activeTime &&
      other.duration == duration;
  }

  @override
  int get hashCode {
    return userId.hashCode ^
      date.hashCode ^
      steps.hashCode ^
      calories.hashCode ^
      distance.hashCode ^
      avgSpeed.hashCode ^
      activeTime.hashCode ^
      duration.hashCode;
  }
}