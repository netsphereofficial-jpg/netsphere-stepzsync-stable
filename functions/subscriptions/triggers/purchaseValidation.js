/**
 * Cloud Functions for Purchase Validation
 * Callable functions for validating Apple and Google Play purchases
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const appleValidator = require('../validators/appleValidator');
const googleValidator = require('../validators/googleValidator');

/**
 * Validate Apple App Store receipt and update user subscription
 */
exports.validateAppleReceipt = functions.https.onCall(async (data, context) => {
  // Authenticate user
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to validate purchases'
    );
  }

  const userId = context.auth.uid;
  const { receiptData } = data;

  // Validate input
  if (!receiptData) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Receipt data is required'
    );
  }

  try {
    console.log(`🍎 Validating Apple receipt for user: ${userId}`);

    // Get Apple shared secret from config
    const config = functions.config();
    const sharedSecret = config.apple?.shared_secret;

    if (!sharedSecret) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Apple shared secret not configured'
      );
    }

    // Validate receipt with Apple
    const validationResult = await appleValidator.validateAppleReceipt(
      receiptData,
      sharedSecret,
      true // Try production first
    );

    // Map product ID to plan type
    const planType = appleValidator.getSubscriptionPlanFromProductId(
      validationResult.productId
    );

    // Get features for plan
    const features = appleValidator.getFeaturesForPlan(planType);

    // Prepare subscription data
    const subscriptionData = {
      currentPlan: planType,
      status: validationResult.status,
      purchaseDate: admin.firestore.Timestamp.fromDate(
        new Date(validationResult.purchaseDate)
      ),
      expiryDate: admin.firestore.Timestamp.fromDate(
        new Date(validationResult.expiryDate)
      ),
      transactionId: validationResult.transactionId,
      originalTransactionId: validationResult.originalTransactionId,
      platform: 'ios',
      autoRenew: validationResult.autoRenew,
      lastValidated: admin.firestore.FieldValue.serverTimestamp(),
      features,
    };

    // Save to Firestore using admin SDK (bypasses security rules)
    const db = admin.firestore();
    await db.collection('user_profiles').doc(userId).set(
      {
        subscription: subscriptionData,
        subscriptionHistory: admin.firestore.FieldValue.arrayUnion({
          action: 'purchased',
          plan: planType,
          transactionId: validationResult.transactionId,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          platform: 'ios',
        }),
      },
      { merge: true }
    );

    console.log(`✅ Apple subscription saved for user: ${userId}`, { planType });

    return {
      success: true,
      subscription: {
        planType,
        status: validationResult.status,
        expiryDate: validationResult.expiryDate,
        features,
      },
    };
  } catch (error) {
    console.error(`❌ Apple validation failed for user: ${userId}`, error);
    throw error;
  }
});

/**
 * Validate Google Play purchase and update user subscription
 */
exports.validateGooglePlayPurchase = functions.https.onCall(async (data, context) => {
  // Authenticate user
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to validate purchases'
    );
  }

  const userId = context.auth.uid;
  const { productId, purchaseToken, packageName } = data;

  // Validate input
  if (!productId || !purchaseToken || !packageName) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Product ID, purchase token, and package name are required'
    );
  }

  try {
    console.log(`🤖 Validating Google Play purchase for user: ${userId}`);

    // Get Google Play service account from config
    const config = functions.config();
    const serviceAccountJson = config.google?.play_service_account;

    if (!serviceAccountJson) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Google Play service account not configured'
      );
    }

    // Parse service account JSON
    const serviceAccount = JSON.parse(serviceAccountJson);

    // Validate purchase with Google Play
    const validationResult = await googleValidator.validateGooglePlayPurchase(
      packageName,
      productId,
      purchaseToken,
      serviceAccount
    );

    // Acknowledge purchase (required for new purchases)
    await googleValidator.acknowledgeGooglePlayPurchase(
      packageName,
      productId,
      purchaseToken,
      serviceAccount
    );

    // Map product ID to plan type
    const planType = googleValidator.getSubscriptionPlanFromProductId(productId);

    // Get features for plan
    const features = googleValidator.getFeaturesForPlan(planType);

    // Prepare subscription data
    const subscriptionData = {
      currentPlan: planType,
      status: validationResult.status,
      purchaseDate: admin.firestore.Timestamp.fromDate(
        new Date(validationResult.purchaseDate)
      ),
      expiryDate: admin.firestore.Timestamp.fromDate(
        new Date(validationResult.expiryDate)
      ),
      transactionId: validationResult.orderId,
      purchaseToken: validationResult.purchaseToken,
      platform: 'android',
      autoRenew: validationResult.autoRenew,
      lastValidated: admin.firestore.FieldValue.serverTimestamp(),
      features,
    };

    // Save to Firestore using admin SDK (bypasses security rules)
    const db = admin.firestore();
    await db.collection('user_profiles').doc(userId).set(
      {
        subscription: subscriptionData,
        subscriptionHistory: admin.firestore.FieldValue.arrayUnion({
          action: 'purchased',
          plan: planType,
          transactionId: validationResult.orderId,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          platform: 'android',
        }),
      },
      { merge: true }
    );

    console.log(`✅ Google Play subscription saved for user: ${userId}`, { planType });

    return {
      success: true,
      subscription: {
        planType,
        status: validationResult.status,
        expiryDate: validationResult.expiryDate,
        features,
      },
    };
  } catch (error) {
    console.error(`❌ Google Play validation failed for user: ${userId}`, error);
    throw error;
  }
});

/**
 * Restore purchases for a user
 * Re-validates existing purchases and updates subscription status
 */
exports.restorePurchases = functions.https.onCall(async (data, context) => {
  // Authenticate user
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to restore purchases'
    );
  }

  const userId = context.auth.uid;
  const { platform, receiptData, purchaseToken, productId, packageName } = data;

  try {
    console.log(`🔄 Restoring purchases for user: ${userId}`, { platform });

    if (platform === 'ios' && receiptData) {
      // Restore Apple purchases
      return await exports.validateAppleReceipt.run({ receiptData }, context);
    } else if (platform === 'android' && purchaseToken && productId && packageName) {
      // Restore Google Play purchases
      return await exports.validateGooglePlayPurchase.run(
        { productId, purchaseToken, packageName },
        context
      );
    } else {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Invalid platform or missing purchase data'
      );
    }
  } catch (error) {
    console.error(`❌ Restore purchases failed for user: ${userId}`, error);
    throw error;
  }
});
