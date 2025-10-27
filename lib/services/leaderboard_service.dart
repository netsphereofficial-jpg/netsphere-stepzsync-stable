import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/xp_models.dart';
import '../models/profile_models.dart';
import '../models/season_model.dart';
import 'season_service.dart';

/// Service for managing leaderboards and rankings
class LeaderboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SeasonService _seasonService = SeasonService();

  /// Get global leaderboard
  /// Returns top users sorted by totalXP
  Future<List<LeaderboardEntry>> getGlobalLeaderboard({
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      log('📊 Fetching global leaderboard (limit: $limit, offset: $offset)');

      final snapshot = await _firestore
          .collection('user_xp')
          .orderBy('totalXP', descending: true)
          .limit(limit + offset)
          .get();

      if (snapshot.docs.isEmpty) {
        log('⚠️ No XP data found for global leaderboard');
        return [];
      }

      // Skip offset documents
      final docs = snapshot.docs.skip(offset).toList();

      // Convert to leaderboard entries with user info
      final entries = await _buildLeaderboardEntries(
        docs,
        startRank: offset + 1,
      );

      log('✅ Fetched ${entries.length} global leaderboard entries');
      return entries;
    } catch (e, stackTrace) {
      log('❌ Error fetching global leaderboard: $e');
      log('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get country-specific leaderboard
  Future<List<LeaderboardEntry>> getCountryLeaderboard({
    required String country,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      log('📊 Fetching country leaderboard for: $country');

      final snapshot = await _firestore
          .collection('user_xp')
          .where('country', isEqualTo: country)
          .orderBy('totalXP', descending: true)
          .limit(limit + offset)
          .get();

      if (snapshot.docs.isEmpty) {
        log('⚠️ No XP data found for country: $country');
        return [];
      }

      // Skip offset documents
      final docs = snapshot.docs.skip(offset).toList();

      final entries = await _buildLeaderboardEntries(
        docs,
        startRank: offset + 1,
      );

      log('✅ Fetched ${entries.length} country leaderboard entries for $country');
      return entries;
    } catch (e) {
      log('❌ Error fetching country leaderboard: $e');
      return [];
    }
  }

  /// Get city-specific leaderboard
  Future<List<LeaderboardEntry>> getCityLeaderboard({
    required String city,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      log('📊 Fetching city leaderboard for: $city');

      final snapshot = await _firestore
          .collection('user_xp')
          .where('city', isEqualTo: city)
          .orderBy('totalXP', descending: true)
          .limit(limit + offset)
          .get();

      if (snapshot.docs.isEmpty) {
        log('⚠️ No XP data found for city: $city');
        return [];
      }

      // Skip offset documents
      final docs = snapshot.docs.skip(offset).toList();

      final entries = await _buildLeaderboardEntries(
        docs,
        startRank: offset + 1,
      );

      log('✅ Fetched ${entries.length} city leaderboard entries for $city');
      return entries;
    } catch (e) {
      log('❌ Error fetching city leaderboard: $e');
      return [];
    }
  }

  /// Get leaderboard as a stream for real-time updates
  Stream<List<LeaderboardEntry>> getGlobalLeaderboardStream({
    int limit = 100,
  }) {
    return _firestore
        .collection('user_xp')
        .orderBy('totalXP', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return [];
      return await _buildLeaderboardEntries(snapshot.docs, startRank: 1);
    });
  }

  /// Get country leaderboard stream
  Stream<List<LeaderboardEntry>> getCountryLeaderboardStream({
    required String country,
    int limit = 100,
  }) {
    return _firestore
        .collection('user_xp')
        .where('country', isEqualTo: country)
        .orderBy('totalXP', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return [];
      return await _buildLeaderboardEntries(snapshot.docs, startRank: 1);
    });
  }

  /// Get city leaderboard stream
  Stream<List<LeaderboardEntry>> getCityLeaderboardStream({
    required String city,
    int limit = 100,
  }) {
    return _firestore
        .collection('user_xp')
        .where('city', isEqualTo: city)
        .orderBy('totalXP', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return [];
      return await _buildLeaderboardEntries(snapshot.docs, startRank: 1);
    });
  }

  /// Build leaderboard entries from UserXP documents
  /// Fetches user profile info to populate full entry data
  Future<List<LeaderboardEntry>> _buildLeaderboardEntries(
    List<QueryDocumentSnapshot> docs, {
    required int startRank,
  }) async {
    final entries = <LeaderboardEntry>[];
    int currentRank = startRank;

    for (var doc in docs) {
      try {
        final userXP = UserXP.fromFirestore(doc);

        // Fetch user profile for name and picture from user_profiles collection
        String userName = 'Unknown User';
        String? profilePicture;

        try {
          final userDoc = await _firestore
              .collection('user_profiles')
              .doc(userXP.userId)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data();
            userName = userData?['fullName'] ?? userData?['username'] ?? 'Unknown User';
            profilePicture = userData?['profilePicture'];
          }
        } catch (e) {
          log('⚠️ Could not fetch user profile for ${userXP.userId}: $e');
        }

        final entry = LeaderboardEntry.fromUserXP(
          userXP,
          userName: userName,
          profilePicture: profilePicture,
          rank: currentRank,
        );

        entries.add(entry);
        currentRank++;
      } catch (e) {
        log('⚠️ Error building leaderboard entry: $e');
      }
    }

    return entries;
  }

  /// Get user's rank in global leaderboard
  Future<int?> getUserGlobalRank(String userId) async {
    try {
      final userXPDoc = await _firestore.collection('user_xp').doc(userId).get();

      if (!userXPDoc.exists) {
        log('⚠️ No XP data found for user: $userId');
        return null;
      }

      final userXP = UserXP.fromFirestore(userXPDoc);
      final totalXP = userXP.totalXP;

      // Count how many users have more XP
      final snapshot = await _firestore
          .collection('user_xp')
          .where('totalXP', isGreaterThan: totalXP)
          .get();

      final rank = snapshot.docs.length + 1;
      log('📊 User $userId global rank: $rank');

      return rank;
    } catch (e) {
      log('❌ Error getting user global rank: $e');
      return null;
    }
  }

  /// Get user's rank in country leaderboard
  Future<int?> getUserCountryRank(String userId, String country) async {
    try {
      final userXPDoc = await _firestore.collection('user_xp').doc(userId).get();

      if (!userXPDoc.exists) {
        log('⚠️ No XP data found for user: $userId');
        return null;
      }

      final userXP = UserXP.fromFirestore(userXPDoc);
      final totalXP = userXP.totalXP;

      // Count how many users in the same country have more XP
      final snapshot = await _firestore
          .collection('user_xp')
          .where('country', isEqualTo: country)
          .where('totalXP', isGreaterThan: totalXP)
          .get();

      final rank = snapshot.docs.length + 1;
      log('📊 User $userId country rank ($country): $rank');

      return rank;
    } catch (e) {
      log('❌ Error getting user country rank: $e');
      return null;
    }
  }

  /// Get user's rank in city leaderboard
  Future<int?> getUserCityRank(String userId, String city) async {
    try {
      final userXPDoc = await _firestore.collection('user_xp').doc(userId).get();

      if (!userXPDoc.exists) {
        log('⚠️ No XP data found for user: $userId');
        return null;
      }

      final userXP = UserXP.fromFirestore(userXPDoc);
      final totalXP = userXP.totalXP;

      // Count how many users in the same city have more XP
      final snapshot = await _firestore
          .collection('user_xp')
          .where('city', isEqualTo: city)
          .where('totalXP', isGreaterThan: totalXP)
          .get();

      final rank = snapshot.docs.length + 1;
      log('📊 User $userId city rank ($city): $rank');

      return rank;
    } catch (e) {
      log('❌ Error getting user city rank: $e');
      return null;
    }
  }

  /// Update all user ranks in the leaderboard
  /// This is a heavy operation and should be run periodically (e.g., via Cloud Function)
  Future<void> updateAllRanks() async {
    try {
      log('🔄 Starting rank update for all users...');

      // Get all users sorted by XP
      final snapshot = await _firestore
          .collection('user_xp')
          .orderBy('totalXP', descending: true)
          .get();

      final batch = _firestore.batch();
      int globalRank = 1;

      // Update global ranks
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'globalRank': globalRank});
        globalRank++;
      }

      await batch.commit();

      log('✅ Updated global ranks for ${snapshot.docs.length} users');

      // Update country ranks
      await _updateCountryRanks();

      // Update city ranks
      await _updateCityRanks();

      log('🎉 Completed rank update for all users');
    } catch (e) {
      log('❌ Error updating all ranks: $e');
      rethrow;
    }
  }

  /// Update country-specific ranks
  Future<void> _updateCountryRanks() async {
    try {
      // Get all unique countries
      final snapshot = await _firestore.collection('user_xp').get();
      final countries = <String>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final country = data['country'];
        if (country != null && country.toString().isNotEmpty) {
          countries.add(country.toString());
        }
      }

      log('🌍 Found ${countries.length} unique countries');

      // Update ranks for each country
      for (var country in countries) {
        final countrySnapshot = await _firestore
            .collection('user_xp')
            .where('country', isEqualTo: country)
            .orderBy('totalXP', descending: true)
            .get();

        final batch = _firestore.batch();
        int countryRank = 1;

        for (var doc in countrySnapshot.docs) {
          batch.update(doc.reference, {'countryRank': countryRank});
          countryRank++;
        }

        await batch.commit();
        log('✅ Updated country ranks for $country (${countrySnapshot.docs.length} users)');
      }
    } catch (e) {
      log('❌ Error updating country ranks: $e');
    }
  }

  /// Update city-specific ranks
  Future<void> _updateCityRanks() async {
    try {
      // Get all unique cities
      final snapshot = await _firestore.collection('user_xp').get();
      final cities = <String>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final city = data['city'];
        if (city != null && city.toString().isNotEmpty) {
          cities.add(city.toString());
        }
      }

      log('🏙️ Found ${cities.length} unique cities');

      // Update ranks for each city
      for (var city in cities) {
        final citySnapshot = await _firestore
            .collection('user_xp')
            .where('city', isEqualTo: city)
            .orderBy('totalXP', descending: true)
            .get();

        final batch = _firestore.batch();
        int cityRank = 1;

        for (var doc in citySnapshot.docs) {
          batch.update(doc.reference, {'cityRank': cityRank});
          cityRank++;
        }

        await batch.commit();
        log('✅ Updated city ranks for $city (${citySnapshot.docs.length} users)');
      }
    } catch (e) {
      log('❌ Error updating city ranks: $e');
    }
  }

  /// Search for users in leaderboard by name
  Future<List<LeaderboardEntry>> searchLeaderboard({
    required String query,
    int limit = 20,
  }) async {
    try {
      log('🔍 Searching leaderboard for: $query');

      // Get all user XP data
      final xpSnapshot = await _firestore
          .collection('user_xp')
          .orderBy('totalXP', descending: true)
          .limit(1000) // Limit search scope for performance
          .get();

      final entries = <LeaderboardEntry>[];
      int rank = 1;

      for (var doc in xpSnapshot.docs) {
        final userXP = UserXP.fromFirestore(doc);

        // Fetch user profile from user_profiles collection
        final userDoc = await _firestore
            .collection('user_profiles')
            .doc(userXP.userId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          final userName = userData?['fullName'] ?? userData?['username'] ?? 'Unknown';

          // Check if name matches query (case insensitive)
          if (userName.toLowerCase().contains(query.toLowerCase())) {
            final entry = LeaderboardEntry.fromUserXP(
              userXP,
              userName: userName,
              profilePicture: userData?['profilePicture'],
              rank: rank,
            );
            entries.add(entry);

            if (entries.length >= limit) break;
          }
        }

        rank++;
      }

      log('✅ Found ${entries.length} matching users');
      return entries;
    } catch (e) {
      log('❌ Error searching leaderboard: $e');
      return [];
    }
  }

  /// Get leaderboard statistics
  Future<Map<String, dynamic>> getLeaderboardStats() async {
    try {
      final snapshot = await _firestore.collection('user_xp').get();

      if (snapshot.docs.isEmpty) {
        return {
          'totalUsers': 0,
          'totalXP': 0,
          'averageXP': 0,
          'highestXP': 0,
          'totalRacesCompleted': 0,
        };
      }

      int totalUsers = snapshot.docs.length;
      int totalXP = 0;
      int highestXP = 0;
      int totalRacesCompleted = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final xp = data['totalXP'] ?? 0;
        final races = data['racesCompleted'] ?? 0;

        totalXP += xp as int;
        totalRacesCompleted += races as int;

        if (xp > highestXP) {
          highestXP = xp;
        }
      }

      return {
        'totalUsers': totalUsers,
        'totalXP': totalXP,
        'averageXP': (totalXP / totalUsers).round(),
        'highestXP': highestXP,
        'totalRacesCompleted': totalRacesCompleted,
      };
    } catch (e) {
      log('❌ Error getting leaderboard stats: $e');
      return {};
    }
  }

  // ============================================
  // SEASON-BASED LEADERBOARD METHODS
  // ============================================

  /// Get season leaderboard (global)
  /// Shows ALL registered users, even those with 0 XP
  Future<List<LeaderboardEntry>> getSeasonLeaderboard({
    required String seasonId,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      log('📊 Fetching season leaderboard for: $seasonId (limit: $limit, offset: $offset)');

      // Step 1: Fetch ALL registered users from user_profiles
      final allUsersSnapshot = await _firestore
          .collection('user_profiles')
          .get();

      if (allUsersSnapshot.docs.isEmpty) {
        log('⚠️ No registered users found');
        return [];
      }

      log('📋 Found ${allUsersSnapshot.docs.length} registered users');

      // Step 2: Fetch season XP data for all users
      final seasonXPSnapshot = await _firestore
          .collection('season_xp')
          .doc(seasonId)
          .collection('users')
          .get();

      // Create a map of userId -> SeasonXP for quick lookup
      final Map<String, SeasonXP> seasonXPMap = {};
      for (var doc in seasonXPSnapshot.docs) {
        final seasonXP = SeasonXP.fromFirestore(doc);
        seasonXPMap[seasonXP.userId] = seasonXP;
      }

      log('📊 Found ${seasonXPMap.length} users with season XP data');

      // Step 3: Build leaderboard entries for ALL users
      final entries = <LeaderboardEntry>[];

      for (var userDoc in allUsersSnapshot.docs) {
        try {
          final userId = userDoc.id;
          final userData = userDoc.data();

          // Get user name and profile picture
          String userName = userData['fullName'] ?? userData['username'] ?? 'Unknown User';
          String? profilePicture = userData['profilePicture'];

          // Get XP data (0 if user hasn't joined any races)
          final seasonXP = seasonXPMap[userId];
          final xp = seasonXP?.seasonXP ?? 0;
          final level = seasonXP?.level ?? 1;
          final racesCompleted = seasonXP?.racesCompleted ?? 0;
          final racesWon = seasonXP?.racesWon ?? 0;

          final entry = LeaderboardEntry(
            userId: userId,
            userName: userName,
            profilePicture: profilePicture,
            totalXP: xp,
            level: level,
            rank: 0, // Will assign ranks after sorting
            racesCompleted: racesCompleted,
            racesWon: racesWon,
          );

          entries.add(entry);
        } catch (e) {
          log('⚠️ Error building entry for user ${userDoc.id}: $e');
        }
      }

      // Step 4: Sort by XP (descending) and assign ranks
      entries.sort((a, b) => b.totalXP.compareTo(a.totalXP));

      final rankedEntries = <LeaderboardEntry>[];
      for (int i = 0; i < entries.length; i++) {
        rankedEntries.add(LeaderboardEntry(
          userId: entries[i].userId,
          userName: entries[i].userName,
          profilePicture: entries[i].profilePicture,
          totalXP: entries[i].totalXP,
          level: entries[i].level,
          rank: i + 1,
          racesCompleted: entries[i].racesCompleted,
          racesWon: entries[i].racesWon,
        ));
      }

      // Step 5: Apply pagination
      final paginatedEntries = rankedEntries.skip(offset).take(limit).toList();

      log('✅ Fetched ${paginatedEntries.length} season leaderboard entries (${rankedEntries.length} total users)');
      return paginatedEntries;
    } catch (e, stackTrace) {
      log('❌ Error fetching season leaderboard: $e');
      log('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get friends leaderboard for a season
  Future<List<LeaderboardEntry>> getFriendsSeasonLeaderboard({
    required String userId,
    required String seasonId,
    required List<String> friendIds,
    int limit = 100,
  }) async {
    try {
      log('📊 Fetching friends season leaderboard for: $seasonId');

      if (friendIds.isEmpty) {
        log('⚠️ No friends found for user: $userId');
        return [];
      }

      // Get season XP for all friends
      final entries = <LeaderboardEntry>[];

      for (var friendId in friendIds) {
        final seasonXP = await _seasonService.getUserSeasonXP(friendId, seasonId);

        // Fetch user profile from user_profiles collection
        String userName = 'Unknown User';
        String? profilePicture;

        final userDoc = await _firestore
            .collection('user_profiles')
            .doc(friendId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          userName = userData?['fullName'] ?? userData?['username'] ?? 'Unknown User';
          profilePicture = userData?['profilePicture'];
        }

        final entry = LeaderboardEntry(
          userId: friendId,
          userName: userName,
          profilePicture: profilePicture,
          totalXP: seasonXP?.seasonXP ?? 0,
          level: seasonXP?.level ?? 1,
          rank: 0, // Will be set after sorting
          racesCompleted: seasonXP?.racesCompleted ?? 0,
          racesWon: seasonXP?.racesWon ?? 0,
        );

        entries.add(entry);
      }

      // Sort by XP and assign ranks
      entries.sort((a, b) => b.totalXP.compareTo(a.totalXP));

      for (int i = 0; i < entries.length; i++) {
        entries[i] = LeaderboardEntry(
          userId: entries[i].userId,
          userName: entries[i].userName,
          profilePicture: entries[i].profilePicture,
          totalXP: entries[i].totalXP,
          level: entries[i].level,
          rank: i + 1,
          racesCompleted: entries[i].racesCompleted,
          racesWon: entries[i].racesWon,
        );
      }

      // Apply limit
      if (entries.length > limit) {
        return entries.sublist(0, limit);
      }

      log('✅ Fetched ${entries.length} friends season leaderboard entries');
      return entries;
    } catch (e) {
      log('❌ Error fetching friends season leaderboard: $e');
      return [];
    }
  }

  /// Get user's rank in season leaderboard
  Future<int?> getUserSeasonRank(String userId, String seasonId) async {
    try {
      return await _seasonService.getUserSeasonRank(userId, seasonId);
    } catch (e) {
      log('❌ Error getting user season rank: $e');
      return null;
    }
  }

  /// Get season leaderboard stream
  /// Shows ALL registered users in real-time
  Stream<List<LeaderboardEntry>> getSeasonLeaderboardStream({
    required String seasonId,
    int limit = 100,
  }) {
    // Listen to season XP changes
    return _firestore
        .collection('season_xp')
        .doc(seasonId)
        .collection('users')
        .snapshots()
        .asyncMap((snapshot) async {
      try {
        // Fetch all registered users
        final allUsersSnapshot = await _firestore
            .collection('user_profiles')
            .get();

        if (allUsersSnapshot.docs.isEmpty) return [];

        // Create map of userId -> SeasonXP
        final Map<String, SeasonXP> seasonXPMap = {};
        for (var doc in snapshot.docs) {
          final seasonXP = SeasonXP.fromFirestore(doc);
          seasonXPMap[seasonXP.userId] = seasonXP;
        }

        // Build entries for all users
        final entries = <LeaderboardEntry>[];

        for (var userDoc in allUsersSnapshot.docs) {
          try {
            final userId = userDoc.id;
            final userData = userDoc.data();

            String userName = userData['fullName'] ?? userData['username'] ?? 'Unknown User';
            String? profilePicture = userData['profilePicture'];

            final seasonXP = seasonXPMap[userId];
            final xp = seasonXP?.seasonXP ?? 0;
            final level = seasonXP?.level ?? 1;
            final racesCompleted = seasonXP?.racesCompleted ?? 0;
            final racesWon = seasonXP?.racesWon ?? 0;

            entries.add(LeaderboardEntry(
              userId: userId,
              userName: userName,
              profilePicture: profilePicture,
              totalXP: xp,
              level: level,
              rank: 0,
              racesCompleted: racesCompleted,
              racesWon: racesWon,
            ));
          } catch (e) {
            log('⚠️ Error building entry: $e');
          }
        }

        // Sort and assign ranks
        entries.sort((a, b) => b.totalXP.compareTo(a.totalXP));

        final rankedEntries = <LeaderboardEntry>[];
        for (int i = 0; i < entries.length; i++) {
          rankedEntries.add(LeaderboardEntry(
            userId: entries[i].userId,
            userName: entries[i].userName,
            profilePicture: entries[i].profilePicture,
            totalXP: entries[i].totalXP,
            level: entries[i].level,
            rank: i + 1,
            racesCompleted: entries[i].racesCompleted,
            racesWon: entries[i].racesWon,
          ));
        }

        return rankedEntries.take(limit).toList();
      } catch (e) {
        log('⚠️ Error in leaderboard stream: $e');
        return [];
      }
    });
  }
}