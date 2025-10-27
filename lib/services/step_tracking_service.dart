import 'dart:async';
import 'dart:math' as math;
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:synchronized/synchronized.dart';
import '../models/daily_step_data.dart';
import '../models/step_summary.dart';
import '../repositories/step_data_repository.dart';
import '../utils/step_date_utils.dart';
import 'pedometer_service.dart';
import 'health_sync_service.dart';
import 'race_step_sync_service.dart';

/// Main Step Tracking Service - Orchestrates all step tracking functionality
///
/// Architecture:
/// 1. On cold start: Fetch HealthKit/Health Connect baseline for today
/// 2. Start pedometer for real-time incremental tracking
/// 3. Combine: todaySteps = healthKitBaseline + pedometerIncrements
/// 4. Sync to Firebase every 30 seconds
/// 5. Handle midnight rollover automatically
///
/// Data Flow:
/// HealthKit/Health Connect → Baseline Steps (fetched on app start)
/// Pedometer → Incremental Steps (real-time)
/// Combined → Display to UI
/// Firebase ← Periodic sync (every 30 sec)
/// SQLite ← Local cache (offline support)
class StepTrackingService extends GetxService {
  // ================== DEPENDENCIES ==================
  final StepDataRepository _repository = StepDataRepository();
  late final PedometerService _pedometerService;
  late final HealthSyncService _healthSyncService;

  // ================== TODAY'S DATA (REAL-TIME) ==================
  final RxInt todaySteps = 0.obs;
  final RxDouble todayDistance = 0.0.obs;
  final RxInt todayCalories = 0.obs;
  final RxInt todayActiveTime = 0.obs;
  final RxString pedestrianStatus = 'unknown'.obs;

  // ================== OVERALL STATISTICS ==================
  final RxInt overallSteps = 0.obs;
  final RxDouble overallDistance = 0.0.obs;
  final RxInt overallDays = 0.obs;

  // ================== STATE MANAGEMENT ==================
  final RxBool isInitialized = false.obs;
  final RxBool isSyncing = false.obs;
  final Rx<DateTime?> lastSyncTime = Rx<DateTime?>(null);
  final RxString currentDate = ''.obs;

  // ================== MANUAL SYNC STATE ==================
  final Rx<DateTime?> lastManualSyncTime = Rx<DateTime?>(null);
  final RxBool isManualSyncing = false.obs;
  final RxDouble syncProgress = 0.0.obs;
  final RxString syncStatusMessage = ''.obs;
  final RxBool syncSuccess = false.obs;
  final RxBool syncError = false.obs;

  // ================== PRIVATE STATE ==================
  int _healthKitBaselineSteps = 0;
  double _healthKitBaselineDistance = 0.0;
  int _healthKitBaselineCalories = 0;
  int _healthKitBaselineActiveTime = 0;

  Timer? _periodicSyncTimer;
  Timer? _midnightCheckTimer;
  bool _isInitializing = false;

  // ================== CONCURRENCY CONTROL ==================
  /// Lock for state updates to prevent race conditions
  final Lock _stateUpdateLock = Lock();

  /// Lock for midnight rollover to prevent concurrent execution
  final Lock _midnightRolloverLock = Lock();

  /// Lock for sync operations
  final Lock _syncLock = Lock();

  // ================== CONSTANTS ==================
  static const Duration _syncInterval = Duration(seconds: 30);
  static const Duration _midnightCheckInterval = Duration(minutes: 1);
  static const double _stepsToKmFactor = 0.000762; // Average: 1 step ≈ 0.762 meters
  static const double _stepsToCaloriesFactor = 0.04; // Average: 1 step ≈ 0.04 calories

  @override
  Future<void> onInit() async {
    super.onInit();
    print('🚀 StepTrackingService: onInit called');
    await initialize();
  }

  /// Initialize the step tracking service
  Future<bool> initialize() async {
    if (_isInitializing || isInitialized.value) {
      print('⏭️ StepTrackingService: Already initialized or initializing');
      return isInitialized.value;
    }

    _isInitializing = true;
    print('📊 StepTrackingService: Starting initialization...');

    try {
      // Step 1: Initialize current date
      currentDate.value = DailyStepData.getTodayDate();
      print('📅 Current date: ${currentDate.value}');

      // Step 2: Get or initialize services
      _pedometerService = Get.isRegistered<PedometerService>()
          ? Get.find<PedometerService>()
          : Get.put(PedometerService(), permanent: true);

      _healthSyncService = Get.isRegistered<HealthSyncService>()
          ? Get.find<HealthSyncService>()
          : Get.put(HealthSyncService(), permanent: true);

      print('✅ Services obtained');

      // Step 3: Load overall statistics first (for display)
      await _loadOverallStatistics();

      // Step 4: Fetch today's HealthKit baseline (CRITICAL)
      await _fetchHealthKitBaseline();

      // Step 5: Initialize pedometer for real-time tracking
      await _initializePedometer();

      // Step 6: Set up periodic sync and midnight check
      _setupPeriodicSync();
      _setupMidnightCheck();

      // Step 7: Set up real-time listeners
      _setupPedometerListeners();

      isInitialized.value = true;
      print('✅ StepTrackingService: Initialization complete');
      print('📊 Today: ${todaySteps.value} steps, Overall: ${overallSteps.value} steps, ${overallDays.value} days');

      return true;
    } catch (e, stackTrace) {
      print('❌ StepTrackingService: Initialization error: $e');
      print('📍 Stack trace: $stackTrace');
      isInitialized.value = false;
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Fetch HealthKit/Health Connect baseline for today
  /// INCLUDES CONFLICT RESOLUTION: HealthKit is always source of truth
  Future<void> _fetchHealthKitBaseline() async {
    try {
      print('🏥 Fetching HealthKit baseline for today...');

      // Check if Health Connect/HealthKit is available
      if (!_healthSyncService.isHealthAvailable.value) {
        print('⚠️ Health services not available, using local data');
        await _loadTodayDataFromLocal();
        return;
      }

      // Request permissions if needed
      if (!_healthSyncService.hasPermissions.value) {
        print('🔐 Requesting health permissions...');
        final granted = await _healthSyncService.requestPermissions();
        if (!granted) {
          print('⚠️ Health permissions denied, using local data');
          await _loadTodayDataFromLocal();
          return;
        }
      }

      // Fetch today's data from HealthKit/Health Connect
      final healthData = await _healthSyncService.fetchTodaySteps();

      if (healthData != null) {
        _healthKitBaselineSteps = healthData['steps'] as int? ?? 0;
        _healthKitBaselineDistance = (healthData['distance'] as num?)?.toDouble() ?? 0.0;
        _healthKitBaselineCalories = healthData['calories'] as int? ?? 0;
        _healthKitBaselineActiveTime = healthData['activeMinutes'] as int? ?? 0;

        print('✅ HealthKit baseline: $_healthKitBaselineSteps steps, ${_healthKitBaselineDistance}km');

        // CONFLICT RESOLUTION: Check if Firebase has different value
        final todayDate = currentDate.value;
        final firebaseData = await _repository.getDailyDataFromFirebaseDirectly(todayDate);

        if (firebaseData != null) {
          final firebaseSteps = firebaseData.steps;
          final healthKitSteps = _healthKitBaselineSteps;

          if (firebaseSteps != healthKitSteps) {
            print('⚠️ CONFLICT DETECTED:');
            print('   Firebase: $firebaseSteps steps');
            print('   HealthKit: $healthKitSteps steps');
            print('   → Using HealthKit as source of truth');
            print('   → Overwriting Firebase with HealthKit value');

            // Immediately overwrite Firebase with HealthKit value
            final correctedData = DailyStepData(
              date: todayDate,
              steps: healthKitSteps,
              distance: _healthKitBaselineDistance,
              calories: _healthKitBaselineCalories,
              activeMinutes: _healthKitBaselineActiveTime,
              syncedAt: DateTime.now(),
              source: 'healthkit',
              isSynced: false,
              pedometerSteps: 0,
              healthKitSteps: healthKitSteps,
            );

            await _repository.saveDailyData(correctedData, syncToFirebase: true);
            print('✅ Firebase corrected with HealthKit value');
          } else {
            print('✅ Firebase and HealthKit in sync ($healthKitSteps steps)');
          }
        } else {
          print('📝 No Firebase data for today yet - will sync after pedometer updates');
        }

        // Update today's display with baseline (before pedometer starts)
        await _stateUpdateLock.synchronized(() async {
          _updateTodayDisplayInternal();
          print('✅ Today\'s baseline updated from HealthKit: ${todaySteps.value} steps');
        });
      } else {
        print('⚠️ No HealthKit data available for today, using local fallback');
        await _loadTodayDataFromLocal();
      }
    } catch (e) {
      print('❌ Error fetching HealthKit baseline: $e');
      await _loadTodayDataFromLocal();
    }
  }

  /// Load today's data from local storage (fallback)
  Future<void> _loadTodayDataFromLocal() async {
    try {
      final today = DailyStepData.getTodayDate();
      final localData = await _repository.getDailyData(today);

      if (localData != null) {
        _healthKitBaselineSteps = localData.steps;
        _healthKitBaselineDistance = localData.distance;
        _healthKitBaselineCalories = localData.calories;
        _healthKitBaselineActiveTime = localData.activeMinutes;

        print('📦 Loaded from local: $_healthKitBaselineSteps steps');
        await _updateTodayDisplay();
      } else {
        print('📦 No local data found for today, starting fresh');
        _healthKitBaselineSteps = 0;
        _healthKitBaselineDistance = 0.0;
        _healthKitBaselineCalories = 0;
        _healthKitBaselineActiveTime = 0;
      }
    } catch (e) {
      print('❌ Error loading local data: $e');
    }
  }

  /// Initialize pedometer for real-time tracking
  Future<void> _initializePedometer() async {
    try {
      print('🚶 Initializing pedometer...');

      if (!_pedometerService.isInitialized.value) {
        await _pedometerService.initialize();
      }

      if (_pedometerService.isAvailable.value) {
        print('✅ Pedometer initialized and available');
      } else {
        print('⚠️ Pedometer not available on this device');
      }
    } catch (e) {
      print('❌ Error initializing pedometer: $e');
    }
  }

  /// Set up real-time pedometer listeners
  void _setupPedometerListeners() {
    // Listen to pedometer incremental steps
    ever(_pedometerService.currentStepCount, (_) {
      // Call async method without await to avoid blocking the callback
      // The synchronized block inside will handle proper ordering
      _updateTodayDisplay();
    });

    // Listen to pedestrian status
    ever(_pedometerService.pedestrianStatus, (status) {
      pedestrianStatus.value = status;
    });

    print('✅ Pedometer listeners configured');
  }

  /// Internal method to update display (must be called inside _stateUpdateLock)
  void _updateTodayDisplayInternal() {
    try {
      // Combine HealthKit baseline + Pedometer increments
      final incrementalSteps = _pedometerService.incrementalSteps;
      final combinedSteps = _healthKitBaselineSteps + incrementalSteps;

      todaySteps.value = combinedSteps;

      // Calculate distance (use HealthKit baseline if available, otherwise estimate)
      if (_healthKitBaselineDistance > 0) {
        final incrementalDistance = incrementalSteps * _stepsToKmFactor;
        todayDistance.value = _healthKitBaselineDistance + incrementalDistance;
      } else {
        todayDistance.value = combinedSteps * _stepsToKmFactor;
      }

      // Calculate calories
      if (_healthKitBaselineCalories > 0) {
        final incrementalCalories = (incrementalSteps * _stepsToCaloriesFactor).round();
        todayCalories.value = _healthKitBaselineCalories + incrementalCalories;
      } else {
        todayCalories.value = (combinedSteps * _stepsToCaloriesFactor).round();
      }

      // Active time (estimate if not from HealthKit)
      if (_healthKitBaselineActiveTime > 0) {
        todayActiveTime.value = _healthKitBaselineActiveTime + _pedometerService.sessionDurationMinutes;
      } else {
        todayActiveTime.value = _pedometerService.sessionDurationMinutes;
      }

      print('📊 Display updated: ${todaySteps.value} steps (${incrementalSteps} incremental)');
    } catch (e) {
      print('❌ Error updating display: $e');
    }
  }

  /// Update today's display with combined data
  /// Uses lock to prevent race conditions during concurrent updates
  Future<void> _updateTodayDisplay() async {
    await _stateUpdateLock.synchronized(() {
      _updateTodayDisplayInternal();
    });
  }

  /// Load overall statistics from Firebase
  /// Aggregates all daily_steps documents and includes today's real-time data
  Future<void> _loadOverallStatistics() async {
    try {
      print('📊 Loading overall statistics from Firebase...');

      // Get aggregated stats from Firebase (all historical data)
      final firebaseStats = await _repository.getOverallStatisticsFromFirebase();

      // Check if today's data is already in Firebase (MUST query Firebase directly, not cache!)
      final todayDate = DailyStepData.getTodayDate();
      final todayInFirebase = await _repository.getDailyDataFromFirebaseDirectly(todayDate);

      // If today's data exists in Firebase, we need to subtract it before adding real-time values
      // to avoid double counting
      int firebaseSteps = firebaseStats['totalSteps'] as int;
      double firebaseDistance = firebaseStats['totalDistance'] as double;
      int firebaseDays = firebaseStats['totalDays'] as int;

      if (todayInFirebase != null) {
        // Today exists in Firebase - don't count it as a new day
        print('   📅 Today exists in Firebase with ${todayInFirebase.steps} steps');
      } else {
        // Today is not in Firebase yet, so count it as a new day
        firebaseDays += 1;
        print('   📅 Today not in Firebase yet - counting as new day');
      }

      // ✅ FIX: Overall stats = Firebase total (no adjustment needed)
      // Firebase aggregation already includes all steps, including today
      // We don't subtract and re-add because it causes the "0 steps" bug
      overallSteps.value = firebaseSteps;
      overallDistance.value = firebaseDistance;
      overallDays.value = firebaseDays;

      print('🔍 DEBUG: Overall stats from Firebase:');
      print('   Firebase total steps: $firebaseSteps');
      print('   Firebase total distance: ${firebaseDistance}km');
      print('   Total days: $firebaseDays');

      print('✅ Overall stats loaded: ${overallSteps.value} steps, ${overallDays.value} days');
    } catch (e) {
      print('❌ Error loading overall statistics: $e');
    }
  }

  /// Public method to refresh overall statistics (called after health sync)
  /// This ensures the homepage displays updated overall steps immediately
  Future<void> refreshOverallStatistics() async {
    print('📊 [PUBLIC] Refreshing overall statistics...');
    await _loadOverallStatistics();
  }

  /// Set up periodic sync to Firebase (every 30 seconds)
  void _setupPeriodicSync() {
    _periodicSyncTimer?.cancel();

    _periodicSyncTimer = Timer.periodic(_syncInterval, (timer) {
      print('⏰ Periodic sync triggered');
      syncToFirebase();
    });

    print('✅ Periodic sync configured (every ${_syncInterval.inSeconds} seconds)');
  }

  /// Set up midnight check for daily rollover
  void _setupMidnightCheck() {
    _midnightCheckTimer?.cancel();

    _midnightCheckTimer = Timer.periodic(_midnightCheckInterval, (timer) {
      _checkForMidnightRollover();
    });

    print('✅ Midnight check configured');
  }

  /// Check if date has changed (midnight rollover)
  /// Check for midnight rollover and handle day transition
  /// Uses lock to prevent concurrent execution if timer fires multiple times
  Future<void> _checkForMidnightRollover() async {
    await _midnightRolloverLock.synchronized(() async {
      final newDate = DailyStepData.getTodayDate();

      // Double-check inside lock - another call might have already processed this
      if (newDate != currentDate.value) {
        print('🌙 Midnight rollover detected: ${currentDate.value} → $newDate');

        // Finalize yesterday's data
        await _finalizeYesterday();

        // Reset for new day
        currentDate.value = newDate;
        await _fetchHealthKitBaseline();
        _pedometerService.resetSession();
        await _updateTodayDisplay();

        // Reload overall stats
        await _loadOverallStatistics();

        print('✅ New day initialized: $newDate');
      }
    });
  }

  /// Finalize yesterday's data and sync to Firebase
  /// IMPORTANT: Writes to HealthKit first before finalizing
  Future<void> _finalizeYesterday() async {
    try {
      final yesterday = DailyStepData.getYesterdayDate();
      print('💾 Finalizing data for $yesterday...');

      // STEP 1: Write yesterday's pedometer steps to HealthKit before midnight
      if (_pedometerService.incrementalSteps > 0) {
        print('✍️ Writing yesterday\'s pedometer steps to HealthKit before finalization...');
        final incrementalSteps = _pedometerService.incrementalSteps;

        // ✅ FIX: Write ONLY incremental steps, not total
        // HealthKit will ADD these to existing steps (no doubling)
        await _healthSyncService.writeStepsToHealth(
          incrementalSteps,  // Only write new steps
          DateTime.now().subtract(Duration(days: 1)), // Yesterday's date
        );
        print('✅ Yesterday\'s $incrementalSteps incremental steps written to HealthKit');
      }

      // STEP 2: Create final data for yesterday
      final yesterdayData = DailyStepData(
        date: yesterday,
        steps: todaySteps.value,
        distance: todayDistance.value,
        calories: todayCalories.value,
        activeMinutes: todayActiveTime.value,
        syncedAt: DateTime.now(),
        source: 'healthkit', // HealthKit is source of truth
        isSynced: false,
        pedometerSteps: 0,
        healthKitSteps: todaySteps.value,
      );

      // STEP 3: Save to repository (local + Firebase)
      await _repository.saveDailyData(yesterdayData, syncToFirebase: true);

      print('✅ Yesterday finalized: ${yesterdayData.steps} steps');
    } catch (e) {
      print('❌ Error finalizing yesterday: $e');
    }
  }

  /// Write pedometer incremental steps to HealthKit/Health Connect
  /// This ensures pedometer data is preserved in the health system
  Future<void> _writePedometerStepsToHealth() async {
    try {
      final incrementalSteps = _pedometerService.incrementalSteps;

      // Only write if we have pedometer steps to add
      if (incrementalSteps <= 0) {
        print('📊 No pedometer steps to write to HealthKit (incremental: $incrementalSteps)');
        return;
      }

      print('✍️ Writing $incrementalSteps pedometer steps to HealthKit...');

      // ✅ FIX: Write ONLY incremental steps to HealthKit
      // HealthKit will ADD these steps to what it already has
      // Writing total (baseline + incremental) causes doubling!
      final success = await _healthSyncService.writeStepsToHealth(
        incrementalSteps,  // Only write new steps, not baseline + incremental
        DateTime.now(),
      );

      if (success) {
        print('✅ Successfully wrote $incrementalSteps incremental steps to HealthKit');

        // Reset pedometer baseline since steps are now in HealthKit
        // Next HealthKit fetch will include these steps
        _pedometerService.resetSession();
      } else {
        print('⚠️ Failed to write steps to HealthKit (continuing with Firebase sync)');
      }
    } catch (e) {
      print('❌ Error writing pedometer steps to HealthKit: $e');
      // Don't throw - continue with Firebase sync even if HealthKit write fails
    }
  }

  /// Sync current data to Firebase
  /// NEW APPROACH: Write to HealthKit first, then read back and sync to Firebase
  /// This ensures HealthKit is ALWAYS the source of truth
  /// Uses lock to prevent concurrent sync operations
  Future<void> syncToFirebase() async {
    // Early check without lock for performance
    if (isSyncing.value) {
      print('⏭️ Sync already in progress');
      return;
    }

    await _syncLock.synchronized(() async {
      // Double-check inside lock
      if (isSyncing.value) {
        print('⏭️ Sync already in progress (double-check)');
        return;
      }

      try {
        isSyncing.value = true;
        print('☁️ Starting sync to Firebase...');

        // STEP 1: Write pedometer incremental steps to HealthKit first
        await _writePedometerStepsToHealth();

        // STEP 2: Re-fetch from HealthKit to get authoritative value
        // This ensures any pedometer steps we just wrote are included
        await _fetchHealthKitBaseline();

        // STEP 3: Now sync the authoritative HealthKit value to Firebase
        final todayData = DailyStepData(
          date: currentDate.value,
          steps: todaySteps.value, // This now reflects HealthKit authoritative value
          distance: todayDistance.value,
          calories: todayCalories.value,
          activeMinutes: todayActiveTime.value,
          syncedAt: DateTime.now(),
          source: 'healthkit', // Always HealthKit as source of truth
          isSynced: false,
          pedometerSteps: 0, // Reset since we wrote to HealthKit
          healthKitSteps: todaySteps.value,
        );

        // Save to repository (syncs to Firebase)
        await _repository.saveDailyData(todayData, syncToFirebase: true);

        // ✅ Reload overall statistics from Firebase after sync
        // This ensures overall stats reflect the latest Firebase aggregation
        await _loadOverallStatistics();

        // Update overall summary with the refreshed stats
        final summary = StepSummary(
          totalDays: overallDays.value,
          totalSteps: overallSteps.value,
          totalDistanceKm: overallDistance.value,
          totalCalories: todayCalories.value,
          totalActiveTimeMinutes: todayActiveTime.value,
          lastUpdated: DateTime.now(),
        );

        await _repository.updateStepSummary(summary);

        lastSyncTime.value = DateTime.now();
        print('✅ Sync complete: HealthKit ($todaySteps steps) → Firebase');
      } catch (e) {
        print('❌ Sync error: $e');
      } finally {
        isSyncing.value = false;
      }
    });
  }

  /// Update from HealthKit sync (called by external sync trigger)
  /// Only updates today's baseline - overall stats come from Firebase aggregation
  /// Uses lock to prevent concurrent state updates
  Future<void> updateFromHealthSync({
    required int todayStepsFromHealth,
    required double todayDistanceFromHealth,
    required int todayCaloriesFromHealth,
    required int todayActiveTimeFromHealth,
  }) async {
    await _stateUpdateLock.synchronized(() async {
      try {
        print('🏥 Updating from HealthKit sync...');

        // Store previous today's steps before updating
        final previousTodaySteps = todaySteps.value;

        // Update today's baselines
        _healthKitBaselineSteps = todayStepsFromHealth;
        _healthKitBaselineDistance = todayDistanceFromHealth;
        _healthKitBaselineCalories = todayCaloriesFromHealth;
        _healthKitBaselineActiveTime = todayActiveTimeFromHealth;

        // Reset pedometer session to avoid double counting
        _pedometerService.resetSession();

        // Update display directly (we're already inside the lock, so don't call the synchronized version)
        _updateTodayDisplayInternal();

        print('✅ HealthKit sync applied successfully');
        print('   Today: ${todaySteps.value} steps (was $previousTodaySteps)');

        // Calculate delta for race sync
        final stepsDelta = todayStepsFromHealth - previousTodaySteps;

        // Propagate health sync delta to active races
        if (stepsDelta > 0 && Get.isRegistered<RaceStepSyncService>()) {
          try {
            final raceService = Get.find<RaceStepSyncService>();
            await raceService.addHealthSyncSteps(stepsDelta);
            print('✅ Added $stepsDelta health-synced steps to active races');
          } catch (e) {
            print('⚠️ Could not update RaceStepSyncService: $e');
          }
        }

        print('   Overall: ${overallSteps.value} steps');
      } catch (e) {
        print('❌ Error applying HealthKit sync: $e');
      }
    });
  }

  /// Force refresh from HealthKit
  Future<void> refreshFromHealthKit() async {
    print('🔄 Forcing HealthKit refresh...');
    await _fetchHealthKitBaseline();
    await _loadOverallStatistics();
  }

  /// Get statistics for a specific filter period
  /// Queries Firebase for the date range and includes today's real-time data
  /// Filters: "Today", "Last 7 days", "Last 30 days", "Last 60 days", "All time"
  Future<Map<String, dynamic>> getStatisticsForFilter(String filter) async {
    try {
      print('📊 Getting statistics for filter: $filter');

      // Get Firebase stats for the filter period
      final firebaseStats = await _repository.getStatisticsForFilter(filter);

      int totalSteps = firebaseStats['totalSteps'] as int;
      double totalDistance = firebaseStats['totalDistance'] as double;
      int totalDays = firebaseStats['totalDays'] as int;
      int totalCalories = firebaseStats['totalCalories'] as int;
      int totalActiveTime = firebaseStats['totalActiveTime'] as int;

      // Check if today is included in the filter period
      final todayDate = DailyStepData.getTodayDate();
      final dateRange = StepDateUtils.getDateRangeForFilter(filter);
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      final todayIncluded = !todayStart.isBefore(dateRange.start) &&
                           !todayStart.isAfter(dateRange.end);

      if (todayIncluded) {
        // Check if today's data is already in Firebase aggregation (MUST query Firebase directly!)
        final todayInFirebase = await _repository.getDailyDataFromFirebaseDirectly(todayDate);

        if (todayInFirebase != null) {
          // Subtract today's Firebase data (we'll add real-time data instead)
          totalSteps -= todayInFirebase.steps;
          totalDistance -= todayInFirebase.distance;
          totalCalories -= todayInFirebase.calories;
          totalActiveTime -= todayInFirebase.activeMinutes;
          // Don't subtract day count - today is still a valid day
        } else {
          // Today is not in Firebase yet, so we need to count it as a new day
          totalDays += 1;
        }

        // Add today's real-time data
        totalSteps += todaySteps.value;
        totalDistance += todayDistance.value;
        totalCalories += todayCalories.value;
        totalActiveTime += todayActiveTime.value;

        print('✅ Filter stats ($filter): $totalSteps steps, $totalDays days (includes today real-time)');
      } else {
        print('✅ Filter stats ($filter): $totalSteps steps, $totalDays days (historical only)');
      }

      return {
        'totalSteps': totalSteps,
        'totalDistance': totalDistance,
        'totalDays': totalDays,
        'totalCalories': totalCalories,
        'totalActiveTime': totalActiveTime,
      };
    } catch (e) {
      print('❌ Error getting filter statistics: $e');
      return {
        'totalSteps': 0,
        'totalDistance': 0.0,
        'totalDays': 0,
        'totalCalories': 0,
        'totalActiveTime': 0,
      };
    }
  }

  /// Check if manual sync is allowed (smart throttling)
  /// Returns true if:
  /// - More than 30 seconds since last manual sync OR
  /// - Last sync failed OR
  /// - Never synced manually before
  bool get canManualSync {
    // Always allow if never synced
    if (lastManualSyncTime.value == null) {
      return true;
    }

    // Allow if last sync failed
    if (syncError.value) {
      return true;
    }

    // Check 30-second cooldown
    final timeSinceLastSync = DateTime.now().difference(lastManualSyncTime.value!);
    return timeSinceLastSync.inSeconds >= 30;
  }

  /// Get time remaining until next manual sync is available
  int get secondsUntilManualSync {
    if (canManualSync) return 0;

    final timeSinceLastSync = DateTime.now().difference(lastManualSyncTime.value!);
    return math.max(0, 30 - timeSinceLastSync.inSeconds);
  }

  /// Manually sync health data with animated progress
  /// Returns true if sync was successful
  Future<bool> manualSyncHealthData() async {
    if (isManualSyncing.value) {
      print('⏭️ Manual sync already in progress');
      return false;
    }

    if (!canManualSync) {
      print('⏭️ Manual sync on cooldown (${secondsUntilManualSync}s remaining)');
      return false;
    }

    try {
      isManualSyncing.value = true;
      syncError.value = false;
      syncSuccess.value = false;
      syncProgress.value = 0.0;
      syncStatusMessage.value = 'Connecting...';

      print('🔄 Starting manual health sync...');

      // Phase 1: Connecting (0-20%)
      await Future.delayed(const Duration(milliseconds: 300));
      syncProgress.value = 0.2;
      syncStatusMessage.value = 'Fetching HealthKit data...';

      // Call health sync service
      final syncResult = await _healthSyncService.syncHealthData(forceSync: true);

      // Phase 2: Fetching HealthKit (20-60%)
      await Future.delayed(const Duration(milliseconds: 500));
      syncProgress.value = 0.6;
      syncStatusMessage.value = 'Syncing to Firebase...';

      if (!syncResult.isSuccess) {
        // Sync failed
        print('❌ Manual sync failed: ${syncResult.errorMessage}');
        syncError.value = true;
        syncStatusMessage.value = syncResult.errorMessage ?? 'Sync failed';
        return false;
      }

      // Phase 3: Syncing to Firebase (60-100%)
      await Future.delayed(const Duration(milliseconds: 400));
      syncProgress.value = 0.9;

      // Refresh overall statistics after successful sync
      await refreshOverallStatistics();

      // Complete
      syncProgress.value = 1.0;
      syncSuccess.value = true;
      syncStatusMessage.value = 'Sync complete!';
      lastManualSyncTime.value = DateTime.now();

      print('✅ Manual sync completed successfully');

      // Schedule reset of success flag after showing it for 2 seconds
      // Use unawaited to avoid blocking, but handle cleanup properly
      _scheduleManualSyncReset();

      return true;
    } catch (e) {
      print('❌ Manual sync error: $e');
      syncError.value = true;
      syncStatusMessage.value = 'Sync error: ${e.toString()}';

      // Schedule reset for error state too
      _scheduleManualSyncReset();

      return false;
    } finally {
      isManualSyncing.value = false;
    }
  }

  /// Schedule reset of manual sync UI state
  /// Separated into its own method to avoid race conditions
  void _scheduleManualSyncReset() {
    Future.delayed(const Duration(seconds: 2), () {
      // Only reset if no new sync has started
      if (!isManualSyncing.value) {
        syncSuccess.value = false;
        syncError.value = false;
        syncProgress.value = 0.0;
        syncStatusMessage.value = '';
      }
    });
  }

  /// Get diagnostics for debugging
  Map<String, dynamic> getDiagnostics() {
    return {
      'isInitialized': isInitialized.value,
      'currentDate': currentDate.value,
      'todaySteps': todaySteps.value,
      'healthKitBaseline': _healthKitBaselineSteps,
      'pedometerIncremental': _pedometerService.incrementalSteps,
      'overallSteps': overallSteps.value,
      'overallDays': overallDays.value,
      'lastSyncTime': lastSyncTime.value?.toIso8601String(),
      'lastManualSyncTime': lastManualSyncTime.value?.toIso8601String(),
      'canManualSync': canManualSync,
      'pedometerDiagnostics': _pedometerService.getDiagnostics(),
    };
  }

  @override
  void onClose() async {
    print('👋 StepTrackingService: Disposing...');
    _periodicSyncTimer?.cancel();
    _midnightCheckTimer?.cancel();

    // CRITICAL: Final sync before closing
    // This ensures any pedometer steps are written to HealthKit and synced to Firebase
    print('🔄 Performing final sync before app close...');
    await syncToFirebase();
    print('✅ Final sync complete');

    super.onClose();
  }
}
