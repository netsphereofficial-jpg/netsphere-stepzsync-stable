import 'dart:async';
import 'package:get/get.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'pedometer_permission_monitor.dart';

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
    if (isInitialized.value) {
      print('⏭️ PedometerService: Already initialized');
      return true;
    }

    try {
      // Web doesn't support pedometer
      if (kIsWeb) {
        print('⚠️ PedometerService: Pedometer not available on web');
        isAvailable.value = false;
        isInitialized.value = true;
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

        // Listen to permission changes and auto-start when granted
        _listenToPermissionChanges();

        return false;
      }

      _hasPermission = true;

      // Start pedometer streams
      await _startPedometerStreams();

      print('✅ PedometerService: Initialized successfully');
      isInitialized.value = true;
      return isAvailable.value;
    } catch (e, stackTrace) {
      print('❌ PedometerService: Initialization error: $e');
      print('📍 Stack trace: $stackTrace');
      errorMessage.value = 'Failed to initialize pedometer: $e';
      isAvailable.value = false;
      isInitialized.value = true;
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
    _sessionStartSteps = currentStepCount.value;
    _incrementalSteps = 0;
    _sessionStartTime = DateTime.now();
    print('✅ Session reset. New baseline: $_sessionStartSteps steps');
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
    };
  }

  @override
  void onClose() {
    print('👋 PedometerService: Disposing...');
    stopTracking();
    super.onClose();
  }
}
