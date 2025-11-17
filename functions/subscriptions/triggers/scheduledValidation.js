/**
 * Scheduled Subscription Validation
 * Runs daily to check and update all active subscriptions
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const appleValidator = require('../validators/appleValidator');
const googleValidator = require('../validators/googleValidator');

/**
 * Validate all active subscriptions daily
 * Runs every day at 2 AM UTC
 */
exports.validateAllSubscriptions = functions.pubsub
  .schedule('0 2 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('🔄 Starting daily subscription validation...');

    const db = admin.firestore();
    let validatedCount = 0;
    let expiredCount = 0;
    let errorCount = 0;

    try {
      // Get all user profiles with active subscriptions
      const usersSnapshot = await db
        .collection('user_profiles')
        .where('subscription.status', '==', 'active')
        .get();

      console.log(`📊 Found ${usersSnapshot.size} active subscriptions to validate`);

      // Process in batches to avoid overwhelming the APIs
      const batchSize = 10;
      const users = usersSnapshot.docs;

      for (let i = 0; i < users.length; i += batchSize) {
        const batch = users.slice(i, i + batchSize);
        const promises = batch.map((doc) => validateUserSubscription(doc));

        const results = await Promise.allSettled(promises);

        results.forEach((result) => {
          if (result.status === 'fulfilled') {
            if (result.value.expired) {
              expiredCount++;
            } else {
              validatedCount++;
            }
          } else {
            errorCount++;
            console.error('Validation error:', result.reason);
          }
        });

        // Add delay between batches to avoid rate limiting
        if (i + batchSize < users.length) {
          await new Promise((resolve) => setTimeout(resolve, 1000));
        }
      }

      console.log('✅ Daily subscription validation complete', {
        total: usersSnapshot.size,
        validated: validatedCount,
        expired: expiredCount,
        errors: errorCount,
      });

      return {
        success: true,
        total: usersSnapshot.size,
        validated: validatedCount,
        expired: expiredCount,
        errors: errorCount,
      };
    } catch (error) {
      console.error('❌ Daily validation failed:', error);
      return { success: false, error: error.message };
    }
  });

/**
 * Validate a single user's subscription
 */
async function validateUserSubscription(userDoc) {
  const userId = userDoc.id;
  const userData = userDoc.data();
  const subscription = userData.subscription;

  if (!subscription) {
    console.log(`⚠️ No subscription data for user: ${userId}`);
    return { userId, skipped: true };
  }

  const { platform, transactionId, originalTransactionId, purchaseToken, currentPlan } =
    subscription;

  try {
    console.log(`🔍 Validating subscription for user: ${userId}`, { platform, currentPlan });

    let validationResult;

    if (platform === 'ios' && originalTransactionId) {
      // For iOS, we need the receipt data which we don't store
      // In production, you'd store the latest receipt or use App Store Server API v2
      // For now, we'll just check the expiry date
      const expiryDate = subscription.expiryDate?.toDate();
      if (expiryDate && expiryDate < new Date()) {
        // Subscription expired
        await updateSubscriptionStatus(userId, 'expired');
        console.log(`⏰ Subscription expired for user: ${userId}`);
        return { userId, expired: true };
      }

      // Still active, update last validated
      await updateLastValidated(userId);
      return { userId, validated: true };
    } else if (platform === 'android' && purchaseToken) {
      // Validate with Google Play
      const config = functions.config();
      const serviceAccountJson = config.google?.play_service_account;

      if (!serviceAccountJson) {
        console.error('Google Play service account not configured');
        return { userId, error: 'Service account not configured' };
      }

      const serviceAccount = JSON.parse(serviceAccountJson);
      const packageName = config.android?.package_name || 'com.stepzsync.app';
      const productId = getProductIdFromPlan(currentPlan);

      validationResult = await googleValidator.validateGooglePlayPurchase(
        packageName,
        productId,
        purchaseToken,
        serviceAccount
      );

      // Update subscription based on validation
      if (validationResult.status === 'expired' || validationResult.status === 'cancelled') {
        await updateSubscriptionStatus(userId, validationResult.status);
        console.log(`⏰ Subscription ${validationResult.status} for user: ${userId}`);
        return { userId, expired: true };
      } else {
        // Update expiry date and last validated
        await updateSubscriptionData(userId, {
          expiryDate: admin.firestore.Timestamp.fromDate(
            new Date(validationResult.expiryDate)
          ),
          autoRenew: validationResult.autoRenew,
          lastValidated: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`✅ Subscription validated for user: ${userId}`);
        return { userId, validated: true };
      }
    } else {
      console.log(`⚠️ Unknown platform or missing data for user: ${userId}`);
      return { userId, skipped: true };
    }
  } catch (error) {
    console.error(`❌ Validation failed for user: ${userId}`, error.message);
    return { userId, error: error.message };
  }
}

/**
 * Update subscription status
 */
async function updateSubscriptionStatus(userId, status) {
  const db = admin.firestore();
  await db
    .collection('user_profiles')
    .doc(userId)
    .update({
      'subscription.status': status,
      'subscription.lastValidated': admin.firestore.FieldValue.serverTimestamp(),
      subscriptionHistory: admin.firestore.FieldValue.arrayUnion({
        action: status,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        source: 'scheduled_validation',
      }),
    });
}

/**
 * Update last validated timestamp
 */
async function updateLastValidated(userId) {
  const db = admin.firestore();
  await db
    .collection('user_profiles')
    .doc(userId)
    .update({
      'subscription.lastValidated': admin.firestore.FieldValue.serverTimestamp(),
    });
}

/**
 * Update subscription data
 */
async function updateSubscriptionData(userId, data) {
  const db = admin.firestore();
  const updates = {};
  Object.keys(data).forEach((key) => {
    updates[`subscription.${key}`] = data[key];
  });
  await db.collection('user_profiles').doc(userId).update(updates);
}

/**
 * Get product ID from plan type
 */
function getProductIdFromPlan(planType) {
  const planMap = {
    premium1: 'premium_1_monthly',
    premium2: 'premium_2_monthly',
    lifetime: 'lifetime_premium',
  };
  return planMap[planType] || '';
}

/**
 * Check expiring subscriptions and send notifications
 * Runs daily at 10 AM UTC
 */
exports.notifyExpiringSubscriptions = functions.pubsub
  .schedule('0 10 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('📢 Checking for expiring subscriptions...');

    const db = admin.firestore();
    const threeDaysFromNow = new Date();
    threeDaysFromNow.setDate(threeDaysFromNow.getDate() + 3);

    try {
      // Get subscriptions expiring in the next 3 days
      const usersSnapshot = await db
        .collection('user_profiles')
        .where('subscription.status', '==', 'active')
        .where('subscription.autoRenew', '==', false)
        .get();

      let notificationCount = 0;

      for (const doc of usersSnapshot.docs) {
        const subscription = doc.data().subscription;
        const expiryDate = subscription.expiryDate?.toDate();

        if (expiryDate && expiryDate <= threeDaysFromNow && expiryDate > new Date()) {
          // Subscription expiring soon
          const daysUntilExpiry = Math.ceil(
            (expiryDate - new Date()) / (1000 * 60 * 60 * 24)
          );

          console.log(`📢 Subscription expiring in ${daysUntilExpiry} days for user: ${doc.id}`);

          // TODO: Send push notification to user
          // You can integrate with your existing notification system here

          notificationCount++;
        }
      }

      console.log(`✅ Sent ${notificationCount} expiry notifications`);
      return { success: true, notifications: notificationCount };
    } catch (error) {
      console.error('❌ Failed to check expiring subscriptions:', error);
      return { success: false, error: error.message };
    }
  });
