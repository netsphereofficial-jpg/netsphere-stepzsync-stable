import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/season_service.dart';
import '../models/season_model.dart';

/// Initialize season data and test XP for leaderboard
Future<void> initializeSeasonData() async {
  try {
    log('🚀 Starting season data initialization...');

    final seasonService = SeasonService();
    final firestore = FirebaseFirestore.instance;

    // Step 1: Initialize default seasons
    log('📅 Initializing Season 1...');
    await seasonService.initializeDefaultSeasons();

    // Step 2: Get Season 1
    final season = await seasonService.getSeasonByNumber(1);
    if (season == null) {
      log('❌ Failed to create Season 1');
      return;
    }

    log('✅ Season 1 created: ${season.id}');

    // Step 3: Create test users with season XP
    log('👥 Creating test users with season XP...');

    final testUsers = [
      {'userId': 'user_1', 'name': 'Alice Johnson', 'xp': 5000, 'racesWon': 5, 'podiumFinishes': 8},
      {'userId': 'user_2', 'name': 'Bob Smith', 'xp': 4500, 'racesWon': 3, 'podiumFinishes': 7},
      {'userId': 'user_3', 'name': 'Charlie Brown', 'xp': 4200, 'racesWon': 4, 'podiumFinishes': 6},
      {'userId': 'user_4', 'name': 'Diana Prince', 'xp': 3800, 'racesWon': 2, 'podiumFinishes': 5},
      {'userId': 'user_5', 'name': 'Ethan Hunt', 'xp': 3500, 'racesWon': 3, 'podiumFinishes': 4},
      {'userId': 'user_6', 'name': 'Fiona Green', 'xp': 3200, 'racesWon': 1, 'podiumFinishes': 4},
      {'userId': 'user_7', 'name': 'George Lee', 'xp': 3000, 'racesWon': 2, 'podiumFinishes': 3},
      {'userId': 'user_8', 'name': 'Hannah White', 'xp': 2800, 'racesWon': 1, 'podiumFinishes': 3},
      {'userId': 'user_9', 'name': 'Ivan Torres', 'xp': 2500, 'racesWon': 1, 'podiumFinishes': 2},
      {'userId': 'user_10', 'name': 'Julia Martinez', 'xp': 2200, 'racesWon': 0, 'podiumFinishes': 2},
      {'userId': 'user_11', 'name': 'Kevin Park', 'xp': 2000, 'racesWon': 1, 'podiumFinishes': 1},
      {'userId': 'user_12', 'name': 'Laura Kim', 'xp': 1800, 'racesWon': 0, 'podiumFinishes': 1},
      {'userId': 'user_13', 'name': 'Mike Chen', 'xp': 1500, 'racesWon': 0, 'podiumFinishes': 1},
      {'userId': 'user_14', 'name': 'Nina Patel', 'xp': 1200, 'racesWon': 0, 'podiumFinishes': 0},
      {'userId': 'user_15', 'name': 'Oscar Lopez', 'xp': 1000, 'racesWon': 0, 'podiumFinishes': 0},
    ];

    final batch = firestore.batch();
    int count = 0;

    for (var userData in testUsers) {
      // Create user profile
      final userProfileRef = firestore.collection('users').doc(userData['userId'] as String);
      batch.set(userProfileRef, {
        'uid': userData['userId'],
        'name': userData['name'],
        'profilePicture': null,
        'email': '${userData['userId']}@test.com',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create season XP
      final seasonXP = SeasonXP(
        userId: userData['userId'] as String,
        seasonId: season.id,
        seasonXP: userData['xp'] as int,
        racesCompleted: (userData['racesWon'] as int) + 2,
        racesWon: userData['racesWon'] as int,
        podiumFinishes: userData['podiumFinishes'] as int,
      );

      final seasonXPRef = firestore
          .collection('season_xp')
          .doc(season.id)
          .collection('users')
          .doc(userData['userId'] as String);

      batch.set(seasonXPRef, seasonXP.toFirestore());

      count++;
    }

    await batch.commit();
    log('✅ Created $count test users with season XP');

    // Step 4: Add current user to Season 1 with some XP
    log('👤 Adding current user to Season 1...');

    log('🎉 Season data initialization completed successfully!');
    log('📊 Created ${testUsers.length} test users');
    log('🏆 Season 1 is now active and ready');

  } catch (e, stackTrace) {
    log('❌ Error initializing season data: $e');
    log('Stack trace: $stackTrace');
    rethrow;
  }
}