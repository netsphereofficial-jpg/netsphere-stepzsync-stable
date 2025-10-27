import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/race_models.dart';

/// Admin Race Service
/// Handles race creation and management for admin panel

class AdminRaceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new race from admin panel
  static Future<String> createRace(RaceModel race) async {
    try {
      final docRef = await _firestore.collection('races').add(race.toFirestore());

      // Create user_races entry for the creator
      if (race.createdBy != null) {
        await _firestore.collection('user_races').add({
          'userId': race.createdBy,
          'raceId': docRef.id,
          'role': 'creator',
          'status': 'joined',
          'joinedAt': FieldValue.serverTimestamp(),
        });
      }

      print('✅ Race created successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Error creating race: $e');
      rethrow;
    }
  }

  /// Update an existing race
  static Future<void> updateRace(String raceId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('races').doc(raceId).update(updates);
      print('✅ Race updated successfully: $raceId');
    } catch (e) {
      print('❌ Error updating race: $e');
      rethrow;
    }
  }

  /// Delete a race
  static Future<void> deleteRace(String raceId) async {
    try {
      // Delete the race
      await _firestore.collection('races').doc(raceId).delete();

      // Delete associated user_races entries
      final userRacesSnapshot = await _firestore
          .collection('user_races')
          .where('raceId', isEqualTo: raceId)
          .get();

      final batch = _firestore.batch();
      for (final doc in userRacesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      print('✅ Race deleted successfully: $raceId');
    } catch (e) {
      print('❌ Error deleting race: $e');
      rethrow;
    }
  }

  /// Get all races with pagination
  static Future<List<RaceModel>> getRaces({
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore
          .collection('races')
          .orderBy('createdTime', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => RaceModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('❌ Error fetching races: $e');
      return [];
    }
  }

  /// Get race by ID
  static Future<RaceModel?> getRaceById(String raceId) async {
    try {
      final doc = await _firestore.collection('races').doc(raceId).get();
      if (doc.exists) {
        return RaceModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('❌ Error fetching race: $e');
      return null;
    }
  }

  /// Search races by title
  static Future<List<RaceModel>> searchRaces(String query) async {
    try {
      final snapshot = await _firestore
          .collection('races')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20)
          .get();

      return snapshot.docs.map((doc) => RaceModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('❌ Error searching races: $e');
      return [];
    }
  }

  /// Update race status
  static Future<void> updateRaceStatus(String raceId, int statusId, String status) async {
    try {
      await _firestore.collection('races').doc(raceId).update({
        'statusId': statusId,
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Race status updated: $raceId -> $status');
    } catch (e) {
      print('❌ Error updating race status: $e');
      rethrow;
    }
  }

  /// Calculate distance between two coordinates (Haversine formula)
  static double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    const double earthRadius = 6371; // km

    final dLat = _degreesToRadians(endLat - startLat);
    final dLng = _degreesToRadians(endLng - startLng);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(startLat)) *
            math.cos(_degreesToRadians(endLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}
