import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stepzsync/services/preferences_service.dart';
import 'package:stepzsync/services/step_tracking_service.dart';
import 'package:synchronized/synchronized.dart';
import 'pedometer_service.dart';
import 'race_service.dart';
import 'health_sync_service.dart';
import '../utils/race_validation_utils.dart';

/// Race Baseline - Pedometer-based race step synchronization
///
/// This model tracks race progress using pedometer sensor:
/// 1. **Baseline Steps** (at join): Pedometer steps when user joined race (anchor point)
/// 2. **Current Steps**: Current pedometer cumulative steps
/// 3. **Delta**: Current - Baseline = Race Progress
///
/// Formula:
/// - raceSteps = currentPedometerSteps - baselinePedometerSteps
/// - raceDistance = raceSteps * 0.000762 km
/// - raceCalories = raceSteps * 0.04 cal
///
/// This ensures:
/// - Realtime step updates (triggered on every pedometer event)
/// - Single source of truth (pedometer sensor)
/// - Simple and reliable calculation
/// - Device reboot recovery using snapshots
/// - Gap filling when app was closed
class RaceBaseline {
  final String raceId;
  final String raceTitle;
  DateTime startTime;                    // When race started (can be updated on re-capture)

  // Persistent state (survives app restarts)
  int serverSteps;                       // Last known steps on server (SOURCE OF TRUTH)
  double serverDistance;                 // Last known distance (km) on server
  int serverCalories;                    // Last known calories on server

  // Session state (resets on app restart, accumulates during session)
  int sessionRaceSteps;                  // Steps walked in THIS RACE during current session
  double sessionRaceDistance;            // Distance (km) walked in THIS RACE during current session
  int sessionRaceCalories;               // Calories burned in THIS RACE during current session

  // HealthKit baseline tracking (for delta calculation)
  double healthKitBaselineDistance;      // HealthKit distance when race started (or last sync)
  int healthKitBaselineCalories;         // HealthKit calories when race started (or last sync)

  // NEW: Time-based baseline tracking
  bool useTimeBasedBaseline;             // Flag to indicate time-based vs legacy baseline
  int? healthKitStepsAtStart;            // HealthKit steps when race was joined (baseline anchor)
  double? healthKitDistanceAtStart;      // HealthKit distance when race was joined
  int? healthKitCaloriesAtStart;         // HealthKit calories when race was joined

  // Completion tracking
  bool isCompleted;                      // Whether participant finished this race
  DateTime? completedAt;                 // When participant finished

  // Data integrity tracking (protection against race conditions)
  int maxStepsEverSeen;                  // Highest step count ever recorded (monotonic increasing)
  DateTime? lastServerSync;              // When we last fetched fresh data from server

  // Baseline re-capture tracking (for scheduled races)
  bool wasRecaptured;                    // Whether baseline was re-captured at race start
  DateTime? originalBaselineTime;        // When original baseline was captured (at creation/join)
  int? originalBaselineSteps;            // Original baseline steps (before re-capture)

  RaceBaseline({
    required this.raceId,
    required this.raceTitle,
    required this.startTime,
    required this.serverSteps,
    this.serverDistance = 0.0,
    this.serverCalories = 0,
    required this.sessionRaceSteps,
    this.sessionRaceDistance = 0.0,
    this.sessionRaceCalories = 0,
    this.healthKitBaselineDistance = 0.0,
    this.healthKitBaselineCalories = 0,
    this.useTimeBasedBaseline = false,
    this.healthKitStepsAtStart,
    this.healthKitDistanceAtStart,
    this.healthKitCaloriesAtStart,
    this.isCompleted = false,
    this.completedAt,
    int? maxStepsEverSeen,
    this.lastServerSync,
    this.wasRecaptured = false,
    this.originalBaselineTime,
    this.originalBaselineSteps,
  }) : maxStepsEverSeen = maxStepsEverSeen ?? serverSteps;

  // JSON serialization for persistence
  Map<String, dynamic> toJson() {
    return {
      'raceId': raceId,
      'raceTitle': raceTitle,
      'startTime': startTime.toIso8601String(),
      'serverSteps': serverSteps,
      'serverDistance': serverDistance,
      'serverCalories': serverCalories,
      'sessionRaceSteps': sessionRaceSteps,
      'sessionRaceDistance': sessionRaceDistance,
      'sessionRaceCalories': sessionRaceCalories,
      'healthKitBaselineDistance': healthKitBaselineDistance,
      'healthKitBaselineCalories': healthKitBaselineCalories,
      'useTimeBasedBaseline': useTimeBasedBaseline,
      'healthKitStepsAtStart': healthKitStepsAtStart,
      'healthKitDistanceAtStart': healthKitDistanceAtStart,
      'healthKitCaloriesAtStart': healthKitCaloriesAtStart,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'maxStepsEverSeen': maxStepsEverSeen,
      'lastServerSync': lastServerSync?.toIso8601String(),
      'wasRecaptured': wasRecaptured,
      'originalBaselineTime': originalBaselineTime?.toIso8601String(),
      'originalBaselineSteps': originalBaselineSteps,
    };
  }

  factory RaceBaseline.fromJson(Map<String, dynamic> json) {
    return RaceBaseline(
      raceId: json['raceId'] as String,
      raceTitle: json['raceTitle'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      // Load server state from storage, will be refreshed from Firestore on startup
      serverSteps: json['serverSteps'] as int? ?? 0,
      serverDistance: json['serverDistance'] as double? ?? 0.0,
      serverCalories: json['serverCalories'] as int? ?? 0,
      // ✅ CRITICAL FIX: Load session metrics from storage to survive app restarts during pedometer resets
      // This prevents metric loss if app crashes after pedometer reset but before next sync
      sessionRaceSteps: json['sessionRaceSteps'] as int? ?? 0,
      sessionRaceDistance: json['sessionRaceDistance'] as double? ?? 0.0,
      sessionRaceCalories: json['sessionRaceCalories'] as int? ?? 0,
      // Load HealthKit baselines
      healthKitBaselineDistance: json['healthKitBaselineDistance'] as double? ?? 0.0,
      healthKitBaselineCalories: json['healthKitBaselineCalories'] as int? ?? 0,
      // Load time-based baseline fields (backwards compatible with legacy baselines)
      useTimeBasedBaseline: json['useTimeBasedBaseline'] as bool? ?? false,
      healthKitStepsAtStart: json['healthKitStepsAtStart'] as int?,
      healthKitDistanceAtStart: json['healthKitDistanceAtStart'] as double?,
      healthKitCaloriesAtStart: json['healthKitCaloriesAtStart'] as int?,
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt'] as String) : null,
      // Load data integrity tracking
      maxStepsEverSeen: json['maxStepsEverSeen'] as int?,
      lastServerSync: json['lastServerSync'] != null ? DateTime.tryParse(json['lastServerSync'] as String) : null,
      // Load baseline re-capture tracking (backwards compatible - defaults to false)
      wasRecaptured: json['wasRecaptured'] as bool? ?? false,
      originalBaselineTime: json['originalBaselineTime'] != null ? DateTime.tryParse(json['originalBaselineTime'] as String) : null,
      originalBaselineSteps: json['originalBaselineSteps'] as int?,
    );
  }

  @override
  String toString() {
    return 'RaceBaseline(race: $raceTitle, server: $serverSteps steps, session: +$sessionRaceSteps, started: $startTime)';
  }
}

/// Race Step Sync Service (PEDOMETER-ONLY)
///
/// Syncs pedometer steps to active races in real-time
/// Uses ONLY pedometer sensor data - no Health API dependency for race tracking
///
/// Features:
/// - Per-race baseline tracking using pedometer cumulative steps
/// - Realtime updates triggered on every pedometer step event
/// - Persists baselines across app restarts via SharedPreferences
/// - Auto-detects user's active races (statusId 3 or 6)
/// - Syncs race progress every 1 second (realtime)
/// - Handles multiple simultaneous races
/// - Device reboot detection and recovery using snapshots
/// - Gap filling when app was closed using 10-second snapshots
/// - Simple and reliable - single source of truth (pedometer)
class RaceStepSyncService extends GetxService {
  // ================== DEPENDENCIES ==================
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final PedometerService _pedometerService;
  SharedPreferences? _prefs;

  // ================== STATE ==================
  final RxBool isRunning = false.obs;
  final RxInt activeRaceCount = 0.obs;
  final RxInt totalSyncCount = 0.obs;
  final RxString lastSyncTime = ''.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  // ================== PRIVATE STATE ==================
  Set<String> _activeRaceIds = {};
  Map<String, RaceBaseline> _raceBaselines = {}; // Per-race baselines
  int _lastSyncedSteps = 0;
  Timer? _syncTimer;
  Timer? _raceRefreshTimer;
  Timer? _batchSaveTimer;  // Timer for batched baseline saves
  bool _isInitialized = false;

  // ================== CUMULATIVE STEP TRACKING ==================
  // These fields maintain a cumulative counter independent of pedometer resets
  int _lastPedometerReading = 0;  // Last pedometer incremental reading
  int _cumulativeSteps = 0;        // Cumulative steps for current session (survives pedometer resets)

  // ================== PENDING HEALTHKIT STEPS ==================
  // Buffer for HealthKit steps received before service starts running
  int _pendingHealthKitSteps = 0;

  // ================== REQUEST DEDUPLICATION ==================
  // Track processed request IDs to prevent duplicate propagation
  final Set<String> _processedRequests = {};

  // ================== CONCURRENCY CONTROL ==================
  /// Lock for baseline updates to prevent race conditions
  final Lock _baselineUpdateLock = Lock();

  /// Lock for baseline saves to prevent concurrent write corruption
  final Lock _baselineSaveLock = Lock();

  // ================== CONSTANTS ==================
  static const Duration SYNC_INTERVAL = Duration(seconds: 1); // Real-time updates every 1 second
  static const Duration RACE_REFRESH_INTERVAL = Duration(seconds: 30); // Refresh race list every 30 sec
  static const int MIN_STEP_DELTA = 1; // Sync every step for real-time tracking
  static const double STEPS_TO_KM_FACTOR = 0.000762; // 1 step ≈ 0.762 meters
  static const double STEPS_TO_CALORIES_FACTOR = 0.04; // 1 step ≈ 0.04 calories
  static const String BASELINES_STORAGE_KEY = 'race_step_baselines';

  @override
  void onInit() {
    super.onInit();
    dev.log('🏁 [RACE_SYNC] RaceStepSyncService initialized');
  }

  /// Initialize the race step sync service
  Future<void> initialize() async {
    if (_isInitialized) {
      dev.log('⚠️ [RACE_SYNC] Already initialized');
      return;
    }

    try {
      dev.log('🚀 [RACE_SYNC] Initializing race step sync service...');

      // Initialize SharedPreferences
      _prefs = await SharedPreferences.getInstance();
      dev.log('✅ [RACE_SYNC] SharedPreferences initialized');

      // Load persisted baselines
      await _loadBaselines();

      // Get PedometerService
      _pedometerService = Get.isRegistered<PedometerService>()
          ? Get.find<PedometerService>()
          : Get.put(PedometerService(), permanent: true);

      dev.log('✅ [RACE_SYNC] PedometerService obtained');

      // Wait for pedometer to initialize properly using Completer
      if (!_pedometerService.isInitialized.value) {
        dev.log('⏳ [RACE_SYNC] Waiting for PedometerService to initialize...');
        await _pedometerService.initializationComplete;
        dev.log('✅ [RACE_SYNC] PedometerService initialization complete');
      }

      _isInitialized = true;
      dev.log('✅ [RACE_SYNC] Initialization complete');
      dev.log('📊 [RACE_SYNC] Current pedometer incremental steps: ${_pedometerService.incrementalSteps}');
    } catch (e) {
      dev.log('❌ [RACE_SYNC] Initialization error: $e');
      hasError.value = true;
      errorMessage.value = e.toString();
    }
  }

  /// Start syncing steps to active races
  Future<void> startSyncing() async {
    if (isRunning.value) {
      dev.log('⚠️ [RACE_SYNC] Already running');
      return;
    }

    try {
      dev.log('🏁 [RACE_SYNC] Starting race step sync...');

      // Ensure initialized
      if (!_isInitialized) {
        await initialize();
      }

      // Check if user is logged in
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        dev.log('⚠️ [RACE_SYNC] No user logged in, cannot sync');
        return;
      }

      // Start timers
      _startSyncTimer();
      _startRaceRefreshTimer();

      isRunning.value = true;
      hasError.value = false;
      errorMessage.value = '';

      // Initialize cumulative step counter
      _lastPedometerReading = _pedometerService.incrementalSteps;
      _cumulativeSteps = 0;
      dev.log('🔄 [RACE_SYNC] Initialized cumulative counter: pedometer baseline = $_lastPedometerReading steps');

      dev.log('✅ [RACE_SYNC] Race step sync started');
      dev.log('📊 [RACE_SYNC] Cached baselines: ${_raceBaselines.length}');
      dev.log('📊 [RACE_SYNC] Current pedometer: ${_pedometerService.incrementalSteps} steps');

      // Refresh server state for all cached baselines (critical for cold restarts)
      if (_raceBaselines.isNotEmpty) {
        await _refreshServerStateForAllRaces();
      }

      // Quick refresh to get latest races
      await _refreshActiveRaces();

      dev.log('📊 [RACE_SYNC] Active races after refresh: ${_activeRaceIds.length}');

      // Apply any pending HealthKit steps that arrived before service started
      if (_pendingHealthKitSteps > 0 && _activeRaceIds.isNotEmpty) {
        dev.log('🔄 [RACE_SYNC] Applying $_pendingHealthKitSteps pending HealthKit steps to active races...');

        // ✅ CRITICAL FIX: Protect with lock to prevent race conditions with _refreshActiveRaces()
        await _baselineUpdateLock.synchronized(() async {
          // Add pending steps to cumulative counter
          _cumulativeSteps += _pendingHealthKitSteps;

          // Add to each active race's session steps
          for (final raceId in _activeRaceIds) {
            final baseline = _raceBaselines[raceId];
            if (baseline != null) {
              baseline.sessionRaceSteps += _pendingHealthKitSteps;
              dev.log('   ✅ "${baseline.raceTitle}": +$_pendingHealthKitSteps steps from pending health sync');
            }
          }

          // Save updated baselines (batched)
          _scheduleBatchSave();
        });

        // Clear pending steps
        final appliedSteps = _pendingHealthKitSteps;
        _pendingHealthKitSteps = 0;

        dev.log('✅ [RACE_SYNC] Applied $appliedSteps pending HealthKit steps to ${_activeRaceIds.length} race(s)');

        // Trigger immediate sync to Firebase to update race progress
        await _performSync();
      } else if (_pendingHealthKitSteps > 0) {
        dev.log('ℹ️ [RACE_SYNC] $_pendingHealthKitSteps pending HealthKit steps, but no active races yet');
      }
      dev.log('📊 [RACE_SYNC] Loaded baselines: ${_raceBaselines.length}');
    } catch (e, stackTrace) {
      dev.log('❌ [RACE_SYNC] Start error: $e');
      dev.log('📍 [RACE_SYNC] Stack trace: $stackTrace');
      hasError.value = true;
      errorMessage.value = e.toString();
    }
  }

  /// Stop syncing steps to races
  Future<void> stopSyncing() async {
    if (!isRunning.value) {
      dev.log('⚠️ [RACE_SYNC] Not running');
      return;
    }

    try {
      dev.log('🛑 [RACE_SYNC] Stopping race step sync...');

      // Save baselines before stopping
      await _saveBaselines();

      // Cancel timers
      _syncTimer?.cancel();
      _syncTimer = null;

      _raceRefreshTimer?.cancel();
      _raceRefreshTimer = null;

      // Clear state (but keep baselines for next start)
      _activeRaceIds.clear();
      _lastSyncedSteps = 0;

      isRunning.value = false;
      activeRaceCount.value = 0;

      dev.log('✅ [RACE_SYNC] Race step sync stopped');
    } catch (e) {
      dev.log('❌ [RACE_SYNC] Stop error: $e');
    }
  }

  /// Refresh list of active races for current user
  Future<void> _refreshActiveRaces() async {
    // ✅ CRITICAL FIX: Protect with lock to prevent race conditions with _performSync()
    // This prevents concurrent modification of _activeRaceIds and _raceBaselines
    await _baselineUpdateLock.synchronized(() async {
      try {
        final currentUser = _auth.currentUser;
        if (currentUser == null) return;

        dev.log('🔍 [RACE_SYNC] Refreshing active races for user: ${currentUser.uid}');

      // Query races where:
      // 1. User is a participant (check participants subcollection)
      // 2. Race is active (statusId = 3) or in deadline mode (statusId = 6)
      final racesSnapshot = await _firestore
          .collection('races')
          .where('statusId', whereIn: [3, 6]) // Active or Deadline
          .get();

      dev.log('📊 [RACE_SYNC] Found ${racesSnapshot.docs.length} active/deadline races in system');

      // Filter to races where current user is a participant
      Set<String> newActiveRaceIds = {};
      Map<String, String> raceTitles = {}; // Store race titles for new races

      for (final raceDoc in racesSnapshot.docs) {
        final raceId = raceDoc.id;

        // Check if user is a participant in this race
        final participantDoc = await _firestore
            .collection('races')
            .doc(raceId)
            .collection('participants')
            .doc(currentUser.uid)
            .get();

        if (participantDoc.exists) {
          // ✅ Filter out races where user has already completed
          final participantData = participantDoc.data();
          final isCompleted = participantData?['isCompleted'] as bool? ?? false;
          if (isCompleted) {
            final raceData = raceDoc.data(); // QueryDocumentSnapshot guarantees non-null
            dev.log('⏭️ [RACE_SYNC] Skipping completed race: ${raceData['title']}');
            continue;
          }

          newActiveRaceIds.add(raceId);
          final raceData = raceDoc.data(); // QueryDocumentSnapshot guarantees non-null
          raceTitles[raceId] = raceData['title'] as String? ?? 'Unknown Race';
          dev.log('✅ [RACE_SYNC] User is participant in race: $raceId');
        }
      }

      // Detect NEW races (need baselines)
      final newRaces = newActiveRaceIds.difference(_activeRaceIds.map((id) => id).toSet());
      for (final raceId in newRaces) {
        if (!_raceBaselines.containsKey(raceId)) {
          await _setRaceBaseline(raceId, raceTitles[raceId] ?? 'Unknown Race');
          dev.log('🆕 [RACE_SYNC] New race baseline created: ${raceTitles[raceId]}');
        }
      }

      // ✅ NEW: Detect scheduled races that have started (need baseline re-capture)
      // This ensures only post-start steps count for scheduled races
      for (final raceId in newActiveRaceIds) {
        try {
          final baseline = _raceBaselines[raceId];
          if (baseline == null) continue;

          // Skip if already re-captured
          if (baseline.wasRecaptured) continue;

          // Fetch race document to check for auto-start
          final raceDoc = await _firestore.collection('races').doc(raceId).get();
          if (!raceDoc.exists) continue;

          final raceData = raceDoc.data();
          if (raceData == null) continue;

          // Check if race was auto-started (scheduled race that transitioned to active)
          final autoStarted = raceData['autoStarted'] as bool? ?? false;
          final actualStartTimeField = raceData['actualStartTime'];

          if (autoStarted && actualStartTimeField != null) {
            final actualStartTime = (actualStartTimeField as Timestamp).toDate();

            // Check if baseline was captured BEFORE race started (stale baseline)
            // Compare baseline capture time vs race actual start time
            final baselineTime = baseline.originalBaselineTime ?? baseline.startTime;

            if (baselineTime.isBefore(actualStartTime)) {
              dev.log('🔍 [RACE_SYNC] Detected scheduled race that started: "${baseline.raceTitle}"');
              dev.log('   Baseline time: ${baselineTime.toIso8601String()}');
              dev.log('   Race start: ${actualStartTime.toIso8601String()}');
              dev.log('   Triggering baseline re-capture...');

              // Re-capture baseline at actual race start time
              await _recaptureBaselineForStartedRace(raceId, actualStartTime);
            }
          }
        } catch (e) {
          dev.log('⚠️ [RACE_SYNC] Error checking race $raceId for baseline re-capture: $e');
          // Continue processing other races
        }
      }

      // Detect COMPLETED races (clean up baselines)
      final completedRaces = _activeRaceIds.difference(newActiveRaceIds);
      for (final raceId in completedRaces) {
        await _removeRaceBaseline(raceId);
      }

      // Update active race IDs
      final previousCount = _activeRaceIds.length;
      _activeRaceIds = newActiveRaceIds;
      activeRaceCount.value = _activeRaceIds.length;

      dev.log('📊 [RACE_SYNC] Active races updated: $previousCount → ${_activeRaceIds.length}');

      if (_activeRaceIds.isNotEmpty) {
        dev.log('🏁 [RACE_SYNC] Active race IDs: $_activeRaceIds');
      } else {
        dev.log('ℹ️ [RACE_SYNC] No active races for this user');
      }
      } catch (e, stackTrace) {
        dev.log('❌ [RACE_SYNC] Error refreshing active races: $e');
        dev.log('📍 [RACE_SYNC] Stack trace: $stackTrace');
      }
    });
  }

  /// Set baseline for a race using dual-layer tracking
  /// Fetches current server state and starts session tracking
  Future<void> _setRaceBaseline(String raceId, String raceTitle) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        dev.log('❌ [RACE_SYNC] No authenticated user');
        return;
      }

      // ✅ CRITICAL FIX: Load baseline from local storage FIRST (fast, no Firebase query)
      // This uses the baseline we captured at join time
      // ✅ RETRY MECHANISM: Wait and retry if baseline not immediately available
      dev.log('📦 [RACE_SYNC] Loading baseline from local storage...');

      int baselineSteps = 0;
      double baselineDistance = 0.0;
      int baselineCalories = 0;
      DateTime raceStartTime = DateTime.now();
      bool foundLocalBaseline = false;

      // Retry logic with exponential backoff (max 3 retries, 100ms, 200ms, 400ms)
      int maxRetries = 3;
      int retryDelay = 100; // milliseconds

      for (int attempt = 0; attempt < maxRetries; attempt++) {
        try {
          final prefsService = Get.find<PreferencesService>();
          final localBaseline = await prefsService.getRaceBaseline(raceId, userId);

          if (localBaseline != null) {
            baselineSteps = localBaseline['baselineSteps'] ?? 0;
            baselineDistance = (localBaseline['baselineDistance'] ?? 0.0).toDouble();
            baselineCalories = localBaseline['baselineCalories'] ?? 0;
            raceStartTime = DateTime.parse(localBaseline['raceStartTime'] ?? DateTime.now().toIso8601String());

            // ✅ VALIDATION: Only accept non-zero baseline
            if (baselineSteps > 0) {
              foundLocalBaseline = true;
              dev.log('✅ [RACE_SYNC] Loaded VALID baseline from local storage (attempt ${attempt + 1}):');
              dev.log('   Baseline: $baselineSteps steps, ${baselineDistance.toStringAsFixed(2)} km, $baselineCalories cal');
              dev.log('   Race start: ${raceStartTime.toIso8601String()}');
              break; // Success - exit retry loop
            } else {
              dev.log('⚠️ [RACE_SYNC] Baseline found but INVALID (steps = 0) on attempt ${attempt + 1}');
              if (attempt < maxRetries - 1) {
                dev.log('   ⏳ Waiting ${retryDelay}ms before retry...');
                await Future.delayed(Duration(milliseconds: retryDelay));
                retryDelay *= 2; // Exponential backoff
              }
            }
          } else {
            dev.log('⚠️ [RACE_SYNC] No local baseline found on attempt ${attempt + 1}/${maxRetries}');
            if (attempt < maxRetries - 1) {
              dev.log('   ⏳ Waiting ${retryDelay}ms before retry...');
              await Future.delayed(Duration(milliseconds: retryDelay));
              retryDelay *= 2; // Exponential backoff
            }
          }
        } catch (e) {
          dev.log('⚠️ [RACE_SYNC] Error loading baseline from local storage (attempt ${attempt + 1}): $e');
          if (attempt < maxRetries - 1) {
            await Future.delayed(Duration(milliseconds: retryDelay));
            retryDelay *= 2;
          }
        }
      }

      // If local baseline not found after retries, fall back to Firebase participant document
      if (!foundLocalBaseline) {
        dev.log('📊 [RACE_SYNC] No valid local baseline after retries, loading from Firebase participant document...');

        // Fetch participant data to get baseline from Firebase
        final participantDoc = await _firestore
            .collection('races')
            .doc(raceId)
            .collection('participants')
            .doc(userId)
            .get();

        if (participantDoc.exists) {
          final participantData = participantDoc.data();
          if (participantData != null) {
            baselineSteps = participantData['baselineSteps'] ?? 0;
            baselineDistance = (participantData['baselineDistance'] ?? 0.0).toDouble();
            baselineCalories = participantData['baselineCalories'] ?? 0;

            // ✅ VALIDATION: Ensure Firebase baseline is also non-zero
            if (baselineSteps > 0) {
              foundLocalBaseline = true; // Mark as found so we proceed

              // Also save to local storage for next time
              try {
                final prefsService = Get.find<PreferencesService>();
                final baselineData = {
                  'raceId': raceId,
                  'userId': userId,
                  'baselineSteps': baselineSteps,
                  'baselineDistance': baselineDistance,
                  'baselineCalories': baselineCalories,
                  'baselineTimestamp': DateTime.now().toIso8601String(),
                  'raceStartTime': raceStartTime.toIso8601String(),
                };
                await prefsService.saveRaceBaseline(raceId, userId, baselineData);
                dev.log('✅ [RACE_SYNC] Cached VALID baseline to local storage from Firebase');
              } catch (e) {
                dev.log('⚠️ [RACE_SYNC] Could not cache baseline: $e');
              }

              dev.log('✅ [RACE_SYNC] Loaded VALID baseline from Firebase:');
              dev.log('   Baseline: $baselineSteps steps, ${baselineDistance.toStringAsFixed(2)} km, $baselineCalories cal');
            } else {
              dev.log('❌ [RACE_SYNC] Firebase baseline is INVALID (steps = 0)!');
              dev.log('   ⚠️ This race may have been created without proper baseline capture');
              dev.log('   ⏸️ Will NOT create baseline object to prevent step drift');
              return; // Exit early - don't create baseline with zero values
            }
          } else {
            dev.log('❌ [RACE_SYNC] Participant data is null in Firebase');
            return; // Exit early
          }
        } else {
          dev.log('❌ [RACE_SYNC] Participant document does not exist in Firebase');
          return; // Exit early
        }
      }

      // Fetch race document to get actual start time
      final raceDoc = await _firestore.collection('races').doc(raceId).get();
      final raceData = raceDoc.data();

      // Get actual race start time from Firebase
      final actualStartTimeField = raceData?['actualStartTime'];

      if (actualStartTimeField is Timestamp) {
        raceStartTime = actualStartTimeField.toDate();
        dev.log('✅ [RACE_SYNC] Using actual race start time: ${raceStartTime.toIso8601String()}');
      } else if (!foundLocalBaseline) {
        // Only use current time if we don't have local baseline
        raceStartTime = DateTime.now();
        dev.log('⚠️ [RACE_SYNC] No actualStartTime found for race $raceId, using current time');
      }

      // Fetch participant data including completion status (source of truth)
      final participantData = await _fetchParticipantData(raceId);

      // ✅ FINAL SAFETY CHECK: Ensure baseline is valid before creating RaceBaseline object
      if (baselineSteps == 0) {
        dev.log('❌ [RACE_SYNC] CRITICAL: Refusing to create baseline with 0 steps!');
        dev.log('   This would cause all current steps to be attributed to the race (step drift)');
        dev.log('   baselineSteps: $baselineSteps');
        dev.log('   baselineDistance: $baselineDistance');
        dev.log('   baselineCalories: $baselineCalories');
        dev.log('   ⚠️ Race baseline will NOT be created. Sync will be skipped for this race.');
        return; // Exit early - do NOT create baseline
      }

      dev.log('✅ [RACE_SYNC] Final baseline validation passed - creating RaceBaseline object:');
      dev.log('   baselineSteps: $baselineSteps (VALID - non-zero)');
      dev.log('   baselineDistance: ${baselineDistance.toStringAsFixed(2)} km');
      dev.log('   baselineCalories: $baselineCalories cal');

      // ✅ CRITICAL FIX: Create baseline using saved baseline from join time
      // This ensures we calculate delta from when user joined, not from detection time
      final baseline = RaceBaseline(
        raceId: raceId,
        raceTitle: raceTitle,
        startTime: raceStartTime,  // ✅ FIXED: Use actual race start time
        serverSteps: participantData.steps,  // Server state (persistent)
        serverDistance: participantData.distance,  // Server distance
        serverCalories: participantData.calories,  // Server calories
        sessionRaceSteps: 0,       // Start counting from 0 in this session
        sessionRaceDistance: 0.0,  // Start distance from 0
        sessionRaceCalories: 0,    // Start calories from 0
        healthKitBaselineDistance: baselineDistance,  // ✅ FIXED: Use saved baseline
        healthKitBaselineCalories: baselineCalories,  // ✅ FIXED: Use saved baseline
        useTimeBasedBaseline: true,  // ✅ ALWAYS use simple delta calculation
        healthKitStepsAtStart: baselineSteps,  // ✅ FIXED: Saved baseline steps
        healthKitDistanceAtStart: baselineDistance,  // ✅ FIXED: Saved baseline distance
        healthKitCaloriesAtStart: baselineCalories,  // ✅ FIXED: Saved baseline calories
        isCompleted: participantData.isCompleted,  // Load completion status
        completedAt: participantData.completedAt,  // Load completion time
      );

      _raceBaselines[raceId] = baseline;
      _scheduleBatchSave(); // Non-critical, will be saved by server state refresh

      // Log completion status for completed races
      if (baseline.isCompleted) {
        dev.log('🏁 [RACE_SYNC] Loaded completed race: "$raceTitle" (finished ${baseline.completedAt})');
      } else {
        dev.log('✅ [RACE_SYNC] Set baseline for "$raceTitle":');
        dev.log('   Baseline (from join): ${baselineSteps} steps, ${baselineDistance.toStringAsFixed(2)} km, $baselineCalories cal');
        dev.log('   Server (current Firebase): ${participantData.steps} steps, ${participantData.distance.toStringAsFixed(2)} km, ${participantData.calories} cal');
        dev.log('   Session: 0 steps, 0.00 km, 0 cal (starting fresh)');
        dev.log('   Started: ${raceStartTime.toIso8601String()}');
      }
    } catch (e) {
      dev.log('❌ [RACE_SYNC] Error setting baseline for race $raceId: $e');
    }
  }

  /// Re-capture baseline for scheduled race that has started
  /// This ensures only steps AFTER race starts are counted, not pre-race steps
  Future<void> _recaptureBaselineForStartedRace(String raceId, DateTime actualStartTime) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        dev.log('❌ [RACE_SYNC] No authenticated user for baseline re-capture');
        return;
      }

      final baseline = _raceBaselines[raceId];
      if (baseline == null) {
        dev.log('⚠️ [RACE_SYNC] No baseline found for race $raceId, cannot re-capture');
        return;
      }

      // Check if already re-captured (idempotency)
      if (baseline.wasRecaptured) {
        dev.log('⏭️ [RACE_SYNC] Baseline already re-captured for "${baseline.raceTitle}", skipping');
        return;
      }

      dev.log('🔧 [RACE_SYNC] Re-capturing baseline for scheduled race: "${baseline.raceTitle}"');
      dev.log('   Original baseline: ${baseline.healthKitStepsAtStart} steps (captured at ${baseline.originalBaselineTime ?? baseline.startTime})');
      dev.log('   Race actual start: ${actualStartTime.toIso8601String()}');

      // Retry mechanism for baseline capture (3 attempts with 2-second delays)
      int maxRetries = 3;
      int retryDelay = 2000; // milliseconds
      int newBaselineSteps = 0;

      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        // Get current pedometer reading
        final currentPedometerSteps = _pedometerService.currentStepCount.value;

        if (currentPedometerSteps > 0) {
          newBaselineSteps = currentPedometerSteps;
          dev.log('   ✅ Captured fresh baseline: $newBaselineSteps steps (attempt $attempt)');
          break;
        } else {
          dev.log('   ⚠️ Pedometer not ready (attempt $attempt/$maxRetries): $currentPedometerSteps steps');
          if (attempt < maxRetries) {
            await Future.delayed(Duration(milliseconds: retryDelay));
          }
        }
      }

      // Validation: Ensure new baseline is valid
      if (newBaselineSteps <= 0) {
        dev.log('   ❌ Failed to capture valid baseline after $maxRetries attempts');
        dev.log('   Keeping original baseline as fallback');
        return;
      }

      // Store original baseline (for debugging/analytics)
      baseline.originalBaselineTime = baseline.startTime;
      baseline.originalBaselineSteps = baseline.healthKitStepsAtStart;

      // Update baseline to fresh reading
      baseline.healthKitStepsAtStart = newBaselineSteps;
      baseline.startTime = actualStartTime; // Update to actual race start time
      baseline.wasRecaptured = true;

      // Reset progress counters (discard pre-race steps)
      baseline.serverSteps = 0;
      baseline.sessionRaceSteps = 0;
      baseline.sessionRaceDistance = 0.0;
      baseline.sessionRaceCalories = 0;
      baseline.maxStepsEverSeen = 0;

      dev.log('   ✅ Baseline re-captured successfully:');
      dev.log('      New baseline: $newBaselineSteps steps');
      dev.log('      Original baseline: ${baseline.originalBaselineSteps} steps (preserved for reference)');
      dev.log('      Progress reset: 0 steps, 0.00 km, 0 cal');
      dev.log('      Pre-race steps discarded (fair play)');

      // Save updated baseline to local storage
      try {
        final prefsService = Get.find<PreferencesService>();
        final baselineData = {
          'raceId': raceId,
          'userId': userId,
          'baselineSteps': newBaselineSteps,
          'baselineDistance': baseline.healthKitDistanceAtStart ?? 0.0,
          'baselineCalories': baseline.healthKitCaloriesAtStart ?? 0,
          'baselineTimestamp': actualStartTime.toIso8601String(),
          'raceStartTime': actualStartTime.toIso8601String(),
          'wasRecaptured': true,
          'originalBaselineSteps': baseline.originalBaselineSteps,
          'originalBaselineTime': baseline.originalBaselineTime?.toIso8601String(),
        };
        await prefsService.saveRaceBaseline(raceId, userId, baselineData);
        dev.log('   💾 Updated baseline saved to local storage');
      } catch (e) {
        dev.log('   ⚠️ Could not save updated baseline to local storage: $e');
      }

      // Also update in Firebase participant document for backup
      try {
        await _firestore
            .collection('races')
            .doc(raceId)
            .collection('participants')
            .doc(userId)
            .set({
          'baselineSteps': newBaselineSteps,
          'baselineRecapturedAt': FieldValue.serverTimestamp(),
          'originalBaselineSteps': baseline.originalBaselineSteps,
          'steps': 0, // Reset progress
          'distance': 0.0,
          'calories': 0,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        dev.log('   ☁️ Updated baseline saved to Firebase');
      } catch (e) {
        dev.log('   ⚠️ Could not update Firebase participant document: $e');
      }

      // Save baseline object to local storage (batched)
      _scheduleBatchSave();

      dev.log('✅ [RACE_SYNC] Baseline re-capture complete for "${baseline.raceTitle}"');
    } catch (e, stackTrace) {
      dev.log('❌ [RACE_SYNC] Error re-capturing baseline for race $raceId: $e');
      dev.log('   Stack trace: $stackTrace');
    }
  }

  /// Remove baseline for completed race
  Future<void> _removeRaceBaseline(String raceId) async {
    try {
      final baseline = _raceBaselines.remove(raceId);
      if (baseline != null) {
        await _saveBaselines();
        dev.log('✅ [RACE_SYNC] Removed baseline for "${baseline.raceTitle}"');
      }
    } catch (e) {
      dev.log('❌ [RACE_SYNC] Error removing baseline for race $raceId: $e');
    }
  }

  /// Recover race baseline from HealthKit historical data
  ///
  /// This method is used when a baseline is missing or corrupted. It queries
  /// HealthKit for steps from the exact race start time to now and recreates
  /// the baseline.
  ///
  /// This is a self-healing mechanism that ensures race progress is never lost.
  Future<bool> recoverRaceBaseline(String raceId, String raceTitle, DateTime raceStartTime) async {
    try {
      dev.log('🔧 [RACE_SYNC] Attempting to recover baseline for race: $raceTitle');
      dev.log('   Race Start Time: ${raceStartTime.toIso8601String()}');

      // Query HealthKit for full race duration
      if (!Get.isRegistered<HealthSyncService>()) {
        dev.log('   ❌ HealthSyncService not available for recovery');
        return false;
      }

      final healthSyncService = Get.find<HealthSyncService>();
      final historicalData = await healthSyncService.getRaceProgressFromStart(raceStartTime);

      if (historicalData == null) {
        dev.log('   ❌ Could not fetch historical data from HealthKit');
        return false;
      }

      final steps = historicalData['steps'] as int;
      final distance = historicalData['distance'] as double;
      final calories = historicalData['calories'] as int;

      dev.log('   ✅ Historical data recovered:');
      dev.log('      Steps: $steps');
      dev.log('      Distance: ${distance.toStringAsFixed(2)} km');
      dev.log('      Calories: $calories');

      // Fetch participant data to get completion status
      final participantData = await _fetchParticipantData(raceId);

      // Create new baseline with recovered data
      final baseline = RaceBaseline(
        raceId: raceId,
        raceTitle: raceTitle,
        startTime: raceStartTime,
        serverSteps: steps,  // Use recovered steps
        serverDistance: distance,  // Use recovered distance
        serverCalories: calories,  // Use recovered calories
        sessionRaceSteps: 0,  // Start fresh session
        sessionRaceDistance: 0.0,
        sessionRaceCalories: 0,
        healthKitBaselineDistance: 0.0,
        healthKitBaselineCalories: 0,
        useTimeBasedBaseline: true,  // Mark as time-based
        healthKitStepsAtStart: 0,  // Unknown original baseline
        healthKitDistanceAtStart: 0.0,
        healthKitCaloriesAtStart: 0,
        isCompleted: participantData.isCompleted,
        completedAt: participantData.completedAt,
      );

      // Save baseline (batched)
      _raceBaselines[raceId] = baseline;
      _scheduleBatchSave();

      dev.log('   ✅ Baseline recovered and scheduled for save');

      // Sync recovered data to server
      try {
        await RaceService.updateParticipantRealTimeData(
          raceId: raceId,
          userId: _auth.currentUser!.uid,
          steps: steps,
          distance: distance,
          calories: calories,
          avgSpeed: 0.0,  // Will be calculated by updateParticipantRealTimeData
        );
        dev.log('   ✅ Recovered data synced to server');
      } catch (e) {
        dev.log('   ⚠️ Could not sync recovered data to server: $e');
      }

      return true;
    } catch (e, stackTrace) {
      dev.log('❌ [RACE_SYNC] Error recovering baseline: $e');
      dev.log('   Stack trace: $stackTrace');
      return false;
    }
  }

  /// Fetch current server participant data for a race (SOURCE OF TRUTH)
  /// This is called on startup and when creating new race baselines
  /// Returns steps, distance, calories, completion status, and completion time
  Future<({int steps, double distance, int calories, bool isCompleted, DateTime? completedAt})> _fetchParticipantData(String raceId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return (steps: 0, distance: 0.0, calories: 0, isCompleted: false, completedAt: null);
      }

      final participantDoc = await _firestore
          .collection('races')
          .doc(raceId)
          .collection('participants')
          .doc(currentUser.uid)
          .get();

      if (participantDoc.exists) {
        final data = participantDoc.data()!;
        final steps = data['steps'] as int? ?? 0;
        final distance = (data['distance'] as num?)?.toDouble() ?? 0.0;
        final calories = data['calories'] as int? ?? 0;
        final isCompleted = data['isCompleted'] as bool? ?? false;
        final completedAt = data['completedAt'] != null
            ? (data['completedAt'] as Timestamp).toDate()
            : null;

        dev.log('📥 [RACE_SYNC] Fetched participant data for race $raceId: $steps steps, ${distance.toStringAsFixed(2)} km, $calories cal, completed=$isCompleted');
        return (steps: steps, distance: distance, calories: calories, isCompleted: isCompleted, completedAt: completedAt);
      } else {
        dev.log('📥 [RACE_SYNC] No participant doc for race $raceId, returning defaults');
        return (steps: 0, distance: 0.0, calories: 0, isCompleted: false, completedAt: null);
      }
    } catch (e) {
      dev.log('❌ [RACE_SYNC] Error fetching participant data for race $raceId: $e');
      return (steps: 0, distance: 0.0, calories: 0, isCompleted: false, completedAt: null);
    }
  }

  /// Refresh server state for all active race baselines
  /// Called on startup to sync with Firestore (source of truth)
  /// ✅ CRITICAL FIX: Now protected by _baselineUpdateLock to prevent race conditions
  Future<void> _refreshServerStateForAllRaces() async {
    await _baselineUpdateLock.synchronized(() async {
      try {
        dev.log('🔄 [RACE_SYNC] Refreshing server state for ${_raceBaselines.length} race(s)... [LOCKED]');

        // ✅ CRITICAL: Get current HealthKit values to reset baseline (prevent double-counting on restart)
        double currentHealthKitDistance = 0.0;
        int currentHealthKitCalories = 0;

        try {
          if (Get.isRegistered<StepTrackingService>()) {
            final stepTrackingService = Get.find<StepTrackingService>();
            currentHealthKitDistance = stepTrackingService.todayDistance.value;
            currentHealthKitCalories = stepTrackingService.todayCalories.value;
            dev.log('📍 [RACE_SYNC] Current HealthKit: ${currentHealthKitDistance.toStringAsFixed(2)} km, $currentHealthKitCalories cal');
          }
        } catch (e) {
          dev.log('⚠️ [RACE_SYNC] Error fetching current HealthKit data: $e');
        }

        for (final entry in _raceBaselines.entries) {
          final raceId = entry.key;
          final baseline = entry.value;

          // ✅ FIX AVGSPEED: Fetch race document to get latest actualStartTime
          // Note: startTime is loaded correctly during baseline creation from server's actualStartTime
          // No need to refresh it here since it's a final field and should not change

          // Fetch fresh participant data including completion status
          final participantData = await _fetchParticipantData(raceId);

          // Update baseline with server state
          baseline.serverSteps = participantData.steps;
          baseline.serverDistance = participantData.distance;  // ✅ NEW: Sync distance
          baseline.serverCalories = participantData.calories;  // ✅ NEW: Sync calories
          baseline.isCompleted = participantData.isCompleted;  // ✅ Sync completion status
          baseline.completedAt = participantData.completedAt;  // ✅ Sync completion time

          // ✅ CRITICAL FIX: Update data integrity tracking
          baseline.maxStepsEverSeen = participantData.steps;  // Server is source of truth
          baseline.lastServerSync = DateTime.now();  // Track when we synced

          // ✅ CRITICAL FIX: Reset HealthKit baseline to current value to prevent double-counting
          // When app restarts, we've already written distance to server, so we need to reset
          // the baseline to current HealthKit value so delta calculation starts fresh
          baseline.healthKitBaselineDistance = currentHealthKitDistance;
          baseline.healthKitBaselineCalories = currentHealthKitCalories;

          dev.log('   ✅ "${baseline.raceTitle}": server=${participantData.steps} steps, ${participantData.distance.toStringAsFixed(2)} km, ${participantData.calories} cal, completed=${participantData.isCompleted}');
          dev.log('      Reset HealthKit baseline to current: ${currentHealthKitDistance.toStringAsFixed(2)} km, $currentHealthKitCalories cal');
          dev.log('      maxStepsEverSeen=${baseline.maxStepsEverSeen}, lastServerSync=${baseline.lastServerSync}');
        }

        // Save updated baselines (batched)
        _scheduleBatchSave();

        dev.log('✅ [RACE_SYNC] Server state refreshed for all races [UNLOCKED]');
      } catch (e) {
        dev.log('❌ [RACE_SYNC] Error refreshing server state: $e');
      }
    });
  }

  /// Save baselines to SharedPreferences (thread-safe)
  Future<void> _saveBaselines() async {
    await _baselineSaveLock.synchronized(() async {
      try {
        if (_prefs == null) return;

        final baselinesJson = _raceBaselines.values
            .map((baseline) => baseline.toJson())
            .toList();

        final jsonString = json.encode(baselinesJson);
        await _prefs!.setString(BASELINES_STORAGE_KEY, jsonString);

        dev.log('💾 [RACE_SYNC] Saved ${_raceBaselines.length} baselines to storage');
      } catch (e) {
        dev.log('❌ [RACE_SYNC] Error saving baselines: $e');
      }
    });
  }

  /// Schedule a batched save to reduce disk I/O
  ///
  /// Instead of saving immediately, this method schedules a save operation
  /// to happen after 5 seconds. If called multiple times within 5 seconds,
  /// only one save will occur.
  ///
  /// This reduces disk writes from ~60/min to ~12/min (80% reduction).
  void _scheduleBatchSave() {
    // Cancel existing timer if any
    _batchSaveTimer?.cancel();

    // Schedule new save in 5 seconds
    _batchSaveTimer = Timer(Duration(seconds: 5), () async {
      await _saveBaselines();
    });
  }

  /// Load baselines from SharedPreferences
  Future<void> _loadBaselines() async {
    try {
      if (_prefs == null) return;

      final jsonString = _prefs!.getString(BASELINES_STORAGE_KEY);
      if (jsonString == null || jsonString.isEmpty) {
        dev.log('ℹ️ [RACE_SYNC] No saved baselines found');
        return;
      }

      final baselinesJson = json.decode(jsonString) as List;
      _raceBaselines = Map.fromEntries(
        baselinesJson.map((json) {
          final baseline = RaceBaseline.fromJson(json as Map<String, dynamic>);
          return MapEntry(baseline.raceId, baseline);
        }),
      );

      dev.log('✅ [RACE_SYNC] Loaded ${_raceBaselines.length} baselines from storage');
      for (final baseline in _raceBaselines.values) {
        dev.log('   - ${baseline.toString()}');
      }
    } catch (e) {
      dev.log('❌ [RACE_SYNC] Error loading baselines: $e');
      _raceBaselines.clear(); // Clear on error
    }
  }

  /// Start sync timer (batched updates every 5 seconds)
  void _startSyncTimer() {
    _syncTimer?.cancel();

    _syncTimer = Timer.periodic(SYNC_INTERVAL, (timer) async {
      await _performSync();
    });

    dev.log('✅ [RACE_SYNC] Sync timer started (${SYNC_INTERVAL.inSeconds}s interval)');
  }

  /// Start race refresh timer (refresh active races every 30 seconds)
  void _startRaceRefreshTimer() {
    _raceRefreshTimer?.cancel();

    _raceRefreshTimer = Timer.periodic(RACE_REFRESH_INTERVAL, (timer) async {
      await _refreshActiveRaces();
    });

    dev.log('✅ [RACE_SYNC] Race refresh timer started (${RACE_REFRESH_INTERVAL.inSeconds}s interval)');
  }


  /// Perform step sync to all active races using delta-based accumulation
  /// This approach maintains a cumulative counter that survives pedometer resets
  Future<void> _performSync() async {
    dev.log('🔄 [RACE_SYNC] _performSync() called, isRunning=${isRunning.value}');
    if (!isRunning.value) {
      dev.log('⚠️ [RACE_SYNC] Service not running, skipping sync');
      return;
    }

    dev.log('🔒 [RACE_SYNC] _performSync acquiring lock...');
    // Protect entire sync operation with lock to prevent concurrent baseline modifications
    await _baselineUpdateLock.synchronized(() async {
      try {
        dev.log('🔓 [RACE_SYNC] _performSync lock acquired, starting sync...');
        final currentUser = _auth.currentUser;
        if (currentUser == null) {
          dev.log('⚠️ [RACE_SYNC] No current user, aborting sync');
          return;
        }

      // ===== STEP 1: Update cumulative counter with delta from pedometer =====
      final currentPedometerReading = _pedometerService.incrementalSteps;
      int stepDelta = currentPedometerReading - _lastPedometerReading;

      // Handle pedometer resets (when StepTrackingService resets session)
      if (stepDelta < 0) {
        // Pedometer was reset - treat current reading as the delta
        dev.log('🔄 [RACE_SYNC] Pedometer reset detected ($_lastPedometerReading → $currentPedometerReading), continuing accumulation');
        stepDelta = currentPedometerReading;
      }

      // Add delta to cumulative counter
      if (stepDelta > 0) {
        _cumulativeSteps += stepDelta;
        dev.log('📊 [RACE_SYNC] Delta: +$stepDelta steps → Cumulative: $_cumulativeSteps steps');
      }

      // Update last reading
      _lastPedometerReading = currentPedometerReading;

      // ===== STEP 2: Check if sync is needed =====
      final cumulativeDelta = (_cumulativeSteps - _lastSyncedSteps).abs();
      if (cumulativeDelta < MIN_STEP_DELTA && _lastSyncedSteps != 0) {
        return; // Not enough change
      }

      // Check if there are active races
      if (_activeRaceIds.isEmpty) {
        return; // No races
      }

      // ===== STEP 3: Sync cumulative steps to all active races =====
      dev.log('🔄 [RACE_SYNC] Syncing to ${_activeRaceIds.length} race(s)...');
      dev.log('📊 [RACE_SYNC] Cumulative steps: $_cumulativeSteps (pedometer: $currentPedometerReading)');

      final raceIdsCopy = _activeRaceIds.toList();
      int updateCount = 0;

      for (final raceId in raceIdsCopy) {
        try {
          var baseline = _raceBaselines[raceId];

          // ✅ CRITICAL FIX: Create baseline on-the-fly if missing
          // This is safe because we're inside _baselineUpdateLock which also protects _refreshActiveRaces()
          // Baseline might be missing if:
          // 1. Race was just created and _refreshActiveRaces() hasn't run yet
          // 2. App crashed between race detection and baseline creation
          if (baseline == null) {
            dev.log('⚠️ [RACE_SYNC] No baseline for race $raceId, creating now...');
            final raceDoc = await _firestore.collection('races').doc(raceId).get();
            final raceTitle = raceDoc.data()?['title'] ?? 'Unknown Race';
            await _setRaceBaseline(raceId, raceTitle);
            baseline = _raceBaselines[raceId];

            // If baseline is still null after creation, skip this race
            if (baseline == null) {
              dev.log('❌ [RACE_SYNC] Failed to create baseline for race $raceId, skipping');
              continue;
            }
          }

          // ✅ SKIP STEP SYNC FOR COMPLETED USERS (view-only mode)
          if (baseline.isCompleted) {
            dev.log('⏭️ [RACE_SYNC] Skipping sync for completed race: "${baseline.raceTitle}"');
            continue;
          }

          // ✅ CRITICAL VALIDATION: Ensure baseline is valid (non-zero) before syncing
          // This prevents step drift when app restarts before baseline is loaded
          if (baseline.useTimeBasedBaseline) {
            final baselineSteps = baseline.healthKitStepsAtStart ?? 0;

            if (baselineSteps == 0) {
              dev.log('⚠️ [RACE_SYNC] INVALID BASELINE DETECTED for race ${baseline.raceTitle}:');
              dev.log('   Baseline steps: $baselineSteps (ZERO - will cause drift!)');
              dev.log('   ⏸️ SKIPPING sync until valid baseline is loaded from local storage or Firebase');
              dev.log('   Race will be synced on next refresh cycle when baseline is available');

              // Force re-load baseline from local storage or Firebase
              dev.log('🔄 [RACE_SYNC] Attempting to reload baseline from storage...');
              await _setRaceBaseline(raceId, baseline.raceTitle);

              // Skip this sync cycle - baseline will be ready next time
              continue;
            }

            dev.log('✅ [RACE_SYNC] Baseline validation passed:');
            dev.log('   Baseline steps: $baselineSteps (VALID)');
          }

          // ✅ TIME-BASED BASELINE LOGIC
          int totalRaceSteps;
          double raceDistance;
          int raceCalories;

          if (baseline.useTimeBasedBaseline) {
            // ✅ PEDOMETER-BASED DELTA CALCULATION: current - baseline
            // Uses pedometer baseline captured at join time (stored locally + Firebase)
            dev.log('📊 [RACE_SYNC] Using pedometer-based delta calculation for race: ${baseline.raceTitle}');

            // Get current pedometer cumulative steps
            final currentPedometerSteps = _pedometerService.currentStepCount.value;

            dev.log('   🚶 Current Pedometer reading:');
            dev.log('      Steps: $currentPedometerSteps');

            // ✅ SIMPLE DELTA FORMULA: delta = current - baseline
            // This gives us steps SINCE user joined the race
            final deltaSteps = currentPedometerSteps - (baseline.healthKitStepsAtStart ?? 0);

            // Check for negative delta (device reboot or pedometer reset)
            if (deltaSteps < 0) {
              dev.log('   ⚠️ Negative delta detected ($deltaSteps) - pedometer reset detected');
              dev.log('   RECALIBRATING baseline to continue tracking...');

              // Calculate new baseline: current_pedometer - already_recorded_progress
              final alreadyRecordedSteps = baseline.serverSteps;
              final newBaseline = currentPedometerSteps - alreadyRecordedSteps;

              if (newBaseline >= 0) {
                dev.log('   🔧 Recalibration:');
                dev.log('      Old baseline: ${baseline.healthKitStepsAtStart} steps');
                dev.log('      Already recorded: $alreadyRecordedSteps steps');
                dev.log('      Current pedometer: $currentPedometerSteps steps');
                dev.log('      New baseline: $newBaseline steps');

                // Update baseline
                baseline.healthKitStepsAtStart = newBaseline;

                // Save updated baseline
                try {
                  final userId = _auth.currentUser?.uid;
                  if (userId != null) {
                    final prefsService = Get.find<PreferencesService>();
                    final baselineData = {
                      'raceId': raceId,
                      'userId': userId,
                      'baselineSteps': newBaseline,
                      'baselineDistance': baseline.healthKitDistanceAtStart ?? 0.0,
                      'baselineCalories': baseline.healthKitCaloriesAtStart ?? 0,
                      'baselineTimestamp': DateTime.now().toIso8601String(),
                      'raceStartTime': baseline.startTime.toIso8601String(),
                    };
                    await prefsService.saveRaceBaseline(raceId, userId, baselineData);
                    dev.log('   ✅ Updated baseline saved to local storage');
                  }
                } catch (e) {
                  dev.log('   ⚠️ Could not save updated baseline: $e');
                }

                // Use server state for THIS cycle (baseline will be used in next cycle)
                totalRaceSteps = baseline.serverSteps;
                raceDistance = baseline.serverDistance;
                raceCalories = baseline.serverCalories;

                dev.log('   ✅ Baseline recalibrated, using server state for this cycle');
              } else {
                dev.log('   ❌ Invalid recalibration (negative baseline: $newBaseline)');
                dev.log('   Using server state as fallback');

                // Use server state (last known good value)
                totalRaceSteps = baseline.serverSteps;
                raceDistance = baseline.serverDistance;
                raceCalories = baseline.serverCalories;
              }
            } else {
              // Calculate distance and calories from pedometer steps using formulas
              const stepsToKm = 0.000762; // 1 step ≈ 0.762 meters
              totalRaceSteps = deltaSteps;
              raceDistance = deltaSteps * stepsToKm;
              raceCalories = (deltaSteps * 0.04).round(); // 1 step ≈ 0.04 cal

              dev.log('   ✅ Pedometer delta calculation:');
              dev.log('      Delta Steps: $deltaSteps → Distance: ${raceDistance.toStringAsFixed(2)} km, Calories: $raceCalories');
            }

            dev.log('   📊 Race progress summary:');
            dev.log('      Baseline (at join): ${baseline.healthKitStepsAtStart} steps');
            dev.log('      Current (pedometer): $currentPedometerSteps steps');
            dev.log('      Delta (race progress): $totalRaceSteps steps, ${raceDistance.toStringAsFixed(2)} km, $raceCalories cal');
          } else {
            // LEGACY: Use pedometer-based dual-layer formula
            dev.log('📊 [RACE_SYNC] Using legacy pedometer-based baseline for race: ${baseline.raceTitle}');

            // Add the step delta to THIS race's session steps
            if (stepDelta > 0) {
              baseline.sessionRaceSteps += stepDelta;
            }

            totalRaceSteps = baseline.serverSteps + baseline.sessionRaceSteps;

            // Safety check (should never be negative with this approach)
            if (totalRaceSteps < 0) {
              dev.log('⚠️ [RACE_SYNC] Negative race steps for $raceId (server: ${baseline.serverSteps}, session: ${baseline.sessionRaceSteps}), skipping');
              continue;
            }

            // Calculate distance and calories using pedometer-based formulas
            const stepsToKm = 0.000762; // 1 step ≈ 0.762 meters
            raceDistance = totalRaceSteps * stepsToKm;
            raceCalories = (totalRaceSteps * 0.04).round(); // 1 step ≈ 0.04 cal

            dev.log('   📊 Legacy calculation (pedometer-only):');
            dev.log('      Server: ${baseline.serverSteps} steps, ${baseline.serverDistance.toStringAsFixed(2)} km, ${baseline.serverCalories} cal');
            dev.log('      Session: ${baseline.sessionRaceSteps} steps');
            dev.log('      Total: $totalRaceSteps steps, ${raceDistance.toStringAsFixed(2)} km, $raceCalories cal');
          }

          // Calculate race time (will be used for avgSpeed later after validation/capping)
          final raceTime = DateTime.now().difference(baseline.startTime);
          final raceSeconds = raceTime.inSeconds;

          // Get race total distance with timeout and null check
          final raceDoc = await _firestore.collection('races').doc(raceId).get()
            .timeout(Duration(seconds: 10), onTimeout: () {
              dev.log('❌ [RACE_SYNC] Timeout fetching race doc for $raceId');
              throw TimeoutException('Race document fetch timeout');
            });

          // ✅ CRITICAL NULL CHECK: Verify race document exists
          if (!raceDoc.exists) {
            dev.log('⚠️ [RACE_SYNC] Race $raceId no longer exists, removing baseline');
            await _removeRaceBaseline(raceId);
            continue; // Skip to next race
          }

          final totalDistance = (raceDoc.data()?['totalDistance'] as num?)?.toDouble() ?? 0.0;

          // ✅ CRITICAL VALIDATION: Verify race has valid distance
          if (totalDistance <= 0) {
            dev.log('❌ [RACE_SYNC] Invalid race distance: $totalDistance km for race $raceId');
            continue; // Skip invalid race
          }

          var cappedRaceDistance = raceDistance;
          var cappedTotalRaceSteps = totalRaceSteps;

          // ✅ VALIDATION: Check for anomalies before writing to Firebase
          final validationResults = RaceValidationUtils.validateAll(
            previousSteps: baseline.serverSteps,
            newSteps: totalRaceSteps,
            timeSinceLastSync: raceTime,
            participantDistance: raceDistance,
            raceTotalDistance: totalDistance,
            raceTitle: baseline.raceTitle,
          );

          // ✅ CRITICAL FIX: If validation errors found, CAP the values
          if (RaceValidationUtils.hasErrors(validationResults)) {
            dev.log('❌ [RACE_SYNC] VALIDATION ERRORS detected for "${baseline.raceTitle}"');
            for (final error in RaceValidationUtils.getErrorMessages(validationResults)) {
              dev.log('   $error');
            }

            // Cap distance at 110% of race total (allow small overshoot for GPS drift)
            if (raceDistance > totalDistance * 1.1) {
              cappedRaceDistance = totalDistance * 1.1;
              dev.log('⚠️ [RACE_SYNC] Capped distance: ${raceDistance.toStringAsFixed(2)}km → ${cappedRaceDistance.toStringAsFixed(2)}km');
            }

            // Recalculate steps based on capped distance
            if (cappedRaceDistance != raceDistance) {
              cappedTotalRaceSteps = (cappedRaceDistance / STEPS_TO_KM_FACTOR).round();
              dev.log('⚠️ [RACE_SYNC] Recalculated steps: $totalRaceSteps → $cappedTotalRaceSteps');
            }

            // Cap step delta if unrealistically high
            final stepDelta = cappedTotalRaceSteps - baseline.serverSteps;
            if (stepDelta > 20000) {
              cappedTotalRaceSteps = baseline.serverSteps + 20000;
              cappedRaceDistance = cappedTotalRaceSteps * STEPS_TO_KM_FACTOR;
              dev.log('⚠️ [RACE_SYNC] Capped step delta: $stepDelta → 20000 steps');
            }
          }

          // Use capped values for remaining calculations
          final remainingDistance = (totalDistance - cappedRaceDistance).clamp(0.0, totalDistance);
          final cappedCalories = (cappedTotalRaceSteps * STEPS_TO_CALORIES_FACTOR).round();

          // Calculate capped avgSpeed using seconds for precision
          double cappedAvgSpeed = 0.0;
          if (raceSeconds > 0) {
            final raceHours = raceSeconds / 3600.0;
            cappedAvgSpeed = cappedRaceDistance / raceHours;

            dev.log('   📊 AvgSpeed Calculation:');
            dev.log('      Distance: ${cappedRaceDistance.toStringAsFixed(2)} km');
            dev.log('      Time: ${raceSeconds}s (${raceHours.toStringAsFixed(2)} hours)');
            dev.log('      Speed: ${cappedAvgSpeed.toStringAsFixed(2)} km/h');
          } else {
            dev.log('   ⚠️ AvgSpeed = 0: raceSeconds = $raceSeconds (cannot calculate)');
          }

          // ✅ CRITICAL FIX: Monotonic increasing validation
          // DETECT writes that would decrease steps and recalibrate baseline instead of rejecting
          if (cappedTotalRaceSteps < baseline.maxStepsEverSeen) {
            dev.log('⚠️ [RACE_SYNC] Detected attempt to decrease steps from ${baseline.maxStepsEverSeen} to $cappedTotalRaceSteps');
            dev.log('   This likely indicates a pedometer reset - recalibrating baseline...');

            // Calculate new baseline: current_pedometer - already_recorded_progress
            // This allows new steps to accumulate from the current position
            final alreadyRecordedSteps = baseline.maxStepsEverSeen;
            final currentPedometerReading = _pedometerService.currentStepCount.value;
            final newBaseline = currentPedometerReading - alreadyRecordedSteps;

            if (newBaseline > 0) {
              dev.log('🔧 [RACE_SYNC] RECALIBRATING baseline for "${baseline.raceTitle}":');
              dev.log('   Old baseline: ${baseline.healthKitStepsAtStart} steps');
              dev.log('   Already recorded progress: $alreadyRecordedSteps steps');
              dev.log('   Current pedometer: $currentPedometerReading steps');
              dev.log('   New baseline: $newBaseline steps');
              dev.log('   Formula: new_baseline = current_pedometer - already_recorded_progress');
              dev.log('   Result: $newBaseline = $currentPedometerReading - $alreadyRecordedSteps');

              // Update baseline
              baseline.healthKitStepsAtStart = newBaseline;

              // Save the updated baseline to local storage
              try {
                final userId = _auth.currentUser?.uid;
                if (userId != null) {
                  final prefsService = Get.find<PreferencesService>();
                  final baselineData = {
                    'raceId': raceId,
                    'userId': userId,
                    'baselineSteps': newBaseline,
                    'baselineDistance': baseline.healthKitDistanceAtStart ?? 0.0,
                    'baselineCalories': baseline.healthKitCaloriesAtStart ?? 0,
                    'baselineTimestamp': DateTime.now().toIso8601String(),
                    'raceStartTime': baseline.startTime.toIso8601String(),
                  };
                  await prefsService.saveRaceBaseline(raceId, userId, baselineData);
                  dev.log('✅ [RACE_SYNC] Updated baseline saved to local storage');
                }
              } catch (e) {
                dev.log('⚠️ [RACE_SYNC] Could not save updated baseline: $e');
              }

              // Recalculate with new baseline
              final newDeltaSteps = currentPedometerReading - newBaseline;
              totalRaceSteps = newDeltaSteps;
              raceDistance = newDeltaSteps * STEPS_TO_KM_FACTOR;
              raceCalories = (newDeltaSteps * STEPS_TO_CALORIES_FACTOR).round();

              // Update capped values
              cappedTotalRaceSteps = totalRaceSteps;
              cappedRaceDistance = raceDistance;

              // Revalidate with new values
              final revalidationResults = RaceValidationUtils.validateAll(
                previousSteps: baseline.serverSteps,
                newSteps: totalRaceSteps,
                timeSinceLastSync: raceTime,
                participantDistance: raceDistance,
                raceTotalDistance: totalDistance,
                raceTitle: baseline.raceTitle,
              );

              if (RaceValidationUtils.hasErrors(revalidationResults)) {
                dev.log('⚠️ [RACE_SYNC] Validation errors after recalibration, applying caps...');
                // Apply same capping logic as before
                if (raceDistance > totalDistance * 1.1) {
                  cappedRaceDistance = totalDistance * 1.1;
                  cappedTotalRaceSteps = (cappedRaceDistance / STEPS_TO_KM_FACTOR).round();
                }
              }

              dev.log('✅ [RACE_SYNC] Baseline recalibrated successfully, continuing with sync...');
              dev.log('   New race progress: $cappedTotalRaceSteps steps, ${cappedRaceDistance.toStringAsFixed(2)} km');

              // Continue with the sync using recalculated values
              // (fall through to the write logic below)
            } else {
              dev.log('❌ [RACE_SYNC] Invalid recalibration (negative baseline), skipping this cycle');
              continue;  // Skip this race if recalibration produces invalid baseline
            }
          }

          // ✅ CRITICAL FIX: Check if server has newer data (timestamp validation)
          // If server was updated recently by another device, skip this sync to avoid overwriting fresh data
          if (baseline.lastServerSync != null) {
            final timeSinceServerSync = DateTime.now().difference(baseline.lastServerSync!);

            // If we haven't synced from server in last 10 seconds, check if server has newer data
            if (timeSinceServerSync.inSeconds > 10) {
              dev.log('⚠️ [RACE_SYNC] Last server sync was ${timeSinceServerSync.inSeconds}s ago, checking for newer data...');

              try {
                final participantDoc = await _firestore
                    .collection('races')
                    .doc(raceId)
                    .collection('participants')
                    .doc(currentUser.uid)
                    .get()
                    .timeout(Duration(seconds: 5));

                if (participantDoc.exists) {
                  final serverSteps = participantDoc.data()?['steps'] as int? ?? 0;

                  // If server has MORE steps than we're about to write, update our baseline
                  if (serverSteps > cappedTotalRaceSteps) {
                    dev.log('🔄 [RACE_SYNC] Server has newer data: $serverSteps steps > our $cappedTotalRaceSteps steps');
                    dev.log('   Updating baseline to server value and skipping this sync cycle');

                    baseline.serverSteps = serverSteps;
                    baseline.sessionRaceSteps = 0;  // Reset session
                    baseline.maxStepsEverSeen = serverSteps;
                    baseline.lastServerSync = DateTime.now();
                    await _saveBaselines();

                    continue;  // Skip this sync cycle, server is ahead
                  }
                }
              } catch (e) {
                dev.log('⚠️ [RACE_SYNC] Error checking server data: $e (continuing with write)');
                // Continue with write if check fails
              }
            }
          }

          // Update maxStepsEverSeen before writing
          baseline.maxStepsEverSeen = cappedTotalRaceSteps;

          // Write to Firebase
          final participantRef = _firestore
              .collection('races')
              .doc(raceId)
              .collection('participants')
              .doc(currentUser.uid);

          dev.log('🔥 [RACE_SYNC] Updating race progress via RaceService: "${baseline.raceTitle}" = $cappedTotalRaceSteps steps');

          // ✅ Use RaceService.updateParticipantRealTimeData to properly trigger completion logic
          // This ensures state machine transitions, celebration dialogs, and countdown timers work correctly
          try {
            await RaceService.updateParticipantRealTimeData(
              raceId: raceId,
              userId: currentUser.uid,
              distance: cappedRaceDistance,
              steps: cappedTotalRaceSteps,
              calories: cappedCalories,
              avgSpeed: cappedAvgSpeed,
              isCompleted: false,  // Let RaceService._checkRaceCompletion determine this
            );

            dev.log('✅ [RACE_SYNC] Race progress updated successfully for "${baseline.raceTitle}"');

            // ✅ Check if user completed during this update
            // Re-fetch participant data to see if completion was triggered
            final participantDoc = await _firestore
                .collection('races')
                .doc(raceId)
                .collection('participants')
                .doc(currentUser.uid)
                .get();

            if (participantDoc.exists) {
              final wasNotCompleted = !baseline.isCompleted;
              final isNowCompleted = participantDoc.data()?['isCompleted'] as bool? ?? false;

              if (wasNotCompleted && isNowCompleted) {
                // User just completed! Update baseline
                baseline.isCompleted = true;
                baseline.completedAt = participantDoc.data()?['completedAt'] != null
                    ? (participantDoc.data()?['completedAt'] as Timestamp).toDate()
                    : DateTime.now();

                dev.log('🏁 [RACE_SYNC] Baseline marked as completed for "${baseline.raceTitle}"');
              }
            }
          } catch (e) {
            dev.log('❌ [RACE_SYNC] Error updating race progress via RaceService: $e');
            // Fallback to direct Firebase write if RaceService call fails
            dev.log('⚠️ [RACE_SYNC] Falling back to direct Firebase write');

            await participantRef.set({
              'steps': cappedTotalRaceSteps,
              'distance': cappedRaceDistance,
              'remainingDistance': remainingDistance,
              'calories': cappedCalories,
              'avgSpeed': cappedAvgSpeed,
              'lastUpdated': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)).timeout(Duration(seconds: 10), onTimeout: () {
              dev.log('❌ [RACE_SYNC] Timeout writing race data for $raceId');
              throw TimeoutException('Firebase write timeout');
            });

            dev.log('✅ [RACE_SYNC] Fallback Firebase write complete');
          }

          // ✅ CRITICAL: Update server state and reset session counter
          // After syncing to server:
          // 1. Update serverSteps with the capped total
          // 2. Reset sessionRaceSteps to 0 (those steps are now in serverSteps)
          baseline.serverSteps = cappedTotalRaceSteps;
          baseline.sessionRaceSteps = 0;

          updateCount++;
          dev.log('   ✅ "${baseline.raceTitle}": $cappedTotalRaceSteps steps → ${cappedRaceDistance.toStringAsFixed(3)}km (${remainingDistance.toStringAsFixed(3)}km remaining)');
        } catch (e) {
          dev.log('⚠️ [RACE_SYNC] Error syncing race $raceId: $e');
        }
      }

      // ===== STEP 4: Update sync state =====
      if (updateCount > 0) {
        _lastSyncedSteps = _cumulativeSteps;
        totalSyncCount.value++;
        lastSyncTime.value = _formatTime(DateTime.now());
        hasError.value = false;

        dev.log('✅ [RACE_SYNC] Synced to $updateCount race(s) successfully');
      }
      } catch (e, stackTrace) {
        dev.log('❌ [RACE_SYNC] Sync error: $e');
        dev.log('📍 [RACE_SYNC] Stack trace: $stackTrace');
        hasError.value = true;
        errorMessage.value = e.toString();
      }
    });
  }

  /// Format time for display
  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  /// Add health-synced steps to all active races
  /// This is called when health data is synced (e.g., HealthKit/Health Connect manual sync)
  /// to ensure race progress includes health-synced steps, not just pedometer steps
  /// Add health-synced steps to active races
  /// Uses lock to prevent race conditions with baseline updates
  Future<void> addHealthSyncSteps(int stepsDelta) async {
    try {
      if (stepsDelta <= 0) {
        dev.log('📊 [RACE_SYNC] No health sync steps to add (delta: $stepsDelta)');
        return;
      }

      if (!isRunning.value) {
        // Queue the steps to be applied when service starts
        _pendingHealthKitSteps += stepsDelta;
        dev.log('⏳ [RACE_SYNC] Service not running yet, queuing $stepsDelta HealthKit steps (total pending: $_pendingHealthKitSteps)');
        return;
      }

      if (_activeRaceIds.isEmpty) {
        dev.log('ℹ️ [RACE_SYNC] No active races, skipping health sync steps');
        return;
      }

      dev.log('🏥 [RACE_SYNC] Adding $stepsDelta health-synced steps to ${_activeRaceIds.length} active race(s)...');
      dev.log('   Current cumulative steps: $_cumulativeSteps');

      // Modify baselines inside lock
      await _baselineUpdateLock.synchronized(() async {
        dev.log('   🔒 [RACE_SYNC] Acquired lock, modifying baselines...');

        // Add the health sync delta to cumulative counter
        _cumulativeSteps += stepsDelta;
        dev.log('   📊 [RACE_SYNC] Updated cumulative: $_cumulativeSteps (+$stepsDelta)');

        // Add the delta to each race's session steps
        for (final raceId in _activeRaceIds) {
          final baseline = _raceBaselines[raceId];
          if (baseline != null) {
            final before = baseline.sessionRaceSteps;
            baseline.sessionRaceSteps += stepsDelta;
            dev.log('   ✅ "${baseline.raceTitle}": session steps $before → ${baseline.sessionRaceSteps} (+$stepsDelta)');
          }
        }

        // Save updated baselines (batched)
        _scheduleBatchSave();
        dev.log('   🔓 [RACE_SYNC] Releasing lock, baselines scheduled for save');
      });

      dev.log('🔥 [RACE_SYNC] Triggering immediate Firebase sync (OUTSIDE lock)...');

      // Trigger immediate sync to Firebase OUTSIDE the lock to prevent deadlock
      await _performSync();

      dev.log('✅ [RACE_SYNC] Health sync complete: steps added and synced to Firebase');
    } catch (e, stackTrace) {
      dev.log('❌ [RACE_SYNC] Error adding health sync steps: $e');
      dev.log('📍 [RACE_SYNC] Stack trace: $stackTrace');
    }
  }

  /// Add health-synced steps to active races (IDEMPOTENT VERSION with request ID deduplication)
  ///
  /// This is the NEW method that should be called by HealthSyncCoordinator.
  /// It prevents duplicate step propagation through request ID tracking.
  ///
  /// Parameters:
  /// - [stepsDelta]: Number of steps to add
  /// - [requestId]: Unique request identifier (prevents duplicate processing)
  /// - [source]: Source identifier for logging (e.g., "HealthKitBaseline", "ManualHealthSync")
  Future<void> addHealthSyncStepsIdempotent({
    required int stepsDelta,
    required String requestId,
    required String source,
    double distanceDelta = 0.0,  // ✅ NEW: Distance delta (km)
    int caloriesDelta = 0,       // ✅ NEW: Calories delta
  }) async {
    try {
      // 1. Check if already processed (idempotency)
      if (_processedRequests.contains(requestId)) {
        dev.log('⏭️ [RACE_SYNC] Skipping duplicate request: $requestId (source: $source)');
        return;
      }

      // 2. Validate steps delta
      if (stepsDelta <= 0) {
        dev.log('⚠️ [RACE_SYNC] Invalid steps delta: $stepsDelta (requestId: $requestId)');
        return;
      }

      if (stepsDelta > 20000) {
        dev.log('❌ [RACE_SYNC] ANOMALY: Step delta too large: $stepsDelta (requestId: $requestId, source: $source)');
        dev.log('   This will be capped at 20,000 steps to prevent abuse.');
        stepsDelta = 20000;
      }

      dev.log('🏥 [RACE_SYNC] Processing health sync request:');
      dev.log('   Request ID: $requestId');
      dev.log('   Source: $source');
      dev.log('   Steps delta: $stepsDelta');
      dev.log('   Distance delta: ${distanceDelta.toStringAsFixed(2)} km');
      dev.log('   Calories delta: $caloriesDelta');

      // 3. Check if service is running
      if (!isRunning.value) {
        // Queue the steps to be applied when service starts
        _pendingHealthKitSteps += stepsDelta;
        _processedRequests.add(requestId); // Mark as processed
        dev.log('⏳ [RACE_SYNC] Service not running yet, queuing $stepsDelta steps (total pending: $_pendingHealthKitSteps)');
        return;
      }

      // 4. Check if there are active races
      if (_activeRaceIds.isEmpty) {
        // Queue the steps instead of discarding - race might become active soon
        _pendingHealthKitSteps += stepsDelta;
        _processedRequests.add(requestId); // Mark as processed
        dev.log('ℹ️ [RACE_SYNC] No active races yet, queuing $stepsDelta steps (total pending: $_pendingHealthKitSteps)');
        return;
      }

      // 5. Apply steps to races
      dev.log('🏥 [RACE_SYNC] Adding $stepsDelta health-synced steps to ${_activeRaceIds.length} active race(s)...');

      // Modify baselines inside lock
      await _baselineUpdateLock.synchronized(() async {
        dev.log('   🔒 [RACE_SYNC] Acquired lock, modifying baselines...');

        // Add the health sync delta to cumulative counter
        _cumulativeSteps += stepsDelta;
        dev.log('   📊 [RACE_SYNC] Updated cumulative: $_cumulativeSteps (+$stepsDelta)');

        // ✅ Get current HealthKit values to update baseline (prevent double-counting)
        double currentHealthKitDistance = 0.0;
        int currentHealthKitCalories = 0;

        try {
          if (Get.isRegistered<StepTrackingService>()) {
            final stepTrackingService = Get.find<StepTrackingService>();
            currentHealthKitDistance = stepTrackingService.todayDistance.value;
            currentHealthKitCalories = stepTrackingService.todayCalories.value;
          }
        } catch (e) {
          dev.log('⚠️ [RACE_SYNC] Error fetching HealthKit data: $e');
        }

        // Add the delta to each race's session steps, distance, and calories
        for (final raceId in _activeRaceIds) {
          final baseline = _raceBaselines[raceId];
          if (baseline != null) {
            final beforeSteps = baseline.sessionRaceSteps;
            final beforeDistance = baseline.sessionRaceDistance;
            final beforeCalories = baseline.sessionRaceCalories;

            baseline.sessionRaceSteps += stepsDelta;
            baseline.sessionRaceDistance += distanceDelta;  // ✅ NEW: Add distance delta
            baseline.sessionRaceCalories += caloriesDelta;  // ✅ NEW: Add calories delta

            // ✅ CRITICAL FIX: Update HealthKit baseline to prevent double-counting
            // When health sync adds distance, we must update the baseline so the delta in _performSync() becomes 0
            baseline.healthKitBaselineDistance = currentHealthKitDistance;
            baseline.healthKitBaselineCalories = currentHealthKitCalories;

            dev.log('   ✅ "${baseline.raceTitle}": session updated:');
            dev.log('      Steps: $beforeSteps → ${baseline.sessionRaceSteps} (+$stepsDelta)');
            dev.log('      Distance: ${beforeDistance.toStringAsFixed(2)} → ${baseline.sessionRaceDistance.toStringAsFixed(2)} km (+${distanceDelta.toStringAsFixed(2)})');
            dev.log('      Calories: $beforeCalories → ${baseline.sessionRaceCalories} (+$caloriesDelta)');
            dev.log('      Updated HealthKit baseline to: ${currentHealthKitDistance.toStringAsFixed(2)} km, $currentHealthKitCalories cal');
          }
        }

        // Save updated baselines (batched)
        _scheduleBatchSave();
        dev.log('   🔓 [RACE_SYNC] Releasing lock, baselines scheduled for save');
      });

      // 6. Mark request as processed
      _processedRequests.add(requestId);

      // Clean up old request IDs (keep last 50)
      if (_processedRequests.length > 50) {
        dev.log('🧹 [RACE_SYNC] Cleaning up old request IDs (count: ${_processedRequests.length})');
        _processedRequests.clear();
      }

      dev.log('🔥 [RACE_SYNC] Triggering immediate Firebase sync (OUTSIDE lock)...');

      // Trigger immediate sync to Firebase OUTSIDE the lock
      await _performSync();

      dev.log('✅ [RACE_SYNC] Health sync complete: steps added and synced to Firebase (requestId: $requestId)');
    } catch (e, stackTrace) {
      dev.log('❌ [RACE_SYNC] Error adding health sync steps (requestId: $requestId): $e');
      dev.log('📍 [RACE_SYNC] Stack trace: $stackTrace');
    }
  }

  @override
  void onClose() {
    _batchSaveTimer?.cancel(); // Cancel batch save timer
    _saveBaselines(); // Save immediately before closing
    stopSyncing();
    super.onClose();
  }
}
