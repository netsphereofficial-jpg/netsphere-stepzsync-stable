import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';
import 'xp_service.dart';

class FirebaseService {
  bool _isInitialized = false;

  // Lazy getters for Firebase services
  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  /// Ensure Firebase is initialized before use
  Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await _initializeFirebase();
    }
  }

  /// Initialize Firebase with error handling and offline persistence
  Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // ✅ Enable Firebase Firestore offline persistence
      // This ensures baseline data is cached locally and survives app restarts
      await _configureFirestoreOfflinePersistence();

      _isInitialized = true;
      log("✅ Firebase initialized successfully with offline persistence");
    } catch (e) {
      log("❌ Firebase initialization failed: $e");
      // Don't throw - let app continue without Firebase
      // Services should handle null/error states gracefully
    }
  }

  /// Configure Firestore offline persistence for reliable baseline storage
  Future<void> _configureFirestoreOfflinePersistence() async {
    try {
      // ✅ Enable persistence for offline access and faster reads
      // Critical for step tracking baseline - data survives app restarts
      final settings = Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      firestore.settings = settings;

      log("✅ Firestore offline persistence enabled");
      log("   - Baseline data will be cached locally");
      log("   - Faster reads from cache");
      log("   - Data survives app restarts");
    } catch (e) {
      log("⚠️ Error configuring Firestore persistence: $e");
      // Don't throw - Firebase can still work without persistence
    }
  }

  /// Check if Firebase is initialized
  bool get isInitialized => _isInitialized;

  /// Get current user (ensures Firebase is initialized first)
  Future<User?> getCurrentUser() async {
    await ensureInitialized();
    return auth.currentUser;
  }

  /// Get auth state changes stream (ensures Firebase is initialized first)
  Stream<User?> getAuthStateChanges() {
    if (!_isInitialized) {
      // Return a stream that waits for initialization
      return Stream.fromFuture(ensureInitialized()).asyncExpand((_) =>
        _isInitialized ? auth.authStateChanges() : const Stream.empty()
      );
    }
    return auth.authStateChanges();
  }

  /// Sign out user
  Future<void> signOut() async {
    await ensureInitialized();
    await auth.signOut();
  }

  /// Create race with all participant data structures atomically
  Future<String> createRaceWithParticipants({
    required Map<String, dynamic> raceData,
    required Map<String, dynamic> participantData,
    required Map<String, dynamic> userRaceData,
    required String userId,
  }) async {
    log('🚀 [XP-DEBUG] createRaceWithParticipants called for user: $userId');

    await ensureInitialized();

    WriteBatch batch = firestore.batch();

    try {
      // Create race document reference
      DocumentReference raceRef = firestore.collection('races').doc();
      String raceId = raceRef.id;

      // Prepare participant data with complete model structure
      Map<String, dynamic> finalParticipantData = {
        ...participantData,
        'raceId': raceId,
        'userId': userId,
        'joinedAt': FieldValue.serverTimestamp(),
      };

      // ✅ OPTIMIZED: Don't use participants array in main document
      Map<String, dynamic> finalRaceData = {
        ...raceData,
        'raceId': raceId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'joinedParticipants': 1, // Creator is auto-joined
        'status': 'pending', // Initially pending until scheduled time
        'participants': null, // Not used - participants in subcollection
      };

      batch.set(raceRef, finalRaceData);

      // Create participant document in race_participants/{raceId}/{userId}
      DocumentReference participantRef = firestore
          .collection('race_participants')
          .doc(raceId)
          .collection('participants')
          .doc(userId);

      batch.set(participantRef, finalParticipantData);

      // Create user race document in user_races/{userId}/{raceId}
      DocumentReference userRaceRef = firestore
          .collection('user_races')
          .doc(userId)
          .collection('races')
          .doc(raceId);

      Map<String, dynamic> finalUserRaceData = {
        ...userRaceData,
        'raceId': raceId,
        'userId': userId,
        'joinedAt': FieldValue.serverTimestamp(),
      };

      batch.set(userRaceRef, finalUserRaceData);

      // Commit the batch
      await batch.commit();

      log('✅ Race created successfully with ID: $raceId');
      log('Creator auto-joined as participant with comprehensive data structure');

      // 🎁 Award XP for joining the race (creator automatically joins)
      try {
        final raceTitle = raceData['title'] ?? 'Race';

        log('🎯 Attempting to award join XP for race creator: $userId');

        // Award join XP asynchronously (don't block race creation on XP award)
        final xpService = XPService();

        log('🎯 XPService created, calling awardJoinRaceXP...');

        await xpService.awardJoinRaceXP(
          userId: userId,
          raceId: raceId,
          raceTitle: raceTitle,
        );

        log('✅ Successfully triggered join XP award for race creator: $userId');
      } catch (e, stackTrace) {
        log('⚠️ Failed to award join XP to creator (non-critical): $e');
        log('Stack trace: $stackTrace');
        // Don't rethrow - race creation should succeed even if XP fails
      }

      return raceId;

    } catch (e) {
      log('❌ Error creating race with participants: $e');
      rethrow;
    }
  }

  // ✅ OPTIMIZED: Removed _safeStringExtract and _safeParticipantListExtract helpers
  // These are no longer needed since we don't manipulate participants array

  /// Add participant to an existing race
  Future<void> addParticipantToRace({
    required String raceId,
    required String userId,
    required Map<String, dynamic> participantData,
    required Map<String, dynamic> userRaceData,
  }) async {
    await ensureInitialized();

    WriteBatch batch = firestore.batch();

    try {
      // ✅ OPTIMIZED: Check if user already exists using subcollection
      final existingParticipant = await firestore
          .collection('race_participants')
          .doc(raceId)
          .collection('participants')
          .doc(userId)
          .get();

      // Track if this is a new join (for XP award)
      final isNewJoin = !existingParticipant.exists;

      // Prepare new participant data
      Map<String, dynamic> finalParticipantData = {
        ...participantData,
        'raceId': raceId,
        'userId': userId,
        'joinedAt': FieldValue.serverTimestamp(),
      };

      DocumentReference raceRef = firestore.collection('races').doc(raceId);

      // Update race - increment count only if new user
      if (isNewJoin) {
        batch.update(raceRef, {
          'joinedParticipants': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        log('✅ Adding new participant $userId to race $raceId');
      } else {
        batch.update(raceRef, {
          'updatedAt': FieldValue.serverTimestamp(),
        });
        log('🔄 Updating existing participant $userId in race $raceId');
      }

      // Add participant document
      DocumentReference participantRef = firestore
          .collection('race_participants')
          .doc(raceId)
          .collection('participants')
          .doc(userId);

      batch.set(participantRef, finalParticipantData);

      // Add user race document
      DocumentReference userRaceRef = firestore
          .collection('user_races')
          .doc(userId)
          .collection('races')
          .doc(raceId);

      Map<String, dynamic> finalUserRaceData = {
        ...userRaceData,
        'raceId': raceId,
        'userId': userId,
        'joinedAt': FieldValue.serverTimestamp(),
      };

      batch.set(userRaceRef, finalUserRaceData);

      // Commit the batch
      await batch.commit();

      log('✅ Participant added to race: $raceId (stored in subcollection)');

      // 🎁 Award XP for joining the race (only for new joins, not updates)
      if (isNewJoin) {
        try {
          log('🎯 Attempting to award join XP for user: $userId');

          // Get race title for XP transaction description
          final raceDoc = await raceRef.get();
          final raceTitle = (raceDoc.data() as Map<String, dynamic>?)?['title'] ?? 'Race';

          log('🎯 Race title: $raceTitle, creating XPService...');

          // Award join XP (await to see errors)
          final xpService = XPService();

          log('🎯 XPService created, calling awardJoinRaceXP...');

          await xpService.awardJoinRaceXP(
            userId: userId,
            raceId: raceId,
            raceTitle: raceTitle,
          );

          log('✅ Successfully awarded join XP for user $userId');
        } catch (e, stackTrace) {
          log('⚠️ Failed to award join XP (non-critical): $e');
          log('Stack trace: $stackTrace');
          // Don't rethrow - join should succeed even if XP fails
        }
      }

    } catch (e) {
      log('❌ Error adding participant to race: $e');
      rethrow;
    }
  }

  /// Remove participant from race
  Future<void> removeParticipantFromRace({
    required String raceId,
    required String userId,
  }) async {
    await ensureInitialized();

    WriteBatch batch = firestore.batch();

    try {
      // ✅ OPTIMIZED: No need to update participants array
      DocumentReference raceRef = firestore.collection('races').doc(raceId);

      // Update race - decrement count
      batch.update(raceRef, {
        'joinedParticipants': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      log('🔍 Removing participant $userId from race $raceId');

      // Remove participant document
      DocumentReference participantRef = firestore
          .collection('race_participants')
          .doc(raceId)
          .collection('participants')
          .doc(userId);

      batch.delete(participantRef);

      // Update user race document status to 'left'
      DocumentReference userRaceRef = firestore
          .collection('user_races')
          .doc(userId)
          .collection('races')
          .doc(raceId);

      batch.update(userRaceRef, {
        'status': 'left',
        'leftAt': FieldValue.serverTimestamp(),
      });

      // Commit the batch
      await batch.commit();

      log('✅ Participant removed from race: $raceId');

    } catch (e) {
      log('❌ Error removing participant from race: $e');
      rethrow;
    }
  }

  /// Update participant progress in race
  Future<void> updateParticipantProgress({
    required String raceId,
    required String userId,
    required Map<String, dynamic> progressData,
  }) async {
    await ensureInitialized();

    try {
      DocumentReference participantRef = firestore
          .collection('race_participants')
          .doc(raceId)
          .collection('participants')
          .doc(userId);

      Map<String, dynamic> updateData = {
        ...progressData,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      await participantRef.update(updateData);

      log('✅ Participant progress updated for race: $raceId');

    } catch (e) {
      log('❌ Error updating participant progress: $e');
      rethrow;
    }
  }

  /// Get race participants stream for real-time updates
  Stream<QuerySnapshot> getRaceParticipantsStream(String raceId) {
    if (!_isInitialized) {
      return Stream.fromFuture(ensureInitialized()).asyncExpand((_) =>
        _isInitialized
          ? firestore.collection('race_participants').doc(raceId).collection('participants').snapshots()
          : const Stream.empty()
      );
    }
    return firestore.collection('race_participants').doc(raceId).collection('participants').snapshots();
  }

  /// Get user races stream for real-time updates
  Stream<QuerySnapshot> getUserRacesStream(String userId) {
    if (!_isInitialized) {
      return Stream.fromFuture(ensureInitialized()).asyncExpand((_) =>
        _isInitialized
          ? firestore.collection('user_races').doc(userId).collection('races').snapshots()
          : const Stream.empty()
      );
    }
    return firestore.collection('user_races').doc(userId).collection('races').snapshots();
  }

  /// Race Status Management Methods

  /// Update race status
  Future<void> updateRaceStatus({
    required String raceId,
    required int statusId,
  }) async {
    await ensureInitialized();

    try {
      DocumentReference raceRef = firestore.collection('races').doc(raceId);
      await raceRef.update({
        'statusId': statusId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      log('✅ Race status updated: $raceId -> Status: $statusId');

    } catch (e) {
      log('❌ Error updating race status: $e');
      rethrow;
    }
  }

  /// Set race deadline
  Future<void> setRaceDeadline({
    required String raceId,
    required DateTime deadline,
  }) async {
    await ensureInitialized();

    try {
      DocumentReference raceRef = firestore.collection('races').doc(raceId);
      await raceRef.update({
        'raceDeadline': Timestamp.fromDate(deadline),
        'statusId': 6, // Deadline status
        'updatedAt': FieldValue.serverTimestamp(),
      });

      log('✅ Race deadline set: $raceId -> Deadline: $deadline');

    } catch (e) {
      log('❌ Error setting race deadline: $e');
      rethrow;
    }
  }

  /// Start race (change status to active and set actual start time)
  Future<void> startRace({
    required String raceId,
  }) async {
    await ensureInitialized();

    try {
      DocumentReference raceRef = firestore.collection('races').doc(raceId);
      await raceRef.update({
        'statusId': 3, // Active status
        'actualStartTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      log('✅ Race started: $raceId');

    } catch (e) {
      log('❌ Error starting race: $e');
      rethrow;
    }
  }

  /// Finish race (change status to completed and set actual end time)
  Future<void> finishRace({
    required String raceId,
  }) async {
    await ensureInitialized();

    try {
      DocumentReference raceRef = firestore.collection('races').doc(raceId);
      await raceRef.update({
        'statusId': 4, // Completed status
        'actualEndTime': FieldValue.serverTimestamp(),
        'isCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      log('✅ Race finished: $raceId');

      // Award XP to all participants after race completion
      try {
        final xpService = XPService();
        await xpService.awardXPToParticipants(raceId);
        log('🎉 XP awarded to race participants: $raceId');
      } catch (xpError) {
        log('⚠️ Error awarding XP for race $raceId: $xpError');
        // Don't rethrow - race completion should succeed even if XP fails
      }

    } catch (e) {
      log('❌ Error finishing race: $e');
      rethrow;
    }
  }

  /// Set race ready to start (organizer can start race)
  Future<void> setRaceReady({
    required String raceId,
  }) async {
    await ensureInitialized();

    try {
      DocumentReference raceRef = firestore.collection('races').doc(raceId);
      await raceRef.update({
        'statusId': 1, // Ready status
        'updatedAt': FieldValue.serverTimestamp(),
      });

      log('✅ Race set to ready: $raceId');

    } catch (e) {
      log('❌ Error setting race ready: $e');
      rethrow;
    }
  }

  /// Start race countdown (10 seconds before race starts)
  Future<void> startRaceCountdown({
    required String raceId,
  }) async {
    await ensureInitialized();

    try {
      DocumentReference raceRef = firestore.collection('races').doc(raceId);
      await raceRef.update({
        'statusId': 2, // Countdown status
        'updatedAt': FieldValue.serverTimestamp(),
      });

      log('✅ Race countdown started: $raceId');

    } catch (e) {
      log('❌ Error starting race countdown: $e');
      rethrow;
    }
  }

  /// Get race status stream for real-time status updates
  Stream<DocumentSnapshot> getRaceStatusStream(String raceId) {
    if (!_isInitialized) {
      return Stream.fromFuture(ensureInitialized()).asyncExpand((_) =>
        _isInitialized
          ? firestore.collection('races').doc(raceId).snapshots()
          : const Stream.empty()
      );
    }
    return firestore.collection('races').doc(raceId).snapshots();
  }

  /// Get real-time participant count for a race
  Stream<int> getRaceParticipantCountStream(String raceId) {
    return getRaceParticipantsStream(raceId).map((snapshot) => snapshot.docs.length);
  }

  /// Get real-time participant progress for a specific user in a race
  Stream<DocumentSnapshot?> getParticipantProgressStream(String raceId, String userId) {
    if (!_isInitialized) {
      return Stream.fromFuture(ensureInitialized()).asyncExpand((_) =>
        _isInitialized
          ? firestore.collection('race_participants').doc(raceId).collection('participants').doc(userId).snapshots()
          : const Stream.empty()
      );
    }
    return firestore.collection('race_participants').doc(raceId).collection('participants').doc(userId).snapshots();
  }

  /// Get user's active races stream (races that are not completed or left)
  Stream<QuerySnapshot> getUserActiveRacesStream(String userId) {
    if (!_isInitialized) {
      return Stream.fromFuture(ensureInitialized()).asyncExpand((_) =>
        _isInitialized
          ? firestore.collection('user_races').doc(userId).collection('races')
              .where('status', whereIn: ['joined', 'active']).snapshots()
          : const Stream.empty()
      );
    }
    return firestore.collection('user_races').doc(userId).collection('races')
        .where('status', whereIn: ['joined', 'active']).snapshots();
  }

  /// Get race leaderboard stream (sorted by steps or distance)
  Stream<QuerySnapshot> getRaceLeaderboardStream(String raceId, {String orderBy = 'steps'}) {
    if (!_isInitialized) {
      return Stream.fromFuture(ensureInitialized()).asyncExpand((_) =>
        _isInitialized
          ? firestore.collection('race_participants').doc(raceId).collection('participants')
              .orderBy(orderBy, descending: true).snapshots()
          : const Stream.empty()
      );
    }
    return firestore.collection('race_participants').doc(raceId).collection('participants')
        .orderBy(orderBy, descending: true).snapshots();
  }

  /// Robust user profile fetcher with multiple fallbacks
  /// Tries: 1) users_profile collection, 2) Firebase Auth, 3) Generate from userId
  static Future<Map<String, dynamic>> getUserProfileWithFallback(String userId) async {
    final firestore = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;

    try {
      // 1. Try users_profile collection
      final userDoc = await firestore.collection('users_profile').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && (data['username'] != null || data['displayName'] != null || data['fullName'] != null)) {
          // Priority: username > displayName > fullName
          final displayName = data['username'] ?? data['displayName'] ?? data['fullName'] ?? '';
          if (displayName.isNotEmpty) {
            log('✅ Found user profile for $userId: $displayName');
            return {
              'displayName': displayName,
              'username': data['username'] ?? displayName,
              'fullName': data['fullName'] ?? displayName,
              'profilePicture': data['profilePicture'],
            };
          }
        }
      }

      // 2. Fallback to Firebase Auth (only for current user)
      final currentUser = auth.currentUser;
      if (currentUser != null && currentUser.uid == userId && currentUser.displayName != null) {
        log('⚠️ Using Firebase Auth displayName for $userId: ${currentUser.displayName}');
        return {
          'displayName': currentUser.displayName!,
          'fullName': currentUser.displayName!,
        };
      }

      // 3. Last resort: Generate from userId
      final generatedName = 'User ${userId.substring(0, 6)}';
      log('⚠️ No profile found for $userId, using generated name: $generatedName');
      return {
        'displayName': generatedName,
        'fullName': generatedName,
      };
    } catch (e) {
      log('❌ Error fetching user profile for $userId: $e');
      final fallbackName = 'User ${userId.substring(0, 6)}';
      return {
        'displayName': fallbackName,
        'fullName': fallbackName,
      };
    }
  }
}