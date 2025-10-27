/**
 * Race Auto-Starter - Scheduled Cloud Function
 *
 * Purpose: Automatically start races when their scheduled time arrives
 *
 * Execution: Runs every 1 minute via Cloud Scheduler
 *
 * Logic:
 * 1. Query all races with statusId == 1 (SCHEDULED)
 * 2. Check if raceScheduleTime has passed
 * 3. Update race status to statusId == 3 (ACTIVE)
 * 4. Update all participants to status 'active'
 * 5. Trigger onRaceStatusChanged which sends notifications
 *
 * Benefits:
 * - Works 24/7 regardless of client app state
 * - Centralized race management
 * - Guaranteed execution via Cloud Scheduler
 * - Automatically triggers notification system
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

const db = admin.firestore();

/**
 * Scheduled function to auto-start races at their scheduled time
 *
 * Schedule: Runs every 1 minute
 * Triggered by: Cloud Scheduler (cron: "* * * * *")
 */
exports.autoStartScheduledRaces = functions.pubsub
  .schedule('every 1 minutes') // Runs every minute
  .timeZone('UTC') // Use UTC timezone
  .onRun(async (context) => {
    console.log('🕒 [Auto-Starter] Checking for scheduled races to start...');

    try {
      const now = admin.firestore.Timestamp.now();

      // Query all scheduled races (statusId == 1)
      const scheduledRacesSnapshot = await db
        .collection('races')
        .where('statusId', '==', 1) // SCHEDULED status
        .get();

      if (scheduledRacesSnapshot.empty) {
        console.log('✅ [Auto-Starter] No scheduled races found');
        return null;
      }

      console.log(`📋 [Auto-Starter] Found ${scheduledRacesSnapshot.size} scheduled races to check`);

      let startedCount = 0;
      let skippedCount = 0;
      let errorCount = 0;

      // Process each scheduled race
      const promises = scheduledRacesSnapshot.docs.map(async (raceDoc) => {
        try {
          const raceId = raceDoc.id;
          const raceData = raceDoc.data();
          const raceTitle = raceData.title || 'Untitled Race';
          const scheduleTimeField = raceData.raceScheduleTime;

          // Skip if no schedule time is set
          if (!scheduleTimeField) {
            console.log(`⚠️ [Auto-Starter] Race ${raceId} has no raceScheduleTime field, skipping`);
            skippedCount++;
            return;
          }

          let scheduleTime = null;

          // Parse schedule time (handle Timestamp, ISO String, and custom format)
          if (scheduleTimeField instanceof admin.firestore.Timestamp) {
            scheduleTime = scheduleTimeField;
          } else if (typeof scheduleTimeField === 'string') {
            // Handle string formats
            if (scheduleTimeField === 'Available anytime' || scheduleTimeField === 'Open-ended') {
              // Solo/Marathon races - skip auto-start
              console.log(`⏭️ [Auto-Starter] Race ${raceId} is "${scheduleTimeField}", skipping auto-start`);
              skippedCount++;
              return;
            }

            try {
              // Try parsing custom format: "dd-MM-yyyy hh:mm a"
              // Example: "09-10-2025 11:52 PM"
              const parts = scheduleTimeField.match(/(\d{2})-(\d{2})-(\d{4}) (\d{2}):(\d{2}) (AM|PM)/i);

              if (parts) {
                const day = parseInt(parts[1]);
                const month = parseInt(parts[2]) - 1; // JS months are 0-indexed
                const year = parseInt(parts[3]);
                let hours = parseInt(parts[4]);
                const minutes = parseInt(parts[5]);
                const ampm = parts[6].toUpperCase();

                // Convert to 24-hour format
                if (ampm === 'PM' && hours !== 12) hours += 12;
                if (ampm === 'AM' && hours === 12) hours = 0;

                const parsedDate = new Date(year, month, day, hours, minutes);
                scheduleTime = admin.firestore.Timestamp.fromDate(parsedDate);
              } else {
                // Try ISO format as fallback
                const parsedDate = new Date(scheduleTimeField);
                if (!isNaN(parsedDate.getTime())) {
                  scheduleTime = admin.firestore.Timestamp.fromDate(parsedDate);
                }
              }
            } catch (parseError) {
              console.error(`❌ [Auto-Starter] Failed to parse schedule time for race ${raceId}: ${scheduleTimeField}`, parseError);
              errorCount++;
              return;
            }
          }

          // Skip if we couldn't parse the schedule time
          if (!scheduleTime) {
            console.log(`⚠️ [Auto-Starter] Could not parse schedule time for race ${raceId}: ${scheduleTimeField}`);
            skippedCount++;
            return;
          }

          // Check if schedule time has arrived or passed
          if (now.toMillis() >= scheduleTime.toMillis()) {
            console.log(`⏰ [Auto-Starter] Race "${raceTitle}" (ID: ${raceId}) schedule time reached, starting...`);

            // Use Firestore transaction to ensure atomic status change
            await db.runTransaction(async (transaction) => {
              const freshRaceDoc = await transaction.get(raceDoc.ref);

              if (!freshRaceDoc.exists) {
                console.log(`⚠️ [Auto-Starter] Race ${raceId} no longer exists`);
                return;
              }

              const freshRaceData = freshRaceDoc.data();
              const currentStatus = freshRaceData.statusId;

              // Only start if still in SCHEDULED status
              if (currentStatus !== 1) {
                console.log(`⚠️ [Auto-Starter] Race ${raceId} status changed (now ${currentStatus}), skipping`);
                skippedCount++;
                return;
              }

              // Update race to ACTIVE status
              transaction.update(raceDoc.ref, {
                statusId: 3, // ACTIVE
                status: 'active',
                actualStartTime: admin.firestore.FieldValue.serverTimestamp(),
                autoStarted: true, // Mark as auto-started by scheduler
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });

              console.log(`✅ [Auto-Starter] Race ${raceId} transitioned to ACTIVE`);
              startedCount++;

              // Update all participants to 'active' status
              const participantsSnapshot = await raceDoc.ref.collection('participants').get();

              participantsSnapshot.forEach((participantDoc) => {
                transaction.update(participantDoc.ref, {
                  status: 'active',
                  lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
                });
              });

              console.log(`👥 [Auto-Starter] Updated ${participantsSnapshot.size} participants to active status`);
            });

            // Note: onRaceStatusChanged trigger will automatically send notifications
          } else {
            // Schedule time not yet reached
            const timeUntilStart = scheduleTime.toMillis() - now.toMillis();
            const minutesUntilStart = Math.floor(timeUntilStart / 60000);
            console.log(`⏳ [Auto-Starter] Race ${raceId} starts in ${minutesUntilStart} minutes`);
            skippedCount++;
          }

        } catch (error) {
          console.error(`❌ [Auto-Starter] Error processing race ${raceDoc.id}:`, error);
          errorCount++;
        }
      });

      // Wait for all races to be processed
      await Promise.all(promises);

      console.log(`
✅ [Auto-Starter] Race Auto-Start Summary:
   - Total Checked: ${scheduledRacesSnapshot.size}
   - Started: ${startedCount}
   - Skipped: ${skippedCount}
   - Errors: ${errorCount}
      `);

      return null;

    } catch (error) {
      console.error('❌ [Auto-Starter] Fatal error in autoStartScheduledRaces:', error);
      return null;
    }
  });
