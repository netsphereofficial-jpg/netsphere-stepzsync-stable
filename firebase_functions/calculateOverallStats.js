/**
 * Firebase Cloud Function to calculate overall_stats from daily_stats
 *
 * This function automatically recalculates and updates overall_stats whenever
 * daily_stats is modified, reducing client-side computation load.
 *
 * Deploy with: firebase deploy --only functions:calculateOverallStats
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Firestore trigger: Recalculate overall_stats when daily_stats changes
 * Triggers on: users/{userId} document updates
 */
exports.calculateOverallStats = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const userId = context.params.userId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Check if daily_stats was modified
    const beforeDailyStats = beforeData.daily_stats || {};
    const afterDailyStats = afterData.daily_stats || {};

    // If daily_stats hasn't changed, skip processing
    if (JSON.stringify(beforeDailyStats) === JSON.stringify(afterDailyStats)) {
      console.log(`No changes to daily_stats for user ${userId}, skipping...`);
      return null;
    }

    console.log(`Recalculating overall_stats for user ${userId}`);

    try {
      // Calculate totals from daily_stats
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

      // Prepare update data
      const overallStats = {
        total_steps: totalSteps,
        total_distance: totalDistance,
        total_calories: totalCalories,
        days_active: daysActive,
        last_updated: admin.firestore.FieldValue.serverTimestamp(),
        calculated_by: 'cloud_function',
      };

      console.log(`Calculated stats for user ${userId}:`, {
        total_steps: totalSteps,
        total_distance: totalDistance,
        days_active: daysActive,
      });

      // Update the document with new overall_stats
      await db.collection('users').doc(userId).update({
        overall_stats: overallStats,
      });

      console.log(`Successfully updated overall_stats for user ${userId}`);
      return null;
    } catch (error) {
      console.error(`Error calculating overall_stats for user ${userId}:`, error);
      // Don't throw - let the function complete gracefully
      return null;
    }
  });

/**
 * Optional: Scheduled function to recalculate all users' stats daily
 * Runs every day at 2 AM UTC
 *
 * Deploy with: firebase deploy --only functions:scheduledStatsRecalculation
 */
exports.scheduledStatsRecalculation = functions.pubsub
  .schedule('0 2 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('Starting scheduled stats recalculation for all users...');

    try {
      const usersSnapshot = await db.collection('users').get();
      let processedCount = 0;
      let errorCount = 0;

      const batchPromises = [];

      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        const data = userDoc.data();
        const dailyStats = data.daily_stats || {};

        // Calculate totals
        let totalSteps = 0;
        let totalDistance = 0.0;
        let totalCalories = 0;
        let daysActive = 0;

        for (const [date, dayData] of Object.entries(dailyStats)) {
          totalSteps += dayData.steps || 0;
          totalDistance += dayData.distance || 0.0;
          totalCalories += dayData.calories || 0;
          daysActive++;
        }

        // Update overall_stats
        const overallStats = {
          total_steps: totalSteps,
          total_distance: totalDistance,
          total_calories: totalCalories,
          days_active: daysActive,
          last_updated: admin.firestore.FieldValue.serverTimestamp(),
          calculated_by: 'scheduled_function',
        };

        batchPromises.push(
          userDoc.ref.update({ overall_stats: overallStats })
            .then(() => {
              processedCount++;
              console.log(`Updated stats for user ${userId}`);
            })
            .catch((error) => {
              errorCount++;
              console.error(`Error updating user ${userId}:`, error);
            })
        );

        // Process in batches of 100 to avoid memory issues
        if (batchPromises.length >= 100) {
          await Promise.all(batchPromises);
          batchPromises.length = 0;
        }
      }

      // Process remaining batches
      if (batchPromises.length > 0) {
        await Promise.all(batchPromises);
      }

      console.log(`Scheduled recalculation complete: ${processedCount} users processed, ${errorCount} errors`);
      return null;
    } catch (error) {
      console.error('Error in scheduled stats recalculation:', error);
      return null;
    }
  });

/**
 * Optional: HTTP callable function to manually trigger recalculation for a user
 *
 * Call from app:
 * const recalculateStats = functions.httpsCallable('recalculateUserStats');
 * await recalculateStats({ userId: 'user_id_here' });
 */
exports.recalculateUserStats = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = data.userId || context.auth.uid;

  console.log(`Manual recalculation requested for user ${userId}`);

  try {
    const userDoc = await db.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User document not found');
    }

    const userData = userDoc.data();
    const dailyStats = userData.daily_stats || {};

    // Calculate totals
    let totalSteps = 0;
    let totalDistance = 0.0;
    let totalCalories = 0;
    let daysActive = 0;

    for (const [date, dayData] of Object.entries(dailyStats)) {
      totalSteps += dayData.steps || 0;
      totalDistance += dayData.distance || 0.0;
      totalCalories += dayData.calories || 0;
      daysActive++;
    }

    // Update overall_stats
    const overallStats = {
      total_steps: totalSteps,
      total_distance: totalDistance,
      total_calories: totalCalories,
      days_active: daysActive,
      last_updated: admin.firestore.FieldValue.serverTimestamp(),
      calculated_by: 'manual_function',
    };

    await userDoc.ref.update({ overall_stats: overallStats });

    console.log(`Successfully recalculated stats for user ${userId}`);

    return {
      success: true,
      stats: {
        total_steps: totalSteps,
        total_distance: totalDistance,
        days_active: daysActive,
      },
    };
  } catch (error) {
    console.error(`Error recalculating stats for user ${userId}:`, error);
    throw new functions.https.HttpsError('internal', 'Failed to recalculate stats');
  }
});
