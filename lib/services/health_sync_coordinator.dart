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

  // SharedPreferences for persistence
  SharedPreferences? _prefs;

  // Thread safety - prevent concurrent state modifications
  final Lock _stateLock = Lock();

  // Storage keys
  static const String _lastStepsKey = 'health_sync_coordinator_last_steps';
  static const String _lastTimestampKey = 'health_sync_coordinator_last_timestamp';

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

    final timestampStr = _prefs?.getString(_lastTimestampKey);
    if (timestampStr != null) {
      _lastProcessedTimestamp = DateTime.tryParse(timestampStr);
    }

    dev.log('📂 [HEALTH_COORDINATOR] Loaded state: lastSteps=$_lastProcessedSteps, lastTimestamp=$_lastProcessedTimestamp');
  }

  /// Save state to SharedPreferences (thread-safe)
  Future<void> _saveState() async {
    await _stateLock.synchronized(() async {
      await _prefs?.setInt(_lastStepsKey, _lastProcessedSteps);

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
  /// - [source]: Source identifier (e.g., "HealthKitBaseline", "ManualHealthSync")
  /// - [forcePropagate]: If true, bypasses rate limiting (use sparingly)
  Future<void> propagateHealthStepsToRaces({
    required int steps,
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

    // 2. Calculate step delta
    final stepsDelta = steps - _lastProcessedSteps;

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
      await _propagateToRaces(cappedDelta, requestId, source);
      _lastProcessedSteps = _lastProcessedSteps + cappedDelta;
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
    dev.log('🏥 [HEALTH_COORDINATOR] Propagating steps to races:');
    dev.log('   Source: $source');
    dev.log('   Request ID: $requestId');
    dev.log('   Previous steps: $_lastProcessedSteps');
    dev.log('   Current steps: $steps');
    dev.log('   Delta: $stepsDelta steps');

    await _propagateToRaces(stepsDelta, requestId, source);

    // 6. Update tracking
    _lastProcessedSteps = steps;
    _lastProcessedTimestamp = now;
    _processedRequestIds.add(requestId);

    // Clean up old request IDs (keep last 100)
    if (_processedRequestIds.length > 100) {
      _processedRequestIds.clear();
    }

    // 7. Persist state
    await _saveState();

    dev.log('✅ [HEALTH_COORDINATOR] Propagation complete');
  }

  /// Internal method to propagate steps to RaceStepSyncService
  Future<void> _propagateToRaces(int stepsDelta, String requestId, String source) async {
    try {
      if (!Get.isRegistered<RaceStepSyncService>()) {
        dev.log('⚠️ [HEALTH_COORDINATOR] RaceStepSyncService not registered, skipping propagation');
        return;
      }

      final raceService = Get.find<RaceStepSyncService>();
      await raceService.addHealthSyncStepsIdempotent(
        stepsDelta: stepsDelta,
        requestId: requestId,
        source: source,
      );
    } catch (e, stackTrace) {
      dev.log('❌ [HEALTH_COORDINATOR] Error propagating to races: $e');
      dev.log('   Stack trace: $stackTrace');
    }
  }

  /// Reset coordinator state (use for testing or manual override)
  Future<void> resetState() async {
    _lastProcessedSteps = 0;
    _lastProcessedTimestamp = null;
    _processedRequestIds.clear();
    await _saveState();
    dev.log('🔄 [HEALTH_COORDINATOR] State reset');
  }

  /// Get current state for debugging
  Map<String, dynamic> getDebugInfo() {
    return {
      'lastProcessedSteps': _lastProcessedSteps,
      'lastProcessedTimestamp': _lastProcessedTimestamp?.toIso8601String(),
      'processedRequestIdsCount': _processedRequestIds.length,
    };
  }
}
