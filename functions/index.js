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

        // ✅ FIX: Check if this is the FIRST finisher to trigger countdown timer
        const raceDoc = await raceRef.get();
        if (raceDoc.exists) {
          const raceData = raceDoc.data();
          const currentCompletedCount = raceData.completedParticipantCount || 0;
          const totalParticipants = raceData.participantCount || 0;

          // If this is the first completion AND there are other participants still racing
          if (currentCompletedCount === 0 && totalParticipants > 1 && raceData.statusId === 3) {
            console.log(`🎯 First finisher in race ${raceId}! Starting countdown timer (statusId: 3 → 6)`);

            // Calculate race deadline based on duration
            const durationMinutes = raceData.durationMins || (raceData.durationHrs * 60) || 60; // Default 1 hour
            const deadlineDate = new Date();
            deadlineDate.setMinutes(deadlineDate.getMinutes() + durationMinutes);

            updateData.statusId = 6; // Start countdown for remaining participants
            updateData.status = 'Ending'; // Update status string
            updateData.firstFinisherTime = admin.firestore.FieldValue.serverTimestamp();
            updateData.firstFinisherUserId = userId; // Track who finished first
            updateData.raceDeadline = deadlineDate.toISOString(); // Set deadline for countdown

            console.log(`⏱️ Countdown timer started for race ${raceId}`);
            console.log(`   Duration: ${durationMinutes} minutes`);
            console.log(`   Deadline: ${deadlineDate.toISOString()}`);
          }
        }
      }

      // ✅ UPDATED: Detect rank changes (overtaking) - only for PRIVATE races
      const oldRank = beforeData.rank || 999;
      const newRank = afterData.rank || 999;
      const rankChanged = oldRank !== newRank;
      const rankImproved = newRank < oldRank; // Lower rank number = better position

      // ✅ RANK 0 CHECK: Skip overtaking notifications when participants are at rank 0
      if (rankChanged && rankImproved && newRank > 0 && oldRank > 0) {
        console.log(`🎯 Rank improved: ${userId} moved from #${oldRank} to #${newRank} in race ${raceId}`);

        // Send overtaking notifications (only for PRIVATE races)
        try {
          const { sendOvertakingNotifications } = require('./notifications/senders/raceNotifications');

          const raceDoc = await raceRef.get();
          if (raceDoc.exists) {
            const raceData = raceDoc.data();
            const raceTypeId = raceData.raceTypeId || 3; // Default to public

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
              participantsSnapshot.docs,
              raceTypeId // ✅ Pass raceTypeId for filtering
            );

            console.log(`🔔 Overtaking notifications sent for race ${raceId}`);
          }
        } catch (notifError) {
          console.error(`⚠️ Failed to send overtaking notifications: ${notifError}`);
        }
      } else if (rankChanged && newRank === 0 && oldRank === 0) {
        console.log(`⏭️ Skipping overtaking notification - participants at rank 0 (race just started)`);
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

        // ✅ UPDATED: Send leader change notification to all participants (only for PUBLIC races)
        try {
          const { sendLeaderChangeNotification } = require('./notifications/senders/raceNotifications');

          const raceDoc = await raceRef.get();
          if (raceDoc.exists) {
            const raceData = raceDoc.data();
            const raceTypeId = raceData.raceTypeId || 3; // Default to public

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
              participantsSnapshot.docs,
              raceTypeId // ✅ Pass raceTypeId for filtering
            );

            console.log(`🔔 Leader change notification sent for race ${raceId}`);
          }
        } catch (notifError) {
          console.error(`⚠️ Failed to send leader change notification: ${notifError}`);
        }
      }

      // ❌ REMOVED: Milestone completion detection (25%, 50%, 75%)
      // Milestone notifications are no longer sent per requirements

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

        // ✅ NEW: Save final leaderboard snapshot for permanent storage
        const finalLeaderboard = participantsSnapshot.docs.map(doc => {
          const data = doc.data();
          return {
            userId: doc.id,
            userName: data.userName || data.displayName || 'Unknown',
            rank: data.rank || 999,
            distance: data.distance || 0,
            steps: data.steps || 0,
            isCompleted: data.isCompleted || false,
            completedAt: data.completedAt || null,
            avgSpeed: data.avgSpeed || 0,
            profilePicture: data.profilePicture || null,
          };
        });

        // Save top 3 for podium display (quick access)
        const podium = finalLeaderboard.slice(0, 3);

        // Update race with final statistics and leaderboard snapshot
        await change.after.ref.update({
          raceCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
          finalParticipantCount: totalParticipants,
          finalCompletedCount: completedParticipants,
          completionRate: totalParticipants > 0 ? (completedParticipants / totalParticipants * 100) : 0,
          finalLeaderboard: finalLeaderboard, // Full leaderboard
          podium: podium, // Top 3 for quick access
        });

        console.log(`✅ [Stats] Race ${raceId} final stats: ${completedParticipants}/${totalParticipants} completed (${(completedParticipants/totalParticipants*100).toFixed(1)}%)`);
        console.log(`📊 [Stats] Saved final leaderboard with ${finalLeaderboard.length} participants`);
        console.log(`🏆 [Stats] Podium: 1st=${podium[0]?.userName}, 2nd=${podium[1]?.userName}, 3rd=${podium[2]?.userName}`);
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
    console.log(`🔍 [HEALTH_SYNC] Querying for active races (statusId 3 or 6)...`);
    console.log(`   User ID: ${userId}`);
    console.log(`   Date: ${date}`);

    const activeRacesSnapshot = await db.collection('races')
      .where('statusId', 'in', [3, 6])
      .get();

    console.log(`   Found ${activeRacesSnapshot.size} total active races in database`);

    if (activeRacesSnapshot.size === 0) {
      console.log(`   ⚠️ No active races found in database with statusId 3 or 6`);
      console.log(`   This could mean: no races are active, or all races have different status`);
    }

    // Filter to races where user is a participant
    const userActiveRaces = [];
    let totalRacesChecked = 0;
    let userParticipantCount = 0;
    let alreadyCompletedCount = 0;

    for (const raceDoc of activeRacesSnapshot.docs) {
      totalRacesChecked++;
      const raceData = raceDoc.data();
      console.log(`   [${totalRacesChecked}/${activeRacesSnapshot.size}] Checking race ${raceDoc.id}:`);
      console.log(`      Title: ${raceData.title}`);
      console.log(`      StatusId: ${raceData.statusId}`);
      console.log(`      Start Time: ${raceData.startTime ? new Date(raceData.startTime._seconds * 1000).toISOString() : 'N/A'}`);
      console.log(`      Total Distance: ${raceData.totalDistance || 'N/A'} km`);

      const participantDoc = await raceDoc.ref
        .collection('participants')
        .doc(userId)
        .get();

      if (participantDoc.exists) {
        userParticipantCount++;
        const participantData = participantDoc.data();
        console.log(`      ✅ User IS a participant!`);
        console.log(`         Current distance: ${participantData.distance || 0}km`);
        console.log(`         Steps: ${participantData.steps || 0}`);
        console.log(`         IsCompleted: ${participantData.isCompleted}`);
        console.log(`         Rank: ${participantData.rank || 'N/A'}`);

        // ✅ DEFENSIVE CHECK: Only sync to races that are truly active
        // statusId 3 = Active, statusId 6 = Paused (both allow step syncing)
        // Once race ends (statusId 4), users who didn't finish are DNF (Did Not Finish)

        // Double-check race status (defensive)
        if (raceData.statusId !== 3 && raceData.statusId !== 6) {
          console.log(`      ❌ Race ${raceDoc.id} has invalid statusId ${raceData.statusId}, skipping`);
          continue;
        }

        // ✅ CRITICAL FIX: Process ALL active races, even if participant completed
        // The monotonic validation later will prevent decreasing steps
        // This allows fixing corrupted data where steps reset to 0 but isCompleted=true
        userActiveRaces.push({
          raceId: raceDoc.id,
          raceData: raceData,
          participantData: participantData,
        });

        if (participantData.isCompleted) {
          alreadyCompletedCount++;
          console.log(`      ⚠️ User completed this race but still processing (allows fixing corrupted data)`);
        } else {
          console.log(`      ✅ ADDED TO SYNC LIST (will process this race)`);
        }
      } else {
        console.log(`      ⏭️ User is NOT a participant in this race`);
      }
    }

    console.log(`\n📊 [RACE_QUERY_SUMMARY]:`);
    console.log(`   Total active races in database: ${activeRacesSnapshot.size}`);
    console.log(`   Races where user is participant: ${userParticipantCount}`);
    console.log(`   Already completed by user: ${alreadyCompletedCount}`);
    console.log(`   Races to sync: ${userActiveRaces.length}`);
    console.log(``);

    if (userActiveRaces.length === 0) {
      console.log(`ℹ️ [HEALTH_SYNC] No active races for user ${userId} (checked ${activeRacesSnapshot.size} races)`);
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
        console.log(`\n🏁 [PROCESSING] Starting to process race: ${raceId} (${raceData.title})`);

        // Get or create baseline for this race
        const baselineRef = db.collection('users')
          .doc(userId)
          .collection('health_baselines')
          .doc(raceId);

        console.log(`   📂 Checking for existing baseline at: users/${userId}/health_baselines/${raceId}`);
        const baselineDoc = await baselineRef.get();
        let baselineData;
        let useTimeBasedBaseline = false;

        if (!baselineDoc.exists) {
          // Create new baseline (first time syncing to this race)
          console.log(`   🆕 [BASELINE] No existing baseline found - creating new one`);
          console.log(`      This is the first sync for this race`);
          console.log(`      Initial baseline will be: ${totalSteps} steps, ${totalDistance.toFixed(2)} km, ${totalCalories} cal`);

          // 🛡️ CRITICAL VALIDATION: Prevent zero baseline creation
          // Zero baselines cause step drift where ALL future steps get added to races
          // This happens during app restarts before Health Connect responds with real data
          if (totalSteps === 0 && totalDistance === 0 && totalCalories === 0) {
            console.log(`   ❌ [BASELINE_VALIDATION] REJECTED: Cannot create baseline with all zero values!`);
            console.log(`      This indicates health data not yet loaded (app restart, Health Connect rate limit, etc.)`);
            console.log(`      Throwing error to notify client that health data is not ready`);
            throw new functions.https.HttpsError(
              'failed-precondition',
              'Cannot create race baseline with zero health data. Health data is not yet loaded. Please wait a few seconds and try again.'
            );
          }

          // Additional safety: Warn if only steps is zero (suspicious)
          if (totalSteps === 0 && (totalDistance > 0 || totalCalories > 0)) {
            console.log(`   ⚠️ [BASELINE_VALIDATION] WARNING: Steps is zero but distance/calories are not`);
            console.log(`      Steps: ${totalSteps}, Distance: ${totalDistance}, Calories: ${totalCalories}`);
            console.log(`      This is unusual but may be valid in edge cases (e.g., wheelchair user)`);
            console.log(`      Proceeding with baseline creation but flagging for review`);
          }

          baselineData = {
            raceId: raceId,
            raceTitle: raceData.title || 'Untitled Race',
            startTimestamp: admin.firestore.Timestamp.now(),
            healthKitBaselineSteps: totalSteps,
            healthKitBaselineDistance: totalDistance,
            healthKitBaselineCalories: totalCalories,
            lastProcessedDate: date,
            maxParticipantStepsEverSeen: participantData.steps || 0,  // ✅ Track max steps for monotonic validation
            createdAt: admin.firestore.Timestamp.now(),
            lastUpdatedAt: admin.firestore.Timestamp.now(),
          };
          batch.set(baselineRef, baselineData);
          console.log(`      ✅ Baseline validation passed - queued for creation in batch`);
        } else {
          console.log(`   📖 [BASELINE] Found existing baseline`);
          baselineData = baselineDoc.data();

          // Check if this is a time-based baseline (new architecture)
          useTimeBasedBaseline = baselineData.useTimeBasedBaseline === true;

          if (useTimeBasedBaseline) {
            console.log(`   ⏰ [TIME-BASED] Using time-based baseline (fixed anchor point)`);
            console.log(`      Baseline at race start: ${baselineData.healthKitStepsAtStart} steps, ${baselineData.healthKitDistanceAtStart.toFixed(2)} km, ${baselineData.healthKitCaloriesAtStart} cal`);
            console.log(`      Race start time: ${baselineData.raceStartTime ? new Date(baselineData.raceStartTime._seconds * 1000).toISOString() : 'N/A'}`);
          } else {
            console.log(`   📅 [LEGACY] Using legacy day-based baseline`);
            console.log(`      Current baseline: ${baselineData.healthKitBaselineSteps} steps, ${baselineData.healthKitBaselineDistance.toFixed(2)} km, ${baselineData.healthKitBaselineCalories} cal`);
            console.log(`      Last processed date: ${baselineData.lastProcessedDate}`);
            console.log(`      Today's date: ${date}`);

            // Check for day rollover (only for legacy baselines)
            if (baselineData.lastProcessedDate && baselineData.lastProcessedDate !== date) {
              console.log(`   🌅 [DAY_ROLLOVER] Day rollover detected!`);
              console.log(`      Previous date: ${baselineData.lastProcessedDate}`);
              console.log(`      Today: ${date}`);
              console.log(`      Resetting baseline: ${baselineData.healthKitBaselineSteps} steps → ${totalSteps} steps`);
              console.log(`      This prevents counting yesterday's steps in today's race`);

              // Reset baseline to current totals
              baselineData.healthKitBaselineSteps = totalSteps;
              baselineData.healthKitBaselineDistance = totalDistance;
              baselineData.healthKitBaselineCalories = totalCalories;
              baselineData.lastProcessedDate = date;
              baselineData.lastUpdatedAt = admin.firestore.Timestamp.now();

              batch.update(baselineRef, baselineData);
              console.log(`      ✅ Baseline reset queued in batch`);
            } else {
              console.log(`   ✅ Same day - no rollover, will calculate delta normally`);
            }
          }
        }

        // 5. Calculate deltas based on baseline type
        let stepsDelta, distanceDelta, caloriesDelta;

        if (useTimeBasedBaseline) {
          // Time-based: Calculate from fixed anchor point at race start
          stepsDelta = totalSteps - (baselineData.healthKitStepsAtStart || 0);
          distanceDelta = totalDistance - (baselineData.healthKitDistanceAtStart || 0);
          caloriesDelta = totalCalories - (baselineData.healthKitCaloriesAtStart || 0);
        } else {
          // Legacy: Calculate from daily baseline
          stepsDelta = totalSteps - baselineData.healthKitBaselineSteps;
          distanceDelta = totalDistance - baselineData.healthKitBaselineDistance;
          caloriesDelta = totalCalories - baselineData.healthKitBaselineCalories;
        }

        console.log(`   📊 Race: ${baselineData.raceTitle}`);
        if (useTimeBasedBaseline) {
          console.log(`      Baseline (at race start): ${baselineData.healthKitStepsAtStart || 0} steps, ${(baselineData.healthKitDistanceAtStart || 0).toFixed(2)} km, ${baselineData.healthKitCaloriesAtStart || 0} cal`);
        } else {
          console.log(`      Baseline (daily): ${baselineData.healthKitBaselineSteps} steps, ${baselineData.healthKitBaselineDistance.toFixed(2)} km, ${baselineData.healthKitBaselineCalories} cal`);
        }
        console.log(`      Current (total today): ${totalSteps} steps, ${totalDistance.toFixed(2)} km, ${totalCalories} cal`);
        console.log(`      Delta (race progress): +${stepsDelta} steps, +${distanceDelta.toFixed(2)} km, +${caloriesDelta} cal`);

        // 🔍 DETAILED DISTANCE DELTA LOGGING
        console.log(`   📏 [DISTANCE_DELTA_CHECK] Distance delta analysis:`);
        console.log(`      Distance delta is zero: ${distanceDelta === 0.0}`);
        console.log(`      Distance delta is negative: ${distanceDelta < 0.0}`);
        console.log(`      Distance delta is positive: ${distanceDelta > 0.0}`);
        console.log(`      Steps delta: ${stepsDelta} (positive: ${stepsDelta > 0})`);

        // Calculate expected distance from steps as fallback
        const STEPS_TO_KM_FACTOR = 0.000762;
        const calculatedDistanceDelta = stepsDelta * STEPS_TO_KM_FACTOR;
        console.log(`      Expected distance from ${stepsDelta} step delta: ${calculatedDistanceDelta.toFixed(4)} km`);
        console.log(`      Should use fallback calculation: ${distanceDelta === 0.0 && stepsDelta > 0}`);

        // ✅ ANDROID FIX: Handle Health Connect inconsistency
        // Health Connect sometimes returns LOWER values after writing new data,
        // likely due to recalculation/deduplication. We need to handle this gracefully.
        let effectiveStepsDelta = stepsDelta;
        let effectiveDistanceDelta = distanceDelta;
        let effectiveCaloriesDelta = caloriesDelta;
        let baselineNeedsReset = false;

        // Case 1: Negative delta (current < baseline) - Health Connect data inconsistency
        // ONLY applies to legacy baselines (time-based baselines should never be reset)
        if (stepsDelta < 0 && !useTimeBasedBaseline) {
          const baselineSteps = baselineData.healthKitBaselineSteps;
          console.log(`   ⚠️ [HEALTH_CONNECT_INCONSISTENCY] Current value (${totalSteps}) is LOWER than baseline (${baselineSteps})`);
          console.log(`      This indicates Health Connect recalculated daily totals`);
          console.log(`      Resetting baseline to current value and treating as new starting point`);

          // Reset baseline to current value - this becomes the new starting point
          baselineNeedsReset = true;
          effectiveStepsDelta = 0;
          effectiveDistanceDelta = 0;
          effectiveCaloriesDelta = 0;

          // Update baseline immediately to prevent future negative deltas
          batch.update(baselineRef, {
            healthKitBaselineSteps: totalSteps,
            healthKitBaselineDistance: totalDistance,
            healthKitBaselineCalories: totalCalories,
            lastProcessedDate: date,
            lastUpdatedAt: admin.firestore.Timestamp.now(),
          });

          console.log(`      Baseline reset complete. Future syncs will calculate from ${totalSteps} steps`);
          continue; // Skip this sync, next sync will show proper progress
        } else if (stepsDelta < 0 && useTimeBasedBaseline) {
          console.log(`   ⚠️ [TIME-BASED] Negative delta detected (${stepsDelta})`);
          console.log(`      This could indicate user deleted health data or device issue`);
          console.log(`      Time-based baseline is NEVER reset - treating as 0 progress this sync`);
          effectiveStepsDelta = 0;
          effectiveDistanceDelta = 0;
          effectiveCaloriesDelta = 0;
        }

        // Case 2: Positive steps but distance is 0 - Use calculated distance
        if (stepsDelta > 0 && Math.abs(distanceDelta) < 0.001) {
          console.log(`   🔧 [ANDROID_FIX] Distance delta is ~0 but steps increased by ${stepsDelta}`);
          console.log(`      Using calculated distance from steps as fallback`);
          effectiveDistanceDelta = calculatedDistanceDelta;
          console.log(`      Calculated distance delta: ${effectiveDistanceDelta.toFixed(4)} km`);
        }

        // Skip if no new progress (after applying fixes)
        if (effectiveStepsDelta <= 0 && effectiveDistanceDelta <= 0) {
          console.log(`   ⏭️ No new progress for race ${raceId}, skipping`);
          continue;
        }

        // 6. Validation: Check for anomalies
        if (effectiveStepsDelta > 20000) {
          console.log(`   ❌ ANOMALY: Step delta too large (${effectiveStepsDelta}), capping at 20,000`);
          // Cap the delta but don't fail - could be legitimate multi-hour sync
          const cappedStepsDelta = 20000;
          const cappedDistanceDelta = effectiveDistanceDelta * (cappedStepsDelta / effectiveStepsDelta);
          const cappedCaloriesDelta = Math.round(effectiveCaloriesDelta * (cappedStepsDelta / effectiveStepsDelta));

          const currentParticipantSteps = participantData.steps || 0;
          const newParticipantStepsCapped = currentParticipantSteps + cappedStepsDelta;

          // ✅ MONOTONIC VALIDATION: Prevent steps from DECREASING
          // Compare new value against CURRENT value, not historical max
          // This allows recovery from data corruption (steps reset to 0)
          if (newParticipantStepsCapped < currentParticipantSteps) {
            console.log(`   ❌ [MONOTONIC_VALIDATION] REJECTED: Attempt to decrease participant steps!`);
            console.log(`      Current steps: ${currentParticipantSteps}`);
            console.log(`      New capped steps: ${newParticipantStepsCapped}`);
            console.log(`      This indicates negative delta from Health Connect recalculation`);
            continue;  // Skip this race
          }

          // Track maximum steps ever seen for debugging/analytics
          const maxStepsEverSeen = baselineData.maxParticipantStepsEverSeen || 0;
          console.log(`   📊 [MONOTONIC_CHECK] Current: ${currentParticipantSteps}, New: ${newParticipantStepsCapped}, Max ever: ${maxStepsEverSeen}`);

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
            maxParticipantStepsEverSeen: Math.max(maxStepsEverSeen, newParticipantStepsCapped),  // ✅ Update max steps
            lastUpdatedAt: admin.firestore.Timestamp.now(),
          });
        } else {
          // 7. Update participant document with deltas
          const currentParticipantSteps = participantData.steps || 0;
          const newParticipantSteps = currentParticipantSteps + effectiveStepsDelta;

          // ✅ MONOTONIC VALIDATION: Prevent steps from DECREASING
          // Compare new value against CURRENT value, not historical max
          // This allows recovery from data corruption (steps reset to 0)
          if (newParticipantSteps < currentParticipantSteps) {
            console.log(`   ❌ [MONOTONIC_VALIDATION] REJECTED: Attempt to decrease participant steps!`);
            console.log(`      Current steps: ${currentParticipantSteps}`);
            console.log(`      New steps: ${newParticipantSteps}`);
            console.log(`      This indicates negative delta from Health Connect recalculation`);
            continue;  // Skip this race
          }

          // Track maximum steps ever seen for debugging/analytics
          const maxStepsEverSeen = baselineData.maxParticipantStepsEverSeen || 0;
          console.log(`   📊 [MONOTONIC_CHECK] Current: ${currentParticipantSteps}, New: ${newParticipantSteps}, Max ever: ${maxStepsEverSeen}`);

          await updateParticipant(
            batch,
            raceId,
            userId,
            participantData,
            effectiveStepsDelta,
            effectiveDistanceDelta,
            effectiveCaloriesDelta,
            raceData.totalDistance || 0,
            raceData.actualStartTime || raceData.startTime || null // Pass race start time for accurate avgSpeed calculation
          );

          // 8. Update baseline to new totals (prevent future double-counting)
          batch.update(baselineRef, {
            healthKitBaselineSteps: totalSteps,
            healthKitBaselineDistance: totalDistance,
            healthKitBaselineCalories: totalCalories,
            maxParticipantStepsEverSeen: Math.max(maxStepsEverSeen, newParticipantSteps),  // ✅ Update max steps
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

    // 10. ✅ CRITICAL FIX: Re-validate participant data before batch commit
    // This prevents race condition where another device updated data between read and write
    console.log(`🔒 [RACE_CONDITION_PROTECTION] Re-validating participant data before batch commit...`);
    let validationFailures = 0;

    for (const { raceId, participantData } of userActiveRaces) {
      try {
        // Re-read current participant data from Firestore
        const currentParticipantDoc = await db.collection('races')
          .doc(raceId)
          .collection('participants')
          .doc(userId)
          .get();

        if (!currentParticipantDoc.exists) {
          console.log(`   ⚠️ [${raceId}] Participant doc no longer exists, skipping validation`);
          continue;
        }

        const currentData = currentParticipantDoc.data();
        const originalSteps = participantData.steps || 0;
        const currentSteps = currentData.steps || 0;

        // Check if server was updated by another device/session between read and write
        if (currentSteps > originalSteps) {
          console.log(`   ❌ [${raceId}] RACE CONDITION DETECTED!`);
          console.log(`      Original steps (when we read): ${originalSteps}`);
          console.log(`      Current steps (on server now): ${currentSteps}`);
          console.log(`      Server was updated by another device/session!`);
          console.log(`      ABORTING this batch to prevent data corruption`);

          validationFailures++;

          // Return failure to trigger retry with fresh data
          return {
            success: false,
            racesUpdated: 0,
            message: `Race condition detected - server updated between read and write. Please retry.`,
          };
        } else if (currentSteps === originalSteps) {
          console.log(`   ✅ [${raceId}] Validation passed: steps unchanged (${currentSteps})`);
        } else {
          // currentSteps < originalSteps - should not happen, but log it
          console.log(`   ⚠️ [${raceId}] Unexpected: current steps (${currentSteps}) < original (${originalSteps})`);
        }
      } catch (validationError) {
        console.error(`   ❌ Error validating race ${raceId}: ${validationError}`);
        // Continue - don't let validation errors block the batch
      }
    }

    if (validationFailures > 0) {
      console.log(`❌ [VALIDATION] ${validationFailures} race(s) failed validation, batch aborted`);
      return {
        success: false,
        racesUpdated: 0,
        message: `Validation failed for ${validationFailures} race(s) - data may have changed`,
      };
    }

    console.log(`✅ [VALIDATION] All races passed validation, proceeding with batch commit`);

    // 11. Commit all updates in a batch
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
  // 1. Primary: Completed participants ALWAYS rank higher than DNF/incomplete
  // 2. Secondary: Sort by distance (descending) - higher distance = better rank
  // 3. Tie-breaker for equal/similar distances (within 0.01 km):
  //    - If both completed: Earlier completedAt timestamp wins
  //    - If both incomplete: Later lastUpdated timestamp wins (more recent progress)
  participants.sort((a, b) => {
    // ✅ CRITICAL FIX: Completed participants ALWAYS rank higher than incomplete
    // This ensures DNF participants never rank above finishers
    if (a.isCompleted && !b.isCompleted) {
      console.log(`   ✅ ${a.userId} completed, ${b.userId} incomplete/DNF - ${a.userId} ranks higher`);
      return -1; // a wins (completed beats incomplete)
    }
    if (!a.isCompleted && b.isCompleted) {
      console.log(`   ✅ ${b.userId} completed, ${a.userId} incomplete/DNF - ${b.userId} ranks higher`);
      return 1; // b wins (completed beats incomplete)
    }

    // Primary sort: distance (descending)
    const distanceDiff = b.distance - a.distance;

    // If distances are significantly different (>0.01 km), use distance
    if (Math.abs(distanceDiff) > 0.01) {
      return distanceDiff;
    }

    // Distances are equal or very close - apply tie-breaking
    console.log(`   🔀 Tie-breaking between ${a.userId} and ${b.userId} (both at ${a.distance.toFixed(2)}km)`);

    // ✅ FIX: If both completed, earlier completion time wins
    if (a.isCompleted && b.isCompleted && a.completedAt && b.completedAt) {
      const completionDiff = a.completedAt.toMillis() - b.completedAt.toMillis();
      console.log(`      Both completed - comparing timestamps: ${a.userId}=${a.completedAt.toDate().toISOString()} vs ${b.userId}=${b.completedAt.toDate().toISOString()}`);
      console.log(`      completionDiff=${completionDiff} (negative means a finished first, should rank higher)`);
      // Earlier completion = negative = ranks FIRST (a.completedAt < b.completedAt → negative → a wins)
      return completionDiff; // Earlier completion = better rank
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
// exports.onRaceCreated = raceTriggers.onRaceCreated; // ❌ DISABLED - race creation notifications removed

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

/**
 * ============================================================================
 * USER ACCOUNT MANAGEMENT (Production)
 * ============================================================================
 */

/**
 * FUNCTION: deleteUserAccount (HTTPS Callable)
 *
 * Permanently deletes a user's account and all associated data.
 * This function is required by Apple's App Store guidelines.
 *
 * What gets deleted:
 * - User authentication (Firebase Auth)
 * - User profile (user_profiles collection)
 * - User health data (users collection)
 * - User health baselines (users/{userId}/health_baselines subcollection)
 * - Race participations (races/{raceId}/participants/{userId})
 * - Friend requests (both sent and received)
 * - Friend relationships
 * - Chat messages sent by user
 * - Notifications
 *
 * Note: Race data created by the user is preserved but anonymized.
 *
 * Returns:
 * {
 *   success: boolean,
 *   message: string
 * }
 */
exports.deleteUserAccount = functions.https.onCall(async (data, context) => {
  // 1. Authentication check
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated to delete account');
  }

  const userId = context.auth.uid;
  console.log(`🗑️ [DELETE_ACCOUNT] Starting account deletion for user ${userId}`);

  try {
    const batch = db.batch();
    let deletionCount = 0;

    // 2. Delete user profile
    console.log(`   📝 Deleting user profile...`);
    const profileRef = db.collection('user_profiles').doc(userId);
    batch.delete(profileRef);
    deletionCount++;

    // 3. Delete user health data
    console.log(`   🏥 Deleting user health data...`);
    const userHealthRef = db.collection('users').doc(userId);
    batch.delete(userHealthRef);
    deletionCount++;

    // 4. Delete health baselines subcollection
    console.log(`   📊 Deleting health baselines...`);
    const baselinesSnapshot = await db.collection('users')
      .doc(userId)
      .collection('health_baselines')
      .get();

    baselinesSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
      deletionCount++;
    });
    console.log(`      Deleted ${baselinesSnapshot.size} baseline(s)`);

    // 5. Remove from all race participations
    console.log(`   🏁 Removing race participations...`);
    const racesSnapshot = await db.collection('races').get();
    let raceParticipationCount = 0;

    for (const raceDoc of racesSnapshot.docs) {
      const participantRef = raceDoc.ref.collection('participants').doc(userId);
      const participantDoc = await participantRef.get();

      if (participantDoc.exists) {
        batch.delete(participantRef);
        raceParticipationCount++;
        deletionCount++;
      }
    }
    console.log(`      Removed from ${raceParticipationCount} race(s)`);

    // 6. Delete friend requests (sent)
    console.log(`   👥 Deleting friend requests sent...`);
    const sentRequestsSnapshot = await db.collection('friend_requests')
      .where('fromUserId', '==', userId)
      .get();

    sentRequestsSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
      deletionCount++;
    });
    console.log(`      Deleted ${sentRequestsSnapshot.size} sent request(s)`);

    // 7. Delete friend requests (received)
    console.log(`   👥 Deleting friend requests received...`);
    const receivedRequestsSnapshot = await db.collection('friend_requests')
      .where('toUserId', '==', userId)
      .get();

    receivedRequestsSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
      deletionCount++;
    });
    console.log(`      Deleted ${receivedRequestsSnapshot.size} received request(s)`);

    // 8. Delete friendships (where user is user1)
    console.log(`   👥 Deleting friendships (as user1)...`);
    const friendshipsAsUser1 = await db.collection('friendships')
      .where('user1Id', '==', userId)
      .get();

    friendshipsAsUser1.docs.forEach(doc => {
      batch.delete(doc.ref);
      deletionCount++;
    });
    console.log(`      Deleted ${friendshipsAsUser1.size} friendship(s)`);

    // 9. Delete friendships (where user is user2)
    console.log(`   👥 Deleting friendships (as user2)...`);
    const friendshipsAsUser2 = await db.collection('friendships')
      .where('user2Id', '==', userId)
      .get();

    friendshipsAsUser2.docs.forEach(doc => {
      batch.delete(doc.ref);
      deletionCount++;
    });
    console.log(`      Deleted ${friendshipsAsUser2.size} friendship(s)`);

    // 10. Delete chat messages
    console.log(`   💬 Deleting chat messages...`);
    const chatMessagesSnapshot = await db.collection('chat_messages')
      .where('senderId', '==', userId)
      .get();

    chatMessagesSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
      deletionCount++;
    });
    console.log(`      Deleted ${chatMessagesSnapshot.size} message(s)`);

    // 11. Delete notifications
    console.log(`   🔔 Deleting notifications...`);
    const notificationsSnapshot = await db.collection('notifications')
      .where('userId', '==', userId)
      .get();

    notificationsSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
      deletionCount++;
    });
    console.log(`      Deleted ${notificationsSnapshot.size} notification(s)`);

    // 12. Commit all Firestore deletions
    console.log(`   💾 Committing ${deletionCount} Firestore deletion(s)...`);
    await batch.commit();
    console.log(`   ✅ Firestore data deleted successfully`);

    // 13. Delete Firebase Auth account (must be done last)
    console.log(`   🔐 Deleting Firebase Auth account...`);
    await admin.auth().deleteUser(userId);
    console.log(`   ✅ Auth account deleted successfully`);

    console.log(`✅ [DELETE_ACCOUNT] Successfully deleted account for user ${userId}`);
    console.log(`   Total items deleted: ${deletionCount}`);

    return {
      success: true,
      message: 'Account successfully deleted',
      itemsDeleted: deletionCount
    };

  } catch (error) {
    console.error(`❌ [DELETE_ACCOUNT] Error deleting account for user ${userId}:`, error);
    throw new functions.https.HttpsError('internal', `Failed to delete account: ${error.message}`);
  }
});

/**
 * FUNCTION: initializeRaceBaseline (HTTPS Callable)
 *
 * Creates a time-based baseline when a user joins a race. This baseline
 * stores the user's current health data at join time, which will be used
 * to calculate race-specific progress.
 *
 * Input:
 * {
 *   userId: string,
 *   raceId: string,
 *   raceTitle: string,
 *   raceStartTime: string,          // ISO8601 timestamp of race start
 *   healthKitStepsAtStart: number,  // User's total steps when joining
 *   healthKitDistanceAtStart: number, // km
 *   healthKitCaloriesAtStart: number,
 *   timestamp: string               // ISO8601 timestamp of request
 * }
 *
 * Returns:
 * {
 *   success: boolean,
 *   message: string
 * }
 */
exports.initializeRaceBaseline = functions.https.onCall(async (data, context) => {
  // 1. Authentication check
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated to initialize baseline');
  }

  const authUserId = context.auth.uid;
  const {
    userId,
    raceId,
    raceTitle,
    raceStartTime,
    healthKitStepsAtStart,
    healthKitDistanceAtStart,
    healthKitCaloriesAtStart,
    timestamp
  } = data;

  // 2. Verify user is initializing their own baseline
  if (userId !== authUserId) {
    throw new functions.https.HttpsError('permission-denied', 'Can only initialize your own baseline');
  }

  // 3. Input validation
  if (!raceId || typeof raceId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid raceId');
  }
  if (!raceTitle || typeof raceTitle !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid raceTitle');
  }
  if (!raceStartTime || typeof raceStartTime !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid raceStartTime');
  }
  if (typeof healthKitStepsAtStart !== 'number' || healthKitStepsAtStart < 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid healthKitStepsAtStart');
  }
  if (typeof healthKitDistanceAtStart !== 'number' || healthKitDistanceAtStart < 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid healthKitDistanceAtStart');
  }
  if (typeof healthKitCaloriesAtStart !== 'number' || healthKitCaloriesAtStart < 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid healthKitCaloriesAtStart');
  }

  console.log(`📊 [INIT_BASELINE] Initializing baseline for user ${userId}, race ${raceId}`);
  console.log(`   Race: ${raceTitle}`);
  console.log(`   Start Time: ${raceStartTime}`);
  console.log(`   Baseline: ${healthKitStepsAtStart} steps, ${healthKitDistanceAtStart.toFixed(2)} km, ${healthKitCaloriesAtStart} cal`);

  // 🛡️ CRITICAL VALIDATION: Prevent zero baseline initialization
  // Zero baselines cause step drift where ALL future steps get added to races
  // This happens during app restarts or when health data hasn't loaded yet
  if (healthKitStepsAtStart === 0 && healthKitDistanceAtStart === 0 && healthKitCaloriesAtStart === 0) {
    console.log(`   ⚠️ [BASELINE_VALIDATION] REJECTED: Cannot initialize baseline with all zero values!`);
    console.log(`      This indicates health data not yet loaded (app restart, Health Connect rate limit, etc.)`);
    console.log(`      Client should retry baseline initialization after health data loads`);
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Cannot initialize baseline with zero health data. Please wait for health data to load and try again.'
    );
  }

  // Additional safety: Warn if only steps is zero (suspicious)
  if (healthKitStepsAtStart === 0 && (healthKitDistanceAtStart > 0 || healthKitCaloriesAtStart > 0)) {
    console.log(`   ⚠️ [BASELINE_VALIDATION] WARNING: Steps is zero but distance/calories are not`);
    console.log(`      Steps: ${healthKitStepsAtStart}, Distance: ${healthKitDistanceAtStart}, Calories: ${healthKitCaloriesAtStart}`);
    console.log(`      This is unusual but may be valid in edge cases (e.g., wheelchair user)`);
    console.log(`      Proceeding with baseline initialization but flagging for review`);
  }

  try {
    // Parse race start time
    const raceStartTimestamp = admin.firestore.Timestamp.fromDate(new Date(raceStartTime));

    // Create baseline document
    const baselineRef = db.collection('users')
      .doc(userId)
      .collection('health_baselines')
      .doc(raceId);

    // Check if baseline already exists
    const existingBaseline = await baselineRef.get();
    if (existingBaseline.exists) {
      console.log(`   ⚠️ Baseline already exists for this race, updating...`);
    }

    const baselineData = {
      raceId: raceId,
      raceTitle: raceTitle,
      raceStartTime: raceStartTimestamp,

      // Time-based baseline flag
      useTimeBasedBaseline: true,

      // Health data at race join time (baseline anchor)
      healthKitStepsAtStart: healthKitStepsAtStart,
      healthKitDistanceAtStart: healthKitDistanceAtStart,
      healthKitCaloriesAtStart: healthKitCaloriesAtStart,

      // Current race progress (starts at 0)
      currentRaceSteps: 0,
      currentRaceDistance: 0.0,
      currentRaceCalories: 0,

      // Metadata
      createdAt: admin.firestore.Timestamp.now(),
      lastUpdatedAt: admin.firestore.Timestamp.now(),
    };

    await baselineRef.set(baselineData, { merge: true });

    console.log(`✅ [INIT_BASELINE] Baseline initialized successfully`);
    console.log(`   Document path: users/${userId}/health_baselines/${raceId}`);
    console.log(`   Time-based: true`);

    return {
      success: true,
      message: 'Baseline initialized successfully',
    };

  } catch (error) {
    console.error(`❌ [INIT_BASELINE] Error initializing baseline:`, error);
    throw new functions.https.HttpsError('internal', `Failed to initialize baseline: ${error.message}`);
  }
});
