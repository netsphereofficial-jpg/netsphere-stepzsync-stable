/**
 * Race Notification Senders
 *
 * This module contains all race-related notification sending functions.
 * These functions are called by Firestore triggers and send push notifications
 * to users via Firebase Cloud Messaging.
 *
 * Race Notification Types:
 * 1. Race Invitation - User invited to join a race
 * 2. Race Started - Race has begun
 * 3. Race Completed - User finished race (with rank)
 * 4. Race Creation Confirmation - Race successfully created
 * 5. Race Reminder - Upcoming race reminders
 * 6. Join Request Accepted - Organizer accepted join request
 * 7. Invite Accepted - User accepted race invite
 * 8. Join Request Declined - Organizer declined join request
 * 9. Invite Declined - User declined race invite
 * 10. New Join Request - User wants to join race
 * 11. Race Won - User won a race
 */

const { sendNotificationToUser, sendNotificationToUsers } = require('../core/fcmService');
const admin = require('firebase-admin');
const db = admin.firestore();

/**
 * 1. Send race invitation notification
 * Triggered when: User is invited to join a race
 */
async function sendRaceInvitation(userId, raceData, inviterData) {
  try {
    console.log(`📤 Sending race invitation to user: ${userId}`);

    const notification = {
      title: 'Race Invitation 🏃‍♂️',
      body: `${inviterData.name} invited you to join "${raceData.title}"`,
    };

    const data = {
      type: 'InviteRace',
      category: 'Race',
      icon: '🏃‍♂️',
      raceId: raceData.id,
      raceName: raceData.title,
      inviterUserId: inviterData.id,
      inviterName: inviterData.name,
      ...(raceData.startTime && { startTime: raceData.startTime }),
      ...(raceData.distance && { distance: String(raceData.distance) }),
      ...(raceData.location && { location: raceData.location }),
    };

    const result = await sendNotificationToUser(userId, notification, data);

    if (result.success) {
      console.log(`✅ Race invitation sent to ${userId}`);
    } else {
      console.error(`❌ Failed to send race invitation to ${userId}: ${result.error}`);
    }

    return result;
  } catch (error) {
    console.error(`❌ Error sending race invitation: ${error}`);
    return { success: false, error: error.message };
  }
}

/**
 * 2. Send race started notification
 * Triggered when: Race statusId changes to 3 (ACTIVE)
 */
async function sendRaceStarted(userId, raceData) {
  try {
    console.log(`📤 Sending race started notification to user: ${userId}`);

    const notification = {
      title: 'Race Started! 🚀',
      body: `"${raceData.title}" has begun! Good luck!`,
    };

    const data = {
      type: 'RaceBegin',
      category: 'Race',
      icon: '🚀',
      raceId: raceData.id,
      raceName: raceData.title,
      ...(raceData.participantCount && { participantCount: String(raceData.participantCount) }),
      startedAt: new Date().toISOString(),
    };

    const result = await sendNotificationToUser(userId, notification, data);

    if (result.success) {
      console.log(`✅ Race started notification sent to ${userId}`);
    } else {
      console.error(`❌ Failed to send race started notification: ${result.error}`);
    }

    return result;
  } catch (error) {
    console.error(`❌ Error sending race started notification: ${error}`);
    return { success: false, error: error.message };
  }
}

/**
 * 3. Send race completed notification
 * Triggered when: Race statusId changes to 4 (COMPLETED)
 */
async function sendRaceCompleted(userId, raceData, participantData) {
  try {
    console.log(`📤 Sending race completed notification to user: ${userId}`);

    const rank = participantData.rank || 0;
    let title;
    let message;

    // Customize message based on rank
    switch (rank) {
      case 1:
        title = 'Congratulations! 🥇';
        message = `You won "${raceData.title}"! Amazing performance!`;
        break;
      case 2:
        title = 'Great Job! 🥈';
        message = `You finished 2nd in "${raceData.title}"! Well done!`;
        break;
      case 3:
        title = 'Excellent! 🥉';
        message = `You finished 3rd in "${raceData.title}"! Great effort!`;
        break;
      default:
        title = 'Race Completed! 🏃‍♂️';
        message = `You finished "${raceData.title}" in ${getOrdinal(rank)} place!`;
    }

    const notification = {
      title: title,
      body: message,
    };

    const data = {
      type: rank === 1 ? 'RaceWon' : 'RaceCompleted',
      category: rank <= 3 ? 'Achievement' : 'Race',
      icon: rank === 1 ? '🏆' : rank === 2 ? '🥈' : rank === 3 ? '🥉' : '🏃‍♂️',
      raceId: raceData.id,
      raceName: raceData.title,
      rank: String(rank),
      ...(participantData.xpEarned && { xpEarned: String(participantData.xpEarned) }),
      ...(participantData.distance && { distanceCovered: String(participantData.distance) }),
      ...(participantData.avgSpeed && { avgSpeed: String(participantData.avgSpeed) }),
      completedAt: new Date().toISOString(),
    };

    const result = await sendNotificationToUser(userId, notification, data);

    if (result.success) {
      console.log(`✅ Race completed notification sent to ${userId} (Rank: ${rank})`);
    } else {
      console.error(`❌ Failed to send race completed notification: ${result.error}`);
    }

    return result;
  } catch (error) {
    console.error(`❌ Error sending race completed notification: ${error}`);
    return { success: false, error: error.message };
  }
}

/**
 * 4. Send race creation confirmation
 * ❌ REMOVED: Race creation notifications are no longer sent
 */
// async function sendRaceCreationConfirmation - REMOVED

/**
 * 5. Send race reminder notification
 * ❌ REMOVED: Race reminder notifications are no longer sent
 */
// async function sendRaceReminder - REMOVED

/**
 * 6. Send join request accepted notification
 * ❌ REMOVED: Join request notifications are no longer sent
 */
// async function sendJoinRequestAccepted - REMOVED

/**
 * 7. Send invite accepted notification
 * Triggered when: User accepts race invitation
 */
async function sendInviteAccepted(userId, raceData, accepterData) {
  try {
    console.log(`📤 Sending invite accepted notification to user: ${userId}`);

    const notification = {
      title: 'Race Invite Accepted 🎉',
      body: `${accepterData.name} accepted your invite to "${raceData.title}"`,
    };

    const data = {
      type: 'InviteAccepted',
      category: 'Race',
      icon: '🎉',
      raceId: raceData.id,
      raceName: raceData.title,
      accepterUserId: accepterData.id,
      accepterName: accepterData.name,
      acceptedAt: new Date().toISOString(),
    };

    const result = await sendNotificationToUser(userId, notification, data);

    if (result.success) {
      console.log(`✅ Invite accepted notification sent to ${userId}`);
    } else {
      console.error(`❌ Failed to send invite accepted notification: ${result.error}`);
    }

    return result;
  } catch (error) {
    console.error(`❌ Error sending invite accepted notification: ${error}`);
    return { success: false, error: error.message };
  }
}

/**
 * 8. Send join request declined notification
 * ❌ REMOVED: Join request notifications are no longer sent
 */
// async function sendJoinRequestDeclined - REMOVED

/**
 * 9. Send invite declined notification
 * Triggered when: User declines race invitation
 */
async function sendInviteDeclined(userId, raceData, declinerData) {
  try {
    console.log(`📤 Sending invite declined notification to user: ${userId}`);

    const notification = {
      title: 'Race Invite Declined',
      body: `${declinerData.name} declined your invite to "${raceData.title}"`,
    };

    const data = {
      type: 'InviteDeclined',
      category: 'Race',
      icon: '😔',
      raceId: raceData.id,
      raceName: raceData.title,
      declinerUserId: declinerData.id,
      declinerName: declinerData.name,
      declinedAt: new Date().toISOString(),
    };

    const result = await sendNotificationToUser(userId, notification, data);

    if (result.success) {
      console.log(`✅ Invite declined notification sent to ${userId}`);
    } else {
      console.error(`❌ Failed to send invite declined notification: ${result.error}`);
    }

    return result;
  } catch (error) {
    console.error(`❌ Error sending invite declined notification: ${error}`);
    return { success: false, error: error.message };
  }
}

/**
 * 10. Send new join request notification
 * ❌ REMOVED: Join request notifications are no longer sent
 */
// async function sendNewJoinRequest - REMOVED

/**
 * 11. Send race won notification (special case for winners)
 * Triggered when: User finishes race in 1st place
 */
async function sendRaceWon(userId, raceData, winnerData) {
  try {
    console.log(`📤 Sending race won notification to user: ${userId}`);

    const notification = {
      title: '🏆 Victory! 🏆',
      body: `Congratulations! You won "${raceData.title}"!`,
    };

    const data = {
      type: 'RaceWon',
      category: 'Achievement',
      icon: '🏆',
      raceId: raceData.id,
      raceName: raceData.title,
      rank: '1',
      ...(winnerData.xpEarned && { xpEarned: String(winnerData.xpEarned) }),
      ...(winnerData.distance && { distanceCovered: String(winnerData.distance) }),
      ...(winnerData.avgSpeed && { avgSpeed: String(winnerData.avgSpeed) }),
      wonAt: new Date().toISOString(),
    };

    const result = await sendNotificationToUser(userId, notification, data);

    if (result.success) {
      console.log(`✅ Race won notification sent to ${userId}`);
    } else {
      console.error(`❌ Failed to send race won notification: ${result.error}`);
    }

    return result;
  } catch (error) {
    console.error(`❌ Error sending race won notification: ${error}`);
    return { success: false, error: error.message };
  }
}

/**
 * Batch send race started notifications to all participants
 * Used by race start trigger
 * ✅ UPDATED: Only sends for PUBLIC races (raceTypeId === 3)
 * ✅ UPDATED: Skips notifications when all participants have rank 0 (race just started)
 */
async function sendRaceStartedToAllParticipants(raceId) {
  try {
    console.log(`📤 Sending race started notifications to all participants of race: ${raceId}`);

    // Get race data
    const raceDoc = await db.collection('races').doc(raceId).get();
    if (!raceDoc.exists) {
      console.error(`❌ Race ${raceId} not found`);
      return { success: false, error: 'Race not found' };
    }

    const raceData = { id: raceId, ...raceDoc.data() };
    const raceTypeId = raceData.raceTypeId || 3; // Default to public

    // ✅ FILTER: Only send race started notifications for PUBLIC races
    if (raceTypeId !== 3) {
      console.log(`⏭️ Skipping race started notifications for race ${raceId} - not a public race (raceTypeId: ${raceTypeId})`);
      return { success: true, message: 'Race started notifications only for public races' };
    }

    // Get all participants
    const participantsSnapshot = await db.collection('races').doc(raceId).collection('participants').get();

    if (participantsSnapshot.empty) {
      console.log(`ℹ️ No participants found for race ${raceId}`);
      return { success: true, message: 'No participants to notify' };
    }

    // ✅ RANK 0 CHECK: If all participants have rank 0, skip notifications
    const allParticipantsRankZero = participantsSnapshot.docs.every(doc => {
      const participantData = doc.data();
      return (participantData.rank === 0 || participantData.rank === undefined || participantData.rank === null);
    });

    if (allParticipantsRankZero) {
      console.log(`⏭️ Skipping race started notifications - all participants at rank 0 (race just started, no movement yet)`);
      return { success: true, message: 'Skipped - all participants at rank 0' };
    }

    // Send to all participants
    const promises = [];
    participantsSnapshot.forEach(doc => {
      const participantUserId = doc.id;
      promises.push(sendRaceStarted(participantUserId, raceData));
    });

    const results = await Promise.all(promises);
    const successCount = results.filter(r => r.success).length;
    const failureCount = results.filter(r => !r.success).length;

    console.log(`✅ Race started notifications sent: ${successCount} succeeded, ${failureCount} failed`);

    return { success: true, successCount, failureCount };
  } catch (error) {
    console.error(`❌ Error sending race started notifications: ${error}`);
    return { success: false, error: error.message };
  }
}

/**
 * Batch send race completed notifications to all participants
 * Used by race complete trigger
 * ✅ UPDATED: Only sends notifications for top 3 finishers (1st, 2nd, 3rd)
 */
async function sendRaceCompletedToAllParticipants(raceId) {
  try {
    console.log(`📤 Sending race completed notifications to all participants of race: ${raceId}`);

    // Get race data
    const raceDoc = await db.collection('races').doc(raceId).get();
    if (!raceDoc.exists) {
      console.error(`❌ Race ${raceId} not found`);
      return { success: false, error: 'Race not found' };
    }

    const raceData = { id: raceId, ...raceDoc.data() };

    // Get all participants with their rankings
    const participantsSnapshot = await db.collection('races').doc(raceId).collection('participants').get();

    if (participantsSnapshot.empty) {
      console.log(`ℹ️ No participants found for race ${raceId}`);
      return { success: true, message: 'No participants to notify' };
    }

    // ✅ FILTER: Only send to top 3 finishers (1st, 2nd, 3rd)
    const promises = [];
    participantsSnapshot.forEach(doc => {
      const participantUserId = doc.id;
      const participantData = doc.data();
      const rank = participantData.rank || 999;

      // Only notify participants who finished in top 3
      if (rank <= 3 && rank >= 1) {
        console.log(`🏆 Sending podium notification to ${participantUserId} (Rank ${rank})`);
        promises.push(sendRaceCompleted(participantUserId, raceData, participantData));
      } else {
        console.log(`⏭️ Skipping notification for ${participantUserId} (Rank ${rank}) - not in top 3`);
      }
    });

    if (promises.length === 0) {
      console.log(`ℹ️ No top 3 finishers to notify for race ${raceId}`);
      return { success: true, message: 'No top 3 finishers to notify' };
    }

    const results = await Promise.all(promises);
    const successCount = results.filter(r => r.success).length;
    const failureCount = results.filter(r => !r.success).length;

    console.log(`✅ Race completed notifications sent to top 3: ${successCount} succeeded, ${failureCount} failed`);

    return { success: true, successCount, failureCount };
  } catch (error) {
    console.error(`❌ Error sending race completed notifications: ${error}`);
    return { success: false, error: error.message };
  }
}

/**
 * 12. Send public race announcement to ALL users
 * ❌ REMOVED: Public race announcements are no longer sent
 */
// async function sendPublicRaceAnnouncement - REMOVED

// Helper function to convert number to ordinal (1st, 2nd, 3rd, etc.)
function getOrdinal(number) {
  if (number >= 11 && number <= 13) {
    return `${number}th`;
  }

  switch (number % 10) {
    case 1:
      return `${number}st`;
    case 2:
      return `${number}nd`;
    case 3:
      return `${number}rd`;
    default:
      return `${number}th`;
  }
}

/**
 * 13. Send participant joined notification to race organizer
 * Triggered when: Someone joins a race
 */
async function sendParticipantJoinedNotification(organizerUserId, raceData, participantData) {
  try {
    console.log(`📤 Sending participant joined notification to organizer: ${organizerUserId}`);

    const notification = {
      title: 'Someone Joined Your Race! 🎉',
      body: `${participantData.name} joined "${raceData.title}"`,
    };

    const data = {
      type: 'RaceParticipantJoined',
      category: 'Race',
      icon: '🎉',
      raceId: raceData.id,
      raceName: raceData.title,
      participantId: participantData.id,
      participantName: participantData.name,
      joinedAt: new Date().toISOString(),
    };

    const result = await sendNotificationToUser(organizerUserId, notification, data);

    if (result.success) {
      console.log(`✅ Participant joined notification sent to ${organizerUserId}`);
    } else {
      console.error(`❌ Failed to send participant joined notification: ${result.error}`);
    }

    return result;
  } catch (error) {
    console.error(`❌ Error sending participant joined notification: ${error}`);
    return { success: false, error: error.message };
  }
}

/**
 * 14. Send overtaking notifications (to overtaker, overtaken, and others)
 * Triggered when: User improves rank by overtaking another participant
 * ✅ UPDATED: Only sends for PRIVATE races (raceTypeId === 2)
 */
async function sendOvertakingNotifications(raceId, raceTitle, overtakerUserId, overtakerName, newRank, oldRank, allParticipantsDocs, raceTypeId) {
  try {
    // ✅ FILTER: Only send overtaking notifications for PRIVATE races
    if (raceTypeId !== 2) {
      console.log(`⏭️ Skipping overtaking notifications for race ${raceId} - not a private race (raceTypeId: ${raceTypeId})`);
      return { success: true, message: 'Overtaking notifications only for private races' };
    }

    console.log(`📤 Sending overtaking notifications for PRIVATE race: ${raceId}`);

    // Find who was overtaken (person now at oldRank)
    let overtakenUserId = null;
    let overtakenName = 'a competitor';

    for (const doc of allParticipantsDocs) {
      const participantData = doc.data();
      if (participantData.rank === oldRank && doc.id !== overtakerUserId) {
        overtakenUserId = doc.id;
        overtakenName = participantData.userName || participantData.displayName || 'a competitor';
        break;
      }
    }

    const promises = [];

    // 1. Notify the overtaker (positive reinforcement)
    const overtakerNotification = {
      title: 'Great Overtake! 🚀',
      body: `Awesome! You overtook ${overtakenName} and moved to rank #${newRank}!`,
    };

    const overtakerData = {
      type: 'RaceOvertaking',
      category: 'Achievement',
      icon: '🚀',
      raceId: raceId,
      raceName: raceTitle,
      newRank: String(newRank),
      oldRank: String(oldRank),
      overtakenUser: overtakenName,
      timestamp: new Date().toISOString(),
    };

    promises.push(sendNotificationToUser(overtakerUserId, overtakerNotification, overtakerData));

    // 2. Notify the person who was overtaken (competitive pressure)
    if (overtakenUserId) {
      const overtakenNotification = {
        title: 'You Were Overtaken! ⚡',
        body: `${overtakerName} just overtook you! Speed up to reclaim your position!`,
      };

      const overtakenData = {
        type: 'RaceOvertaken',
        category: 'Race',
        icon: '⚡',
        raceId: raceId,
        raceName: raceTitle,
        overtakerName: overtakerName,
        yourNewRank: String(oldRank),
        timestamp: new Date().toISOString(),
      };

      promises.push(sendNotificationToUser(overtakenUserId, overtakenNotification, overtakenData));
    }

    // 3. Notify other participants (creates competitive atmosphere)
    const generalNotification = {
      title: 'Overtaking Alert! 🏃‍♂️',
      body: `${overtakerName} overtook ${overtakenName} and moved to rank #${newRank}!`,
    };

    const generalData = {
      type: 'RaceOvertakingGeneral',
      category: 'Race',
      icon: '🏃‍♂️',
      raceId: raceId,
      raceName: raceTitle,
      overtakingUser: overtakerName,
      overtakenUser: overtakenName,
      newRank: String(newRank),
      timestamp: new Date().toISOString(),
    };

    for (const doc of allParticipantsDocs) {
      const participantUserId = doc.id;
      const participantData = doc.data();

      // Skip overtaker and overtaken (they got specific notifications)
      if (participantUserId === overtakerUserId || participantUserId === overtakenUserId) {
        continue;
      }

      // Skip users who have already won (rank 1 and completed)
      if (participantData.rank === 1 && participantData.isCompleted === true) {
        console.log(`⏭️ Skipping winner ${participantUserId} - already won the race`);
        continue;
      }

      promises.push(sendNotificationToUser(participantUserId, generalNotification, generalData));
    }

    await Promise.all(promises);

    console.log(`✅ Overtaking notifications sent for ${allParticipantsDocs.length} participants`);

    return { success: true };
  } catch (error) {
    console.error(`❌ Error sending overtaking notifications: ${error}`);
    return { success: false, error: error.message };
  }
}

/**
 * 15. Send leader change notification to all participants
 * Triggered when: Someone takes 1st place
 * ✅ UPDATED: Only sends for PUBLIC races (raceTypeId === 3)
 */
async function sendLeaderChangeNotification(raceId, raceTitle, newLeaderUserId, newLeaderName, allParticipantsDocs, raceTypeId) {
  try {
    // ✅ FILTER: Only send leader change notifications for PUBLIC races
    if (raceTypeId !== 3) {
      console.log(`⏭️ Skipping leader change notifications for race ${raceId} - not a public race (raceTypeId: ${raceTypeId})`);
      return { success: true, message: 'Leader change notifications only for public races' };
    }

    console.log(`📤 Sending leader change notification for PUBLIC race: ${raceId}`);

    const notification = {
      title: 'New Leader! 👑',
      body: `${newLeaderName} took the lead in "${raceTitle}"!`,
    };

    const data = {
      type: 'RaceLeaderChange',
      category: 'Race',
      icon: '👑',
      raceId: raceId,
      raceName: raceTitle,
      newLeaderUserId: newLeaderUserId,
      newLeaderName: newLeaderName,
      timestamp: new Date().toISOString(),
    };

    const promises = [];

    // Send to all participants except the new leader
    for (const doc of allParticipantsDocs) {
      const participantUserId = doc.id;
      const participantData = doc.data();

      // Don't notify the new leader about themselves
      if (participantUserId === newLeaderUserId) {
        continue;
      }

      // Skip users who have already won (rank 1 and completed)
      if (participantData.rank === 1 && participantData.isCompleted === true) {
        console.log(`⏭️ Skipping winner ${participantUserId} - already won the race`);
        continue;
      }

      promises.push(sendNotificationToUser(participantUserId, notification, data));
    }

    await Promise.all(promises);

    console.log(`✅ Leader change notification sent to ${promises.length} participants`);

    return { success: true, notifiedCount: promises.length };
  } catch (error) {
    console.error(`❌ Error sending leader change notification: ${error}`);
    return { success: false, error: error.message };
  }
}

/**
 * 16. Send first finisher notification
 * Triggered when: First participant completes race (statusId 3 → 6)
 */
async function sendFirstFinisherNotification(userId, raceData) {
  try {
    console.log(`📤 Sending first finisher notification to user: ${userId}`);

    const notification = {
      title: '🏁 First to Finish!',
      body: `Amazing! You're the first to complete "${raceData.title}"!`,
    };

    const data = {
      type: 'RaceFirstFinisher',
      category: 'Achievement',
      icon: '🏁',
      raceId: raceData.id,
      raceName: raceData.title,
      finishedAt: new Date().toISOString(),
    };

    const result = await sendNotificationToUser(userId, notification, data);

    if (result.success) {
      console.log(`✅ First finisher notification sent to ${userId}`);
    } else {
      console.error(`❌ Failed to send first finisher notification: ${result.error}`);
    }

    return result;
  } catch (error) {
    console.error(`❌ Error sending first finisher notification: ${error}`);
    return { success: false, error: error.message };
  }
}

/**
 * 17. Send deadline alert notification to all active participants
 * Triggered when: First participant finishes and deadline is set (statusId → 6)
 * ✅ UPDATED: Only sends for PUBLIC races (raceTypeId === 3)
 */
async function sendDeadlineAlertNotification(raceId, raceData, firstFinisherName, deadlineMinutes, raceTypeId) {
  try {
    // ✅ FILTER: Only send deadline alerts for PUBLIC races
    if (raceTypeId !== 3) {
      console.log(`⏭️ Skipping deadline alert for race ${raceId} - not a public race (raceTypeId: ${raceTypeId})`);
      return { success: true, message: 'Deadline alerts only for public races' };
    }

    console.log(`📤 Sending deadline alert notifications for PUBLIC race: ${raceId}`);

    // Get all participants
    const participantsSnapshot = await db.collection('races').doc(raceId).collection('participants').get();

    if (participantsSnapshot.empty) {
      console.log(`ℹ️ No participants found for race ${raceId}`);
      return { success: true, message: 'No participants to notify' };
    }

    const notification = {
      title: '⏰ Deadline Approaching!',
      body: `${firstFinisherName} finished first! You have ${deadlineMinutes} minutes to complete the race!`,
    };

    const data = {
      type: 'RaceDeadlineAlert',
      category: 'Race',
      icon: '⏰',
      raceId: raceId,
      raceName: raceData.title,
      firstFinisherName: firstFinisherName,
      deadlineMinutes: String(deadlineMinutes),
      deadline: raceData.deadline, // ISO timestamp
      timestamp: new Date().toISOString(),
    };

    const promises = [];

    // Send to all participants who haven't finished yet
    participantsSnapshot.forEach(doc => {
      const participantUserId = doc.id;
      const participantData = doc.data();

      // Skip if participant already completed (isCompleted = true)
      if (participantData.isCompleted === true) {
        console.log(`⏭️ Skipping ${participantUserId} - already completed`);
        return;
      }

      // Skip the first finisher (they got a different notification)
      if (participantUserId === raceData.firstFinisherUserId) {
        return;
      }

      promises.push(sendNotificationToUser(participantUserId, notification, data));
    });

    const results = await Promise.all(promises);
    const successCount = results.filter(r => r.success).length;
    const failureCount = results.filter(r => !r.success).length;

    console.log(`✅ Deadline alert notifications sent: ${successCount} succeeded, ${failureCount} failed`);

    return { success: true, successCount, failureCount };
  } catch (error) {
    console.error(`❌ Error sending deadline alert notifications: ${error}`);
    return { success: false, error: error.message };
  }
}

/**
 * 18. Send race cancelled notification to all participants
 * Triggered when: Race is cancelled (statusId → 7)
 */
async function sendRaceCancelledNotification(raceId, raceTitle, cancellationReason) {
  try {
    console.log(`📤 Sending race cancelled notifications for race: ${raceId}`);

    // Get all participants
    const participantsSnapshot = await db.collection('races').doc(raceId).collection('participants').get();

    if (participantsSnapshot.empty) {
      console.log(`ℹ️ No participants found for race ${raceId}`);
      return { success: true, message: 'No participants to notify' };
    }

    const notification = {
      title: '❌ Race Cancelled',
      body: `The race "${raceTitle}" has been cancelled. ${cancellationReason ? `Reason: ${cancellationReason}` : ''}`,
    };

    const data = {
      type: 'RaceCancelled',
      category: 'Race',
      icon: '❌',
      raceId: raceId,
      raceName: raceTitle,
      cancellationReason: cancellationReason || 'Not specified',
      cancelledAt: new Date().toISOString(),
    };

    const promises = [];

    // Send to all participants
    participantsSnapshot.forEach(doc => {
      const participantUserId = doc.id;
      promises.push(sendNotificationToUser(participantUserId, notification, data));
    });

    const results = await Promise.all(promises);
    const successCount = results.filter(r => r.success).length;
    const failureCount = results.filter(r => !r.success).length;

    console.log(`✅ Race cancelled notifications sent: ${successCount} succeeded, ${failureCount} failed`);

    return { success: true, successCount, failureCount };
  } catch (error) {
    console.error(`❌ Error sending race cancelled notifications: ${error}`);
    return { success: false, error: error.message };
  }
}

/**
 * 19. Send personal milestone notification to participant who reached milestone
 * ❌ REMOVED: Milestone notifications are no longer sent
 */
// async function sendMilestonePersonalNotification - REMOVED

/**
 * 20. Send milestone alert notification to all other participants
 * ❌ REMOVED: Milestone notifications are no longer sent
 */
// async function sendMilestoneAlertNotification - REMOVED

/**
 * 21. Send proximity alert notification when opponent gets within 20m
 * Triggered when: Participant closes gap to within 20 meters of person ahead
 */
async function sendProximityAlertNotification(
  leadUserId,
  chaserUserId,
  chaserName,
  distanceGap,
  raceId,
  raceTitle
) {
  try {
    console.log(`📤 Sending proximity alert: ${chaserName} is ${distanceGap}m behind leader`);

    const notification = {
      title: '🔥 Opponent Approaching!',
      body: `${chaserName} is only ${distanceGap}m behind you! Speed up!`,
    };

    const data = {
      type: 'RaceProximityAlert',
      category: 'Race',
      icon: '🔥',
      raceId: raceId,
      raceName: raceTitle,
      chaserName: chaserName,
      chaserUserId: chaserUserId,
      distanceGap: String(distanceGap),
      timestamp: new Date().toISOString(),
    };

    const result = await sendNotificationToUser(leadUserId, notification, data);

    if (result.success) {
      console.log(`✅ Proximity alert sent: ${chaserName} is ${distanceGap}m behind`);
    } else {
      console.error(`❌ Failed to send proximity alert: ${result.error}`);
    }

    return result;
  } catch (error) {
    console.error(`❌ Error sending proximity alert notification: ${error}`);
    return { success: false, error: error.message };
  }
}

/**
 * 22. Send countdown timer notification to all active participants
 * Triggered when: Race deadline is approaching (5 minutes remaining)
 */
async function sendCountdownTimerNotification(raceId, raceData, minutesLeft) {
  try {
    console.log(`📤 Sending countdown timer notifications for race: ${raceId} (${minutesLeft} minutes left)`);

    // Get all participants
    const participantsSnapshot = await db.collection('races').doc(raceId).collection('participants').get();

    if (participantsSnapshot.empty) {
      console.log(`ℹ️ No participants found for race ${raceId}`);
      return { success: true, message: 'No participants to notify' };
    }

    const notification = {
      title: `⏰ ${minutesLeft} Minutes Left!`,
      body: `Time is running out in "${raceData.title}"! Sprint to the finish!`,
    };

    const data = {
      type: 'RaceCountdownTimer',
      category: 'Race',
      icon: '⏰',
      raceId: raceId,
      raceName: raceData.title,
      minutesLeft: String(minutesLeft),
      timestamp: new Date().toISOString(),
    };

    const promises = [];

    // Send to all participants who haven't finished yet
    participantsSnapshot.forEach(doc => {
      const participantUserId = doc.id;
      const participantData = doc.data();

      // Skip if participant already completed (isCompleted = true)
      if (participantData.isCompleted === true) {
        console.log(`⏭️ Skipping ${participantUserId} - already completed`);
        return;
      }

      promises.push(sendNotificationToUser(participantUserId, notification, data));
    });

    const results = await Promise.all(promises);
    const successCount = results.filter(r => r.success).length;
    const failureCount = results.filter(r => !r.success).length;

    console.log(`✅ Countdown timer (${minutesLeft}m) sent: ${successCount} succeeded, ${failureCount} failed`);

    return { success: true, successCount, failureCount };
  } catch (error) {
    console.error(`❌ Error sending countdown timer notifications: ${error}`);
    return { success: false, error: error.message };
  }
}

module.exports = {
  sendRaceInvitation,
  sendRaceStarted,
  sendRaceCompleted,
  // sendRaceCreationConfirmation, - REMOVED
  // sendRaceReminder, - REMOVED
  // sendJoinRequestAccepted, - REMOVED
  sendInviteAccepted,
  // sendJoinRequestDeclined, - REMOVED
  sendInviteDeclined,
  // sendNewJoinRequest, - REMOVED
  sendRaceWon,
  sendRaceStartedToAllParticipants,
  sendRaceCompletedToAllParticipants,
  // sendPublicRaceAnnouncement, - REMOVED
  sendParticipantJoinedNotification,
  sendOvertakingNotifications,
  sendLeaderChangeNotification,
  sendFirstFinisherNotification,
  sendDeadlineAlertNotification,
  sendRaceCancelledNotification,
  // sendMilestonePersonalNotification, - REMOVED
  // sendMilestoneAlertNotification, - REMOVED
  sendProximityAlertNotification,
  sendCountdownTimerNotification,
};
