import 'dart:developer' as dev;
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';
import 'race_step_sync_service.dart';

/// Centralized coordinator for propagating health data (steps) to races.
///
/// This service is the SINGLE ENTRY POINT for all health-to-race step propagation,
/// preventing duplicate counting through:
/// - Request ID deduplication
/// - Timestamp-based rate limiting
/// - Last processed value tracking
///
/// Usage:
/// ```dart
/// final coordinator = Get.find<HealthSyncCoordinator>();
/// await coordinator.propagateHealthStepsToRaces(
///   steps: 6200,
///   source: 'HealthKitBaseline',
/// );
/// ```
class HealthSyncCoordinator extends GetxService {
  // Processed request IDs to prevent duplicate propagation
  final Set<String> _processedRequestIds = {};

  // Last processed values
  DateTime? _lastProcessedTimestamp;
  int _lastProcessedSteps = 0;
  double _lastProcessedDistance = 0.0;  // ✅ NEW: Track last distance
  int _lastProcessedCalories = 0;       // ✅ NEW: Track last calories
  String? _lastProcessedDate; // Track which date the steps belong to (format: yyyy-MM-dd)

  // SharedPreferences for persistence
  SharedPreferences? _prefs;

  // Thread safety - prevent concurrent state modifications
  final Lock _stateLock = Lock();

  // Storage keys
  static const String _lastStepsKey = 'health_sync_coordinator_last_steps';
  static const String _lastDistanceKey = 'health_sync_coordinator_last_distance';  // ✅ NEW
  static const String _lastCaloriesKey = 'health_sync_coordinator_last_calories';  // ✅ NEW
  static const String _lastTimestampKey = 'health_sync_coordinator_last_timestamp';
  static const String _lastDateKey = 'health_sync_coordinator_last_date';

  @override
  Future<void> onInit() async {
    super.onInit();
    await _loadState();
    dev.log('✅ [HEALTH_COORDINATOR] Initialized');
  }

  /// Load persisted state from SharedPreferences
  Future<void> _loadState() async {
    _prefs = await SharedPreferences.getInstance();

    _lastProcessedSteps = _prefs?.getInt(_lastStepsKey) ?? 0;
    _lastProcessedDistance = _prefs?.getDouble(_lastDistanceKey) ?? 0.0;  // ✅ NEW
    _lastProcessedCalories = _prefs?.getInt(_lastCaloriesKey) ?? 0;  // ✅ NEW
    _lastProcessedDate = _prefs?.getString(_lastDateKey);

    final timestampStr = _prefs?.getString(_lastTimestampKey);
    if (timestampStr != null) {
      _lastProcessedTimestamp = DateTime.tryParse(timestampStr);
    }

    dev.log('📂 [HEALTH_COORDINATOR] Loaded state:');
    dev.log('   Steps: $_lastProcessedSteps, Distance: ${_lastProcessedDistance.toStringAsFixed(2)} km, Calories: $_lastProcessedCalories');
    dev.log('   Date: $_lastProcessedDate, Timestamp: $_lastProcessedTimestamp');

    // ✅ CRITICAL FIX: Check if it's a new day - reset tracking if date changed
    final today = _getTodayDateString();
    if (_lastProcessedDate != null && _lastProcessedDate != today) {
      dev.log('🌅 [HEALTH_COORDINATOR] New day detected! Previous: $_lastProcessedDate, Today: $today');
      dev.log('   Resetting tracking for new day (was: $_lastProcessedSteps steps, ${_lastProcessedDistance.toStringAsFixed(2)} km, $_lastProcessedCalories cal)');
      _lastProcessedSteps = 0;
      _lastProcessedDistance = 0.0;  // ✅ NEW: Reset distance
      _lastProcessedCalories = 0;    // ✅ NEW: Reset calories
      _lastProcessedDate = today;
      await _saveState();
      dev.log('✅ [HEALTH_COORDINATOR] Tracking reset for new day');
    }
  }

  /// Get today's date as string (yyyy-MM-dd format)
  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Save state to SharedPreferences (thread-safe)
  Future<void> _saveState() async {
    await _stateLock.synchronized(() async {
      await _prefs?.setInt(_lastStepsKey, _lastProcessedSteps);
      await _prefs?.setDouble(_lastDistanceKey, _lastProcessedDistance);  // ✅ NEW
      await _prefs?.setInt(_lastCaloriesKey, _lastProcessedCalories);     // ✅ NEW

      if (_lastProcessedDate != null) {
        await _prefs?.setString(_lastDateKey, _lastProcessedDate!);
      }

      if (_lastProcessedTimestamp != null) {
        await _prefs?.setString(_lastTimestampKey, _lastProcessedTimestamp!.toIso8601String());
      }
    });
  }

  /// Propagate health steps to all active races.
  ///
  /// This is the ONLY method that should call RaceStepSyncService.addHealthSyncStepsIdempotent().
  /// All other services (StepTrackingService, HealthSyncService) should call THIS method.
  ///
  /// Parameters:
  /// - [steps]: Total steps from health source (HealthKit/Health Connect)
  /// - [distance]: Total distance from health source (km)  // ✅ NEW
  /// - [calories]: Total calories from health source       // ✅ NEW
  /// - [source]: Source identifier (e.g., "HealthKitBaseline", "ManualHealthSync")
  /// - [forcePropagate]: If true, bypasses rate limiting (use sparingly)
  Future<void> propagateHealthStepsToRaces({
    required int steps,
    required double distance,   // ✅ NEW
    required int calories,      // ✅ NEW
    required String source,
    bool forcePropagate = false,
  }) async {
    final now = DateTime.now();

    // Generate request ID (unique per source + timestamp)
    final requestId = '${now.millisecondsSinceEpoch}_$source';

    // 1. Check if already processed (deduplication)
    if (_processedRequestIds.contains(requestId)) {
      dev.log('⏭️ [HEALTH_COORDINATOR] Skipping duplicate request: $requestId');
      return;
    }

    // 2. Calculate deltas
    final stepsDelta = steps - _lastProcessedSteps;
    final distanceDelta = distance - _lastProcessedDistance;  // ✅ NEW
    final caloriesDelta = calories - _lastProcessedCalories;  // ✅ NEW

    if (stepsDelta <= 0 && !forcePropagate) {
      dev.log('⏭️ [HEALTH_COORDINATOR] No new steps to propagate (delta: $stepsDelta)');
      return;
    }

    // 3. Validate step delta is reasonable
    if (stepsDelta > 20000 && !forcePropagate) {
      dev.log('❌ [HEALTH_COORDINATOR] ANOMALY: Step delta too large: $stepsDelta steps (source: $source)');
      dev.log('   Previous: $_lastProcessedSteps, Current: $steps');
      dev.log('   This propagation will be CAPPED at 20,000 steps to prevent abuse.');
      // Cap at 20,000 to prevent extreme anomalies
      final cappedDelta = 20000;
      // Also cap distance/calories proportionally
      final cappedDistanceDelta = distanceDelta * (cappedDelta / stepsDelta);
      final cappedCaloriesDelta = (caloriesDelta * (cappedDelta / stepsDelta)).round();
      await _propagateToRaces(cappedDelta, cappedDistanceDelta, cappedCaloriesDelta, requestId, source);
      _lastProcessedSteps = _lastProcessedSteps + cappedDelta;
      _lastProcessedDistance = _lastProcessedDistance + cappedDistanceDelta;
      _lastProcessedCalories = _lastProcessedCalories + cappedCaloriesDelta;
      await _saveState();
      return;
    }

    // 4. Rate limiting check (prevent rapid syncs < 5 seconds apart)
    if (_lastProcessedTimestamp != null && !forcePropagate) {
      final timeSinceLastSync = now.difference(_lastProcessedTimestamp!);
      if (timeSinceLastSync.inSeconds < 5 && stepsDelta < 50) {
        dev.log('⏭️ [HEALTH_COORDINATOR] Skipping rapid sync (<5s since last, delta: $stepsDelta)');
        return;
      }
    }

    // 5. Propagate to races
    dev.log('🏥 [HEALTH_COORDINATOR] Propagating to races:');
    dev.log('   Source: $source');
    dev.log('   Request ID: $requestId');
    dev.log('   Previous: $_lastProcessedSteps steps, ${_lastProcessedDistance.toStringAsFixed(2)} km, $_lastProcessedCalories cal');
    dev.log('   Current: $steps steps, ${distance.toStringAsFixed(2)} km, $calories cal');
    dev.log('   Delta: $stepsDelta steps, ${distanceDelta.toStringAsFixed(2)} km, $caloriesDelta cal');

    await _propagateToRaces(stepsDelta, distanceDelta, caloriesDelta, requestId, source);

    // 6. Update tracking
    _lastProcessedSteps = steps;
    _lastProcessedDistance = distance;        // ✅ NEW: Track distance
    _lastProcessedCalories = calories;        // ✅ NEW: Track calories
    _lastProcessedTimestamp = now;
    _lastProcessedDate = _getTodayDateString(); // ✅ Track which date these steps belong to
    _processedRequestIds.add(requestId);

    // Clean up old request IDs (keep last 100)
    if (_processedRequestIds.length > 100) {
      _processedRequestIds.clear();
    }

    // 7. Persist state
    await _saveState();

    dev.log('✅ [HEALTH_COORDINATOR] Propagation complete (date: $_lastProcessedDate)');
  }

  /// ❌ DISABLED: Old client-side race step propagation - now using Cloud Functions
  /// The Cloud Function (syncHealthDataToRaces) handles ALL step distribution server-side
  /// This method is kept for reference but no longer used
  Future<void> _propagateToRaces(int stepsDelta, double distanceDelta, int caloriesDelta, String requestId, String source) async {
    // ❌ DISABLED: Client-side step propagation replaced by Cloud Functions
    // See: lib/services/race_step_reconciliation_service.dart for new implementation
    dev.log('ℹ️ [HEALTH_COORDINATOR] Client-side race propagation disabled - using Cloud Functions');
    return;

    // try {
    //   if (!Get.isRegistered<RaceStepSyncService>()) {
    //     dev.log('⚠️ [HEALTH_COORDINATOR] RaceStepSyncService not registered, skipping propagation');
    //     return;
    //   }
    //
    //   final raceService = Get.find<RaceStepSyncService>();
    //   await raceService.addHealthSyncStepsIdempotent(
    //     stepsDelta: stepsDelta,
    //     distanceDelta: distanceDelta,
    //     caloriesDelta: caloriesDelta,
    //     requestId: requestId,
    //     source: source,
    //   );
    // } catch (e, stackTrace) {
    //   dev.log('❌ [HEALTH_COORDINATOR] Error propagating to races: $e');
    //   dev.log('   Stack trace: $stackTrace');
    // }
  }

  /// Reset coordinator state (use for testing or manual override)
  Future<void> resetState() async {
    _lastProcessedSteps = 0;
    _lastProcessedDistance = 0.0;    // ✅ NEW: Reset distance
    _lastProcessedCalories = 0;      // ✅ NEW: Reset calories
    _lastProcessedTimestamp = null;
    _lastProcessedDate = null;
    _processedRequestIds.clear();
    await _saveState();
    dev.log('🔄 [HEALTH_COORDINATOR] State reset');
  }

  /// Get current state for debugging
  Map<String, dynamic> getDebugInfo() {
    return {
      'lastProcessedSteps': _lastProcessedSteps,
      'lastProcessedDistance': _lastProcessedDistance,    // ✅ NEW
      'lastProcessedCalories': _lastProcessedCalories,    // ✅ NEW
      'lastProcessedDate': _lastProcessedDate,
      'lastProcessedTimestamp': _lastProcessedTimestamp?.toIso8601String(),
      'processedRequestIdsCount': _processedRequestIds.length,
      'todayDate': _getTodayDateString(),
    };
  }
}
