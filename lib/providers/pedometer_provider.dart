import 'dart:async';
import 'dart:developer' as dev;
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/step_constants.dart';

/// Provider for real-time pedometer step tracking
/// Manages pedometer sensor stream and pedestrian status
class PedometerProvider {
  // Streams
  Stream<StepCount>? _stepCountStream;
  Stream<PedestrianStatus>? _pedestrianStatusStream;

  // Subscriptions
  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;

  // Controllers for broadcasting
  final _stepCountController = StreamController<int>.broadcast();
  final _pedestrianStatusController = StreamController<PedestrianStatus>.broadcast();

  // State
  bool _isInitialized = false;
  bool _isListening = false;
  int? _initialStepCount;
  int _currentStepCount = 0;
  DateTime? _lastUpdateTime;

  /// Stream of step counts
  Stream<int> get stepCountStream => _stepCountController.stream;

  /// Stream of pedestrian status
  Stream<PedestrianStatus> get pedestrianStatusStream => _pedestrianStatusController.stream;

  /// Current step count
  int get currentStepCount => _currentStepCount;

  /// Whether the provider is listening
  bool get isListening => _isListening;

  /// Initialize the pedometer
  Future<bool> initialize() async {
    if (_isInitialized) {
      dev.log('⚠️ PedometerProvider already initialized');
      return true;
    }

    try {
      // Request activity recognition permission
      final permissionStatus = await Permission.activityRecognition.request();

      if (!permissionStatus.isGranted) {
        dev.log('❌ Activity recognition permission not granted');
        return false;
      }

      // Initialize streams
      _stepCountStream = Pedometer.stepCountStream;
      _pedestrianStatusStream = Pedometer.pedestrianStatusStream;

      _isInitialized = true;
      dev.log('✅ PedometerProvider initialized successfully');
      return true;
    } catch (e) {
      dev.log('❌ Error initializing PedometerProvider: $e');
      _handleError(e);
      return false;
    }
  }

  /// Start listening to pedometer events
  Future<void> startListening({int? baselineStepCount}) async {
    if (!_isInitialized) {
      dev.log('⚠️ PedometerProvider not initialized. Initializing now...');
      final success = await initialize();
      if (!success) {
        dev.log('❌ Failed to initialize PedometerProvider');
        return;
      }
    }

    if (_isListening) {
      dev.log('⚠️ PedometerProvider already listening');
      return;
    }

    try {
      // Set baseline if provided
      if (baselineStepCount != null) {
        _initialStepCount = baselineStepCount;
        dev.log('📍 Set baseline step count: $baselineStepCount');
      }

      // Listen to step count stream
      _stepCountSubscription = _stepCountStream?.listen(
        _onStepCount,
        onError: _onStepCountError,
        cancelOnError: false,
      );

      // Listen to pedestrian status stream
      _pedestrianStatusSubscription = _pedestrianStatusStream?.listen(
        _onPedestrianStatus,
        onError: _onPedestrianStatusError,
        cancelOnError: false,
      );

      _isListening = true;
      dev.log('✅ Started listening to pedometer events');
    } catch (e) {
      dev.log('❌ Error starting pedometer listener: $e');
      _handleError(e);
    }
  }

  /// Stop listening to pedometer events
  Future<void> stopListening() async {
    if (!_isListening) {
      dev.log('⚠️ PedometerProvider not listening');
      return;
    }

    await _stepCountSubscription?.cancel();
    await _pedestrianStatusSubscription?.cancel();

    _stepCountSubscription = null;
    _pedestrianStatusSubscription = null;
    _isListening = false;

    dev.log('⏹️ Stopped listening to pedometer events');
  }

  /// Reset the step count baseline
  void resetBaseline(int newBaseline) {
    _initialStepCount = newBaseline;
    dev.log('🔄 Reset pedometer baseline to: $newBaseline');
  }

  /// Get steps since baseline
  int getStepsSinceBaseline() {
    if (_initialStepCount == null) return _currentStepCount;
    return _currentStepCount - _initialStepCount!;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopListening();
    await _stepCountController.close();
    await _pedestrianStatusController.close();
    _isInitialized = false;
    dev.log('🗑️ PedometerProvider disposed');
  }

  // Private event handlers

  void _onStepCount(StepCount event) {
    try {
      _currentStepCount = event.steps;
      _lastUpdateTime = event.timeStamp;

      // Calculate steps since baseline
      final stepsSinceBaseline = getStepsSinceBaseline();

      // Emit to stream
      _stepCountController.add(stepsSinceBaseline);

      dev.log('👣 Step count update: $stepsSinceBaseline steps (total: ${event.steps})');
    } catch (e) {
      dev.log('❌ Error processing step count: $e');
    }
  }

  void _onStepCountError(error) {
    dev.log('❌ Step count stream error: $error');
    _handleError(error);
  }

  void _onPedestrianStatus(PedestrianStatus event) {
    try {
      _pedestrianStatusController.add(event);
      dev.log('🚶 Pedestrian status: ${event.status} at ${event.timeStamp}');
    } catch (e) {
      dev.log('❌ Error processing pedestrian status: $e');
    }
  }

  void _onPedestrianStatusError(error) {
    dev.log('❌ Pedestrian status stream error: $error');
    // Don't stop everything for pedestrian status errors
  }

  void _handleError(dynamic error) {
    final errorString = error.toString();

    if (errorString.contains('not available')) {
      dev.log('❌ ${StepConstants.errorPedometerNotAvailable}');
    } else if (errorString.contains('permission')) {
      dev.log('❌ ${StepConstants.errorPermissionDenied}');
    } else {
      dev.log('❌ Pedometer error: $error');
    }
  }

  /// Check if pedometer is available on this device
  static Future<bool> isPedometerAvailable() async {
    try {
      // Try to get permission status
      final status = await Permission.activityRecognition.status;
      return status.isGranted || status.isDenied || status.isPermanentlyDenied;
    } catch (e) {
      dev.log('❌ Error checking pedometer availability: $e');
      return false;
    }
  }

  /// Request activity recognition permission
  static Future<bool> requestPermission() async {
    try {
      final status = await Permission.activityRecognition.request();
      return status.isGranted;
    } catch (e) {
      dev.log('❌ Error requesting activity recognition permission: $e');
      return false;
    }
  }
}
