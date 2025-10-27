/// Health Sync Data Models
///
/// Models for managing health data synchronization between
/// HealthKit (iOS) and Health Connect (Android)

/// Complete health sync data payload
class HealthSyncData {
  // Today's stats
  final int todaySteps;
  final double todayDistance; // in kilometers
  final int todayCalories;
  final int todayActiveMinutes;

  // Overall stats (since app install)
  final int overallSteps;
  final double overallDistance; // in kilometers
  final int overallDays;

  // Historical daily data for period calculations
  final List<DailyHealthData> historicalData;

  // Sync metadata
  final DateTime syncTimestamp;
  final String source; // 'health_connect' or 'healthkit'

  HealthSyncData({
    required this.todaySteps,
    required this.todayDistance,
    required this.todayCalories,
    required this.todayActiveMinutes,
    required this.overallSteps,
    required this.overallDistance,
    required this.overallDays,
    required this.historicalData,
    required this.syncTimestamp,
    required this.source,
  });

  /// Create empty sync data (for initialization)
  factory HealthSyncData.empty() {
    return HealthSyncData(
      todaySteps: 0,
      todayDistance: 0.0,
      todayCalories: 0,
      todayActiveMinutes: 0,
      overallSteps: 0,
      overallDistance: 0.0,
      overallDays: 1,
      historicalData: [],
      syncTimestamp: DateTime.now(),
      source: 'none',
    );
  }

  /// Create from JSON (for caching)
  factory HealthSyncData.fromJson(Map<String, dynamic> json) {
    return HealthSyncData(
      todaySteps: json['todaySteps'] ?? 0,
      todayDistance: (json['todayDistance'] ?? 0.0).toDouble(),
      todayCalories: json['todayCalories'] ?? 0,
      todayActiveMinutes: json['todayActiveMinutes'] ?? 0,
      overallSteps: json['overallSteps'] ?? 0,
      overallDistance: (json['overallDistance'] ?? 0.0).toDouble(),
      overallDays: json['overallDays'] ?? 1,
      historicalData: (json['historicalData'] as List?)
              ?.map((e) => DailyHealthData.fromJson(e))
              .toList() ??
          [],
      syncTimestamp: DateTime.parse(json['syncTimestamp'] ?? DateTime.now().toIso8601String()),
      source: json['source'] ?? 'unknown',
    );
  }

  /// Convert to JSON (for caching)
  Map<String, dynamic> toJson() {
    return {
      'todaySteps': todaySteps,
      'todayDistance': todayDistance,
      'todayCalories': todayCalories,
      'todayActiveMinutes': todayActiveMinutes,
      'overallSteps': overallSteps,
      'overallDistance': overallDistance,
      'overallDays': overallDays,
      'historicalData': historicalData.map((e) => e.toJson()).toList(),
      'syncTimestamp': syncTimestamp.toIso8601String(),
      'source': source,
    };
  }

  @override
  String toString() {
    return 'HealthSyncData(today: $todaySteps steps, overall: $overallSteps steps, days: $overallDays, historical: ${historicalData.length} days, source: $source)';
  }
}

/// Daily health data for a specific date
class DailyHealthData {
  final DateTime date;
  final int steps;
  final double distance; // in kilometers
  final int calories;
  final int activeMinutes;
  final int? heartRateBpm; // Optional heart rate data

  DailyHealthData({
    required this.date,
    required this.steps,
    required this.distance,
    required this.calories,
    required this.activeMinutes,
    this.heartRateBpm,
  });

  /// Create from JSON
  factory DailyHealthData.fromJson(Map<String, dynamic> json) {
    return DailyHealthData(
      date: DateTime.parse(json['date']),
      steps: json['steps'] ?? 0,
      distance: (json['distance'] ?? 0.0).toDouble(),
      calories: json['calories'] ?? 0,
      activeMinutes: json['activeMinutes'] ?? 0,
      heartRateBpm: json['heartRateBpm'],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'steps': steps,
      'distance': distance,
      'calories': calories,
      'activeMinutes': activeMinutes,
      if (heartRateBpm != null) 'heartRateBpm': heartRateBpm,
    };
  }

  /// Create empty daily data for a specific date
  factory DailyHealthData.empty(DateTime date) {
    return DailyHealthData(
      date: date,
      steps: 0,
      distance: 0.0,
      calories: 0,
      activeMinutes: 0,
    );
  }

  @override
  String toString() {
    return 'DailyHealthData(${date.toIso8601String().split('T')[0]}: $steps steps, $distance km, $calories cal, $activeMinutes min)';
  }
}

/// Health sync status and result
enum HealthSyncStatus {
  idle,
  connecting,
  syncing,
  updating,
  completed,
  failed,
  permissionDenied,
  notAvailable,
}

/// Result of a health sync operation
class HealthSyncResult {
  final HealthSyncStatus status;
  final HealthSyncData? data;
  final String? errorMessage;
  final int itemsSynced;

  HealthSyncResult({
    required this.status,
    this.data,
    this.errorMessage,
    this.itemsSynced = 0,
  });

  bool get isSuccess => status == HealthSyncStatus.completed && data != null;
  bool get isFailed => status == HealthSyncStatus.failed || status == HealthSyncStatus.permissionDenied;

  /// Success result
  factory HealthSyncResult.success(HealthSyncData data, int itemsSynced) {
    return HealthSyncResult(
      status: HealthSyncStatus.completed,
      data: data,
      itemsSynced: itemsSynced,
    );
  }

  /// Failed result
  factory HealthSyncResult.failure(String errorMessage, {HealthSyncStatus? status}) {
    return HealthSyncResult(
      status: status ?? HealthSyncStatus.failed,
      errorMessage: errorMessage,
    );
  }

  /// Permission denied result
  factory HealthSyncResult.permissionDenied() {
    return HealthSyncResult(
      status: HealthSyncStatus.permissionDenied,
      errorMessage: 'Health permissions not granted',
    );
  }

  /// Not available result (Health Connect/HealthKit not available)
  factory HealthSyncResult.notAvailable() {
    return HealthSyncResult(
      status: HealthSyncStatus.notAvailable,
      errorMessage: 'Health services not available on this device',
    );
  }

  @override
  String toString() {
    return 'HealthSyncResult(status: $status, items: $itemsSynced, error: $errorMessage)';
  }
}
