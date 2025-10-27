/**
 * Firebase Cloud Functions for Race Participant Management
 *
 * These functions automatically maintain denormalized data (participant counts, top participant)
 * whenever participants join, leave, or update their race progress.
 *
 * Deploy with: firebase deploy --only functions
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * FUNCTION 1: Auto-increment participant count when user joins a race
 *
 * Triggers when: A new document is created in races/{raceId}/participants/{userId}
 * Updates: participantCount, lastParticipantJoinedAt in race document
 */
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

      // If participant already has steps > 0, increment active participant count
      if (participantData.steps && participantData.steps > 0) {
        updateData.activeParticipantCount = admin.firestore.FieldValue.increment(1);
      }

      await raceRef.update(updateData);

      console.log(`✅ Race ${raceId} participant count incremented. User: ${participantData.userName || userId}`);
      return null;

    } catch (error) {
      console.error(`❌ Error incrementing participant count for race ${raceId}:`, error);
      return null;
    }
  });

/**
 * FUNCTION 2: Auto-decrement participant count when user leaves a race
 *
 * Triggers when: A document is deleted from races/{raceId}/participants/{userId}
 * Updates: participantCount in race document
 */
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

      // If participant was active, decrement active participant count
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

/**
 * FUNCTION 3: Update top participant and active counts when participant progress changes
 *
 * Triggers when: A participant document is updated (steps, distance, rank changes)
 * Updates: topParticipant, activeParticipantCount in race document
 * Notifications: Milestones (25%, 50%, 75%), Proximity Alerts (<20m gap)
 */
exports.onParticipantUpdated = functions.firestore
  .document('races/{raceId}/participants/{userId}')
  .onUpdate(async (change, context) => {
    const raceId = context.params.raceId;
    const userId = context.params.userId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    try {
      const raceRef = db.collection('races').doc(raceId);
      const raceDoc = await raceRef.get();

      if (!raceDoc.exists) {
        console.error(`Race ${raceId} not found`);
        return null;
      }

      const raceData = raceDoc.data();
      const raceTitle = raceData.title || 'Untitled Race';
      const userName = afterData.userName || afterData.displayName || 'Unknown';
      const updateData = {};

      // Check if participant became active (started moving)
      const wasActive = beforeData.steps && beforeData.steps > 0;
      const isActive = afterData.steps && afterData.steps > 0;

      if (!wasActive && isActive) {
        // Participant just became active
        updateData.activeParticipantCount = admin.firestore.FieldValue.increment(1);
        console.log(`🏃 Participant ${userId} is now active in race ${raceId}`);
      }

      // Check if participant completed the race
      const wasCompleted = beforeData.isCompleted || false;
      const isCompleted = afterData.isCompleted || false;

      if (!wasCompleted && isCompleted) {
        // Participant just completed the race
        updateData.completedParticipantCount = admin.firestore.FieldValue.increment(1);
        if (isActive) {
          updateData.activeParticipantCount = admin.firestore.FieldValue.increment(-1);
        }
        console.log(`🏆 Participant ${userId} completed race ${raceId}`);
      }

      // Update top participant if this participant is now rank #1
      if (afterData.rank === 1 && beforeData.rank !== 1) {
        updateData.topParticipant = {
          userId: userId,
          userName: afterData.userName || afterData.displayName || 'Unknown',
          steps: afterData.steps || 0,
          distance: afterData.distance || 0,
          rank: 1,
          profilePicture: afterData.profilePicture || null,
        };
        console.log(`🏆 New leader in race ${raceId}: ${updateData.topParticipant.userName} (${updateData.topParticipant.steps} steps)`);
      }

      // Only update if there are changes
      if (Object.keys(updateData).length > 0) {
        updateData.updatedAt = admin.firestore.FieldValue.serverTimestamp();
        await raceRef.update(updateData);
        console.log(`✅ Race ${raceId} updated with participant progress`);
      }

      // ===== NOTIFICATION LOGIC (Perfect Race Notifications) =====

      // 1. MILESTONE NOTIFICATIONS (25%, 50%, 75% completion)
      const oldProgress = beforeData.completionPercent || 0;
      const newProgress = afterData.completionPercent || 0;

      const milestones = [25, 50, 75];
      for (const milestone of milestones) {
        if (oldProgress < milestone && newProgress >= milestone) {
          console.log(`🎯 Milestone reached: ${userName} hit ${milestone}% in race ${raceId}`);

          const { sendMilestonePersonalNotification, sendMilestoneAlertNotification } =
            require('./notifications/senders/raceNotifications');

          const raceDataForNotification = {
            id: raceId,
            title: raceTitle,
          };

          // Send personal achievement notification to the participant
          await sendMilestonePersonalNotification(userId, raceDataForNotification, milestone);

          // Alert other participants about this milestone
          await sendMilestoneAlertNotification(raceId, raceDataForNotification, userName, milestone, userId);
        }
      }

      // 2. PROXIMITY ALERT NOTIFICATIONS (Opponent within 20m)
      // Only check proximity if participant is active and not in 1st place
      if (isActive && afterData.rank > 1 && !isCompleted) {
        const personAheadRank = afterData.rank - 1;

        // Get person ahead's data
        const personAheadSnapshot = await db.collection('races')
          .doc(raceId)
          .collection('participants')
          .where('rank', '==', personAheadRank)
          .limit(1)
          .get();

        if (!personAheadSnapshot.empty) {
          const personAheadDoc = personAheadSnapshot.docs[0];
          const personAheadData = personAheadDoc.data();
          const personAheadDistance = personAheadData.distance || 0;
          const currentDistance = afterData.distance || 0;

          const gap = personAheadDistance - currentDistance;
          const oldDistance = beforeData.distance || 0;
          const oldGap = personAheadDistance - oldDistance;

          // Send alert if:
          // - Gap is now <= 20m
          // - Gap was previously > 20m (crossing the threshold)
          // - Gap is positive (chaser is behind)
          // - Person ahead has NOT already won the race
          const personAheadHasWon = personAheadData.rank === 1 && personAheadData.isCompleted === true;

          if (gap > 0 && gap <= 20 && oldGap > 20 && !personAheadHasWon) {
            console.log(`🔥 Proximity alert: ${userName} is ${Math.round(gap)}m behind rank ${personAheadRank}`);

            const { sendProximityAlertNotification } =
              require('./notifications/senders/raceNotifications');

            await sendProximityAlertNotification(
              personAheadDoc.id,
              userId,
              userName,
              Math.round(gap),
              raceId,
              raceTitle
            );
          } else if (personAheadHasWon) {
            console.log(`⏭️ Skipping proximity alert - person ahead (${personAheadDoc.id}) has already won the race`);
          }
        }
      }

      return null;

    } catch (error) {
      console.error(`❌ Error updating race ${raceId} from participant update:`, error);
      return null;
    }
  });

/**
 * FUNCTION 4: Update race status counts when race status changes
 *
 * Triggers when: A race document's status changes (created → active → completed)
 * Updates: Handles notifications, final calculations when race completes
 */
exports.onRaceStatusChanged = functions.firestore
  .document('races/{raceId}')
  .onUpdate(async (change, context) => {
    const raceId = context.params.raceId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    const oldStatus = beforeData.statusId;
    const newStatus = afterData.statusId;

    // Only process if status actually changed
    if (oldStatus === newStatus) {
      return null;
    }

    console.log(`📊 Race ${raceId} status changed: ${oldStatus} → ${newStatus}`);

    try {
      // Race just started (statusId changed to 3 = ACTIVE)
      if (newStatus === 3 && oldStatus !== 3) {
        console.log(`🏁 Race "${afterData.title}" started! ID: ${raceId}`);

        // Initialize active participant count if not set
        if (afterData.activeParticipantCount === undefined) {
          await change.after.ref.update({
            activeParticipantCount: 0,
            raceStartedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        // TODO: You can trigger push notifications here
        // Example: Send notification to all participants that race has started
      }

      // Race just completed (statusId changed to 4 = COMPLETED)
      if (newStatus === 4 && oldStatus !== 4) {
        console.log(`🏆 Race "${afterData.title}" completed! ID: ${raceId}`);

        // Get all participants and their final rankings
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

        // Update race with final statistics
        await change.after.ref.update({
          raceCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
          finalParticipantCount: totalParticipants,
          finalCompletedCount: completedParticipants,
          completionRate: totalParticipants > 0 ? (completedParticipants / totalParticipants * 100) : 0,
        });

        console.log(`✅ Race ${raceId} final stats: ${completedParticipants}/${totalParticipants} completed (${(completedParticipants/totalParticipants*100).toFixed(1)}%)`);

        // TODO: Award XP, send completion notifications, update leaderboards, etc.
      }

      // Race cancelled (statusId changed to 7 = CANCELLED)
      if (newStatus === 7 && oldStatus !== 7) {
        console.log(`❌ Race "${afterData.title}" cancelled! ID: ${raceId}`);

        await change.after.ref.update({
          raceCancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // TODO: Send cancellation notifications to participants
      }

      return null;

    } catch (error) {
      console.error(`❌ Error handling status change for race ${raceId}:`, error);
      return null;
    }
  });

/**
 * OPTIONAL: Background function to fix/migrate existing races
 *
 * Run once to add denormalized fields to all existing races
 * Call via Firebase Console or schedule as one-time job
 */
exports.migrateExistingRaces = functions.https.onCall(async (data, context) => {
  // Verify admin authentication (optional - add your security logic)
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  console.log('🔧 Starting migration of existing races...');

  try {
    const racesSnapshot = await db.collection('races').get();
    let migratedCount = 0;
    let errorCount = 0;

    const batchPromises = [];

    for (const raceDoc of racesSnapshot.docs) {
      const raceId = raceDoc.id;
      const raceData = raceDoc.data();

      try {
        // Get participants count from subcollection
        const participantsSnapshot = await db
          .collection('races')
          .doc(raceId)
          .collection('participants')
          .get();

        const participantCount = participantsSnapshot.size;
        let activeCount = 0;
        let completedCount = 0;
        let topParticipant = null;

        // Calculate counts and find top participant
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

        // Update race document with denormalized fields
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
