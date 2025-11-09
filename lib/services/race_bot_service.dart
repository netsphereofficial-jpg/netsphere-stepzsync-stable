import 'dart:async';
import 'dart:developer';
import 'dart:math' hide log;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../core/models/race_data_model.dart';
import 'race_service.dart';

/// Realistic bot movement profile - simulates human racing behavior
class BotMovementProfile {
  final String botId;
  final String botName;
  final String botType; // Personality type (Walker, Jogger, Runner, Fast, Elite)
  final double baseSpeed; // m/s
  final double consistency; // 0.0-1.0 (how consistent is the pace)
  final double restFrequency; // How often bot takes breaks (0-100 percentage)
  final double sprintTendency; // Likelihood to speed up (0-100 percentage)
  final double fatigueRate; // How quickly bot gets tired

  // Current state
  bool isResting = false;
  DateTime? restStartTime;
  int restDuration = 0; // seconds
  double fatigueLevel = 0.0; // 0.0-1.0
  double currentDistance = 0.0;
  DateTime lastUpdate = DateTime.now();

  // Momentum and warm-up tracking
  double currentMomentum = 0.6; // Start at 60% of base speed (warm-up phase)
  bool isWarmedUp = false;

  BotMovementProfile({
    required this.botId,
    required this.botName,
    required this.botType,
    required this.baseSpeed,
    required this.consistency,
    required this.restFrequency,
    required this.sprintTendency,
    required this.fatigueRate,
  });

  /// Log bot creation with personality details
  void logCreation(double speed) {
    log('🤖 Bot $botName ($botType): ${(speed * 3.6).toStringAsFixed(1)} km/h, rest=${restFrequency.toStringAsFixed(0)}%, sprint=${sprintTendency.toStringAsFixed(0)}%, fatigue=${(fatigueRate * 100).toStringAsFixed(0)}%');
  }
}

/// Service for managing realistic bot participants in races
/// Bots are completely indistinguishable from real users in Firebase
class RaceBotService extends GetxService {
  static RaceBotService get instance => Get.find<RaceBotService>();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // In-memory bot tracking (NOT stored in Firebase!)
  final Map<String, List<BotMovementProfile>> _activeBots = {};
  final Map<String, Timer?> _raceTimers = {};
  final Random _random = Random();

  // ✅ NEW: Bot health monitoring
  final Map<String, int> _botFailureCount = {};
  final Map<String, DateTime> _lastSuccessfulUpdate = {};
  final Map<String, Timer?> _healthCheckTimers = {};

  // Constants (match StepTrackingService for consistency)
  static const double _averageStepLength = 0.1; // meters per step (same as real users)
  static const double _caloriesPerStep = 0.05; // calories per step (same as real users)

  // Realistic first names pool (100+ names)
  static const List<String> _realisticNames = [
    // Male names
    'Alex', 'Michael', 'David', 'James', 'John', 'Robert', 'Daniel', 'Chris',
    'Matthew', 'Ryan', 'Kevin', 'Brian', 'Andrew', 'Thomas', 'Brandon', 'Jason',
    'Justin', 'Eric', 'Adam', 'Steven', 'Joshua', 'Nathan', 'Tyler', 'Jacob',
    'Aaron', 'Kyle', 'Ian', 'Luke', 'Sean', 'Mark', 'Paul', 'Peter', 'Patrick',

    // Female names
    'Sarah', 'Emily', 'Jessica', 'Ashley', 'Jennifer', 'Amanda', 'Stephanie',
    'Lauren', 'Rachel', 'Nicole', 'Samantha', 'Melissa', 'Lisa', 'Amy', 'Rebecca',
    'Laura', 'Brittany', 'Megan', 'Hannah', 'Emma', 'Olivia', 'Sophia', 'Isabella',
    'Madison', 'Abigail', 'Chloe', 'Grace', 'Victoria', 'Natalie', 'Anna', 'Julia',

    // Gender-neutral
    'Jordan', 'Taylor', 'Casey', 'Morgan', 'Riley', 'Avery', 'Quinn', 'Cameron',
    'Dakota', 'Skylar', 'Parker', 'Alexis', 'Blake', 'Reese', 'Peyton',

    // International
    'Arjun', 'Priya', 'Wei', 'Li', 'Yuki', 'Mei', 'Mohammed', 'Fatima',
    'Carlos', 'Maria', 'Luis', 'Ana', 'Diego', 'Sofia', 'Marco', 'Lucia',
    'Hassan', 'Amira', 'Raj', 'Anjali', 'Min', 'Hana', 'Omar', 'Layla',
  ];

  /// Add bots to a race to fill empty slots
  Future<void> addBotsToRace({
    required String raceId,
    required int botCount,
    required double raceDistance, // in meters
  }) async {
    try {
      log('🤖 Adding $botCount realistic bots to race $raceId');

      final batch = _firestore.batch();
      final List<BotMovementProfile> botProfiles = [];
      final usedNames = <String>{}; // Track used names to avoid duplicates

      for (int i = 0; i < botCount; i++) {
        // Generate realistic bot ID (looks like real user ID)
        final botId = _generateRealisticUserId();

        // Pick unique realistic name
        String botName;
        do {
          botName = _realisticNames[_random.nextInt(_realisticNames.length)];
        } while (usedNames.contains(botName) && usedNames.length < _realisticNames.length);
        usedNames.add(botName);

        // Create movement profile (realistic personality)
        final profile = _createRandomBotProfile(botId, botName);
        botProfiles.add(profile);

        // Create participant document (indistinguishable from real user)
        final participantRef = _firestore
            .collection('races')
            .doc(raceId)
            .collection('participants')
            .doc(botId);

        final participant = Participant(
          userId: botId,
          userName: botName,
          distance: 0.0, // Starting distance in KM
          remainingDistance: raceDistance / 1000, // Convert meters to KM (matches Participant model)
          rank: 1,
          steps: 0,
          status: 'joined',
          lastUpdated: DateTime.now(),
          calories: 0,
          avgSpeed: 0.0,
          isCompleted: false,
        );

        batch.set(participantRef, participant.toFirestore());
      }

      // Update race joinedParticipants count
      final raceRef = _firestore.collection('races').doc(raceId);
      batch.update(raceRef, {
        'joinedParticipants': FieldValue.increment(botCount),
      });

      await batch.commit();

      // Store bot profiles in memory only (not in Firebase!)
      _activeBots[raceId] = botProfiles;

      log('✅ Successfully added $botCount bots to race $raceId');
    } catch (e) {
      log('❌ Error adding bots to race: $e');
      rethrow;
    }
  }

  /// ✅ NEW: Recreate bot profiles from existing Firebase participant data
  /// This is needed when app restarts or when restarting bot simulation
  Future<void> recreateBotProfiles(String raceId, List<Participant> participants) async {
    try {
      log('🔄 DEBUG: recreateBotProfiles called for race $raceId');
      log('📊 DEBUG: Total participants received: ${participants.length}');

      final List<BotMovementProfile> botProfiles = [];

      // Filter bots (userId starts with 'u_')
      final bots = participants.where((p) => p.userId.startsWith('u_')).toList();
      log('🤖 DEBUG: Filtered ${bots.length} bot participants from ${participants.length} total');

      if (bots.isEmpty) {
        log('⚠️ DEBUG: No bots found to recreate profiles for race $raceId');
        // Store empty list to prevent null errors
        _activeBots[raceId] = botProfiles;
        return;
      }

      log('🤖 DEBUG: Bot userIds: ${bots.map((b) => b.userId).join(", ")}');
      log('🤖 DEBUG: Bot names: ${bots.map((b) => b.userName).join(", ")}');

      for (final bot in bots) {
        log('🔨 DEBUG: Creating profile for bot ${bot.userName} (${bot.userId})');

        // Create movement profile with similar characteristics to original
        final profile = _createRandomBotProfile(bot.userId, bot.userName);
        log('   📝 DEBUG: Profile created - Type: ${profile.botType}, Speed: ${(profile.baseSpeed * 3.6).toStringAsFixed(1)} km/h');

        // ✅ CRITICAL: Restore current state from Firebase
        final distanceKm = bot.distance ?? 0.0;
        profile.currentDistance = distanceKm * 1000; // Convert KM to meters
        profile.lastUpdate = DateTime.now();
        log('   📍 DEBUG: Restored distance: ${distanceKm}km (${profile.currentDistance.toStringAsFixed(1)}m)');

        // If bot has already covered some distance, consider them warmed up
        if (profile.currentDistance > 100) {
          profile.isWarmedUp = true;
          profile.currentMomentum = 1.0;
          log('   🔥 DEBUG: Bot is warmed up (distance > 100m)');
        } else {
          log('   ❄️ DEBUG: Bot needs warm-up (distance <= 100m)');
        }

        botProfiles.add(profile);
        log('✅ DEBUG: Successfully recreated profile for bot ${bot.userName}');
      }

      // Store bot profiles in memory
      _activeBots[raceId] = botProfiles;
      log('💾 DEBUG: Stored ${botProfiles.length} bot profiles in memory for race $raceId');
      log('🗂️ DEBUG: Total races with active bots: ${_activeBots.length}');
      log('📋 DEBUG: Active race IDs: ${_activeBots.keys.join(", ")}');

      log('✅ Successfully recreated ${botProfiles.length} bot profiles for race $raceId');
    } catch (e, stackTrace) {
      log('❌ Error recreating bot profiles: $e');
      log('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// ✅ IMPROVED: Start bot simulation with health monitoring and auto-restart
  Future<void> startBotSimulation(String raceId) async {
    try {
      log('🏁 DEBUG: startBotSimulation called for race $raceId');

      // ✅ CRITICAL CHECK: Ensure bot profiles exist before starting
      log('🔍 DEBUG: Checking if race $raceId has bot profiles...');
      log('🔍 DEBUG: _activeBots contains race? ${_activeBots.containsKey(raceId)}');

      if (!_activeBots.containsKey(raceId)) {
        log('⚠️ DEBUG: Race $raceId NOT found in _activeBots map');
        log('⚠️ DEBUG: Available race IDs in _activeBots: ${_activeBots.keys.join(", ")}');
        log('⚠️ Cannot start bot simulation - no bot profiles found for race $raceId');
        log('⚠️ Make sure to call recreateBotProfiles() or addBotsToRace() first');
        return;
      }

      final botProfiles = _activeBots[raceId]!;
      log('✅ DEBUG: Found ${botProfiles.length} bot profiles for race $raceId');

      if (botProfiles.isEmpty) {
        log('⚠️ DEBUG: Bot profiles list is EMPTY for race $raceId');
        log('⚠️ Cannot start bot simulation - no bot profiles found for race $raceId');
        log('⚠️ Make sure to call recreateBotProfiles() or addBotsToRace() first');
        return;
      }

      // Log bot details
      for (final profile in botProfiles) {
        log('   🤖 Bot: ${profile.botName} (${profile.botId}) - ${profile.botType} - ${(profile.baseSpeed * 3.6).toStringAsFixed(1)} km/h - Current: ${profile.currentDistance.toStringAsFixed(1)}m');
      }

      // Cancel any existing timer (but keep bot profiles)
      if (_raceTimers.containsKey(raceId)) {
        log('🔄 DEBUG: Cancelling existing timer for race $raceId');
        _raceTimers[raceId]?.cancel();
        _raceTimers.remove(raceId);
      }

      // ✅ NEW: Initialize health tracking
      _botFailureCount[raceId] = 0;
      _lastSuccessfulUpdate[raceId] = DateTime.now();
      log('💊 DEBUG: Health tracking initialized for race $raceId');

      log('🏁 Starting realistic bot simulation with health monitoring for race $raceId (${botProfiles.length} bots)');

      // Start irregular update timer (2-5 second intervals)
      log('⏰ DEBUG: Starting irregular updates for race $raceId...');
      _startIrregularUpdates(raceId);

      // ✅ NEW: Start health check timer (runs every 60 seconds)
      log('🏥 DEBUG: Starting health check for race $raceId...');
      _startHealthCheck(raceId);

      log('✅ DEBUG: Bot simulation fully started for race $raceId');
    } catch (e, stackTrace) {
      log('❌ Error starting bot simulation: $e');
      log('Stack trace: $stackTrace');
    }
  }

  /// Stop bot simulation for a race (removes both timer and bot profiles)
  void stopBotSimulation(String raceId) {
    _raceTimers[raceId]?.cancel();
    _raceTimers.remove(raceId);
    _activeBots.remove(raceId);

    // ✅ NEW: Clean up health check timers
    _healthCheckTimers[raceId]?.cancel();
    _healthCheckTimers.remove(raceId);
    _botFailureCount.remove(raceId);
    _lastSuccessfulUpdate.remove(raceId);

    log('🛑 Stopped bot simulation for race $raceId');
  }

  /// Start irregular update pattern (realistic timing)
  void _startIrregularUpdates(String raceId) {
    // ✅ IMPROVED: Faster updates for more realistic racing action
    // Random interval: 5-10 seconds (realistic race progress visibility)
    final interval = Duration(
      milliseconds: 5000 + _random.nextInt(5000),
    );

    log('⏱️ DEBUG: Scheduling next bot update for race $raceId in ${interval.inSeconds}s (${interval.inMilliseconds}ms)');
    log('⏱️ DEBUG: Current time: ${DateTime.now().toIso8601String()}');

    _raceTimers[raceId] = Timer(interval, () async {
      log('⏰ DEBUG: ========== TIMER FIRED for race $raceId ==========');
      log('⏰ DEBUG: Timer execution time: ${DateTime.now().toIso8601String()}');
      log('⏰ DEBUG: Calling _updateAllBots...');

      await _updateAllBots(raceId);

      log('⏰ DEBUG: _updateAllBots completed, scheduling next update...');

      // Schedule next update with new random interval
      if (_activeBots.containsKey(raceId)) {
        log('✅ DEBUG: Race $raceId still has active bots, scheduling next update');
        _startIrregularUpdates(raceId);
      } else {
        log('⚠️ DEBUG: Race $raceId not in active bots map, stopping updates');
        log('⚠️ DEBUG: Available races: ${_activeBots.keys.join(", ")}');
      }
    });

    log('✅ DEBUG: Timer created and registered for race $raceId');
  }

  /// Update all bots in a race with realistic movement
  Future<void> _updateAllBots(String raceId) async {
    try {
      log('🔄 Attempting to update bots for race $raceId');
      final botProfiles = _activeBots[raceId];
      if (botProfiles == null || botProfiles.isEmpty) {
        log('⚠️ No bot profiles found for race $raceId');
        return;
      }
      log('📊 Found ${botProfiles.length} bots to update');

      // Get race data to know total distance
      final raceDoc = await _firestore.collection('races').doc(raceId).get();
      if (!raceDoc.exists) {
        log('⚠️ Race document not found: $raceId');
        return;
      }

      final raceData = RaceData.fromFirestore(raceDoc);
      final totalDistance = (raceData.totalDistance ?? 1.0) * 1000; // Convert to meters
      log('📏 Race total distance: ${totalDistance}m');

      final batch = _firestore.batch();
      int updatedCount = 0;
      final List<Map<String, dynamic>> completedBots = []; // Track bots that just finished

      for (final profile in botProfiles) {
        // ✅ FIXED: Don't skip completed bots - let them continue walking
        // This ensures continuous activity and eventual race clearing
        final hasCompletedRace = profile.currentDistance >= totalDistance;

        // Calculate realistic progress
        final elapsed = DateTime.now().difference(profile.lastUpdate).inSeconds.toDouble();

        // Calculate distance ratio (used for fatigue and rest calculations)
        final distanceRatio = profile.currentDistance / totalDistance;

        // Progressive rest frequency: Increases with fatigue and distance
        final fatigueRestMultiplier = 1.0 + (profile.fatigueLevel * 2.0); // 1x to 3x based on fatigue
        final progressRestMultiplier = 1.0 + distanceRatio; // 1x at start, 2x at finish
        final adjustedRestChance = (profile.restFrequency / 100) * fatigueRestMultiplier * progressRestMultiplier;

        // Check if bot should start/end resting
        if (!profile.isResting && _random.nextDouble() < adjustedRestChance) {
          // Start rest period - longer breaks as fatigue increases
          profile.isResting = true;
          profile.restStartTime = DateTime.now();
          // Rest duration: 15-90 seconds, longer when more fatigued
          final baseDuration = 15 + _random.nextInt(46); // 15-60 seconds base
          final fatigueDuration = (baseDuration * (1.0 + profile.fatigueLevel)).round(); // Up to 90s when fatigued
          profile.restDuration = fatigueDuration.clamp(15, 90);
          log('😴 Bot ${profile.botName} is taking a ${profile.restDuration}s break (fatigue: ${(profile.fatigueLevel * 100).toStringAsFixed(1)}%)');

          // ✅ CRITICAL FIX: Update lastUpdate when starting rest to prevent huge elapsed time on resume
          profile.lastUpdate = DateTime.now();
          continue; // No movement during rest start
        }

        // Check if rest period ended
        if (profile.isResting) {
          if (DateTime.now().difference(profile.restStartTime!).inSeconds >= profile.restDuration) {
            profile.isResting = false;
            final oldFatigue = profile.fatigueLevel;
            // Reduce fatigue slightly after rest (recovery mechanic)
            profile.fatigueLevel = (profile.fatigueLevel * 0.85).clamp(0.0, 1.0);
            // Reset momentum to 70% after rest (need to accelerate again)
            profile.currentMomentum = 0.7;

            // ✅ CRITICAL FIX: Reset lastUpdate when resuming to prevent huge elapsed time
            profile.lastUpdate = DateTime.now();
            log('💪 Bot ${profile.botName} resumed running (fatigue: ${(oldFatigue * 100).toStringAsFixed(0)}% → ${(profile.fatigueLevel * 100).toStringAsFixed(0)}%)');
          } else {
            // ✅ CRITICAL FIX: Update lastUpdate even while resting to prevent time accumulation
            profile.lastUpdate = DateTime.now();
            continue; // Still resting
          }
        }

        // Smooth momentum adjustments (gradual acceleration/deceleration)
        // Target momentum is 1.0 when running normally, affected by fatigue
        final targetMomentum = 1.0;
        final momentumAdjustment = (targetMomentum - profile.currentMomentum) * 0.15; // 15% adjustment per update
        profile.currentMomentum = (profile.currentMomentum + momentumAdjustment).clamp(0.5, 1.0);

        // Warm-up phase: Gradually increase momentum to 100% over first ~100 meters
        if (!profile.isWarmedUp) {
          profile.currentMomentum += 0.05; // Increase by 5% each update
          if (profile.currentMomentum >= 1.0 || profile.currentDistance > 100) {
            profile.currentMomentum = 1.0;
            profile.isWarmedUp = true;
            log('🔥 Bot ${profile.botName} is warmed up!');
          }
        }

        // Calculate current speed with natural variation
        double currentSpeed = profile.baseSpeed * profile.currentMomentum;

        // ✅ NEW: If bot has completed race, continue at reduced speed (slower walking)
        // This ensures continuous activity and prevents stalled races
        if (hasCompletedRace) {
          currentSpeed *= 0.5; // Move at 50% speed after completion (casual stroll)
          log('🚶 Bot ${profile.botName} continuing post-race at ${(currentSpeed * 3.6).toStringAsFixed(1)} km/h');
        }

        // Calculate distance-based fatigue using exponential model (more realistic)
        // Fatigue increases exponentially as race progresses
        final exponentialFatigue = 1.0 - exp(-profile.fatigueRate * distanceRatio * 3.0);
        final previousFatigue = profile.fatigueLevel;
        profile.fatigueLevel = exponentialFatigue.clamp(0.0, 0.7); // Max 70% fatigue

        // Log fatigue progression at key thresholds
        if (previousFatigue < 0.30 && profile.fatigueLevel >= 0.30) {
          log('😓 Bot ${profile.botName} getting tired (fatigue: ${(profile.fatigueLevel * 100).toStringAsFixed(0)}%)');
        } else if (previousFatigue < 0.50 && profile.fatigueLevel >= 0.50) {
          log('😰 Bot ${profile.botName} is exhausted! (fatigue: ${(profile.fatigueLevel * 100).toStringAsFixed(0)}%)');
        }

        // Add micro speed variation (±3-8% per update for smooth transitions)
        final speedMicroVariation = 0.95 + _random.nextDouble() * 0.10; // 95%-105%
        currentSpeed *= speedMicroVariation;

        // Apply consistency factor (less consistent = more variation)
        if (_random.nextDouble() > profile.consistency) {
          currentSpeed *= 0.85 + _random.nextDouble() * 0.30; // 85%-115%
        }

        // Sprint bursts - decrease frequency as fatigue increases
        final sprintChance = (profile.sprintTendency / 100) * (1.0 - profile.fatigueLevel);
        final isSprinting = _random.nextDouble() < sprintChance;
        if (isSprinting) {
          final oldSpeed = currentSpeed * 3.6; // Convert to km/h for logging
          currentSpeed *= 1.2 + _random.nextDouble() * 0.3; // 120%-150% (reduced from 130-170%)
          final newSpeed = currentSpeed * 3.6; // Convert to km/h for logging
          // Sprinting costs energy - increase fatigue
          profile.fatigueLevel = (profile.fatigueLevel + 0.05).clamp(0.0, 0.7);
          log('💨 Bot ${profile.botName} is sprinting! (${oldSpeed.toStringAsFixed(1)} → ${newSpeed.toStringAsFixed(1)} km/h)');
        }

        // Apply exponential fatigue slowdown (can reduce speed by up to 70%)
        currentSpeed *= (1.0 - profile.fatigueLevel * 0.85);

        // ✅ STEP-BASED CALCULATION (matches real user flow in StepTrackingService)
        // Step 1: Calculate expected distance based on speed and time
        final expectedDistance = currentSpeed * elapsed;

        // Step 2: Convert distance to steps (reverse of real user calculation)
        // Real users: distance = steps * averageStepLength / 1000
        // Bots: steps = distance / averageStepLength
        final calculatedSteps = (expectedDistance / _averageStepLength).round();

        // Step 3: Add step variation (humans don't walk perfectly)
        final stepVariation = 0.90 + _random.nextDouble() * 0.20; // ±10%
        final actualSteps = (calculatedSteps * stepVariation).round().clamp(1, calculatedSteps * 2);

        // Step 4: Calculate FINAL distance from steps (matches StepTrackingService logic)
        final actualDistance = actualSteps * _averageStepLength; // in meters

        // Step 5: Calculate calories from steps (matches StepTrackingService)
        final newCalories = (actualSteps * _caloriesPerStep).round();

        // ✅ FIXED: Update distance without clamping to totalDistance
        // Allow bots to continue beyond finish line to ensure race completion
        final newDistance = profile.currentDistance + actualDistance;

        // Check if bot completed (just crossed finish line)
        final isCompleted = newDistance >= totalDistance;
        final wasNotCompletedBefore = profile.currentDistance < totalDistance;

        if (isCompleted && wasNotCompletedBefore) {
          log('🏆 Bot ${profile.botName} completed the race!');
          // Track this bot for race completion check after batch commit
          completedBots.add({
            'botId': profile.botId,
            'botName': profile.botName,
            'distance': newDistance / 1000, // Convert meters to km for RaceService
            'steps': actualSteps,
            'calories': newCalories,
            'avgSpeed': currentSpeed,
          });
        }

        // Update Firestore
        final participantRef = _firestore
            .collection('races')
            .doc(raceId)
            .collection('participants')
            .doc(profile.botId);

        // ✅ FIXED: Cap displayed distance at totalDistance for UI consistency
        // But internally track full distance to ensure continuous updates
        final displayDistance = newDistance.clamp(0.0, totalDistance);

        batch.update(participantRef, {
          'distance': displayDistance / 1000, // Convert meters to KM (matches real user format)
          'remainingDistance': (totalDistance - displayDistance).clamp(0.0, totalDistance) / 1000, // Also in KM
          'steps': FieldValue.increment(actualSteps), // Use actualSteps, not newSteps
          'calories': FieldValue.increment(newCalories),
          'avgSpeed': currentSpeed,
          'lastUpdated': FieldValue.serverTimestamp(),
          // ❌ DON'T set isCompleted here - let RaceService._checkRaceCompletion handle it
          // This ensures proper race state transitions (Active → Ending → Completed)
        });

        // Update profile state
        profile.lastUpdate = DateTime.now();
        profile.currentDistance = newDistance;
        updatedCount++;

        log('✅ Updated bot ${profile.botName}: ${newDistance.toStringAsFixed(1)}m (+${actualDistance.toStringAsFixed(1)}m), $actualSteps steps, ${(currentSpeed * 3.6).toStringAsFixed(1)} km/h');
      }

      if (updatedCount > 0) {
        await batch.commit();
        log('✅ Committed $updatedCount bot updates to Firestore');

        // ✅ CRITICAL: Trigger race completion checks for any bots that just finished
        // This ensures race state transitions (Active → Ending → Completed) work correctly
        for (final completedBot in completedBots) {
          try {
            log('🎯 Triggering race completion check for bot ${completedBot['botName']} at ${completedBot['distance']}km');

            // Call updateParticipantRealTimeData which will:
            // 1. Update participant data in Firebase
            // 2. Recalculate ranks for all participants
            // 3. Call _checkRaceCompletion which handles:
            //    - Setting isCompleted flag
            //    - Triggering state transitions (Active → Ending → Completed)
            //    - Showing celebration dialog (for real users)
            await RaceService.updateParticipantRealTimeData(
              raceId: raceId,
              userId: completedBot['botId'] as String,
              distance: completedBot['distance'] as double,
              steps: completedBot['steps'] as int,
              calories: completedBot['calories'] as int,
              avgSpeed: completedBot['avgSpeed'] as double,
              isCompleted: false, // Don't set - let _checkRaceCompletion handle it
            );
            log('✅ Race completion check completed for bot ${completedBot['botName']}');
          } catch (e) {
            log('❌ Error triggering race completion for bot ${completedBot['botName']}: $e');
          }
        }
      } else {
        log('ℹ️ No bots needed updating this cycle');
      }

      // ✅ NEW: Track successful update
      _lastSuccessfulUpdate[raceId] = DateTime.now();
      _botFailureCount[raceId] = 0; // Reset failure count on success

      // ✅ FIXED: Don't stop bot simulation when all bots finish
      // Bots should continue walking to ensure race completion and clear inactive races
      // The race will be properly ended by RaceService._checkRaceCompletion
      // This prevents stalled races where player is inactive
    } catch (e, stackTrace) {
      log('❌ Error updating bots: $e');
      log('Stack trace: $stackTrace');

      // ✅ NEW: Track failure and attempt retry with exponential backoff
      final failureCount = (_botFailureCount[raceId] ?? 0) + 1;
      _botFailureCount[raceId] = failureCount;

      if (failureCount <= 3) {
        // Retry with exponential backoff: 2s, 4s, 8s
        final retryDelay = Duration(seconds: 2 * (1 << (failureCount - 1)));
        log('🔄 Retrying bot update for race $raceId after ${retryDelay.inSeconds}s (attempt $failureCount/3)');

        await Future.delayed(retryDelay);

        // Retry the update
        try {
          await _updateAllBots(raceId);
          log('✅ Retry successful for race $raceId');
        } catch (retryError) {
          log('❌ Retry $failureCount failed: $retryError');
        }
      } else {
        log('⚠️ Max retries exceeded for race $raceId, will wait for health check to restart');
      }
    }
  }

  /// ✅ NEW: Health check to monitor and restart failed bot simulations
  void _startHealthCheck(String raceId) {
    _healthCheckTimers[raceId]?.cancel();

    _healthCheckTimers[raceId] = Timer.periodic(Duration(seconds: 60), (timer) async {
      try {
        // Check if bots are still active
        if (!_activeBots.containsKey(raceId)) {
          timer.cancel();
          _healthCheckTimers.remove(raceId);
          return;
        }

        final lastUpdate = _lastSuccessfulUpdate[raceId];
        final failureCount = _botFailureCount[raceId] ?? 0;

        // If no successful update in last 90 seconds, restart simulation
        if (lastUpdate != null && DateTime.now().difference(lastUpdate).inSeconds > 90) {
          log('⚠️ Bot simulation unhealthy for race $raceId (no update in 90s, failures: $failureCount)');

          // Check if race is still active
          final raceDoc = await _firestore.collection('races').doc(raceId).get();
          if (raceDoc.exists) {
            final status = raceDoc.data()?['statusId'] ?? 0;
            if (status == 3 || status == 6) { // Active or Ending
              log('🔄 Restarting bot simulation for race $raceId due to health check failure');
              await startBotSimulation(raceId); // This will reset timers and counters
            } else {
              log('⏹️ Race $raceId is not active (status: $status), stopping bot simulation');
              stopBotSimulation(raceId);
            }
          } else {
            log('⏹️ Race $raceId not found, stopping bot simulation');
            stopBotSimulation(raceId);
          }
        }
      } catch (e) {
        log('❌ Error in health check for race $raceId: $e');
      }
    });

    log('🏥 Health check started for race $raceId (checks every 60s)');
  }

  /// Generate realistic user ID (looks like real user ID)
  String _generateRealisticUserId() {
    const chars = '0123456789abcdef';
    return 'u_${List.generate(8, (_) => chars[_random.nextInt(chars.length)]).join()}';
  }

  /// Create random bot movement profile (balanced realistic speeds)
  BotMovementProfile _createRandomBotProfile(String botId, String botName) {
    // Weighted random selection of bot type - BALANCED FOR REALISTIC COMPETITION
    final rand = _random.nextDouble();

    if (rand < 0.25) {
      // Profile 1: Casual Walker/Jogger (25%) - Light activity
      final speed = 1.2 + _random.nextDouble() * 0.6; // 1.2-1.8 m/s (4.3-6.5 km/h)
      return BotMovementProfile(
        botId: botId,
        botName: botName,
        botType: 'Casual Walker',
        baseSpeed: speed,
        consistency: 0.75 + _random.nextDouble() * 0.15, // 0.75-0.90
        restFrequency: 14.0 + _random.nextDouble() * 6.0, // 14-20% chance
        sprintTendency: 5.0 + _random.nextDouble() * 5.0, // 5-10% chance
        fatigueRate: 0.10 + _random.nextDouble() * 0.08, // 0.10-0.18
      )..logCreation(speed);
    } else if (rand < 0.50) {
      // Profile 2: Brisk Walker (25%) - Moderate pace
      final speed = 1.8 + _random.nextDouble() * 0.5; // 1.8-2.3 m/s (6.5-8.3 km/h)
      return BotMovementProfile(
        botId: botId,
        botName: botName,
        botType: 'Brisk Walker',
        baseSpeed: speed,
        consistency: 0.70 + _random.nextDouble() * 0.2, // 0.70-0.90
        restFrequency: 12.0 + _random.nextDouble() * 5.0, // 12-17% chance
        sprintTendency: 8.0 + _random.nextDouble() * 5.0, // 8-13% chance
        fatigueRate: 0.09 + _random.nextDouble() * 0.09, // 0.09-0.18
      )..logCreation(speed);
    } else if (rand < 0.75) {
      // Profile 3: Light Jogger (25%) - Easy jogging pace
      final speed = 2.3 + _random.nextDouble() * 0.5; // 2.3-2.8 m/s (8.3-10.1 km/h)
      return BotMovementProfile(
        botId: botId,
        botName: botName,
        botType: 'Light Jogger',
        baseSpeed: speed,
        consistency: 0.65 + _random.nextDouble() * 0.2, // 0.65-0.85
        restFrequency: 10.0 + _random.nextDouble() * 5.0, // 10-15% chance
        sprintTendency: 10.0 + _random.nextDouble() * 6.0, // 10-16% chance
        fatigueRate: 0.10 + _random.nextDouble() * 0.08, // 0.10-0.18
      )..logCreation(speed);
    } else if (rand < 0.92) {
      // Profile 4: Moderate Runner (17%) - Good running pace
      final speed = 2.8 + _random.nextDouble() * 0.6; // 2.8-3.4 m/s (10.1-12.2 km/h)
      return BotMovementProfile(
        botId: botId,
        botName: botName,
        botType: 'Moderate Runner',
        baseSpeed: speed,
        consistency: 0.70 + _random.nextDouble() * 0.15, // 0.70-0.85
        restFrequency: 8.0 + _random.nextDouble() * 4.0, // 8-12% chance
        sprintTendency: 12.0 + _random.nextDouble() * 6.0, // 12-18% chance
        fatigueRate: 0.11 + _random.nextDouble() * 0.08, // 0.11-0.19
      )..logCreation(speed);
    } else {
      // Profile 5: Fast Runner (8%) - Competitive pace
      final speed = 3.4 + _random.nextDouble() * 0.7; // 3.4-4.1 m/s (12.2-14.8 km/h)
      return BotMovementProfile(
        botId: botId,
        botName: botName,
        botType: 'Fast Runner',
        baseSpeed: speed,
        consistency: 0.75 + _random.nextDouble() * 0.15, // 0.75-0.90
        restFrequency: 6.0 + _random.nextDouble() * 4.0, // 6-10% chance
        sprintTendency: 15.0 + _random.nextDouble() * 8.0, // 15-23% chance
        fatigueRate: 0.12 + _random.nextDouble() * 0.08, // 0.12-0.20
      )..logCreation(speed);
    }
  }

  /// Clean up all resources
  void dispose() {
    for (final timer in _raceTimers.values) {
      timer?.cancel();
    }
    _raceTimers.clear();
    _activeBots.clear();
  }
}
