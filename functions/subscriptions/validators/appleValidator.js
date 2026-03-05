/**
 * Apple App Store Receipt Validator
 * Validates subscription receipts with Apple's App Store Server API
 */

const axios = require('axios');
const functions = require('firebase-functions');

// Apple verification endpoints
const PRODUCTION_URL = 'https://buy.itunes.apple.com/verifyReceipt';
const SANDBOX_URL = 'https://sandbox.itunes.apple.com/verifyReceipt';

// Status codes from Apple
const STATUS_CODES = {
  SUCCESS: 0,
  SANDBOX_RECEIPT_ON_PROD: 21007,
  PROD_RECEIPT_ON_SANDBOX: 21008,
};

/**
 * Validate an Apple App Store receipt
 * @param {string} receiptData - Base64 encoded receipt data
 * @param {string} sharedSecret - App-specific shared secret from App Store Connect
 * @param {boolean} isProduction - Whether to use production or sandbox environment
 * @returns {Promise<object>} Validation result with subscription details
 */
async function validateAppleReceipt(receiptData, sharedSecret, isProduction = true) {
  try {
    console.log('🍎 Validating Apple receipt...', { isProduction });

    // Prepare request body
    const requestBody = {
      'receipt-data': receiptData,
      'password': sharedSecret,
      'exclude-old-transactions': true,
    };

    // Try production first
    let response = await axios.post(
      isProduction ? PRODUCTION_URL : SANDBOX_URL,
      requestBody,
      {
        headers: { 'Content-Type': 'application/json' },
        timeout: 10000,
      }
    );

    let data = response.data;

    // If we get sandbox receipt on production, retry with sandbox
    if (data.status === STATUS_CODES.SANDBOX_RECEIPT_ON_PROD) {
      console.log('🍎 Sandbox receipt detected, retrying with sandbox URL...');
      response = await axios.post(SANDBOX_URL, requestBody, {
        headers: { 'Content-Type': 'application/json' },
        timeout: 10000,
      });
      data = response.data;
    }

    // Check status
    if (data.status !== STATUS_CODES.SUCCESS) {
      throw new Error(`Apple verification failed with status ${data.status}`);
    }

    // Extract latest receipt info
    const latestReceiptInfo = data.latest_receipt_info || [];
    const pendingRenewalInfo = data.pending_renewal_info || [];

    // Get the most recent subscription
    const sortedReceipts = latestReceiptInfo.sort(
      (a, b) => parseInt(b.purchase_date_ms) - parseInt(a.purchase_date_ms)
    );
    const latestReceipt = sortedReceipts[0];

    if (!latestReceipt) {
      throw new Error('No valid subscription found in receipt');
    }

    // Parse subscription data
    const expiresDate = new Date(parseInt(latestReceipt.expires_date_ms));
    const purchaseDate = new Date(parseInt(latestReceipt.purchase_date_ms));
    const isExpired = expiresDate < new Date();

    // Check auto-renew status
    const renewalInfo = pendingRenewalInfo.find(
      (info) => info.product_id === latestReceipt.product_id
    );
    const autoRenewStatus = renewalInfo?.auto_renew_status === '1';

    // Determine subscription status
    let status = 'active';
    if (isExpired) {
      status = autoRenewStatus ? 'expired' : 'cancelled';
    } else if (renewalInfo?.expiration_intent) {
      // Expiration intent means cancellation is pending
      status = 'cancelled';
    }

    console.log('✅ Apple receipt validated successfully', {
      productId: latestReceipt.product_id,
      status,
      expiresDate,
    });

    return {
      success: true,
      platform: 'ios',
      productId: latestReceipt.product_id,
      transactionId: latestReceipt.transaction_id,
      originalTransactionId: latestReceipt.original_transaction_id,
      purchaseDate: purchaseDate.toISOString(),
      expiryDate: expiresDate.toISOString(),
      status,
      autoRenew: autoRenewStatus,
      isTrialPeriod: latestReceipt.is_trial_period === 'true',
      cancellationDate: latestReceipt.cancellation_date_ms
        ? new Date(parseInt(latestReceipt.cancellation_date_ms)).toISOString()
        : null,
      environment: data.environment || (isProduction ? 'Production' : 'Sandbox'),
    };
  } catch (error) {
    console.error('❌ Apple receipt validation error:', error.message);
    throw new functions.https.HttpsError(
      'invalid-argument',
      `Failed to validate Apple receipt: ${error.message}`
    );
  }
}

/**
 * Map Apple product ID to subscription plan type
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

module.exports = {
  validateAppleReceipt,
  getSubscriptionPlanFromProductId,
  getFeaturesForPlan,
};
