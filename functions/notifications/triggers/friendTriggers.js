/**
 * Friend Notification Triggers
 *
 * Firestore triggers that automatically send notifications when friend events occur.
 *
 * Triggers:
 * 1. onFriendRequestCreated - When user sends a friend request
 * 2. onFriendRequestAccepted - When user accepts friend request
 * 3. onFriendRequestDeclined - When user declines friend request
 * 4. onFriendRemoved - When user is removed from friends list
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const db = admin.firestore();

const {
  sendFriendRequest,
  sendFriendAccepted,
  sendFriendRemoved,
  sendFriendDeclined,
} = require('../senders/socialNotifications');

/**
 * TRIGGER 1: Friend Request Created
 *
 * Triggers when: Document created in friend_requests collection
 * Sends: Friend request notification to receiver
 */
exports.onFriendRequestCreated = functions.firestore
  .document('friend_requests/{requestId}')
  .onCreate(async (snap, context) => {
    try {
      const requestData = snap.data();
      const requestId = context.params.requestId;

      console.log(`🎯 Trigger: Friend request created ${requestId}`);

      const senderId = requestData.senderId;
      const receiverId = requestData.receiverId;

      if (!senderId || !receiverId) {
        console.error(`❌ Missing required fields in friend request ${requestId}`);
        return null;
      }

      // Fetch sender details
      const senderDoc = await db.collection('user_profiles').doc(senderId).get();
      if (!senderDoc.exists) {
        console.error(`❌ User ${senderId} not found`);
        return null;
      }

      const senderData = senderDoc.data();
      const senderInfo = {
        id: senderId,
        name: senderData.fullName || senderData.displayName || 'Unknown User',
        profilePic: senderData.profilePicture || senderData.profilePictureUrl || null,
      };

      // Calculate mutual friends (optional)
      // TODO: Implement mutual friends calculation if needed
      const mutualFriends = null;

      console.log(`📨 Friend request: ${senderInfo.name} → ${receiverId}`);
      await sendFriendRequest(receiverId, senderInfo, mutualFriends);

      return null;
    } catch (error) {
      console.error(`❌ Error in onFriendRequestCreated: ${error}`);
      return null;
    }
  });

/**
 * TRIGGER 2: Friend Request Accepted
 *
 * Triggers when: friend_requests document is updated with status = 'accepted'
 * Sends: Acceptance notification to original requester
 */
exports.onFriendRequestAccepted = functions.firestore
  .document('friend_requests/{requestId}')
  .onUpdate(async (change, context) => {
    try {
      const requestId = context.params.requestId;
      const beforeData = change.before.data();
      const afterData = change.after.data();

      // Only process if status changed to 'accepted'
      if (beforeData.status === afterData.status || afterData.status !== 'accepted') {
        return null;
      }

      console.log(`🎯 Trigger: Friend request accepted ${requestId}`);

      const senderId = afterData.senderId; // Original requester
      const receiverId = afterData.receiverId; // Person who accepted

      if (!senderId || !receiverId) {
        console.error(`❌ Missing required fields in friend request ${requestId}`);
        return null;
      }

      // Fetch accepter details
      const accepterDoc = await db.collection('user_profiles').doc(receiverId).get();
      if (!accepterDoc.exists) {
        console.error(`❌ User ${receiverId} not found`);
        return null;
      }

      const accepterData = accepterDoc.data();
      const accepterInfo = {
        id: receiverId,
        name: accepterData.fullName || accepterData.displayName || 'Unknown User',
        profilePic: accepterData.profilePicture || accepterData.profilePictureUrl || null,
      };

      console.log(`✅ Friend request accepted: ${accepterInfo.name} accepted request from ${senderId}`);
      await sendFriendAccepted(senderId, accepterInfo);

      return null;
    } catch (error) {
      console.error(`❌ Error in onFriendRequestAccepted: ${error}`);
      return null;
    }
  });

/**
 * TRIGGER 3: Friend Request Declined
 *
 * Triggers when: friend_requests document is updated with status = 'declined'
 * Sends: Decline notification to original requester
 */
exports.onFriendRequestDeclined = functions.firestore
  .document('friend_requests/{requestId}')
  .onUpdate(async (change, context) => {
    try {
      const requestId = context.params.requestId;
      const beforeData = change.before.data();
      const afterData = change.after.data();

      // Only process if status changed to 'declined'
      if (beforeData.status === afterData.status || afterData.status !== 'declined') {
        return null;
      }

      console.log(`🎯 Trigger: Friend request declined ${requestId}`);

      const senderId = afterData.senderId; // Original requester
      const receiverId = afterData.receiverId; // Person who declined

      if (!senderId || !receiverId) {
        console.error(`❌ Missing required fields in friend request ${requestId}`);
        return null;
      }

      // Fetch decliner details
      const declinerDoc = await db.collection('user_profiles').doc(receiverId).get();
      if (!declinerDoc.exists) {
        console.error(`❌ User ${receiverId} not found`);
        return null;
      }

      const declinerData = declinerDoc.data();
      const declinerInfo = {
        id: receiverId,
        name: declinerData.fullName || declinerData.displayName || 'Unknown User',
      };

      console.log(`❌ Friend request declined: ${declinerInfo.name} declined request from ${senderId}`);
      await sendFriendDeclined(senderId, declinerInfo);

      return null;
    } catch (error) {
      console.error(`❌ Error in onFriendRequestDeclined: ${error}`);
      return null;
    }
  });

/**
 * TRIGGER 4: Friend Removed
 *
 * Triggers when: Document deleted from friends collection
 * Sends: Friend removed notification to removed friend
 *
 * NOTE: This trigger watches for friend removal in the friends collection.
 * Since friendships are bidirectional (two docs), we only send notification
 * to the friendId user when their friendship doc is deleted.
 */
exports.onFriendRemoved = functions.firestore
  .document('friends/{friendshipId}')
  .onDelete(async (snap, context) => {
    try {
      const friendshipId = context.params.friendshipId;
      const friendshipData = snap.data();

      const userId = friendshipData.userId; // User who owns this friendship doc
      const friendId = friendshipData.friendId; // Friend who was removed

      console.log(`🎯 Trigger: Friend removed - ${userId} removed ${friendId}`);

      if (!userId || !friendId) {
        console.error(`❌ Missing required fields in friend removal`);
        return null;
      }

      // Fetch remover details (the person who owns this friendship doc)
      const removerDoc = await db.collection('user_profiles').doc(userId).get();
      if (!removerDoc.exists) {
        console.error(`❌ User ${userId} not found`);
        return null;
      }

      const removerData = removerDoc.data();
      const removerInfo = {
        id: userId,
        name: removerData.fullName || removerData.displayName || 'Unknown User',
      };

      console.log(`💔 Friend removed: ${removerInfo.name} removed ${friendId} from friends`);
      await sendFriendRemoved(friendId, removerInfo);

      return null;
    } catch (error) {
      console.error(`❌ Error in onFriendRemoved: ${error}`);
      return null;
    }
  });
