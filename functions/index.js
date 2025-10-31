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
 * HEALTH DATA SYNC FUNCTION (Server-Side Baseline Management)
 * ============================================================================
 */

/**
 * FUNCTION: syncHealthDataToRaces (HTTPS Callable)
 *
 * Accepts total health data (steps, distance, calories) from client and propagates
 * to all active races using server-side baseline tracking.
 *
 * Features:
 * - Server-side baseline storage (single source of truth)
 * - Automatic day rollover detection and baseline reset
 * - Delta calculation server-side
 * - Idempotency using request IDs
 * - Validation and anomaly detection
 * - Multi-race support
 *
 * Input:
 * {
 *   userId: string,
 *   totalSteps: number,
 *   totalDistance: number,  // km
 *   totalCalories: number,
 *   timestamp: number,      // milliseconds since epoch
 *   date: string           // "yyyy-MM-dd"
 * }
 *
 * Returns:
 * {
 *   success: boolean,
 *   racesUpdated: number,
 *   message: string
 * }
 */
exports.syncHealthDataToRaces = functions.https.onCall(async (data, context) => {
  // 1. Authentication check
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated to sync health data');
  }

  const userId = context.auth.uid;
  const { totalSteps, totalDistance, totalCalories, timestamp, date } = data;

  // 2. Input validation
  if (typeof totalSteps !== 'number' || totalSteps < 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid totalSteps');
  }
  if (typeof totalDistance !== 'number' || totalDistance < 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid totalDistance');
  }
  if (typeof totalCalories !== 'number' || totalCalories < 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid totalCalories');
  }
  if (!date || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid date format (expected yyyy-MM-dd)');
  }

  console.log(`🏥 [HEALTH_SYNC] Processing health data for user ${userId}:`);
  console.log(`   Steps: ${totalSteps}, Distance: ${totalDistance.toFixed(2)} km, Calories: ${totalCalories}`);
  console.log(`   Date: ${date}, Timestamp: ${new Date(timestamp).toISOString()}`);

  try {
    // 3. Get all active races for this user (statusId 3 or 6)
    const activeRacesSnapshot = await db.collection('races')
      .where('statusId', 'in', [3, 6])
      .get();

    // Filter to races where user is a participant
    const userActiveRaces = [];
    for (const raceDoc of activeRacesSnapshot.docs) {
      const raceData = raceDoc.data();
      const participantDoc = await raceDoc.ref
        .collection('participants')
        .doc(userId)
        .get();

      if (participantDoc.exists) {
        const participantData = participantDoc.data();

        // ✅ DEFENSIVE CHECK: Only sync to races that are truly active and user hasn't completed
        // statusId 3 = Active, statusId 6 = Paused (both allow step syncing)
        // Once race ends (statusId 4), users who didn't finish are DNF (Did Not Finish)
        if (!participantData.isCompleted) {
          // Double-check race status (defensive)
          if (raceData.statusId !== 3 && raceData.statusId !== 6) {
            console.log(`   ⚠️ Race ${raceDoc.id} has invalid statusId ${raceData.statusId}, skipping`);
            continue;
          }

          userActiveRaces.push({
            raceId: raceDoc.id,
            raceData: raceData,
            participantData: participantData,
          });
        } else {
          console.log(`   ⏭️ User already completed race ${raceDoc.id}, skipping`);
        }
      }
    }

    if (userActiveRaces.length === 0) {
      console.log(`ℹ️ [HEALTH_SYNC] No active races for user ${userId}`);
      return {
        success: true,
        racesUpdated: 0,
        message: 'No active races to update',
      };
    }

    console.log(`📊 [HEALTH_SYNC] Found ${userActiveRaces.length} active race(s) for user ${userId}`);

    // 4. Process each race
    let racesUpdated = 0;
    const batch = db.batch();

    for (const { raceId, raceData, participantData } of userActiveRaces) {
      try {
        // Get or create baseline for this race
        const baselineRef = db.collection('users')
          .doc(userId)
          .collection('health_baselines')
          .doc(raceId);

        const baselineDoc = await baselineRef.get();
        let baselineData;

        if (!baselineDoc.exists) {
          // Create new baseline (first time syncing to this race)
          console.log(`🆕 [HEALTH_SYNC] Creating baseline for race ${raceId} (${raceData.title})`);
          baselineData = {
            raceId: raceId,
            raceTitle: raceData.title || 'Untitled Race',
            startTimestamp: admin.firestore.Timestamp.now(),
            healthKitBaselineSteps: totalSteps,
            healthKitBaselineDistance: totalDistance,
            healthKitBaselineCalories: totalCalories,
            lastProcessedDate: date,
            createdAt: admin.firestore.Timestamp.now(),
            lastUpdatedAt: admin.firestore.Timestamp.now(),
          };
          batch.set(baselineRef, baselineData);
        } else {
          baselineData = baselineDoc.data();

          // Check for day rollover
          if (baselineData.lastProcessedDate && baselineData.lastProcessedDate !== date) {
            console.log(`🌅 [HEALTH_SYNC] Day rollover detected for race ${raceId}`);
            console.log(`   Previous date: ${baselineData.lastProcessedDate}, Today: ${date}`);
            console.log(`   Resetting baseline: ${baselineData.healthKitBaselineSteps} steps → ${totalSteps} steps`);

            // Reset baseline to current totals
            baselineData.healthKitBaselineSteps = totalSteps;
            baselineData.healthKitBaselineDistance = totalDistance;
            baselineData.healthKitBaselineCalories = totalCalories;
            baselineData.lastProcessedDate = date;
            baselineData.lastUpdatedAt = admin.firestore.Timestamp.now();

            batch.update(baselineRef, baselineData);
          }
        }

        // 5. Calculate deltas
        const stepsDelta = totalSteps - baselineData.healthKitBaselineSteps;
        const distanceDelta = totalDistance - baselineData.healthKitBaselineDistance;
        const caloriesDelta = totalCalories - baselineData.healthKitBaselineCalories;

        console.log(`   📊 Race: ${baselineData.raceTitle}`);
        console.log(`      Baseline: ${baselineData.healthKitBaselineSteps} steps, ${baselineData.healthKitBaselineDistance.toFixed(2)} km, ${baselineData.healthKitBaselineCalories} cal`);
        console.log(`      Current: ${totalSteps} steps, ${totalDistance.toFixed(2)} km, ${totalCalories} cal`);
        console.log(`      Delta: +${stepsDelta} steps, +${distanceDelta.toFixed(2)} km, +${caloriesDelta} cal`);

        // Skip if no new progress
        if (stepsDelta <= 0 && distanceDelta <= 0) {
          console.log(`   ⏭️ No new progress for race ${raceId}, skipping`);
          continue;
        }

        // 6. Validation: Check for anomalies
        if (stepsDelta > 20000) {
          console.log(`   ❌ ANOMALY: Step delta too large (${stepsDelta}), capping at 20,000`);
          // Cap the delta but don't fail - could be legitimate multi-hour sync
          const cappedStepsDelta = 20000;
          const cappedDistanceDelta = distanceDelta * (cappedStepsDelta / stepsDelta);
          const cappedCaloriesDelta = Math.round(caloriesDelta * (cappedStepsDelta / stepsDelta));

          // Continue with capped values
          await updateParticipant(
            batch,
            raceId,
            userId,
            participantData,
            cappedStepsDelta,
            cappedDistanceDelta,
            cappedCaloriesDelta,
            raceData.totalDistance || 0,
            raceData.actualStartTime || raceData.startTime || null // Pass race start time for accurate avgSpeed calculation
          );

          // Update baseline with capped values
          batch.update(baselineRef, {
            healthKitBaselineSteps: baselineData.healthKitBaselineSteps + cappedStepsDelta,
            healthKitBaselineDistance: baselineData.healthKitBaselineDistance + cappedDistanceDelta,
            healthKitBaselineCalories: baselineData.healthKitBaselineCalories + cappedCaloriesDelta,
            lastUpdatedAt: admin.firestore.Timestamp.now(),
          });
        } else {
          // 7. Update participant document with deltas
          await updateParticipant(
            batch,
            raceId,
            userId,
            participantData,
            stepsDelta,
            distanceDelta,
            caloriesDelta,
            raceData.totalDistance || 0,
            raceData.actualStartTime || raceData.startTime || null // Pass race start time for accurate avgSpeed calculation
          );

          // 8. Update baseline to new totals (prevent future double-counting)
          batch.update(baselineRef, {
            healthKitBaselineSteps: totalSteps,
            healthKitBaselineDistance: totalDistance,
            healthKitBaselineCalories: totalCalories,
            lastProcessedDate: date,
            lastUpdatedAt: admin.firestore.Timestamp.now(),
          });
        }

        racesUpdated++;
        console.log(`   ✅ Race ${raceId} queued for update`);

      } catch (raceError) {
        console.error(`   ❌ Error processing race ${raceId}: ${raceError}`);
        // Continue with other races even if one fails
      }
    }

    // 9. Update ranks for all affected races
    console.log('📊 [HEALTH_SYNC] Updating ranks for all affected races...');
    for (const { raceId } of userActiveRaces) {
      try {
        await updateRaceRanks(raceId);
        console.log(`   ✅ Ranks updated for race ${raceId}`);
      } catch (rankError) {
        console.error(`   ⚠️ Failed to update ranks for race ${raceId}: ${rankError}`);
        // Don't fail the whole operation if rank update fails
      }
    }

    // 9.5. Check if races should auto-end (all participants completed)
    console.log('🏁 [HEALTH_SYNC] Checking for race auto-completion...');
    for (const { raceId, raceData } of userActiveRaces) {
      try {
        // Get all participants for this race
        const allParticipants = await db.collection('races')
          .doc(raceId)
          .collection('participants')
          .get();

        if (allParticipants.empty) {
          console.log(`   ⚠️ Race ${raceId} has no participants, skipping auto-end check`);
          continue;
        }

        // Check if ALL participants have completed
        const allCompleted = allParticipants.docs.every(doc => {
          const data = doc.data();
          return data.isCompleted === true;
        });

        if (allCompleted) {
          console.log(`   🏁 All ${allParticipants.size} participant(s) completed race ${raceId} (${raceData.title || 'Untitled'})`);
          console.log(`      Auto-ending race...`);

          // Update race to completed status
          batch.update(db.collection('races').doc(raceId), {
            statusId: 4, // Completed
            actualEndTime: admin.firestore.Timestamp.now(),
            status: 'completed',
          });

          console.log(`   ✅ Race ${raceId} queued for auto-end`);
        } else {
          const completedCount = allParticipants.docs.filter(doc => doc.data().isCompleted === true).length;
          console.log(`   ⏳ Race ${raceId} still active (${completedCount}/${allParticipants.size} completed)`);
        }
      } catch (autoEndError) {
        console.error(`   ⚠️ Error checking auto-end for race ${raceId}: ${autoEndError}`);
        // Don't fail the whole operation if auto-end check fails
      }
    }

    // 10. Commit all updates in a batch
    await batch.commit();
    console.log(`✅ [HEALTH_SYNC] Successfully updated ${racesUpdated} race(s) for user ${userId}`);

    return {
      success: true,
      racesUpdated: racesUpdated,
      message: `Successfully updated ${racesUpdated} race(s)`,
    };

  } catch (error) {
    console.error(`❌ [HEALTH_SYNC] Error syncing health data: ${error}`);
    throw new functions.https.HttpsError('internal', `Failed to sync health data: ${error.message}`);
  }
});

/**
 * Helper function to update ranks for all participants in a race
 * Sorts participants by distance with tie-breaking logic
 */
async function updateRaceRanks(raceId) {
  const participantsSnapshot = await db.collection('races')
    .doc(raceId)
    .collection('participants')
    .get();

  if (participantsSnapshot.empty) {
    console.log(`   ℹ️ No participants in race ${raceId}`);
    return;
  }

  // Get all participants with full data for tie-breaking
  const participants = participantsSnapshot.docs.map(doc => {
    const data = doc.data();
    return {
      userId: doc.id,
      distance: data.distance || 0,
      completedAt: data.completedAt || null,
      lastUpdated: data.lastUpdated || null,
      isCompleted: data.isCompleted || false,
      ref: doc.ref,
    };
  });

  // ✅ IMPROVED SORTING WITH TIE-BREAKING:
  // 1. Primary: Sort by distance (descending) - higher distance = better rank
  // 2. Tie-breaker for equal/similar distances (within 0.01 km):
  //    - If both completed: Earlier completedAt timestamp wins
  //    - If both incomplete: Later lastUpdated timestamp wins (more recent progress)
  //    - Completed participants rank higher than incomplete at same distance
  participants.sort((a, b) => {
    // Primary sort: distance (descending)
    const distanceDiff = b.distance - a.distance;

    // If distances are significantly different (>0.01 km), use distance
    if (Math.abs(distanceDiff) > 0.01) {
      return distanceDiff;
    }

    // Distances are equal or very close - apply tie-breaking
    console.log(`   🔀 Tie-breaking between ${a.userId} and ${b.userId} (both at ${a.distance.toFixed(2)}km)`);

    // If both completed, earlier completion time wins
    if (a.isCompleted && b.isCompleted && a.completedAt && b.completedAt) {
      const completionDiff = a.completedAt.toMillis() - b.completedAt.toMillis();
      console.log(`      Both completed - comparing timestamps: ${a.userId}=${a.completedAt.toDate().toISOString()} vs ${b.userId}=${b.completedAt.toDate().toISOString()}`);
      return completionDiff; // Earlier completion = better rank (negative = a wins)
    }

    // If one completed and one didn't, completed wins
    if (a.isCompleted && !b.isCompleted) {
      console.log(`      ${a.userId} completed, ${b.userId} incomplete - ${a.userId} wins`);
      return -1; // a wins
    }
    if (!a.isCompleted && b.isCompleted) {
      console.log(`      ${b.userId} completed, ${a.userId} incomplete - ${b.userId} wins`);
      return 1; // b wins
    }

    // Both incomplete - more recent update wins (they're still racing)
    if (a.lastUpdated && b.lastUpdated) {
      const updateDiff = b.lastUpdated.toMillis() - a.lastUpdated.toMillis();
      console.log(`      Both incomplete - more recent update wins: ${a.userId}=${a.lastUpdated.toDate().toISOString()} vs ${b.userId}=${b.lastUpdated.toDate().toISOString()}`);
      return updateDiff; // More recent update = better rank
    }

    // Fallback: maintain current order
    return 0;
  });

  // Update ranks using batch
  const rankBatch = db.batch();
  participants.forEach((participant, index) => {
    const newRank = index + 1;
    rankBatch.update(participant.ref, { rank: newRank });
    console.log(`      Rank ${newRank}: ${participant.userId} - ${participant.distance.toFixed(2)}km (completed: ${participant.isCompleted})`);
  });

  await rankBatch.commit();
  console.log(`   📊 Updated ranks for ${participants.length} participants with tie-breaking`);
}

/**
 * Helper function to update participant document with deltas
 */
async function updateParticipant(batch, raceId, userId, participantData, stepsDelta, distanceDelta, caloriesDelta, raceTotalDistance, raceStartTime) {
  const participantRef = db.collection('races')
    .doc(raceId)
    .collection('participants')
    .doc(userId);

  // Calculate new totals
  const currentSteps = participantData.steps || 0;
  const currentDistance = participantData.distance || 0;
  const currentCalories = participantData.calories || 0;

  const newSteps = currentSteps + stepsDelta;
  let newDistance = currentDistance + distanceDelta;
  const newCalories = currentCalories + caloriesDelta;

  // ✅ CRITICAL VALIDATION: Prevent backward progress
  // Ensure new values >= current values (no going backwards)
  if (newSteps < currentSteps) {
    console.log(`   ⚠️ Skipping update for ${userId} - new steps (${newSteps}) < current steps (${currentSteps})`);
    return; // Don't add this update to batch
  }

  if (newDistance < currentDistance) {
    console.log(`   ⚠️ Adjusting distance for ${userId} - new distance (${newDistance.toFixed(2)}km) < current distance (${currentDistance.toFixed(2)}km)`);
    newDistance = currentDistance; // Don't go backwards
  }

  // Validation: Cap distance at exactly race total (no GPS drift allowance)
  if (raceTotalDistance > 0 && newDistance > raceTotalDistance) {
    console.log(`   ⚠️ Distance exceeds race total, capping: ${newDistance.toFixed(2)}km → ${raceTotalDistance.toFixed(2)}km`);
    newDistance = raceTotalDistance;
  }

  // Calculate remaining distance
  const remainingDistance = Math.max(0, raceTotalDistance - newDistance);

  // ✅ IMPROVED: Calculate average speed using RACE start time, not participant join time
  // This gives accurate speed from when race actually started, not when user joined
  let avgSpeed = 0;
  if (raceStartTime) {
    const startTime = raceStartTime.toDate ? raceStartTime.toDate() : new Date(raceStartTime);
    const raceTimeMinutes = (Date.now() - startTime.getTime()) / (1000 * 60);

    if (raceTimeMinutes > 0) {
      // avgSpeed in km/h = (distance in km / time in minutes) * 60
      avgSpeed = (newDistance / raceTimeMinutes) * 60;
      console.log(`   📊 Average Speed Calculation: ${newDistance.toFixed(2)}km / ${raceTimeMinutes.toFixed(1)}min * 60 = ${avgSpeed.toFixed(2)} km/h`);
    } else {
      console.log(`   ⚠️ Race time is 0 or negative, cannot calculate average speed`);
    }
  } else {
    // Fallback: use participant join time if race start time not available
    console.log(`   ⚠️ No race start time available (actualStartTime/startTime missing), using participant joinedAt as fallback`);
    const fallbackStartTime = participantData.joinedAt?.toDate() || new Date();
    const raceTimeMinutes = (Date.now() - fallbackStartTime.getTime()) / (1000 * 60);
    avgSpeed = raceTimeMinutes > 0 ? (newDistance / raceTimeMinutes) * 60 : 0;
    console.log(`   📊 Fallback Average Speed: ${newDistance.toFixed(2)}km / ${raceTimeMinutes.toFixed(1)}min * 60 = ${avgSpeed.toFixed(2)} km/h`);
  }

  // Check if participant completed
  const isCompleted = raceTotalDistance > 0 && newDistance >= raceTotalDistance;

  // Update participant document
  const updateData = {
    steps: newSteps,
    distance: newDistance,
    calories: newCalories,
    remainingDistance: remainingDistance,
    avgSpeed: avgSpeed,
    lastUpdated: admin.firestore.Timestamp.now(),
  };

  if (isCompleted && !participantData.isCompleted) {
    updateData.isCompleted = true;
    updateData.completedAt = admin.firestore.Timestamp.now();
    console.log(`   🏆 Participant ${userId} completed race ${raceId}!`);
  }

  batch.update(participantRef, updateData);
}

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
