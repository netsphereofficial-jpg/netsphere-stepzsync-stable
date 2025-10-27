import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../core/models/race_data_model.dart';
import '../services/firebase_service.dart';

/// Utility class to migrate race data from old string-based participants to new Participant object format
class RaceDataMigration {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseService _firebaseService = Get.find<FirebaseService>();

  /// Check if a race has string-based participants that need migration
  static bool needsMigration(Map<String, dynamic> raceData) {
    final participants = raceData['participants'] as List?;
    if (participants == null || participants.isEmpty) {
      return false;
    }

    // Check if any participant is a string (old format)
    return participants.any((p) => p is String);
  }

  /// Migrate a single race from string-based to Participant object format
  static Future<bool> migrateRace(String raceId, Map<String, dynamic> raceData) async {
    try {
      await _firebaseService.ensureInitialized();

      final participants = raceData['participants'] as List?;
      if (participants == null || participants.isEmpty) {
        log('🔄 Race $raceId has no participants, skipping migration');
        return true;
      }

      // Check if migration is needed
      if (!needsMigration(raceData)) {
        log('✅ Race $raceId already uses Participant objects, no migration needed');
        return true;
      }

      log('🔄 Migrating race $raceId from string-based to Participant object format');

      final totalDistance = (raceData['totalDistance'] ?? 0.0).toDouble();
      final migratedParticipants = <Map<String, dynamic>>[];

      int rank = 1;
      for (var participant in participants) {
        if (participant is String) {
          // Convert string (user ID) to Participant object
          final participantObj = Participant(
            userId: participant,
            userName: 'User $participant', // Placeholder name
            distance: 0.0,
            remainingDistance: totalDistance,
            rank: rank++,
            steps: 0,
            status: 'joined',
            lastUpdated: DateTime.now(),
            calories: 0,
            avgSpeed: 0.0,
            isCompleted: false,
          );
          migratedParticipants.add(participantObj.toFirestore());
          log('📝 Migrated string participant: $participant -> Participant object');
        } else if (participant is Map<String, dynamic>) {
          // Already in correct format
          migratedParticipants.add(participant);
          log('✅ Participant already in object format: ${participant['userId']}');
        } else {
          log('⚠️ Unknown participant format for race $raceId: ${participant.runtimeType}');
        }
      }

      // Update the race document with migrated participants
      await _firestore.collection('races').doc(raceId).update({
        'participants': migratedParticipants,
        'migratedAt': FieldValue.serverTimestamp(),
        'migrationVersion': '1.0.0',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      log('✅ Successfully migrated race $raceId with ${migratedParticipants.length} participants');
      return true;
    } catch (e) {
      log('❌ Failed to migrate race $raceId: $e');
      return false;
    }
  }

  /// Migrate all races that need migration (use with caution)
  static Future<void> migrateAllRaces({int batchSize = 10}) async {
    try {
      await _firebaseService.ensureInitialized();

      log('🚀 Starting race data migration (batch size: $batchSize)');

      // Get all races
      final raceQuery = await _firestore.collection('races').get();
      final totalRaces = raceQuery.docs.length;

      log('📊 Found $totalRaces races to check for migration');

      int migrationCount = 0;
      int skipCount = 0;
      int errorCount = 0;
      int processedCount = 0;

      // Process races in batches
      for (int i = 0; i < raceQuery.docs.length; i += batchSize) {
        final batchDocs = raceQuery.docs.skip(i).take(batchSize).toList();

        log('🔄 Processing batch ${(i ~/ batchSize) + 1}/${((totalRaces - 1) ~/ batchSize) + 1} (${batchDocs.length} races)');

        final futures = batchDocs.map((doc) async {
          final raceId = doc.id;
          final raceData = doc.data();

          processedCount++;

          if (needsMigration(raceData)) {
            final success = await migrateRace(raceId, raceData);
            if (success) {
              migrationCount++;
            } else {
              errorCount++;
            }
          } else {
            skipCount++;
          }
        });

        // Wait for batch to complete
        await Future.wait(futures);

        // Small delay between batches to avoid overwhelming Firestore
        if (i + batchSize < raceQuery.docs.length) {
          await Future.delayed(Duration(milliseconds: 500));
        }

        log('📊 Progress: $processedCount/$totalRaces races processed');
      }

      log('🎉 Migration completed!');
      log('📈 Summary:');
      log('   - Total races checked: $totalRaces');
      log('   - Races migrated: $migrationCount');
      log('   - Races skipped (no migration needed): $skipCount');
      log('   - Races with errors: $errorCount');

      if (errorCount > 0) {
        log('⚠️ Some races failed to migrate. Check logs for details.');
      }
    } catch (e) {
      log('❌ Migration failed: $e');
      rethrow;
    }
  }

  /// Get migration status for all races
  static Future<Map<String, int>> getMigrationStatus() async {
    try {
      await _firebaseService.ensureInitialized();

      final raceQuery = await _firestore.collection('races').get();

      int needsMigrationCount = 0;
      int alreadyMigratedCount = 0;
      int totalCount = raceQuery.docs.length;

      for (var doc in raceQuery.docs) {
        final raceData = doc.data();
        if (needsMigration(raceData)) {
          needsMigrationCount++;
        } else {
          alreadyMigratedCount++;
        }
      }

      return {
        'total': totalCount,
        'needsMigration': needsMigrationCount,
        'alreadyMigrated': alreadyMigratedCount,
      };
    } catch (e) {
      log('❌ Error getting migration status: $e');
      return {'total': 0, 'needsMigration': 0, 'alreadyMigrated': 0};
    }
  }

  /// Validate that a race has been properly migrated
  static bool validateMigratedRace(Map<String, dynamic> raceData) {
    final participants = raceData['participants'] as List?;
    if (participants == null) return true; // No participants is valid

    // All participants should be objects with required fields
    return participants.every((p) {
      if (p is! Map<String, dynamic>) return false;

      // Check required Participant fields
      return p.containsKey('userId') &&
             p.containsKey('userName') &&
             p.containsKey('distance') &&
             p.containsKey('rank') &&
             p.containsKey('status');
    });
  }
}