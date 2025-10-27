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

      const raceData = raceDoc.data();

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

      // ✅ Send notification to race organizer/creator
      try {
        const { sendParticipantJoinedNotification } = require('./notifications/senders/raceNotifications');

        const organizerUserId = raceData.createdBy || raceData.organizerUserId;

        // Don't notify if participant is the organizer themselves
        if (organizerUserId && organizerUserId !== userId) {
          await sendParticipantJoinedNotification(
            organizerUserId,
            {
              id: raceId,
              title: raceData.title || 'Untitled Race',
            },
            {
              id: userId,
              name: participantData.userName || participantData.displayName || 'Someone',
            }
          );
          console.log(`🔔 Participant joined notification sent to organizer: ${organizerUserId}`);
        }
      } catch (notifError) {
        console.error(`⚠️ Failed to send participant joined notification: ${notifError}`);
        // Don't fail the whole operation if notification fails
      }

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
 * Notifications: Sends overtaking and leader change notifications
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

      // ✅ NEW: Detect rank changes (overtaking)
      const oldRank = beforeData.rank || 999;
      const newRank = afterData.rank || 999;
      const rankChanged = oldRank !== newRank;
      const rankImproved = newRank < oldRank; // Lower rank number = better position

      if (rankChanged && rankImproved && newRank > 0) {
        console.log(`🎯 Rank improved: ${userId} moved from #${oldRank} to #${newRank} in race ${raceId}`);

        // Send overtaking notifications
        try {
          const { sendOvertakingNotifications } = require('./notifications/senders/raceNotifications');

          const raceDoc = await raceRef.get();
          if (raceDoc.exists) {
            const raceData = raceDoc.data();

            // Get all participants to find who was overtaken
            const participantsSnapshot = await db
              .collection('races')
              .doc(raceId)
              .collection('participants')
              .get();

            await sendOvertakingNotifications(
              raceId,
              raceData.title || 'Race',
              userId,
              afterData.userName || afterData.displayName || 'Someone',
              newRank,
              oldRank,
              participantsSnapshot.docs
            );

            console.log(`🔔 Overtaking notifications sent for race ${raceId}`);
          }
        } catch (notifError) {
          console.error(`⚠️ Failed to send overtaking notifications: ${notifError}`);
        }
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

        // ✅ NEW: Send leader change notification to all participants
        try {
          const { sendLeaderChangeNotification } = require('./notifications/senders/raceNotifications');

          const raceDoc = await raceRef.get();
          if (raceDoc.exists) {
            const raceData = raceDoc.data();

            // Get all participants
            const participantsSnapshot = await db
              .collection('races')
              .doc(raceId)
              .collection('participants')
              .get();

            await sendLeaderChangeNotification(
              raceId,
              raceData.title || 'Race',
              userId,
              updateData.topParticipant.userName,
              participantsSnapshot.docs
            );

            console.log(`🔔 Leader change notification sent for race ${raceId}`);
          }
        } catch (notifError) {
          console.error(`⚠️ Failed to send leader change notification: ${notifError}`);
        }
      }

      // ✅ NEW: Detect milestone completion (25%, 50%, 75%)
      const oldDistance = beforeData.distance || 0;
      const newDistance = afterData.distance || 0;

      if (newDistance > oldDistance) {
        try {
          const raceDoc = await raceRef.get();
          if (raceDoc.exists) {
            const raceData = raceDoc.data();
            const totalDistance = raceData.totalDistance || 0;

            if (totalDistance > 0) {
              const oldProgress = (oldDistance / totalDistance) * 100;
              const newProgress = (newDistance / totalDistance) * 100;

              // Get previously reached milestones from participant document
              const reachedMilestones = afterData.reachedMilestones || [];
              const milestones = [25, 50, 75];

              for (const milestone of milestones) {
                // Check if milestone was just crossed (wasn't reached before, but is now)
                if (oldProgress < milestone && newProgress >= milestone && !reachedMilestones.includes(milestone)) {
                  console.log(`🎯 Milestone reached: ${userId} hit ${milestone}% in race ${raceId}`);

                  // Update participant's reached milestones
                  await change.after.ref.update({
                    reachedMilestones: admin.firestore.FieldValue.arrayUnion(milestone),
                  });

                  // Send notifications
                  const {
                    sendMilestonePersonalNotification,
                    sendMilestoneAlertNotification,
                  } = require('./notifications/senders/raceNotifications');

                  const raceInfo = {
                    id: raceId,
                    title: raceData.title || 'Race',
                  };

                  const userName = afterData.userName || afterData.displayName || 'Someone';

                  // Send personal notification to achiever
                  await sendMilestonePersonalNotification(userId, raceInfo, milestone);

                  // Send alert to all other participants
                  await sendMilestoneAlertNotification(raceId, raceInfo, userName, milestone, userId);

                  console.log(`🔔 Milestone notifications sent for ${userId} - ${milestone}%`);
                }
              }
            }
          }
        } catch (milestoneError) {
          console.error(`⚠️ Failed to handle milestone detection: ${milestoneError}`);
        }
      }

      // Only update if there are changes
      if (Object.keys(updateData).length > 0) {
        updateData.updatedAt = admin.firestore.FieldValue.serverTimestamp();
        await raceRef.update(updateData);
        console.log(`✅ Race ${raceId} updated with participant progress`);
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
 * Updates: Handles statistics updates for race status transitions
 *
 * NOTE: Notifications are handled by onRaceStatusChanged in raceTriggers.js
 */
exports.onRaceStatusChangedStats = functions.firestore
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

    console.log(`📊 [Stats] Race ${raceId} status changed: ${oldStatus} → ${newStatus}`);

    try {
      // Race just started (statusId changed to 3 = ACTIVE)
      if (newStatus === 3 && oldStatus !== 3) {
        console.log(`🏁 [Stats] Race "${afterData.title}" started! ID: ${raceId}`);

        // Initialize active participant count if not set
        if (afterData.activeParticipantCount === undefined) {
          await change.after.ref.update({
            activeParticipantCount: 0,
            raceStartedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      // Race just completed (statusId changed to 4 = COMPLETED)
      if (newStatus === 4 && oldStatus !== 4) {
        console.log(`🏆 [Stats] Race "${afterData.title}" completed! ID: ${raceId}`);

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

        console.log(`✅ [Stats] Race ${raceId} final stats: ${completedParticipants}/${totalParticipants} completed (${(completedParticipants/totalParticipants*100).toFixed(1)}%)`);
      }

      // Race cancelled (statusId changed to 7 = CANCELLED)
      if (newStatus === 7 && oldStatus !== 7) {
        console.log(`❌ [Stats] Race "${afterData.title}" cancelled! ID: ${raceId}`);

        await change.after.ref.update({
          raceCancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      return null;

    } catch (error) {
      console.error(`❌ [Stats] Error handling status change for race ${raceId}:`, error);
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

/**
 * ============================================================================
 * PUSH NOTIFICATION FUNCTIONS (Testing Phase)
 * ============================================================================
 */

// Import test notification functions
const testNotificationFunctions = require('./notifications/test/testNotification');

// Export test notification functions
exports.testNotification = testNotificationFunctions.testNotification;
exports.testNotificationHTTP = testNotificationFunctions.testNotificationHTTP;
exports.quickTestNotification = testNotificationFunctions.quickTestNotification;
exports.testNotificationToMe = testNotificationFunctions.testNotificationToMe;

/**
 * ============================================================================
 * RACE NOTIFICATION TRIGGERS (Phase 2A - Production)
 * ============================================================================
 */

// Import race notification triggers
const raceTriggers = require('./notifications/triggers/raceTriggers');

// Export race triggers
exports.onRaceInviteCreated = raceTriggers.onRaceInviteCreated;
exports.onRaceStatusChanged = raceTriggers.onRaceStatusChanged;
exports.onRaceInviteAccepted = raceTriggers.onRaceInviteAccepted;
exports.onRaceInviteDeclined = raceTriggers.onRaceInviteDeclined;
exports.onRaceCreated = raceTriggers.onRaceCreated;

/**
 * ============================================================================
 * FRIEND NOTIFICATION TRIGGERS (Phase 2B - Production)
 * ============================================================================
 */

// Import friend notification triggers
const friendTriggers = require('./notifications/triggers/friendTriggers');

// Export friend triggers
exports.onFriendRequestCreated = friendTriggers.onFriendRequestCreated;
exports.onFriendRequestAccepted = friendTriggers.onFriendRequestAccepted;
exports.onFriendRequestDeclined = friendTriggers.onFriendRequestDeclined;
exports.onFriendRemoved = friendTriggers.onFriendRemoved;

/**
 * ============================================================================
 * CHAT NOTIFICATION TRIGGERS (Phase 2C - Production)
 * ============================================================================
 */

// Import chat notification triggers
const chatTriggers = require('./notifications/triggers/chatTriggers');

// Export chat triggers
exports.onChatMessageCreated = chatTriggers.onChatMessageCreated;
exports.onRaceChatMessageCreated = chatTriggers.onRaceChatMessageCreated;

/**
 * ============================================================================
 * SCHEDULED CLOUD FUNCTIONS (Phase 3 - Production)
 * ============================================================================
 */

// Import scheduled race auto-starter
const raceAutoStarter = require('./scheduled/raceAutoStarter');

// Import race countdown checker (Perfect Race Notifications)
const raceCountdownChecker = require('./scheduled/raceCountdownChecker');

// Export scheduled functions
exports.autoStartScheduledRaces = raceAutoStarter.autoStartScheduledRaces;
exports.checkRaceCountdowns = raceCountdownChecker.checkRaceCountdowns;
