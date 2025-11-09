/**
 * FCM Service - Core Firebase Cloud Messaging functionality
 *
 * This module handles all push notification sending via Firebase Admin SDK.
 * It provides a unified interface for sending notifications to iOS and Android devices.
 *
 * Usage:
 * const { sendNotification, sendBatchNotifications } = require('./fcmService');
 * await sendNotification(fcmToken, notification, data);
 */

const admin = require('firebase-admin');

// ===== NOTIFICATION THROTTLING =====
// Track last notification time per user per type to prevent spam
const notificationThrottleMap = new Map();

/**
 * Throttling Configuration
 * Defines cooldown periods (in seconds) for different notification types
 */
const THROTTLE_RULES = {
  'RaceProximityAlert': 60,       // Max 1 per minute per user
  'RaceOvertaking': 30,            // Max 1 per 30 seconds
  'RaceOvertaken': 30,             // Max 1 per 30 seconds
  'RaceLeaderChange': 120,         // Max 1 per 2 minutes
  'RaceCountdownTimer': 300,       // Max 1 per 5 minutes (should only fire once anyway)
  'RaceMilestoneAlert': 60,        // Max 1 per minute per milestone
  'RaceParticipantJoined': 30,     // Max 1 per 30 seconds
  // Milestones and important notifications have no throttle
  'RaceMilestonePersonal': 0,
  'RaceFirstFinisher': 0,
  'RaceWon': 0,
  'RaceCompleted': 0,
  'RaceBegin': 0,
  'InviteRace': 0,
};

/**
 * Check if a notification should be throttled (rate-limited)
 *
 * @param {string} userId - The user receiving the notification
 * @param {string} notificationType - The type of notification
 * @returns {boolean} True if notification should be throttled (blocked), false if allowed
 */
function shouldThrottleNotification(userId, notificationType) {
  // Get cooldown period for this notification type (default 0 = no throttle)
  const cooldownSeconds = THROTTLE_RULES[notificationType] || 0;

  // No throttle configured for this type
  if (cooldownSeconds === 0) {
    return false;
  }

  const key = `${userId}_${notificationType}`;
  const lastSent = notificationThrottleMap.get(key);
  const now = Date.now();

  // Check if notification was sent recently
  if (lastSent && (now - lastSent) < (cooldownSeconds * 1000)) {
    const secondsSinceLastSent = Math.floor((now - lastSent) / 1000);
    console.log(`⏸️ Throttling ${notificationType} for user ${userId} (sent ${secondsSinceLastSent}s ago, cooldown: ${cooldownSeconds}s)`);
    return true; // Throttle (block)
  }

  // Update last sent time
  notificationThrottleMap.set(key, now);
  return false; // Allow
}

/**
 * Clear throttle history for a specific user and notification type
 * Useful for testing or manual override
 */
function clearThrottle(userId, notificationType) {
  const key = `${userId}_${notificationType}`;
  notificationThrottleMap.delete(key);
  console.log(`🗑️ Cleared throttle for ${key}`);
}

/**
 * Clean up old throttle entries (older than 1 hour)
 * Should be called periodically to prevent memory leaks
 */
function cleanupThrottleMap() {
  const now = Date.now();
  const oneHourAgo = now - (60 * 60 * 1000);
  let removedCount = 0;

  notificationThrottleMap.forEach((timestamp, key) => {
    if (timestamp < oneHourAgo) {
      notificationThrottleMap.delete(key);
      removedCount++;
    }
  });

  if (removedCount > 0) {
    console.log(`🧹 Cleaned up ${removedCount} old throttle entries`);
  }
}

// Run cleanup every 30 minutes
setInterval(cleanupThrottleMap, 30 * 60 * 1000);

/**
 * Send a push notification to a single device
 *
 * @param {string} fcmToken - The FCM token of the device
 * @param {Object} notification - Notification payload { title, body, imageUrl? }
 * @param {Object} data - Custom data payload (all values must be strings)
 * @param {Object} options - Optional configuration { priority, sound, badge }
 * @returns {Promise<Object>} Result { success: boolean, messageId?: string, error?: string }
 */
async function sendNotification(fcmToken, notification, data = {}, options = {}) {
  try {
    // Validate FCM token
    if (!fcmToken || typeof fcmToken !== 'string' || fcmToken.trim() === '') {
      console.error('❌ Invalid FCM token provided');
      return { success: false, error: 'Invalid FCM token' };
    }

    // Validate notification
    if (!notification || !notification.title || !notification.body) {
      console.error('❌ Notification must have title and body');
      return { success: false, error: 'Invalid notification payload' };
    }

    // Ensure all data values are strings (FCM requirement)
    const stringData = {};
    Object.keys(data).forEach(key => {
      stringData[key] = String(data[key]);
    });

    // Build the FCM message
    const message = {
      token: fcmToken,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: stringData,
      // iOS-specific configuration (APNS)
      apns: {
        payload: {
          aps: {
            sound: options.sound || 'default',
            badge: options.badge !== undefined ? options.badge : 1,
            alert: {
              title: notification.title,
              body: notification.body,
            },
            // Show notification even when app is in foreground
            contentAvailable: true,
          },
        },
      },
      // Android-specific configuration
      android: {
        priority: options.priority || 'high',
        notification: {
          channelId: 'stepzsync_channel',
          sound: options.sound || 'default',
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
    };

    // Add image if provided
    if (notification.imageUrl) {
      message.notification.imageUrl = notification.imageUrl;
      message.apns.payload.aps.alert.imageUrl = notification.imageUrl;
      message.android.notification.imageUrl = notification.imageUrl;
    }

    // Send the message
    console.log(`📤 Sending notification to token: ${fcmToken.substring(0, 20)}...`);
    const response = await admin.messaging().send(message);

    console.log(`✅ Notification sent successfully: ${response}`);
    return { success: true, messageId: response };

  } catch (error) {
    console.error('❌ Error sending notification:', error);

    // Handle specific FCM errors
    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      console.error('🚫 Invalid or expired FCM token - should be removed from database');
      return { success: false, error: 'Invalid FCM token', shouldDelete: true };
    }

    return { success: false, error: error.message || 'Failed to send notification' };
  }
}

/**
 * Send notifications to multiple devices in batch
 *
 * @param {Array<Object>} notifications - Array of { fcmToken, notification, data }
 * @param {Object} options - Optional configuration
 * @returns {Promise<Object>} Result { successCount, failureCount, results }
 */
async function sendBatchNotifications(notifications, options = {}) {
  try {
    if (!Array.isArray(notifications) || notifications.length === 0) {
      console.error('❌ Invalid notifications array');
      return { successCount: 0, failureCount: 0, results: [] };
    }

    console.log(`📦 Sending batch notifications to ${notifications.length} devices...`);

    // Send all notifications in parallel
    const promises = notifications.map(({ fcmToken, notification, data }) =>
      sendNotification(fcmToken, notification, data, options)
    );

    const results = await Promise.all(promises);

    // Count successes and failures
    const successCount = results.filter(r => r.success).length;
    const failureCount = results.filter(r => !r.success).length;

    console.log(`✅ Batch complete: ${successCount} sent, ${failureCount} failed`);

    return { successCount, failureCount, results };

  } catch (error) {
    console.error('❌ Error sending batch notifications:', error);
    return { successCount: 0, failureCount: notifications.length, error: error.message };
  }
}

/**
 * Send notification to a user by userId (fetches FCM token from Firestore)
 *
 * @param {string} userId - The user's ID
 * @param {Object} notification - Notification payload { title, body }
 * @param {Object} data - Custom data payload
 * @param {Object} options - Optional configuration { priority, sound, badge, skipThrottle }
 * @returns {Promise<Object>} Result { success: boolean, messageId?: string, error?: string, throttled?: boolean }
 */
async function sendNotificationToUser(userId, notification, data = {}, options = {}) {
  try {
    // Check throttling (unless skipThrottle is true)
    const notificationType = data.type || 'Unknown';
    const skipThrottle = options.skipThrottle === true;

    if (!skipThrottle && shouldThrottleNotification(userId, notificationType)) {
      console.log(`⏸️ Notification throttled for user ${userId} (type: ${notificationType})`);
      return { success: false, error: 'Notification throttled', throttled: true };
    }

    // Get user's FCM token from Firestore
    const userDoc = await admin.firestore().collection('user_profiles').doc(userId).get();

    if (!userDoc.exists) {
      console.error(`❌ User ${userId} not found`);
      return { success: false, error: 'User not found' };
    }

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (!fcmToken || fcmToken.trim() === '') {
      console.error(`❌ User ${userId} has no FCM token`);
      return { success: false, error: 'User has no FCM token' };
    }

    // Send notification
    const result = await sendNotification(fcmToken, notification, data, options);

    // If token is invalid, remove it from Firestore
    if (result.shouldDelete) {
      console.log(`🗑️ Removing invalid FCM token for user ${userId}`);
      await admin.firestore().collection('user_profiles').doc(userId).update({
        fcmToken: admin.firestore.FieldValue.delete(),
        fcmTokenUpdatedAt: admin.firestore.FieldValue.delete(),
      });
    }

    // ✅ CRITICAL FIX: Store notification in Firestore for in-app notification list
    // This allows users to see notifications even if they dismissed the push notification
    if (result.success) {
      try {
        const notificationDoc = {
          userId: userId,
          type: data.type || 'Unknown',
          category: data.category || 'General',
          icon: data.icon || '🔔',
          title: notification.title,
          message: notification.body,
          data: data, // Store all data for routing/actions
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        await admin.firestore().collection('user_notifications').add(notificationDoc);
        console.log(`📝 Stored notification in Firestore for user ${userId}`);
      } catch (storeError) {
        console.error(`⚠️ Failed to store notification in Firestore: ${storeError}`);
        // Don't fail the whole operation if storage fails
      }
    }

    return result;

  } catch (error) {
    console.error(`❌ Error sending notification to user ${userId}:`, error);
    return { success: false, error: error.message };
  }
}

/**
 * Send notification to multiple users by userIds
 *
 * @param {Array<string>} userIds - Array of user IDs
 * @param {Object} notification - Notification payload { title, body }
 * @param {Object} data - Custom data payload
 * @param {Object} options - Optional configuration
 * @returns {Promise<Object>} Result { successCount, failureCount, results }
 */
async function sendNotificationToUsers(userIds, notification, data = {}, options = {}) {
  try {
    if (!Array.isArray(userIds) || userIds.length === 0) {
      console.error('❌ Invalid userIds array');
      return { successCount: 0, failureCount: 0, results: [] };
    }

    console.log(`📦 Sending notifications to ${userIds.length} users...`);

    // Fetch all user FCM tokens in parallel
    const userPromises = userIds.map(userId =>
      admin.firestore().collection('user_profiles').doc(userId).get()
    );

    const userDocs = await Promise.all(userPromises);

    // Build notifications array with valid tokens
    const notifications = [];
    const invalidUsers = [];

    userDocs.forEach((doc, index) => {
      if (!doc.exists) {
        console.error(`❌ User ${userIds[index]} not found`);
        invalidUsers.push({ userId: userIds[index], error: 'User not found' });
        return;
      }

      const userData = doc.data();
      const fcmToken = userData.fcmToken;

      if (!fcmToken || fcmToken.trim() === '') {
        console.error(`❌ User ${userIds[index]} has no FCM token`);
        invalidUsers.push({ userId: userIds[index], error: 'No FCM token' });
        return;
      }

      notifications.push({ fcmToken, notification, data });
    });

    // Send batch notifications
    const batchResult = await sendBatchNotifications(notifications, options);

    console.log(`✅ Sent to ${batchResult.successCount}/${userIds.length} users`);

    return {
      successCount: batchResult.successCount,
      failureCount: batchResult.failureCount + invalidUsers.length,
      results: batchResult.results,
      invalidUsers,
    };

  } catch (error) {
    console.error('❌ Error sending notifications to users:', error);
    return { successCount: 0, failureCount: userIds.length, error: error.message };
  }
}

module.exports = {
  sendNotification,
  sendBatchNotifications,
  sendNotificationToUser,
  sendNotificationToUsers,
  shouldThrottleNotification,
  clearThrottle,
  cleanupThrottleMap,
};
