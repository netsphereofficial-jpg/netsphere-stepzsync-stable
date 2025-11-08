import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Utility to fix participant count mismatches
/// Run this when joinedParticipants counter is out of sync with actual participants subcollection
class ParticipantCountFixer {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fix participant count for a specific race
  /// Counts actual participants in subcollection and updates joinedParticipants field
  static Future<void> fixRaceParticipantCount(String raceId) async {
    try {
      debugPrint('🔧 [FIX] Starting participant count fix for race: $raceId');

      final raceRef = _firestore.collection('races').doc(raceId);
      final raceDoc = await raceRef.get();

      if (!raceDoc.exists) {
        debugPrint('❌ [FIX] Race not found: $raceId');
        return;
      }

      final raceData = raceDoc.data()!;
      final currentCount = raceData['joinedParticipants'] ?? 0;
      debugPrint('📊 [FIX] Current joinedParticipants value: $currentCount');

      // Count actual participants in subcollection
      final participantsSnapshot = await raceRef
          .collection('participants')
          .get();

      final actualCount = participantsSnapshot.docs.length;
      debugPrint('📊 [FIX] Actual participants in subcollection: $actualCount');

      if (currentCount == actualCount) {
        debugPrint('✅ [FIX] Count is already correct! No update needed.');
        return;
      }

      // Update the counter to match actual count
      await raceRef.update({
        'joinedParticipants': actualCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ [FIX] Updated joinedParticipants from $currentCount to $actualCount');
      debugPrint('📋 [FIX] Participant IDs in subcollection:');
      for (final doc in participantsSnapshot.docs) {
        debugPrint('   - ${doc.id}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [FIX] Error fixing participant count: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Fix participant counts for all races
  /// Use with caution - scans all races
  static Future<void> fixAllRaceParticipantCounts() async {
    try {
      debugPrint('🔧 [FIX] Starting participant count fix for ALL races...');

      final racesSnapshot = await _firestore.collection('races').get();
      int fixedCount = 0;
      int alreadyCorrectCount = 0;

      for (final raceDoc in racesSnapshot.docs) {
        final raceData = raceDoc.data();
        final currentCount = raceData['joinedParticipants'] ?? 0;

        // Count actual participants in subcollection
        final participantsSnapshot = await raceDoc.reference
            .collection('participants')
            .get();

        final actualCount = participantsSnapshot.docs.length;

        if (currentCount != actualCount) {
          debugPrint('🔧 [FIX] Race ${raceDoc.id} (${raceData['title']}): $currentCount → $actualCount');

          await raceDoc.reference.update({
            'joinedParticipants': actualCount,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          fixedCount++;
        } else {
          alreadyCorrectCount++;
        }
      }

      debugPrint('✅ [FIX] Completed!');
      debugPrint('   Fixed: $fixedCount races');
      debugPrint('   Already correct: $alreadyCorrectCount races');
    } catch (e, stackTrace) {
      debugPrint('❌ [FIX] Error fixing all participant counts: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
}
