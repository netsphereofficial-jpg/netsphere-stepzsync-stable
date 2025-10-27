/**
 * Social Notification Senders
 *
 * This module contains all friend/social-related notification sending functions.
 * These functions are called by Firestore triggers and send push notifications
 * to users via Firebase Cloud Messaging.
 *
 * Social Notification Types:
 * 1. Friend Request - New friend request received
 * 2. Friend Accepted - Friend request was accepted
 * 3. Friend Removed - Removed from friends list
 * 4. Friend Declined - Friend request was declined
 */

const { sendNotificationToUser } = require('../core/fcmService');
const admin = require('firebase-admin');
const db = admin.firestore();

/**
 * 1. Send friend request notification
 * Triggered when: User sends a friend request
 */
async function sendFriendRequest(userId, fromUserData, mutualFriends = null) {
  try {
    console.log(`📤 Sending friend request notification to user: ${userId}`);

    const notification = {
      title: 'New Friend Request 👥',
      body: `${fromUserData.name} wants to be your friend!`,
    };

    const data = {
      type: 'FriendRequest',
      category: 'Social',
      icon: '👥',
      userId: fromUserData.id,
      userName: fromUserData.name,
      ...(fromUserData.profilePic && { thumbnail: fromUserData.profilePic }),
      ...(mutualFriends !== null && { mutualFriends: String(mutualFriends) }),
      requestSentAt: new Date().toISOString(),
    };

    const result = await sendNotificationToUser(userId, notification, data);

    if (result.success) {
      console.log(`✅ Friend request notification sent to ${userId}`);
    } else {
      console.error(`❌ Failed to send friend request notification: ${result.error}`);
    }

    return result;
  } catch (error) {
    console.error(`❌ Error sending friend request notification: ${error}`);
    return { success: false, error: error.message };
  }
}

/**
 * 2. Send friend request accepted notification
 * Triggered when: User accepts a friend request
 */
async function sendFriendAccepted(userId, friendData) {
  try {
    console.log(`📤 Sending friend accepted notification to user: ${userId}`);

    const notification = {
      title: 'Friend Request Accepted! 🎉',
      body: `${friendData.name} accepted your friend request!`,
    };

    const data = {
      type: 'FriendAccepted',
      category: 'Social',
      icon: '🎉',
      userId: friendData.id,
      userName: friendData.name,
      ...(friendData.profilePic && { thumbnail: friendData.profilePic }),
      acceptedAt: new Date().toISOString(),
    };

    const result = await sendNotificationToUser(userId, notification, data);

    if (result.success) {
      console.log(`✅ Friend accepted notification sent to ${userId}`);
    } else {
      console.error(`❌ Failed to send friend accepted notification: ${result.error}`);
    }

    return result;
  } catch (error) {
    console.error(`❌ Error sending friend accepted notification: ${error}`);
    return { success: false, error: error.message };
  }
}

/**
 * 3. Send friend removed notification
 * Triggered when: User is removed from friends list
 */
async function sendFriendRemoved(userId, removerData) {
  try {
    console.log(`📤 Sending friend removed notification to user: ${userId}`);

    const notification = {
      title: 'Friendship Ended 💔',
      body: `${removerData.name} removed you from their friends list.`,
    };

    const data = {
      type: 'FriendRemoved',
      category: 'Social',
      icon: '💔',
      userId: removerData.id,
      userName: removerData.name,
      removedAt: new Date().toISOString(),
    };

    const result = await sendNotificationToUser(userId, notification, data);

    if (result.success) {
      console.log(`✅ Friend removed notification sent to ${userId}`);
    } else {
      console.error(`❌ Failed to send friend removed notification: ${result.error}`);
    }

    return result;
  } catch (error) {
    console.error(`❌ Error sending friend removed notification: ${error}`);
    return { success: false, error: error.message };
  }
}

/**
 * 4. Send friend request declined notification
 * Triggered when: User declines a friend request
 */
async function sendFriendDeclined(userId, declinerData) {
  try {
    console.log(`📤 Sending friend declined notification to user: ${userId}`);

    const notification = {
      title: 'Friend Request Declined 😔',
      body: `${declinerData.name} declined your friend request.`,
    };

    const data = {
      type: 'FriendDeclined',
      category: 'Social',
      icon: '😔',
      userId: declinerData.id,
      userName: declinerData.name,
      declinedAt: new Date().toISOString(),
    };

    const result = await sendNotificationToUser(userId, notification, data);

    if (result.success) {
      console.log(`✅ Friend declined notification sent to ${userId}`);
    } else {
      console.error(`❌ Failed to send friend declined notification: ${result.error}`);
    }

    return result;
  } catch (error) {
    console.error(`❌ Error sending friend declined notification: ${error}`);
    return { success: false, error: error.message };
  }
}

module.exports = {
  sendFriendRequest,
  sendFriendAccepted,
  sendFriendRemoved,
  sendFriendDeclined,
};
