import 'dart:developer';
import 'dart:math' as dart_math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../../core/models/race_data_model.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../database/step_database.dart';
import '../../models/daily_step_data.dart';
import '../../models/place_model.dart';
import '../../services/auth/firebase_auth_service.dart';
import '../../services/firebase_service.dart';
import '../../services/health_sync_coordinator.dart';
import '../../services/health_sync_service.dart';
import '../../services/places_service.dart';
import '../../services/preferences_service.dart';
import '../../services/step_tracking_service.dart';
import '../../screens/races/quick_race/quick_race_waiting_room_screen.dart';

class QuickRaceController extends GetxController {
  // Observable variables
  final RxInt selectedParticipants = 2.obs;
  final RxDouble selectedDistance = 1.0.obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingLocation = false.obs;
  final RxString currentAddress = 'Getting your location...'.obs;

  // Location coordinates
  final Rx<double?> currentLat = Rx<double?>(null);
  final Rx<double?> currentLng = Rx<double?>(null);

  // Location category selection
  final Rx<LocationCategory> selectedLocationCategory = LocationCategory.currentLocation.obs;
  final Rx<QuickRaceStartLocation?> selectedStartLocation = Rx<QuickRaceStartLocation?>(null);

  // Firebase service
  late final FirebaseService _firebaseService;

  @override
  void onInit() {
    super.onInit();
    _firebaseService = Get.find<FirebaseService>();
    _loadCurrentLocation();
  }

  /// Load current location automatically on init
  Future<void> _loadCurrentLocation() async {
    try {
      isLoadingLocation.value = true;

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        currentAddress.value = 'Location permission denied';
        SnackbarUtils.showError(
          'Permission Denied',
          'Please enable location permissions to create quick races',
        );
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        currentAddress.value = 'Location services disabled';
        SnackbarUtils.showError(
          'Location Disabled',
          'Please enable location services to create quick races',
        );
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      currentLat.value = position.latitude;
      currentLng.value = position.longitude;

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address = '${placemark.locality ?? ''}, ${placemark.administrativeArea ?? ''}, ${placemark.country ?? ''}'
            .replaceAll(RegExp(r'^,\s*|,\s*$'), '')
            .replaceAll(RegExp(r',\s*,'), ',');

        currentAddress.value = address.trim().isNotEmpty ? address.trim() : 'Current location';
      } else {
        currentAddress.value = 'Current location';
      }

      // Set default selected start location to current location
      selectedStartLocation.value = QuickRaceStartLocation.fromCurrentLocation(
        address: currentAddress.value,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      log('📍 Location loaded: ${currentAddress.value} (${position.latitude}, ${position.longitude})');
    } catch (e) {
      log('❌ Error getting current location: $e');
      currentAddress.value = 'Unable to get location';
      SnackbarUtils.showError(
        'Location Error',
        'Could not get your current location. Please try again.',
      );
    } finally {
      isLoadingLocation.value = false;
    }
  }

  /// Handle location category selection
  void selectLocationCategory(LocationCategory category) {
    selectedLocationCategory.value = category;

    // Reset to current location when selecting current location category
    if (category == LocationCategory.currentLocation && currentLat.value != null && currentLng.value != null) {
      selectedStartLocation.value = QuickRaceStartLocation.fromCurrentLocation(
        address: currentAddress.value,
        latitude: currentLat.value!,
        longitude: currentLng.value!,
      );
      log('✅ Reset to current location');
    }
    // For other categories, user needs to select from the list
  }

  /// Set custom start location from place result
  void setCustomStartLocation(PlaceResult place) {
    selectedStartLocation.value = QuickRaceStartLocation.fromPlaceResult(
      place: place,
      category: selectedLocationCategory.value,
    );
    log('✅ Selected start location: ${place.displayName}');
  }

  /// Get the actual start coordinates to use for race creation
  Map<String, double> _getStartCoordinates() {
    final location = selectedStartLocation.value;
    if (location != null) {
      return {
        'lat': location.latitude,
        'lng': location.longitude,
      };
    }
    // Fallback to current location
    return {
      'lat': currentLat.value ?? 0.0,
      'lng': currentLng.value ?? 0.0,
    };
  }

  /// Get the start address to use for race creation
  String _getStartAddress() {
    final location = selectedStartLocation.value;
    if (location != null && location.name != 'Current Location') {
      return '${location.name}, ${location.address}';
    }
    return currentAddress.value;
  }

  /// Find and atomically join matching quick race using transaction
  /// This prevents race condition when multiple users tap simultaneously
  Future<RaceData?> _findAndJoinMatchingQuickRace() async {
    try {
      // Only match races created in last 30 seconds (during countdown)
      final cutoffTime = DateTime.now().subtract(Duration(seconds: 30));
      final currentUser = await FirebaseAuthService.currentUser;

      if (currentUser == null) return null;

      // Get potential matching races (without transaction first for performance)
      final matchingRaces = await _firebaseService.firestore
          .collection('races')
          .where('raceTypeId', isEqualTo: 5) // Quick Race
          .where('maxParticipants', isEqualTo: selectedParticipants.value)
          .where('totalDistance', isEqualTo: selectedDistance.value)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoffTime))
          .orderBy('createdAt', descending: false) // Join oldest first
          .limit(3) // Get top 3 to try in case first is full
          .get();

      if (matchingRaces.docs.isEmpty) {
        log('📝 No matching races found');
        return null;
      }

      // ✅ CRITICAL: Capture baseline BEFORE transaction (outside transaction for performance)
      // We'll capture for the first race attempt and reuse if we retry with another race
      log('📊 [QUICK_RACE] Pre-capturing baseline for joiner before transaction...');

      // Use the multi-source fallback to get baseline
      // Note: We need a temporary raceId for the _captureBaseline call, but we'll override it later
      final Map<String, dynamic>? baselineData = await _captureBaseline('temp', currentUser.uid);

      // 🛡️ VALIDATION: Block race join if baseline capture fails
      if (baselineData == null) {
        log('❌ [QUICK_RACE] Baseline capture failed - cannot join race');
        SnackbarUtils.showError(
          'Health Data Not Ready',
          'Cannot join race: health data is not available. Please wait a few seconds and try again.',
        );
        return null;
      }

      log('✅ [QUICK_RACE] Joiner baseline pre-captured: ${baselineData['baselineSteps']} steps from ${baselineData['dataSource']}');

      // Try to join each matching race using atomic transaction
      for (var raceDoc in matchingRaces.docs) {
        final raceRef = _firebaseService.firestore.collection('races').doc(raceDoc.id);

        try {
          // Use transaction to atomically check, increment, and add participant
          final result = await _firebaseService.firestore.runTransaction<RaceData?>((transaction) async {
            final freshRaceDoc = await transaction.get(raceRef);

            if (!freshRaceDoc.exists) {
              log('⚠️ Race ${raceDoc.id} no longer exists');
              return null;
            }

            final raceData = freshRaceDoc.data() as Map<String, dynamic>;
            final joinedParticipants = raceData['joinedParticipants'] as int? ?? 0;
            final maxParticipants = raceData['maxParticipants'] as int? ?? 0;
            final statusId = raceData['statusId'] as int? ?? 0;
            final totalDistance = (raceData['totalDistance'] ?? 0.0).toDouble();

            // Check if race is joinable
            if (joinedParticipants >= maxParticipants) {
              log('⚠️ Race ${raceDoc.id} is full ($joinedParticipants/$maxParticipants)');
              return null;
            }

            if (statusId != 0 && statusId != 3) {
              log('⚠️ Race ${raceDoc.id} has wrong status: $statusId');
              return null;
            }

            // Check participant doesn't already exist
            final participantRef = raceRef.collection('participants').doc(currentUser.uid);
            final participantDoc = await transaction.get(participantRef);

            if (participantDoc.exists) {
              log('⚠️ User already in race ${raceDoc.id}');
              return null;
            }

            // Get user profile
            final userDoc = await transaction.get(
              _firebaseService.firestore.collection('user_profiles').doc(currentUser.uid)
            );
            final userData = userDoc.data() ?? {};
            final userName = userData['fullName'] ??
                userData['firstName'] ??
                userData['displayName'] ??
                currentUser.displayName ??
                'User';

            // Atomically: increment count + add participant
            transaction.update(raceRef, {
              'joinedParticipants': FieldValue.increment(1),
              'updatedAt': FieldValue.serverTimestamp(),
            });

            // Add participant to subcollection WITH baseline
            final participant = Participant(
              userId: currentUser.uid,
              userName: userName,
              distance: 0.0,
              remainingDistance: totalDistance,
              rank: joinedParticipants + 1,
              steps: 0,
              status: 'joined',
              lastUpdated: DateTime.now(),
              calories: 0,
              avgSpeed: 0.0,
              isCompleted: false,
              baselineSteps: baselineData?['baselineSteps'] ?? 0,
              baselineDistance: baselineData?['baselineDistance'] ?? 0.0,
              baselineCalories: baselineData?['baselineCalories'] ?? 0,
              baselineTimestamp: baselineData != null
                  ? (baselineData['baselineTimestamp'] as Timestamp).toDate()
                  : DateTime.now(),
            );

            log('✅ [QUICK_RACE] Adding joiner with baseline: ${baselineData?['baselineSteps'] ?? 0} steps');
            transaction.set(participantRef, participant.toFirestore());

            // Add to user_races collection
            final userRaceRef = _firebaseService.firestore
                .collection('user_races')
                .doc('${currentUser.uid}_${raceDoc.id}');

            transaction.set(userRaceRef, {
              'userId': currentUser.uid,
              'raceId': raceDoc.id,
              'role': 'participant',
              'status': 'joined',
              'joinedAt': FieldValue.serverTimestamp(),
            });

            log('✅ Successfully joined race ${raceDoc.id} atomically');
            return RaceData.fromFirestore(freshRaceDoc);
          });

          if (result != null) {
            log('✅ Transaction completed successfully for race ${result.id}');

            // Save baseline to local storage after successful join
            if (baselineData != null) {
              try {
                if (Get.isRegistered<PreferencesService>()) {
                  final prefsService = Get.find<PreferencesService>();
                  await prefsService.saveRaceBaseline(result.id!, currentUser.uid, {
                    'raceId': result.id!,
                    'userId': currentUser.uid,
                    'baselineSteps': baselineData['baselineSteps'],
                    'baselineDistance': baselineData['baselineDistance'],
                    'baselineCalories': baselineData['baselineCalories'],
                    'baselineTimestamp': (baselineData['baselineTimestamp'] as Timestamp).toDate().toIso8601String(),
                    'raceStartTime': DateTime.now().toIso8601String(),
                  });
                  log('✅ [QUICK_RACE] Joiner baseline saved to local storage');
                }
              } catch (e) {
                log('⚠️ [QUICK_RACE] Could not save joiner baseline to local storage: $e');
              }
            }

            return result;
          }
        } catch (e) {
          log('❌ Transaction failed for race ${raceDoc.id}: $e');
          continue; // Try next race
        }
      }

      log('⚠️ Could not join any matching race');
      return null;
    } catch (e) {
      log('❌ Error in find and join matching quick race: $e');
      return null;
    }
  }

  /// Create and start quick race
  Future<void> createAndStartQuickRace() async {
    if (currentLat.value == null || currentLng.value == null) {
      SnackbarUtils.showError(
        'Location Required',
        'Please wait while we get your location',
      );
      return;
    }

    try {
      isLoading.value = true;

      // Get current user
      final currentUser = await FirebaseAuthService.currentUser;
      if (currentUser == null) {
        SnackbarUtils.showError(
          'Authentication Error',
          'Please login to create a race',
        );
        return;
      }

      // ✅ STEP 1: Try to atomically find and join an existing matching quick race
      // Add small random delay (0-500ms) to prevent simultaneous queries
      final random = dart_math.Random();
      final delayMs = random.nextInt(500);
      log('⏱️ Adding ${delayMs}ms stagger delay to prevent race condition...');
      await Future.delayed(Duration(milliseconds: delayMs));

      log('🔍 Searching for matching quick race with transaction...');
      final matchedRace = await _findAndJoinMatchingQuickRace();

      if (matchedRace != null) {
        // Successfully joined existing race via atomic transaction
        SnackbarUtils.showSuccess(
          'Matched!',
          'Joined existing Quick Race with same criteria!',
        );

        log('🔄 Navigating to waiting room for matched race: ${matchedRace.id}');

        // Fetch fresh race data with updated participant count
        final freshRaceDoc = await _firebaseService.firestore
            .collection('races')
            .doc(matchedRace.id)
            .get();
        final freshRaceData = RaceData.fromFirestore(freshRaceDoc);

        log('📊 Fresh race data - participants: ${freshRaceData.joinedParticipants}/${freshRaceData.maxParticipants}');

        // Navigate to Waiting Room Screen with the matched race
        try {
          await Get.to(
            () => QuickRaceWaitingRoomScreen(
              raceId: matchedRace.id!,
              raceData: freshRaceData, // Use fresh data
              maxParticipants: selectedParticipants.value,
              raceDistance: selectedDistance.value,
            ),
            transition: Transition.rightToLeftWithFade,
            duration: Duration(milliseconds: 300),
          );
          log('✅ Navigation to waiting room completed (matched race)');
          return; // Exit early - we joined an existing race
        } catch (navError) {
          log('❌ Navigation error: $navError');
          rethrow;
        }
      } else {
        log('📝 No matching race found or all were full, creating new quick race');
      }

      // ✅ STEP 2: No matching race found or all were full - create new race

      // Get the actual start coordinates (current location or custom selected place)
      final startCoords = _getStartCoordinates();
      final startAddress = _getStartAddress();

      // Calculate duration based on distance with appropriate cutoff times
      int durationMinutes = _calculateDurationByDistance(selectedDistance.value);

      // Calculate end point through nearby POIs (monuments, parks, malls, etc.)
      log('🗺️ Calculating route through nearby POIs...');
      final endPoint = await _calculateEndPointWithPOI(
        startCoords['lat']!,
        startCoords['lng']!,
        selectedDistance.value,
      );

      // Get end address
      String endAddress = 'Destination';
      try {
        List<Placemark> endPlacemarks = await placemarkFromCoordinates(
          endPoint['lat']!,
          endPoint['lng']!,
        );
        if (endPlacemarks.isNotEmpty) {
          final placemark = endPlacemarks.first;
          endAddress = '${placemark.locality ?? ''}, ${placemark.administrativeArea ?? ''}'
              .replaceAll(RegExp(r'^,\s*|,\s*$'), '')
              .replaceAll(RegExp(r',\s*,'), ',')
              .trim();
          if (endAddress.isEmpty) endAddress = 'Destination';
        }
      } catch (e) {
        log('Could not get end address: $e');
      }

      // ✅ CRITICAL: Capture baseline BEFORE creating participant
      // We need raceId first, so we'll capture baseline after race creation
      // For now, create participant with placeholder baseline (will update after race created)
      final creatorParticipant = Participant(
        userId: currentUser.uid,
        userName: currentUser.displayName ??
            currentUser.email?.split('@')[0] ??
            'User',
        distance: 0.0,
        remainingDistance: selectedDistance.value,
        rank: 1,
        steps: 0,
        status: 'joined',
        lastUpdated: DateTime.now(),
        calories: 0,
        avgSpeed: 0.0,
        isCompleted: false,
        baselineSteps: 0, // Will be updated after race creation
        baselineDistance: 0.0,
        baselineCalories: 0,
        baselineTimestamp: DateTime.now(),
      );

      // Create race using RaceData model
      final race = RaceData(
        title: 'Quick Race ${selectedDistance.value.toStringAsFixed(0)}km',
        raceTypeId: 5, // Quick Race type
        maxParticipants: selectedParticipants.value,
        minParticipants: 2,
        joinedParticipants: 1, // Creator is auto-joined
        startLat: startCoords['lat'],
        startLong: startCoords['lng'],
        endLat: endPoint['lat'],
        endLong: endPoint['lng'],
        startAddress: startAddress,
        endAddress: endAddress,
        isPrivate: false, // Always public
        raceScheduleTime: 'Active', // Started immediately
        raceDeadline: DateTime.now().add(Duration(minutes: durationMinutes)).toIso8601String(),
        durationHrs: 0,
        durationMins: durationMinutes,
        genderPreferenceId: 0, // Any gender
        organizerUserId: currentUser.uid,
        organizerName: currentUser.displayName ??
            currentUser.email?.split('@')[0] ??
            'User',
        totalDistance: selectedDistance.value,
        statusId: 3, // Active - race starts immediately
        status: 'active',
        currentRank: null,
        distanceCovered: 0.0,
        remainingDistance: selectedDistance.value,
        participants: null, // NOT USED - participants stored in subcollection
        leaderPreview: null,
      );

      // Save to Firestore
      await _firebaseService.ensureInitialized();

      // Create the race document
      final raceCollection = _firebaseService.firestore.collection('races');
      final raceDocRef = await raceCollection.add(race.toFirestore());
      final raceId = raceDocRef.id;

      // Update the race document with the generated ID and set actual start time
      await raceDocRef.update({
        'id': raceId,
        'createdAt': FieldValue.serverTimestamp(),
        'actualStartTime': FieldValue.serverTimestamp(), // Race starts now
        'startedAt': FieldValue.serverTimestamp(),
      });

      // ✅ CRITICAL: Capture baseline NOW that we have raceId
      log('📊 [QUICK_RACE] Capturing baseline for race creator...');
      final baselineData = await _captureBaseline(raceId, currentUser.uid);

      // 🛡️ VALIDATION: Block race creation if baseline capture fails
      if (baselineData == null) {
        log('❌ [QUICK_RACE] Baseline capture failed - deleting race and aborting creation');

        // Clean up: Delete the race document since we can't proceed
        try {
          await raceDocRef.delete();
        } catch (e) {
          log('⚠️ [QUICK_RACE] Failed to clean up race document: $e');
        }

        SnackbarUtils.showError(
          'Health Data Not Ready',
          'Cannot create race: health data is not available. Please wait a few seconds and try again.',
        );
        return;
      }

      // Update participant with actual baseline data
      final participantData = creatorParticipant.toFirestore();
      participantData['baselineSteps'] = baselineData['baselineSteps'];
      participantData['baselineDistance'] = baselineData['baselineDistance'];
      participantData['baselineCalories'] = baselineData['baselineCalories'];
      participantData['baselineTimestamp'] = baselineData['baselineTimestamp'];
      log('✅ [QUICK_RACE] Creator baseline added to participant document');

      // Add participant to race's participants subcollection with baseline
      await raceDocRef
          .collection('participants')
          .doc(currentUser.uid)
          .set(participantData);

      log('✅ Quick race created with ID: $raceId (statusId: 3 - Active)');
      log('📍 Start: $startAddress');
      log('🏁 End: $endAddress');
      log('📏 Distance: ${selectedDistance.value} km');
      log('👥 Max participants: ${selectedParticipants.value}');
      if (endPoint.containsKey('poi')) {
        log('🎯 Route passes through: ${endPoint['poi']}');
      }

      SnackbarUtils.showSuccess(
        'Quick Race Created!',
        'Finding racers to join your race...',
      );

      // Fetch the created race to pass to waiting room
      final createdRaceDoc = await _firebaseService.firestore
          .collection('races')
          .doc(raceId)
          .get();

      final createdRace = RaceData.fromFirestore(createdRaceDoc);

      log('🔄 Navigating to waiting room for race: $raceId');

      // Navigate to Waiting Room Screen (bots will be added after timer)
      try {
        await Get.to(
          () => QuickRaceWaitingRoomScreen(
            raceId: raceId,
            raceData: createdRace,
            maxParticipants: selectedParticipants.value,
            raceDistance: selectedDistance.value,
          ),
          transition: Transition.rightToLeftWithFade,
          duration: Duration(milliseconds: 300),
        );
        log('✅ Navigation to waiting room completed');
      } catch (navError) {
        log('❌ Navigation error: $navError');
        rethrow;
      }
    } catch (e) {
      SnackbarUtils.showError(
        'Error',
        'Failed to create quick race: ${e.toString()}',
      );
      log('❌ Error creating quick race: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Capture baseline health data at race join time with multi-source fallback
  /// Returns map with baseline data or null if all sources fail
  ///
  /// 🛡️ CRITICAL: Never accepts zero baselines - uses fallback sources
  /// Fallback hierarchy: HealthKit → Coordinator → Firebase → StepService → SQLite
  Future<Map<String, dynamic>?> _captureBaseline(String raceId, String userId, {int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      log('📊 [QUICK_RACE] Baseline capture attempt $attempt/$maxRetries');

      // Try multiple data sources in priority order

      // 1. PRIMARY: Health Connect/HealthKit
      final healthData = await _tryHealthSource();
      if (healthData != null && healthData['steps'] > 0) {
        return _createBaselineData(healthData, raceId, userId);
      }

      // 2. FALLBACK 1: HealthSyncCoordinator cache
      final coordinatorData = await _tryCoordinatorSource();
      if (coordinatorData != null && coordinatorData['steps'] > 0) {
        return _createBaselineData(coordinatorData, raceId, userId);
      }

      // 3. FALLBACK 2: Firebase daily_steps
      final firebaseData = await _tryFirebaseSource();
      if (firebaseData != null && firebaseData['steps'] > 0) {
        return _createBaselineData(firebaseData, raceId, userId);
      }

      // 4. FALLBACK 3: StepTrackingService memory
      final stepServiceData = await _tryStepServiceSource();
      if (stepServiceData != null && stepServiceData['steps'] > 0) {
        return _createBaselineData(stepServiceData, raceId, userId);
      }

      // 5. FALLBACK 4: Local SQLite cache
      final sqliteData = await _trySqliteSource();
      if (sqliteData != null && sqliteData['steps'] > 0) {
        return _createBaselineData(sqliteData, raceId, userId);
      }

      // Wait before retry
      if (attempt < maxRetries) {
        log('⏳ [QUICK_RACE] All sources returned 0, waiting 2s before retry...');
        await Future.delayed(Duration(seconds: 2));
      }
    }

    // All retries exhausted
    log('❌ [QUICK_RACE] All fallback sources failed after $maxRetries attempts');
    return null;
  }

  /// Create baseline data structure and save to local storage
  Future<Map<String, dynamic>> _createBaselineData(
    Map<String, dynamic> healthData,
    String raceId,
    String userId,
  ) async {
    final baselineSteps = healthData['steps'] as int;
    final baselineDistance = healthData['distance'] as double;
    final baselineCalories = healthData['calories'] as int;
    final source = healthData['source'] as String?;
    final baselineTimestamp = DateTime.now();

    log('✅ [QUICK_RACE] Baseline captured from $source: $baselineSteps steps, ${baselineDistance.toStringAsFixed(2)} km');

    final baselineData = {
      'baselineSteps': baselineSteps,
      'baselineDistance': baselineDistance,
      'baselineCalories': baselineCalories,
      'baselineTimestamp': Timestamp.fromDate(baselineTimestamp),
      'raceId': raceId,
      'userId': userId,
      'raceStartTime': DateTime.now().toIso8601String(),
      'dataSource': source ?? 'unknown',
    };

    // Save to local storage for fast access during race
    try {
      if (Get.isRegistered<PreferencesService>()) {
        final prefsService = Get.find<PreferencesService>();
        await prefsService.saveRaceBaseline(raceId, userId, {
          'raceId': raceId,
          'userId': userId,
          'baselineSteps': baselineSteps,
          'baselineDistance': baselineDistance,
          'baselineCalories': baselineCalories,
          'baselineTimestamp': baselineTimestamp.toIso8601String(),
          'raceStartTime': DateTime.now().toIso8601String(),
          'dataSource': source ?? 'unknown',
        });
        log('✅ [QUICK_RACE] Baseline saved to local storage');
      }
    } catch (e) {
      log('⚠️ [QUICK_RACE] Could not save baseline to local storage: $e');
      // Don't fail if local save fails
    }

    return baselineData;
  }

  /// Try to get health data from Health Connect/HealthKit
  Future<Map<String, dynamic>?> _tryHealthSource() async {
    try {
      if (!Get.isRegistered<HealthSyncService>()) {
        return null;
      }

      final healthService = Get.find<HealthSyncService>();
      final healthData = await healthService.fetchTodaySteps();

      if (healthData != null && healthData['steps'] > 0) {
        log('✅ [QUICK_RACE] Using Health Connect/HealthKit: ${healthData['steps']} steps');
        return {...healthData, 'source': 'healthkit'};
      }
    } catch (e) {
      log('⚠️ [QUICK_RACE] Health source failed: $e');
    }
    return null;
  }

  /// Try to get health data from HealthSyncCoordinator cache
  Future<Map<String, dynamic>?> _tryCoordinatorSource() async {
    try {
      if (!Get.isRegistered<HealthSyncCoordinator>()) {
        return null;
      }

      final coordinator = Get.find<HealthSyncCoordinator>();
      final debugInfo = coordinator.getDebugInfo();

      final steps = debugInfo['lastProcessedSteps'] as int;
      final distance = debugInfo['lastProcessedDistance'] as double;
      final calories = debugInfo['lastProcessedCalories'] as int;
      final date = debugInfo['lastProcessedDate'] as String?;

      // Check if data is from today
      final now = DateTime.now();
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      if (date == today && steps > 0) {
        log('✅ [QUICK_RACE] Using HealthSyncCoordinator cache: $steps steps (from $date)');
        return {
          'steps': steps,
          'distance': distance,
          'calories': calories,
          'source': 'coordinator_cache',
        };
      }
    } catch (e) {
      log('⚠️ [QUICK_RACE] Coordinator source failed: $e');
    }
    return null;
  }

  /// Try to get health data from Firebase daily_steps
  Future<Map<String, dynamic>?> _tryFirebaseSource() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return null;

      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('daily_steps')
          .doc(dateKey)
          .get();

      final firebaseData = doc.exists ? doc.data() : null;

      if (firebaseData != null && (firebaseData['steps'] ?? 0) > 0) {
        log('✅ [QUICK_RACE] Using Firebase daily_steps: ${firebaseData['steps']} steps');
        return {
          'steps': firebaseData['steps'] ?? 0,
          'distance': firebaseData['distance'] ?? 0.0,
          'calories': firebaseData['calories'] ?? 0,
          'source': 'firebase_daily_steps',
        };
      }
    } catch (e) {
      log('⚠️ [QUICK_RACE] Firebase source failed: $e');
    }
    return null;
  }

  /// Try to get health data from StepTrackingService in-memory state
  Future<Map<String, dynamic>?> _tryStepServiceSource() async {
    try {
      if (!Get.isRegistered<StepTrackingService>()) {
        return null;
      }

      final stepService = Get.find<StepTrackingService>();
      final steps = stepService.todaySteps.value;

      if (steps > 0) {
        log('✅ [QUICK_RACE] Using StepTrackingService: $steps steps');
        return {
          'steps': steps,
          'distance': stepService.todayDistance.value,
          'calories': stepService.todayCalories.value,
          'source': 'step_service_memory',
        };
      }
    } catch (e) {
      log('⚠️ [QUICK_RACE] StepService source failed: $e');
    }
    return null;
  }

  /// Try to get health data from local SQLite cache
  Future<Map<String, dynamic>?> _trySqliteSource() async {
    try {
      final db = StepDatabase.instance;
      final today = DailyStepData.getTodayDate();
      final localData = await db.getDailyData(today);

      if (localData != null && localData.steps > 0) {
        log('✅ [QUICK_RACE] Using SQLite cache: ${localData.steps} steps');
        return {
          'steps': localData.steps,
          'distance': localData.distance,
          'calories': localData.calories,
          'source': 'sqlite_cache',
        };
      }
    } catch (e) {
      log('⚠️ [QUICK_RACE] SQLite source failed: $e');
    }
    return null;
  }

  /// Calculate end point coordinates based on distance
  /// Tries to route through a nearby POI (monument, park, mall, etc.)
  /// Returns end coordinates and optionally the POI used
  Future<Map<String, dynamic>> _calculateEndPointWithPOI(
    double startLat,
    double startLng,
    double distanceKm,
  ) async {
    try {
      // Try to find a POI near user's location
      final placesService = PlacesService();
      final poi = await placesService.findBestPOIForRoute(
        userLat: startLat,
        userLng: startLng,
        raceDistanceKm: distanceKm,
      );

      if (poi != null) {
        // If POI found, calculate end point through the POI
        log('🎯 Routing through POI: ${poi.displayName}');

        // Calculate bearing from start to POI
        final bearingToPOI = _calculateBearing(startLat, startLng, poi.latitude, poi.longitude);

        // Calculate end point at race distance in the same direction
        final endPoint = _calculatePointAtDistance(
          startLat,
          startLng,
          distanceKm,
          bearingToPOI,
        );

        return {
          'lat': endPoint['lat'],
          'lng': endPoint['lng'],
          'poi': poi.displayName,
          'poiLat': poi.latitude,
          'poiLng': poi.longitude,
        };
      } else {
        log('⚠️ No POI found, using random bearing');
      }
    } catch (e) {
      log('❌ Error finding POI: $e');
    }

    // Fallback: use random bearing if no POI found
    final random = dart_math.Random();
    final bearing = random.nextDouble() * 2 * dart_math.pi;
    final endPoint = _calculatePointAtDistance(startLat, startLng, distanceKm, bearing);

    return {
      'lat': endPoint['lat'],
      'lng': endPoint['lng'],
    };
  }

  /// Calculate bearing from point A to point B
  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final lat1Rad = lat1 * dart_math.pi / 180;
    final lat2Rad = lat2 * dart_math.pi / 180;
    final dLon = (lon2 - lon1) * dart_math.pi / 180;

    final y = dart_math.sin(dLon) * dart_math.cos(lat2Rad);
    final x = dart_math.cos(lat1Rad) * dart_math.sin(lat2Rad) -
        dart_math.sin(lat1Rad) * dart_math.cos(lat2Rad) * dart_math.cos(dLon);

    return dart_math.atan2(y, x);
  }

  /// Calculate a point at a given distance and bearing from start point
  Map<String, double> _calculatePointAtDistance(
    double startLat,
    double startLng,
    double distanceKm,
    double bearing,
  ) {
    const double earthRadius = 6371000; // Earth radius in meters
    final double distanceMeters = distanceKm * 1000; // Convert km to meters

    // Convert to radians
    final lat1 = startLat * dart_math.pi / 180;
    final lng1 = startLng * dart_math.pi / 180;

    // Calculate new coordinates using Haversine formula
    final lat2 = dart_math.asin(
      dart_math.sin(lat1) * dart_math.cos(distanceMeters / earthRadius) +
          dart_math.cos(lat1) *
              dart_math.sin(distanceMeters / earthRadius) *
              dart_math.cos(bearing),
    );

    final lng2 = lng1 +
        dart_math.atan2(
          dart_math.sin(bearing) *
              dart_math.sin(distanceMeters / earthRadius) *
              dart_math.cos(lat1),
          dart_math.cos(distanceMeters / earthRadius) -
              dart_math.sin(lat1) * dart_math.sin(lat2),
        );

    return {
      'lat': lat2 * 180 / dart_math.pi,
      'lng': lng2 * 180 / dart_math.pi,
    };
  }

  /// Calculate duration (cutoff time) based on race distance
  /// Returns duration in minutes
  int _calculateDurationByDistance(double distanceKm) {
    if (distanceKm <= 1.0) {
      return 10; // 1 km: 10 minutes
    } else if (distanceKm <= 3.0) {
      return 30; // 3 km: 30 minutes (around 25-30 minutes)
    } else if (distanceKm <= 5.0) {
      return 50; // 5 km: 50 minutes (around 40-50 minutes)
    } else if (distanceKm <= 7.0) {
      return 70; // 7 km: 70 minutes (around 55-70 minutes)
    } else {
      // For distances > 7km, scale proportionally (10 minutes per km)
      return (distanceKm * 10).round();
    }
  }

  /// Get formatted duration string for the UI based on selected distance
  String get formattedDuration {
    final durationMins = _calculateDurationByDistance(selectedDistance.value);
    if (durationMins < 60) {
      return '$durationMins Min';
    } else {
      final hours = durationMins ~/ 60;
      final mins = durationMins % 60;
      return mins > 0 ? '$hours Hr $mins Min' : '$hours Hour${hours > 1 ? 's' : ''}';
    }
  }

}
