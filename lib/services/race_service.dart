import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../models/race_models.dart';
import '../models/api_response.dart';
import '../core/models/race_data_model.dart';
import '../database/step_database.dart';
import '../models/daily_step_data.dart';
import 'step_tracking_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import 'race_state_machine.dart';
import 'health_sync_coordinator.dart';
import 'health_sync_service.dart';
import 'race_step_reconciliation_service.dart';
import 'preferences_service.dart';
import '../widgets/race/race_completion_celebration_dialog.dart';
import '../controllers/race/completed_races_controller.dart';
import '../core/utils/snackbar_utils.dart';

class RaceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Track which races have already shown celebration dialog (prevents duplicate dialogs)
  // Key format: "raceId:userId"
  static final Set<String> _celebrationDialogShown = {};

  // Collection reference
  static CollectionReference get _racesCollection => _firestore.collection('races');
  static CollectionReference get _usersCollection => _firestore.collection('users_profile');

  /// Get count of users in a specific city
  static Future<int> getUserCountByCity(String city) async {
    try {
      final querySnapshot = await _usersCollection
          .where('location', isEqualTo: city)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      // Error getting user count by city: $e
      return 1; // Default to 1 if error occurs
    }
  }

  /// Check if races already exist for a location
  static Future<int> getExistingRaceCountByLocation(String location) async {
    try {
      final querySnapshot = await _racesCollection
          .where('startAddress', isGreaterThanOrEqualTo: location)
          .where('startAddress', isLessThan: '$location\uf8ff')
          .where('status', isEqualTo: 'scheduled')
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      // Error getting existing race count: $e
      return 0;
    }
  }

  /// Create multiple races based on location
  static Future<ApiResponse<List<RaceModel>>> createLocationBasedRaces({
    required String city,
    required String location,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Check if races already exist for this location
      final existingRaceCount = await getExistingRaceCountByLocation(location);

      // If we already have enough races, check if they have correct participant counts
      if (existingRaceCount >= 5) {
        final existingRaces = await getRacesByCity(city);
        if (existingRaces.isSuccess && existingRaces.data!.isNotEmpty) {
          // Check if existing races have low participant counts (indicating new format)
          final hasCorrectFormat = existingRaces.data!.any((race) =>
            race.totalParticipant <= 3 && race.partcipantLimit >= 20);

          if (hasCorrectFormat) {
            return existingRaces;
          } else {
            // Old races with wrong format, clear them and create new ones
            await _clearOldRaces(location);
          }
        }
      }

      final userCount = await getUserCountByCity(city);

      // Calculate how many races to create
      // Minimum 5 races, but create more based on user count
      int racesToCreate;
      if (userCount < 5) {
        racesToCreate = 5 - existingRaceCount; // Ensure minimum 5 total
      } else {
        final targetRaces = userCount.clamp(5, 15); // 5-15 races based on user count
        racesToCreate = (targetRaces - existingRaceCount).clamp(0, 10); // Don't create more than 10 at once
      }

      // If no races need to be created, return existing ones
      if (racesToCreate <= 0) {
        final existingRaces = await getRacesByCity(city);
        if (existingRaces.isSuccess) {
          return existingRaces;
        }
      }

      final races = <RaceModel>[];
      final random = Random();

      for (int i = 0; i < racesToCreate; i++) {
        final race = _generateRandomRace(
          city: city,
          location: location,
          latitude: latitude,
          longitude: longitude,
          index: existingRaceCount + i,
          random: random,
        );

        // Add race to Firestore
        final docRef = await _racesCollection.add(race.toFirestore());
        final raceWithId = race.copyWith(id: docRef.id);
        races.add(raceWithId);

        // Small delay to avoid overwhelming Firestore
        await Future.delayed(Duration(milliseconds: 200));
      }

      return ApiResponse.success(races);
    } catch (e) {
      // Error creating location-based races: $e
      return ApiResponse.error('Failed to create races: $e');
    }
  }

  /// Generate a random race
  static RaceModel _generateRandomRace({
    required String city,
    required String location,
    required double latitude,
    required double longitude,
    required int index,
    required Random random,
  }) {
    final raceTypes = ['Steps Challenge', 'Distance Race', 'Time Trial', 'Calorie Burn', 'Mixed Challenge'];
    final durations = ['7 days', '14 days', '30 days', '3 days', '21 days'];
    final distances = [5.0, 10.0, 15.0, 20.0, 25.0, 30.0];
    final participantLimits = [20, 30, 50, 75, 100];

    final raceType = raceTypes[random.nextInt(raceTypes.length)];
    final duration = durations[random.nextInt(durations.length)];
    final distance = distances[random.nextInt(distances.length)];
    final participantLimit = participantLimits[random.nextInt(participantLimits.length)];

    // Generate nearby coordinates (within 5km radius)
    final latOffset = (random.nextDouble() - 0.5) * 0.09; // ~5km
    final lngOffset = (random.nextDouble() - 0.5) * 0.09; // ~5km

    final startLat = latitude + latOffset;
    final startLng = longitude + lngOffset;
    final endLat = startLat + (random.nextDouble() - 0.5) * 0.02; // ~1km
    final endLng = startLng + (random.nextDouble() - 0.5) * 0.02; // ~1km

    final now = DateTime.now();
    final startDate = now.add(Duration(hours: random.nextInt(48) + 1)); // Start in 1-48 hours

    // Ensure participant limit is always much higher than current participants
    final actualParticipantLimit = participantLimit.clamp(20, 100);

    // Generate bot participants (50% of participant limit)
    final botParticipants = _generateBotParticipants(random, actualParticipantLimit, distance);

    return RaceModel(
      title: '${_getRaceAdjective(random)} $raceType ${index + 1}',
      orgName: 'StepzSync',
      createdTime: now,
      startAddress: _generateNearbyAddress(location, random),
      endAddress: _generateNearbyAddress(location, random),
      raceType: raceType,
      totalDistance: distance,
      genderPrefrence: _getRandomGenderPreference(random),
      raceStoppingTime: duration,
      totalParticipant: actualParticipantLimit,
      partcipantLimit: actualParticipantLimit,
      scheduleTime: _formatDateTime(startDate),
      startLatitude: startLat,
      startLongitude: startLng,
      endLatitude: endLat,
      endLongitude: endLng,
      bannerUrl: _getRandomBannerUrl(random),
      createdBy: 'system',
      participants: botParticipants,
      status: 'scheduled',
      hasBot: true,
      botParticipants: botParticipants.map((p) => p.userId).toList(), // Keep IDs for compatibility
    );
  }

  /// Get random race adjective
  static String _getRaceAdjective(Random random) {
    final adjectives = [
      'Ultimate', 'Epic', 'Challenge', 'Sprint', 'Marathon',
      'Power', 'Elite', 'Champion', 'Victory', 'Thunder',
      'Lightning', 'Blaze', 'Titan', 'Phoenix', 'Storm'
    ];
    return adjectives[random.nextInt(adjectives.length)];
  }

  /// Generate nearby address
  static String _generateNearbyAddress(String baseLocation, Random random) {
    final areas = [
      'Central Park', 'Stadium Area', 'City Center', 'Sports Complex',
      'Riverside', 'Mall Road', 'Garden Area', 'Tech Park',
      'University Area', 'Market Square'
    ];
    return '${areas[random.nextInt(areas.length)]}, $baseLocation';
  }

  /// Get random gender preference
  static String _getRandomGenderPreference(Random random) {
    final preferences = ['All', 'Male', 'Female'];
    return preferences[random.nextInt(preferences.length)];
  }

  /// Format DateTime for display
  static String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Get random banner URL
  static String _getRandomBannerUrl(Random random) {
    final banners = [
      'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800',
      'https://images.unsplash.com/photo-1544717305-2782549b5136?w=800',
      'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=800',
      'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800',
      'https://images.unsplash.com/photo-1594736797933-d0dd59a71d2d?w=800',
    ];
    return banners[random.nextInt(banners.length)];
  }

  /// Generate bot participants
  static List<Participant> _generateBotParticipants(Random random, int participantLimit, double totalDistance) {
    final botNames = [
      'SpeedRunner_${random.nextInt(999)}',
      'FitnessGuru_${random.nextInt(999)}',
      'MarathonMaster_${random.nextInt(999)}',
      'RunnerPro_${random.nextInt(999)}',
      'StepChamp_${random.nextInt(999)}',
      'RaceChamp_${random.nextInt(999)}',
      'FastTrack_${random.nextInt(999)}',
      'PowerRunner_${random.nextInt(999)}',
      'HealthTracker_${random.nextInt(999)}',
      'FitnessBeast_${random.nextInt(999)}',
      'RunHero_${random.nextInt(999)}',
      'StepMaster_${random.nextInt(999)}',
      'ChampionRunner_${random.nextInt(999)}',
      'FlashRunner_${random.nextInt(999)}',
      'MegaRunner_${random.nextInt(999)}',
      'TurboStep_${random.nextInt(999)}',
    ];

    // Fill 50% of participant limit with bots
    final numberOfBots = (participantLimit * 0.5).round().clamp(1, botNames.length);

    return botNames.take(numberOfBots).map((botName) {
      return Participant(
        userId: 'bot_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(9999)}',
        userName: botName,
        distance: 0.0,
        remainingDistance: totalDistance,
        rank: 1, // Will be updated when race starts
        steps: 0,
        status: 'joined',
        lastUpdated: DateTime.now(),
        calories: 0,
        avgSpeed: 0.0,
        isCompleted: false,
      );
    }).toList();
  }

  /// Get races by city
  static Future<ApiResponse<List<RaceModel>>> getRacesByCity(String city) async {
    try {
      final querySnapshot = await _racesCollection
          .where('startAddress', isGreaterThanOrEqualTo: city)
          .where('startAddress', isLessThan: '$city\uf8ff')
          .orderBy('createdTime', descending: true)
          .limit(20)
          .get();

      final races = querySnapshot.docs
          .map((doc) => RaceModel.fromFirestore(doc))
          .toList();

      return ApiResponse.success(races);
    } catch (e) {
      // Error getting races by city: $e
      return ApiResponse.error('Failed to fetch races: $e');
    }
  }

  /// Get all races
  static Future<ApiResponse<List<RaceModel>>> getAllRaces() async {
    try {
      final querySnapshot = await _racesCollection
          .orderBy('createdTime', descending: true)
          .limit(50)
          .get();

      final races = querySnapshot.docs
          .map((doc) => RaceModel.fromFirestore(doc))
          .toList();

      return ApiResponse.success(races);
    } catch (e) {
      // Error getting all races: $e
      return ApiResponse.error('Failed to fetch races: $e');
    }
  }

  /// Join any user to a race (used for invite acceptance)
  static Future<ApiResponse<bool>> joinRaceAsUser(String raceId, String targetUserId) async {
    try {
      print('🔄 RaceService.joinRaceAsUser called for race: $raceId, user: $targetUserId');

      // Get race details to check status and current participants
      final raceDoc = await _racesCollection.doc(raceId).get();
      if (!raceDoc.exists) {
        return ApiResponse.error('Race not found');
      }

      final raceData = raceDoc.data() as Map<String, dynamic>;
      final raceStatus = raceData['status'] as String? ?? 'scheduled';

      // ✅ OPTIMIZED: Check if user is already a participant using subcollection
      final participantDoc = await _racesCollection
          .doc(raceId)
          .collection('participants')
          .doc(targetUserId)
          .get();

      if (participantDoc.exists) {
        return ApiResponse.error('User is already a participant in this race');
      }

      // Check if race is full
      final maxParticipants = raceData['maxParticipants'] as int? ?? 0;
      final joinedParticipants = raceData['joinedParticipants'] as int? ?? 0;
      if (joinedParticipants >= maxParticipants) {
        return ApiResponse.error('Race is full');
      }

      // Get user profile data for the target user
      final userDoc = await _firestore.collection('user_profiles').doc(targetUserId).get();
      final userData = userDoc.data() ?? {};
      final userName = userData['fullName'] ??
                      userData['firstName'] ??
                      userData['displayName'] ??
                      'Unknown User';
      final userProfilePicture = userData['profilePicture'] ?? '';

      // Get race distance for participant initialization
      final totalDistance = (raceData['totalDistance'] ?? 0.0).toDouble();

      // ✅ CRITICAL FIX: Capture baseline with multi-source fallback validation
      // This prevents zero baseline acceptance that causes step drift
      print('📊 [JOIN_RACE_AS_USER] Capturing baseline for user $targetUserId...');

      Map<String, dynamic>? baselineData = await _captureBaselineWithFallback(raceId, targetUserId);

      // ✅ VALIDATION: Never accept zero baseline - block join operation if all sources fail
      if (baselineData == null) {
        print('❌ [JOIN_RACE_AS_USER] Baseline capture failed - aborting join operation');
        return ApiResponse.error('Health data not ready. Please wait a few seconds and try again.');
      }

      final baselineSteps = baselineData['steps'] as int;
      final baselineDistance = baselineData['distance'] as double;
      final baselineCalories = baselineData['calories'] as int;
      final baselineTimestamp = baselineData['timestamp'] as DateTime;

      print('✅ [JOIN_RACE_AS_USER] Baseline captured: $baselineSteps steps, ${baselineDistance.toStringAsFixed(2)} km, $baselineCalories kcal');

      // Create new participant using the same structure as race creation
      final newParticipant = Participant(
        userId: targetUserId,
        userName: userName,
        distance: 0.0,
        remainingDistance: totalDistance,
        rank: joinedParticipants + 1, // Assign next rank
        steps: 0,
        status: 'joined',
        lastUpdated: DateTime.now(),
        userProfilePicture: userProfilePicture,
        calories: 0,
        avgSpeed: 0.0,
        isCompleted: false,
        baselineSteps: baselineSteps,
        baselineDistance: baselineDistance,
        baselineCalories: baselineCalories,
        baselineTimestamp: baselineTimestamp,
      );

      // Start batch operation for all 3 collections
      final batch = _firestore.batch();

      // 1. Update the main race document (DO NOT update participants array - using subcollection only)
      // ✅ OPTIMIZED: Removed participants array update to maintain consistency with Phase 0 optimization
      final raceRef = _racesCollection.doc(raceId);
      batch.update(raceRef, {
        // 'participants': FieldValue.arrayUnion([newParticipant.toFirestore()]), // REMOVED - use subcollection
        'joinedParticipants': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Add to the participants subcollection for detailed tracking (primary source of truth)
      final participantRef = raceRef.collection('participants').doc(targetUserId);
      batch.set(participantRef, newParticipant.toFirestore());

      // 3. Add to user_races collection for user's race list
      final userRaceRef = _firestore
          .collection('user_races')
          .doc(targetUserId)
          .collection('races')
          .doc(raceId);

      final userRaceData = {
        'userId': targetUserId,
        'raceId': raceId,
        'role': 'participant',
        'status': 'joined',
        'raceTitle': raceData['title'] ?? 'Unknown Race',
        'raceType': _getRaceTypeFromId(raceData['raceTypeId'] ?? 3),
        'totalDistance': totalDistance,
        'startAddress': raceData['startAddress'] ?? '',
        'endAddress': raceData['endAddress'] ?? '',
        'scheduleTime': raceData['raceScheduleTime'] ?? '',
        'joinedAt': FieldValue.serverTimestamp(),
        'joinedViaInvite': true,
      };
      batch.set(userRaceRef, userRaceData);

      // Commit all changes atomically
      await batch.commit();

      print('✅ User $targetUserId added to race $raceId with 3-collection structure');

      // If race is active or scheduled, start step tracking for target user (if they're the current user)
      if ((raceStatus == 'active' || raceStatus == 'scheduled') && targetUserId == _auth.currentUser?.uid) {
        try {
          // Get permanent step tracking service and start tracking for this race
          final stepService = Get.find<StepTrackingService>();
          // final trackingId = await stepService.startRaceStepTracking(raceId);

          // if (trackingId != null) {
          //   print('✅ Started persistent step tracking for race $raceId after joining');
          // } else {
          //   print('⚠️ Could not start persistent step tracking for race $raceId');
          // }
        } catch (e) {
          print('❌ Error starting step tracking after joining race: $e');
          // Don't fail the join operation if step tracking fails
        }
      }

      return ApiResponse.success(true);
    } catch (e) {
      print('❌ Error in joinRaceAsUser: $e');
      return ApiResponse.error('Failed to join race: $e');
    }
  }

  /// Helper method to get race type string from ID
  static String _getRaceTypeFromId(int raceTypeId) {
    switch (raceTypeId) {
      case 1:
        return 'solo';
      case 2:
        return 'private';
      case 3:
        return 'public';
      case 4:
        return 'marathon';
      default:
        return 'public';
    }
  }

  /// Join a race and automatically start step tracking if race is active
  static Future<ApiResponse<bool>> joinRace(String raceId) async {
    try {
      print('🔄 RaceService.joinRace called for race: $raceId');
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('❌ User not authenticated');
        return ApiResponse.error('User not authenticated');
      }
      print('👤 User $userId attempting to join race $raceId');

      // Get race details to check status and current participants
      final raceDoc = await _racesCollection.doc(raceId).get();
      if (!raceDoc.exists) {
        return ApiResponse.error('Race not found');
      }

      final raceData = raceDoc.data() as Map<String, dynamic>;
      final raceStatus = raceData['status'] as String? ?? 'scheduled';

      // ✅ OPTIMIZED: Check if user is already a participant using subcollection
      final participantDoc = await _racesCollection
          .doc(raceId)
          .collection('participants')
          .doc(userId)
          .get();

      if (participantDoc.exists) {
        return ApiResponse.error('You are already a participant in this race');
      }

      // Check if race is full
      final maxParticipants = raceData['maxParticipants'] as int? ?? 0;
      final joinedParticipants = raceData['joinedParticipants'] as int? ?? 0;
      if (joinedParticipants >= maxParticipants) {
        return ApiResponse.error('Race is full');
      }

      // Get user profile data
      final userDoc = await _firestore.collection('user_profiles').doc(userId).get();
      final userData = userDoc.data() ?? {};
      final userName = userData['fullName'] ??
                      userData['firstName'] ??
                      userData['displayName'] ??
                      'Unknown User';
      final userProfilePicture = userData['profilePicture'] ?? '';

      // Get race distance for participant initialization
      final totalDistance = (raceData['totalDistance'] ?? 0.0).toDouble();

      // ✅ CRITICAL FIX: Capture baseline at join time with multi-source fallback validation
      // This prevents accumulative steps issue and late baseline capture glitch
      // NOTE: User will wait here until baseline capture completes - this is intentional
      // Loading indicator in UI will show during this operation
      print('📊 [JOIN_RACE] Capturing baseline at join time (user will wait for this)...');

      // Multi-source fallback baseline capture with validation (3 retry attempts)
      Map<String, dynamic>? baselineData = await _captureBaselineWithFallback(raceId, userId);

      // ✅ VALIDATION: Never accept zero baseline - block join operation if all sources fail
      if (baselineData == null) {
        print('❌ [JOIN_RACE] Baseline capture failed after all retries - aborting join operation');
        SnackbarUtils.showError(
          'Health Data Not Ready',
          'Cannot join race: health data is not available. Please wait a few seconds and try again.',
        );
        return ApiResponse.error('Health data not ready. Please wait a few seconds and try again.');
      }

      final baselineSteps = baselineData['steps'] as int;
      final baselineDistance = baselineData['distance'] as double;
      final baselineCalories = baselineData['calories'] as int;
      final baselineTimestamp = baselineData['timestamp'] as DateTime;

      print('✅ [JOIN_RACE] Baseline captured: $baselineSteps steps, ${baselineDistance.toStringAsFixed(2)} km, $baselineCalories kcal');

      // Create new participant using the same structure as race creation
      final newParticipant = Participant(
        userId: userId,
        userName: userName,
        distance: 0.0,
        remainingDistance: totalDistance,
        rank: joinedParticipants + 1, // Assign next rank
        steps: 0,
        status: 'joined',
        lastUpdated: DateTime.now(),
        userProfilePicture: userProfilePicture,
        calories: 0,
        avgSpeed: 0.0,
        isCompleted: false,
        baselineSteps: baselineSteps,
        baselineDistance: baselineDistance,
        baselineCalories: baselineCalories,
        baselineTimestamp: baselineTimestamp,
      );

      // Use batch operation for all 3 collections
      final batch = _firestore.batch();
      final raceRef = _racesCollection.doc(raceId);

      // 1. Update the race document (DO NOT update participants array - using subcollection only)
      // ✅ OPTIMIZED: Removed participants array update to maintain consistency with Phase 0 optimization
      batch.update(raceRef, {
        // 'participants': FieldValue.arrayUnion([newParticipant.toFirestore()]), // REMOVED - use subcollection
        'joinedParticipants': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Add to the participants subcollection for detailed tracking (primary source of truth)
      final participantRef = raceRef.collection('participants').doc(userId);
      batch.set(participantRef, newParticipant.toFirestore());

      // 3. Add to user_races collection for user's race list
      final userRaceRef = _firestore
          .collection('user_races')
          .doc(userId)
          .collection('races')
          .doc(raceId);

      final userRaceData = {
        'userId': userId,
        'raceId': raceId,
        'role': 'participant',
        'status': 'joined',
        'raceTitle': raceData['title'] ?? 'Unknown Race',
        'raceType': _getRaceTypeFromId(raceData['raceTypeId'] ?? 3),
        'totalDistance': totalDistance,
        'startAddress': raceData['startAddress'] ?? '',
        'endAddress': raceData['endAddress'] ?? '',
        'scheduleTime': raceData['raceScheduleTime'] ?? '',
        'joinedAt': FieldValue.serverTimestamp(),
        'joinedViaInvite': false,
      };
      batch.set(userRaceRef, userRaceData);

      // Commit all changes atomically
      await batch.commit();

      print('✅ Participant added to race with 3-collection structure');
      print('✅ Baseline saved to Firebase: $baselineSteps steps, ${baselineDistance.toStringAsFixed(2)} km, $baselineCalories kcal');

      // ✅ CRITICAL FIX: Save baseline to local storage for fast access during race
      // This eliminates the need for Firebase queries during every sync
      // NOTE: User waits for this too - ensures baseline is ready before join completes
      try {
        final prefsService = Get.find<PreferencesService>();

        final baselineData = {
          'raceId': raceId,
          'userId': userId,
          'baselineSteps': baselineSteps,
          'baselineDistance': baselineDistance,
          'baselineCalories': baselineCalories,
          'baselineTimestamp': baselineTimestamp.toIso8601String(),
          'raceStartTime': (raceData['actualStartTime'] != null
              ? (raceData['actualStartTime'] as Timestamp).toDate()
              : DateTime.now()).toIso8601String(),
        };

        await prefsService.saveRaceBaseline(raceId, userId, baselineData);
        print('✅ [JOIN_RACE] Baseline saved to local storage - join complete, user can proceed');
      } catch (e) {
        print('⚠️ [JOIN_RACE] Could not save baseline to local storage: $e');
        // Don't fail the join operation if local save fails
        // Firebase has the baseline as backup
      }

      // If race is active or scheduled, start step tracking
      // if (raceStatus == 'active' || raceStatus == 'scheduled') {
      //   try {
      //     // Get permanent step tracking service and start tracking for this race
      //     final stepService = Get.find<StepTrackingService>();
      //     final trackingId = await stepService.startRaceStepTracking(raceId);
      //
      //     if (trackingId != null) {
      //       print('✅ Started persistent step tracking for race $raceId after joining');
      //     } else {
      //       print('⚠️ Could not start persistent step tracking for race $raceId');
      //     }
      //   } catch (e) {
      //     print('❌ Error starting step tracking after joining race: $e');
      //     // Don't fail the join operation if step tracking fails
      //   }
      // }
//TODO:TESTING
      return ApiResponse.success(true);
    } catch (e) {
      // Error joining race: $e
      return ApiResponse.error('Failed to join race: $e');
    }
  }

  /// Start a race - updates race document status and statusId
  static Future<Map<String, dynamic>?> startRaceApiCall(String? raceId) async {
    if (raceId == null) {
      return {'status': 400, 'message': 'Invalid race ID'};
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return {'status': 400, 'message': 'User not authenticated'};
    }

    try {
      // Update race document directly to active status (skip countdown)
      await _racesCollection.doc(raceId).update({
        'status': 'active',
        'statusId': 3, // Active status - race starts immediately
        'actualStartTime': FieldValue.serverTimestamp(),
        'startedAt': FieldValue.serverTimestamp(),
        'startedBy': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update all participants status from 'joined' to 'active' in subcollection
      // ✅ OPTIMIZED: Removed participants array update to maintain consistency with Phase 0 optimization
      final participantsSnapshot = await _racesCollection
          .doc(raceId)
          .collection('participants')
          .get();

      final batch = _firestore.batch();
      for (var doc in participantsSnapshot.docs) {
        batch.update(doc.reference, {
          'status': 'active',
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      print('✅ Updated all participants status to active in subcollection');

      // 🆕 CRITICAL FIX: Initialize or update baseline for all participants when race starts
      // This ensures baseline is set at actual race start time, not join time
      try {
        print('📊 Initializing baselines for all participants at race start...');

        // Get race data to fetch actualStartTime
        final raceDoc = await _racesCollection.doc(raceId).get();
        final raceData = raceDoc.data() as Map<String, dynamic>?;

        if (raceData != null) {
          final actualStartTime = (raceData['actualStartTime'] as Timestamp?)?.toDate() ?? DateTime.now();
          final raceTitle = raceData['title'] as String? ?? 'Unknown Race';

          // Only initialize baseline for current user (each user initializes their own)
          if (Get.isRegistered<RaceStepReconciliationService>()) {
            final reconciliationService = Get.find<RaceStepReconciliationService>();

            // ✅ CRITICAL FIX: Use multi-source fallback instead of just healthSyncService
            // This prevents zero baseline if Health Connect hasn't loaded yet
            print('📊 [START_RACE] Capturing baseline with multi-source fallback...');
            final baselineData = await _captureBaselineWithFallback(raceId, userId);

            if (baselineData != null) {
              final healthKitStepsAtStart = baselineData['steps'] as int;
              final healthKitDistanceAtStart = baselineData['distance'] as double;
              final healthKitCaloriesAtStart = baselineData['calories'] as int;

              print('📊 Current user baseline at race start:');
              print('   Steps: $healthKitStepsAtStart');
              print('   Distance: ${healthKitDistanceAtStart.toStringAsFixed(2)} km');
              print('   Calories: $healthKitCaloriesAtStart');

              // Initialize/update baseline via Cloud Function
              final baselineInitSuccess = await reconciliationService.initializeRaceBaseline(
                raceId: raceId,
                raceTitle: raceTitle,
                raceStartTime: actualStartTime,
                healthKitStepsAtStart: healthKitStepsAtStart,
                healthKitDistanceAtStart: healthKitDistanceAtStart,
                healthKitCaloriesAtStart: healthKitCaloriesAtStart,
              );

              if (baselineInitSuccess) {
                print('✅ Baseline initialized/updated for current user at race start');
              } else {
                print('⚠️ Could not initialize baseline for current user (will use existing or create on first sync)');
              }
            } else {
              print('⚠️ Could not fetch health data for baseline initialization');
            }
          } else {
            print('⚠️ Required services not available for baseline initialization');
          }
        }
      } catch (e) {
        print('⚠️ Error initializing baselines at race start: $e');
        // Don't fail race start if baseline initialization fails
        // The syncHealthDataToRaces will create it on first sync
      }

      return {
        'status': 200,
        'message': 'Race started successfully!',
      };
    } catch (e) {
      print('❌ Error starting race: $e');
      return {
        'status': 500,
        'message': 'Failed to start race: $e',
      };
    }
  }

  /// End a race - updates race document status and statusId
  static Future<Map<String, dynamic>?> endRaceApiCall(String? raceId) async {
    if (raceId == null) {
      return {'status': 400, 'message': 'Invalid race ID'};
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return {'status': 400, 'message': 'User not authenticated'};
    }

    try {
      await _racesCollection.doc(raceId).update({
        'status': 'completed',
        'statusId': 4, // Completed status in your RaceData model
        'actualEndTime': FieldValue.serverTimestamp(),
        'endedAt': FieldValue.serverTimestamp(),
        'endedBy': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'status': 200,
        'message': 'Race ended successfully!',
      };
    } catch (e) {
      print('❌ Error ending race: $e');
      return {
        'status': 500,
        'message': 'Failed to end race: $e',
      };
    }
  }

  /// Update participant real-time data during race (for step tracking integration)
  static Future<void> updateParticipantRealTimeData({
    required String raceId,
    required String userId,
    required double distance,
    required int steps,
    required int calories,
    required double avgSpeed,
    bool isCompleted = false,
  }) async {
    try {
      final raceRef = _racesCollection.doc(raceId);

      // Get current race data to update participant in array
      final raceDoc = await raceRef.get();
      if (!raceDoc.exists) return;

      final raceData = raceDoc.data() as Map<String, dynamic>;
      final totalDistance = (raceData['totalDistance'] ?? 0.0).toDouble();

      // 🚀 OPTIMIZED: Read from participants subcollection instead of main document array
      final participantsSnapshot = await raceRef.collection('participants').get();

      if (participantsSnapshot.docs.isEmpty) {
        return;
      }

      // Convert to list for ranking calculation
      final participantsList = participantsSnapshot.docs.map((doc) {
        return {
          'userId': doc.id,
          ...doc.data(),
        };
      }).toList();

      // Update current user's data in the list
      bool participantFound = false;
      int currentStepsOnServer = 0;
      for (int i = 0; i < participantsList.length; i++) {
        if (participantsList[i]['userId'].toString() == userId) {
          // ✅ CRITICAL FIX: Validate that new steps >= current steps on server before updating
          // This prevents race condition where stale data overwrites fresh data
          currentStepsOnServer = (participantsList[i]['steps'] as num?)?.toInt() ?? 0;

          if (steps < currentStepsOnServer) {
            print('⚠️ [RACE_SERVICE] REJECTED: new steps ($steps) < current steps on server ($currentStepsOnServer)');
            print('   This prevents data loss from race conditions on app restart');
            return; // Skip update to prevent going backwards
          }

          print('   📊 [RACE_SERVICE] Validated: $steps steps >= $currentStepsOnServer steps on server ✅');

          participantsList[i].addAll({
            'distance': distance,
            'steps': steps,
            'calories': calories,
            'avgSpeed': avgSpeed,
            'isCompleted': isCompleted,
          });
          participantFound = true;
          break;
        }
      }

      if (!participantFound) {
        return;
      }

      // Sort participants by distance for ranking
      participantsList.sort((a, b) =>
        ((b['distance'] ?? 0.0) as num).toDouble().compareTo(
          ((a['distance'] ?? 0.0) as num).toDouble()
        )
      );

      print('📊 Calculating ranks for race $raceId:');
      for (int i = 0; i < participantsList.length; i++) {
        final p = participantsList[i];
        print('   ${i + 1}. ${p['userName'] ?? p['userId']}: ${p['distance']}km');
      }

      // ✅ FIX: Update ALL participants' ranks, not just current user
      // Use batch to update all ranks efficiently
      final batch = _firestore.batch();
      int currentRank = 0;

      for (int i = 0; i < participantsList.length; i++) {
        final newRank = i + 1;
        final participantUserId = participantsList[i]['userId'].toString();
        final participantRef = raceRef.collection('participants').doc(participantUserId);

        // Always update rank to ensure consistency (batch writes are efficient)
        batch.set(participantRef, {'rank': newRank}, SetOptions(merge: true));

        if (participantUserId == userId) {
          currentRank = newRank;
        }
      }

      // Update current user's full data
      // NOTE: Only update progress fields, don't overwrite userName, userProfilePicture, userId, joinedAt
      final participantRef = raceRef.collection('participants').doc(userId);

      // ✅ CRITICAL FIX: Double-check before batch commit to prevent race condition
      // Re-read current server value to ensure we're not overwriting fresher data
      final currentParticipantDoc = await participantRef.get();
      if (currentParticipantDoc.exists) {
        final finalServerSteps = (currentParticipantDoc.data()?['steps'] as num?)?.toInt() ?? 0;
        if (steps < finalServerSteps) {
          print('❌ [RACE_SERVICE] CRITICAL: Server updated between read and write!');
          print('   Server now has $finalServerSteps steps, we were about to write $steps steps');
          print('   Aborting batch to prevent data corruption');
          return; // Abort the entire batch to prevent data loss
        }
      }

      batch.set(participantRef, {
        'userId': userId, // Ensure userId is set for document creation
        'distance': distance,
        'remainingDistance': totalDistance - distance,
        'steps': steps,
        'calories': calories,
        'avgSpeed': avgSpeed,
        'isCompleted': isCompleted,
        'rank': currentRank,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Commit all rank updates atomically
      await batch.commit();

      print('✅ Updated participant real-time data: $userId, Distance: ${distance}km, Steps: $steps');
      print('   📊 Race: $raceId, Calories: $calories, Avg Speed: ${avgSpeed.toStringAsFixed(2)} km/h');

      // Update leaderPreview cache if user is in top 3 (lightweight check)
      if (currentRank <= 3) {
        // Don't await - run in background to avoid blocking step updates
        updateLeaderPreview(raceId).catchError((e) {
          print('⚠️ Background leaderPreview update failed: $e');
        });
      }

      // Check for race completion after updating participant data
      await _checkRaceCompletion(raceId, raceData, distance, userId);
    } catch (e) {
      print('❌ Error updating participant real-time data: $e');

      // 🔄 Retry logic for Firebase failures (subcollection only)
      if (e.toString().contains('network') || e.toString().contains('deadline')) {
        print('🔄 Retrying Firebase update after network error...');
        try {
          await Future.delayed(Duration(seconds: 2));
          // Retry - update subcollection only
          final participantRef = _racesCollection
              .doc(raceId)
              .collection('participants')
              .doc(userId);

          await participantRef.update({
            'distance': distance,
            'steps': steps,
            'calories': calories,
            'avgSpeed': avgSpeed,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          print('✅ Retry successful for participant data update');
        } catch (retryError) {
          print('❌ Retry failed: $retryError');
        }
      }
    }
  }

  /// Update leaderPreview with top 3 participants for quick display
  /// This should be called periodically (every 10-15 seconds) during active races
  static Future<void> updateLeaderPreview(String raceId) async {
    try {
      final raceRef = _racesCollection.doc(raceId);

      // Get top 3 participants from subcollection
      final top3Snapshot = await raceRef
          .collection('participants')
          .orderBy('distance', descending: true)
          .limit(3)
          .get();

      if (top3Snapshot.docs.isEmpty) {
        return;
      }

      // Convert to simple map format for caching
      final leaderPreview = top3Snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'userId': doc.id,
          'userName': data['userName'] ?? 'Unknown',
          'distance': data['distance'] ?? 0.0,
          'rank': data['rank'] ?? 0,
          'userProfilePicture': data['userProfilePicture'],
          'isCompleted': data['isCompleted'] ?? false,
        };
      }).toList();

      // Update main race document with cached top 3
      await raceRef.update({
        'leaderPreview': leaderPreview,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Updated leaderPreview for race $raceId with ${leaderPreview.length} participants');
    } catch (e) {
      print('❌ Error updating leaderPreview: $e');
    }
  }

  /// Start real-time step tracking updates for a race participant
  static Future<void> startRealTimeTracking(String raceId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    print('🏃 Starting real-time tracking for race $raceId, user $userId');

    try {
      // Get the step tracking service and start tracking for this race
      final stepService = Get.find<StepTrackingService>();

      // Start race step tracking if not already started
      // final trackingId = await stepService.startRaceStepTracking(raceId);

      // if (trackingId != null) {
      //   print('✅ Started step tracking for race $raceId');
      // } else {
      //   print('⚠️ Step tracking already active for race $raceId');
      // }
    } catch (e) {
      print('❌ Error starting real-time tracking for race $raceId: $e');
    }
  }

  /// Leave a race and stop step tracking
  static Future<ApiResponse<bool>> leaveRace(String raceId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return ApiResponse.error('User not authenticated');
      }

      // Stop step tracking for this race if active
      try {
        final stepService = Get.find<StepTrackingService>();
        // await stepService.stopRaceStepTracking(raceId, status: 'left');
        print('✅ Stopped step tracking for race $raceId after leaving');
      } catch (e) {
        print('Error stopping step tracking after leaving race: $e');
        // Don't fail the leave operation if step tracking fails
      }

      // Use FirebaseService to remove participant with proper 3-collection structure
      final firebaseService = Get.find<FirebaseService>();
      await firebaseService.removeParticipantFromRace(
        raceId: raceId,
        userId: userId,
      );

      return ApiResponse.success(true);
    } catch (e) {
      // Error leaving race: $e
      return ApiResponse.error('Failed to leave race: $e');
    }
  }

  /// Update race status in database
  static Future<void> updateRaceStatus(String raceId, int newStatus) async {
    try {
      await _racesCollection.doc(raceId).update({
        'statusId': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Race $raceId status updated to: $newStatus');
    } catch (e) {
      print('❌ Error updating race status: $e');
      throw e;
    }
  }

  /// Check if race should be completed when a participant reaches the target distance
  static Future<void> _checkRaceCompletion(
    String raceId,
    Map<String, dynamic> raceData,
    double participantDistance,
    String userId,
  ) async {
    try {
      final totalDistance = (raceData['totalDistance'] ?? 0.0).toDouble();
      final currentStatus = raceData['statusId'] ?? 0;

      // Only check completion for active races (status 3) or ending countdown (status 6)
      // DO NOT process if race is already completed (status 4)
      if (currentStatus != 3 && currentStatus != 6) {
        print('⚠️ Skipping completion check - race status is $currentStatus (not active/ending)');
        return;
      }

      // Check if participant has reached or exceeded the target distance
      if (participantDistance >= totalDistance && totalDistance > 0) {
        print('🏁 Participant completion detected! $userId completed ${participantDistance}km of ${totalDistance}km');
        print('   Current race status: $currentStatus');

        // Get fresh race data to avoid stale state
        final freshRaceDoc = await _racesCollection.doc(raceId).get();
        if (!freshRaceDoc.exists) {
          print('❌ Race document not found during completion check');
          return;
        }

        final freshRaceData = freshRaceDoc.data() as Map<String, dynamic>;
        final freshStatus = freshRaceData['statusId'] ?? 0;

        print('   Fresh race status from Firebase: $freshStatus');

        // 🚀 OPTIMIZED: Check participant completion from subcollection
        final participantRef = _racesCollection
            .doc(raceId)
            .collection('participants')
            .doc(userId);

        final participantDoc = await participantRef.get();
        if (!participantDoc.exists) {
          print('❌ Participant document not found in subcollection');
          return;
        }

        final participantData = participantDoc.data()!;
        if (participantData['isCompleted'] == true) {
          print('⚠️ Participant $userId already marked as completed, skipping');
          return;
        }

        // Count how many participants have already completed (excluding current user)
        final completedSnapshot = await _racesCollection
            .doc(raceId)
            .collection('participants')
            .where('isCompleted', isEqualTo: true)
            .get();

        int completedCount = completedSnapshot.docs.length;
        final finishOrder = completedCount + 1;

        print('   Participants already completed: $completedCount');
        print('   Set finish order for $userId: $finishOrder');

        // Mark the participant as completed in subcollection
        await participantRef.update({
          'isCompleted': true,
          'completedAt': FieldValue.serverTimestamp(),
          'finishOrder': finishOrder,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ Participant $userId marked as completed in subcollection (finish order: $finishOrder)');

        // ✅ OPTIMIZATION: Trigger CompletedRacesController refresh if it exists
        // This ensures the completed race appears immediately in the Completed Races screen
        try {
          if (Get.isRegistered<CompletedRacesController>()) {
            final completedRacesController = Get.find<CompletedRacesController>();
            print('🔄 Triggering CompletedRacesController refresh after race completion');
            // Note: No need to call refresh manually since we're using real-time listeners
            // The listener will automatically detect the statusId change and update the UI
          }
        } catch (e) {
          print('⚠️ CompletedRacesController not registered, skipping refresh: $e');
        }

        // 🎉 Show celebration dialog ONLY for the user who completed (not for organizer or other participants)
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId == userId) {
          // Check if we've already shown the dialog for this race + user combination
          final dialogKey = '$raceId:$userId';
          if (_celebrationDialogShown.contains(dialogKey)) {
            print('⏭️ Celebration dialog already shown for $userId in race $raceId, skipping');
            return;
          }

          // Mark that we're about to show the dialog (prevents race conditions)
          _celebrationDialogShown.add(dialogKey);

          print('🎉 Showing celebration dialog for current user: $userId');
          final raceName = freshRaceData['title'] ?? 'Race';
          final currentRank = participantData['rank'] ?? finishOrder;

          // Extract participant stats for display
          final distance = (participantData['distance'] as num?)?.toDouble();
          final calories = (participantData['calories'] as num?)?.toDouble();
          final avgSpeed = (participantData['avgSpeed'] as num?)?.toDouble();

          // Reconstruct RaceData object for modal
          final raceDataForModal = RaceData.fromFirestoreMap(freshRaceData, raceId);

          // Get race type to determine if this is a solo race
          final raceTypeId = freshRaceData['raceTypeId'] ?? 0;
          final isSoloRace = raceTypeId == 1;

          RaceCompletionCelebrationDialog.show(
            finishPosition: finishOrder,
            finalRank: currentRank,
            raceName: raceName,
            distance: distance,
            calories: calories,
            avgSpeed: avgSpeed,
            isSoloRace: isSoloRace,
            onComplete: () {
              print('✅ Celebration dialog dismissed for $userId');

              // Navigate to home screen after celebration
              // Use Get.offAllNamed to clear all navigation stack and go to home
              try {
                Get.offAllNamed('/home');
                print('✅ Navigated to home screen after race completion');
              } catch (e) {
                print('❌ Error navigating to home: $e');
                // Fallback: try to go back
                Get.back();
              }
            },
          );
        } else {
          print('⏭️ Skipping celebration dialog - current user ($currentUserId) is not the one who completed ($userId)');
        }

        // Get race type to determine completion flow
        final raceTypeId = freshRaceData['raceTypeId'] ?? 0;
        final isSoloRace = raceTypeId == 1;

        // If this is the FIRST finisher AND race is still active
        if (completedCount == 0 && freshStatus == RaceStateMachine.STATUS_ACTIVE) {
          if (isSoloRace) {
            // ✅ Solo races skip the "ending" status and go directly to completed
            print('🏁 Solo race completed! Transitioning directly to COMPLETED');
            await RaceStateMachine.transitionToCompleted(raceId);
          } else {
            print('🎉 FIRST FINISHER! Starting race ending countdown');

            // Get race duration - prefer minutes, fallback to hours converted to minutes
            final durationMins = freshRaceData['durationMins'] as int? ??
                                ((freshRaceData['durationHrs'] as int? ?? 1) * 60);

            // 🚀 Use State Machine to transition to ENDING
            final transitioned = await RaceStateMachine.transitionToEnding(
              raceId,
              userId,
              durationMins,
            );

            if (transitioned) {
              print('✅ Race transitioned to ENDING via state machine');
            } else {
              print('⚠️ Failed to transition race to ENDING');
            }
          }
        } else if (freshStatus == RaceStateMachine.STATUS_ENDING) {
          // Race is in ending countdown - participant already updated
          print('📝 Subsequent finisher during countdown (finish order: $finishOrder)');
        } else {
          // Edge case: status is not active or ending
          print('⚠️ Participant finished in unexpected status $freshStatus');
        }

        // Check if ALL participants have finished (for non-solo races)
        if (!isSoloRace) {
          final allFinished = await RaceStateMachine.areAllParticipantsFinished(raceId);
          if (allFinished) {
            print('🏆 ALL participants finished! Transitioning to COMPLETED');
            await RaceStateMachine.transitionToCompleted(raceId);
          }
        }
      }
    } catch (e) {
      print('❌ Error checking race completion: $e');
    }
  }

  /// Clear old races with incorrect participant format
  static Future<void> _clearOldRaces(String location) async {
    try {
      final querySnapshot = await _racesCollection
          .where('startAddress', isGreaterThanOrEqualTo: location)
          .where('startAddress', isLessThan: '$location\uf8ff')
          .where('createdBy', isEqualTo: 'system')
          .get();

      // Delete old races in batches
      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      // Error clearing old races: $e
    }
  }

  // ============================================================================
  // BASELINE CAPTURE WITH MULTI-SOURCE FALLBACK
  // ============================================================================

  /// Capture baseline with multi-source fallback and validation
  /// Returns null if all sources fail after retries
  /// NEVER accepts zero baseline values - ensures data integrity
  static Future<Map<String, dynamic>?> _captureBaselineWithFallback(
    String raceId,
    String userId, {
    int maxRetries = 3,
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      print('📊 [RACE_SERVICE] Baseline capture attempt $attempt/$maxRetries');

      // Try multiple data sources in priority order
      // Source 1: Health Connect/HealthKit (primary)
      final healthData = await _tryHealthSource();
      if (healthData != null && healthData['steps'] > 0) {
        print('✅ [RACE_SERVICE] Baseline from HealthKit/Health Connect');
        return _createBaselineData(healthData, raceId, userId);
      }

      // Source 2: Firebase daily_steps collection
      final firebaseData = await _tryFirebaseSource(userId);
      if (firebaseData != null && firebaseData['steps'] > 0) {
        print('✅ [RACE_SERVICE] Baseline from Firebase daily_steps');
        return _createBaselineData(firebaseData, raceId, userId);
      }

      // Source 3: StepTrackingService in-memory state
      final stepServiceData = await _tryStepServiceSource();
      if (stepServiceData != null && stepServiceData['steps'] > 0) {
        print('✅ [RACE_SERVICE] Baseline from StepTrackingService');
        return _createBaselineData(stepServiceData, raceId, userId);
      }

      // Source 4: Local SQLite cache (last resort)
      final sqliteData = await _trySqliteSource();
      if (sqliteData != null && sqliteData['steps'] > 0) {
        print('✅ [RACE_SERVICE] Baseline from SQLite cache');
        return _createBaselineData(sqliteData, raceId, userId);
      }

      // All sources failed - retry with delay
      if (attempt < maxRetries) {
        print('⚠️ [RACE_SERVICE] All sources returned 0 or failed, retrying in 2 seconds...');
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    // All retries exhausted
    print('❌ [RACE_SERVICE] Baseline capture failed after $maxRetries attempts');
    return null;
  }

  /// Try to get health data from HealthKit/Health Connect
  static Future<Map<String, dynamic>?> _tryHealthSource() async {
    try {
      final healthSyncService = Get.find<HealthSyncService>();
      final data = await healthSyncService.fetchTodaySteps();
      if (data != null && data['steps'] > 0) {
        return data;
      }
    } catch (e) {
      print('⚠️ [RACE_SERVICE] Health source failed: $e');
    }
    return null;
  }

  /// Try to get data from Firebase daily_steps collection
  static Future<Map<String, dynamic>?> _tryFirebaseSource(String userId) async {
    try {
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_steps')
          .doc(dateKey)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && (data['steps'] ?? 0) > 0) {
          return {
            'steps': data['steps'] ?? 0,
            'distance': data['distance'] ?? 0.0,
            'calories': data['calories'] ?? 0,
          };
        }
      }
    } catch (e) {
      print('⚠️ [RACE_SERVICE] Firebase source failed: $e');
    }
    return null;
  }

  /// Try to get data from StepTrackingService in-memory state
  static Future<Map<String, dynamic>?> _tryStepServiceSource() async {
    try {
      if (Get.isRegistered<StepTrackingService>()) {
        final stepService = Get.find<StepTrackingService>();
        final steps = stepService.todaySteps.value;
        if (steps > 0) {
          return {
            'steps': steps,
            'distance': stepService.todayDistance.value,
            'calories': stepService.todayCalories.value,
          };
        }
      }
    } catch (e) {
      print('⚠️ [RACE_SERVICE] StepService source failed: $e');
    }
    return null;
  }

  /// Try to get data from local SQLite cache
  static Future<Map<String, dynamic>?> _trySqliteSource() async {
    try {
      final db = StepDatabase.instance;
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final data = await db.getDailyData(dateKey);
      if (data != null && data.steps > 0) {
        return {
          'steps': data.steps,
          'distance': data.distance,
          'calories': data.calories,
        };
      }
    } catch (e) {
      print('⚠️ [RACE_SERVICE] SQLite source failed: $e');
    }
    return null;
  }

  /// Create baseline data object from health data
  static Map<String, dynamic> _createBaselineData(
    Map<String, dynamic> healthData,
    String raceId,
    String userId,
  ) {
    return {
      'steps': healthData['steps'] ?? 0,
      'distance': healthData['distance'] ?? 0.0,
      'calories': healthData['calories'] ?? 0,
      'timestamp': DateTime.now(),
    };
  }
}