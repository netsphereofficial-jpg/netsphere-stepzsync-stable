/**
 * Chat Notification Triggers
 *
 * Firestore triggers that automatically send notifications when chat messages are sent.
 *
 * Triggers:
 * 1. onChatMessageCreated - When direct chat message is sent
 * 2. onRaceChatMessageCreated - When race chat message is sent
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const db = admin.firestore();

const {
  sendChatMessageNotification,
  sendRaceChatNotification,
} = require('../senders/chatNotifications');

/**
 * TRIGGER 1: Direct Chat Message Created
 *
 * Triggers when: Document created in chat_messages collection
 * Sends: Chat message notification to receiver
 */
exports.onChatMessageCreated = functions.firestore
  .document('chat_messages/{messageId}')
  .onCreate(async (snap, context) => {
    try {
      const messageData = snap.data();
      const messageId = context.params.messageId;

      console.log(`🎯 Trigger: Chat message created ${messageId}`);

      const receiverId = messageData.receiverId;
      const senderName = messageData.senderName || 'Someone';
      const messageText = messageData.message || '';
      const chatId = messageData.chatId;

      if (!receiverId || !messageText) {
        console.error(`❌ Missing required fields in message ${messageId}`);
        return null;
      }

      console.log(`💬 Chat message: ${senderName} → ${receiverId}`);
      await sendChatMessageNotification(receiverId, senderName, messageText, chatId);

      return null;
    } catch (error) {
      console.error(`❌ Error in onChatMessageCreated: ${error}`);
      return null;
    }
  });

/**
 * TRIGGER 2: Race Chat Message Created
 *
 * Triggers when: Document created in race_chat_messages collection
 * Sends: Race chat message notification to all participants except sender
 */
exports.onRaceChatMessageCreated = functions.firestore
  .document('race_chat_messages/{messageId}')
  .onCreate(async (snap, context) => {
    try {
      const messageData = snap.data();
      const messageId = context.params.messageId;

      console.log(`🎯 Trigger: Race chat message created ${messageId}`);

      const senderId = messageData.senderId;
      const senderName = messageData.senderName || 'Someone';
      const messageText = messageData.message || '';
      const raceChatId = messageData.raceChatId;
      const raceId = messageData.raceId;

      if (!senderId || !messageText || !raceChatId) {
        console.error(`❌ Missing required fields in race message ${messageId}`);
        return null;
      }

      // Fetch race chat room to get participants
      const raceChatDoc = await db.collection('race_chat_rooms').doc(raceChatId).get();
      if (!raceChatDoc.exists) {
        console.error(`❌ Race chat room ${raceChatId} not found`);
        return null;
      }

      const raceChatData = raceChatDoc.data();
      const participantIds = raceChatData.participantIds || [];
      const raceTitle = raceChatData.raceTitle || 'Race Chat';

      console.log(`🏃 Race chat message in "${raceTitle}": ${senderName} → ${participantIds.length} participants`);

      // Send notification to all participants except sender
      const notificationPromises = [];
      for (const participantId of participantIds) {
        if (participantId !== senderId) {
          notificationPromises.push(
            sendRaceChatNotification(
              participantId,
              senderName,
              messageText,
              raceTitle,
              raceId,
              raceChatId
            )
          );
        }
      }

      await Promise.all(notificationPromises);
      console.log(`✅ Sent ${notificationPromises.length} race chat notifications`);

      return null;
    } catch (error) {
      console.error(`❌ Error in onRaceChatMessageCreated: ${error}`);
      return null;
    }
  });
