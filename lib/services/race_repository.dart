import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/race_models.dart';
import 'firebase_service.dart';

class RaceRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // Start race - updates race document status
  Future<Map<String, dynamic>?> startRaceApiCall(String? raceId) async {
    if (raceId == null || currentUserId == null) {
      return {
        'status': 400,
        'message': 'Invalid race ID or user not authenticated',
      };
    }

    try {
      await _firestore.collection('races').doc(raceId).update({
        'status': 'active',
        'statusId': 3, // Set statusId to 3 (active) for real-time updates
        'startedAt': FieldValue.serverTimestamp(),
        'startedBy': currentUserId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {'status': 200, 'message': 'Race started successfully!'};
    } catch (e) {
      return {'status': 500, 'message': 'Failed to start race: $e'};
    }
  }

  // End race - updates race document status
  Future<Map<String, dynamic>?> endRaceApiCall(String? raceId) async {
    if (raceId == null || currentUserId == null) {
      return {
        'status': 400,
        'message': 'Invalid race ID or user not authenticated',
      };
    }

    try {
      await _firestore.collection('races').doc(raceId).update({
        'status': 'completed',
        'endedAt': FieldValue.serverTimestamp(),
        'endedBy': currentUserId,
      });

      return {'status': 200, 'message': 'Race ended successfully!'};
    } catch (e) {
      return {'status': 500, 'message': 'Failed to end race: $e'};
    }
  }

  // Get race real-time stream
  Stream<RaceModel?> getRaceStream(String raceId) {
    return _firestore.collection('races').doc(raceId).snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists) {
        return RaceModel.fromFirestore(snapshot);
      }
      return null;
    });
  }

  // Join race and create participant document
  Future<Map<String, dynamic>?> joinRaceApiCall(String raceId) async {
    if (currentUserId == null) {
      return {'status': 400, 'message': 'User not authenticated'};
    }

    try {
      // Get user profile information
      final userProfile = await _getUserProfile(currentUserId!);
      final displayName =
          userProfile['displayName'] ?? userProfile['fullName'] ?? 'User';

      final batch = _firestore.batch();

      // ✅ OPTIMIZED: Check if user is already a participant using subcollection
      final participantDoc = await _firestore
          .collection('races')
          .doc(raceId)
          .collection('participants')
          .doc(currentUserId)
          .get();

      if (participantDoc.exists) {
        return {'status': 400, 'message': 'You are already a participant in this race'};
      }

      // Update race - no participants array write
      final raceRef = _firestore.collection('races').doc(raceId);
      batch.update(raceRef, {
        'joinedParticipants': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create participant document
      final participantRef = _firestore
          .collection('races')
          .doc(raceId)
          .collection('participants')
          .doc(currentUserId);

      batch.set(participantRef, {
        'userId': currentUserId,
        'userName': displayName, // Changed from 'displayName' to match Participant model
        'joinedAt': FieldValue.serverTimestamp(),
        'distanceCovered': 0.0,
        'stepsCount': 0,
        'currentLatitude': 0.0, // Will be updated when race starts
        'currentLongitude': 0.0,
        'status': 'joined',
        'rank': 0,
        'progress': 0.0,
      });

      await batch.commit();

      return {'status': 200, 'message': 'Successfully joined race!'};
    } catch (e) {
      return {'status': 500, 'message': 'Failed to join race: $e'};
    }
  }

  // Helper method to get user profile information with robust fallbacks
  Future<Map<String, dynamic>> _getUserProfile(String userId) async {
    // Use FirebaseService's robust fetcher with multiple fallbacks
    return await FirebaseService.getUserProfileWithFallback(userId);
  }
}
