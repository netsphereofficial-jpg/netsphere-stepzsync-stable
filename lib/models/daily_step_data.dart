import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single day's step tracking data
/// Combines data from both HealthKit/Health Connect and Pedometer sources
/// Stored in Firebase: users/{userId}/daily_steps/{YYYY-MM-DD}
/// Cached locally in SQLite for offline access
class DailyStepData {
  /// Date in YYYY-MM-DD format (UTC normalized)
  final String date;

  /// Total steps for the day
  final int steps;

  /// Distance covered in kilometers
  final double distance;

  /// Calories burned
  final int calories;

  /// Active time in minutes
  final int activeMinutes;

  /// Last sync timestamp
  final DateTime syncedAt;

  /// Data source: 'healthkit', 'health_connect', 'pedometer', or 'hybrid'
  final String source;

  /// Whether this data has been synced to Firebase
  final bool isSynced;

  /// Steps from pedometer sensor (incremental tracking)
  final int? pedometerSteps;

  /// Steps from HealthKit/Health Connect (baseline)
  final int? healthKitSteps;

  /// Hourly breakdown for detailed analytics (hour 0-23 -> steps)
  final Map<int, int> hourlyBreakdown;

  /// Created timestamp
  final DateTime createdAt;

  /// Average speed in km/h (calculated field)
  double get averageSpeed {
    if (activeMinutes == 0) return 0.0;
    final hours = activeMinutes / 60.0;
    return distance / hours;
  }

  DailyStepData({
    required this.date,
    required this.steps,
    required this.distance,
    required this.calories,
    required this.activeMinutes,
    required this.syncedAt,
    required this.source,
    this.isSynced = true,
    this.pedometerSteps,
    this.healthKitSteps,
    Map<int, int>? hourlyBreakdown,
    DateTime? createdAt,
  })  : hourlyBreakdown = hourlyBreakdown ?? {},
        createdAt = createdAt ?? DateTime.now();

  /// Create from Firebase document
  factory DailyStepData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyStepData.fromJson(data, doc.id);
  }

  /// Create from JSON with optional date override
  factory DailyStepData.fromJson(
    Map<String, dynamic> json, [
    String? dateOverride,
  ]) {
    return DailyStepData(
      date: dateOverride ?? json['date'] as String,
      steps: json['steps'] as int? ?? 0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      calories: json['calories'] as int? ?? 0,
      activeMinutes: json['activeMinutes'] as int? ?? 0,
      syncedAt: json['syncedAt'] != null
          ? _parseTimestamp(json['syncedAt'])
          : DateTime.now(),
      source: json['source'] as String? ?? 'unknown',
      isSynced: json['isSynced'] as bool? ?? true,
      pedometerSteps: json['pedometerSteps'] as int?,
      healthKitSteps: json['healthKitSteps'] as int?,
      hourlyBreakdown: _parseHourlyBreakdown(json['hourlyBreakdown']),
      createdAt: json['createdAt'] != null
          ? _parseTimestamp(json['createdAt'])
          : DateTime.now(),
    );
  }

  /// Convert to JSON for Firebase storage
  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'steps': steps,
      'distance': distance,
      'calories': calories,
      'activeMinutes': activeMinutes,
      'syncedAt': Timestamp.fromDate(syncedAt),
      'source': source,
      'isSynced': isSynced,
      'pedometerSteps': pedometerSteps,
      'healthKitSteps': healthKitSteps,
      'hourlyBreakdown': hourlyBreakdown,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Convert to SQLite-friendly map (uses String/Int for timestamps)
  Map<String, dynamic> toSqliteMap() {
    return {
      'date': date,
      'steps': steps,
      'distance': distance,
      'calories': calories,
      'activeMinutes': activeMinutes,
      'syncedAt': syncedAt.millisecondsSinceEpoch,
      'source': source,
      'isSynced': isSynced ? 1 : 0,
      'pedometerSteps': pedometerSteps,
      'healthKitSteps': healthKitSteps,
      'hourlyBreakdown': _hourlyBreakdownToString(hourlyBreakdown),
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Create from SQLite row
  factory DailyStepData.fromSqliteMap(Map<String, dynamic> map) {
    return DailyStepData(
      date: map['date'] as String,
      steps: map['steps'] as int,
      distance: (map['distance'] as num).toDouble(),
      calories: map['calories'] as int,
      activeMinutes: map['activeMinutes'] as int,
      syncedAt: DateTime.fromMillisecondsSinceEpoch(map['syncedAt'] as int),
      source: map['source'] as String,
      isSynced: (map['isSynced'] as int) == 1,
      pedometerSteps: map['pedometerSteps'] as int?,
      healthKitSteps: map['healthKitSteps'] as int?,
      hourlyBreakdown: _parseHourlyBreakdownString(map['hourlyBreakdown'] as String?),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  /// Create a copy with updated fields
  DailyStepData copyWith({
    String? date,
    int? steps,
    double? distance,
    int? calories,
    int? activeMinutes,
    DateTime? syncedAt,
    String? source,
    bool? isSynced,
    int? pedometerSteps,
    int? healthKitSteps,
    Map<int, int>? hourlyBreakdown,
    DateTime? createdAt,
  }) {
    return DailyStepData(
      date: date ?? this.date,
      steps: steps ?? this.steps,
      distance: distance ?? this.distance,
      calories: calories ?? this.calories,
      activeMinutes: activeMinutes ?? this.activeMinutes,
      syncedAt: syncedAt ?? this.syncedAt,
      source: source ?? this.source,
      isSynced: isSynced ?? this.isSynced,
      pedometerSteps: pedometerSteps ?? this.pedometerSteps,
      healthKitSteps: healthKitSteps ?? this.healthKitSteps,
      hourlyBreakdown: hourlyBreakdown ?? this.hourlyBreakdown,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Merge with another DailyStepData (takes maximum values)
  /// Useful for combining HealthKit baseline with pedometer increments
  DailyStepData merge(DailyStepData other) {
    if (date != other.date) {
      throw ArgumentError('Cannot merge data from different dates: $date vs ${other.date}');
    }

    // Combine hourly breakdowns
    final mergedHourly = Map<int, int>.from(hourlyBreakdown);
    other.hourlyBreakdown.forEach((hour, otherSteps) {
      mergedHourly[hour] = (mergedHourly[hour] ?? 0) > otherSteps
          ? mergedHourly[hour]!
          : otherSteps;
    });

    return DailyStepData(
      date: date,
      steps: steps > other.steps ? steps : other.steps,
      distance: distance > other.distance ? distance : other.distance,
      calories: calories > other.calories ? calories : other.calories,
      activeMinutes: activeMinutes > other.activeMinutes
          ? activeMinutes
          : other.activeMinutes,
      syncedAt: syncedAt.isAfter(other.syncedAt) ? syncedAt : other.syncedAt,
      source: 'hybrid', // Always mark merged data as hybrid
      isSynced: isSynced && other.isSynced,
      pedometerSteps: other.pedometerSteps ?? pedometerSteps,
      healthKitSteps: other.healthKitSteps ?? healthKitSteps,
      hourlyBreakdown: mergedHourly,
      createdAt: createdAt.isBefore(other.createdAt) ? createdAt : other.createdAt,
    );
  }

  /// Create empty data for a specific date
  factory DailyStepData.empty(String date) {
    final now = DateTime.now();
    return DailyStepData(
      date: date,
      steps: 0,
      distance: 0.0,
      calories: 0,
      activeMinutes: 0,
      syncedAt: now,
      source: 'none',
      isSynced: true,
      createdAt: now,
    );
  }

  /// Get today's date in YYYY-MM-DD format (UTC normalized)
  static String getTodayDate() {
    final now = DateTime.now();
    return formatDate(now);
  }

  /// Get yesterday's date in YYYY-MM-DD format
  static String getYesterdayDate() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return formatDate(yesterday);
  }

  /// Parse date string to DateTime (start of day)
  static DateTime parseDate(String dateStr) {
    return DateTime.parse(dateStr);
  }

  /// Format DateTime to date string (YYYY-MM-DD)
  static String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Check if this data is from today
  bool get isToday => date == getTodayDate();

  /// Check if this data is from yesterday
  bool get isYesterday => date == getYesterdayDate();

  // ================== PRIVATE HELPER METHODS ==================

  static Map<int, int> _parseHourlyBreakdown(dynamic data) {
    if (data == null) return {};
    if (data is Map) {
      return data.map((key, value) => MapEntry(
        int.parse(key.toString()),
        (value as num).toInt(),
      ));
    }
    return {};
  }

  static String _hourlyBreakdownToString(Map<int, int> breakdown) {
    if (breakdown.isEmpty) return '{}';
    final entries = breakdown.entries.map((e) => '"${e.key}":${e.value}').join(',');
    return '{$entries}';
  }

  static Map<int, int> _parseHourlyBreakdownString(String? data) {
    if (data == null || data.isEmpty || data == '{}') return {};
    try {
      final cleaned = data.substring(1, data.length - 1); // Remove { }
      if (cleaned.isEmpty) return {};

      final pairs = cleaned.split(',');
      final Map<int, int> result = {};

      for (final pair in pairs) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          final hour = int.parse(parts[0].replaceAll('"', '').trim());
          final steps = int.parse(parts[1].trim());
          result[hour] = steps;
        }
      }
      return result;
    } catch (e) {
      print('⚠️ Error parsing hourly breakdown: $e');
      return {};
    }
  }

  static DateTime _parseTimestamp(dynamic data) {
    if (data is Timestamp) {
      return data.toDate();
    } else if (data is DateTime) {
      return data;
    } else if (data is int) {
      return DateTime.fromMillisecondsSinceEpoch(data);
    } else if (data is String) {
      return DateTime.parse(data);
    }
    return DateTime.now();
  }

  @override
  String toString() {
    return 'DailyStepData(date: $date, steps: $steps, distance: ${distance.toStringAsFixed(2)}km, '
        'calories: $calories, activeMinutes: $activeMinutes, source: $source, synced: $isSynced)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DailyStepData && other.date == date;
  }

  @override
  int get hashCode => date.hashCode;
}
