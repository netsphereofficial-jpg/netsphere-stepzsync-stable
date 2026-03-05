#!/usr/bin/env node

/**
 * Google Play Subscription & Product Setup Script
 *
 * Creates subscription products in Google Play Console programmatically
 * matching the iOS App Store Connect products.
 *
 * Products created:
 *   - premium_1_monthly  (monthly auto-renewing subscription)
 *   - premium_1_yearly   (yearly auto-renewing subscription)
 *   - premium_lifetime_onetime ($299 one-time in-app product)
 *
 * Usage:
 *   node scripts/setup_google_play_products.js <path-to-service-account.json>
 */

const { google } = require('googleapis');
const fs = require('fs');
const path = require('path');

// ─── Configuration ──────────────────────────────────────────────────────────

const PACKAGE_NAME = 'com.health.stepzsync.stepzsync';
const REGIONS_VERSION = '2022/02';

const SUBSCRIPTIONS = [
  {
    productId: 'premium_1_monthly',
    basePlanId: 'monthly',
    listing: {
      title: 'Premium 1 - Country Access',
      description: 'Unlock country-level races, create & join up to 7 races, local/country marathons, advanced statistics with filters, heart-rate zones & recovery insights, detailed calorie analysis, full breathing pack, custom reminders, and local/country leaderboards.',
      benefits: [
        'City + Country level races',
        'Join & create up to 7 races',
        'Local/Country marathons & leaderboards',
        'Advanced statistics & heart-rate zones',
        'Full breathing pack & custom reminders',
      ],
    },
    price: { units: '9', nanos: 990000000 }, // $9.99
    billingPeriod: 'P1M', // Monthly
    freeTrialDays: 7,
  },
  {
    productId: 'premium_1_yearly',
    basePlanId: 'yearly',
    listing: {
      title: 'Premium 1 - Country Access (Yearly)',
      description: 'Unlock country-level races, create & join up to 7 races, local/country marathons, advanced statistics with filters, heart-rate zones & recovery insights, detailed calorie analysis, full breathing pack, custom reminders, and local/country leaderboards. Save with annual billing!',
      benefits: [
        'City + Country level races',
        'Join & create up to 7 races',
        'Local/Country marathons & leaderboards',
        'Advanced statistics & heart-rate zones',
        'Save with annual billing',
      ],
    },
    price: { units: '49', nanos: 990000000 }, // $49.99 (placeholder — set to match iOS)
    billingPeriod: 'P1Y', // Yearly
    freeTrialDays: 7,
  },
];

const LIFETIME_PRODUCT = {
  sku: 'premium_lifetime_onetime',
  defaultPrice: {
    priceMicros: '299000000', // $299.00
    currency: 'USD',
  },
  listing: {
    title: 'Premium Lifetime',
    description: 'Premium Lifetime',
  },
};

// ─── Main ───────────────────────────────────────────────────────────────────

async function main() {
  const serviceAccountPath = process.argv[2];

  if (!serviceAccountPath) {
    console.error('Usage: node setup_google_play_products.js <path-to-service-account.json>');
    process.exit(1);
  }

  // Load service account
  const fullPath = path.resolve(serviceAccountPath);
  if (!fs.existsSync(fullPath)) {
    console.error(`❌ Service account file not found: ${fullPath}`);
    process.exit(1);
  }

  const serviceAccount = JSON.parse(fs.readFileSync(fullPath, 'utf8'));
  console.log(`✅ Loaded service account: ${serviceAccount.client_email}`);
  console.log(`   Project: ${serviceAccount.project_id}`);
  console.log(`   Package: ${PACKAGE_NAME}`);
  console.log(`   Regions Version: ${REGIONS_VERSION}\n`);

  // Authenticate
  const auth = new google.auth.GoogleAuth({
    credentials: serviceAccount,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });

  const androidPublisher = google.androidpublisher({ version: 'v3', auth });

  let successCount = 0;
  let failCount = 0;

  // Create subscriptions
  for (const sub of SUBSCRIPTIONS) {
    const ok = await createSubscription(androidPublisher, sub);
    if (ok) successCount++;
    else failCount++;
  }

  // Create lifetime in-app product
  const ok = await createLifetimeProduct(androidPublisher);
  if (ok) successCount++;
  else failCount++;

  console.log('\n══════════════════════════════════════════');
  if (failCount === 0) {
    console.log('  ✅ All products created successfully!');
  } else {
    console.log(`  ⚠️  ${successCount} succeeded, ${failCount} failed`);
  }
  console.log('══════════════════════════════════════════');
  console.log('\nNext steps:');
  console.log('1. Go to Google Play Console → Monetize → Products');
  console.log('2. Verify the products appear correctly');
  console.log('3. Set up Firebase config for server-side validation:');
  console.log(`   firebase functions:config:set google.play_service_account="$(cat ${fullPath} | python3 -c 'import sys,json; print(json.dumps(json.load(sys.stdin)))')"`);
  console.log('4. Deploy Cloud Functions: firebase deploy --only functions');
}

// ─── Create Subscription ────────────────────────────────────────────────────

async function createSubscription(androidPublisher, config) {
  const { productId, basePlanId, listing, price, billingPeriod, freeTrialDays } = config;

  console.log(`📦 Creating subscription: ${productId}...`);

  try {
    // Build base plan config
    const basePlan = {
      basePlanId,
      autoRenewingBasePlanType: {
        billingPeriodDuration: billingPeriod,
      },
      regionalConfigs: [
        {
          regionCode: 'US',
          newSubscriberAvailability: true,
          price: {
            currencyCode: 'USD',
            units: price.units,
            nanos: price.nanos,
          },
        },
      ],
      state: 'DRAFT',
    };

    // Step 1: Create the subscription with base plan
    const subscriptionBody = {
      packageName: PACKAGE_NAME,
      productId,
      listings: [
        {
          languageCode: 'en-US',
          title: listing.title,
          description: listing.description,
          benefits: listing.benefits,
        },
      ],
      basePlans: [basePlan],
    };

    await androidPublisher.monetization.subscriptions.create({
      packageName: PACKAGE_NAME,
      productId,
      'regionsVersion.version': REGIONS_VERSION,
      requestBody: subscriptionBody,
    });

    console.log(`   ✅ Subscription created: ${productId}`);

    // Step 2: Activate the base plan
    console.log(`   🔄 Activating base plan: ${basePlanId}...`);

    await androidPublisher.monetization.subscriptions.basePlans.activate({
      packageName: PACKAGE_NAME,
      productId,
      basePlanId,
    });

    console.log(`   ✅ Base plan activated: ${productId}/${basePlanId}`);

    // Step 3: Create free trial offer if configured
    if (freeTrialDays) {
      console.log(`   🎁 Creating ${freeTrialDays}-day free trial offer...`);

      const offerId = `${basePlanId}-free-trial`;
      const offerBody = {
        packageName: PACKAGE_NAME,
        productId,
        basePlanId,
        offerId,
        phases: [
          {
            recurrenceCount: 1,
            duration: `P${freeTrialDays}D`,
            regionalConfigs: [
              {
                regionCode: 'US',
                newSubscriberAvailability: true,
                // Free trial — price is zero (omitted means free)
              },
            ],
          },
        ],
        targeting: {
          acquisitionRule: {
            scope: {
              specificSubscriptionInApp: false, // New subscribers only
            },
          },
        },
        state: 'DRAFT',
      };

      try {
        await androidPublisher.monetization.subscriptions.basePlans.offers.create({
          packageName: PACKAGE_NAME,
          productId,
          basePlanId,
          offerId,
          'regionsVersion.version': REGIONS_VERSION,
          requestBody: offerBody,
        });

        // Activate the offer
        await androidPublisher.monetization.subscriptions.basePlans.offers.activate({
          packageName: PACKAGE_NAME,
          productId,
          basePlanId,
          offerId,
        });

        console.log(`   ✅ Free trial offer activated: ${offerId}`);
      } catch (offerError) {
        if (offerError.code === 409 || offerError.message?.includes('already exists')) {
          console.log(`   ⚠️  Trial offer already exists — skipping`);
        } else {
          console.error(`   ⚠️  Failed to create trial offer: ${offerError.message}`);
          console.log(`   💡 You can add the trial offer manually in Google Play Console`);
        }
      }
    }

    const period = billingPeriod === 'P1Y' ? 'year' : 'month';
    console.log(`   💰 Price: $${price.units}.${String(price.nanos).slice(0, 2)} USD/${period}\n`);
    return true;

  } catch (error) {
    if (error.code === 409 || error.message?.includes('already exists')) {
      console.log(`   ⚠️  Subscription ${productId} already exists — skipping`);
      console.log(`   💡 To update, use Google Play Console or the patch API\n`);
      return true; // Not a failure
    } else {
      console.error(`   ❌ Failed to create ${productId}:`, error.message);
      if (error.errors) {
        error.errors.forEach(e => console.error(`      - ${e.message}`));
      }
      console.log('');
      return false;
    }
  }
}

// ─── Create Lifetime In-App Product ─────────────────────────────────────────

async function createLifetimeProduct(androidPublisher) {
  const { sku, defaultPrice, listing } = LIFETIME_PRODUCT;

  console.log(`📦 Creating in-app product: ${sku}...`);

  try {
    const productBody = {
      packageName: PACKAGE_NAME,
      sku,
      status: 'active',
      purchaseType: 'managedUser', // Non-consumable one-time purchase
      defaultPrice: {
        priceMicros: defaultPrice.priceMicros,
        currency: defaultPrice.currency,
      },
      listings: {
        'en-US': {
          title: listing.title,
          description: listing.description,
        },
      },
      defaultLanguage: 'en-US',
    };

    await androidPublisher.inappproducts.insert({
      packageName: PACKAGE_NAME,
      requestBody: productBody,
    });

    console.log(`   ✅ In-app product created: ${sku}`);
    console.log(`   💰 Price: $${parseInt(defaultPrice.priceMicros) / 1000000} USD (one-time)\n`);
    return true;

  } catch (error) {
    if (error.code === 409 || error.message?.includes('already exists')) {
      console.log(`   ⚠️  Product ${sku} already exists — skipping`);
      console.log(`   💡 To update, use Google Play Console or the update API\n`);
      return true;
    } else {
      console.error(`   ❌ Failed to create ${sku}:`, error.message);
      if (error.errors) {
        error.errors.forEach(e => console.error(`      - ${e.message}`));
      }
      console.log('');
      return false;
    }
  }
}

// ─── Run ────────────────────────────────────────────────────────────────────

main().catch((error) => {
  console.error('\n❌ Script failed:', error.message);
  if (error.code === 401 || error.code === 403) {
    console.error('\n💡 Permission issue. Make sure:');
    console.error('   1. Google Play Android Developer API is enabled in Google Cloud Console');
    console.error('   2. Service account is invited in Google Play Console → Users & Permissions');
    console.error('   3. Service account has "Admin" or "Manage store presence" permission');
    console.error('   4. Wait 24 hours after granting permissions (Google caches access)');
  }
  process.exit(1);
});
