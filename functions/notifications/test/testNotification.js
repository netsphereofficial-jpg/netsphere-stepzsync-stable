/**
 * Test Notification Functions
 *
 * These functions allow you to test push notifications from the Firebase Console
 * or via HTTP requests. Use these to validate FCM integration before full migration.
 *
 * Usage:
 * 1. Deploy: firebase deploy --only functions
 * 2. Test from Firebase Console or call via HTTP
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { sendNotification, sendNotificationToUser } = require('../core/fcmService');

/**
 * Test notification endpoint (HTTPS callable function)
 *
 * Call from Flutter:
 * final result = await FirebaseFunctions.instance.httpsCallable('testNotification').call({
 *   'userId': 'user123',
 *   'title': 'Test Notification',
 *   'body': 'This is a test notification from Cloud Functions'
 * });
 *
 * Call from Firebase Console or REST API:
 * POST https://us-central1-YOUR_PROJECT.cloudfunctions.net/testNotification
 * {
 *   "data": {
 *     "userId": "user123",
 *     "title": "Test Notification",
 *     "body": "This is a test"
 *   }
 * }
 */
exports.testNotification = functions.https.onCall(async (data, context) => {
  try {
    console.log('🧪 Test notification called with data:', JSON.stringify(data));

    // Extract parameters
    const { userId, fcmToken, title, body, imageUrl, notificationType } = data;

    // Validate required fields
    if (!title || !body) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Title and body are required'
      );
    }

    // Build notification payload
    const notification = {
      title: title,
      body: body,
    };

    if (imageUrl) {
      notification.imageUrl = imageUrl;
    }

    // Build data payload
    const notificationData = {
      type: notificationType || 'Test',
      category: 'Test',
      icon: '🧪',
      timestamp: new Date().toISOString(),
      source: 'cloud_functions_test',
    };

    let result;

    // Send via userId or direct FCM token
    if (userId) {
      console.log(`📤 Sending test notification to user: ${userId}`);
      result = await sendNotificationToUser(userId, notification, notificationData);
    } else if (fcmToken) {
      console.log(`📤 Sending test notification to token: ${fcmToken.substring(0, 20)}...`);
      result = await sendNotification(fcmToken, notification, notificationData);
    } else {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Either userId or fcmToken must be provided'
      );
    }

    if (result.success) {
      console.log('✅ Test notification sent successfully');
      return {
        success: true,
        message: 'Notification sent successfully',
        messageId: result.messageId,
      };
    } else {
      console.error('❌ Test notification failed:', result.error);
      throw new functions.https.HttpsError(
        'internal',
        `Failed to send notification: ${result.error}`
      );
    }

  } catch (error) {
    console.error('❌ Error in testNotification:', error);
    throw new functions.https.HttpsError(
      'internal',
      error.message || 'Failed to send test notification'
    );
  }
});

/**
 * Test notification endpoint for direct HTTP calls (HTTP function)
 *
 * Call via HTTP POST:
 * curl -X POST https://us-central1-YOUR_PROJECT.cloudfunctions.net/testNotificationHTTP \
 *   -H "Content-Type: application/json" \
 *   -d '{"userId":"user123","title":"Test","body":"Hello from Cloud Functions"}'
 */
exports.testNotificationHTTP = functions.https.onRequest(async (req, res) => {
  try {
    // Only allow POST requests
    if (req.method !== 'POST') {
      res.status(405).send({ error: 'Method not allowed. Use POST.' });
      return;
    }

    console.log('🧪 HTTP test notification called with body:', JSON.stringify(req.body));

    // Extract parameters from request body
    const { userId, fcmToken, title, body, imageUrl, notificationType } = req.body;

    // Validate required fields
    if (!title || !body) {
      res.status(400).send({ error: 'Title and body are required' });
      return;
    }

    // Build notification payload
    const notification = {
      title: title,
      body: body,
    };

    if (imageUrl) {
      notification.imageUrl = imageUrl;
    }

    // Build data payload
    const notificationData = {
      type: notificationType || 'Test',
      category: 'Test',
      icon: '🧪',
      timestamp: new Date().toISOString(),
      source: 'cloud_functions_test_http',
    };

    let result;

    // Send via userId or direct FCM token
    if (userId) {
      console.log(`📤 Sending HTTP test notification to user: ${userId}`);
      result = await sendNotificationToUser(userId, notification, notificationData);
    } else if (fcmToken) {
      console.log(`📤 Sending HTTP test notification to token: ${fcmToken.substring(0, 20)}...`);
      result = await sendNotification(fcmToken, notification, notificationData);
    } else {
      res.status(400).send({ error: 'Either userId or fcmToken must be provided' });
      return;
    }

    if (result.success) {
      console.log('✅ HTTP test notification sent successfully');
      res.status(200).send({
        success: true,
        message: 'Notification sent successfully',
        messageId: result.messageId,
      });
    } else {
      console.error('❌ HTTP test notification failed:', result.error);
      res.status(500).send({
        success: false,
        error: result.error,
      });
    }

  } catch (error) {
    console.error('❌ Error in testNotificationHTTP:', error);
    res.status(500).send({
      success: false,
      error: error.message || 'Failed to send test notification',
    });
  }
});

/**
 * Quick test to specific FCM token (for debugging)
 *
 * Call from Firebase Console:
 * {
 *   "fcmToken": "your-fcm-token-here",
 *   "message": "Quick test message"
 * }
 */
exports.quickTestNotification = functions.https.onCall(async (data, context) => {
  try {
    const { fcmToken, message } = data;

    if (!fcmToken) {
      throw new functions.https.HttpsError('invalid-argument', 'fcmToken is required');
    }

    console.log(`🚀 Quick test to token: ${fcmToken.substring(0, 20)}...`);

    const result = await sendNotification(
      fcmToken,
      {
        title: '🧪 Quick Test',
        body: message || 'Quick test from Cloud Functions',
      },
      {
        type: 'QuickTest',
        category: 'Test',
        icon: '🚀',
        timestamp: new Date().toISOString(),
      }
    );

    if (result.success) {
      return { success: true, messageId: result.messageId };
    } else {
      throw new functions.https.HttpsError('internal', result.error);
    }

  } catch (error) {
    console.error('❌ Error in quickTestNotification:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Test notification to current authenticated user
 *
 * Call from Flutter app when user is logged in:
 * final result = await FirebaseFunctions.instance.httpsCallable('testNotificationToMe').call();
 */
exports.testNotificationToMe = functions.https.onCall(async (data, context) => {
  try {
    // Check if user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to test notifications'
      );
    }

    const userId = context.auth.uid;
    console.log(`🧪 Sending test notification to authenticated user: ${userId}`);

    const result = await sendNotificationToUser(
      userId,
      {
        title: '✅ Test Successful!',
        body: 'Your Firebase Cloud Functions push notifications are working perfectly!',
      },
      {
        type: 'TestToMe',
        category: 'Test',
        icon: '✅',
        userId: userId,
        timestamp: new Date().toISOString(),
      }
    );

    if (result.success) {
      console.log('✅ Test notification sent to authenticated user');
      return {
        success: true,
        message: 'Notification sent! Check your device.',
        messageId: result.messageId,
      };
    } else {
      throw new functions.https.HttpsError('internal', result.error);
    }

  } catch (error) {
    console.error('❌ Error in testNotificationToMe:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
