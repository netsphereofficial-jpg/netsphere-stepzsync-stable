/// Constants for step tracking service
class StepConstants {
  // Firebase Collection Names
  static const String userStepsCollection = 'user_steps';
  static const String dailyStepsSubcollection = 'daily_steps';
  static const String usersCollection = 'users';
  static const String stepSummaryDocument = 'step_summary';

  // Sync Settings
  static const Duration syncDebounceInterval = Duration(seconds: 10);
  static const int minimumStepsForSync = 10;
  static const Duration healthKitSyncInterval = Duration(minutes: 30);
  static const int maxSyncRetries = 3;

  // Database Settings
  static const String sqliteDatabaseName = 'step_tracking.db';
  static const int sqliteDatabaseVersion = 3;
  static const String dailyStepsTableName = 'daily_steps';

  // Step Calculation Constants
  static const double averageStrideLength = 0.762; // meters (approximately 2.5 feet)
  static const double caloriesPerStep = 0.04; // approximate calories burned per step
  static const double stepsPerKm = 1312.0; // approximate steps per kilometer

  // Background Service
  static const String foregroundServiceChannelId = 'step_tracking_channel';
  static const String foregroundServiceChannelName = 'Step Tracking';
  static const String foregroundServiceNotificationTitle = 'StepzSync is tracking your steps';
  static const String foregroundServiceNotificationBody = 'Tracking in progress...';
  static const int foregroundServiceNotificationId = 1001;

  // Permissions
  static const List<String> requiredPermissions = [
    'activityRecognition',
    'health',
    'notification',
  ];

  // Data Source Priority
  static const String sourceHealthKit = 'healthkit';
  static const String sourcePedometer = 'pedometer';
  static const String sourceMerged = 'merged';

  // Error Messages
  static const String errorPermissionDenied = 'Required permissions not granted';
  static const String errorServiceNotInitialized = 'Step tracking service not initialized';
  static const String errorHealthKitNotAvailable = 'HealthKit not available on this device';
  static const String errorPedometerNotAvailable = 'Pedometer not available on this device';
  static const String errorFirebaseSyncFailed = 'Failed to sync data with Firebase';

  // Performance Limits
  static const int maxCachedDays = 90; // Keep 90 days in local cache
  static const int batchSyncSize = 30; // Sync max 30 days at once

  // Filter Options
  static const List<String> availableFilters = [
    'Today',
    'Yesterday',
    'Last 7 days',
    'Last 30 days',
    'Last 60 days',
    'Last 90 days',
    'All time',
  ];

  // Conversion Helpers

  /// Convert steps to kilometers
  static double stepsToKm(int steps) {
    return steps / stepsPerKm;
  }

  /// Convert steps to meters
  static double stepsToMeters(int steps) {
    return steps * averageStrideLength;
  }

  /// Calculate calories from steps
  static int stepsToCalories(int steps) {
    return (steps * caloriesPerStep).round();
  }

  /// Convert meters to kilometers
  static double metersToKm(double meters) {
    return meters / 1000;
  }

  /// Convert kilometers to steps
  static int kmToSteps(double km) {
    return (km * stepsPerKm).round();
  }
}

/// Data source enum
enum DataSource {
  pedometer,
  healthKit,
  merged;

  String get value {
    switch (this) {
      case DataSource.pedometer:
        return StepConstants.sourcePedometer;
      case DataSource.healthKit:
        return StepConstants.sourceHealthKit;
      case DataSource.merged:
        return StepConstants.sourceMerged;
    }
  }

  static DataSource fromString(String value) {
    switch (value) {
      case 'pedometer':
        return DataSource.pedometer;
      case 'healthkit':
        return DataSource.healthKit;
      case 'merged':
        return DataSource.merged;
      default:
        return DataSource.pedometer;
    }
  }
}
