import 'package:health/health.dart';
import 'dart:io';

/// Health data configuration for HealthKit (iOS) and Health Connect (Android)
///
/// Defines what health data types we want to access and sync
/// Updated to request ALL available Health Connect permissions
class HealthConfig {
  /// Health data types to request and sync
  /// This list includes ALL data types supported by Android Health Connect
  static List<HealthDataType> get dataTypes {
    if (Platform.isAndroid) {
      // All Android Health Connect supported data types
      return [
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.BASAL_ENERGY_BURNED,
        HealthDataType.BLOOD_GLUCOSE,
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthDataType.BODY_FAT_PERCENTAGE,
        HealthDataType.BODY_MASS_INDEX,
        HealthDataType.BODY_TEMPERATURE,
        HealthDataType.BODY_WATER_MASS,
        HealthDataType.DISTANCE_DELTA,
        HealthDataType.FLIGHTS_CLIMBED,
        HealthDataType.HEART_RATE,
        HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
        HealthDataType.HEIGHT,
        HealthDataType.LEAN_BODY_MASS,
        HealthDataType.MENSTRUATION_FLOW,
        HealthDataType.NUTRITION,
        HealthDataType.RESPIRATORY_RATE,
        HealthDataType.RESTING_HEART_RATE,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_AWAKE_IN_BED,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_OUT_OF_BED,
        HealthDataType.SLEEP_REM,
        HealthDataType.SLEEP_SESSION,
        HealthDataType.SLEEP_UNKNOWN,
        HealthDataType.SPEED,
        HealthDataType.STEPS,
        HealthDataType.TOTAL_CALORIES_BURNED,
        HealthDataType.WATER,
        HealthDataType.WEIGHT,
        HealthDataType.WORKOUT,
      ];
    } else {
      // iOS HealthKit - comprehensive list
      return [
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.BASAL_ENERGY_BURNED,
        HealthDataType.BLOOD_GLUCOSE,
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthDataType.BODY_FAT_PERCENTAGE,
        HealthDataType.BODY_MASS_INDEX,
        HealthDataType.BODY_TEMPERATURE,
        HealthDataType.DISTANCE_WALKING_RUNNING,
        HealthDataType.DISTANCE_SWIMMING,
        HealthDataType.DISTANCE_CYCLING,
        HealthDataType.EXERCISE_TIME,
        HealthDataType.FLIGHTS_CLIMBED,
        HealthDataType.HEART_RATE,
        HealthDataType.HEART_RATE_VARIABILITY_SDNN,
        HealthDataType.HEIGHT,
        HealthDataType.LEAN_BODY_MASS,
        HealthDataType.MINDFULNESS,
        HealthDataType.RESTING_HEART_RATE,
        HealthDataType.RESPIRATORY_RATE,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_IN_BED,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_REM,
        HealthDataType.STEPS,
        HealthDataType.WAIST_CIRCUMFERENCE,
        HealthDataType.WALKING_HEART_RATE,
        HealthDataType.WATER,
        HealthDataType.WEIGHT,
        HealthDataType.WORKOUT,
      ];
    }
  }

  /// Permissions for each data type (READ_WRITE for maximum access)
  /// Requesting READ_WRITE for all data types to allow comprehensive health data management
  static List<HealthDataAccess> get permissions {
    return dataTypes.map((type) {
      // Request READ_WRITE permission for all data types
      // This allows both reading existing data and writing new data
      return HealthDataAccess.READ_WRITE;
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
