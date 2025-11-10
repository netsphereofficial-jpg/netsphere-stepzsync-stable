import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:health/health.dart';
import 'package:synchronized/synchronized.dart';
import 'package:stepzsync/services/step_tracking_service.dart';
import 'package:stepzsync/services/race_step_sync_service.dart';
import '../config/health_config.dart';
import '../models/health_sync_models.dart';
import '../models/daily_step_data.dart';
import '../repositories/step_data_repository.dart';
import '../utils/health_permissions_helper.dart';
import '../utils/guest_utils.dart';
import 'preferences_service.dart';

/// Core Health Sync Service
///
/// Manages synchronization with HealthKit (iOS) and Health Connect (Android)
/// Fetches health data and reconciles with local step tracking
class HealthSyncService extends GetxController {
  // Health instance
  final Health _health = Health();

  // Helper services
  final HealthPermissionsHelper _permissionsHelper = HealthPermissionsHelper();
  final PreferencesService _preferencesService = PreferencesService();

  // Observable state
  final Rx<HealthSyncStatus> syncStatus = HealthSyncStatus.idle.obs;
  final RxBool isSyncing = false.obs;
  final RxBool isHealthAvailable = false.obs;
  final RxBool hasPermissions = false.obs;

  // Stream controller for sync status updates
  final StreamController<HealthSyncStatus> _syncStatusController =
      StreamController<HealthSyncStatus>.broadcast();

  Stream<HealthSyncStatus> get syncStatusStream => _syncStatusController.stream;

  // Last sync data cache
  HealthSyncData? _lastSyncData;

  // Initialization signaling - use Completer instead of polling/delays
  final Completer<bool> _initCompleter = Completer<bool>();

  /// Future that completes when initialization is done
  /// Returns true if health services are available, false otherwise
  Future<bool> get initializationComplete => _initCompleter.future;

  // Concurrency control - protect sync operations from concurrent access
  final Lock _syncLock = Lock();

  @override
  void onInit() {
    super.onInit();
    _initializeHealthService();
  }

  /// Initialize health service
  Future<void> _initializeHealthService() async {
    // Check if already initialized
    if (_initCompleter.isCompleted) {
      print('${HealthConfig.logPrefix} Already initialized');
      return;
    }

    try {
      print('${HealthConfig.logPrefix} Initializing health sync service...');

      // Skip for guest users
      if (GuestUtils.isGuest()) {
        print('${HealthConfig.logPrefix} Skipping health sync for guest user');
        isHealthAvailable.value = false;
        _initCompleter.complete(false);
        return;
      }

      // Check if health is available
      final available = await _permissionsHelper.isHealthAvailable();
      isHealthAvailable.value = available;

      if (!available) {
        print('${HealthConfig.logPrefix} Health services not available');
        _initCompleter.complete(false);
        return;
      }

      // Check permissions
      final hasPerms = await _permissionsHelper.hasHealthPermissions();
      hasPermissions.value = hasPerms;

      if (!hasPerms) {
        print('${HealthConfig.logPrefix} Health permissions not granted yet');
      } else {
        print('${HealthConfig.logPrefix} ✅ Health sync service initialized successfully');
      }

      // Complete initialization (successful even without permissions)
      _initCompleter.complete(available);
    } catch (e) {
      print('${HealthConfig.logPrefix} ❌ Error initializing health service: $e');
      isHealthAvailable.value = false;
      _initCompleter.complete(false);
    }
  }

  /// Request health permissions
  ///
  /// [skipOnboarding] - If true, skips the onboarding check for background sync operations
  Future<bool> requestPermissions({bool skipOnboarding = false}) async {
    try {


      final granted = await _permissionsHelper.requestHealthPermissions(
        skipOnboarding: skipOnboarding,
      );
      hasPermissions.value = granted;

      if (granted) {
        await _preferencesService.setHealthPermissionsGranted(true);
      }

      return granted;
    } catch (e) {
      print('${HealthConfig.logPrefix} Error requesting permissions: $e');
      return false;
    }
  }

  /// Main sync method - syncs today's data + historical backfill
  Future<HealthSyncResult> syncHealthData({
    bool forceSync = false,
  }) async {
    // Early guard checks (before acquiring lock for performance)
    if (isSyncing.value) {
      print('${HealthConfig.logPrefix} Sync already in progress, skipping');
      return HealthSyncResult.failure('Sync already in progress');
    }

    if (GuestUtils.isGuest()) {
      print('${HealthConfig.logPrefix} Skipping sync for guest user');
      return HealthSyncResult.notAvailable();
    }

    if (!forceSync && !await _shouldSync()) {
      print('${HealthConfig.logPrefix} Sync not needed yet');
      return HealthSyncResult.success(
        _lastSyncData ?? HealthSyncData.empty(),
        0,
      );
    }

    // Protect entire sync operation with lock
    return await _syncLock.synchronized(() async {
      // Double-check inside lock
      if (isSyncing.value) {
        print('${HealthConfig.logPrefix} Sync already in progress (double-check)');
        return HealthSyncResult.failure('Sync already in progress');
      }

      isSyncing.value = true;

    try {
      // Phase 1: Connecting
      _updateSyncStatus(HealthSyncStatus.connecting);
      print('${HealthConfig.logPrefix} Starting health data sync...');

      // Simple availability check (don't re-validate permissions - we just granted them!)
      final available = await _permissionsHelper.isHealthAvailable();
      if (!available) {
        print('${HealthConfig.logPrefix} ❌ Health services not available');
        _updateSyncStatus(HealthSyncStatus.notAvailable);

        // Add iOS Simulator check
        if (Platform.isIOS && !Platform.environment.containsKey('FLUTTER_TEST')) {
          print('${HealthConfig.logPrefix} ℹ️  If on iOS Simulator, HealthKit data is not available');
          print('${HealthConfig.logPrefix} ℹ️  Please test on a real iPhone device');
        }

        return HealthSyncResult.failure('Health services not available');
      }

      print('${HealthConfig.logPrefix} ✅ Health services available, proceeding with sync');

      // Phase 2: Syncing
      _updateSyncStatus(HealthSyncStatus.syncing);

      // Fetch today's data only (no historical backfill)
      final todayData = await _fetchTodayData();

      // Phase 3: Updating
      _updateSyncStatus(HealthSyncStatus.updating);

      // Build sync data payload (today only)
      final syncData = HealthSyncData(
        todaySteps: todayData.steps,
        todayDistance: todayData.distance,
        todayCalories: todayData.calories,
        todayActiveMinutes: todayData.activeMinutes,
        overallSteps: todayData.steps, // Overall stats come from Firebase aggregation
        overallDistance: todayData.distance,
        overallDays: 1,
        historicalData: [], // No historical data
        syncTimestamp: DateTime.now(),
        source: Platform.isIOS ? 'healthkit' : 'health_connect',
      );

      // Save today's data to database and Firebase
      await _saveTodayDataToDatabase(todayData);

      // Update last sync time
      await _preferencesService.setLastHealthSyncTimestamp(
        DateTime.now().millisecondsSinceEpoch,
      );

      // Cache sync data
      _lastSyncData = syncData;

      // ✅ FIX: Update StepTrackingService with health sync data
      // This ensures today's steps are updated BEFORE calculating overall stats
      // updateFromHealthSync() internally:
      // 1. Updates today's baseline
      // 2. Refreshes overall stats
      // 3. Propagates health sync delta to active races (avoiding duplicate calls!)
      if (Get.isRegistered<StepTrackingService>()) {
        try {
          final stepService = Get.find<StepTrackingService>();

          await stepService.updateFromHealthSync(
            todayStepsFromHealth: todayData.steps,
            todayDistanceFromHealth: todayData.distance,
            todayCaloriesFromHealth: todayData.calories,
            todayActiveTimeFromHealth: todayData.activeMinutes,
          );

          print('${HealthConfig.logPrefix} ✅ Updated StepTrackingService with health data and refreshed overall stats');
        } catch (e) {
          print('${HealthConfig.logPrefix} ⚠️ Could not update StepTrackingService: $e');
        }
      }

      // Phase 4: Completed
      _updateSyncStatus(HealthSyncStatus.completed);

      print('${HealthConfig.logPrefix} ✅ Sync completed successfully');
      print('${HealthConfig.logPrefix} Today: ${syncData.todaySteps} steps');

      return HealthSyncResult.success(syncData, 1); // Only 1 day synced (today)
      } catch (e, stackTrace) {
        print('${HealthConfig.logPrefix} ❌ Sync failed: $e');
        print('${HealthConfig.logPrefix} Stack trace: $stackTrace');
        _updateSyncStatus(HealthSyncStatus.failed);
        return HealthSyncResult.failure(e.toString());
      } finally {
        isSyncing.value = false;
      }
    });
  }

  /// Fetch today's health data
  Future<DailyHealthData> _fetchTodayData() async {
    final now = DateTime.now();
    // ✅ FIX: Query for the FULL calendar day, not just from midnight to now
    // Health Connect aggregates data by calendar day, so we need to query the entire day
    // Using end-of-day ensures we capture all steps recorded today
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    print('${HealthConfig.logPrefix} 📅 Querying health data for today (full day):');
    print('   Start: $startOfDay (${startOfDay.toIso8601String()})');
    print('   End: $endOfDay (${endOfDay.toIso8601String()})');
    print('   Duration: ${endOfDay.difference(startOfDay).inHours}h ${endOfDay.difference(startOfDay).inMinutes % 60}m');

    return await _fetchDataForPeriod(startOfDay, endOfDay);
  }


  /// Fetch health data for a specific time period
  Future<DailyHealthData> _fetchDataForPeriod(
    DateTime start,
    DateTime end,
  ) async {
    try {
      // ✅ FIX: Use aggregate query for steps to let HealthKit handle deduplication
      // This prevents counting duplicate step entries from multiple sources
      final steps = await _health.getTotalStepsInInterval(start, end) ?? 0;

      print('${HealthConfig.logPrefix} ✅ Fetched aggregated steps for period ${start.toString().substring(0, 10)}: $steps steps');

      // Build platform-specific health data types list
      final List<HealthDataType> otherDataTypes = [
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.HEART_RATE,
      ];

      // ✅ FIX: EXERCISE_TIME is only available on HealthKit (iOS), not Health Connect (Android)
      // Without this check, Health Connect throws an error that discards successfully fetched steps
      if (Platform.isIOS) {
        otherDataTypes.add(HealthDataType.EXERCISE_TIME);
      }

      // Add platform-specific distance type
      if (Platform.isIOS) {
        otherDataTypes.add(HealthDataType.DISTANCE_WALKING_RUNNING);
      } else if (Platform.isAndroid) {
        otherDataTypes.add(HealthDataType.DISTANCE_DELTA);
      }

      // Fetch other health data points (distance, calories, etc.)
      final List<HealthDataPoint> healthData = await _health
          .getHealthDataFromTypes(
            types: otherDataTypes,
            startTime: start,
            endTime: end,
          )
          .timeout(
            HealthConfig.syncTimeout,
            onTimeout: () => throw TimeoutException('Health data fetch timeout'),
          );

      print('${HealthConfig.logPrefix} Fetched ${healthData.length} additional data points for period ${start.toString().substring(0, 10)}');

      // Parse and aggregate other data (distance, calories, etc.)
      double distanceMeters = 0.0;
      double caloriesKcal = 0.0;
      int activeMinutes = 0;
      int? heartRate;

      for (final point in healthData) {
        switch (point.type) {
          case HealthDataType.DISTANCE_DELTA: // Android
          case HealthDataType.DISTANCE_WALKING_RUNNING: // iOS
            if (point.value is NumericHealthValue) {
              distanceMeters += (point.value as NumericHealthValue).numericValue;
            }
            break;

          case HealthDataType.ACTIVE_ENERGY_BURNED:
            if (point.value is NumericHealthValue) {
              caloriesKcal += (point.value as NumericHealthValue).numericValue;
            }
            break;

          case HealthDataType.EXERCISE_TIME:
            // iOS only - calculate active minutes from exercise time
            if (point.value is NumericHealthValue) {
              activeMinutes += (point.value as NumericHealthValue).numericValue.toInt();
            }
            break;

          case HealthDataType.HEART_RATE:
            if (point.value is NumericHealthValue) {
              heartRate = (point.value as NumericHealthValue).numericValue.toInt();
            }
            break;

          default:
            break;
        }
      }

      // Convert units
      final distanceKm = distanceMeters * HealthConfig.metersToKilometers;

      // ✅ Fallback: Estimate distance from steps if HealthKit has no distance data
      double finalDistance = distanceKm;
      if (distanceKm == 0.0 && steps > 0) {
        const stepsToKm = 0.000762; // 1 step ≈ 0.762 meters
        finalDistance = steps * stepsToKm;
        print('${HealthConfig.logPrefix} ⚠️ No distance data from HealthKit, estimated from steps: ${finalDistance.toStringAsFixed(2)}km');
      }

      // ✅ Fallback: Estimate calories from steps if HealthKit has no calorie data
      int finalCalories = caloriesKcal.round();
      if (caloriesKcal == 0.0 && steps > 0) {
        const stepsToCalories = 0.04; // 1 step ≈ 0.04 calories
        finalCalories = (steps * stepsToCalories).round();
        print('${HealthConfig.logPrefix} ⚠️ No calorie data from HealthKit, estimated from steps: $finalCalories cal');
      }

      // ✅ Fallback: Estimate active minutes from steps if not available from HealthKit
      // Android: Health Connect doesn't support EXERCISE_TIME
      // iOS: HealthKit may not have EXERCISE_TIME data if no workouts were logged
      // Average walking pace: 100 steps/minute
      if (activeMinutes == 0 && steps > 0) {
        activeMinutes = (steps / 100).round();
        final platform = Platform.isAndroid ? 'Android' : 'iOS';
        print('${HealthConfig.logPrefix} [$platform] Estimated active minutes from steps: $activeMinutes minutes');
      }

      final result = DailyHealthData(
        date: start,
        steps: steps,
        distance: finalDistance,
        calories: finalCalories,
        activeMinutes: activeMinutes,
        heartRateBpm: heartRate,
      );

      print('${HealthConfig.logPrefix} Parsed data: ${steps} steps, ${finalDistance.toStringAsFixed(2)} km, $finalCalories cal, ${activeMinutes} active min');

      return result;
    } catch (e) {
      print('${HealthConfig.logPrefix} Error fetching period data: $e');
      return DailyHealthData.empty(start);
    }
  }


  /// Save today's data to local database and Firebase
  /// Only saves today's date - history builds naturally day by day
  Future<void> _saveTodayDataToDatabase(DailyHealthData todayData) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Use the new StepDataRepository for proper Firebase sync
      final repository = StepDataRepository();

      // Format today's date as YYYY-MM-DD
      final dateString = todayData.date.toIso8601String().substring(0, 10);

      // Create DailyStepData object for today only
      final dailyStepData = DailyStepData(
        date: dateString,
        steps: todayData.steps,
        distance: todayData.distance,
        calories: todayData.calories,
        activeMinutes: todayData.activeMinutes,
        syncedAt: DateTime.now(),
        source: Platform.isIOS ? 'healthkit' : 'health_connect',
        isSynced: false,
        healthKitSteps: todayData.steps,
        pedometerSteps: null,
      );

      // Save today's data to repository (saves to both SQLite and Firebase)
      await repository.saveDailyData(dailyStepData, syncToFirebase: true);

      print('${HealthConfig.logPrefix} ✅ Saved today ($dateString) to database and Firebase');
    } catch (e) {
      print('${HealthConfig.logPrefix} Error saving today\'s data: $e');
    }
  }

  /// Check if sync is needed (based on last sync time)
  Future<bool> _shouldSync() async {
    try {
      final lastSyncTimestamp =
          await _preferencesService.getLastHealthSyncTimestamp();

      if (lastSyncTimestamp == null) {
        // Never synced before
        return true;
      }

      final lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncTimestamp);
      final now = DateTime.now();
      final timeSinceSync = now.difference(lastSyncTime);

      // Sync if more than minimum interval has passed
      return timeSinceSync >= HealthConfig.minimumSyncInterval;
    } catch (e) {
      print('${HealthConfig.logPrefix} Error checking if sync needed: $e');
      return true; // Default to syncing on error
    }
  }

  /// Update sync status and broadcast to listeners
  void _updateSyncStatus(HealthSyncStatus status) {
    syncStatus.value = status;
    _syncStatusController.add(status);
  }

  /// Get cached sync data (if available)
  HealthSyncData? getCachedSyncData() {
    return _lastSyncData;
  }

  /// Write steps to HealthKit/Health Connect
  /// This ensures pedometer incremental steps are persisted in the health system
  Future<bool> writeStepsToHealth(int steps, DateTime date) async {
    try {
      print('${HealthConfig.logPrefix} Writing $steps steps to ${HealthConfig.healthAppName} for ${date.toIso8601String().substring(0, 10)}...');

      // Check availability and permissions
      if (!isHealthAvailable.value) {
        print('${HealthConfig.logPrefix} Health not available, cannot write');
        return false;
      }

      if (!hasPermissions.value) {
        print('${HealthConfig.logPrefix} Health permissions not granted, cannot write');
        return false;
      }

      // Get start and end time for the date
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      // Write to health system
      final now = DateTime.now();
      final success = await _health.writeHealthData(
        value: steps.toDouble(),
        type: HealthDataType.STEPS,
        startTime: startOfDay,
        endTime: now.isBefore(endOfDay) ? now : endOfDay,
      );

      if (success) {
        print('${HealthConfig.logPrefix} ✅ Successfully wrote $steps steps to ${HealthConfig.healthAppName}');
      } else {
        print('${HealthConfig.logPrefix} ❌ Failed to write steps to ${HealthConfig.healthAppName}');
      }

      return success;
    } catch (e, stackTrace) {
      print('${HealthConfig.logPrefix} ❌ Error writing steps to health: $e');
      print('📍 Stack trace: $stackTrace');
      return false;
    }
  }

  /// Write today's incremental pedometer steps to HealthKit/Health Connect
  /// This is called periodically to sync pedometer data back to the health system
  Future<bool> writeTodayIncrementalSteps(int incrementalSteps) async {
    try {
      if (incrementalSteps <= 0) {
        print('${HealthConfig.logPrefix} No incremental steps to write (${incrementalSteps})');
        return true; // Not an error, just nothing to write
      }

      final today = DateTime.now();
      return await writeStepsToHealth(incrementalSteps, today);
    } catch (e) {
      print('${HealthConfig.logPrefix} ❌ Error writing incremental steps: $e');
      return false;
    }
  }

  /// Fetch today's steps from HealthKit/Health Connect
  /// Used by StepTrackingService for baseline initialization
  Future<Map<String, dynamic>?> fetchTodaySteps() async {
    try {
      print('${HealthConfig.logPrefix} Fetching today\'s health data from HealthKit/Health Connect...');

      // Check availability and permissions
      if (!isHealthAvailable.value) {
        print('${HealthConfig.logPrefix} Health not available');
        return null;
      }

      if (!hasPermissions.value) {
        print('${HealthConfig.logPrefix} Health permissions not granted');
        return null;
      }

      // Get today's start and end
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // ✅ FIX: Use aggregate query to let HealthKit handle deduplication
      // This prevents counting duplicate step entries from multiple sources
      final totalSteps = await _health.getTotalStepsInInterval(startOfDay, endOfDay) ?? 0;

      // ✅ NEW: Fetch actual distance, calories, and active time from HealthKit/Health Connect
      // Instead of calculating with generic formulas, get the real data
      final List<HealthDataType> otherDataTypes = [
        HealthDataType.ACTIVE_ENERGY_BURNED, // Calories from HealthKit/Health Connect
      ];

      // Add platform-specific data types
      if (Platform.isIOS) {
        otherDataTypes.add(HealthDataType.DISTANCE_WALKING_RUNNING); // iOS distance
        otherDataTypes.add(HealthDataType.EXERCISE_TIME); // iOS active time
      } else if (Platform.isAndroid) {
        otherDataTypes.add(HealthDataType.DISTANCE_DELTA); // Android distance
        // Note: Android Health Connect doesn't have EXERCISE_TIME, will estimate from steps
      }

      // Fetch actual health data from HealthKit/Health Connect
      final List<HealthDataPoint> healthData = await _health
          .getHealthDataFromTypes(
            types: otherDataTypes,
            startTime: startOfDay,
            endTime: endOfDay,
          )
          .timeout(
            HealthConfig.syncTimeout,
            onTimeout: () => throw TimeoutException('Health data fetch timeout'),
          );

      print('${HealthConfig.logPrefix} Fetched ${healthData.length} additional data points for today');

      // Parse and aggregate health data
      double distanceMeters = 0.0;
      double caloriesKcal = 0.0;
      int activeMinutes = 0;

      for (final point in healthData) {
        switch (point.type) {
          case HealthDataType.DISTANCE_DELTA: // Android
          case HealthDataType.DISTANCE_WALKING_RUNNING: // iOS
            if (point.value is NumericHealthValue) {
              distanceMeters += (point.value as NumericHealthValue).numericValue;
            }
            break;

          case HealthDataType.ACTIVE_ENERGY_BURNED:
            if (point.value is NumericHealthValue) {
              caloriesKcal += (point.value as NumericHealthValue).numericValue;
            }
            break;

          case HealthDataType.EXERCISE_TIME:
            // iOS only - get actual active minutes from HealthKit
            if (point.value is NumericHealthValue) {
              activeMinutes += (point.value as NumericHealthValue).numericValue.toInt();
            }
            break;

          default:
            break;
        }
      }

      // Convert distance from meters to kilometers
      final distanceKm = distanceMeters * HealthConfig.metersToKilometers;

      // ✅ Fallback to calculation if HealthKit data is missing (e.g., no GPS data for distance)
      double finalDistance = distanceKm;
      int finalCalories = caloriesKcal.round();
      int finalActiveMinutes = activeMinutes;

      if (distanceKm == 0.0 && totalSteps > 0) {
        // Fallback: Estimate distance from steps if HealthKit has no distance data
        const stepsToKm = 0.000762; // 1 step ≈ 0.762 meters
        finalDistance = totalSteps * stepsToKm;
        print('${HealthConfig.logPrefix} ⚠️ No distance data from HealthKit, estimated from steps: ${finalDistance.toStringAsFixed(2)}km');
      }

      if (caloriesKcal == 0.0 && totalSteps > 0) {
        // Fallback: Estimate calories from steps if HealthKit has no calorie data
        const stepsToCalories = 0.04; // 1 step ≈ 0.04 calories
        finalCalories = (totalSteps * stepsToCalories).round();
        print('${HealthConfig.logPrefix} ⚠️ No calorie data from HealthKit, estimated from steps: $finalCalories cal');
      }

      // ✅ Fallback: Estimate active minutes from steps if not available from HealthKit
      // Android: Health Connect doesn't support EXERCISE_TIME
      // iOS: HealthKit may not have EXERCISE_TIME data if no workouts were logged
      if (finalActiveMinutes == 0 && totalSteps > 0) {
        finalActiveMinutes = (totalSteps / 100).round(); // Average walking pace: 100 steps/minute
        final platform = Platform.isAndroid ? 'Android' : 'iOS';
        print('${HealthConfig.logPrefix} [$platform] Estimated active minutes from steps: $finalActiveMinutes minutes');
      }

      print('${HealthConfig.logPrefix} ✅ Today: $totalSteps steps, ${finalDistance.toStringAsFixed(2)}km, $finalCalories cal, $finalActiveMinutes min (from HealthKit)');

      return {
        'steps': totalSteps,
        'distance': finalDistance,
        'calories': finalCalories,
        'activeMinutes': finalActiveMinutes,
      };
    } catch (e, stackTrace) {
      print('${HealthConfig.logPrefix} ❌ Error fetching today\'s health data: $e');
      print('📍 Stack trace: $stackTrace');
      return null;
    }
  }

  /// Fetch health data for a custom date range
  /// Used for filter statistics (Last 7 days, Last 30 days, etc.)
  /// Returns aggregated steps, distance, calories, and active time for the period
  Future<Map<String, dynamic>?> getHealthDataForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      print('${HealthConfig.logPrefix} Fetching health data for range: ${startDate.toString().substring(0, 10)} to ${endDate.toString().substring(0, 10)}');

      // Check availability and permissions
      if (!isHealthAvailable.value) {
        print('${HealthConfig.logPrefix} Health not available');
        return null;
      }

      if (!hasPermissions.value) {
        print('${HealthConfig.logPrefix} Health permissions not granted');
        return null;
      }

      // Normalize dates to start of day and end of day
      final start = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
      final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      // ✅ Use aggregated query for steps (efficient and handles deduplication)
      final totalSteps = await _health.getTotalStepsInInterval(start, end) ?? 0;

      print('${HealthConfig.logPrefix} ✅ Fetched aggregated steps for range: $totalSteps steps');

      // Build platform-specific health data types list
      final List<HealthDataType> otherDataTypes = [
        HealthDataType.ACTIVE_ENERGY_BURNED,
      ];

      // Add platform-specific data types
      if (Platform.isIOS) {
        otherDataTypes.add(HealthDataType.DISTANCE_WALKING_RUNNING);
        otherDataTypes.add(HealthDataType.EXERCISE_TIME);
      } else if (Platform.isAndroid) {
        otherDataTypes.add(HealthDataType.DISTANCE_DELTA);
      }

      // Fetch other health data points
      final List<HealthDataPoint> healthData = await _health
          .getHealthDataFromTypes(
            types: otherDataTypes,
            startTime: start,
            endTime: end,
          )
          .timeout(
            HealthConfig.syncTimeout,
            onTimeout: () => throw TimeoutException('Health data fetch timeout'),
          );

      print('${HealthConfig.logPrefix} Fetched ${healthData.length} additional data points for range');

      // Parse and aggregate other data
      double distanceMeters = 0.0;
      double caloriesKcal = 0.0;
      int activeMinutes = 0;

      for (final point in healthData) {
        switch (point.type) {
          case HealthDataType.DISTANCE_DELTA: // Android
          case HealthDataType.DISTANCE_WALKING_RUNNING: // iOS
            if (point.value is NumericHealthValue) {
              distanceMeters += (point.value as NumericHealthValue).numericValue;
            }
            break;

          case HealthDataType.ACTIVE_ENERGY_BURNED:
            if (point.value is NumericHealthValue) {
              caloriesKcal += (point.value as NumericHealthValue).numericValue;
            }
            break;

          case HealthDataType.EXERCISE_TIME:
            // iOS only
            if (point.value is NumericHealthValue) {
              activeMinutes += (point.value as NumericHealthValue).numericValue.toInt();
            }
            break;

          default:
            break;
        }
      }

      // Convert units
      final distanceKm = distanceMeters * HealthConfig.metersToKilometers;

      // ✅ Fallback: Estimate if health data is missing
      double finalDistance = distanceKm;
      int finalCalories = caloriesKcal.round();
      int finalActiveMinutes = activeMinutes;

      if (distanceKm == 0.0 && totalSteps > 0) {
        const stepsToKm = 0.000762;
        finalDistance = totalSteps * stepsToKm;
        print('${HealthConfig.logPrefix} ⚠️ No distance data, estimated from steps: ${finalDistance.toStringAsFixed(2)}km');
      }

      if (caloriesKcal == 0.0 && totalSteps > 0) {
        const stepsToCalories = 0.04;
        finalCalories = (totalSteps * stepsToCalories).round();
        print('${HealthConfig.logPrefix} ⚠️ No calorie data, estimated from steps: $finalCalories cal');
      }

      if (finalActiveMinutes == 0 && totalSteps > 0) {
        finalActiveMinutes = (totalSteps / 100).round();
        final platform = Platform.isAndroid ? 'Android' : 'iOS';
        print('${HealthConfig.logPrefix} [$platform] Estimated active minutes from steps: $finalActiveMinutes minutes');
      }

      // Calculate number of days in range
      final days = end.difference(start).inDays + 1;

      print('${HealthConfig.logPrefix} ✅ Range data: $totalSteps steps, ${finalDistance.toStringAsFixed(2)}km, $finalCalories cal, $finalActiveMinutes min over $days days');

      return {
        'totalSteps': totalSteps,
        'totalDistance': finalDistance,
        'totalCalories': finalCalories,
        'totalActiveTime': finalActiveMinutes,
        'totalDays': days,
      };
    } catch (e, stackTrace) {
      print('${HealthConfig.logPrefix} ❌ Error fetching health data for date range: $e');
      print('📍 Stack trace: $stackTrace');
      return null;
    }
  }

  /// Get race progress from exact race start time to now (time-based baseline)
  ///
  /// This method queries HealthKit/Health Connect for steps, distance, and calories
  /// accumulated from the exact race start time to the current time.
  ///
  /// Used for time-based baseline tracking where we want to know EXACTLY how much
  /// the user has progressed since joining a race, regardless of day boundaries.
  ///
  /// Returns null if health services are unavailable or query fails.
  Future<Map<String, dynamic>?> getRaceProgressFromStart(DateTime raceStartTime) async {
    if (!isHealthAvailable.value) {
      print('${HealthConfig.logPrefix} ⚠️ Health services not available for race progress query');
      return null;
    }

    try {
      final now = DateTime.now();

      print('${HealthConfig.logPrefix} 📊 Querying race progress from ${raceStartTime.toIso8601String()} to ${now.toIso8601String()}');

      // Query steps for the exact time range
      final steps = await _health.getTotalStepsInInterval(raceStartTime, now) ?? 0;

      // Query distance and calories for the same time range
      final otherDataTypes = <HealthDataType>[
        Platform.isIOS
            ? HealthDataType.DISTANCE_WALKING_RUNNING
            : HealthDataType.DISTANCE_DELTA,
        HealthDataType.ACTIVE_ENERGY_BURNED,
      ];

      final List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        types: otherDataTypes,
        startTime: raceStartTime,
        endTime: now,
      ).timeout(HealthConfig.syncTimeout);

      // Extract distance
      double distanceKm = 0.0;
      for (var point in healthData) {
        if (point.type == HealthDataType.DISTANCE_WALKING_RUNNING ||
            point.type == HealthDataType.DISTANCE_DELTA) {
          final distanceMeters = (point.value as num).toDouble();
          distanceKm += distanceMeters / 1000.0;
        }
      }

      // Extract calories
      int caloriesKcal = 0;
      for (var point in healthData) {
        if (point.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
          caloriesKcal += (point.value as num).toInt();
        }
      }

      // Fallback: If no distance data, calculate from steps
      double finalDistance = distanceKm;
      if (finalDistance == 0.0 && steps > 0) {
        const stepsToKm = 0.000762; // Average: ~1312 steps per km
        finalDistance = steps * stepsToKm;
        print('${HealthConfig.logPrefix} ℹ️ No distance data, calculated from steps: ${finalDistance.toStringAsFixed(2)} km');
      }

      // Fallback: If no calorie data, estimate from steps
      int finalCalories = caloriesKcal;
      if (finalCalories == 0 && steps > 0) {
        const stepsToCalories = 0.04; // Average: ~0.04 calories per step
        finalCalories = (steps * stepsToCalories).round();
        print('${HealthConfig.logPrefix} ℹ️ No calorie data, estimated from steps: $finalCalories kcal');
      }

      print('${HealthConfig.logPrefix} ✅ Race progress: $steps steps, ${finalDistance.toStringAsFixed(2)} km, $finalCalories kcal');

      return {
        'steps': steps,
        'distance': finalDistance,
        'calories': finalCalories,
      };
    } catch (e, stackTrace) {
      print('${HealthConfig.logPrefix} ❌ Error querying race progress: $e');
      print('📍 Stack trace: $stackTrace');
      return null;
    }
  }

  @override
  void onClose() {
    _syncStatusController.close();
    super.onClose();
  }
}
