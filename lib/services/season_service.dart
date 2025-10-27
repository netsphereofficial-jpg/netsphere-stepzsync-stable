import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/season_model.dart';

/// Service for managing competition seasons
class SeasonService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get the current active season
  Future<Season?> getCurrentSeason() async {
    try {
      final snapshot = await _firestore
          .collection('seasons')
          .where('isCurrent', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        log('⚠️ No current season found');
        return null;
      }

      return Season.fromFirestore(snapshot.docs.first);
    } catch (e) {
      log('❌ Error getting current season: $e');
      return null;
    }
  }

  /// Get all seasons (ordered by number descending)
  Future<List<Season>> getAllSeasons() async {
    try {
      final snapshot = await _firestore
          .collection('seasons')
          .orderBy('number', descending: true)
          .get();

      return snapshot.docs.map((doc) => Season.fromFirestore(doc)).toList();
    } catch (e) {
      log('❌ Error getting all seasons: $e');
      return [];
    }
  }

  /// Get active seasons only
  Future<List<Season>> getActiveSeasons() async {
    try {
      final snapshot = await _firestore
          .collection('seasons')
          .where('isActive', isEqualTo: true)
          .orderBy('number', descending: true)
          .get();

      return snapshot.docs.map((doc) => Season.fromFirestore(doc)).toList();
    } catch (e) {
      log('❌ Error getting active seasons: $e');
      return [];
    }
  }

  /// Get a specific season by ID
  Future<Season?> getSeasonById(String seasonId) async {
    try {
      final doc = await _firestore.collection('seasons').doc(seasonId).get();

      if (!doc.exists) {
        log('⚠️ Season not found: $seasonId');
        return null;
      }

      return Season.fromFirestore(doc);
    } catch (e) {
      log('❌ Error getting season: $e');
      return null;
    }
  }

  /// Get season by number
  Future<Season?> getSeasonByNumber(int seasonNumber) async {
    try {
      final snapshot = await _firestore
          .collection('seasons')
          .where('number', isEqualTo: seasonNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        log('⚠️ Season not found: Season $seasonNumber');
        return null;
      }

      return Season.fromFirestore(snapshot.docs.first);
    } catch (e) {
      log('❌ Error getting season by number: $e');
      return null;
    }
  }

  /// Create a new season
  Future<String?> createSeason(Season season) async {
    try {
      // If this is the current season, unset other current seasons
      if (season.isCurrent) {
        await _unsetCurrentSeasons();
      }

      final docRef = await _firestore.collection('seasons').add(season.toFirestore());

      log('✅ Created season: ${season.name} (${docRef.id})');
      return docRef.id;
    } catch (e) {
      log('❌ Error creating season: $e');
      return null;
    }
  }

  /// Update season
  Future<bool> updateSeason(String seasonId, Map<String, dynamic> updates) async {
    try {
      // If setting this as current, unset others first
      if (updates['isCurrent'] == true) {
        await _unsetCurrentSeasons();
      }

      await _firestore.collection('seasons').doc(seasonId).update(updates);

      log('✅ Updated season: $seasonId');
      return true;
    } catch (e) {
      log('❌ Error updating season: $e');
      return false;
    }
  }

  /// Set a season as current
  Future<bool> setCurrentSeason(String seasonId) async {
    try {
      // Unset all other current seasons
      await _unsetCurrentSeasons();

      // Set this season as current
      await _firestore.collection('seasons').doc(seasonId).update({
        'isCurrent': true,
        'isActive': true,
      });

      log('✅ Set current season: $seasonId');
      return true;
    } catch (e) {
      log('❌ Error setting current season: $e');
      return false;
    }
  }

  /// Unset all current seasons (helper method)
  Future<void> _unsetCurrentSeasons() async {
    final currentSeasons = await _firestore
        .collection('seasons')
        .where('isCurrent', isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    for (var doc in currentSeasons.docs) {
      batch.update(doc.reference, {'isCurrent': false});
    }
    await batch.commit();
  }

  /// Get user's season XP
  Future<SeasonXP?> getUserSeasonXP(String userId, String seasonId) async {
    try {
      final doc = await _firestore
          .collection('season_xp')
          .doc(seasonId)
          .collection('users')
          .doc(userId)
          .get();

      if (!doc.exists) {
        log('⚠️ No season XP found for user $userId in season $seasonId');
        return null;
      }

      return SeasonXP.fromFirestore(doc);
    } catch (e) {
      log('❌ Error getting user season XP: $e');
      return null;
    }
  }

  /// Update user's season XP
  Future<bool> updateUserSeasonXP({
    required String userId,
    required String seasonId,
    required int xpToAdd,
    int? rank,
    bool? wonRace,
    bool? isPodium,
  }) async {
    try {
      final docRef = _firestore
          .collection('season_xp')
          .doc(seasonId)
          .collection('users')
          .doc(userId);

      final doc = await docRef.get();

      if (doc.exists) {
        // Update existing
        final current = SeasonXP.fromFirestore(doc);
        final updates = <String, dynamic>{
          'seasonXP': current.seasonXP + xpToAdd,
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        if (rank != null) updates['seasonRank'] = rank;
        if (wonRace == true) updates['racesWon'] = current.racesWon + 1;
        if (isPodium == true) updates['podiumFinishes'] = current.podiumFinishes + 1;

        updates['racesCompleted'] = current.racesCompleted + 1;

        await docRef.update(updates);
      } else {
        // Create new
        final seasonXP = SeasonXP(
          userId: userId,
          seasonId: seasonId,
          seasonXP: xpToAdd,
          seasonRank: rank ?? 0,
          racesCompleted: 1,
          racesWon: wonRace == true ? 1 : 0,
          podiumFinishes: isPodium == true ? 1 : 0,
        );

        await docRef.set(seasonXP.toFirestore());
      }

      log('✅ Updated season XP for user $userId: +$xpToAdd XP');
      return true;
    } catch (e) {
      log('❌ Error updating user season XP: $e');
      return false;
    }
  }

  /// Get season leaderboard
  Future<List<SeasonXP>> getSeasonLeaderboard({
    required String seasonId,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      var query = _firestore
          .collection('season_xp')
          .doc(seasonId)
          .collection('users')
          .orderBy('seasonXP', descending: true);

      if (offset > 0) {
        query = query.limit(limit + offset);
      } else {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      final docs = offset > 0 ? snapshot.docs.skip(offset).toList() : snapshot.docs;

      return docs.map((doc) => SeasonXP.fromFirestore(doc)).toList();
    } catch (e) {
      log('❌ Error getting season leaderboard: $e');
      return [];
    }
  }

  /// Get user's rank in season
  Future<int?> getUserSeasonRank(String userId, String seasonId) async {
    try {
      final userDoc = await _firestore
          .collection('season_xp')
          .doc(seasonId)
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        return null;
      }

      final userXP = userDoc.data()!['seasonXP'] ?? 0;

      // Count users with more XP
      final snapshot = await _firestore
          .collection('season_xp')
          .doc(seasonId)
          .collection('users')
          .where('seasonXP', isGreaterThan: userXP)
          .get();

      return snapshot.docs.length + 1;
    } catch (e) {
      log('❌ Error getting user season rank: $e');
      return null;
    }
  }

  /// Initialize default seasons (call once during app setup)
  Future<void> initializeDefaultSeasons() async {
    try {
      final existingSeasons = await getAllSeasons();

      if (existingSeasons.isNotEmpty) {
        log('ℹ️ Seasons already initialized');
        return;
      }

      // Create Season 1 (current)
      final now = DateTime.now();
      final season1Start = DateTime(now.year, 1, 1); // January 1st
      final season1End = DateTime(now.year, 3, 31, 23, 59, 59); // March 31st

      final season1 = Season(
        id: 'season_1',
        name: 'Season 1',
        number: 1,
        startDate: season1Start,
        endDate: season1End,
        isActive: true,
        isCurrent: true,
        description: 'The inaugural season! Compete for the top spot and earn exclusive rewards.',
        rewardDescription: 'Top 10 winners get special badges',
      );

      await _firestore.collection('seasons').doc('season_1').set(season1.toFirestore());

      log('✅ Initialized default seasons');
    } catch (e) {
      log('❌ Error initializing default seasons: $e');
    }
  }

  /// Migrate existing user XP to current season
  Future<void> migrateExistingXPToSeason(String seasonId) async {
    try {
      log('🔄 Starting XP migration to season: $seasonId');

      // Get all users from user_xp collection
      final userXPSnapshot = await _firestore.collection('user_xp').get();

      final batch = _firestore.batch();
      int count = 0;

      for (var doc in userXPSnapshot.docs) {
        final data = doc.data();
        final userId = doc.id;
        final totalXP = data['totalXP'] ?? 0;
        final racesCompleted = data['racesCompleted'] ?? 0;
        final racesWon = data['racesWon'] ?? 0;
        final podiumFinishes = data['podiumFinishes'] ?? 0;

        final seasonXP = SeasonXP(
          userId: userId,
          seasonId: seasonId,
          seasonXP: totalXP,
          racesCompleted: racesCompleted,
          racesWon: racesWon,
          podiumFinishes: podiumFinishes,
        );

        final seasonDocRef = _firestore
            .collection('season_xp')
            .doc(seasonId)
            .collection('users')
            .doc(userId);

        batch.set(seasonDocRef, seasonXP.toFirestore());
        count++;

        // Commit in batches of 500
        if (count % 500 == 0) {
          await batch.commit();
          log('📦 Migrated $count users...');
        }
      }

      // Commit remaining
      if (count % 500 != 0) {
        await batch.commit();
      }

      log('✅ Successfully migrated $count users to season $seasonId');
    } catch (e) {
      log('❌ Error migrating XP to season: $e');
      rethrow;
    }
  }
}