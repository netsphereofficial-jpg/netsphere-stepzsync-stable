import 'package:health/health.dart';
import 'dart:io';

/// Health data configuration for HealthKit (iOS) and Health Connect (Android)
///
/// Defines what health data types we want to access and sync
class HealthConfig {
  /// Health data types to request and sync
  static List<HealthDataType> get dataTypes {
    final types = <HealthDataType>[
      HealthDataType.STEPS,
      // Platform-specific distance type: iOS uses WALKING_RUNNING, Android uses DELTA
      Platform.isIOS
          ? HealthDataType.DISTANCE_WALKING_RUNNING
          : HealthDataType.DISTANCE_DELTA,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.HEART_RATE,
      HealthDataType.BLOOD_OXYGEN,
      HealthDataType.RESPIRATORY_RATE,
    ];

    // EXERCISE_TIME is iOS-only (HealthKit concept)
    // On Android Health Connect, there's no equivalent - we track via step activity
    if (Platform.isIOS) {
      types.add(HealthDataType.EXERCISE_TIME);
    }

    return types;
  }

  /// Permissions for each data type (READ and WRITE access)
  /// We need WRITE access to sync pedometer steps back to HealthKit
  static List<HealthDataAccess> get permissions {
    return dataTypes.map((type) {
      // Only request WRITE permission for STEPS
      // All other data types are READ only
      if (type == HealthDataType.STEPS) {
        return HealthDataAccess.READ_WRITE;
      }
      return HealthDataAccess.READ;
    }).toList();
  }

  /// Number of days to backfill historical data
  static const int historicalDaysToSync = 30;

  /// Minimum interval between syncs (prevent excessive syncing)
  static const Duration minimumSyncInterval = Duration(hours: 6);

  /// Sync timeout duration
  static const Duration syncTimeout = Duration(seconds: 15);

  /// Conversion constants
  static const double metersToKilometers = 0.001;
  static const double caloriesPerKcal = 1.0; // HealthKit returns kcal

  /// Platform-specific health app names
  static String get healthAppName =>
      Platform.isIOS ? 'Apple Health' : 'Health Connect';

  /// Platform-specific settings navigation
  static String get healthAppPackage =>
      Platform.isIOS ? '' : 'com.google.android.apps.healthdata';

  /// Data type display names for UI
  static Map<HealthDataType, String> dataTypeNames = {
    HealthDataType.STEPS: 'Steps',
    HealthDataType.DISTANCE_DELTA: 'Distance', // Android
    HealthDataType.DISTANCE_WALKING_RUNNING: 'Distance', // iOS
    HealthDataType.ACTIVE_ENERGY_BURNED: 'Calories',
    HealthDataType.EXERCISE_TIME: 'Active Minutes',
    HealthDataType.HEART_RATE: 'Heart Rate',
    HealthDataType.BLOOD_OXYGEN: 'Blood Oxygen',
    HealthDataType.RESPIRATORY_RATE: 'Respiratory Rate',
  };

  /// Check if a specific health data type is available
  static bool isDataTypeSupported(HealthDataType type) {
    // EXERCISE_TIME is cross-platform
    return dataTypes.contains(type);
  }

  /// Get active time data type (cross-platform)
  static HealthDataType get activeTimeDataType {
    return HealthDataType.EXERCISE_TIME; // Cross-platform
  }

  /// Minimum steps threshold to consider a day as "active"
  static const int minimumDailyStepsThreshold = 100;

  /// Debug logging enabled
  static const bool enableDebugLogging = true;

  /// Log prefix for health sync operations
  static const String logPrefix = '🏥 [HEALTH_SYNC]';
}
