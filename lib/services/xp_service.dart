import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/xp_models.dart';
import '../models/race_models.dart';
import '../core/models/race_data_model.dart';
import '../models/season_model.dart';
import 'season_service.dart';

/// Service for calculating and managing XP (Experience Points)
class XPService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SeasonService _seasonService = SeasonService();

  /// Calculate base XP based on distance bracket
  /// 5-10 km = 50 XP
  /// 10-15 km = 100 XP
  /// 15-20 km = 200 XP
  int calculateBaseXP(double distance) {
    if (distance >= 15 && distance <= 20) {
      return 200;
    } else if (distance >= 10 && distance < 15) {
      return 100;
    } else if (distance >= 5 && distance < 10) {
      return 50;
    } else {
      // For races shorter than 5km or longer than 20km, use proportional scaling
      if (distance < 5) {
        return (50 * (distance / 5)).round();
      } else {
        // For > 20km, give proportional bonus
        return (200 * (distance / 15)).round();
      }
    }
  }

  /// Calculate distance multiplier
  /// Formula: distance ÷ 5
  double calculateDistanceMultiplier(double distance) {
    return distance / 5.0;
  }

  /// Calculate participation XP
  /// Formula: Base XP × Distance Multiplier
  int calculateParticipationXP(double distance) {
    final baseXP = calculateBaseXP(distance);
    final multiplier = calculateDistanceMultiplier(distance);
    return (baseXP * multiplier).round();
  }

  /// Calculate placement XP based on rank
  /// 1st Place = 500 XP
  /// 2nd Place = 300 XP
  /// 3rd Place = 200 XP
  int calculatePlacementXP(int rank) {
    switch (rank) {
      case 1:
        return 500;
      case 2:
        return 300;
      case 3:
        return 200;
      default:
        return 0; // No placement XP for ranks > 3
    }
  }

  /// Calculate bonus XP for extraordinary achievements
  /// e.g., fastest average walking speed
  int calculateBonusXP({
    required double avgSpeed,
    required List<Participant> allParticipants,
    required String userId,
  }) {
    if (allParticipants.isEmpty) return 0;

    // Find the fastest average speed among all participants
    double fastestSpeed = 0.0;
    for (var participant in allParticipants) {
      if (participant.avgSpeed > fastestSpeed) {
        fastestSpeed = participant.avgSpeed;
      }
    }

    // Award bonus if this user has the fastest speed
    final currentParticipant = allParticipants.firstWhere(
      (p) => p.userId == userId,
      orElse: () => Participant(
        userId: userId,
        userName: '',
        distance: 0,
        remainingDistance: 0,
        rank: 0,
        steps: 0,
        avgSpeed: avgSpeed,
      ),
    );

    if (currentParticipant.avgSpeed == fastestSpeed && fastestSpeed > 0) {
      // Award 100 bonus XP for fastest speed
      return 100;
    }

    return 0;
  }

  /// Calculate total XP for a race participant
  /// Returns RaceXPResult with complete breakdown
  RaceXPResult calculateRaceXP({
    required String raceId,
    required String userId,
    required RaceParticipantModel participant,
    required RaceModel race,
    required List<Participant> allParticipants,
  }) {
    final distance = race.totalDistance;
    final rank = participant.rank;
    final avgSpeed = participant.avgSpeed;

    // Calculate each component
    final baseXP = calculateBaseXP(distance);
    final distanceMultiplier = calculateDistanceMultiplier(distance);
    final participationXP = calculateParticipationXP(distance);
    final placementXP = calculatePlacementXP(rank);
    final bonusXP = calculateBonusXP(
      avgSpeed: avgSpeed,
      allParticipants: allParticipants,
      userId: userId,
    );

    final totalXP = participationXP + placementXP + bonusXP;

    // Create breakdown
    final breakdown = XPBreakdown(
      baseXP: baseXP,
      distanceMultiplier: distanceMultiplier,
      participationXP: participationXP,
      placementXP: placementXP,
      bonusXP: bonusXP,
      bonusReason: bonusXP > 0 ? 'Fastest Average Speed' : '',
    );

    return RaceXPResult(
      raceId: raceId,
      userId: userId,
      participationXP: participationXP,
      placementXP: placementXP,
      bonusXP: bonusXP,
      totalXP: totalXP,
      rank: rank,
      distance: distance,
      avgSpeed: avgSpeed,
      raceTitle: race.title,
      breakdown: breakdown,
    );
  }

  /// Award XP to all participants when race completes
  /// This should be called when race status changes to 'completed' (statusId = 4)
  Future<void> awardXPToParticipants(String raceId) async {
    try {
      log('🏆 Starting XP award process for race: $raceId');

      // Get race data
      final raceDoc = await _firestore.collection('races').doc(raceId).get();
      if (!raceDoc.exists) {
        log('❌ Race not found: $raceId');
        return;
      }

      final race = RaceModel.fromFirestore(raceDoc);

      // Get all participants
      // ✅ FIXED: Standardized to use races subcollection
      final participantsSnapshot = await _firestore
          .collection('races')
          .doc(raceId)
          .collection('participants')
          .get();

      if (participantsSnapshot.docs.isEmpty) {
        log('⚠️ No participants found for race: $raceId');
        return;
      }

      // Convert to participant models
      final participants = participantsSnapshot.docs
          .map((doc) => RaceParticipantModel.fromFirestore(doc))
          .toList();

      // Sort by rank to ensure correct ranking
      participants.sort((a, b) => a.rank.compareTo(b.rank));

      // ✅ OPTIMIZED: Get all participants from subcollection for bonus calculation
      // Convert RaceParticipantModel to Participant for backward compatibility
      final allParticipants = participants.map((p) => Participant(
        userId: p.userId,
        userName: p.userName ?? 'Unknown',
        distance: p.distance,
        remainingDistance: p.remainingDistance,
        rank: p.rank,
        steps: p.steps,
        avgSpeed: p.avgSpeed,
        isCompleted: p.isCompleted,
      )).toList();

      // Calculate and award XP for each participant
      final batch = _firestore.batch();
      final xpResults = <RaceXPResult>[];

      for (var participant in participants) {
        // Only award XP to participants who completed the race
        if (!participant.isCompleted) {
          log('⏭️ Skipping incomplete participant: ${participant.userId}');
          continue;
        }

        // Calculate XP
        final xpResult = calculateRaceXP(
          raceId: raceId,
          userId: participant.userId,
          participant: participant,
          race: race,
          allParticipants: allParticipants,
        );

        xpResults.add(xpResult);

        // Update or create user_xp document (lifetime XP)
        await _updateUserXP(
          userId: participant.userId,
          xpToAdd: xpResult.totalXP,
          rank: participant.rank,
          race: race,
          batch: batch,
        );

        // Update season XP (don't use batch here to avoid size limits)
        await _updateSeasonXP(
          userId: participant.userId,
          xpToAdd: xpResult.totalXP,
          rank: participant.rank,
        );

        // Create XP transaction record
        final transactionRef = _firestore.collection('xp_transactions').doc();
        batch.set(transactionRef, {
          'userId': participant.userId,
          'xpAmount': xpResult.totalXP,
          'source': 'race_completion',
          'sourceId': raceId,
          'description': 'Earned ${xpResult.totalXP} XP from "${race.title}"',
          'timestamp': FieldValue.serverTimestamp(),
          'metadata': xpResult.toJson(),
        });

        // Store race XP result
        final resultRef = _firestore
            .collection('race_xp_results')
            .doc('${raceId}_${participant.userId}');
        batch.set(resultRef, xpResult.toFirestore());

        log('✅ Calculated XP for ${participant.userId}: ${xpResult.totalXP} (Participation: ${xpResult.participationXP}, Placement: ${xpResult.placementXP}, Bonus: ${xpResult.bonusXP})');

        // 🎁 Award first win XP if this is 1st place (100 XP one-time)
        if (participant.rank == 1) {
          try {
            await awardFirstWinXP(
              userId: participant.userId,
              raceId: raceId,
              raceTitle: race.title ?? 'Race',
            );
          } catch (e) {
            log('⚠️ Failed to award first win XP to ${participant.userId}: $e');
          }
        }
      }

      // Commit all changes atomically
      await batch.commit();

      log('🎉 Successfully awarded XP to ${xpResults.length} participants for race: $raceId');
    } catch (e, stackTrace) {
      log('❌ Error awarding XP for race $raceId: $e');
      log('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Update user's total XP and stats
  Future<void> _updateUserXP({
    required String userId,
    required int xpToAdd,
    required int rank,
    required RaceModel race,
    required WriteBatch batch,
  }) async {
    final userXPRef = _firestore.collection('user_xp').doc(userId);
    final userXPDoc = await userXPRef.get();

    if (userXPDoc.exists) {
      // Update existing XP record
      final currentXP = UserXP.fromFirestore(userXPDoc);
      final newTotalXP = currentXP.totalXP + xpToAdd;
      final newLevel = UserXP.calculateLevel(newTotalXP);
      final newRacesCompleted = currentXP.racesCompleted + 1;
      final newRacesWon = rank == 1 ? currentXP.racesWon + 1 : currentXP.racesWon;
      final newPodiumFinishes = rank <= 3 ? currentXP.podiumFinishes + 1 : currentXP.podiumFinishes;

      batch.update(userXPRef, {
        'totalXP': newTotalXP,
        'level': newLevel,
        'racesCompleted': newRacesCompleted,
        'racesWon': newRacesWon,
        'podiumFinishes': newPodiumFinishes,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } else {
      // Create new XP record
      // Try to get user's location from their profile
      String? country;
      String? city;

      try {
        final userProfileDoc = await _firestore.collection('users').doc(userId).get();
        if (userProfileDoc.exists) {
          final profileData = userProfileDoc.data();
          country = profileData?['country'];
          city = profileData?['city'];
          // Fallback to location field if country/city not available
          if (country == null && profileData?['location'] != null) {
            final location = profileData!['location'] as String;
            // Try to parse location (assuming format like "City, Country")
            final parts = location.split(',');
            if (parts.length >= 2) {
              city = parts[0].trim();
              country = parts[1].trim();
            } else {
              city = location;
            }
          }
        }
      } catch (e) {
        log('⚠️ Could not fetch user location: $e');
      }

      final newUserXP = UserXP(
        userId: userId,
        totalXP: xpToAdd,
        level: UserXP.calculateLevel(xpToAdd),
        country: country,
        city: city,
        racesCompleted: 1,
        racesWon: rank == 1 ? 1 : 0,
        podiumFinishes: rank <= 3 ? 1 : 0,
        createdAt: DateTime.now(),
      );

      batch.set(userXPRef, newUserXP.toFirestore());
    }
  }

  /// Get user's XP data
  Future<UserXP?> getUserXP(String userId) async {
    try {
      final doc = await _firestore.collection('user_xp').doc(userId).get();
      if (doc.exists) {
        return UserXP.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      log('❌ Error getting user XP: $e');
      return null;
    }
  }

  /// Get user's XP history (transactions)
  Stream<List<XPTransaction>> getUserXPHistory(String userId, {int limit = 50}) {
    return _firestore
        .collection('xp_transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => XPTransaction.fromFirestore(doc)).toList());
  }

  /// Get race XP result for a specific user and race
  Future<RaceXPResult?> getRaceXPResult(String raceId, String userId) async {
    try {
      final doc = await _firestore
          .collection('race_xp_results')
          .doc('${raceId}_$userId')
          .get();

      if (doc.exists) {
        return RaceXPResult.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      log('❌ Error getting race XP result: $e');
      return null;
    }
  }

  /// Manually award bonus XP to a user (admin function)
  Future<void> awardBonusXP({
    required String userId,
    required int xpAmount,
    required String reason,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final batch = _firestore.batch();

      // Update user's total XP
      final userXPRef = _firestore.collection('user_xp').doc(userId);
      final userXPDoc = await userXPRef.get();

      if (userXPDoc.exists) {
        final currentXP = UserXP.fromFirestore(userXPDoc);
        final newTotalXP = currentXP.totalXP + xpAmount;
        final newLevel = UserXP.calculateLevel(newTotalXP);

        batch.update(userXPRef, {
          'totalXP': newTotalXP,
          'level': newLevel,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new XP record if doesn't exist
        final newUserXP = UserXP(
          userId: userId,
          totalXP: xpAmount,
          level: UserXP.calculateLevel(xpAmount),
          createdAt: DateTime.now(),
        );
        batch.set(userXPRef, newUserXP.toFirestore());
      }

      // Create transaction record
      final transactionRef = _firestore.collection('xp_transactions').doc();
      batch.set(transactionRef, {
        'userId': userId,
        'xpAmount': xpAmount,
        'source': 'bonus',
        'sourceId': null,
        'description': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata,
      });

      await batch.commit();
      log('✅ Awarded bonus XP: $xpAmount to user $userId - Reason: $reason');
    } catch (e) {
      log('❌ Error awarding bonus XP: $e');
      rethrow;
    }
  }

  /// Update user's season XP
  Future<void> _updateSeasonXP({
    required String userId,
    required int xpToAdd,
    required int rank,
  }) async {
    try {
      // Get current season
      final currentSeason = await _seasonService.getCurrentSeason();
      if (currentSeason == null) {
        log('⚠️ No current season found, skipping season XP update');
        return;
      }

      // Update season XP
      await _seasonService.updateUserSeasonXP(
        userId: userId,
        seasonId: currentSeason.id,
        xpToAdd: xpToAdd,
        wonRace: rank == 1,
        isPodium: rank <= 3,
      );

      log('✅ Updated season XP for user $userId in ${currentSeason.name}: +$xpToAdd XP');
    } catch (e) {
      log('❌ Error updating season XP: $e');
      // Don't rethrow - season XP is supplementary, shouldn't block main XP
    }
  }

  /// Award XP for joining a race
  /// Gives a small participation bonus to encourage joining races
  ///
  /// XP Amount: 10 XP (fixed)
  ///
  /// This creates early engagement and populates the leaderboard
  Future<void> awardJoinRaceXP({
    required String userId,
    required String raceId,
    required String raceTitle,
  }) async {
    try {
      log('🎯 Awarding join race XP to user: $userId for race: $raceId');

      const int joinXP = 10; // Fixed XP for joining a race

      final batch = _firestore.batch();

      // Update user's total XP
      final userXPRef = _firestore.collection('user_xp').doc(userId);
      final userXPDoc = await userXPRef.get();

      if (userXPDoc.exists) {
        // Update existing XP record
        final currentXP = UserXP.fromFirestore(userXPDoc);
        final newTotalXP = currentXP.totalXP + joinXP;
        final newLevel = UserXP.calculateLevel(newTotalXP);

        batch.update(userXPRef, {
          'totalXP': newTotalXP,
          'level': newLevel,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new XP record
        // Try to get user's location from their profile
        String? country;
        String? city;

        try {
          final userProfileDoc = await _firestore.collection('users').doc(userId).get();
          if (userProfileDoc.exists) {
            final profileData = userProfileDoc.data();
            country = profileData?['country'];
            city = profileData?['city'];
            // Fallback to location field if country/city not available
            if (country == null && profileData?['location'] != null) {
              final location = profileData!['location'] as String;
              // Try to parse location (assuming format like "City, Country")
              final parts = location.split(',');
              if (parts.length >= 2) {
                city = parts[0].trim();
                country = parts[1].trim();
              } else {
                city = location;
              }
            }
          }
        } catch (e) {
          log('⚠️ Could not fetch user location: $e');
        }

        final newUserXP = UserXP(
          userId: userId,
          totalXP: joinXP,
          level: UserXP.calculateLevel(joinXP),
          country: country,
          city: city,
          racesCompleted: 0,
          racesWon: 0,
          podiumFinishes: 0,
          createdAt: DateTime.now(),
        );

        batch.set(userXPRef, newUserXP.toFirestore());
      }

      // Update season XP (don't use batch here to avoid size limits)
      await _updateSeasonXPForJoin(userId: userId, xpToAdd: joinXP);

      // Create XP transaction record
      final transactionRef = _firestore.collection('xp_transactions').doc();
      batch.set(transactionRef, {
        'userId': userId,
        'xpAmount': joinXP,
        'source': 'race_join',
        'sourceId': raceId,
        'description': 'Earned $joinXP XP for joining "$raceTitle"',
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': {
          'raceId': raceId,
          'raceTitle': raceTitle,
          'action': 'join_race',
        },
      });

      // Commit all changes atomically
      await batch.commit();

      log('✅ Awarded $joinXP XP to $userId for joining race: $raceTitle');
    } catch (e, stackTrace) {
      log('❌ Error awarding join race XP for user $userId: $e');
      log('Stack trace: $stackTrace');
      // Don't rethrow - joining should still succeed even if XP fails
    }
  }

  /// Update user's season XP for joining a race
  Future<void> _updateSeasonXPForJoin({
    required String userId,
    required int xpToAdd,
  }) async {
    try {
      // Get current season
      final currentSeason = await _seasonService.getCurrentSeason();
      if (currentSeason == null) {
        log('⚠️ No current season found, skipping season XP update for join');
        return;
      }

      // Update season XP (without incrementing race counts since race hasn't been completed)
      final docRef = _firestore
          .collection('season_xp')
          .doc(currentSeason.id)
          .collection('users')
          .doc(userId);

      final doc = await docRef.get();

      if (doc.exists) {
        // Update existing
        final current = SeasonXP.fromFirestore(doc);
        await docRef.update({
          'seasonXP': current.seasonXP + xpToAdd,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new
        final seasonXP = SeasonXP(
          userId: userId,
          seasonId: currentSeason.id,
          seasonXP: xpToAdd,
          seasonRank: 0,
          racesCompleted: 0,
          racesWon: 0,
          podiumFinishes: 0,
        );

        await docRef.set(seasonXP.toFirestore());
      }

      log('✅ Updated season XP for join: user $userId in ${currentSeason.name}: +$xpToAdd XP');
    } catch (e) {
      log('❌ Error updating season XP for join: $e');
      // Don't rethrow - season XP is supplementary
    }
  }

  /// Award XP for creating a race
  /// XP Amount: 15 XP (fixed)
  Future<void> awardCreateRaceXP({
    required String userId,
    required String raceId,
    required String raceTitle,
  }) async {
    try {
      log('🎯 Awarding create race XP to user: $userId for race: $raceId');

      const int createXP = 15;

      await _awardSimpleXP(
        userId: userId,
        xpAmount: createXP,
        source: 'race_create',
        sourceId: raceId,
        description: 'Earned $createXP XP for creating "$raceTitle"',
      );

      log('✅ Awarded $createXP XP to $userId for creating race: $raceTitle');
    } catch (e, stackTrace) {
      log('❌ Error awarding create race XP for user $userId: $e');
      log('Stack trace: $stackTrace');
    }
  }

  /// Award XP for reaching a race milestone (25%, 50%, 75%)
  /// XP Amount: 5 XP per milestone
  Future<void> awardMilestoneXP({
    required String userId,
    required String raceId,
    required String raceTitle,
    required int milestonePercent,
  }) async {
    try {
      log('🎯 Awarding milestone XP to user: $userId for $milestonePercent% in race: $raceId');

      const int milestoneXP = 5;

      await _awardSimpleXP(
        userId: userId,
        xpAmount: milestoneXP,
        source: 'race_milestone',
        sourceId: raceId,
        description: 'Earned $milestoneXP XP for reaching $milestonePercent% in "$raceTitle"',
        metadata: {'milestone': milestonePercent},
      );

      log('✅ Awarded $milestoneXP XP to $userId for $milestonePercent% milestone');
    } catch (e, stackTrace) {
      log('❌ Error awarding milestone XP for user $userId: $e');
      log('Stack trace: $stackTrace');
    }
  }

  /// Award XP for completing profile (one-time)
  /// XP Amount: 30 XP (one-time only)
  Future<void> awardProfileCompletionXP({
    required String userId,
  }) async {
    try {
      log('🎯 Checking if profile completion XP already awarded for user: $userId');

      // Check if already awarded
      final existingTransaction = await _firestore
          .collection('xp_transactions')
          .where('userId', isEqualTo: userId)
          .where('source', isEqualTo: 'profile_complete')
          .limit(1)
          .get();

      if (existingTransaction.docs.isNotEmpty) {
        log('⏭️ Profile completion XP already awarded to user: $userId');
        return;
      }

      const int profileXP = 30;

      await _awardSimpleXP(
        userId: userId,
        xpAmount: profileXP,
        source: 'profile_complete',
        sourceId: null,
        description: 'Earned $profileXP XP for completing your profile',
      );

      log('✅ Awarded $profileXP XP to $userId for profile completion');
    } catch (e, stackTrace) {
      log('❌ Error awarding profile completion XP for user $userId: $e');
      log('Stack trace: $stackTrace');
    }
  }

  /// Award XP for first race ever (one-time)
  /// XP Amount: 50 XP (one-time only)
  Future<void> awardFirstRaceXP({
    required String userId,
    required String raceId,
    required String raceTitle,
  }) async {
    try {
      log('🎯 Checking if first race XP already awarded for user: $userId');

      // Check if already awarded
      final existingTransaction = await _firestore
          .collection('xp_transactions')
          .where('userId', isEqualTo: userId)
          .where('source', isEqualTo: 'first_race')
          .limit(1)
          .get();

      if (existingTransaction.docs.isNotEmpty) {
        log('⏭️ First race XP already awarded to user: $userId');
        return;
      }

      const int firstRaceXP = 50;

      await _awardSimpleXP(
        userId: userId,
        xpAmount: firstRaceXP,
        source: 'first_race',
        sourceId: raceId,
        description: 'Earned $firstRaceXP XP for joining your first race: "$raceTitle"',
      );

      log('✅ Awarded $firstRaceXP XP to $userId for first race');
    } catch (e, stackTrace) {
      log('❌ Error awarding first race XP for user $userId: $e');
      log('Stack trace: $stackTrace');
    }
  }

  /// Award XP for first win (one-time)
  /// XP Amount: 100 XP (one-time only)
  Future<void> awardFirstWinXP({
    required String userId,
    required String raceId,
    required String raceTitle,
  }) async {
    try {
      log('🎯 Checking if first win XP already awarded for user: $userId');

      // Check if already awarded
      final existingTransaction = await _firestore
          .collection('xp_transactions')
          .where('userId', isEqualTo: userId)
          .where('source', isEqualTo: 'first_win')
          .limit(1)
          .get();

      if (existingTransaction.docs.isNotEmpty) {
        log('⏭️ First win XP already awarded to user: $userId');
        return;
      }

      const int firstWinXP = 100;

      await _awardSimpleXP(
        userId: userId,
        xpAmount: firstWinXP,
        source: 'first_win',
        sourceId: raceId,
        description: 'Earned $firstWinXP XP for winning your first race: "$raceTitle"',
      );

      log('✅ Awarded $firstWinXP XP to $userId for first win');
    } catch (e, stackTrace) {
      log('❌ Error awarding first win XP for user $userId: $e');
      log('Stack trace: $stackTrace');
    }
  }

  /// Award XP for adding a friend
  /// XP Amount: 20 XP per friend added
  Future<void> awardAddFriendXP({
    required String userId,
    required String friendId,
    required String friendName,
  }) async {
    try {
      log('🎯 Awarding add friend XP to user: $userId for adding: $friendName');

      const int friendXP = 20;

      await _awardSimpleXP(
        userId: userId,
        xpAmount: friendXP,
        source: 'add_friend',
        sourceId: friendId,
        description: 'Earned $friendXP XP for adding $friendName as a friend',
      );

      log('✅ Awarded $friendXP XP to $userId for adding friend: $friendName');
    } catch (e, stackTrace) {
      log('❌ Error awarding add friend XP for user $userId: $e');
      log('Stack trace: $stackTrace');
    }
  }

  /// Helper method to award simple XP (reusable for various events)
  Future<void> _awardSimpleXP({
    required String userId,
    required int xpAmount,
    required String source,
    required String? sourceId,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    final batch = _firestore.batch();

    // Update user's total XP
    final userXPRef = _firestore.collection('user_xp').doc(userId);
    final userXPDoc = await userXPRef.get();

    if (userXPDoc.exists) {
      final currentXP = UserXP.fromFirestore(userXPDoc);
      final newTotalXP = currentXP.totalXP + xpAmount;
      final newLevel = UserXP.calculateLevel(newTotalXP);

      batch.update(userXPRef, {
        'totalXP': newTotalXP,
        'level': newLevel,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } else {
      // Create new XP record
      final newUserXP = UserXP(
        userId: userId,
        totalXP: xpAmount,
        level: UserXP.calculateLevel(xpAmount),
        createdAt: DateTime.now(),
      );
      batch.set(userXPRef, newUserXP.toFirestore());
    }

    // Update season XP
    await _updateSeasonXPForSimple(userId: userId, xpToAdd: xpAmount);

    // Create XP transaction record
    final transactionRef = _firestore.collection('xp_transactions').doc();
    batch.set(transactionRef, {
      'userId': userId,
      'xpAmount': xpAmount,
      'source': source,
      'sourceId': sourceId,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
      if (metadata != null) 'metadata': metadata,
    });

    await batch.commit();
  }

  /// Update user's season XP for simple events (without race completion stats)
  Future<void> _updateSeasonXPForSimple({
    required String userId,
    required int xpToAdd,
  }) async {
    try {
      final currentSeason = await _seasonService.getCurrentSeason();
      if (currentSeason == null) {
        log('⚠️ No current season found, skipping season XP update');
        return;
      }

      final docRef = _firestore
          .collection('season_xp')
          .doc(currentSeason.id)
          .collection('users')
          .doc(userId);

      final doc = await docRef.get();

      if (doc.exists) {
        final current = SeasonXP.fromFirestore(doc);
        await docRef.update({
          'seasonXP': current.seasonXP + xpToAdd,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        final seasonXP = SeasonXP(
          userId: userId,
          seasonId: currentSeason.id,
          seasonXP: xpToAdd,
          seasonRank: 0,
          racesCompleted: 0,
          racesWon: 0,
          podiumFinishes: 0,
        );
        await docRef.set(seasonXP.toFirestore());
      }

      log('✅ Updated season XP: user $userId in ${currentSeason.name}: +$xpToAdd XP');
    } catch (e) {
      log('❌ Error updating season XP: $e');
    }
  }
}