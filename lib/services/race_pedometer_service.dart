import 'dart:async';
import 'package:get/get.dart';
import 'package:synchronized/synchronized.dart';
import 'pedometer_service.dart';
import '../database/step_database.dart';
import '../utils/step_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Dedicated service for race step tracking using pedometer
/// Provides realtime step updates and gap filling for races
class RacePedometerService extends GetxService {
  final PedometerService _pedometerService = Get.find<PedometerService>();
  final _stepDatabase = StepDatabase.instance;

  // Race baselines - maps raceId to baseline data
  final Map<String, RacePedometerBaseline> _raceBaselines = {};

  // Concurrency control
  final Lock _raceLock = Lock();

  // Observables for UI updates
  final RxMap<String, int> raceSteps = <String, int>{}.obs;
  final RxMap<String, double> raceDistances = <String, double>{}.obs;
  final RxMap<String, int> raceCalories = <String, int>{}.obs;
  final RxMap<String, double> raceSpeeds = <String, double>{}.obs;

  // Pedometer subscription
  StreamSubscription? _pedometerSubscription;

  @override
  Future<void> onInit() async {
    super.onInit();
    print('🏁 RacePedometerService: Initializing...');

    // Wait for pedometer to be ready
    await _pedometerService.initializationComplete;

    // Load persisted baselines
    await _loadPersistedBaselines();

    // Start listening to pedometer updates
    _startPedometerListener();

    print('✅ RacePedometerService: Initialized');
  }

  /// Start listening to pedometer updates for realtime race tracking
  void _startPedometerListener() {
    // Listen to pedometer step count changes
    ever(_pedometerService.currentStepCount, (_) async {
      await _updateAllRaces();
    });

    print('👂 Started listening to pedometer updates');
  }

  /// Create a new race baseline
  Future<bool> createRaceBaseline({
    required String raceId,
    required String userId,
    required DateTime raceStartTime,
  }) async {
    return await _raceLock.synchronized(() async {
      try {
        print('🏁 Creating race baseline for race: $raceId');

        // Check if pedometer is available
        if (!_pedometerService.isAvailable.value) {
          print('❌ Pedometer not available');
          return false;
        }

        // Get current pedometer steps as baseline
        final currentSteps = _pedometerService.currentStepCount.value;

        if (currentSteps == 0) {
          print('⚠️ Pedometer has 0 steps - waiting for first reading...');
          // Wait briefly for first pedometer reading
          await Future.delayed(const Duration(seconds: 2));
          final retrySteps = _pedometerService.currentStepCount.value;
          if (retrySteps == 0) {
            print('❌ Still 0 steps after wait - pedometer may not be working');
            return false;
          }
        }

        final baseline = RacePedometerBaseline(
          raceId: raceId,
          userId: userId,
          baselineSteps: _pedometerService.currentStepCount.value,
          raceStartTime: raceStartTime,
          createdAt: DateTime.now(),
          sessionStartSteps: _pedometerService.currentStepCount.value,
          deviceBootTime: _pedometerService.getDiagnostics()['deviceBootTime'] as int?,
        );

        _raceBaselines[raceId] = baseline;

        // Initialize race observables
        raceSteps[raceId] = 0;
        raceDistances[raceId] = 0.0;
        raceCalories[raceId] = 0;
        raceSpeeds[raceId] = 0.0;

        // Persist baseline
        await _persistBaseline(raceId, baseline);

        print('✅ Race baseline created: ${baseline.baselineSteps} steps');
        return true;
      } catch (e) {
        print('❌ Error creating race baseline: $e');
        return false;
      }
    });
  }

  /// Update all active races with current step count
  Future<void> _updateAllRaces() async {
    if (_raceBaselines.isEmpty) return;

    await _raceLock.synchronized(() async {
      final currentSteps = _pedometerService.currentStepCount.value;

      for (final entry in _raceBaselines.entries) {
        final raceId = entry.key;
        final baseline = entry.value;

        // Calculate race steps
        int raceStepCount = currentSteps - baseline.baselineSteps;

        // Handle negative values (device reboot or pedometer reset)
        if (raceStepCount < 0) {
          print('⚠️ Negative race steps detected for $raceId - device may have rebooted');

          // Try to recover from snapshots
          final recovered = await _recoverFromReboot(raceId, baseline);
          if (recovered) {
            raceStepCount = currentSteps; // Use current steps as new baseline
            baseline.baselineSteps = 0; // Reset baseline
            await _persistBaseline(raceId, baseline);
          } else {
            raceStepCount = 0; // Fallback to 0
          }
        }

        // Calculate distance and calories
        final distance = raceStepCount * StepConstants.averageStrideLength / 1000; // Convert to km
        final calories = (raceStepCount * StepConstants.caloriesPerStep).round();

        // Calculate average speed
        final raceDuration = DateTime.now().difference(baseline.raceStartTime);
        final raceHours = raceDuration.inSeconds / 3600.0;
        final speed = raceHours > 0 ? distance / raceHours : 0.0;

        // Update observables
        raceSteps[raceId] = raceStepCount;
        raceDistances[raceId] = distance;
        raceCalories[raceId] = calories;
        raceSpeeds[raceId] = speed;

        // Update last sync time
        baseline.lastSyncTime = DateTime.now();
      }
    });
  }

  /// Attempt to recover race data after device reboot
  Future<bool> _recoverFromReboot(String raceId, RacePedometerBaseline baseline) async {
    try {
      print('🔄 Attempting to recover race data after reboot for $raceId');

      // Get the last snapshot before reboot
      final lastSnapshot = await _stepDatabase.getLatestSnapshot();

      if (lastSnapshot != null) {
        final snapshotSteps = lastSnapshot['cumulativeSteps'] as int;
        final snapshotTime = DateTime.fromMillisecondsSinceEpoch(lastSnapshot['timestamp'] as int);

        print('📊 Last snapshot: $snapshotSteps steps at $snapshotTime');

        // Calculate steps from race start to last snapshot
        final stepsBeforeReboot = snapshotSteps - baseline.sessionStartSteps!;

        if (stepsBeforeReboot > 0) {
          // Update baseline to account for pre-reboot steps
          baseline.recoveredSteps = stepsBeforeReboot;
          print('✅ Recovered $stepsBeforeReboot steps from before reboot');
          return true;
        }
      }

      return false;
    } catch (e) {
      print('❌ Error recovering from reboot: $e');
      return false;
    }
  }

  /// Get race steps for a specific race
  int getRaceSteps(String raceId) {
    return raceSteps[raceId] ?? 0;
  }

  /// Get race distance for a specific race
  double getRaceDistance(String raceId) {
    return raceDistances[raceId] ?? 0.0;
  }

  /// Get race calories for a specific race
  int getRaceCalories(String raceId) {
    return raceCalories[raceId] ?? 0;
  }

  /// Get race speed for a specific race
  double getRaceSpeed(String raceId) {
    return raceSpeeds[raceId] ?? 0.0;
  }

  /// Check if race is being tracked
  bool isTrackingRace(String raceId) {
    return _raceBaselines.containsKey(raceId);
  }

  /// Stop tracking a race
  Future<void> stopTrackingRace(String raceId) async {
    await _raceLock.synchronized(() async {
      _raceBaselines.remove(raceId);
      raceSteps.remove(raceId);
      raceDistances.remove(raceId);
      raceCalories.remove(raceId);
      raceSpeeds.remove(raceId);

      // Remove persisted baseline
      await _removePersistedBaseline(raceId);

      print('🛑 Stopped tracking race: $raceId');
    });
  }

  /// Fill gaps when app was closed
  Future<Map<String, dynamic>> fillGaps(
    String raceId,
    DateTime lastSyncTime,
  ) async {
    try {
      print('🔄 Filling gaps for race $raceId from $lastSyncTime');

      final baseline = _raceBaselines[raceId];
      if (baseline == null) {
        return {'success': false, 'message': 'Race baseline not found'};
      }

      // Get steps from snapshots during the gap period
      final gapData = await _pedometerService.getStepsInRange(
        lastSyncTime,
        DateTime.now(),
      );

      if (gapData['success'] == true) {
        final missedSteps = gapData['stepsDelta'] as int;
        print('✅ Found $missedSteps steps during gap period');

        return {
          'success': true,
          'missedSteps': missedSteps,
          'snapshotCount': gapData['snapshotCount'],
        };
      }

      return gapData;
    } catch (e) {
      print('❌ Error filling gaps: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Persist baseline to SharedPreferences
  Future<void> _persistBaseline(String raceId, RacePedometerBaseline baseline) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'race_pedometer_baseline_$raceId';
      final json = baseline.toJson();
      await prefs.setString(key, jsonEncode(json));
      print('💾 Persisted baseline for race: $raceId');
    } catch (e) {
      print('❌ Error persisting baseline: $e');
    }
  }

  /// Load persisted baselines
  Future<void> _loadPersistedBaselines() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('race_pedometer_baseline_'));

      for (final key in keys) {
        final jsonStr = prefs.getString(key);
        if (jsonStr != null) {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          final baseline = RacePedometerBaseline.fromJson(json);
          _raceBaselines[baseline.raceId] = baseline;

          // Initialize observables
          raceSteps[baseline.raceId] = 0;
          raceDistances[baseline.raceId] = 0.0;
          raceCalories[baseline.raceId] = 0;
          raceSpeeds[baseline.raceId] = 0.0;

          print('📥 Loaded persisted baseline for race: ${baseline.raceId}');
        }
      }

      if (_raceBaselines.isNotEmpty) {
        print('✅ Loaded ${_raceBaselines.length} persisted race baselines');

        // Trigger immediate update
        await _updateAllRaces();
      }
    } catch (e) {
      print('❌ Error loading persisted baselines: $e');
    }
  }

  /// Remove persisted baseline
  Future<void> _removePersistedBaseline(String raceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'race_pedometer_baseline_$raceId';
      await prefs.remove(key);
      print('🗑️ Removed persisted baseline for race: $raceId');
    } catch (e) {
      print('❌ Error removing persisted baseline: $e');
    }
  }

  /// Get diagnostic info
  Map<String, dynamic> getDiagnostics() {
    return {
      'activeRaces': _raceBaselines.length,
      'raceIds': _raceBaselines.keys.toList(),
      'pedometerAvailable': _pedometerService.isAvailable.value,
      'currentPedometerSteps': _pedometerService.currentStepCount.value,
    };
  }

  @override
  void onClose() {
    print('👋 RacePedometerService: Disposing...');
    _pedometerSubscription?.cancel();
    super.onClose();
  }
}

/// Race pedometer baseline data
class RacePedometerBaseline {
  final String raceId;
  final String userId;
  int baselineSteps; // Pedometer steps at race join
  final DateTime raceStartTime;
  final DateTime createdAt;
  DateTime lastSyncTime;

  // For reboot recovery
  int? sessionStartSteps;
  int? deviceBootTime;
  int recoveredSteps; // Steps recovered from snapshots after reboot

  RacePedometerBaseline({
    required this.raceId,
    required this.userId,
    required this.baselineSteps,
    required this.raceStartTime,
    required this.createdAt,
    DateTime? lastSyncTime,
    this.sessionStartSteps,
    this.deviceBootTime,
    this.recoveredSteps = 0,
  }) : lastSyncTime = lastSyncTime ?? createdAt;

  Map<String, dynamic> toJson() {
    return {
      'raceId': raceId,
      'userId': userId,
      'baselineSteps': baselineSteps,
      'raceStartTime': raceStartTime.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'lastSyncTime': lastSyncTime.toIso8601String(),
      'sessionStartSteps': sessionStartSteps,
      'deviceBootTime': deviceBootTime,
      'recoveredSteps': recoveredSteps,
    };
  }

  factory RacePedometerBaseline.fromJson(Map<String, dynamic> json) {
    return RacePedometerBaseline(
      raceId: json['raceId'] as String,
      userId: json['userId'] as String,
      baselineSteps: json['baselineSteps'] as int,
      raceStartTime: DateTime.parse(json['raceStartTime'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastSyncTime: DateTime.parse(json['lastSyncTime'] as String),
      sessionStartSteps: json['sessionStartSteps'] as int?,
      deviceBootTime: json['deviceBootTime'] as int?,
      recoveredSteps: json['recoveredSteps'] as int? ?? 0,
    );
  }
}
