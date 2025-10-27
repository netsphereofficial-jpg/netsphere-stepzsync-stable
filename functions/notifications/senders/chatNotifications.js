/**
 * Chat Notification Senders
 *
 * Functions to send chat-related notifications via FCM.
 *
 * Notification Types:
 * 1. Direct Chat Message - 1-on-1 chat notifications
 * 2. Race Chat Message - Group race chat notifications
 */

const { sendNotificationToUser } = require('../core/fcmService');

/**
 * Send direct chat message notification
 *
 * @param {string} userId - Receiver user ID
 * @param {string} senderName - Name of message sender
 * @param {string} messageText - Message content (truncated if needed)
 * @param {string} chatRoomId - Chat room ID for navigation
 */
async function sendChatMessageNotification(userId, senderName, messageText, chatRoomId) {
  try {
    // Truncate long messages for notification
    let displayMessage = messageText;
    if (messageText.length > 100) {
      displayMessage = messageText.substring(0, 97) + '...';
    }

    const notification = {
      title: `New Message from ${senderName} 💬`,
      body: displayMessage,
    };

    const data = {
      type: 'ChatMessage',
      category: 'Chat',
      senderName: senderName,
      chatRoomId: chatRoomId,
      clickAction: 'OPEN_CHAT',
    };

    console.log(`📨 Sending chat notification to ${userId} from ${senderName}`);
    await sendNotificationToUser(userId, notification, data);
    console.log(`✅ Chat notification sent successfully`);
  } catch (error) {
    console.error(`❌ Error sending chat message notification: ${error}`);
  }
}

/**
 * Send race chat message notification to multiple participants
 *
 * @param {string} userId - Receiver user ID
 * @param {string} senderName - Name of message sender
 * @param {string} messageText - Message content (truncated if needed)
 * @param {string} raceTitle - Race title
 * @param {string} raceId - Race ID for navigation
 * @param {string} raceChatId - Race chat ID
 */
async function sendRaceChatNotification(userId, senderName, messageText, raceTitle, raceId, raceChatId) {
  try {
    // Truncate long messages for notification
    let displayMessage = messageText;
    if (messageText.length > 80) {
      displayMessage = messageText.substring(0, 77) + '...';
    }

    const notification = {
      title: `${raceTitle} 🏃`,
      body: `${senderName}: ${displayMessage}`,
    };

    const data = {
      type: 'RaceChatMessage',
      category: 'RaceChat',
      senderName: senderName,
      raceTitle: raceTitle,
      raceId: raceId,
      raceChatId: raceChatId,
      clickAction: 'OPEN_RACE_CHAT',
    };

    console.log(`📨 Sending race chat notification to ${userId} from ${senderName} in "${raceTitle}"`);
    await sendNotificationToUser(userId, notification, data);
    console.log(`✅ Race chat notification sent successfully`);
  } catch (error) {
    console.error(`❌ Error sending race chat notification: ${error}`);
  }
}

module.exports = {
  sendChatMessageNotification,
  sendRaceChatNotification,
};
