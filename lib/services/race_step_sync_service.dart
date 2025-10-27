import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';
import 'pedometer_service.dart';

/// Race Baseline - Dual-layer tracking for robust race step synchronization
///
/// This model uses a two-layer approach:
/// 1. **Server State** (persistent): Last known steps on Firestore (source of truth)
/// 2. **Session Steps** (volatile): Steps accumulated in this race during current app session
///
/// Formula: totalRaceSteps = serverSteps + sessionRaceSteps
///
/// This ensures:
/// - Races survive app restarts (server state persists)
/// - Real-time tracking within session (session steps accumulate)
/// - Multi-day races work correctly
/// - Independent tracking for multiple simultaneous races
/// - Survives pedometer resets (session steps track independently)
class RaceBaseline {
  final String raceId;
  final String raceTitle;
  final DateTime startTime;              // When race originally started

  // Persistent state (survives app restarts)
  int serverSteps;                       // Last known steps on server (SOURCE OF TRUTH)

  // Session state (resets on app restart, accumulates during session)
  int sessionRaceSteps;                  // Steps walked in THIS RACE during current session

  RaceBaseline({
    required this.raceId,
    required this.raceTitle,
    required this.startTime,
    required this.serverSteps,
    required this.sessionRaceSteps,
  });

  // JSON serialization for persistence
  Map<String, dynamic> toJson() {
    return {
      'raceId': raceId,
      'raceTitle': raceTitle,
      'startTime': startTime.toIso8601String(),
      'serverSteps': serverSteps,
      'sessionRaceSteps': sessionRaceSteps,
    };
  }

  factory RaceBaseline.fromJson(Map<String, dynamic> json) {
    return RaceBaseline(
      raceId: json['raceId'] as String,
      raceTitle: json['raceTitle'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      // Load server steps from storage, will be refreshed from Firestore on startup
      serverSteps: json['serverSteps'] as int? ?? 0,
      // Session race steps always start at 0 after app restart
      sessionRaceSteps: 0,
    );
  }

  @override
  String toString() {
    return 'RaceBaseline(race: $raceTitle, server: $serverSteps steps, session: +$sessionRaceSteps, started: $startTime)';
  }
}

/// Race Step Sync Service (SIMPLIFIED)
///
/// Syncs pedometer incremental steps to active races in real-time
/// Uses ONLY pedometer data - no HealthKit dependency for race tracking
///
/// Features:
/// - Per-race baseline tracking using pedometer incremental steps
/// - Persists baselines across app restarts via SharedPreferences
/// - Auto-detects user's active races (statusId 3 or 6)
/// - Syncs race-specific step deltas every 5 seconds
/// - Handles multiple simultaneous races
/// - Simple and reliable - no HealthKit conflicts
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
  bool _isInitialized = false;

  // ================== CUMULATIVE STEP TRACKING ==================
  // These fields maintain a cumulative counter independent of pedometer resets
  int _lastPedometerReading = 0;  // Last pedometer incremental reading
  int _cumulativeSteps = 0;        // Cumulative steps for current session (survives pedometer resets)

  // ================== CONCURRENCY CONTROL ==================
  /// Lock for baseline updates to prevent race conditions
  final Lock _baselineUpdateLock = Lock();

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
          newActiveRaceIds.add(raceId);
          raceTitles[raceId] = raceDoc.data()?['title'] as String? ?? 'Unknown Race';
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
  }

  /// Set baseline for a race using dual-layer tracking
  /// Fetches current server state and starts session tracking
  Future<void> _setRaceBaseline(String raceId, String raceTitle) async {
    try {
      // Fetch current server steps (source of truth)
      final serverSteps = await _fetchServerSteps(raceId);

      // Create baseline with dual-layer tracking
      final baseline = RaceBaseline(
        raceId: raceId,
        raceTitle: raceTitle,
        startTime: DateTime.now(),
        serverSteps: serverSteps,              // Server state (persistent)
        sessionRaceSteps: 0,                   // Start counting from 0 in this session
      );

      _raceBaselines[raceId] = baseline;
      await _saveBaselines();

      dev.log('✅ [RACE_SYNC] Set baseline for "$raceTitle": server=$serverSteps, sessionSteps=0');
    } catch (e) {
      dev.log('❌ [RACE_SYNC] Error setting baseline for race $raceId: $e');
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

  /// Fetch current server steps for a race (SOURCE OF TRUTH)
  /// This is called on startup and when creating new race baselines
  Future<int> _fetchServerSteps(String raceId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return 0;

      final participantDoc = await _firestore
          .collection('races')
          .doc(raceId)
          .collection('participants')
          .doc(currentUser.uid)
          .get();

      if (participantDoc.exists) {
        final steps = participantDoc.data()?['steps'] as int? ?? 0;
        dev.log('📥 [RACE_SYNC] Fetched server steps for race $raceId: $steps');
        return steps;
      } else {
        dev.log('📥 [RACE_SYNC] No participant doc for race $raceId, server steps: 0');
        return 0;
      }
    } catch (e) {
      dev.log('❌ [RACE_SYNC] Error fetching server steps for race $raceId: $e');
      return 0;
    }
  }

  /// Refresh server state for all active race baselines
  /// Called on startup to sync with Firestore (source of truth)
  Future<void> _refreshServerStateForAllRaces() async {
    try {
      dev.log('🔄 [RACE_SYNC] Refreshing server state for ${_raceBaselines.length} race(s)...');

      for (final entry in _raceBaselines.entries) {
        final raceId = entry.key;
        final baseline = entry.value;

        // Fetch fresh server steps
        final serverSteps = await _fetchServerSteps(raceId);

        // Update baseline with server state
        baseline.serverSteps = serverSteps;

        dev.log('   ✅ "${baseline.raceTitle}": server=$serverSteps steps');
      }

      // Save updated baselines
      await _saveBaselines();

      dev.log('✅ [RACE_SYNC] Server state refreshed for all races');
    } catch (e) {
      dev.log('❌ [RACE_SYNC] Error refreshing server state: $e');
    }
  }

  /// Save baselines to SharedPreferences
  Future<void> _saveBaselines() async {
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
    if (!isRunning.value) return;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

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

          // Create baseline on-the-fly if missing (fixes new race bug)
          if (baseline == null) {
            dev.log('⚠️ [RACE_SYNC] No baseline for race $raceId, creating now...');
            final raceDoc = await _firestore.collection('races').doc(raceId).get();
            final raceTitle = raceDoc.data()?['title'] ?? 'Unknown Race';
            await _setRaceBaseline(raceId, raceTitle);
            baseline = _raceBaselines[raceId]!;
          }

          // Calculate race steps using SIMPLIFIED DUAL-LAYER FORMULA:
          // totalRaceSteps = serverSteps + sessionRaceSteps
          //
          // Instead of tracking sessionStart and calculating delta, we directly track
          // how many steps were walked in THIS RACE during this session.
          // This survives pedometer resets because we increment sessionRaceSteps
          // independently based on step deltas.

          // Add the step delta to THIS race's session steps
          if (stepDelta > 0) {
            baseline.sessionRaceSteps += stepDelta;
          }

          final totalRaceSteps = baseline.serverSteps + baseline.sessionRaceSteps;

          // Safety check (should never be negative with this approach)
          if (totalRaceSteps < 0) {
            dev.log('⚠️ [RACE_SYNC] Negative race steps for $raceId (server: ${baseline.serverSteps}, session: ${baseline.sessionRaceSteps}), skipping');
            continue;
          }

          // ✅ DEBUG: Log detailed step calculation breakdown
          dev.log('   📊 Race: ${baseline.raceTitle}');
          dev.log('      Server steps: ${baseline.serverSteps}');
          dev.log('      Session steps: ${baseline.sessionRaceSteps}');
          dev.log('      Step delta this cycle: +$stepDelta');
          dev.log('      Total race steps: $totalRaceSteps');

          final raceDistance = totalRaceSteps * STEPS_TO_KM_FACTOR;
          final raceCalories = (totalRaceSteps * STEPS_TO_CALORIES_FACTOR).round();

          // Calculate average speed
          final raceTime = DateTime.now().difference(baseline.startTime);
          final raceMinutes = raceTime.inMinutes;
          final avgSpeed = raceMinutes > 0 ? (raceDistance / raceMinutes) * 60 : 0.0;

          // Get race total distance
          final raceDoc = await _firestore.collection('races').doc(raceId).get();
          final totalDistance = (raceDoc.data()?['totalDistance'] as num?)?.toDouble() ?? 0.0;
          final remainingDistance = (totalDistance - raceDistance).clamp(0.0, totalDistance);

          // Write to Firebase
          final participantRef = _firestore
              .collection('races')
              .doc(raceId)
              .collection('participants')
              .doc(currentUser.uid);

          await participantRef.set({
            'steps': totalRaceSteps,
            'distance': raceDistance,
            'remainingDistance': remainingDistance,
            'calories': raceCalories,
            'avgSpeed': avgSpeed,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // ✅ CRITICAL: Update server state and reset session counter
          // After syncing to server:
          // 1. Update serverSteps with the total
          // 2. Reset sessionRaceSteps to 0 (those steps are now in serverSteps)
          baseline.serverSteps = totalRaceSteps;
          baseline.sessionRaceSteps = 0;

          updateCount++;
          dev.log('   ✅ "${baseline.raceTitle}": $totalRaceSteps steps → ${raceDistance.toStringAsFixed(3)}km (${remainingDistance.toStringAsFixed(3)}km remaining)');
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
    await _baselineUpdateLock.synchronized(() async {
      try {
        if (stepsDelta <= 0) {
          dev.log('📊 [RACE_SYNC] No health sync steps to add (delta: $stepsDelta)');
          return;
        }

        if (!isRunning.value) {
          dev.log('⚠️ [RACE_SYNC] Service not running, cannot add health sync steps');
          return;
        }

        if (_activeRaceIds.isEmpty) {
          dev.log('ℹ️ [RACE_SYNC] No active races, skipping health sync steps');
          return;
        }

        dev.log('🏥 [RACE_SYNC] Adding $stepsDelta health-synced steps to ${_activeRaceIds.length} active race(s)...');

        // Add the health sync delta to cumulative counter
        _cumulativeSteps += stepsDelta;

        // Add the delta to each race's session steps
        for (final raceId in _activeRaceIds) {
          final baseline = _raceBaselines[raceId];
          if (baseline != null) {
            baseline.sessionRaceSteps += stepsDelta;
            dev.log('   ✅ "${baseline.raceTitle}": +$stepsDelta steps from health sync');
          }
        }

        // Save updated baselines
        await _saveBaselines();

        // Trigger immediate sync to Firebase
        await _performSync();

        dev.log('✅ [RACE_SYNC] Health sync steps added to all active races');
      } catch (e, stackTrace) {
        dev.log('❌ [RACE_SYNC] Error adding health sync steps: $e');
        dev.log('📍 [RACE_SYNC] Stack trace: $stackTrace');
      }
    });
  }

  /// Get diagnostics for debugging
  Map<String, dynamic> getDiagnostics() {
    return {
      'isRunning': isRunning.value,
      'isInitialized': _isInitialized,
      'activeRaceCount': activeRaceCount.value,
      'activeRaceIds': _activeRaceIds.toList(),
      'raceBaselines': _raceBaselines.map((key, value) => MapEntry(key, value.toJson())),
      'totalSyncCount': totalSyncCount.value,
      'lastSyncTime': lastSyncTime.value,
      'lastSyncedSteps': _lastSyncedSteps,
      'currentPedometerSteps': _pedometerService.incrementalSteps,
      'lastPedometerReading': _lastPedometerReading,
      'cumulativeSteps': _cumulativeSteps,
      'hasError': hasError.value,
      'errorMessage': errorMessage.value,
    };
  }

  @override
  void onClose() {
    _saveBaselines(); // Save before closing
    stopSyncing();
    super.onClose();
  }
}
