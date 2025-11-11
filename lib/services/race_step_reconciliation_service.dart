import 'dart:developer' as dev;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

/// Race Step Reconciliation Service
///
/// NEW ARCHITECTURE: Uses Cloud Functions for server-side baseline management.
///
/// This service replaces the complex client-side baseline tracking with a simple
/// Cloud Function call that sends total health data (not deltas) to the server.
///
/// Benefits:
/// - Single source of truth on server
/// - No app restart bugs
/// - No day rollover bugs
/// - No double-counting bugs
/// - Simplified client code
/// - Better security
///
/// Usage:
/// ```dart
/// final service = Get.find<RaceStepReconciliationService>();
/// await service.syncHealthDataToRaces(
///   totalSteps: 12000,
///   totalDistance: 9.2,
///   totalCalories: 450,
/// );
/// ```
class RaceStepReconciliationService extends GetxService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State tracking
  final RxBool isSyncing = false.obs;
  final RxInt lastSyncRaceCount = 0.obs;
  final RxString lastSyncTime = ''.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  // Rate limiting
  DateTime? _lastSyncTimestamp;
  static const Duration MIN_SYNC_INTERVAL = Duration(seconds: 5);

  @override
  Future<void> onInit() async {
    super.onInit();
  }

  /// Sync health data to all active races using Cloud Functions.
  ///
  /// This is the ONLY method needed to propagate health data to races.
  /// No baseline tracking, no delta calculation - server handles everything.
  ///
  /// Parameters:
  /// - [totalSteps]: Total steps from HealthKit/Health Connect today
  /// - [totalDistance]: Total distance (km) from HealthKit/Health Connect today
  /// - [totalCalories]: Total calories from HealthKit/Health Connect today
  /// - [forceSync]: If true, bypasses rate limiting (default: false)
  Future<bool> syncHealthDataToRaces({
    required int totalSteps,
    required double totalDistance,
    required int totalCalories,
    bool forceSync = false,
  }) async {
    // 1. Authentication check
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return false;
    }

    // 2. Rate limiting (prevent rapid syncs)
    if (!forceSync && _lastSyncTimestamp != null) {
      final timeSinceLastSync = DateTime.now().difference(_lastSyncTimestamp!);
      if (timeSinceLastSync < MIN_SYNC_INTERVAL) {
        return false;
      }
    }

    // 3. Prevent concurrent syncs
    if (isSyncing.value) {
      return false;
    }

    isSyncing.value = true;
    hasError.value = false;
    errorMessage.value = '';

    try {



      // Calculate expected distance from steps as fallback
      const double STEPS_TO_KM_FACTOR = 0.000762;
      final calculatedDistance = totalSteps * STEPS_TO_KM_FACTOR;

      // 4. Prepare payload
      final now = DateTime.now();
      final dateString = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final payload = {
        'userId': currentUser.uid,
        'totalSteps': totalSteps,
        'totalDistance': totalDistance,
        'totalCalories': totalCalories,
        'timestamp': now.millisecondsSinceEpoch,
        'date': dateString,
      };

      dev.log('📦 [PAYLOAD] Prepared payload for Cloud Function:');
      dev.log('   userId: ${currentUser.uid}');
      dev.log('   totalSteps: $totalSteps');
      dev.log('   totalDistance: $totalDistance');
      dev.log('   totalCalories: $totalCalories');
      dev.log('   date: $dateString');

      // 5. Call Cloud Function
      final callable = _functions.httpsCallable('syncHealthDataToRaces');
      final result = await callable.call(payload);

      // 6. Process result
      final data = result.data as Map<String, dynamic>;
      final success = data['success'] as bool? ?? false;
      final racesUpdated = data['racesUpdated'] as int? ?? 0;
      final message = data['message'] as String? ?? 'Unknown response';

      if (success) {


        lastSyncRaceCount.value = racesUpdated;
        lastSyncTime.value = DateTime.now().toIso8601String();
        _lastSyncTimestamp = DateTime.now();

        return true;
      } else {
        hasError.value = true;
        errorMessage.value = message;
        return false;
      }
    } catch (e, stackTrace) {

      hasError.value = true;
      errorMessage.value = e.toString();

      return false;
    } finally {
      isSyncing.value = false;
    }
  }

  /// Initialize time-based baseline for a newly joined race
  ///
  /// This method creates a baseline document on the server with the user's current
  /// health data at the time of joining. This baseline will be used to calculate
  /// race-specific progress using time-based queries.
  ///
  /// Parameters:
  /// - [raceId]: The ID of the race being joined
  /// - [raceTitle]: The title of the race
  /// - [raceStartTime]: The exact time when the race started (or will start)
  /// - [healthKitStepsAtStart]: User's total steps when joining
  /// - [healthKitDistanceAtStart]: User's total distance (km) when joining
  /// - [healthKitCaloriesAtStart]: User's total calories when joining
  Future<bool> initializeRaceBaseline({
    required String raceId,
    required String raceTitle,
    required DateTime raceStartTime,
    required int healthKitStepsAtStart,
    required double healthKitDistanceAtStart,
    required int healthKitCaloriesAtStart,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return false;
    }

    try {

      // Call Cloud Function to initialize baseline
      final callable = _functions.httpsCallable('initializeRaceBaseline');
      final result = await callable.call({
        'userId': currentUser.uid,
        'raceId': raceId,
        'raceTitle': raceTitle,
        'raceStartTime': raceStartTime.toIso8601String(),
        'healthKitStepsAtStart': healthKitStepsAtStart,
        'healthKitDistanceAtStart': healthKitDistanceAtStart,
        'healthKitCaloriesAtStart': healthKitCaloriesAtStart,
        'timestamp': DateTime.now().toIso8601String(),
      });

      final data = result.data as Map<String, dynamic>;
      final success = data['success'] as bool? ?? false;
      final message = data['message'] as String? ?? 'Unknown error';

      if (success) {
        return true;
      } else {
        return false;
      }
    } catch (e, stackTrace) {

      return false;
    }
  }

  /// Get debug information about sync state
  Map<String, dynamic> getDebugInfo() {
    return {
      'isSyncing': isSyncing.value,
      'lastSyncRaceCount': lastSyncRaceCount.value,
      'lastSyncTime': lastSyncTime.value,
      'hasError': hasError.value,
      'errorMessage': errorMessage.value,
      'lastSyncTimestamp': _lastSyncTimestamp?.toIso8601String(),
    };
  }
}
