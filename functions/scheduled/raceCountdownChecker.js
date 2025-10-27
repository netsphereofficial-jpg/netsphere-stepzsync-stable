/**
 * Race Countdown Timer Checker
 *
 * Scheduled Cloud Function that runs every minute to check for races
 * approaching their deadline (5 minutes remaining) and sends countdown
 * notifications to active participants.
 *
 * Schedule: Every 1 minute
 * Target: Races in ENDING status (statusId = 6) with deadline approaching
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { sendCountdownTimerNotification } = require('../notifications/senders/raceNotifications');

const db = admin.firestore();

/**
 * Scheduled function: Check for race countdowns every minute
 *
 * Finds races that:
 * 1. Are in ENDING status (statusId = 6)
 * 2. Have a deadline between now and 5 minutes from now
 * 3. Haven't already received a 5-minute countdown notification
 *
 * Sends countdown notifications to all active (non-completed) participants
 */
exports.checkRaceCountdowns = functions.pubsub
  .schedule('every 1 minutes')
  .timeZone('America/New_York') // Adjust to your timezone
  .onRun(async (context) => {
    console.log('⏰ Starting race countdown checker...');

    try {
      const now = new Date();
      const fiveMinutesFromNow = new Date(now.getTime() + 5.5 * 60000); // 5.5 min buffer
      const fourMinutesFromNow = new Date(now.getTime() + 4 * 60000); // 4 min to avoid duplicates

      console.log(`🔍 Checking for races with deadlines between ${fourMinutesFromNow.toISOString()} and ${fiveMinutesFromNow.toISOString()}`);

      // Find races in ENDING status with deadline approaching
      // statusId = 6 means ENDING (first finisher crossed, deadline active)
      const racesSnapshot = await db
        .collection('races')
        .where('statusId', '==', 6)
        .where('raceDeadline', '>', fourMinutesFromNow)
        .where('raceDeadline', '<=', fiveMinutesFromNow)
        .get();

      if (racesSnapshot.empty) {
        console.log('ℹ️ No races found with approaching deadlines');
        return null;
      }

      console.log(`📋 Found ${racesSnapshot.size} race(s) with approaching deadlines`);

      const promises = [];

      for (const raceDoc of racesSnapshot.docs) {
        const raceId = raceDoc.id;
        const raceData = raceDoc.data();
        const deadline = raceData.raceDeadline?.toDate ? raceData.raceDeadline.toDate() : new Date(raceData.raceDeadline);
        const minutesLeft = Math.ceil((deadline - now) / 60000);

        // Check if we've already sent a countdown notification for this race
        const countdownNotificationSent = raceData.countdownNotificationSent || false;

        if (countdownNotificationSent) {
          console.log(`⏭️ Skipping race ${raceId} - countdown notification already sent`);
          continue;
        }

        // Only send if exactly 5 minutes left (with 1-minute tolerance)
        if (minutesLeft >= 4 && minutesLeft <= 5) {
          console.log(`⏰ Race "${raceData.title}" has ${minutesLeft} minutes left until deadline`);

          const raceDataForNotification = {
            id: raceId,
            title: raceData.title || 'Untitled Race',
          };

          // Send countdown notification
          promises.push(
            sendCountdownTimerNotification(raceId, raceDataForNotification, 5)
              .then(async (result) => {
                if (result.success) {
                  // Mark that countdown notification was sent to prevent duplicates
                  await raceDoc.ref.update({
                    countdownNotificationSent: true,
                    countdownNotificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
                  });
                  console.log(`✅ Countdown notification sent for race ${raceId} (${result.successCount} participants)`);
                } else {
                  console.error(`❌ Failed to send countdown notification for race ${raceId}`);
                }
                return result;
              })
              .catch(error => {
                console.error(`❌ Error sending countdown notification for race ${raceId}:`, error);
              })
          );
        }
      }

      // Wait for all notifications to be sent
      await Promise.all(promises);

      console.log(`✅ Race countdown checker completed - processed ${promises.length} race(s)`);
      return null;

    } catch (error) {
      console.error('❌ Error in race countdown checker:', error);
      return null;
    }
  });
