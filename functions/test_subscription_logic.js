#!/usr/bin/env node

/**
 * Unit tests for subscription validation logic
 * Tests planMap, isTrialPeriod, isOneTimePurchase — no emulator needed
 *
 * Run: node functions/test_subscription_logic.js
 */

const appleValidator = require('./subscriptions/validators/appleValidator');
const googleValidator = require('./subscriptions/validators/googleValidator');

let passed = 0;
let failed = 0;

function assert(condition, testName) {
  if (condition) {
    console.log(`  ✅ ${testName}`);
    passed++;
  } else {
    console.error(`  ❌ ${testName}`);
    failed++;
  }
}

// ─── Apple planMap tests ────────────────────────────────────────────────────

console.log('\n🍎 Apple Validator — planMap');

assert(
  appleValidator.getSubscriptionPlanFromProductId('premium_1_monthly') === 'premium1',
  'premium_1_monthly → premium1'
);

assert(
  appleValidator.getSubscriptionPlanFromProductId('premium_1_yearly') === 'premium1',
  'premium_1_yearly → premium1'
);

assert(
  appleValidator.getSubscriptionPlanFromProductId('premium_lifetime_onetime') === 'lifetime',
  'premium_lifetime_onetime → lifetime'
);

assert(
  appleValidator.getSubscriptionPlanFromProductId('unknown_product') === 'free',
  'unknown product → free (fallback)'
);

// Old product IDs should NOT map to anything
assert(
  appleValidator.getSubscriptionPlanFromProductId('premium_2_monthly') === 'free',
  'premium_2_monthly (old) → free (removed)'
);

assert(
  appleValidator.getSubscriptionPlanFromProductId('lifetime_premium') === 'free',
  'lifetime_premium (old) → free (removed)'
);

// ─── Google planMap tests ───────────────────────────────────────────────────

console.log('\n🤖 Google Validator — planMap');

assert(
  googleValidator.getSubscriptionPlanFromProductId('premium_1_monthly') === 'premium1',
  'premium_1_monthly → premium1'
);

assert(
  googleValidator.getSubscriptionPlanFromProductId('premium_1_yearly') === 'premium1',
  'premium_1_yearly → premium1'
);

assert(
  googleValidator.getSubscriptionPlanFromProductId('premium_lifetime_onetime') === 'lifetime',
  'premium_lifetime_onetime → lifetime'
);

assert(
  googleValidator.getSubscriptionPlanFromProductId('unknown_product') === 'free',
  'unknown product → free (fallback)'
);

assert(
  googleValidator.getSubscriptionPlanFromProductId('premium_2_monthly') === 'free',
  'premium_2_monthly (old) → free (removed)'
);

assert(
  googleValidator.getSubscriptionPlanFromProductId('lifetime_premium') === 'free',
  'lifetime_premium (old) → free (removed)'
);

// ─── isOneTimePurchase tests ────────────────────────────────────────────────

console.log('\n💎 Google Validator — isOneTimePurchase');

assert(
  googleValidator.isOneTimePurchase('premium_lifetime_onetime') === true,
  'premium_lifetime_onetime → true'
);

assert(
  googleValidator.isOneTimePurchase('premium_1_monthly') === false,
  'premium_1_monthly → false'
);

assert(
  googleValidator.isOneTimePurchase('premium_1_yearly') === false,
  'premium_1_yearly → false'
);

assert(
  googleValidator.isOneTimePurchase('lifetime_premium') === false,
  'lifetime_premium (old) → false'
);

// ─── Features tests ────────────────────────────────────────────────────────

console.log('\n⚙️  Features — getFeaturesForPlan');

const premium1Features = googleValidator.getFeaturesForPlan('premium1');
assert(premium1Features.hasAdvancedStats === true, 'premium1 has advanced stats');
assert(premium1Features.maxRaces === 7, 'premium1 maxRaces = 7');
assert(premium1Features.hasGlobalAccess === false, 'premium1 no global access');

const lifetimeFeatures = googleValidator.getFeaturesForPlan('lifetime');
assert(lifetimeFeatures.hasGlobalAccess === true, 'lifetime has global access');
assert(lifetimeFeatures.maxRaces === 999, 'lifetime maxRaces = 999');

// premium2 features still exist for backward compat with existing Firestore users
const premium2Features = googleValidator.getFeaturesForPlan('premium2');
assert(premium2Features.hasGlobalAccess === true, 'premium2 (legacy) has global access');
assert(premium2Features.maxRaces === 20, 'premium2 (legacy) maxRaces = 20');

const freeFeatures = googleValidator.getFeaturesForPlan('free');
assert(freeFeatures.maxRaces === 3, 'free maxRaces = 3');

const unknownFeatures = googleValidator.getFeaturesForPlan('nonexistent');
assert(unknownFeatures.maxRaces === 3, 'unknown plan → free features (fallback)');

// ─── Summary ────────────────────────────────────────────────────────────────

console.log('\n══════════════════════════════════════════');
if (failed === 0) {
  console.log(`  ✅ All ${passed} tests passed!`);
} else {
  console.log(`  ❌ ${failed} failed, ${passed} passed`);
}
console.log('══════════════════════════════════════════\n');

process.exit(failed > 0 ? 1 : 0);
