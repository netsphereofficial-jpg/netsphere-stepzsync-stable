import 'dart:async';
import 'package:get/get.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:synchronized/synchronized.dart';
import 'dart:io' show Platform;
import 'pedometer_permission_monitor.dart';
import '../database/step_database.dart';

/// Service for real-time pedometer tracking
/// Provides incremental step counts since app start
/// Works alongside HealthKit/Health Connect for accurate baseline tracking
class PedometerService extends GetxService {
  // Observables
  final RxInt currentStepCount = 0.obs;
  final RxString pedestrianStatus = 'unknown'.obs;
  final RxBool isAvailable = false.obs;
  final RxBool isInitialized = false.obs;
  final RxString errorMessage = ''.obs;

  // Private state
  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;
  int? _sessionStartSteps;
  int _incrementalSteps = 0;
  DateTime? _sessionStartTime;
  bool _hasPermission = false;

  // Snapshot tracking for race gap filling
  Timer? _snapshotTimer;
  final _stepDatabase = StepDatabase.instance;
  int? _deviceBootTime;

  // Initialization signaling - use Completer instead of polling/delays
  final Completer<bool> _initCompleter = Completer<bool>();

  /// Future that completes when initialization is done
  /// Returns true if pedometer is available, false otherwise
  Future<bool> get initializationComplete => _initCompleter.future;

  // Concurrency control - protect session state from concurrent access
  final Lock _pedLock = Lock();

  /// Get incremental steps since app start (session-based)
  int get incrementalSteps => _incrementalSteps;

  /// Check if pedometer is tracking
  bool get isTracking => _stepCountSubscription != null;

  /// Session start time
  DateTime? get sessionStartTime => _sessionStartTime;

  @override
  Future<void> onInit() async {
    super.onInit();
    print('🚶 PedometerService: Initializing...');
    await initialize();
  }

  /// Initialize the pedometer service
  Future<bool> initialize() async {
    // Check if initialization is already in progress or completed
    if (_initCompleter.isCompleted) {
      print('⏭️ PedometerService: Already initialized');
      return isAvailable.value;
    }

    // Check if already initialized (redundant check but safe)
    if (isInitialized.value) {
      print('⏭️ PedometerService: Already initialized (flag check)');
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete(isAvailable.value);
      }
      return isAvailable.value;
    }

    try {
      // Web doesn't support pedometer
      if (kIsWeb) {
        print('⚠️ PedometerService: Pedometer not available on web');
        isAvailable.value = false;
        isInitialized.value = true;
        _initCompleter.complete(false);
        return false;
      }

      // Check permission via PedometerPermissionMonitor
      // The monitor will show blocking dialog if permission not granted
      final monitor = PedometerPermissionMonitor.instance;
      await monitor.checkPermission();

      if (!monitor.hasPermission.value) {
        print('⚠️ PedometerService: Permission not granted - waiting for user to grant');
        errorMessage.value = 'Activity recognition permission not granted';
        isAvailable.value = false;
        isInitialized.value = true;
        _initCompleter.complete(false);

        // Listen to permission changes and auto-start when granted
        _listenToPermissionChanges();

        return false;
      }

      _hasPermission = true;

      // Estimate device boot time (for reboot detection)
      await _estimateDeviceBootTime();

      // Restore session from last snapshot if available
      await _restoreFromLastSnapshot();

      // Start pedometer streams
      await _startPedometerStreams();

      // Start periodic snapshot saving (every 10 seconds)
      _startSnapshotTimer();

      print('✅ PedometerService: Initialized successfully');
      isInitialized.value = true;
      _initCompleter.complete(isAvailable.value);
      return isAvailable.value;
    } catch (e, stackTrace) {
      print('❌ PedometerService: Initialization error: $e');
      print('📍 Stack trace: $stackTrace');
      errorMessage.value = 'Failed to initialize pedometer: $e';
      isAvailable.value = false;
      isInitialized.value = true;
      _initCompleter.complete(false);
      return false;
    }
  }

  /// Listen to permission changes and auto-start when granted
  void _listenToPermissionChanges() {
    final monitor = PedometerPermissionMonitor.instance;

    // Watch for permission to be granted
    ever(monitor.hasPermission, (hasPermission) {
      if (hasPermission && !isAvailable.value) {
        print('✅ Permission granted - starting pedometer...');
        _hasPermission = true;
        _startPedometerStreams();
      }
    });
  }

  /// Request necessary permissions
  Future<void> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.activityRecognition.status;
        if (status.isDenied) {
          final result = await Permission.activityRecognition.request();
          _hasPermission = result.isGranted;
          print('📱 Activity Recognition Permission: ${result.isGranted ? "Granted" : "Denied"}');
        } else {
          _hasPermission = status.isGranted;
          print('📱 Activity Recognition Permission: Already granted');
        }
      } else {
        // iOS doesn't need explicit activity recognition permission
        _hasPermission = true;
        print('📱 iOS: No explicit permission needed for pedometer');
      }
    } catch (e) {
      print('❌ Error requesting permissions: $e');
      _hasPermission = false;
    }
  }

  /// Start pedometer streams
  Future<void> _startPedometerStreams() async {
    try {
      print('🚶 Starting pedometer streams...');

      // Initialize session
      _sessionStartTime = DateTime.now();
      _sessionStartSteps = null;
      _incrementalSteps = 0;

      // Start step count stream
      _stepCountSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: _onStepCountError,
        cancelOnError: false,
      );

      // Start pedestrian status stream
      _pedestrianStatusSubscription = Pedometer.pedestrianStatusStream.listen(
        _onPedestrianStatus,
        onError: _onPedestrianStatusError,
        cancelOnError: false,
      );

      print('✅ Pedometer streams started');
      isAvailable.value = true;
    } catch (e) {
      print('❌ Error starting pedometer streams: $e');
      isAvailable.value = false;
      throw Exception('Failed to start pedometer: $e');
    }
  }

  /// Handle step count updates
  void _onStepCount(StepCount event) {
    try {
      print('👣 Pedometer event: ${event.steps} steps at ${event.timeStamp}');

      // Protect session state from concurrent access
      _pedLock.synchronized(() {
        // Set baseline on first reading
        if (_sessionStartSteps == null) {
          _sessionStartSteps = event.steps;
          _incrementalSteps = 0;
          print('📊 Session baseline set: $_sessionStartSteps steps');
        } else {
          // Calculate incremental steps since session start
          _incrementalSteps = event.steps - _sessionStartSteps!;

          // Handle pedometer resets (negative values)
          if (_incrementalSteps < 0) {
            print('⚠️ Pedometer reset detected, resetting baseline');
            _sessionStartSteps = event.steps;
            _incrementalSteps = 0;
          }
        }

        currentStepCount.value = event.steps;
        print('📊 Incremental steps this session: $_incrementalSteps');
      });
    } catch (e) {
      print('❌ Error processing step count: $e');
    }
  }

  /// Handle step count errors
  void _onStepCountError(error) {
    print('❌ Pedometer step count error: $error');
    errorMessage.value = 'Step count error: $error';

    // Check if it's a permission error
    if (error.toString().contains('permission') ||
        error.toString().contains('Permission')) {
      print('⚠️ Permission issue detected, triggering permission check...');
      // Trigger permission monitor to check and show dialog if needed
      final monitor = PedometerPermissionMonitor.instance;
      monitor.checkPermission();
    }
  }

  /// Handle pedestrian status updates
  void _onPedestrianStatus(PedestrianStatus event) {
    try {
      pedestrianStatus.value = event.status;
      print('🚶 Pedestrian status: ${event.status}');
    } catch (e) {
      print('❌ Error processing pedestrian status: $e');
    }
  }

  /// Handle pedestrian status errors
  void _onPedestrianStatusError(error) {
    print('❌ Pedometer pedestrian status error: $error');
    pedestrianStatus.value = 'unknown';
  }

  /// Reset session (useful for new day or after HealthKit sync)
  void resetSession() {
    print('🔄 Resetting pedometer session...');
    // Protect session state from concurrent access
    _pedLock.synchronized(() {
      _sessionStartSteps = currentStepCount.value;
      _incrementalSteps = 0;
      _sessionStartTime = DateTime.now();
      print('✅ Session reset. New baseline: $_sessionStartSteps steps');
    });
  }

  /// Manually adjust baseline (e.g., after HealthKit sync)
  void adjustBaseline(int newBaseline) {
    print('🔄 Adjusting pedometer baseline to: $newBaseline');
    _sessionStartSteps = currentStepCount.value;
    _incrementalSteps = 0;
  }

  /// Get session duration in minutes
  int get sessionDurationMinutes {
    if (_sessionStartTime == null) return 0;
    return DateTime.now().difference(_sessionStartTime!).inMinutes;
  }

  /// Check if permission is granted
  Future<bool> hasPermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;

    final status = await Permission.activityRecognition.status;
    return status.isGranted;
  }

  /// Request permission explicitly
  Future<bool> requestPermission() async {
    await _requestPermissions();
    return _hasPermission;
  }

  /// Stop tracking
  Future<void> stopTracking() async {
    print('🛑 Stopping pedometer tracking...');
    await _stepCountSubscription?.cancel();
    await _pedestrianStatusSubscription?.cancel();
    _stepCountSubscription = null;
    _pedestrianStatusSubscription = null;
    print('✅ Pedometer tracking stopped');
  }

  /// Restart tracking
  Future<bool> restartTracking() async {
    print('🔄 Restarting pedometer tracking...');
    await stopTracking();
    return await initialize();
  }

  /// Get diagnostic info
  Map<String, dynamic> getDiagnostics() {
    return {
      'isInitialized': isInitialized.value,
      'isAvailable': isAvailable.value,
      'isTracking': isTracking,
      'hasPermission': _hasPermission,
      'sessionStartTime': _sessionStartTime?.toIso8601String(),
      'sessionDurationMinutes': sessionDurationMinutes,
      'currentStepCount': currentStepCount.value,
      'sessionStartSteps': _sessionStartSteps,
      'incrementalSteps': _incrementalSteps,
      'pedestrianStatus': pedestrianStatus.value,
      'errorMessage': errorMessage.value,
      'deviceBootTime': _deviceBootTime,
    };
  }

  // ========== SNAPSHOT METHODS (for race gap filling) ==========

  /// Estimate device boot time for reboot detection
  Future<void> _estimateDeviceBootTime() async {
    try {
      // Device boot time = current time - uptime
      final uptime = DateTime.now().millisecondsSinceEpoch;
      _deviceBootTime = uptime;
      print('📱 Estimated device boot time: $_deviceBootTime');
    } catch (e) {
      print('❌ Error estimating boot time: $e');
      _deviceBootTime = DateTime.now().millisecondsSinceEpoch;
    }
  }

  /// Restore session from last snapshot
  Future<void> _restoreFromLastSnapshot() async {
    try {
      final lastSnapshot = await _stepDatabase.getLatestSnapshot();

      if (lastSnapshot != null) {
        print('📊 Found last snapshot: ${lastSnapshot['cumulativeSteps']} steps at ${DateTime.fromMillisecondsSinceEpoch(lastSnapshot['timestamp'])}');

        // Check if this is after a device reboot
        final snapshotBootTime = lastSnapshot['deviceBootTime'] as int?;
        if (snapshotBootTime != null && snapshotBootTime != _deviceBootTime) {
          print('⚠️ Device rebooted detected - starting fresh session');
          // Don't restore, start fresh
          return;
        }

        // Calculate time since last snapshot
        final timeSinceSnapshot = DateTime.now().millisecondsSinceEpoch - (lastSnapshot['timestamp'] as int);
        final minutesSinceSnapshot = timeSinceSnapshot / 60000;

        print('⏱️ Time since last snapshot: ${minutesSinceSnapshot.toStringAsFixed(1)} minutes');

        // If snapshot is recent (< 30 minutes), try to use it
        if (minutesSinceSnapshot < 30) {
          print('✅ Snapshot is recent, will use it for gap filling if needed');
        } else {
          print('⚠️ Snapshot is old (${minutesSinceSnapshot.toStringAsFixed(1)} min), starting fresh');
        }
      } else {
        print('📊 No previous snapshot found - first time tracking');
      }
    } catch (e) {
      print('❌ Error restoring from snapshot: $e');
    }
  }

  /// Start periodic snapshot timer (saves every 10 seconds)
  void _startSnapshotTimer() {
    _snapshotTimer?.cancel();

    _snapshotTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _saveSnapshot();
    });

    print('⏰ Started snapshot timer (10 second intervals)');
  }

  /// Save current pedometer state as snapshot
  Future<void> _saveSnapshot() async {
    try {
      // Only save if we have valid data
      if (_sessionStartSteps == null || !isAvailable.value) {
        return;
      }

      await _stepDatabase.insertSnapshot(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        cumulativeSteps: currentStepCount.value,
        incrementalSteps: _incrementalSteps,
        sessionStartSteps: _sessionStartSteps,
        source: 'pedometer',
        deviceBootTime: _deviceBootTime,
      );

      // Cleanup old snapshots (keep only last 7 days)
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
      await _stepDatabase.deleteOldSnapshots(sevenDaysAgo);

    } catch (e) {
      print('❌ Error saving snapshot: $e');
    }
  }

  /// Get steps at a specific timestamp (for race baseline)
  Future<int?> getStepsAtTime(DateTime timestamp) async {
    try {
      final snapshot = await _stepDatabase.getSnapshotNearTime(
        timestamp.millisecondsSinceEpoch,
      );

      if (snapshot != null) {
        return snapshot['cumulativeSteps'] as int;
      }

      return null;
    } catch (e) {
      print('❌ Error getting steps at time: $e');
      return null;
    }
  }

  /// Get steps in a time range (for gap filling)
  Future<Map<String, dynamic>> getStepsInRange(
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      final snapshots = await _stepDatabase.getSnapshotsInRange(
        startTime.millisecondsSinceEpoch,
        endTime.millisecondsSinceEpoch,
      );

      if (snapshots.isEmpty) {
        return {
          'success': false,
          'message': 'No snapshots found in range',
        };
      }

      final firstSnapshot = snapshots.first;
      final lastSnapshot = snapshots.last;

      final stepsDelta = (lastSnapshot['cumulativeSteps'] as int) -
                         (firstSnapshot['cumulativeSteps'] as int);

      return {
        'success': true,
        'stepsDelta': stepsDelta,
        'startSteps': firstSnapshot['cumulativeSteps'],
        'endSteps': lastSnapshot['cumulativeSteps'],
        'snapshotCount': snapshots.length,
        'startTime': DateTime.fromMillisecondsSinceEpoch(firstSnapshot['timestamp'] as int),
        'endTime': DateTime.fromMillisecondsSinceEpoch(lastSnapshot['timestamp'] as int),
      };
    } catch (e) {
      print('❌ Error getting steps in range: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  /// Check if device rebooted (pedometer count dropped significantly)
  bool detectReboot(int previousSteps, int currentSteps) {
    // If current steps < previous steps, device likely rebooted
    return currentSteps < previousSteps && (previousSteps - currentSteps) > 1000;
  }

  @override
  void onClose() {
    print('👋 PedometerService: Disposing...');
    _snapshotTimer?.cancel();
    stopTracking();
    super.onClose();
  }
}
