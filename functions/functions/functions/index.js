/**
 * StepzSync Cloud Functions
 * Combined: Stats calculation + Race participant management
 * Using v1 API for easier deployment (no IAM permissions needed)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();
const db = admin.firestore();

// ========================================
// STATS CALCULATION FUNCTIONS
// ========================================

exports.calculateOverallStats = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const userId = context.params.userId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    const beforeDailyStats = beforeData.daily_stats || {};
    const afterDailyStats = afterData.daily_stats || {};

    if (JSON.stringify(beforeDailyStats) === JSON.stringify(afterDailyStats)) {
      console.log(`No changes to daily_stats for user ${userId}, skipping...`);
      return null;
    }

    console.log(`Recalculating overall_stats for user ${userId}`);

    try {
      let totalSteps = 0;
      let totalDistance = 0.0;
      let totalCalories = 0;
      let daysActive = 0;

      for (const [date, dayData] of Object.entries(afterDailyStats)) {
        totalSteps += dayData.steps || 0;
        totalDistance += dayData.distance || 0.0;
        totalCalories += dayData.calories || 0;
        daysActive++;
      }

      const overallStats = {
        total_steps: totalSteps,
        total_distance: totalDistance,
        total_calories: totalCalories,
        days_active: daysActive,
        last_updated: admin.firestore.FieldValue.serverTimestamp(),
        calculated_by: 'cloud_function',
      };

      await db.collection('users').doc(userId).update({
        overall_stats: overallStats,
      });

      console.log(`Successfully updated overall_stats for user ${userId}`);
      return null;
    } catch (error) {
      console.error(`Error calculating overall_stats for user ${userId}:`, error);
      return null;
    }
  });

// ========================================
// RACE PARTICIPANT MANAGEMENT FUNCTIONS
// ========================================

exports.onParticipantJoined = functions.firestore
  .document('races/{raceId}/participants/{userId}')
  .onCreate(async (snap, context) => {
    const raceId = context.params.raceId;
    const userId = context.params.userId;
    const participantData = snap.data();

    console.log(`✅ Participant ${userId} joined race ${raceId}`);

    try {
      const raceRef = db.collection('races').doc(raceId);
      const raceDoc = await raceRef.get();

      if (!raceDoc.exists) {
        console.error(`Race ${raceId} not found`);
        return null;
      }

      const updateData = {
        participantCount: admin.firestore.FieldValue.increment(1),
        lastParticipantJoinedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (participantData.steps && participantData.steps > 0) {
        updateData.activeParticipantCount = admin.firestore.FieldValue.increment(1);
      }

      await raceRef.update(updateData);
      console.log(`✅ Race ${raceId} participant count incremented`);
      return null;
    } catch (error) {
      console.error(`❌ Error incrementing participant count for race ${raceId}:`, error);
      return null;
    }
  });

exports.onParticipantLeft = functions.firestore
  .document('races/{raceId}/participants/{userId}')
  .onDelete(async (snap, context) => {
    const raceId = context.params.raceId;
    const userId = context.params.userId;
    const participantData = snap.data();

    console.log(`🚪 Participant ${userId} left race ${raceId}`);

    try {
      const raceRef = db.collection('races').doc(raceId);
      const raceDoc = await raceRef.get();

      if (!raceDoc.exists) {
        console.warn(`Race ${raceId} not found (may have been deleted)`);
        return null;
      }

      const updateData = {
        participantCount: admin.firestore.FieldValue.increment(-1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (participantData.steps && participantData.steps > 0) {
        updateData.activeParticipantCount = admin.firestore.FieldValue.increment(-1);
      }

      await raceRef.update(updateData);
      console.log(`✅ Race ${raceId} participant count decremented`);
      return null;
    } catch (error) {
      console.error(`❌ Error decrementing participant count for race ${raceId}:`, error);
      return null;
    }
  });

exports.onParticipantUpdated = functions.firestore
  .document('races/{raceId}/participants/{userId}')
  .onUpdate(async (change, context) => {
    const raceId = context.params.raceId;
    const userId = context.params.userId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    try {
      const raceRef = db.collection('races').doc(raceId);
      const updateData = {};

      const wasActive = beforeData.steps && beforeData.steps > 0;
      const isActive = afterData.steps && afterData.steps > 0;

      if (!wasActive && isActive) {
        updateData.activeParticipantCount = admin.firestore.FieldValue.increment(1);
        console.log(`🏃 Participant ${userId} is now active in race ${raceId}`);
      }

      const wasCompleted = beforeData.isCompleted || false;
      const isCompleted = afterData.isCompleted || false;

      if (!wasCompleted && isCompleted) {
        updateData.completedParticipantCount = admin.firestore.FieldValue.increment(1);
        if (isActive) {
          updateData.activeParticipantCount = admin.firestore.FieldValue.increment(-1);
        }
        console.log(`🏆 Participant ${userId} completed race ${raceId}`);
      }

      if (afterData.rank === 1 && beforeData.rank !== 1) {
        updateData.topParticipant = {
          userId: userId,
          userName: afterData.userName || afterData.displayName || 'Unknown',
          steps: afterData.steps || 0,
          distance: afterData.distance || 0,
          rank: 1,
          profilePicture: afterData.profilePicture || null,
        };
        console.log(`🏆 New leader in race ${raceId}: ${updateData.topParticipant.userName}`);
      }

      if (Object.keys(updateData).length > 0) {
        updateData.updatedAt = admin.firestore.FieldValue.serverTimestamp();
        await raceRef.update(updateData);
      }

      return null;
    } catch (error) {
      console.error(`❌ Error updating race ${raceId} from participant update:`, error);
      return null;
    }
  });

exports.onRaceStatusChanged = functions.firestore
  .document('races/{raceId}')
  .onUpdate(async (change, context) => {
    const raceId = context.params.raceId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    const oldStatus = beforeData.statusId;
    const newStatus = afterData.statusId;

    if (oldStatus === newStatus) return null;

    console.log(`📊 Race ${raceId} status changed: ${oldStatus} → ${newStatus}`);

    try {
      if (newStatus === 3 && oldStatus !== 3) {
        console.log(`🏁 Race "${afterData.title}" started! ID: ${raceId}`);
        if (afterData.activeParticipantCount === undefined) {
          await change.after.ref.update({
            activeParticipantCount: 0,
            raceStartedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      if (newStatus === 4 && oldStatus !== 4) {
        console.log(`🏆 Race "${afterData.title}" completed! ID: ${raceId}`);
        const participantsSnapshot = await db
          .collection('races')
          .doc(raceId)
          .collection('participants')
          .orderBy('rank')
          .get();

        const totalParticipants = participantsSnapshot.size;
        const completedParticipants = participantsSnapshot.docs.filter(
          doc => doc.data().isCompleted
        ).length;

        await change.after.ref.update({
          raceCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
          finalParticipantCount: totalParticipants,
          finalCompletedCount: completedParticipants,
          completionRate: totalParticipants > 0 ? (completedParticipants / totalParticipants * 100) : 0,
        });

        console.log(`✅ Race ${raceId} final stats: ${completedParticipants}/${totalParticipants} completed`);
      }

      return null;
    } catch (error) {
      console.error(`❌ Error handling status change for race ${raceId}:`, error);
      return null;
    }
  });

// ========================================
// UTILITY FUNCTIONS
// ========================================

exports.migrateExistingRaces = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  console.log('🔧 Starting migration of existing races...');

  try {
    const racesSnapshot = await db.collection('races').get();
    let migratedCount = 0;
    let errorCount = 0;

    for (const raceDoc of racesSnapshot.docs) {
      const raceId = raceDoc.id;

      try {
        const participantsSnapshot = await db
          .collection('races')
          .doc(raceId)
          .collection('participants')
          .get();

        const participantCount = participantsSnapshot.size;
        let activeCount = 0;
        let completedCount = 0;
        let topParticipant = null;

        participantsSnapshot.docs.forEach(doc => {
          const pData = doc.data();
          if (pData.steps && pData.steps > 0) activeCount++;
          if (pData.isCompleted) completedCount++;

          if (pData.rank === 1) {
            topParticipant = {
              userId: doc.id,
              userName: pData.userName || pData.displayName || 'Unknown',
              steps: pData.steps || 0,
              distance: pData.distance || 0,
              rank: 1,
            };
          }
        });

        const updateData = {
          participantCount: participantCount,
          activeParticipantCount: activeCount,
          completedParticipantCount: completedCount,
        };

        if (topParticipant) {
          updateData.topParticipant = topParticipant;
        }

        await raceDoc.ref.update(updateData);
        migratedCount++;
        console.log(`✅ Migrated race ${raceId}: ${participantCount} participants`);
      } catch (error) {
        errorCount++;
        console.error(`❌ Error migrating race ${raceId}:`, error);
      }
    }

    console.log(`🎉 Migration complete: ${migratedCount} races migrated, ${errorCount} errors`);

    return {
      success: true,
      migratedCount: migratedCount,
      errorCount: errorCount,
      totalRaces: racesSnapshot.size,
    };
  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw new functions.https.HttpsError('internal', 'Migration failed');
  }
});
