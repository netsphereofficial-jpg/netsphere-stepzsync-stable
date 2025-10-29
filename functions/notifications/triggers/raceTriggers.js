/**
 * Race Notification Triggers
 *
 * Firestore triggers that automatically send notifications when race events occur.
 *
 * Triggers:
 * 1. onRaceInviteCreated - When user is invited to a race
 * 2. onRaceStatusChanged - When race starts or completes
 * 3. onRaceInviteAccepted - When user accepts race invite
 * 4. onRaceInviteDeclined - When user declines race invite
 * 5. onRaceCreated - When new race is created (confirmation to creator)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const db = admin.firestore();

const {
  sendRaceInvitation,
  sendRaceStarted,
  sendRaceStartedToAllParticipants,
  sendRaceCompletedToAllParticipants,
  sendRaceCreationConfirmation,
  sendJoinRequestAccepted,
  sendInviteAccepted,
  sendJoinRequestDeclined,
  sendInviteDeclined,
  sendNewJoinRequest,
  sendFirstFinisherNotification,
  sendDeadlineAlertNotification,
  sendRaceCancelledNotification,
} = require('../senders/raceNotifications');

/**
 * TRIGGER 1: Race Invite Created
 *
 * Triggers when: Document created in race_invites collection
 * Sends: Race invitation notification to invited user
 */
exports.onRaceInviteCreated = functions.firestore
  .document('race_invites/{inviteId}')
  .onCreate(async (snap, context) => {
    try {
      const inviteData = snap.data();
      const inviteId = context.params.inviteId;

      console.log(`🎯 Trigger: Race invite created ${inviteId}`);

      // Only process 'received' type invites to avoid duplicate notifications
      // (Both 'sent' and 'received' invites are created, but we only need to notify once)
      if (inviteData.type !== 'received') {
        console.log(`⏭️ Skipping 'sent' type invite ${inviteId} to avoid duplicate notification`);
        return null;
      }

      // Extract invite details
      const toUserId = inviteData.toUserId;
      const fromUserId = inviteData.fromUserId;
      const raceId = inviteData.raceId;
      const isJoinRequest = inviteData.isJoinRequest === true;

      if (!toUserId || !fromUserId || !raceId) {
        console.error(`❌ Missing required fields in invite ${inviteId}`);
        return null;
      }

      // Fetch race details
      const raceDoc = await db.collection('races').doc(raceId).get();
      if (!raceDoc.exists) {
        console.error(`❌ Race ${raceId} not found for invite ${inviteId}`);
        return null;
      }

      const raceDataRaw = raceDoc.data();
      const raceData = {
        id: raceId,
        title: raceDataRaw.title || 'Untitled Race',
        distance: raceDataRaw.totalDistance,
        startTime: raceDataRaw.scheduleTime,
        location: raceDataRaw.startAddress,
      };

      // Fetch user details (fromUser)
      const fromUserDoc = await db.collection('user_profiles').doc(fromUserId).get();
      if (!fromUserDoc.exists) {
        console.error(`❌ User ${fromUserId} not found for invite ${inviteId}`);
        return null;
      }

      const fromUserData = fromUserDoc.data();
      const fromUserInfo = {
        id: fromUserId,
        name: fromUserData.fullName || fromUserData.displayName || 'Unknown User',
      };

      // Determine notification type based on isJoinRequest flag
      if (isJoinRequest) {
        // This is a join request (user wants to join race)
        // Send notification to race organizer (toUserId)
        console.log(`📩 Join request: ${fromUserInfo.name} wants to join "${raceData.title}"`);
        await sendNewJoinRequest(toUserId, raceData, fromUserInfo);
      } else {
        // This is a race invitation (organizer invites user)
        // Send notification to invited user (toUserId)
        console.log(`📨 Race invitation: ${fromUserInfo.name} invited someone to "${raceData.title}"`);
        await sendRaceInvitation(toUserId, raceData, fromUserInfo);
      }

      return null;
    } catch (error) {
      console.error(`❌ Error in onRaceInviteCreated: ${error}`);
      return null;
    }
  });

/**
 * TRIGGER 2: Race Status Changed
 *
 * Triggers when: Race document is updated (statusId changes)
 * Sends: Race started (status 3) or race completed (status 4) notifications
 */
exports.onRaceStatusChanged = functions.firestore
  .document('races/{raceId}')
  .onUpdate(async (change, context) => {
    try {
      const raceId = context.params.raceId;
      const beforeData = change.before.data();
      const afterData = change.after.data();

      const oldStatus = beforeData.statusId;
      const newStatus = afterData.statusId;

      // Only process if status actually changed
      if (oldStatus === newStatus) {
        return null;
      }

      console.log(`🎯 Trigger: Race status changed ${raceId}: ${oldStatus} → ${newStatus}`);

      // Race started (statusId changed to 3 = ACTIVE)
      if (newStatus === 3 && oldStatus !== 3) {
        console.log(`🚀 Race "${afterData.title}" started (ID: ${raceId})`);
        await sendRaceStartedToAllParticipants(raceId);
        return null;
      }

      // Race completed (statusId changed to 4 = COMPLETED)
      if (newStatus === 4 && oldStatus !== 4) {
        console.log(`🏁 Race "${afterData.title}" completed (ID: ${raceId})`);
        await sendRaceCompletedToAllParticipants(raceId);
        return null;
      }

      // Race ending - first finisher crossed finish line (statusId changed to 6 = ENDING)
      if (newStatus === 6 && oldStatus !== 6) {
        console.log(`⏰ Race "${afterData.title}" ending - first finisher detected (ID: ${raceId})`);

        const firstFinisherUserId = afterData.firstFinisherUserId;
        const raceDeadline = afterData.raceDeadline;

        if (!firstFinisherUserId) {
          console.error(`❌ No firstFinisherUserId found for race ${raceId}`);
          return null;
        }

        // Get first finisher's details
        const firstFinisherDoc = await db.collection('races').doc(raceId)
          .collection('participants').doc(firstFinisherUserId).get();

        if (!firstFinisherDoc.exists) {
          console.error(`❌ First finisher ${firstFinisherUserId} not found in participants`);
          return null;
        }

        const firstFinisherData = firstFinisherDoc.data();
        const firstFinisherName = firstFinisherData.userName || firstFinisherData.displayName || 'Someone';

        // Calculate deadline minutes (time between now and deadline)
        let deadlineMinutes = 30; // Default 30 minutes
        if (raceDeadline) {
          const deadline = raceDeadline.toDate ? raceDeadline.toDate() : new Date(raceDeadline);
          const now = new Date();
          deadlineMinutes = Math.ceil((deadline - now) / 60000); // Convert ms to minutes
        }

        const raceData = {
          id: raceId,
          title: afterData.title || 'Untitled Race',
          deadline: raceDeadline?.toDate ? raceDeadline.toDate().toISOString() : new Date(Date.now() + deadlineMinutes * 60000).toISOString(),
          firstFinisherUserId: firstFinisherUserId,
        };

        // Send first finisher notification
        await sendFirstFinisherNotification(firstFinisherUserId, raceData);

        // Send deadline alert to all other active participants
        await sendDeadlineAlertNotification(raceId, raceData, firstFinisherName, deadlineMinutes);

        return null;
      }

      // Race cancelled (statusId changed to 7 = CANCELLED)
      if (newStatus === 7 && oldStatus !== 7) {
        console.log(`❌ Race "${afterData.title}" cancelled (ID: ${raceId})`);

        const cancellationReason = afterData.cancellationReason || 'Not specified';

        await sendRaceCancelledNotification(raceId, afterData.title || 'Untitled Race', cancellationReason);

        return null;
      }

      return null;
    } catch (error) {
      console.error(`❌ Error in onRaceStatusChanged: ${error}`);
      return null;
    }
  });

/**
 * TRIGGER 3: Race Invite Accepted
 *
 * Triggers when: race_invites document is updated with status = 'accepted'
 * Sends: Acceptance notification to inviter/organizer
 */
exports.onRaceInviteAccepted = functions.firestore
  .document('race_invites/{inviteId}')
  .onUpdate(async (change, context) => {
    try {
      const inviteId = context.params.inviteId;
      const beforeData = change.before.data();
      const afterData = change.after.data();

      // Only process if status changed to 'accepted'
      if (beforeData.status === afterData.status || afterData.status !== 'accepted') {
        return null;
      }

      // Only process 'received' type invites to avoid duplicate notifications
      // (Both 'sent' and 'received' invites are updated, but we only need to notify once)
      if (afterData.type !== 'received') {
        console.log(`⏭️ Skipping 'sent' type invite ${inviteId} to avoid duplicate notification`);
        return null;
      }

      console.log(`🎯 Trigger: Race invite accepted ${inviteId}`);

      const fromUserId = afterData.fromUserId; // Original inviter/organizer
      const toUserId = afterData.toUserId; // Person who accepted
      const raceId = afterData.raceId;
      const isJoinRequest = afterData.isJoinRequest === true;

      if (!fromUserId || !toUserId || !raceId) {
        console.error(`❌ Missing required fields in invite ${inviteId}`);
        return null;
      }

      // Fetch race details
      const raceDoc = await db.collection('races').doc(raceId).get();
      if (!raceDoc.exists) {
        console.error(`❌ Race ${raceId} not found`);
        return null;
      }

      const raceDataRaw = raceDoc.data();
      const raceData = {
        id: raceId,
        title: raceDataRaw.title || 'Untitled Race',
      };

      // Fetch accepter details (toUserId - person who accepted)
      const accepterDoc = await db.collection('user_profiles').doc(toUserId).get();
      if (!accepterDoc.exists) {
        console.error(`❌ User ${toUserId} not found`);
        return null;
      }

      const accepterData = accepterDoc.data();
      const accepterInfo = {
        id: toUserId,
        name: accepterData.fullName || accepterData.displayName || 'Unknown User',
      };

      // Determine notification type
      if (isJoinRequest) {
        // Join request was accepted - notify requester
        console.log(`✅ Join request accepted for "${raceData.title}"`);
        await sendJoinRequestAccepted(toUserId, raceData, { id: fromUserId, name: afterData.fromUserName || 'Organizer' });
      } else {
        // Race invitation was accepted - notify inviter
        console.log(`✅ Race invitation accepted for "${raceData.title}"`);
        await sendInviteAccepted(fromUserId, raceData, accepterInfo);
      }

      return null;
    } catch (error) {
      console.error(`❌ Error in onRaceInviteAccepted: ${error}`);
      return null;
    }
  });

/**
 * TRIGGER 4: Race Invite Declined
 *
 * Triggers when: race_invites document is updated with status = 'declined'
 * Sends: Decline notification to inviter/organizer
 */
exports.onRaceInviteDeclined = functions.firestore
  .document('race_invites/{inviteId}')
  .onUpdate(async (change, context) => {
    try {
      const inviteId = context.params.inviteId;
      const beforeData = change.before.data();
      const afterData = change.after.data();

      // Only process if status changed to 'declined'
      if (beforeData.status === afterData.status || afterData.status !== 'declined') {
        return null;
      }

      // Only process 'received' type invites to avoid duplicate notifications
      // (Both 'sent' and 'received' invites are updated, but we only need to notify once)
      if (afterData.type !== 'received') {
        console.log(`⏭️ Skipping 'sent' type invite ${inviteId} to avoid duplicate notification`);
        return null;
      }

      console.log(`🎯 Trigger: Race invite declined ${inviteId}`);

      const fromUserId = afterData.fromUserId; // Original inviter/organizer
      const toUserId = afterData.toUserId; // Person who declined
      const raceId = afterData.raceId;
      const isJoinRequest = afterData.isJoinRequest === true;

      if (!fromUserId || !toUserId || !raceId) {
        console.error(`❌ Missing required fields in invite ${inviteId}`);
        return null;
      }

      // Fetch race details
      const raceDoc = await db.collection('races').doc(raceId).get();
      if (!raceDoc.exists) {
        console.error(`❌ Race ${raceId} not found`);
        return null;
      }

      const raceDataRaw = raceDoc.data();
      const raceData = {
        id: raceId,
        title: raceDataRaw.title || 'Untitled Race',
      };

      // Fetch decliner details (toUserId - person who declined)
      const declinerDoc = await db.collection('user_profiles').doc(toUserId).get();
      if (!declinerDoc.exists) {
        console.error(`❌ User ${toUserId} not found`);
        return null;
      }

      const declinerData = declinerDoc.data();
      const declinerInfo = {
        id: toUserId,
        name: declinerData.fullName || declinerData.displayName || 'Unknown User',
      };

      // Determine notification type
      if (isJoinRequest) {
        // Join request was declined - notify requester
        console.log(`❌ Join request declined for "${raceData.title}"`);
        await sendJoinRequestDeclined(toUserId, raceData, { id: fromUserId, name: afterData.fromUserName || 'Organizer' });
      } else {
        // Race invitation was declined - notify inviter
        console.log(`❌ Race invitation declined for "${raceData.title}"`);
        await sendInviteDeclined(fromUserId, raceData, declinerInfo);
      }

      return null;
    } catch (error) {
      console.error(`❌ Error in onRaceInviteDeclined: ${error}`);
      return null;
    }
  });

/**
 * TRIGGER 5: Race Created
 *
 * Triggers when: New race document is created
 * Sends:
 *   - Race creation confirmation to creator
 *   - Public race announcement to ALL users (if raceTypeId == 3)
 *
 * Race Type IDs:
 *   1 = Solo
 *   2 = Private
 *   3 = Public  ← Broadcasts to all users
 *   4 = Marathon
 *   5 = Quick Race
 */
exports.onRaceCreated = functions.firestore
  .document('races/{raceId}')
  .onCreate(async (snap, context) => {
    try {
      const raceId = context.params.raceId;
      const raceData = snap.data();

      console.log(`🎯 Trigger: Race created ${raceId}`);

      const creatorUserId = raceData.createdBy;
      const raceTypeId = raceData.raceTypeId || 3; // Default to Public if not specified
      const isPublicRace = raceTypeId === 3;

      // Prepare race data for notification
      const raceInfo = {
        id: raceId,
        title: raceData.title || 'Untitled Race',
        raceType: raceData.raceType,
        raceTypeId: raceTypeId,
        distance: raceData.totalDistance,
        scheduledTime: raceData.scheduleTime,
        participantCount: raceData.totalParticipants || 0,
        startAddress: raceData.startAddress,
        organizerName: raceData.orgName || 'Unknown',
      };

      // 1. Send confirmation to creator
      if (creatorUserId) {
        console.log(`🎉 Sending race creation confirmation to ${creatorUserId}`);
        await sendRaceCreationConfirmation(creatorUserId, raceInfo);
      }

      // 2. If public race, broadcast to ALL users
      if (isPublicRace) {
        console.log(`📢 Broadcasting public race announcement to all users...`);
        const { sendPublicRaceAnnouncement } = require('../senders/raceNotifications');
        await sendPublicRaceAnnouncement(raceInfo, creatorUserId);
      }

      return null;
    } catch (error) {
      console.error(`❌ Error in onRaceCreated: ${error}`);
      return null;
    }
  });
