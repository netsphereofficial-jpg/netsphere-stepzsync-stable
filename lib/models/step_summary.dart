import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the overall summary of step tracking data
/// Stored in Firebase: users/{userId}/step_summary
/// Used for quick access to aggregate statistics
class StepSummary {
  final int totalDays; // Total number of days with step data
  final int totalSteps; // Lifetime total steps
  final double totalDistanceKm; // Lifetime total distance
  final int totalCalories; // Lifetime total calories
  final int totalActiveTimeMinutes; // Lifetime total active time
  final DateTime? firstTrackingDate; // First day of tracking
  final DateTime lastUpdated;

  StepSummary({
    required this.totalDays,
    required this.totalSteps,
    required this.totalDistanceKm,
    required this.totalCalories,
    required this.totalActiveTimeMinutes,
    this.firstTrackingDate,
    required this.lastUpdated,
  });

  /// Create empty summary
  factory StepSummary.empty() {
    return StepSummary(
      totalDays: 0,
      totalSteps: 0,
      totalDistanceKm: 0.0,
      totalCalories: 0,
      totalActiveTimeMinutes: 0,
      firstTrackingDate: null,
      lastUpdated: DateTime.now(),
    );
  }

  /// Create from Firebase document
  factory StepSummary.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) return StepSummary.empty();
    final data = doc.data() as Map<String, dynamic>;
    return StepSummary.fromMap(data);
  }

  /// Create from map
  factory StepSummary.fromMap(Map<String, dynamic> map) {
    return StepSummary(
      totalDays: map['totalDays'] as int? ?? 0,
      totalSteps: map['totalSteps'] as int? ?? 0,
      totalDistanceKm: (map['totalDistance'] as num?)?.toDouble() ?? 0.0,
      totalCalories: map['totalCalories'] as int? ?? 0,
      totalActiveTimeMinutes: map['totalActiveTimeMinutes'] as int? ?? 0,
      firstTrackingDate: _parseTimestamp(map['firstTrackingDate']),
      lastUpdated: _parseTimestamp(map['lastUpdated']) ?? DateTime.now(),
    );
  }

  /// Convert to map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'totalDays': totalDays,
      'totalSteps': totalSteps,
      'totalDistance': totalDistanceKm,
      'totalCalories': totalCalories,
      'totalActiveTimeMinutes': totalActiveTimeMinutes,
      'firstTrackingDate': firstTrackingDate != null
          ? Timestamp.fromDate(firstTrackingDate!)
          : null,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  /// Copy with modifications
  StepSummary copyWith({
    int? totalDays,
    int? totalSteps,
    double? totalDistanceKm,
    int? totalCalories,
    int? totalActiveTimeMinutes,
    DateTime? firstTrackingDate,
    DateTime? lastUpdated,
  }) {
    return StepSummary(
      totalDays: totalDays ?? this.totalDays,
      totalSteps: totalSteps ?? this.totalSteps,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      totalCalories: totalCalories ?? this.totalCalories,
      totalActiveTimeMinutes: totalActiveTimeMinutes ?? this.totalActiveTimeMinutes,
      firstTrackingDate: firstTrackingDate ?? this.firstTrackingDate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Add data from a daily step record
  StepSummary addDailyData({
    required int steps,
    required double distanceKm,
    required int calories,
    required int activeTimeMinutes,
    required DateTime date,
  }) {
    return StepSummary(
      totalDays: totalDays + 1,
      totalSteps: totalSteps + steps,
      totalDistanceKm: totalDistanceKm + distanceKm,
      totalCalories: totalCalories + calories,
      totalActiveTimeMinutes: totalActiveTimeMinutes + activeTimeMinutes,
      firstTrackingDate: firstTrackingDate ?? date,
      lastUpdated: DateTime.now(),
    );
  }

  /// Update with incremental data (for same-day updates)
  StepSummary updateWithIncrement({
    required int stepsDelta,
    required double distanceDelta,
    required int caloriesDelta,
    required int activeTimeDelta,
  }) {
    return StepSummary(
      totalDays: totalDays,
      totalSteps: totalSteps + stepsDelta,
      totalDistanceKm: totalDistanceKm + distanceDelta,
      totalCalories: totalCalories + caloriesDelta,
      totalActiveTimeMinutes: totalActiveTimeMinutes + activeTimeDelta,
      firstTrackingDate: firstTrackingDate,
      lastUpdated: DateTime.now(),
    );
  }

  // Helper methods

  static DateTime? _parseTimestamp(dynamic data) {
    if (data == null) return null;
    if (data is Timestamp) {
      return data.toDate();
    } else if (data is DateTime) {
      return data;
    } else if (data is int) {
      return DateTime.fromMillisecondsSinceEpoch(data);
    }
    return null;
  }

  /// Get average steps per day
  double get averageStepsPerDay {
    if (totalDays == 0) return 0.0;
    return totalSteps / totalDays;
  }

  /// Get average distance per day
  double get averageDistancePerDay {
    if (totalDays == 0) return 0.0;
    return totalDistanceKm / totalDays;
  }

  /// Get tracking duration in days
  int get trackingDurationDays {
    if (firstTrackingDate == null) return 0;
    return DateTime.now().difference(firstTrackingDate!).inDays + 1;
  }

  @override
  String toString() {
    return 'StepSummary(totalDays: $totalDays, totalSteps: $totalSteps, totalDistance: ${totalDistanceKm.toStringAsFixed(2)}km)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StepSummary &&
        other.totalDays == totalDays &&
        other.totalSteps == totalSteps;
  }

  @override
  int get hashCode => Object.hash(totalDays, totalSteps);
}
