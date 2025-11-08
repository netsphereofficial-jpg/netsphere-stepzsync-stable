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
          .orderBy('racesWon', descending: true)
          .limit(limit)
          .get();

      if (snapshot.docs.isEmpty) {
        log('⚠️ No winners data found');
        return [];
      }

      final entries = await _buildLeaderboardEntries(snapshot.docs);
      log('✅ Fetched ${entries.length} top winners');
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

    for (int i = 0; i < docs.length; i++) {
      final doc = docs[i];
      final userXP = UserXP.fromFirestore(doc);

      // Get user profile for display name and avatar
      final userProfile = await _getUserProfile(userXP.userId);

      if (userProfile != null) {
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
      }
    }

    return entries;
  }

  /// Get user profile data
  Future<UserProfile?> _getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return UserProfile.fromFirestore(doc);
    } catch (e) {
      log('❌ Error fetching user profile for $userId: $e');
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
