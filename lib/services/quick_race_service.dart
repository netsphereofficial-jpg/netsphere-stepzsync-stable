import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/quick_race_model.dart';
import 'firebase_service.dart';

class QuickRaceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // Find or create a quick race based on participant count
  Future<Map<String, dynamic>> joinQuickRace(int participantCount) async {
    if (currentUserId == null) {
      return {'success': false, 'message': 'User not authenticated. Please login first.'};
    }

    // Validate participant count
    if (participantCount < 2 || participantCount > 8) {
      return {'success': false, 'message': 'Invalid participant count. Must be between 2-8 players.'};
    }

    try {
      // First, try to find an existing quick race that's waiting for players
      final existingRaceQuery = await _firestore
          .collection('quick_races')
          .where('maxParticipants', isEqualTo: participantCount)
          .where('status', isEqualTo: 'waiting')
          .where('currentParticipants', isLessThan: participantCount)
          .limit(1)
          .get();

      QuickRaceModel quickRace;
      String raceId;

      if (existingRaceQuery.docs.isNotEmpty) {
        // Join existing race
        final existingRaceDoc = existingRaceQuery.docs.first;
        raceId = existingRaceDoc.id;
        quickRace = QuickRaceModel.fromFirestore(existingRaceDoc);

        // Check if user is already in this race
        if (quickRace.participants.contains(currentUserId)) {
          return {'success': false, 'message': 'You are already in this race!'};
        }

        // Add user to existing race
        final updatedParticipants = [...quickRace.participants, currentUserId!];
        final newParticipantCount = updatedParticipants.length;

        await _firestore.collection('quick_races').doc(raceId).update({
          'participants': updatedParticipants,
          'currentParticipants': newParticipantCount,
          'status': newParticipantCount == participantCount ? 'ready' : 'waiting',
        });

        // Create participant document
        await _createParticipantDocument(raceId, currentUserId!);

        quickRace = quickRace.copyWith(
          participants: updatedParticipants,
          currentParticipants: newParticipantCount,
          status: newParticipantCount == participantCount ? 'ready' : 'waiting',
        );

        return {
          'success': true,
          'message': 'Joined existing quick race!',
          'raceId': raceId,
          'race': quickRace,
          'isNew': false,
        };
      } else {
        // Create new quick race
        quickRace = _createQuickRaceModel(participantCount);

        final docRef = await _firestore.collection('quick_races').add(quickRace.toFirestore());
        raceId = docRef.id;

        // Create participant document for creator
        await _createParticipantDocument(raceId, currentUserId!);

        return {
          'success': true,
          'message': 'Created new quick race! Waiting for ${participantCount - 1} more players.',
          'raceId': raceId,
          'race': quickRace,
          'isNew': true,
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Failed to join quick race: $e'};
    }
  }

  QuickRaceModel _createQuickRaceModel(int participantCount) {
    final now = DateTime.now();
    final raceTypeLabel = participantCount == 4 ? '1v3' :
                         participantCount == 6 ? '1v5' : '1v7';

    // ✅ OPTIMIZED: Don't initialize with participants array - use subcollection only
    return QuickRaceModel(
      title: 'Quick Race $raceTypeLabel',
      createdTime: now,
      raceType: 'Quick',
      maxParticipants: participantCount,
      currentParticipants: 1,
      participants: [], // Empty - participants stored in subcollection
      status: participantCount == 1 ? 'ready' : 'waiting',
      createdBy: currentUserId!,
      distance: 1.0, // 1km quick sprint
      duration: 30, // 30 minutes
    );
  }

  Future<void> _createParticipantDocument(String raceId, String userId) async {
    // Get current location with proper permission handling
    Position? currentPosition;
    try {
      // Check location permission first
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          // Continue without location
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        // Continue without location
      } else {
        currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      }
    } catch (e) {
      print('Failed to get location: $e');
      // Continue without location - quick race can work without precise location
    }

    // Get user profile information
    final userProfile = await _getUserProfile(userId);
    final displayName = userProfile['displayName'] ?? userProfile['fullName'] ?? 'User';

    await _firestore
        .collection('quick_races')
        .doc(raceId)
        .collection('participants')
        .doc(userId)
        .set({
      'userId': userId,
      'userName': displayName, // Changed from 'displayName' to match Participant model
      'joinedAt': FieldValue.serverTimestamp(),
      'distanceCovered': 0.0,
      'stepsCount': 0,
      'currentLatitude': currentPosition?.latitude ?? 0.0,
      'currentLongitude': currentPosition?.longitude ?? 0.0,
      'status': 'joined',
      'rank': 0,
      'progress': 0.0,
    });
  }

  // Start a quick race when all participants are ready
  Future<Map<String, dynamic>> startQuickRace(String raceId) async {
    if (currentUserId == null) {
      return {'success': false, 'message': 'User not authenticated'};
    }

    try {
      await _firestore.collection('quick_races').doc(raceId).update({
        'status': 'active',
        'startedAt': FieldValue.serverTimestamp(),
        'startedBy': currentUserId,
      });

      return {'success': true, 'message': 'Quick race started!'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to start race: $e'};
    }
  }

  // Get user's active quick races
  Stream<List<QuickRaceModel>> getUserActiveQuickRaces() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('quick_races')
        .where('participants', arrayContains: currentUserId)
        .where('status', whereIn: ['waiting', 'ready', 'active'])
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => QuickRaceModel.fromFirestore(doc))
            .toList());
  }

  // Get real-time quick race updates
  Stream<QuickRaceModel?> getQuickRaceStream(String raceId) {
    return _firestore
        .collection('quick_races')
        .doc(raceId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return QuickRaceModel.fromFirestore(snapshot);
      }
      return null;
    });
  }

  // Leave a quick race
  Future<Map<String, dynamic>> leaveQuickRace(String raceId) async {
    if (currentUserId == null) {
      return {'success': false, 'message': 'User not authenticated'};
    }

    try {
      final raceDoc = await _firestore.collection('quick_races').doc(raceId).get();
      if (!raceDoc.exists) {
        return {'success': false, 'message': 'Race not found'};
      }

      final race = QuickRaceModel.fromFirestore(raceDoc);

      if (!race.participants.contains(currentUserId)) {
        return {'success': false, 'message': 'You are not in this race'};
      }

      final updatedParticipants = race.participants.where((id) => id != currentUserId).toList();

      if (updatedParticipants.isEmpty) {
        // Delete race if no participants left
        await _firestore.collection('quick_races').doc(raceId).delete();
      } else {
        // Update race with remaining participants
        await _firestore.collection('quick_races').doc(raceId).update({
          'participants': updatedParticipants,
          'currentParticipants': updatedParticipants.length,
          'status': 'waiting',
        });
      }

      // Remove participant document
      await _firestore
          .collection('quick_races')
          .doc(raceId)
          .collection('participants')
          .doc(currentUserId)
          .delete();

      return {'success': true, 'message': 'Left quick race successfully'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to leave race: $e'};
    }
  }

  // Helper method to get user profile information with robust fallbacks
  Future<Map<String, dynamic>> _getUserProfile(String userId) async {
    // Use FirebaseService's robust fetcher with multiple fallbacks
    return await FirebaseService.getUserProfileWithFallback(userId);
  }
}