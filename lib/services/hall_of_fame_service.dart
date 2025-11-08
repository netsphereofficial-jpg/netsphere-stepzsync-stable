import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/xp_models.dart';
import '../models/profile_models.dart';
import '../models/season_model.dart';

/// Service for managing Hall of Fame data and queries
class HallOfFameService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get top winners by total races won (All-time)
  Future<List<LeaderboardEntry>> getTopWinners({int limit = 10}) async {
    try {
      log('🏆 Fetching top winners (limit: $limit)');

      final snapshot = await _firestore
          .collection('user_xp')
          .orderBy('totalXP', descending: true) // Changed from racesWon to totalXP
          .limit(limit)
          .get();

      log('📊 user_xp collection has ${snapshot.docs.length} documents');
      if (snapshot.docs.isNotEmpty) {
        // Log first document for debugging
        final firstDoc = snapshot.docs.first.data();
        log('📄 Sample user_xp doc: racesWon=${firstDoc['racesWon']}, totalXP=${firstDoc['totalXP']}, podiumFinishes=${firstDoc['podiumFinishes']}');
      }

      if (snapshot.docs.isEmpty) {
        log('⚠️ No data found in user_xp');
        return [];
      }

      // Filter out users with 0 totalXP
      final docsWithXP = snapshot.docs.where((doc) {
        final data = doc.data();
        return (data['totalXP'] ?? 0) > 0;
      }).toList();

      if (docsWithXP.isEmpty) {
        log('⚠️ No users with XP > 0');
        return [];
      }

      final entries = await _buildLeaderboardEntries(docsWithXP);
      log('✅ Fetched ${entries.length} users with XP');
      return entries;
    } catch (e, stackTrace) {
      log('❌ Error fetching top winners: $e');
      log('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get top podium finishers (Top 3 placements)
  Future<List<LeaderboardEntry>> getTopPodiumFinishers({int limit = 10}) async {
    try {
      log('🥇 Fetching top podium finishers (limit: $limit)');

      final snapshot = await _firestore
          .collection('user_xp')
          .orderBy('podiumFinishes', descending: true)
          .limit(limit)
          .get();

      log('📊 Podium query returned ${snapshot.docs.length} documents');

      if (snapshot.docs.isEmpty) {
        log('⚠️ No podium finishers data found');
        return [];
      }

      final entries = await _buildLeaderboardEntries(snapshot.docs);
      log('✅ Fetched ${entries.length} top podium finishers');
      return entries;
    } catch (e, stackTrace) {
      log('❌ Error fetching top podium finishers: $e');
      log('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get highest XP earners (Lifetime XP)
  Future<List<LeaderboardEntry>> getTopXPEarners({int limit = 10}) async {
    try {
      log('⚡ Fetching top XP earners (limit: $limit)');

      final snapshot = await _firestore
          .collection('user_xp')
          .orderBy('totalXP', descending: true)
          .limit(limit)
          .get();

      if (snapshot.docs.isEmpty) {
        log('⚠️ No XP earners data found');
        return [];
      }

      final entries = await _buildLeaderboardEntries(snapshot.docs);
      log('✅ Fetched ${entries.length} top XP earners');
      return entries;
    } catch (e, stackTrace) {
      log('❌ Error fetching top XP earners: $e');
      log('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get seasonal champions (Users who ranked #1 in each season)
  Future<List<SeasonChampion>> getSeasonalChampions() async {
    try {
      log('👑 Fetching seasonal champions');

      // Get all seasons
      final seasonsSnapshot = await _firestore
          .collection('seasons')
          .orderBy('number', descending: true)
          .get();

      if (seasonsSnapshot.docs.isEmpty) {
        log('⚠️ No seasons found');
        return [];
      }

      List<SeasonChampion> champions = [];

      // For each season, get the champion (rank 1)
      for (var seasonDoc in seasonsSnapshot.docs) {
        final season = Season.fromFirestore(seasonDoc);

        // Query season_xp collection for this season's champion
        final championSnapshot = await _firestore
            .collection('season_xp')
            .where('seasonId', isEqualTo: season.id)
            .where('seasonRank', isEqualTo: 1)
            .limit(1)
            .get();

        if (championSnapshot.docs.isNotEmpty) {
          final seasonXPData = SeasonXP.fromFirestore(championSnapshot.docs.first);

          // Get user profile data
          final userProfile = await _getUserProfile(seasonXPData.userId);

          if (userProfile != null) {
            champions.add(SeasonChampion(
              season: season,
              seasonXP: seasonXPData,
              userName: userProfile.fullName ?? userProfile.username ?? 'Unknown User',
              profilePicture: userProfile.profilePicture,
              country: userProfile.country,
              city: userProfile.city,
            ));
          }
        }
      }

      log('✅ Fetched ${champions.length} seasonal champions');
      return champions;
    } catch (e, stackTrace) {
      log('❌ Error fetching seasonal champions: $e');
      log('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Real-time stream for top winners
  Stream<List<LeaderboardEntry>> getTopWinnersStream({int limit = 10}) {
    return _firestore
        .collection('user_xp')
        .orderBy('racesWon', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return [];
      return await _buildLeaderboardEntries(snapshot.docs);
    });
  }

  /// Real-time stream for top podium finishers
  Stream<List<LeaderboardEntry>> getTopPodiumFinishersStream({int limit = 10}) {
    return _firestore
        .collection('user_xp')
        .orderBy('podiumFinishes', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return [];
      return await _buildLeaderboardEntries(snapshot.docs);
    });
  }

  /// Real-time stream for top XP earners
  Stream<List<LeaderboardEntry>> getTopXPEarnersStream({int limit = 10}) {
    return _firestore
        .collection('user_xp')
        .orderBy('totalXP', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return [];
      return await _buildLeaderboardEntries(snapshot.docs);
    });
  }

  /// Build leaderboard entries from UserXP documents
  Future<List<LeaderboardEntry>> _buildLeaderboardEntries(
    List<QueryDocumentSnapshot> docs,
  ) async {
    List<LeaderboardEntry> entries = [];

    log('🔧 Building leaderboard entries from ${docs.length} documents...');

    for (int i = 0; i < docs.length; i++) {
      final doc = docs[i];
      log('📄 Processing doc ${i + 1}/${docs.length}: ${doc.id}');

      try {
        final userXP = UserXP.fromFirestore(doc);
        log('   ✓ UserXP parsed: userId=${userXP.userId}, totalXP=${userXP.totalXP}, racesWon=${userXP.racesWon}');

        // Get user profile for display name and avatar
        final userProfile = await _getUserProfile(userXP.userId);

        if (userProfile != null) {
          log('   ✓ UserProfile found: ${userProfile.fullName ?? userProfile.username ?? "Unknown"}');
          entries.add(LeaderboardEntry(
            userId: userXP.userId,
            userName: userProfile.fullName ?? userProfile.username ?? 'Unknown User',
            profilePicture: userProfile.profilePicture,
            totalXP: userXP.totalXP,
            level: userXP.level,
            rank: i + 1, // Position in this list
            racesCompleted: userXP.racesCompleted,
            racesWon: userXP.racesWon,
            podiumFinishes: userXP.podiumFinishes,
            country: userProfile.country,
            city: userProfile.city,
          ));
          log('   ✓ Entry added successfully');
        } else {
          log('   ✗ UserProfile is null for userId=${userXP.userId} - ENTRY SKIPPED!');
        }
      } catch (e, stackTrace) {
        log('   ✗ Error processing document ${doc.id}: $e');
        log('   Stack trace: $stackTrace');
      }
    }

    log('🏁 Completed building entries: ${entries.length} out of ${docs.length} documents');
    return entries;
  }

  /// Get user profile data
  Future<UserProfile?> _getUserProfile(String userId) async {
    try {
      log('      🔍 Fetching user profile for userId: $userId');
      final doc = await _firestore.collection('user_profiles').doc(userId).get();

      if (!doc.exists) {
        log('      ✗ User document does not exist in user_profiles collection for userId: $userId');
        return null;
      }

      log('      ✓ User document found, parsing UserProfile...');
      final profile = UserProfile.fromFirestore(doc);
      log('      ✓ UserProfile parsed successfully: ${profile.fullName ?? profile.username ?? "no name"}');
      return profile;
    } catch (e, stackTrace) {
      log('      ❌ Error fetching user profile for $userId: $e');
      log('      Stack trace: $stackTrace');
      return null;
    }
  }
}

/// Data model for seasonal champion
class SeasonChampion {
  final Season season;
  final SeasonXP seasonXP;
  final String userName;
  final String? profilePicture;
  final String? country;
  final String? city;

  SeasonChampion({
    required this.season,
    required this.seasonXP,
    required this.userName,
    this.profilePicture,
    this.country,
    this.city,
  });
}
