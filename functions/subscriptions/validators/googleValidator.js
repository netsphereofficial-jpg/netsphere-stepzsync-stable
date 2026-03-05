/**
 * Google Play Store Purchase Validator
 * Validates subscription purchases with Google Play Developer API
 */

const { google } = require('googleapis');
const functions = require('firebase-functions');

/**
 * Initialize Google Play Developer API client
 */
function getPlayDeveloperClient(serviceAccountKey) {
  try {
    const auth = new google.auth.GoogleAuth({
      credentials: serviceAccountKey,
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });

    return google.androidpublisher({
      version: 'v3',
      auth: auth,
    });
  } catch (error) {
    console.error('❌ Failed to initialize Google Play client:', error.message);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to initialize Google Play validation service'
    );
  }
}

/**
 * Validate a Google Play subscription purchase
 * @param {string} packageName - Android app package name
 * @param {string} productId - Subscription product ID
 * @param {string} purchaseToken - Purchase token from the client
 * @param {object} serviceAccountKey - Google Play service account credentials
 * @returns {Promise<object>} Validation result with subscription details
 */
async function validateGooglePlayPurchase(
  packageName,
  productId,
  purchaseToken,
  serviceAccountKey
) {
  try {
    console.log('🤖 Validating Google Play purchase...', { packageName, productId });

    const androidPublisher = getPlayDeveloperClient(serviceAccountKey);

    // Get subscription details
    const response = await androidPublisher.purchases.subscriptions.get({
      packageName,
      subscriptionId: productId,
      token: purchaseToken,
    });

    const purchase = response.data;

    // Parse dates
    const startTimeMillis = parseInt(purchase.startTimeMillis);
    const expiryTimeMillis = parseInt(purchase.expiryTimeMillis);
    const purchaseDate = new Date(startTimeMillis);
    const expiryDate = new Date(expiryTimeMillis);

    // Determine subscription status
    const now = Date.now();
    const isExpired = expiryTimeMillis < now;
    const autoRenewing = purchase.autoRenewing === true;

    let status = 'active';
    if (isExpired) {
      status = 'expired';
    } else if (purchase.cancelReason !== undefined) {
      status = 'cancelled';
    } else if (!autoRenewing && expiryTimeMillis < now + 3 * 24 * 60 * 60 * 1000) {
      // Less than 3 days until expiry and not renewing
      status = 'cancelled';
    }

    // Payment state: 0=pending, 1=received, 2=free_trial, 3=pending_deferred
    const paymentState = purchase.paymentState;
    if (paymentState === 0) {
      status = 'pending';
    }

    console.log('✅ Google Play purchase validated successfully', {
      productId,
      status,
      expiryDate,
    });

    return {
      success: true,
      platform: 'android',
      productId,
      purchaseToken,
      orderId: purchase.orderId,
      purchaseDate: purchaseDate.toISOString(),
      expiryDate: expiryDate.toISOString(),
      status,
      autoRenew: autoRenewing,
      cancelReason: getCancelReason(purchase.cancelReason),
      userCancellationTime: purchase.userCancellationTimeMillis
        ? new Date(parseInt(purchase.userCancellationTimeMillis)).toISOString()
        : null,
      isTrialPeriod: paymentState === 2,
      paymentState: getPaymentState(paymentState),
      priceAmountMicros: purchase.priceAmountMicros,
      priceCurrencyCode: purchase.priceCurrencyCode,
      countryCode: purchase.countryCode,
      developerPayload: purchase.developerPayload,
    };
  } catch (error) {
    console.error('❌ Google Play validation error:', error.message);

    // Handle specific error cases
    if (error.code === 404) {
      throw new functions.https.HttpsError(
        'not-found',
        'Purchase not found or already consumed'
      );
    }

    if (error.code === 401 || error.code === 403) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Invalid service account credentials or permissions'
      );
    }

    throw new functions.https.HttpsError(
      'invalid-argument',
      `Failed to validate Google Play purchase: ${error.message}`
    );
  }
}

/**
 * Acknowledge a Google Play subscription purchase
 * Required for new purchases to prevent refunds
 */
async function acknowledgeGooglePlayPurchase(
  packageName,
  productId,
  purchaseToken,
  serviceAccountKey
) {
  try {
    const androidPublisher = getPlayDeveloperClient(serviceAccountKey);

    await androidPublisher.purchases.subscriptions.acknowledge({
      packageName,
      subscriptionId: productId,
      token: purchaseToken,
    });

    console.log('✅ Google Play purchase acknowledged');
    return { success: true };
  } catch (error) {
    console.error('❌ Failed to acknowledge purchase:', error.message);
    // Don't throw - acknowledgment can be retried
    return { success: false, error: error.message };
  }
}

/**
 * Get human-readable cancel reason
 */
function getCancelReason(code) {
  const reasons = {
    0: 'User cancelled',
    1: 'System cancelled',
    2: 'Replaced with new subscription',
    3: 'Developer cancelled',
  };
  return code !== undefined ? reasons[code] || 'Unknown' : null;
}

/**
 * Get human-readable payment state
 */
function getPaymentState(code) {
  const states = {
    0: 'Pending',
    1: 'Received',
    2: 'Free trial',
    3: 'Pending deferred',
  };
  return states[code] || 'Unknown';
}

/**
 * Map Google Play product ID to subscription plan type
 */
function getSubscriptionPlanFromProductId(productId) {
  const planMap = {
    'premium_1_monthly': 'premium1',
    'premium_1_yearly': 'premium1',
    'premium_lifetime_onetime': 'lifetime',
  };

  return planMap[productId] || 'free';
}

/**
 * Get features for a subscription plan
 */
function getFeaturesForPlan(planType) {
  const features = {
    free: {
      hasGlobalAccess: false,
      maxRaces: 3,
      maxCreateRaces: 2,
      hasLeaderboards: false,
      hasHallOfFame: false,
      hasAdvancedStats: false,
      hasHeartRateZones: false,
      hasMarathons: false,
      hasGroupChat: false,
    },
    premium1: {
      hasGlobalAccess: false,
      maxRaces: 7,
      maxCreateRaces: 7,
      hasLeaderboards: true,
      hasHallOfFame: false,
      hasAdvancedStats: true,
      hasHeartRateZones: true,
      hasMarathons: true,
      hasGroupChat: false,
    },
    premium2: {
      hasGlobalAccess: true,
      maxRaces: 20,
      maxCreateRaces: 20,
      hasLeaderboards: true,
      hasHallOfFame: true,
      hasAdvancedStats: true,
      hasHeartRateZones: true,
      hasMarathons: true,
      hasGroupChat: true,
    },
    lifetime: {
      hasGlobalAccess: true,
      maxRaces: 999,
      maxCreateRaces: 999,
      hasLeaderboards: true,
      hasHallOfFame: true,
      hasAdvancedStats: true,
      hasHeartRateZones: true,
      hasMarathons: true,
      hasGroupChat: true,
    },
  };

  return features[planType] || features.free;
}

/**
 * Check if a product ID is a one-time (non-subscription) purchase
 */
function isOneTimePurchase(productId) {
  return productId === 'premium_lifetime_onetime';
}

/**
 * Validate a Google Play one-time in-app product purchase
 * Used for premium_lifetime_onetime and other non-subscription products
 */
async function validateGooglePlayProduct(
  packageName,
  productId,
  purchaseToken,
  serviceAccountKey
) {
  try {
    console.log('🤖 Validating Google Play in-app product...', { packageName, productId });

    const androidPublisher = getPlayDeveloperClient(serviceAccountKey);

    const response = await androidPublisher.purchases.products.get({
      packageName,
      productId,
      token: purchaseToken,
    });

    const purchase = response.data;

    // purchaseState: 0=purchased, 1=canceled, 2=pending
    const purchaseState = purchase.purchaseState;
    let status = 'active';
    if (purchaseState === 1) {
      status = 'cancelled';
    } else if (purchaseState === 2) {
      status = 'pending';
    }

    const purchaseTimeMillis = parseInt(purchase.purchaseTimeMillis);
    const purchaseDate = new Date(purchaseTimeMillis);

    // Lifetime products don't expire — set expiry far in the future
    const expiryDate = new Date('2099-12-31T23:59:59Z');

    console.log('✅ Google Play in-app product validated successfully', {
      productId,
      status,
      orderId: purchase.orderId,
    });

    return {
      success: true,
      platform: 'android',
      productId,
      purchaseToken,
      orderId: purchase.orderId,
      purchaseDate: purchaseDate.toISOString(),
      expiryDate: expiryDate.toISOString(),
      status,
      autoRenew: false, // One-time purchase, never renews
      cancelReason: null,
      userCancellationTime: null,
      paymentState: purchaseState === 0 ? 'Received' : 'Pending',
      consumptionState: purchase.consumptionState,
      developerPayload: purchase.developerPayload,
    };
  } catch (error) {
    console.error('❌ Google Play product validation error:', error.message);

    if (error.code === 404) {
      throw new functions.https.HttpsError(
        'not-found',
        'Purchase not found or already consumed'
      );
    }

    if (error.code === 401 || error.code === 403) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Invalid service account credentials or permissions'
      );
    }

    throw new functions.https.HttpsError(
      'invalid-argument',
      `Failed to validate Google Play product: ${error.message}`
    );
  }
}

/**
 * Acknowledge a Google Play in-app product purchase
 * Required for new purchases to prevent refunds
 */
async function acknowledgeGooglePlayProduct(
  packageName,
  productId,
  purchaseToken,
  serviceAccountKey
) {
  try {
    const androidPublisher = getPlayDeveloperClient(serviceAccountKey);

    await androidPublisher.purchases.products.acknowledge({
      packageName,
      productId,
      token: purchaseToken,
    });

    console.log('✅ Google Play in-app product acknowledged');
    return { success: true };
  } catch (error) {
    console.error('❌ Failed to acknowledge product:', error.message);
    return { success: false, error: error.message };
  }
}

module.exports = {
  validateGooglePlayPurchase,
  validateGooglePlayProduct,
  acknowledgeGooglePlayPurchase,
  acknowledgeGooglePlayProduct,
  isOneTimePurchase,
  getSubscriptionPlanFromProductId,
  getFeaturesForPlan,
};
