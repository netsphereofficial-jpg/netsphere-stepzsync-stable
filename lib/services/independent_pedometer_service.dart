// import 'dart:async';
// import 'dart:developer';
// import 'dart:math' as math;
//
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/widgets.dart';
// import 'package:get/get.dart';
// import 'package:pedometer/pedometer.dart';
//
// import 'database_controller.dart';
//
// class IndependentPedometerService extends GetxController
//     with WidgetsBindingObserver {
//   // Observable properties
//   final RxInt currentSteps = 0.obs;
//   final RxInt todaySteps = 0.obs;
//   final RxDouble todayDistance = 0.0.obs;
//   final RxInt todayCalories = 0.obs;
//   final RxInt todayActiveTime = 0.obs; // in minutes
//   final RxBool isTracking = false.obs;
//   final RxBool isInitialized = false.obs;
//   final RxString lastError = ''.obs;
//
//   // Race tracking
//   final RxSet<String> _activeRaceIds = <String>{}.obs;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//
//   // Step validation constants
//   static const int MIN_STEP_INTERVAL_MS =
//       150; // Minimum time between steps (ms) - prevent rapid-fire steps
//   static const int MAX_STEPS_PER_MINUTE =
//       150; // More realistic for fast walking/jogging
//   static const int MAX_STEPS_PER_HOUR = 9000; // 150 steps/min * 60 minutes
//
//   // Private variables
//   DatabaseController? _dbController;
//   User? _currentUser;
//
//   // Sensor data
//   StreamSubscription<StepCount>? _stepCountSubscription;
//   DateTime _lastStepTime = DateTime.now();
//   DateTime _lastUpdateTime = DateTime.now();
//   DateTime _sessionStartTime = DateTime.now();
//   int _stepsInCurrentSession = 0;
//   int _baselineSteps = 0; // Steps loaded from DB on startup
//
//   // Timers
//   Timer? _saveTimer;
//   Timer? _validationTimer;
//
//   @override
//   void onInit() {
//     super.onInit();
//     WidgetsBinding.instance.addObserver(this);
//     log('🚀 IndependentPedometerService initializing...');
//     _initialize();
//   }
//
//   @override
//   void onClose() {
//     // NEVER allow this service to be disposed
//     // This service must persist across all screens and app lifecycle
//     log(
//       '🚫 IndependentPedometerService.onClose() called - preventing disposal',
//     );
//     // DO NOT call _cleanup() or super.onClose()
//     // This ensures the service remains active globally
//   }
//
//   // === APP LIFECYCLE MANAGEMENT ===
//
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     super.didChangeAppLifecycleState(state);
//     log('📱 App lifecycle changed: $state');
//
//     switch (state) {
//       case AppLifecycleState.resumed:
//         _handleAppResumed();
//         break;
//       case AppLifecycleState.paused:
//       case AppLifecycleState.inactive:
//       case AppLifecycleState.detached:
//       case AppLifecycleState.hidden:
//         _handleAppPaused();
//         break;
//     }
//   }
//
//   void _handleAppResumed() {
//     log('📱 App resumed - checking for new day and restarting sensors');
//
//     // Check if it's a new day (compare full dates, not just day numbers)
//     final now = DateTime.now();
//     final currentDate = DateTime(now.year, now.month, now.day);
//     final lastUpdateDate = DateTime(
//       _lastUpdateTime.year,
//       _lastUpdateTime.month,
//       _lastUpdateTime.day,
//     );
//
//     if (!currentDate.isAtSameMomentAs(lastUpdateDate)) {
//       log('🌅 New day detected - handling day transition');
//       log('📅 Last update: ${lastUpdateDate.toString().split(' ')[0]}');
//       log('📅 Current date: ${currentDate.toString().split(' ')[0]}');
//       _handleNewDayTransition();
//     }
//
//     // Restart pedometer if needed
//     if (isInitialized.value && !isTracking.value) {
//       log('🔄 Restarting step tracking after app resume');
//       _startPedometerMonitoring();
//       isTracking.value = true;
//     }
//   }
//
//   void _handleAppPaused() {
//     log('📱 App paused - saving current data');
//
//     // Force save current data
//     _saveToDatabase();
//   }
//
//   void _handleNewDayTransition() {
//     // Save yesterday's data to step history
//     _saveToDatabase();
//
//     // For independent step counting, reset everything to 0 for new day
//     // DON'T carry forward device cumulative steps
//     _baselineSteps = 0;
//     _stepsInCurrentSession = 0;
//
//     // Reset today's specific metrics
//     todaySteps.value = 0;
//     todayDistance.value = 0.0;
//     todayCalories.value = 0;
//     todayActiveTime.value = 0;
//
//     // Reset current steps for independent counting
//     currentSteps.value = 0;
//
//     // Update session timing
//     _sessionStartTime = DateTime.now();
//     _lastUpdateTime = DateTime.now();
//
//     log(
//       '🌅 New day transition completed - fresh start with 0 steps (independent counting)',
//     );
//   }
//
//   // === INITIALIZATION ===
//
//   Future<void> _initialize() async {
//     if (isInitialized.value) {
//       log('⚠️ IndependentPedometerService already initialized, skipping...');
//       return;
//     }
//
//     try {
//       // Get database controller
//       _dbController = Get.find<DatabaseController>();
//
//       // Get current user
//       _currentUser = FirebaseAuth.instance.currentUser;
//       if (_currentUser == null) {
//         throw Exception('No authenticated user found');
//       }
//
//       // Load existing step data from database
//       await _loadBaselineFromDatabase();
//
//       // Start pedometer monitoring
//       await _startPedometerMonitoring();
//
//       // Start periodic tasks
//       _startPeriodicSave();
//
//       isInitialized.value = true;
//       isTracking.value = true;
//       lastError.value = '';
//
//       log('✅ IndependentPedometerService initialized successfully');
//       log('📊 Baseline steps loaded: $_baselineSteps');
//     } catch (e) {
//       log('❌ Error initializing pedometer service: $e');
//       lastError.value = 'Initialization failed: $e';
//       isInitialized.value = false;
//     }
//   }
//
//   // === DATABASE OPERATIONS ===
//
//   Future<void> _loadBaselineFromDatabase() async {
//     try {
//       final userId = _currentUser!.uid.hashCode
//           .abs(); // Convert Firebase UID to integer
//
//       // Try to get today's step metrics first
//       final todayMetrics = await _dbController!.getTodayStepMetrics(userId);
//
//       if (todayMetrics != null) {
//         // Continue from today's existing data
//         _baselineSteps = todayMetrics.steps;
//         currentSteps.value = _baselineSteps;
//         todaySteps.value = _baselineSteps;
//         todayDistance.value = todayMetrics.distance;
//         todayCalories.value = todayMetrics.calories.round();
//         todayActiveTime.value = todayMetrics.activeTime;
//
//         log('📊 Loaded today\'s existing data: ${todayMetrics.steps} steps');
//       } else {
//         // Check if user has overall stats (not first time user)
//         final overallStats = await _dbController!.getUserOverallStats(userId);
//
//         if (overallStats == null) {
//           // First time user - initialize with 0
//           await _dbController!.initializeUserOverallStats(userId);
//           _baselineSteps = 0;
//           log('👤 New user initialized with 0 steps');
//         } else {
//           // Existing user, new day - start fresh for today but preserve history
//           _baselineSteps = 0;
//           log('🌅 New day started for existing user');
//         }
//
//         currentSteps.value = _baselineSteps;
//         todaySteps.value = _baselineSteps;
//         todayDistance.value = 0.0;
//         todayCalories.value = 0;
//         todayActiveTime.value = 0;
//       }
//
//       _sessionStartTime = DateTime.now();
//       _lastUpdateTime = DateTime.now();
//     } catch (e) {
//       log('❌ Error loading baseline from database: $e');
//       // Fallback to 0 if database read fails
//       _baselineSteps = 0;
//       currentSteps.value = 0;
//       todaySteps.value = 0;
//     }
//   }
//
//   // === PEDOMETER MONITORING ===
//
//   Future<void> _startPedometerMonitoring() async {
//     try {
//       // Cancel existing subscription if any
//       await _stepCountSubscription?.cancel();
//
//       log('🔧 Starting pedometer monitoring...');
//
//       // Check pedometer permission first
//       await _checkPedometerPermission();
//
//       _stepCountSubscription = Pedometer.stepCountStream.listen(
//         _processStepCountEvent,
//         onError: _handleSensorError,
//         cancelOnError: false,
//       );
//
//       log('✅ Pedometer monitoring started');
//     } catch (e) {
//       log('❌ Error starting pedometer: $e');
//       lastError.value = 'Pedometer error: $e';
//       throw e;
//     }
//   }
//
//   Future<void> _checkPedometerPermission() async {
//     try {
//       log('🔍 Checking pedometer permissions...');
//
//       // The pedometer package handles permissions internally
//       // We'll just try to listen and handle errors gracefully
//       log('✅ Pedometer permissions handled by package');
//     } catch (e) {
//       log('❌ Pedometer permission error: $e');
//       lastError.value = 'Permission error: $e';
//       rethrow;
//     }
//   }
//
//   void _processStepCountEvent(StepCount stepCount) {
//     try {
//       // Ignore stepCount.steps value (device cumulative count)
//       // Just use this event as "step detected" trigger
//       log("👟 Pedometer step event received (ignoring device count)");
//
//       // Use our own step registration with validation
//       _registerStep();
//     } catch (e) {
//       log('❌ Error processing step count event: $e');
//     }
//   }
//
//   void _registerStep() {
//     final now = DateTime.now();
//
//     // Validate step increment
//     if (!_validateStepIncrement()) {
//       log('🚫 Step validation failed - not registering step');
//       return;
//     }
//
//     // Increment counters
//     _stepsInCurrentSession++;
//     final newStepCount = _baselineSteps + _stepsInCurrentSession;
//
//     // Update observable values
//     currentSteps.value = newStepCount;
//     todaySteps.value = newStepCount;
//
//     // Calculate derived metrics
//     _updateDerivedMetrics();
//
//     log('👟 Step registered! Total: ${currentSteps.value}');
//   }
//
//   // === STEP VALIDATION ===
//
//   bool _validateStepIncrement() {
//     final now = DateTime.now();
//     final timeSinceLastStep = now.difference(_lastStepTime);
//
//     // Only validate against step-to-step timing, not session timing
//     if (timeSinceLastStep.inMilliseconds < MIN_STEP_INTERVAL_MS) {
//       return false; // Too fast, likely noise
//     }
//
//     // Allow more lenient session validation
//     final timeSinceSession = now.difference(_sessionStartTime);
//     final maxStepsForSession = _calculateMaxStepsForTimeGap(timeSinceSession);
//
//     if (_stepsInCurrentSession >= maxStepsForSession) {
//       log(
//         '🚫 Too many steps for session: ${_stepsInCurrentSession} steps in ${timeSinceSession.inMinutes} minutes',
//       );
//       return false;
//     }
//
//     return true;
//   }
//
//   int _calculateMaxStepsForTimeGap(Duration timeGap) {
//     final seconds = timeGap.inSeconds;
//     if (seconds <= 0) return 10; // Allow up to 10 steps immediately
//     if (seconds < 30) return 30; // Allow 30 steps in first 30 seconds
//     if (seconds < 60)
//       return 60; // Allow 60 steps in first minute (moderate walking)
//
//     final minutes = timeGap.inMinutes;
//     // Use realistic walking pace: 100-150 steps per minute
//     return math.min(minutes * MAX_STEPS_PER_MINUTE, MAX_STEPS_PER_HOUR);
//   }
//
//   // === DERIVED METRICS CALCULATION ===
//
//   void _updateDerivedMetrics() {
//     final steps = currentSteps.value;
//     if (steps <= 0) return;
//
//     // Calculate distance (assuming average step length of 0.78m)
//     final distance = (steps * 0.78) / 1000; // Convert to kilometers
//     todayDistance.value = distance;
//
//     // Calculate calories (rough estimate: 0.04 calories per step)
//     final calories = (steps * 0.04).round();
//     todayCalories.value = calories;
//
//     // Calculate active time (assuming 100 steps per minute when walking)
//     final activeMinutes = (steps / 100).round();
//     todayActiveTime.value = activeMinutes;
//   }
//
//   // === PERIODIC OPERATIONS ===
//
//   void _startPeriodicSave() {
//     _saveTimer?.cancel();
//     _saveTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
//       _saveToDatabase();
//     });
//
//     log('⏰ Periodic save timer started (15s interval)');
//   }
//
//   Future<void> _saveToDatabase() async {
//     if (!isInitialized.value || _currentUser == null || _dbController == null) {
//       return;
//     }
//
//     try {
//       final userId = _currentUser!.uid.hashCode
//           .abs(); // Convert Firebase UID to integer
//       final now = DateTime.now();
//
//       // Only save if we have steps to save
//       if (currentSteps.value <= 0) return;
//
//       // Validate before saving
//       final existingMetrics = await _dbController!.getTodayStepMetrics(userId);
//       if (existingMetrics != null &&
//           currentSteps.value < existingMetrics.steps) {
//         log('🚫 Not saving - step count would go backwards');
//         return;
//       }
//
//       // Calculate average speed (km/h)
//       final sessionDuration = now.difference(_sessionStartTime);
//       double avgSpeed = 0.0;
//       if (sessionDuration.inMinutes > 0 && todayDistance.value > 0) {
//         avgSpeed = todayDistance.value / (sessionDuration.inHours);
//       }
//
//       // Format duration
//       final duration = _formatDuration(todayActiveTime.value);
//
//       // Update database using the comprehensive method
//       await _dbController!.updateDailyStepDataAndSync(
//         userId: userId,
//         date: now,
//         steps: currentSteps.value,
//         distance: todayDistance.value,
//         calories: todayCalories.value.toDouble(),
//         activeTime: todayActiveTime.value,
//         avgSpeed: avgSpeed,
//         duration: duration,
//       );
//
//       _lastUpdateTime = now;
//       log('💾 Saved to database: ${currentSteps.value} steps');
//
//       // ALSO save to Firestore races if any races are active
//       // if (hasActiveRaces) {
//       print('Has Active Races Called - > ');
//       // await _updateRaceParticipants();
//       // }
//     } catch (e) {
//       log('❌ Error saving to database: $e');
//       lastError.value = 'Save error: $e';
//     }
//   }
//
//   String _formatDuration(int minutes) {
//     final hours = minutes ~/ 60;
//     final remainingMinutes = minutes % 60;
//     return '${hours.toString().padLeft(2, '0')}:${remainingMinutes.toString().padLeft(2, '0')}';
//   }
//
//   // === ERROR HANDLING ===
//
//   void _handleSensorError(dynamic error) {
//     log('❌ Sensor error: $error');
//     lastError.value = 'Sensor error: $error';
//
//     // Try to restart sensor after a delay
//     Timer(const Duration(seconds: 5), () {
//       if (isInitialized.value) {
//         log('🔄 Attempting to restart pedometer...');
//         _startPedometerMonitoring();
//       }
//     });
//   }
//
//   // === PUBLIC METHODS ===
//
//   /// Start pedometer service after successful login/signup
//   static Future<void> startAfterLogin() async {
//     try {
//       final service = Get.find<IndependentPedometerService>();
//       if (!service.isInitialized.value) {
//         await service._initialize();
//         log('🚀 Pedometer service started after login');
//       } else {
//         log('⚠️ Pedometer service already initialized, skipping start');
//       }
//     } catch (e) {
//       log('❌ Error starting pedometer service after login: $e');
//       // Service will be initialized when first accessed due to lazy loading
//     }
//   }
//
//   /// Stop pedometer service (for logout only - use with caution)
//   static void stopService() {
//     try {
//       final service = Get.find<IndependentPedometerService>();
//       // Only stop tracking, but keep service alive for global persistence
//       service._stepCountSubscription?.cancel();
//       service._saveTimer?.cancel();
//       service.isTracking.value = false;
//       log('🛑 Pedometer tracking paused (service remains active)');
//     } catch (e) {
//       log('❌ Error pausing pedometer service: $e');
//     }
//   }
//
//   /// Resume pedometer tracking (if paused)
//   static Future<void> resumeTracking() async {
//     try {
//       final service = Get.find<IndependentPedometerService>();
//       if (!service.isTracking.value && service.isInitialized.value) {
//         await service._startPedometerMonitoring();
//         service._startPeriodicSave();
//         service.isTracking.value = true;
//         log('▶️ Pedometer tracking resumed');
//       }
//     } catch (e) {
//       log('❌ Error resuming pedometer tracking: $e');
//     }
//   }
//
//   /// Force save current data to database
//   Future<void> forceSave() async {
//     await _saveToDatabase();
//   }
//
//   /// Reset step count (for testing or new day)
//   Future<void> resetStepCount() async {
//     _baselineSteps = 0;
//     _stepsInCurrentSession = 0;
//     currentSteps.value = 0;
//     todaySteps.value = 0;
//     todayDistance.value = 0.0;
//     todayCalories.value = 0;
//     todayActiveTime.value = 0;
//     _sessionStartTime = DateTime.now();
//
//     await _saveToDatabase();
//     log('🔄 Step count reset');
//   }
//
//   /// Get current service status
//   Map<String, dynamic> getStatus() {
//     return {
//       'isInitialized': isInitialized.value,
//       'isTracking': isTracking.value,
//       'currentSteps': currentSteps.value,
//       'todaySteps': todaySteps.value,
//       'todayDistance': todayDistance.value,
//       'todayCalories': todayCalories.value,
//       'todayActiveTime': todayActiveTime.value,
//       'baselineSteps': _baselineSteps,
//       'sessionSteps': _stepsInCurrentSession,
//       'sessionStartTime': _sessionStartTime.toIso8601String(),
//       'lastUpdateTime': _lastUpdateTime.toIso8601String(),
//       'lastError': lastError.value,
//     };
//   }
//
//   // === CLEANUP (RESTRICTED) ===
//
//   void _cleanup() {
//     log(
//       '🚫 _cleanup() called - IndependentPedometerService should NEVER be cleaned up',
//     );
//     log('🔒 This service must remain active globally across all screens');
//     // DO NOT cleanup - this service should persist forever
//     // Only allow manual pause/resume operations for specific use cases
//   }
// }
