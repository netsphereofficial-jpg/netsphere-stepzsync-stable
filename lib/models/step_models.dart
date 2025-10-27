import 'package:cloud_firestore/cloud_firestore.dart';

/// Data models for the comprehensive step tracking system
/// Supports both local storage and Firebase sync with real-time capabilities

/// Base step tracking model for all step-related data
class StepTrackingModel {
  final String id;
  final String userId;
  final DateTime timestamp;
  final int steps;
  final Map<String, dynamic>? metadata;

  const StepTrackingModel({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.steps,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'timestamp': timestamp.toIso8601String(),
    'steps': steps,
    'metadata': metadata,
  };

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'timestamp': Timestamp.fromDate(timestamp),
    'steps': steps,
    'metadata': metadata ?? {},
  };

  factory StepTrackingModel.fromJson(Map<String, dynamic> json) => StepTrackingModel(
    id: json['id'] as String,
    userId: json['userId'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    steps: json['steps'] as int,
    metadata: json['metadata'] as Map<String, dynamic>?,
  );

  factory StepTrackingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StepTrackingModel(
      id: doc.id,
      userId: data['userId'] as String,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      steps: data['steps'] as int,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  StepTrackingModel copyWith({
    String? id,
    String? userId,
    DateTime? timestamp,
    int? steps,
    Map<String, dynamic>? metadata,
  }) => StepTrackingModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    timestamp: timestamp ?? this.timestamp,
    steps: steps ?? this.steps,
    metadata: metadata ?? this.metadata,
  );
}

/// Global step data model for home screen tracking
class GlobalStepData {
  final String userId;
  final DateTime date;
  final int totalSteps;
  final int preRaceSteps;
  final int raceSteps;
  final double totalDistance;
  final int totalCalories;
  final int activeTime;
  final double avgSpeed;
  final DateTime lastUpdated;
  final List<StepIncrement> increments;
  final List<String> activeRaces;
  final Map<String, int> raceStepBreakdown;
  final int? todayBaselineBeforeFirstRace;

  const GlobalStepData({
    required this.userId,
    required this.date,
    required this.totalSteps,
    required this.preRaceSteps,
    required this.raceSteps,
    required this.totalDistance,
    required this.totalCalories,
    required this.activeTime,
    required this.avgSpeed,
    required this.lastUpdated,
    required this.increments,
    this.activeRaces = const [],
    this.raceStepBreakdown = const {},
    this.todayBaselineBeforeFirstRace,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'date': date.toIso8601String().split('T')[0],
    'totalSteps': totalSteps,
    'preRaceSteps': preRaceSteps,
    'raceSteps': raceSteps,
    'totalDistance': totalDistance,
    'totalCalories': totalCalories,
    'activeTime': activeTime,
    'avgSpeed': avgSpeed,
    'lastUpdated': lastUpdated.toIso8601String(),
    'increments': increments.map((e) => e.toJson()).toList(),
    'activeRaces': activeRaces,
    'raceStepBreakdown': raceStepBreakdown,
    'todayBaselineBeforeFirstRace': todayBaselineBeforeFirstRace,
  };

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'date': date.toIso8601String().split('T')[0],
    'totalSteps': totalSteps,
    'preRaceSteps': preRaceSteps,
    'raceSteps': raceSteps,
    'totalDistance': totalDistance,
    'totalCalories': totalCalories,
    'activeTime': activeTime,
    'avgSpeed': avgSpeed,
    'lastUpdated': Timestamp.fromDate(lastUpdated),
    'increments': increments.map((e) => e.toFirestore()).toList(),
    'activeRaces': activeRaces,
    'raceStepBreakdown': raceStepBreakdown,
    'todayBaselineBeforeFirstRace': todayBaselineBeforeFirstRace,
  };

  factory GlobalStepData.fromJson(Map<String, dynamic> json) => GlobalStepData(
    userId: json['userId'] as String,
    date: DateTime.parse(json['date'] as String),
    totalSteps: json['totalSteps'] as int,
    preRaceSteps: json['preRaceSteps'] as int,
    raceSteps: json['raceSteps'] as int,
    totalDistance: (json['totalDistance'] as num).toDouble(),
    totalCalories: json['totalCalories'] as int,
    activeTime: json['activeTime'] as int,
    avgSpeed: (json['avgSpeed'] as num).toDouble(),
    lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    increments: (json['increments'] as List)
        .map((e) => StepIncrement.fromJson(e as Map<String, dynamic>))
        .toList(),
    activeRaces: json['activeRaces'] != null ? List<String>.from(json['activeRaces']) : [],
    raceStepBreakdown: json['raceStepBreakdown'] != null ? Map<String, int>.from(json['raceStepBreakdown']) : {},
    todayBaselineBeforeFirstRace: json['todayBaselineBeforeFirstRace'] as int?,
  );

  factory GlobalStepData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GlobalStepData(
      userId: data['userId'] as String,
      date: DateTime.parse(data['date'] as String),
      totalSteps: data['totalSteps'] as int,
      preRaceSteps: data['preRaceSteps'] as int,
      raceSteps: data['raceSteps'] as int,
      totalDistance: (data['totalDistance'] as num).toDouble(),
      totalCalories: data['totalCalories'] as int,
      activeTime: data['activeTime'] as int,
      avgSpeed: (data['avgSpeed'] as num).toDouble(),
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
      increments: (data['increments'] as List)
          .map((e) => StepIncrement.fromFirestore(e as Map<String, dynamic>))
          .toList(),
      activeRaces: data['activeRaces'] != null ? List<String>.from(data['activeRaces']) : [],
      raceStepBreakdown: data['raceStepBreakdown'] != null ? Map<String, int>.from(data['raceStepBreakdown']) : {},
      todayBaselineBeforeFirstRace: data['todayBaselineBeforeFirstRace'] as int?,
    );
  }

  GlobalStepData copyWith({
    String? userId,
    DateTime? date,
    int? totalSteps,
    int? preRaceSteps,
    int? raceSteps,
    double? totalDistance,
    int? totalCalories,
    int? activeTime,
    double? avgSpeed,
    DateTime? lastUpdated,
    List<StepIncrement>? increments,
    List<String>? activeRaces,
    Map<String, int>? raceStepBreakdown,
    int? todayBaselineBeforeFirstRace,
  }) => GlobalStepData(
    userId: userId ?? this.userId,
    date: date ?? this.date,
    totalSteps: totalSteps ?? this.totalSteps,
    preRaceSteps: preRaceSteps ?? this.preRaceSteps,
    raceSteps: raceSteps ?? this.raceSteps,
    totalDistance: totalDistance ?? this.totalDistance,
    totalCalories: totalCalories ?? this.totalCalories,
    activeTime: activeTime ?? this.activeTime,
    avgSpeed: avgSpeed ?? this.avgSpeed,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    increments: increments ?? this.increments,
    activeRaces: activeRaces ?? this.activeRaces,
    raceStepBreakdown: raceStepBreakdown ?? this.raceStepBreakdown,
    todayBaselineBeforeFirstRace: todayBaselineBeforeFirstRace ?? this.todayBaselineBeforeFirstRace,
  );
}

/// Race-specific step tracking model
class RaceStepData {
  final String raceId;
  final String userId;
  final String participantId;
  final int stepsAtStart;
  final int currentSteps;
  final int raceSteps;
  final DateTime raceStartTime;
  final DateTime? raceEndTime;
  final DateTime lastUpdated;
  final bool isActive;
  final List<StepIncrement> raceIncrements;
  final Map<String, dynamic>? raceMetadata;

  const RaceStepData({
    required this.raceId,
    required this.userId,
    required this.participantId,
    required this.stepsAtStart,
    required this.currentSteps,
    required this.raceSteps,
    required this.raceStartTime,
    this.raceEndTime,
    required this.lastUpdated,
    required this.isActive,
    required this.raceIncrements,
    this.raceMetadata,
  });

  Map<String, dynamic> toJson() => {
    'raceId': raceId,
    'userId': userId,
    'participantId': participantId,
    'stepsAtStart': stepsAtStart,
    'currentSteps': currentSteps,
    'raceSteps': raceSteps,
    'raceStartTime': raceStartTime.toIso8601String(),
    'raceEndTime': raceEndTime?.toIso8601String(),
    'lastUpdated': lastUpdated.toIso8601String(),
    'isActive': isActive,
    'raceIncrements': raceIncrements.map((e) => e.toJson()).toList(),
    'raceMetadata': raceMetadata,
  };

  Map<String, dynamic> toFirestore() => {
    'raceId': raceId,
    'userId': userId,
    'participantId': participantId,
    'stepsAtStart': stepsAtStart,
    'currentSteps': currentSteps,
    'raceSteps': raceSteps,
    'raceStartTime': Timestamp.fromDate(raceStartTime),
    'raceEndTime': raceEndTime != null ? Timestamp.fromDate(raceEndTime!) : null,
    'lastUpdated': Timestamp.fromDate(lastUpdated),
    'isActive': isActive,
    'raceIncrements': raceIncrements.map((e) => e.toFirestore()).toList(),
    'raceMetadata': raceMetadata ?? {},
  };

  factory RaceStepData.fromJson(Map<String, dynamic> json) => RaceStepData(
    raceId: json['raceId'] as String,
    userId: json['userId'] as String,
    participantId: json['participantId'] as String,
    stepsAtStart: json['stepsAtStart'] as int,
    currentSteps: json['currentSteps'] as int,
    raceSteps: json['raceSteps'] as int,
    raceStartTime: DateTime.parse(json['raceStartTime'] as String),
    raceEndTime: json['raceEndTime'] != null ? DateTime.parse(json['raceEndTime'] as String) : null,
    lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    isActive: json['isActive'] as bool,
    raceIncrements: (json['raceIncrements'] as List)
        .map((e) => StepIncrement.fromJson(e as Map<String, dynamic>))
        .toList(),
    raceMetadata: json['raceMetadata'] as Map<String, dynamic>?,
  );

  factory RaceStepData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RaceStepData(
      raceId: data['raceId'] as String,
      userId: data['userId'] as String,
      participantId: data['participantId'] as String,
      stepsAtStart: data['stepsAtStart'] as int,
      currentSteps: data['currentSteps'] as int,
      raceSteps: data['raceSteps'] as int,
      raceStartTime: (data['raceStartTime'] as Timestamp).toDate(),
      raceEndTime: data['raceEndTime'] != null ? (data['raceEndTime'] as Timestamp).toDate() : null,
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
      isActive: data['isActive'] as bool,
      raceIncrements: (data['raceIncrements'] as List)
          .map((e) => StepIncrement.fromFirestore(e as Map<String, dynamic>))
          .toList(),
      raceMetadata: data['raceMetadata'] as Map<String, dynamic>?,
    );
  }

  RaceStepData copyWith({
    String? raceId,
    String? userId,
    String? participantId,
    int? stepsAtStart,
    int? currentSteps,
    int? raceSteps,
    DateTime? raceStartTime,
    DateTime? raceEndTime,
    DateTime? lastUpdated,
    bool? isActive,
    List<StepIncrement>? raceIncrements,
    Map<String, dynamic>? raceMetadata,
  }) => RaceStepData(
    raceId: raceId ?? this.raceId,
    userId: userId ?? this.userId,
    participantId: participantId ?? this.participantId,
    stepsAtStart: stepsAtStart ?? this.stepsAtStart,
    currentSteps: currentSteps ?? this.currentSteps,
    raceSteps: raceSteps ?? this.raceSteps,
    raceStartTime: raceStartTime ?? this.raceStartTime,
    raceEndTime: raceEndTime ?? this.raceEndTime,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    isActive: isActive ?? this.isActive,
    raceIncrements: raceIncrements ?? this.raceIncrements,
    raceMetadata: raceMetadata ?? this.raceMetadata,
  );
}

/// Individual step increment model for tracking differential changes
class StepIncrement {
  final String id;
  final DateTime timestamp;
  final int incrementValue;
  final String source; // 'pedometer', 'background', 'health', 'manual'
  final Map<String, dynamic>? metadata;

  const StepIncrement({
    required this.id,
    required this.timestamp,
    required this.incrementValue,
    required this.source,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'incrementValue': incrementValue,
    'source': source,
    'metadata': metadata,
  };

  Map<String, dynamic> toFirestore() => {
    'timestamp': Timestamp.fromDate(timestamp),
    'incrementValue': incrementValue,
    'source': source,
    'metadata': metadata ?? {},
  };

  factory StepIncrement.fromJson(Map<String, dynamic> json) => StepIncrement(
    id: json['id'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    incrementValue: json['incrementValue'] as int,
    source: json['source'] as String,
    metadata: json['metadata'] as Map<String, dynamic>?,
  );

  factory StepIncrement.fromFirestore(Map<String, dynamic> data) => StepIncrement(
    id: data['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
    timestamp: (data['timestamp'] as Timestamp).toDate(),
    incrementValue: data['incrementValue'] as int,
    source: data['source'] as String,
    metadata: data['metadata'] as Map<String, dynamic>?,
  );

  StepIncrement copyWith({
    String? id,
    DateTime? timestamp,
    int? incrementValue,
    String? source,
    Map<String, dynamic>? metadata,
  }) => StepIncrement(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
    incrementValue: incrementValue ?? this.incrementValue,
    source: source ?? this.source,
    metadata: metadata ?? this.metadata,
  );
}

/// Real-time step update model for Firebase streams
class RealTimeStepUpdate {
  final String userId;
  final DateTime timestamp;
  final int totalSteps;
  final Map<String, int> activeRaceSteps; // raceId -> steps
  final bool isOnline;
  final String deviceId;

  const RealTimeStepUpdate({
    required this.userId,
    required this.timestamp,
    required this.totalSteps,
    required this.activeRaceSteps,
    required this.isOnline,
    required this.deviceId,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'timestamp': timestamp.toIso8601String(),
    'totalSteps': totalSteps,
    'activeRaceSteps': activeRaceSteps,
    'isOnline': isOnline,
    'deviceId': deviceId,
  };

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'timestamp': Timestamp.fromDate(timestamp),
    'totalSteps': totalSteps,
    'activeRaceSteps': activeRaceSteps,
    'isOnline': isOnline,
    'deviceId': deviceId,
    'ttl': Timestamp.fromDate(timestamp.add(Duration(hours: 24))), // Auto-cleanup
  };

  factory RealTimeStepUpdate.fromJson(Map<String, dynamic> json) => RealTimeStepUpdate(
    userId: json['userId'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    totalSteps: json['totalSteps'] as int,
    activeRaceSteps: Map<String, int>.from(json['activeRaceSteps'] as Map),
    isOnline: json['isOnline'] as bool,
    deviceId: json['deviceId'] as String,
  );

  factory RealTimeStepUpdate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RealTimeStepUpdate(
      userId: data['userId'] as String,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      totalSteps: data['totalSteps'] as int,
      activeRaceSteps: Map<String, int>.from(data['activeRaceSteps'] as Map),
      isOnline: data['isOnline'] as bool,
      deviceId: data['deviceId'] as String,
    );
  }

  RealTimeStepUpdate copyWith({
    String? userId,
    DateTime? timestamp,
    int? totalSteps,
    Map<String, int>? activeRaceSteps,
    bool? isOnline,
    String? deviceId,
  }) => RealTimeStepUpdate(
    userId: userId ?? this.userId,
    timestamp: timestamp ?? this.timestamp,
    totalSteps: totalSteps ?? this.totalSteps,
    activeRaceSteps: activeRaceSteps ?? this.activeRaceSteps,
    isOnline: isOnline ?? this.isOnline,
    deviceId: deviceId ?? this.deviceId,
  );
}

/// Aggregated step statistics model
class StepStatistics {
  final String userId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final StepPeriodType periodType;
  final int totalSteps;
  final double totalDistance;
  final int totalCalories;
  final int activeTime;
  final double avgSpeed;
  final int bestDaySteps;
  final DateTime? bestDayDate;
  final List<DailyStepSummary> dailyBreakdown;

  const StepStatistics({
    required this.userId,
    required this.periodStart,
    required this.periodEnd,
    required this.periodType,
    required this.totalSteps,
    required this.totalDistance,
    required this.totalCalories,
    required this.activeTime,
    required this.avgSpeed,
    required this.bestDaySteps,
    this.bestDayDate,
    required this.dailyBreakdown,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'periodStart': periodStart.toIso8601String(),
    'periodEnd': periodEnd.toIso8601String(),
    'periodType': periodType.name,
    'totalSteps': totalSteps,
    'totalDistance': totalDistance,
    'totalCalories': totalCalories,
    'activeTime': activeTime,
    'avgSpeed': avgSpeed,
    'bestDaySteps': bestDaySteps,
    'bestDayDate': bestDayDate?.toIso8601String(),
    'dailyBreakdown': dailyBreakdown.map((e) => e.toJson()).toList(),
  };

  factory StepStatistics.fromJson(Map<String, dynamic> json) => StepStatistics(
    userId: json['userId'] as String,
    periodStart: DateTime.parse(json['periodStart'] as String),
    periodEnd: DateTime.parse(json['periodEnd'] as String),
    periodType: StepPeriodType.values.byName(json['periodType'] as String),
    totalSteps: json['totalSteps'] as int,
    totalDistance: (json['totalDistance'] as num).toDouble(),
    totalCalories: json['totalCalories'] as int,
    activeTime: json['activeTime'] as int,
    avgSpeed: (json['avgSpeed'] as num).toDouble(),
    bestDaySteps: json['bestDaySteps'] as int,
    bestDayDate: json['bestDayDate'] != null ? DateTime.parse(json['bestDayDate'] as String) : null,
    dailyBreakdown: (json['dailyBreakdown'] as List)
        .map((e) => DailyStepSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Daily step summary for statistics breakdown
class DailyStepSummary {
  final DateTime date;
  final int steps;
  final double distance;
  final int calories;
  final int activeTime;

  const DailyStepSummary({
    required this.date,
    required this.steps,
    required this.distance,
    required this.calories,
    required this.activeTime,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String().split('T')[0],
    'steps': steps,
    'distance': distance,
    'calories': calories,
    'activeTime': activeTime,
  };

  factory DailyStepSummary.fromJson(Map<String, dynamic> json) => DailyStepSummary(
    date: DateTime.parse(json['date'] as String),
    steps: json['steps'] as int,
    distance: (json['distance'] as num).toDouble(),
    calories: json['calories'] as int,
    activeTime: json['activeTime'] as int,
  );
}

/// Background sync status model
class BackgroundSyncStatus {
  final DateTime lastSyncTime;
  final bool isLocationActive;
  final bool isFirebaseConnected;
  final int pendingUpdates;
  final String? lastError;
  final Map<String, dynamic>? diagnostics;

  const BackgroundSyncStatus({
    required this.lastSyncTime,
    required this.isLocationActive,
    required this.isFirebaseConnected,
    required this.pendingUpdates,
    this.lastError,
    this.diagnostics,
  });

  Map<String, dynamic> toJson() => {
    'lastSyncTime': lastSyncTime.toIso8601String(),
    'isLocationActive': isLocationActive,
    'isFirebaseConnected': isFirebaseConnected,
    'pendingUpdates': pendingUpdates,
    'lastError': lastError,
    'diagnostics': diagnostics,
  };

  factory BackgroundSyncStatus.fromJson(Map<String, dynamic> json) => BackgroundSyncStatus(
    lastSyncTime: DateTime.parse(json['lastSyncTime'] as String),
    isLocationActive: json['isLocationActive'] as bool,
    isFirebaseConnected: json['isFirebaseConnected'] as bool,
    pendingUpdates: json['pendingUpdates'] as int,
    lastError: json['lastError'] as String?,
    diagnostics: json['diagnostics'] as Map<String, dynamic>?,
  );

  BackgroundSyncStatus copyWith({
    DateTime? lastSyncTime,
    bool? isLocationActive,
    bool? isFirebaseConnected,
    int? pendingUpdates,
    String? lastError,
    Map<String, dynamic>? diagnostics,
  }) => BackgroundSyncStatus(
    lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    isLocationActive: isLocationActive ?? this.isLocationActive,
    isFirebaseConnected: isFirebaseConnected ?? this.isFirebaseConnected,
    pendingUpdates: pendingUpdates ?? this.pendingUpdates,
    lastError: lastError ?? this.lastError,
    diagnostics: diagnostics ?? this.diagnostics,
  );
}

/// Race session tracking model for Firebase storage
class RaceSession {
  final String raceId;
  final String userId;
  final DateTime startTime;
  final int stepsAtStart;
  final int currentRaceSteps;
  final DateTime lastUpdated;
  final bool isActive;
  final String status; // 'active', 'paused', 'completed', 'cancelled'
  final Map<String, dynamic>? metadata;

  const RaceSession({
    required this.raceId,
    required this.userId,
    required this.startTime,
    required this.stepsAtStart,
    required this.currentRaceSteps,
    required this.lastUpdated,
    required this.isActive,
    required this.status,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'raceId': raceId,
    'userId': userId,
    'startTime': startTime.toIso8601String(),
    'stepsAtStart': stepsAtStart,
    'currentRaceSteps': currentRaceSteps,
    'lastUpdated': lastUpdated.toIso8601String(),
    'isActive': isActive,
    'status': status,
    'metadata': metadata,
  };

  Map<String, dynamic> toFirestore() => {
    'raceId': raceId,
    'userId': userId,
    'startTime': Timestamp.fromDate(startTime),
    'stepsAtStart': stepsAtStart,
    'currentRaceSteps': currentRaceSteps,
    'lastUpdated': Timestamp.fromDate(lastUpdated),
    'isActive': isActive,
    'status': status,
    'metadata': metadata ?? {},
  };

  factory RaceSession.fromJson(Map<String, dynamic> json) => RaceSession(
    raceId: json['raceId'] as String,
    userId: json['userId'] as String,
    startTime: DateTime.parse(json['startTime'] as String),
    stepsAtStart: json['stepsAtStart'] as int,
    currentRaceSteps: json['currentRaceSteps'] as int,
    lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    isActive: json['isActive'] as bool,
    status: json['status'] as String,
    metadata: json['metadata'] as Map<String, dynamic>?,
  );

  factory RaceSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RaceSession(
      raceId: data['raceId'] as String,
      userId: data['userId'] as String,
      startTime: (data['startTime'] as Timestamp).toDate(),
      stepsAtStart: data['stepsAtStart'] as int,
      currentRaceSteps: data['currentRaceSteps'] as int,
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
      isActive: data['isActive'] as bool,
      status: data['status'] as String,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  RaceSession copyWith({
    String? raceId,
    String? userId,
    DateTime? startTime,
    int? stepsAtStart,
    int? currentRaceSteps,
    DateTime? lastUpdated,
    bool? isActive,
    String? status,
    Map<String, dynamic>? metadata,
  }) => RaceSession(
    raceId: raceId ?? this.raceId,
    userId: userId ?? this.userId,
    startTime: startTime ?? this.startTime,
    stepsAtStart: stepsAtStart ?? this.stepsAtStart,
    currentRaceSteps: currentRaceSteps ?? this.currentRaceSteps,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    isActive: isActive ?? this.isActive,
    status: status ?? this.status,
    metadata: metadata ?? this.metadata,
  );
}

/// Enums for type safety
enum StepPeriodType { today, week, month, year, custom }

enum StepDataSource { pedometer, background, health, manual, sync }

enum RaceStepStatus { active, paused, completed, cancelled }

/// Extension methods for convenience
extension StepStatisticsExtensions on StepStatistics {
  String get formattedSteps => totalSteps.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]!},',
  );

  String get formattedDistance => '${totalDistance.toStringAsFixed(2)} km';

  String get formattedCalories => '${totalCalories} cal';

  String get formattedActiveTime {
    final hours = activeTime ~/ 60;
    final minutes = activeTime % 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }

  double get avgStepsPerDay {
    final days = periodEnd.difference(periodStart).inDays + 1;
    return days > 0 ? totalSteps / days : 0.0;
  }
}

extension GlobalStepDataExtensions on GlobalStepData {
  String get formattedSteps => totalSteps.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]!},',
  );

  String get formattedDistance => '${totalDistance.toStringAsFixed(2)} km';

  String get formattedCalories => '${totalCalories} cal';

  /// Calculate race steps for a specific time period
  int getRaceStepsForPeriod(DateTime start, DateTime end) {
    return increments
        .where((inc) =>
            inc.timestamp.isAfter(start) &&
            inc.timestamp.isBefore(end) &&
            inc.source != 'pre-race')
        .fold(0, (accumulator, inc) => accumulator + inc.incrementValue);
  }
}

extension RaceStepDataExtensions on RaceStepData {
  String get formattedRaceSteps => raceSteps.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]!},',
  );

  Duration get raceDuration {
    final endTime = raceEndTime ?? DateTime.now();
    return endTime.difference(raceStartTime);
  }

  double get raceDistance => raceSteps * 0.75 / 1000; // km

  String get formattedRaceDistance => '${raceDistance.toStringAsFixed(2)} km';
}