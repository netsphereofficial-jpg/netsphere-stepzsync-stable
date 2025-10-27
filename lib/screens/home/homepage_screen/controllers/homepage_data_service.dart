import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../services/race_invite_service.dart';
import '../../../../services/step_tracking_service.dart';
import '../../../../services/race_step_sync_service.dart';
import '../../../../services/user_profile_service.dart';
import '../../../../services/heart_rate_service.dart';
import '../../../../services/respiratory_data_service.dart';
import '../../../../services/health_sync_service.dart';
import '../../../../services/permission_service.dart';
import '../../../../services/background_location_service.dart';
import '../../../../services/preferences_service.dart';
import '../../../../models/health_sync_models.dart';
import '../../../../widgets/dialogs/health_sync_dialog.dart';

class HomepageDataService extends GetxController {
  // Observable data
  final RxString userName = 'User'.obs;
  final RxString profileImageUrl = ''.obs;
  final RxInt totalRaceCount = 0.obs;
  final RxInt activeJoinedRaceCount = 0.obs;
  final RxInt quickRaceCount = 0.obs;
  final RxInt pendingInvitesCount = 0.obs;

  // Service instances
  StepTrackingService? _stepTrackingService;
  RaceStepSyncService? _raceStepSyncService;
  RaceInviteService? _raceInviteService;
  HeartRateService? _heartRateService;
  RespiratoryDataService? _respiratoryDataService;
  HealthSyncService? _healthSyncService;

  // Period-specific stats
  final RxInt periodSteps = 0.obs;
  final RxDouble periodDistance = 0.0.obs;
  final RxInt periodActiveTime = 0.obs;
  final RxDouble periodSpeed = 0.0.obs;
  final RxInt periodCalories = 0.obs;
  final RxBool isLoadingPeriodData = false.obs;

  // Loading states
  final RxBool isInitialLoading = true.obs;
  final RxBool isSecondaryDataLoaded = false.obs;

  // Initialization guards to prevent duplicate setup
  bool _isInitializing = false;
  bool _isFullyInitialized = false;
  bool _isDisposed = false;  // ✅ Track disposal state to prevent updates after cleanup

  // Real-time step tracking - local observables
  final RxInt realTimeSteps = 0.obs;
  final RxInt localTodaySteps = 0.obs;
  final RxInt localOverallSteps = 0.obs;
  final RxDouble localTodayDistance = 0.0.obs;
  final RxDouble localOverallDistance = 0.0.obs;
  final RxInt localTodayCalories = 0.obs;
  final RxInt localTodayActiveTime = 0.obs;
  final RxInt localOverallDays = 0.obs;
  final RxString localPedestrianStatus = 'unknown'.obs;

  // Heart rate data - local observables
  final RxInt localCurrentHeartRate = 0.obs;
  final RxInt localAverageHeartRate = 0.obs;
  final RxBool localIsHeartRateAvailable = false.obs;

  // Respiratory data - local observables
  final RxInt localCurrentBloodOxygen = 0.obs;
  final RxInt localAverageBloodOxygen = 0.obs;
  final RxBool localIsBloodOxygenAvailable = false.obs;
  final RxInt localCurrentRespiratoryRate = 0.obs;
  final RxInt localAverageRespiratoryRate = 0.obs;
  final RxBool localIsRespiratoryRateAvailable = false.obs;

  // Animation variables for smooth transitions
  Timer? _stepAnimationTimer;
  int _targetStepCount = 0;
  int _currentAnimatedSteps = 0;

  // Cache variables
  static int? _cachedTotalRaceCount;
  static DateTime? _lastRaceCountUpdate;
  static const Duration _cacheExpiry = Duration(seconds: 10);

  // Timers
  Timer? _raceCountRefreshTimer;

  Future<void> initializeCriticalData() async {
    // Guard: Prevent duplicate initialization
    if (_isInitializing || _isFullyInitialized) {
      print('⏭️ HomepageDataService: Skipping duplicate initialization (initializing: $_isInitializing, initialized: $_isFullyInitialized)');
      return;
    }

    _isInitializing = true;
    print('🚀 HomepageDataService: Starting critical data initialization');

    // 📊 Start Firebase Performance trace
    final trace = FirebasePerformance.instance.newTrace('homepage_critical_init');
    await trace.start();

    try {
      // Only load essential user data that affects initial UI
      await loadUserName();
      isInitialLoading.value = false;
      print('✅ HomepageDataService: Critical data initialization complete');

      // 📊 Mark trace as successful
      trace.putAttribute('status', 'success');
    } catch (e) {
      print('❌ HomepageDataService: Error during critical data initialization: $e');
      isInitialLoading.value = false;

      // 📊 Mark trace as failed
      trace.putAttribute('status', 'failed');
      trace.putAttribute('error', e.toString());
      rethrow;
    } finally {
      _isInitializing = false;
      // 📊 Stop trace
      await trace.stop();
    }
  }

  Future<void> initializeSecondaryData() async {
    // Guard: Prevent duplicate initialization
    if (_isFullyInitialized) {
      print('⏭️ HomepageDataService: Secondary data already initialized');
      return;
    }

    if (_isInitializing) {
      print('⏳ HomepageDataService: Waiting for ongoing initialization to complete...');
      // Wait for ongoing initialization with timeout
      int attempts = 0;
      while (_isInitializing && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      if (_isFullyInitialized) {
        print('✅ HomepageDataService: Initialization already completed by another call');
        return;
      }
    }

    _isInitializing = true;
    print('🚀 HomepageDataService: Starting secondary data initialization');

    // 📊 Start Firebase Performance trace
    final trace = FirebasePerformance.instance.newTrace('homepage_secondary_init');
    await trace.start();

    try {
      // Load these in parallel after initial render
      await Future.wait([
        loadUserProfile(),
        loadRaceCountCached(),
        loadActiveJoinedRaceCount(),
      ]);

      // Initialize services
      await _initializeStepTrackingService();
      await _initializeRaceStepSyncService(); // Start race sync service to capture health sync steps
      await _initializeRaceInviteService();
      await _initializeHeartRateService();
      await _initializeRespiratoryDataService();

      isSecondaryDataLoaded.value = true;
      _isFullyInitialized = true;
      _setupOptimizedRefresh();

      print('✅ HomepageDataService: Secondary data initialization complete');

      // 📊 Mark trace as successful
      trace.putAttribute('status', 'success');
    } catch (e) {
      print('❌ HomepageDataService: Error during secondary data initialization: $e');

      // 📊 Mark trace as failed
      trace.putAttribute('status', 'failed');
      trace.putAttribute('error', e.toString());

      // Don't mark as fully initialized if there was an error
      rethrow;
    } finally {
      _isInitializing = false;
      // 📊 Stop trace
      await trace.stop();
    }
  }

  Future<void> loadUserName() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('user_profiles')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          // Try different possible field names for the user's name
          final name =
              userData['username'] ??
              userData['displayName'] ??
              userData['firstName'] ??
              userData['fullName'] ??
              'User';
          userName.value = name.toString();
        }
      }
    } catch (e) {
      // Handle error silently in production
      userName.value = 'User';
    }
  }

  Future<void> loadUserProfile() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final userBasicInfo = await UserProfileService.getUserBasicInfo(userId);
        if (userBasicInfo['profilePicture'] != null) {
          profileImageUrl.value = userBasicInfo['profilePicture']!;
        }
      }
    } catch (e) {
      // Handle error silently in production
      profileImageUrl.value = '';
    }
  }

  Future<void> loadRaceCountCached() async {
    try {
      // Check cache first
      if (_cachedTotalRaceCount != null &&
          _lastRaceCountUpdate != null &&
          DateTime.now().difference(_lastRaceCountUpdate!) < _cacheExpiry) {
        totalRaceCount.value = _cachedTotalRaceCount!;
        return;
      }

      // Fetch from Firebase if cache is expired
      final querySnapshot = await FirebaseFirestore.instance
          .collection('races')
          .get();

      // Filter out solo races that don't belong to current user (same logic as RacesListController)
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      int count = 0;

      for (final doc in querySnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final raceTypeId = data['raceTypeId'] as int?;
          final organizerUserId = data['organizerUserId'] as String?;
          final statusId = data['statusId'] as int?;

          // Filter out completed (4) and cancelled (7) races to match "All Races" screen
          if (statusId == 4 || statusId == 7) {
            continue; // Skip completed/cancelled races
          }

          // Filter out solo races that don't belong to the current user
          if (raceTypeId == 1) { // Solo race
            if (organizerUserId != currentUserId) {
              continue; // Skip this solo race as it doesn't belong to current user
            }
          }

          count++;
        } catch (e) {
          // Skip problematic race documents
          continue;
        }
      }

      // Update cache
      _cachedTotalRaceCount = count;
      _lastRaceCountUpdate = DateTime.now();
      totalRaceCount.value = count;
    } catch (e) {
      // Use cached value if available, otherwise set to 0
      totalRaceCount.value = _cachedTotalRaceCount ?? 0;
    }
  }

  // Stream subscription for real-time active race count
  StreamSubscription<QuerySnapshot>? _activeRaceCountSubscription;

  Future<void> loadActiveJoinedRaceCount() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        activeJoinedRaceCount.value = 0;
        return;
      }

      // Cancel existing subscription if any
      _activeRaceCountSubscription?.cancel();

      // Set up real-time listener for user's active races
      _activeRaceCountSubscription = FirebaseFirestore.instance
          .collection('races')
          .where(
            'status',
            whereIn: ['active', 'scheduled', 'waiting', 'starting'],
          )
          .snapshots()
          .listen(
            (snapshot) {
              ///TODO: PROCESSING ACTIVE RACES
              _processActiveRaceCount(snapshot, currentUserId);
            },
            onError: (error) {
              print('Error listening to active race count: $error');
              activeJoinedRaceCount.value = 0;
            },
          );
    } catch (e) {
      activeJoinedRaceCount.value = 0;
    }
  }

  void _processActiveRaceCount(QuerySnapshot snapshot, String currentUserId) {
    try {
      int count = 0;
      final now = DateTime.now();

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;

          // Check if user is organizer
          final isOrganizer = data['organizerUserId'] == currentUserId;

          // Check if user is participant (using proper participant structure)
          bool isParticipant = false;
          final participants = data['participants'] as List?;
          if (participants != null) {
            isParticipant = participants.any((p) {
              if (p is Map<String, dynamic>) {
                return p['userId'] == currentUserId;
              } else if (p is String) {
                return p == currentUserId;
              }
              return false;
            });
          }

          // Skip if user is neither organizer nor participant
          if (!isOrganizer && !isParticipant) {
            continue;
          }

          // Quick validation - skip expired races
          final scheduleTime = data['raceScheduleTime'] as String?;
          final duration = data['durationHrs'] as int?;

          if (scheduleTime != null && duration != null) {
            final raceEndTime = _calculateRaceEndTimeFromHours(
              scheduleTime,
              duration,
            );
            if (raceEndTime != null && now.isAfter(raceEndTime)) {
              continue;
            }
          }

          count++;
        } catch (e) {
          continue; // Skip problematic races
        }
      }

      activeJoinedRaceCount.value = count;
      print('Real-time active race count updated: $count');
    } catch (e) {
      print('Error processing active race count: $e');
      activeJoinedRaceCount.value = 0;
    }
  }

  DateTime? _calculateRaceEndTimeFromHours(
    String scheduleTime,
    int durationHrs,
  ) {
    try {
      DateTime startTime;

      // Try to parse as ISO format first
      try {
        startTime = DateTime.parse(scheduleTime);
      } catch (e) {
        // Try to parse the format "dd/MM/yyyy at hh:mm a"
        if (scheduleTime.contains(' at ')) {
          final parts = scheduleTime.split(' at ');
          if (parts.length >= 2) {
            final datePart = parts[0];
            final timePart = parts[1];

            final dateComponents = datePart.split('/');
            if (dateComponents.length == 3) {
              final day = int.parse(dateComponents[0]);
              final month = int.parse(dateComponents[1]);
              final year = int.parse(dateComponents[2]);

              // Parse time
              final timeComponents = timePart.toLowerCase().split(' ');
              final timeOnly = timeComponents[0];
              final amPm = timeComponents.length > 1 ? timeComponents[1] : '';

              final hourMinute = timeOnly.split(':');
              int hour = int.parse(hourMinute[0]);
              final minute = int.parse(hourMinute[1]);

              if (amPm == 'pm' && hour != 12) {
                hour += 12;
              } else if (amPm == 'am' && hour == 12) {
                hour = 0;
              }

              startTime = DateTime(year, month, day, hour, minute);
            } else {
              return null;
            }
          } else {
            return null;
          }
        } else {
          return null;
        }
      }

      return startTime.add(Duration(hours: durationHrs));
    } catch (e) {
      return null;
    }
  }

  DateTime? _calculateRaceEndTime(String scheduleTime, String duration) {
    try {
      DateTime startTime;

      // Try to parse as ISO format first
      try {
        startTime = DateTime.parse(scheduleTime);
      } catch (e) {
        // Try to parse the format "dd/MM/yyyy at hh:mm a"
        if (scheduleTime.contains(' at ')) {
          final parts = scheduleTime.split(' at ');
          if (parts.length >= 2) {
            final datePart = parts[0];
            final timePart = parts[1];

            final dateComponents = datePart.split('/');
            if (dateComponents.length == 3) {
              final day = int.parse(dateComponents[0]);
              final month = int.parse(dateComponents[1]);
              final year = int.parse(dateComponents[2]);

              // Parse time
              final timeComponents = timePart.toLowerCase().split(' ');
              final timeOnly = timeComponents[0];
              final amPm = timeComponents.length > 1 ? timeComponents[1] : '';

              final hourMinute = timeOnly.split(':');
              int hour = int.parse(hourMinute[0]);
              final minute = int.parse(hourMinute[1]);

              if (amPm == 'pm' && hour != 12) {
                hour += 12;
              } else if (amPm == 'am' && hour == 12) {
                hour = 0;
              }

              startTime = DateTime(year, month, day, hour, minute);
            } else {
              return null;
            }
          } else {
            return null;
          }
        } else {
          return null;
        }
      }

      // Parse duration (assuming format like "30 minutes", "1 hour", etc.)
      final durationParts = duration.toLowerCase().split(' ');
      if (durationParts.length >= 2) {
        final value = int.tryParse(durationParts[0]);
        final unit = durationParts[1];

        if (value != null) {
          Duration durationToAdd;
          if (unit.startsWith('minute')) {
            durationToAdd = Duration(minutes: value);
          } else if (unit.startsWith('hour')) {
            durationToAdd = Duration(hours: value);
          } else if (unit.startsWith('day')) {
            durationToAdd = Duration(days: value);
          } else {
            durationToAdd = Duration(minutes: value); // Default to minutes
          }

          return startTime.add(durationToAdd);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  void _setupOptimizedRefresh() {
    // Refresh race counts every 5 minutes (less aggressive)
    _raceCountRefreshTimer = Timer.periodic(const Duration(minutes: 5), (
      timer,
    ) {
      if (isSecondaryDataLoaded.value) {
        loadActiveJoinedRaceCount();
        loadRaceCountCached();
      }
    });
  }

  Future<void> _initializeStepTrackingService() async {
    // 📊 Start Firebase Performance trace
    final trace = FirebasePerformance.instance.newTrace('step_tracking_init');
    await trace.start();

    try {
      print('📊 HomepageDataService: Initializing StepTrackingService...');

      // Get or create the permanent step tracking service instance
      if (Get.isRegistered<StepTrackingService>()) {
        _stepTrackingService = Get.find<StepTrackingService>();
        print('✅ Found existing StepTrackingService instance');
        trace.putAttribute('service_type', 'existing');
      } else {
        _stepTrackingService = Get.put(StepTrackingService(), permanent: true);
        print('✅ Created new StepTrackingService instance');
        trace.putAttribute('service_type', 'new');
      }

      // ✅ OPTIMIZATION: Reduced timeout from 5s to 1s for faster startup
      // Wait for the service to be fully initialized
      if (_stepTrackingService != null) {
        // Wait for service initialization or timeout after 1 second
        int attempts = 0;
        const maxAttempts = 10; // 1 second with 100ms intervals (reduced from 50)

        while (!_stepTrackingService!.isInitialized.value &&
            attempts < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }

        if (!_stepTrackingService!.isInitialized.value) {
          print('⚠️ StepTrackingService initialization timeout after ${attempts * 100}ms (continuing in background)');
          trace.putAttribute('init_status', 'timeout');
          trace.setMetric('wait_time_ms', attempts * 100);
          // Continue anyway - service will continue initializing in background
          // UI will show skeleton until service is ready
        } else {
          print('✅ Step tracking service initialized after ${attempts * 100}ms');
          trace.putAttribute('init_status', 'success');
          trace.setMetric('wait_time_ms', attempts * 100);
        }

        print('📊 Today steps: ${_stepTrackingService?.todaySteps.value}');
        print('📊 Overall steps: ${_stepTrackingService?.overallSteps.value}');

        // Set initial values immediately
        _setInitialValues();
      }

      // Initialize period data with today's data by default
      _updatePeriodDataFromRealTime();

      // Set up listeners to sync local observables with service data
      if (_stepTrackingService != null) {
        // Listen for service initialization completion
        ever(_stepTrackingService!.isInitialized, (bool initialized) {
          if (initialized) {
            print('✅ StepTrackingService initialized - loading period data');
            // Retry loading period data now that service is ready
            _updatePeriodDataFromRealTime();
          }
        });

        // Listen to step changes and animate to new value
        // ✅ All listeners include disposal guards
        ever(_stepTrackingService!.todaySteps, (int steps) {
          if (!_isDisposed) {
            print('HomepageDataService: Today steps updated to $steps');
            _animateStepCount(steps);
          }
        });

        ever(_stepTrackingService!.overallSteps, (int steps) {
          if (!_isDisposed) {
            print('HomepageDataService: Overall steps updated to $steps');
            localOverallSteps.value = steps;
          }
        });

        ever(_stepTrackingService!.todayDistance, (double distance) {
          if (!_isDisposed) {
            print('HomepageDataService: Today distance updated to $distance');
            localTodayDistance.value = distance;
          }
        });

        ever(_stepTrackingService!.todayCalories, (int calories) {
          if (!_isDisposed) {
            print('HomepageDataService: Today calories updated to $calories');
            localTodayCalories.value = calories;
          }
        });

        ever(_stepTrackingService!.todayActiveTime, (int activeTime) {
          if (!_isDisposed) {
            localTodayActiveTime.value = activeTime;
          }
        });

        ever(_stepTrackingService!.overallDistance, (double distance) {
          if (!_isDisposed) {
            localOverallDistance.value = distance;
          }
        });

        ever(_stepTrackingService!.overallDays, (int days) {
          if (!_isDisposed) {
            print('📊 [HOMEPAGE_DATA] StepTrackingService overallDays changed: $days');
            print('📊 [HOMEPAGE_DATA] Setting localOverallDays.value = $days');
            localOverallDays.value = days;
            print('📊 [HOMEPAGE_DATA] localOverallDays.value is now: ${localOverallDays.value}');
          }
        });

        ever(_stepTrackingService!.pedestrianStatus, (String status) {
          if (!_isDisposed) {
            localPedestrianStatus.value = status;
          }
        });

        print('✅ StepTrackingService listeners configured');
      }

      // 📊 Mark trace as successful
      trace.putAttribute('status', 'success');
    } catch (e, stackTrace) {
      print('❌ Error initializing step tracking service: $e');
      print('📍 Stack trace: $stackTrace');

      // 📊 Mark trace as failed
      trace.putAttribute('status', 'failed');
      trace.putAttribute('error', e.toString());

      // Don't rethrow - allow app to continue with partial functionality
    } finally {
      // 📊 Stop trace
      await trace.stop();
    }
  }

  Future<void> _initializeRaceStepSyncService() async {
    try {
      print('🏁 HomepageDataService: Initializing RaceStepSyncService...');

      // Get or create the permanent race step sync service instance
      if (Get.isRegistered<RaceStepSyncService>()) {
        _raceStepSyncService = Get.find<RaceStepSyncService>();
        print('✅ Found existing RaceStepSyncService instance');
      } else {
        _raceStepSyncService = Get.put(RaceStepSyncService(), permanent: true);
        print('✅ Created new RaceStepSyncService instance');
      }

      // Initialize the service
      if (_raceStepSyncService != null) {
        await _raceStepSyncService!.initialize();
        print('✅ RaceStepSyncService initialized');

        // Start syncing if service is initialized
        await _raceStepSyncService!.startSyncing();
        print('✅ RaceStepSyncService started syncing to active races');
      }
    } catch (e, stackTrace) {
      print('❌ Error initializing race step sync service: $e');
      print('📍 Stack trace: $stackTrace');
      // Don't rethrow - allow app to continue with partial functionality
    }
  }

  void updateStepCount(int steps) {
    realTimeSteps.value = steps;
  }

  void _animateStepCount(int targetSteps) {
    _stepAnimationTimer?.cancel();
    _targetStepCount = targetSteps;

    final int startSteps = _currentAnimatedSteps;
    final int stepDifference = targetSteps - startSteps;

    if (stepDifference == 0) return;

    // Calculate animation duration based on step difference
    // Larger differences get longer animations but capped at 2 seconds
    final int animationDurationMs = (stepDifference.abs() * 15).clamp(
      300,
      2000,
    );
    const int intervalMs = 50; // Update every 50ms for smooth animation
    final int totalIntervals = animationDurationMs ~/ intervalMs;
    int currentInterval = 0;

    _stepAnimationTimer = Timer.periodic(Duration(milliseconds: intervalMs), (
      timer,
    ) {
      currentInterval++;
      final double progress = currentInterval / totalIntervals;

      if (progress >= 1.0) {
        _currentAnimatedSteps = targetSteps;
        localTodaySteps.value = targetSteps;
        timer.cancel();
      } else {
        // Use easeOut animation curve for natural feel
        final double easedProgress = 1.0 - math.pow(1.0 - progress, 3);
        _currentAnimatedSteps =
            startSteps + (stepDifference * easedProgress).round();
        localTodaySteps.value = _currentAnimatedSteps;
      }
    });
  }

  /// Set initial values from step tracking service
  void _setInitialValues() {
    try {
      if (_stepTrackingService == null) {
        print('⚠️ [HOMEPAGE_DATA] Cannot set initial values - StepTrackingService is null');
        return;
      }

      // Set all initial values immediately with null safety
      final currentTodaySteps = _stepTrackingService!.todaySteps.value ?? 0;
      localTodaySteps.value = currentTodaySteps;
      _currentAnimatedSteps = currentTodaySteps;
      _targetStepCount = currentTodaySteps;

      localOverallSteps.value = _stepTrackingService!.overallSteps.value ?? 0;
      localTodayDistance.value = _stepTrackingService!.todayDistance.value ?? 0.0;
      localTodayCalories.value = _stepTrackingService!.todayCalories.value ?? 0;
      localTodayActiveTime.value = _stepTrackingService!.todayActiveTime.value ?? 0;
      localOverallDistance.value = _stepTrackingService!.overallDistance.value ?? 0.0;
      localOverallDays.value = _stepTrackingService!.overallDays.value ?? 0;
      localPedestrianStatus.value =
          _stepTrackingService!.pedestrianStatus.value ?? 'unknown';

      print('📊 [HOMEPAGE_DATA] Initial values set from StepTrackingService:');
      print('   Today Steps: $currentTodaySteps');
      print('   Overall Steps: ${localOverallSteps.value}');
      print('   Overall Distance: ${localOverallDistance.value}');
      print('   Overall Days: ${localOverallDays.value}');
      print('   Distance: ${localTodayDistance.value}');
    } catch (e, stackTrace) {
      print('❌ [HOMEPAGE_DATA] Error setting initial values: $e');
      print('📍 Stack trace: $stackTrace');
      // Set safe default values
      localTodaySteps.value = 0;
      localOverallSteps.value = 0;
      localTodayDistance.value = 0.0;
      localOverallDistance.value = 0.0;
      localOverallDays.value = 0;
    }
  }

  // Getters for step tracking data - return local observables
  RxInt get overallSteps => localOverallSteps;

  RxDouble get overallDistance => localOverallDistance;

  RxInt get overallDays => localOverallDays;

  RxInt get todaySteps => localTodaySteps;

  RxDouble get todayDistance => localTodayDistance;

  RxInt get todayCalories => localTodayCalories;

  RxInt get todayActiveTime => localTodayActiveTime;

  RxString get pedestrianStatus => localPedestrianStatus;

  // Getters for heart rate data - return local observables
  RxInt get currentHeartRate => localCurrentHeartRate;
  RxInt get averageHeartRate => localAverageHeartRate;
  RxBool get isHeartRateAvailable => localIsHeartRateAvailable;

  /// Get display text for heart rate
  String get heartRateDisplayText {
    if (!localIsHeartRateAvailable.value) return '--';
    if (localCurrentHeartRate.value == 0) return '--';
    return localCurrentHeartRate.value.toString();
  }

  // Getters for respiratory data - return local observables
  RxInt get currentBloodOxygen => localCurrentBloodOxygen;
  RxInt get averageBloodOxygen => localAverageBloodOxygen;
  RxBool get isBloodOxygenAvailable => localIsBloodOxygenAvailable;
  RxInt get currentRespiratoryRate => localCurrentRespiratoryRate;
  RxInt get averageRespiratoryRate => localAverageRespiratoryRate;
  RxBool get isRespiratoryRateAvailable => localIsRespiratoryRateAvailable;

  Future<void> _initializeRaceInviteService() async {
    try {
      print('📨 HomepageDataService: Initializing RaceInviteService...');

      // Initialize race invite service
      _raceInviteService = RaceInviteService();

      // Set up real-time listener for pending received invites count with error handling
      // ✅ Add disposal guards to prevent updates on disposed service
      _raceInviteService!.getPendingInvitesCount().listen(
        (count) {
          if (!_isDisposed) {  // ✅ Guard against disposed state
            pendingInvitesCount.value = count;
            print(
              'HomepageDataService: Pending received invites count updated to $count',
            );
          }
        },
        onError: (error) {
          if (!_isDisposed) {  // ✅ Guard against disposed state
            print('❌ Error listening to pending invites count: $error');
            // Set to 0 on error to prevent showing stale data
            pendingInvitesCount.value = 0;

            // ✅ Log to Sentry for production monitoring
            try {
              // Sentry.captureException(error);
            } catch (_) {}
          }
        },
        cancelOnError: false, // Continue listening even after errors
      );

      print('✅ Race invite service initialized successfully');

      // Check for any manually accepted invites that might need processing
      await _raceInviteService!.checkAndProcessManuallyAcceptedInvites();
    } catch (e, stackTrace) {
      print('❌ Error initializing race invite service: $e');
      print('📍 Stack trace: $stackTrace');
      // Ensure pendingInvitesCount is set to 0 if initialization fails
      pendingInvitesCount.value = 0;

      // Retry initialization after a delay (max 1 retry)
      if (_raceInviteService == null) {
        Future.delayed(const Duration(seconds: 3), () {
          if (_raceInviteService == null && _isFullyInitialized) {
            print('🔄 Retrying race invite service initialization...');
            _initializeRaceInviteService();
          }
        });
      }
    }
  }

  /// Manually refresh pending invites count
  void loadPendingInvitesCount() {
    // The count is automatically updated via stream listener
    // This method can be called to trigger a manual refresh if needed
    try {
      if (_raceInviteService != null) {
        print('✅ Refreshing pending invites count stream');
        // Force a refresh by re-initializing the listener if needed
      } else {
        print(
          'Race invite service not initialized, attempting to initialize...',
        );
        _initializeRaceInviteService();
      }
    } catch (e) {
      print('Error refreshing pending invites count: $e');
      // Try to reinitialize the service
      _initializeRaceInviteService();
    }
  }

  Future<void> _initializeHeartRateService() async {
    // 📊 Start Firebase Performance trace
    final trace = FirebasePerformance.instance.newTrace('heart_rate_init');
    await trace.start();

    try {
      print('💓 HomepageDataService: Initializing HeartRateService...');

      // Get or create the permanent heart rate service instance
      if (Get.isRegistered<HeartRateService>()) {
        _heartRateService = Get.find<HeartRateService>();
        print('✅ Found existing HeartRateService instance');
        trace.putAttribute('service_type', 'existing');
      } else {
        _heartRateService = Get.put(HeartRateService(), permanent: true);
        print('✅ Created new HeartRateService instance');
        trace.putAttribute('service_type', 'new');
      }

      // ✅ OPTIMIZATION: Reduced timeout from 3s to 500ms for faster startup
      // Wait for the service to be fully initialized
      if (_heartRateService != null) {
        // Wait for service initialization or timeout after 500ms
        int attempts = 0;
        const maxAttempts = 5; // 500ms with 100ms intervals (reduced from 30)

        while (!_heartRateService!.isInitialized.value && attempts < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }

        if (!_heartRateService!.isInitialized.value) {
          print('⚠️ HeartRateService initialization timeout after ${attempts * 100}ms (continuing in background)');
          trace.putAttribute('init_status', 'timeout');
          trace.setMetric('wait_time_ms', attempts * 100);
          // Continue anyway - service will continue initializing in background
          // UI will show placeholder until service is ready
        } else {
          print('✅ Heart rate service initialized after ${attempts * 100}ms');
          trace.putAttribute('init_status', 'success');
          trace.setMetric('wait_time_ms', attempts * 100);
        }

        print('💓 Current heart rate: ${_heartRateService?.currentHeartRate.value}');
        print('💓 Heart rate available: ${_heartRateService?.isHeartRateAvailable.value}');

        // Set initial values immediately
        _setInitialHeartRateValues();
      }

      // Set up listeners to sync local observables with service data
      // ✅ All listeners include disposal guards
      if (_heartRateService != null) {
        ever(_heartRateService!.currentHeartRate, (int heartRate) {
          if (!_isDisposed) {
            print('HomepageDataService: Current heart rate updated to $heartRate');
            localCurrentHeartRate.value = heartRate;
          }
        });

        ever(_heartRateService!.averageHeartRate, (int avgHeartRate) {
          if (!_isDisposed) {
            print('HomepageDataService: Average heart rate updated to $avgHeartRate');
            localAverageHeartRate.value = avgHeartRate;
          }
        });

        ever(_heartRateService!.isHeartRateAvailable, (bool available) {
          if (!_isDisposed) {
            print('HomepageDataService: Heart rate availability updated to $available');
            localIsHeartRateAvailable.value = available;
          }
        });

        print('✅ HeartRateService listeners configured');
      }

      // 📊 Mark trace as successful
      trace.putAttribute('status', 'success');
    } catch (e, stackTrace) {
      print('❌ Error initializing heart rate service: $e');
      print('📍 Stack trace: $stackTrace');

      // 📊 Mark trace as failed
      trace.putAttribute('status', 'failed');
      trace.putAttribute('error', e.toString());

      // Don't rethrow - allow app to continue with partial functionality
    } finally {
      // 📊 Stop trace
      await trace.stop();
    }
  }

  /// Set initial heart rate values from heart rate service
  void _setInitialHeartRateValues() {
    try {
      if (_heartRateService == null) {
        print('⚠️ [HOMEPAGE_DATA] Cannot set initial heart rate values - HeartRateService is null');
        return;
      }

      // Set all initial heart rate values immediately with null safety
      localCurrentHeartRate.value = _heartRateService!.currentHeartRate.value ?? 0;
      localAverageHeartRate.value = _heartRateService!.averageHeartRate.value ?? 0;
      localIsHeartRateAvailable.value = _heartRateService!.isHeartRateAvailable.value ?? false;

      print(
        '✅ Initial heart rate values set: Current=${localCurrentHeartRate.value}, Available=${localIsHeartRateAvailable.value}',
      );
    } catch (e, stackTrace) {
      print('❌ [HOMEPAGE_DATA] Error setting initial heart rate values: $e');
      print('📍 Stack trace: $stackTrace');
      // Set safe default values
      localCurrentHeartRate.value = 0;
      localAverageHeartRate.value = 0;
      localIsHeartRateAvailable.value = false;
    }
  }

  /// Manually refresh heart rate data
  Future<void> refreshHeartRate() async {
    try {
      if (_heartRateService != null) {
        await _heartRateService!.refreshHeartRate();
      } else {
        print('⚠️ Cannot refresh heart rate - HeartRateService is null');
      }
    } catch (e) {
      print('❌ Error refreshing heart rate: $e');
    }
  }

  Future<void> _initializeRespiratoryDataService() async {
    // 📊 Start Firebase Performance trace
    final trace = FirebasePerformance.instance.newTrace('respiratory_data_init');
    await trace.start();

    try {
      print('🫁 HomepageDataService: Initializing RespiratoryDataService...');

      // Get or create the permanent respiratory data service instance
      if (Get.isRegistered<RespiratoryDataService>()) {
        _respiratoryDataService = Get.find<RespiratoryDataService>();
        print('✅ Found existing RespiratoryDataService instance');
        trace.putAttribute('service_type', 'existing');
      } else {
        _respiratoryDataService = Get.put(RespiratoryDataService(), permanent: true);
        print('✅ Created new RespiratoryDataService instance');
        trace.putAttribute('service_type', 'new');
      }

      // ✅ OPTIMIZATION: Reduced timeout from 3s to 500ms for faster startup
      // Wait for the service to be fully initialized
      if (_respiratoryDataService != null) {
        // Wait for service initialization or timeout after 500ms
        int attempts = 0;
        const maxAttempts = 5; // 500ms with 100ms intervals (reduced from 30)

        while (!_respiratoryDataService!.isInitialized.value && attempts < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }

        if (!_respiratoryDataService!.isInitialized.value) {
          print('⚠️ RespiratoryDataService initialization timeout after ${attempts * 100}ms (continuing in background)');
          trace.putAttribute('init_status', 'timeout');
          trace.setMetric('wait_time_ms', attempts * 100);
          // Continue anyway - service will continue initializing in background
          // UI will show placeholder until service is ready
        } else {
          print('✅ Respiratory data service initialized after ${attempts * 100}ms');
          trace.putAttribute('init_status', 'success');
          trace.setMetric('wait_time_ms', attempts * 100);
        }

        print('🫁 Current blood oxygen: ${_respiratoryDataService?.currentBloodOxygen.value}');
        print('🫁 Current respiratory rate: ${_respiratoryDataService?.currentRespiratoryRate.value}');
        print('🫁 Blood oxygen available: ${_respiratoryDataService?.isBloodOxygenAvailable.value}');
        print('🫁 Respiratory rate available: ${_respiratoryDataService?.isRespiratoryRateAvailable.value}');

        // Set initial values immediately
        _setInitialRespiratoryDataValues();
      }

      // Set up listeners to sync local observables with service data
      // ✅ All listeners include disposal guards
      if (_respiratoryDataService != null) {
        ever(_respiratoryDataService!.currentBloodOxygen, (int bloodOxygen) {
          if (!_isDisposed) {
            print('HomepageDataService: Current blood oxygen updated to $bloodOxygen');
            localCurrentBloodOxygen.value = bloodOxygen;
          }
        });

        ever(_respiratoryDataService!.averageBloodOxygen, (int avgBloodOxygen) {
          if (!_isDisposed) {
            print('HomepageDataService: Average blood oxygen updated to $avgBloodOxygen');
            localAverageBloodOxygen.value = avgBloodOxygen;
          }
        });

        ever(_respiratoryDataService!.isBloodOxygenAvailable, (bool available) {
          if (!_isDisposed) {
            print('HomepageDataService: Blood oxygen availability updated to $available');
            localIsBloodOxygenAvailable.value = available;
          }
        });

        ever(_respiratoryDataService!.currentRespiratoryRate, (int respiratoryRate) {
          if (!_isDisposed) {
            print('HomepageDataService: Current respiratory rate updated to $respiratoryRate');
            localCurrentRespiratoryRate.value = respiratoryRate;
          }
        });

        ever(_respiratoryDataService!.averageRespiratoryRate, (int avgRespiratoryRate) {
          if (!_isDisposed) {
            print('HomepageDataService: Average respiratory rate updated to $avgRespiratoryRate');
            localAverageRespiratoryRate.value = avgRespiratoryRate;
          }
        });

        ever(_respiratoryDataService!.isRespiratoryRateAvailable, (bool available) {
          if (!_isDisposed) {
            print('HomepageDataService: Respiratory rate availability updated to $available');
            localIsRespiratoryRateAvailable.value = available;
          }
        });

        print('✅ RespiratoryDataService listeners configured');
      }

      // 📊 Mark trace as successful
      trace.putAttribute('status', 'success');
    } catch (e, stackTrace) {
      print('❌ Error initializing respiratory data service: $e');
      print('📍 Stack trace: $stackTrace');

      // 📊 Mark trace as failed
      trace.putAttribute('status', 'failed');
      trace.putAttribute('error', e.toString());

      // Don't rethrow - allow app to continue with partial functionality
    } finally {
      // 📊 Stop trace
      await trace.stop();
    }
  }

  /// Set initial respiratory data values from respiratory data service
  void _setInitialRespiratoryDataValues() {
    try {
      if (_respiratoryDataService == null) {
        print('⚠️ [HOMEPAGE_DATA] Cannot set initial respiratory data values - RespiratoryDataService is null');
        return;
      }

      // Set all initial respiratory data values immediately with null safety
      localCurrentBloodOxygen.value = _respiratoryDataService!.currentBloodOxygen.value;
      localAverageBloodOxygen.value = _respiratoryDataService!.averageBloodOxygen.value;
      localIsBloodOxygenAvailable.value = _respiratoryDataService!.isBloodOxygenAvailable.value;
      localCurrentRespiratoryRate.value = _respiratoryDataService!.currentRespiratoryRate.value;
      localAverageRespiratoryRate.value = _respiratoryDataService!.averageRespiratoryRate.value;
      localIsRespiratoryRateAvailable.value = _respiratoryDataService!.isRespiratoryRateAvailable.value;

      print(
        '✅ Initial respiratory data values set: BloodO2=${localCurrentBloodOxygen.value}%, RespiratoryRate=${localCurrentRespiratoryRate.value} RPM',
      );
    } catch (e, stackTrace) {
      print('❌ [HOMEPAGE_DATA] Error setting initial respiratory data values: $e');
      print('📍 Stack trace: $stackTrace');
      // Set safe default values
      localCurrentBloodOxygen.value = 0;
      localAverageBloodOxygen.value = 0;
      localIsBloodOxygenAvailable.value = false;
      localCurrentRespiratoryRate.value = 0;
      localAverageRespiratoryRate.value = 0;
      localIsRespiratoryRateAvailable.value = false;
    }
  }

  /// Manually refresh respiratory data
  Future<void> refreshRespiratoryData() async {
    try {
      if (_respiratoryDataService != null) {
        await _respiratoryDataService!.refreshRespiratoryData();
      } else {
        print('⚠️ Cannot refresh respiratory data - RespiratoryDataService is null');
      }
    } catch (e) {
      print('❌ Error refreshing respiratory data: $e');
    }
  }

  /// Load period-based analytics data using Firebase aggregation
  Future<void> loadPeriodData(String period) async {
    // 📊 Start Firebase Performance trace
    final trace = FirebasePerformance.instance.newTrace('load_period_data');
    await trace.start();
    trace.putAttribute('period', period);

    try {
      isLoadingPeriodData.value = true;

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        trace.putAttribute('status', 'no_user');
        await trace.stop();
        return;
      }

      // For "Today", use real-time data from StepTrackingService
      if (period.toLowerCase() == 'today') {
        trace.putAttribute('data_source', 'real_time');
        _updatePeriodDataFromRealTime();
        trace.putAttribute('status', 'success');
        await trace.stop();
        return;
      }

      // For all other periods, use Firebase aggregation via StepTrackingService
      trace.putAttribute('data_source', 'firebase_aggregation');

      // Guard: Check if step tracking service is available
      if (_stepTrackingService == null) {
        print('⚠️ StepTrackingService not initialized, falling back to today\'s data');
        trace.putAttribute('status', 'service_not_initialized');
        _updatePeriodDataFromRealTime();
        await trace.stop();
        return;
      }

      // Get statistics from Firebase using the new aggregation method
      final stats = await _stepTrackingService!.getStatisticsForFilter(period);

      // Always show period stats, even if 0 (accurate data integrity)
      _updatePeriodDataFromStats(stats);
      print('✅ Loaded $period analytics from Firebase: ${stats['totalSteps']} steps, ${stats['totalDays']} days');
      trace.putAttribute('status', 'success');
      trace.setMetric('steps_loaded', stats['totalSteps'] ?? 0);

    } catch (e) {
      print('❌ Error loading period data for $period: $e');
      trace.putAttribute('status', 'error');
      trace.putAttribute('error', e.toString());
      // Fallback to today's data on error
      _updatePeriodDataFromRealTime();
    } finally {
      isLoadingPeriodData.value = false;
      // 📊 Stop trace if not already stopped
      if (trace.hashCode != 0) {
        await trace.stop();
      }
    }
  }

  /// Update period data from real-time step tracking service (for "Today")
  void _updatePeriodDataFromRealTime() {
    try {
      // ✅ CRITICAL: Comprehensive null safety checks
      if (_stepTrackingService == null) {
        print('⚠️ StepTrackingService is null - keeping loading state');
        isLoadingPeriodData.value = true;
        return;  // Don't proceed if service doesn't exist
      }

      if (!_stepTrackingService!.isInitialized.value) {
        print('⚠️ StepTrackingService not initialized - scheduling retry');
        isLoadingPeriodData.value = true;

        // ✅ Schedule retry after 500ms instead of immediate failure
        Future.delayed(Duration(milliseconds: 500), () {
          // Only retry if still loading (user might have switched filters)
          if (isLoadingPeriodData.value) {
            _updatePeriodDataFromRealTime();
          }
        });
        return;
      }

      print('✅ Updating period data from StepTrackingService');

      // ✅ Wrap all service accesses with null-coalescing for safety
      periodSteps.value = _stepTrackingService?.todaySteps.value ?? 0;
      periodDistance.value = _stepTrackingService?.todayDistance.value ?? 0.0;
      periodCalories.value = _stepTrackingService?.todayCalories.value ?? 0;
      periodActiveTime.value = _stepTrackingService?.todayActiveTime.value ?? 0;

      // Calculate average speed with null safety
      if (periodActiveTime.value > 0 && periodDistance.value > 0) {
        final hours = periodActiveTime.value / 60.0;
        periodSpeed.value = hours > 0 ? periodDistance.value / hours : 0.0;
      } else {
        periodSpeed.value = 0.0;
      }

      isLoadingPeriodData.value = false;
      print('📊 Period data updated: ${periodSteps.value} steps, ${periodDistance.value}km');
    } catch (e, stackTrace) {
      // ✅ Log to Sentry for production monitoring
      try {
        // Sentry will be available after initialization
        // Sentry.captureException(e, stackTrace: stackTrace);
      } catch (_) {
        // Sentry might not be initialized yet
      }

      print('❌ Error updating period data from real-time: $e');
      print('📍 Stack trace: $stackTrace');

      // Don't set to 0 immediately - keep loading and retry
      isLoadingPeriodData.value = true;

      // Schedule retry after error
      Future.delayed(Duration(seconds: 1), () {
        if (isLoadingPeriodData.value) {
          _updatePeriodDataFromRealTime();
        }
      });
    }
  }

  /// Update period data from database statistics
  void _updatePeriodDataFromStats(Map<String, dynamic> stats) {
    periodSteps.value = stats['totalSteps'] ?? 0;
    periodDistance.value = (stats['totalDistance'] ?? 0.0).toDouble();
    periodCalories.value = (stats['totalCalories'] ?? 0).round();
    periodActiveTime.value = stats['totalActiveTime'] ?? 0;
    periodSpeed.value = (stats['averageSpeed'] ?? 0.0).toDouble();
  }

  /// Get homepage statistics combining overall and period data
  /// Uses Firebase aggregation for accurate statistics
  Future<Map<String, dynamic>> getHomepageStats({String period = 'Today'}) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return {};

      // Get overall statistics from StepTrackingService (Firebase-based)
      final overallStats = {
        'totalSteps': _stepTrackingService?.overallSteps.value ?? 0,
        'totalDistance': _stepTrackingService?.overallDistance.value ?? 0.0,
        'totalDays': _stepTrackingService?.overallDays.value ?? 0,
      };

      // Get period statistics from Firebase aggregation
      final periodStats = await _stepTrackingService?.getStatisticsForFilter(period) ?? {};

      return {
        'overallStats': overallStats,
        'periodStats': periodStats,
        'availablePeriods': availablePeriods,
      };
    } catch (e) {
      print('❌ Error getting homepage stats: $e');
      return {
        'overallStats': {'totalSteps': 0, 'totalDistance': 0.0, 'totalDays': 0},
        'periodStats': {'totalSteps': 0, 'totalDistance': 0.0, 'totalDays': 0},
        'availablePeriods': availablePeriods,
      };
    }
  }

  /// Get available period options for filtering
  List<String> get availablePeriods => [
    'Today',
    'Yesterday',
    'Last 7 days',
    'Last 30 days',
    'Last 60 days',
    'Last 90 days',
    'All time'
  ];

  /// Reset initialization state (useful during auth transitions)
  void resetInitializationState() {
    print('🔄 HomepageDataService: Resetting initialization state');
    _isInitializing = false;
    _isFullyInitialized = false;
    isInitialLoading.value = true;
    isSecondaryDataLoaded.value = false;
  }

  // ================== HEALTH SYNC INTEGRATION ==================

  /// ✅ OPTIMIZATION: Sync health data in background without blocking UI
  /// This runs asynchronously after the UI is displayed to the user
  Future<void> syncHealthDataOnColdStart(BuildContext context) async {
    // ✅ Run health sync in background to avoid blocking UI
    Future.microtask(() async {
      try {
        print('🏥 [HOMEPAGE_DATA] Starting background health sync...');

        // Initialize health sync service if not already done
        if (_healthSyncService == null) {
          if (Get.isRegistered<HealthSyncService>()) {
            _healthSyncService = Get.find<HealthSyncService>();
          } else {
            _healthSyncService = Get.put(HealthSyncService(), permanent: true);
          }
        }

        // ✅ OPTIMIZATION: No artificial delays - check permissions immediately
        // Permissions are now requested in background, not blocking UI
        print('🏥 [HOMEPAGE_DATA] Checking health permissions...');

        // Check if permissions already granted (don't request if not needed)
        if (!_healthSyncService!.hasPermissions.value) {
          print('🏥 [HOMEPAGE_DATA] Requesting health permissions in background...');
          // ✅ FIX: Skip onboarding for background sync on cold start
          // Onboarding will be shown when user explicitly enables health sync via UI
          final granted = await _healthSyncService!.requestPermissions(skipOnboarding: true);
          if (!granted) {
            print('🏥 [HOMEPAGE_DATA] Health permissions denied by user');
            return;
          }
          print('🏥 [HOMEPAGE_DATA] ✅ Health permissions granted successfully');
        }

        // Now check if health services are available
        if (!_healthSyncService!.isHealthAvailable.value) {
          print('🏥 [HOMEPAGE_DATA] Health services not available on this device');
          return;
        }

        // ✅ Show sync dialog using Get.dialog to avoid context.mounted issues
        // Get.dialog doesn't require context.mounted check as it uses Get's navigation
        print('🏥 [HOMEPAGE_DATA] Showing health sync dialog...');
        Get.dialog(
          HealthSyncDialog(
            syncStatusStream: _healthSyncService!.syncStatusStream,
            onSyncComplete: () async {
              print('✅ [HOMEPAGE_DATA] Sync dialog dismissed');

              // Request location permission after health sync completes
              if (context.mounted) {
                await _requestLocationPermissionAfterSync(context);
              }
            },
          ),
          barrierDismissible: false,
          barrierColor: Colors.black.withOpacity(0.7),
        );

        // Perform sync with forceSync=true on cold start
        print('🏥 [HOMEPAGE_DATA] Starting background health sync (non-blocking)...');
        final syncResult = await _healthSyncService!.syncHealthData(forceSync: true);

        if (syncResult.isSuccess && syncResult.data != null) {
          print('🏥 [HOMEPAGE_DATA] Health sync successful, updating step tracking...');
          await _updateStepTrackingFromHealthSync(syncResult.data!);
          print('✅ [HOMEPAGE_DATA] Background health sync completed successfully');
        } else {
          print('🏥 [HOMEPAGE_DATA] Health sync failed or returned no data');
        }
      } catch (e, stackTrace) {
        print('❌ [HOMEPAGE_DATA] Error during background health sync: $e');
        print('📍 Stack trace: $stackTrace');
      }
    });

    // Return immediately - sync continues in background
    print('✅ [HOMEPAGE_DATA] Health sync started in background (non-blocking)');
  }

  /// Update step tracking service with health sync data
  /// NOTE: No longer needed - HealthSyncService now calls updateFromHealthSync() directly
  /// This method is kept for logging purposes only
  Future<void> _updateStepTrackingFromHealthSync(HealthSyncData healthData) async {
    try {
      print('🏥 [HOMEPAGE_DATA] Health sync data received:');
      print('   Today Steps: ${healthData.todaySteps}');
      print('   Today Distance: ${healthData.todayDistance} km');
      print('   Today Calories: ${healthData.todayCalories}');
      print('   Overall Steps: ${healthData.overallSteps}');
      print('   Overall Distance: ${healthData.overallDistance} km');
      print('   Overall Days: ${healthData.overallDays}');

      // ✅ REMOVED: HealthSyncService now handles updateFromHealthSync() directly
      // This prevents double-calling which was causing negative overall steps on Android
      // await _stepTrackingService!.updateFromHealthSync(...);

      print('✅ [HOMEPAGE_DATA] Step tracking updated successfully from health sync');
    } catch (e, stackTrace) {
      print('❌ [HOMEPAGE_DATA] Error logging health sync data: $e');
      print('📍 Stack trace: $stackTrace');
    }
  }

  /// Request location permission after health sync completes
  /// Shows explanation dialog and requests "Always Allow" permission for background tracking
  Future<void> _requestLocationPermissionAfterSync(BuildContext context) async {
    try {
      print('📍 [HOMEPAGE_DATA] Checking location permission status...');

      // Check if location permission is already granted
      final hasPermission = await PermissionService.hasBackgroundLocationPermission();
      if (hasPermission) {
        print('✅ [HOMEPAGE_DATA] Location permission already granted');

        // Start background location tracking if not already running
        final locationService = BackgroundLocationService();
        if (!locationService.isTracking) {
          print('📍 [HOMEPAGE_DATA] Starting background location service (permission already granted)');
          final started = await locationService.startBackgroundTracking();
          if (started) {
            print('✅ [HOMEPAGE_DATA] Background location tracking started');
          }
        } else {
          print('✅ [HOMEPAGE_DATA] Background location tracking already active');
        }
        return;
      }

      // Check if dialog has already been shown
      final prefsService = PreferencesService();
      final hasShownDialog = await prefsService.hasShownBackgroundLocationDialog();
      if (hasShownDialog) {
        print('ℹ️ [HOMEPAGE_DATA] Background location dialog already shown previously');
        return;
      }



      if (!context.mounted) return;


    } catch (e, stackTrace) {
      print('❌ [HOMEPAGE_DATA] Error requesting location permission: $e');
      print('📍 Stack trace: $stackTrace');
    }
  }

  // ================== END HEALTH SYNC INTEGRATION ==================

  // ================== CHART DATA INTEGRATION ==================

  /// Get current period data for charts
  /// Returns a map with all current period statistics
  Map<String, dynamic> getChartPeriodData() {
    return {
      'steps': periodSteps.value,
      'distance': periodDistance.value,
      'activeTime': periodActiveTime.value,
      'calories': periodCalories.value,
      'speed': periodSpeed.value,
    };
  }

  // ================== END CHART DATA INTEGRATION ==================

  @override
  void onClose() {
    _raceCountRefreshTimer?.cancel();
    _stepAnimationTimer?.cancel();
    _activeRaceCountSubscription?.cancel();
    _isDisposed = true;  // ✅ Mark as disposed to prevent further updates
    super.onClose();
  }
}
