# StepzSync Subscription Setup Guide

This guide will walk you through setting up in-app subscriptions for StepzSync using Apple App Store and Google Play Store.

## Table of Contents
1. [Overview](#overview)
2. [Subscription Plans](#subscription-plans)
3. [Apple App Store Setup](#apple-app-store-setup)
4. [Google Play Store Setup](#google-play-store-setup)
5. [Firebase Configuration](#firebase-configuration)
6. [Testing](#testing)
7. [Deployment](#deployment)

---

## Overview

StepzSync uses native in-app purchases (IAP) through:
- **iOS**: Apple App Store (StoreKit)
- **Android**: Google Play Billing Library

All purchases are validated server-side using Firebase Cloud Functions for security.

### Architecture
```
Mobile App → Purchase via Store → Cloud Function Validation → Firestore Update
```

---

## Subscription Plans

### 1. Free Plan (🆓 City Access)
- **Price**: Free
- **Product ID**: N/A (default)
- **Features**: City-only races, 3 joins, 2 creates

### 2. Premium 1 (⭐ Country Access)
- **Price**: $9.99/month (33% off from $14.99)
- **Product ID**: `premium_1_monthly`
- **Billing**: Auto-renewable monthly subscription
- **Features**: Country races, 7 joins, 7 creates, advanced stats

### 3. Premium 2 (🏆 World/Elite Access)
- **Price**: $19.99/month (33% off from $29.99)
- **Product ID**: `premium_2_monthly`
- **Billing**: Auto-renewable monthly subscription
- **Features**: Global races, 20 joins, 20 creates, all features

### 4. Lifetime Premium (⭐ One-Time)
- **Price**: $299 (50% off from $600)
- **Product ID**: `lifetime_premium`
- **Billing**: One-time purchase (non-consumable)
- **Features**: All Premium 2 features forever

---

## Apple App Store Setup

### Step 1: Create App in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Navigate to **My Apps** → **Your App**
3. If your app doesn't exist yet, create it first

### Step 2: Create In-App Purchases

1. In your app, go to **Features** → **In-App Purchases**
2. Click the **+** button to create a new subscription

#### For Premium 1 (Country Access):

**Subscription Details:**
- **Type**: Auto-Renewable Subscription
- **Reference Name**: StepzSync Premium 1 - Country Access
- **Product ID**: `premium_1_monthly`
- **Subscription Group**: Create new group "StepzSync Subscriptions"

**Subscription Pricing:**
- **Price**: $9.99/month (Tier 10)
- **Duration**: 1 month

**Localization:**
- **Display Name**: Premium - Country Access
- **Description**:
  ```
  Unlock country-level races, join up to 7 races, create up to 7 races, and access advanced statistics including heart-rate zones, detailed calorie analysis, and local/country leaderboards.
  ```

**Promotional Image**: Upload a 1024x1024 image showcasing country features

**Review Information:**
- **Screenshot**: Upload screenshot showing subscription screen
- **Review Notes**: Explain the features and benefits

#### For Premium 2 (World/Elite Access):

**Subscription Details:**
- **Type**: Auto-Renewable Subscription
- **Reference Name**: StepzSync Premium 2 - World Elite Access
- **Product ID**: `premium_2_monthly`
- **Subscription Group**: Use same "StepzSync Subscriptions" group

**Subscription Pricing:**
- **Price**: $19.99/month (Tier 20)
- **Duration**: 1 month

**Localization:**
- **Display Name**: Elite - World Access
- **Description**:
  ```
  Access global races, join up to 20 races, create up to 20 races, and unlock all premium features including Hall of Fame, advanced group chat, global leaderboards, and international marathons.
  ```

#### For Lifetime Premium:

**In-App Purchase Details:**
- **Type**: Non-Consumable
- **Reference Name**: StepzSync Lifetime Premium
- **Product ID**: `lifetime_premium`

**Pricing:**
- **Price**: $299.99 (Tier 75)

**Localization:**
- **Display Name**: Lifetime Premium - One-Time
- **Description**:
  ```
  Get all Elite features forever with a one-time payment. Includes unlimited races, all future premium features, priority support, and an exclusive lifetime member badge.
  ```

### Step 3: Set Up Subscription Groups

1. In **Subscription Groups**, configure:
   - **Name**: StepzSync Subscriptions
   - **Display Name**: StepzSync Premium Plans
   - **Subscription Levels**:
     - Level 1: Premium 1 (lower tier)
     - Level 2: Premium 2 (higher tier)

This allows users to upgrade/downgrade between plans.

### Step 4: Get Shared Secret

1. In **App Store Connect** → **My Apps** → **Your App**
2. Go to **App Information** (under General)
3. Scroll to **App-Specific Shared Secret**
4. Click **Generate** if not already created
5. **Copy and save this secret** - you'll need it for Firebase

### Step 5: Submit for Review

1. Fill out all required metadata
2. Submit each in-app purchase for review
3. Wait for Apple approval (usually 1-3 days)

---

## Google Play Store Setup

### Step 1: Create App in Google Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Navigate to your app or create a new one
3. Complete the app details and content rating

### Step 2: Create Subscription Products

1. In the left sidebar, go to **Monetize** → **Subscriptions**
2. Click **Create subscription**

#### For Premium 1 (Country Access):

**Subscription Details:**
- **Product ID**: `premium_1_monthly`
- **Name**: Premium - Country Access
- **Description**:
  ```
  Unlock country-level races, join up to 7 races, create up to 7 races, and access advanced statistics including heart-rate zones, detailed calorie analysis, and local/country leaderboards.
  ```

**Base Plans:**
- **Base plan ID**: `monthly`
- **Billing period**: 1 month
- **Price**: $9.99 USD (set for all countries)
- **Auto-renewing**: Yes
- **Free trial**: Optional (7 days recommended)

**Benefits** (for Google Play listing):
- Country-level race access
- Join up to 7 races
- Create up to 7 races
- Advanced statistics & analytics

**Tags**: fitness, racing, premium

#### For Premium 2 (World/Elite Access):

**Subscription Details:**
- **Product ID**: `premium_2_monthly`
- **Name**: Elite - World Access
- **Description**:
  ```
  Access global races, join up to 20 races, create up to 20 races, and unlock all premium features including Hall of Fame, advanced group chat, global leaderboards, and international marathons.
  ```

**Base Plans:**
- **Base plan ID**: `monthly`
- **Billing period**: 1 month
- **Price**: $19.99 USD
- **Auto-renewing**: Yes
- **Free trial**: Optional (7 days recommended)

#### For Lifetime Premium:

1. Go to **Monetize** → **In-app products** (not subscriptions)
2. Click **Create product**

**Product Details:**
- **Product ID**: `lifetime_premium`
- **Name**: Lifetime Premium - One-Time
- **Description**:
  ```
  Get all Elite features forever with a one-time payment. Includes unlimited races, all future premium features, priority support, and an exclusive lifetime member badge.
  ```
- **Price**: $299.99 USD
- **Managed product** (one-time purchase)

### Step 3: Set Up Service Account for API Access

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select the project linked to your Play Console app
3. Navigate to **IAM & Admin** → **Service Accounts**
4. Click **Create Service Account**

**Service Account Details:**
- **Name**: Firebase Subscription Validator
- **ID**: `firebase-subscription-validator`
- **Description**: Service account for validating Play Store subscriptions

5. Click **Create and Continue**
6. Grant role: **Project** → **Viewer**
7. Click **Done**

**Create Key:**
1. Click on the service account you just created
2. Go to **Keys** tab
3. Click **Add Key** → **Create new key**
4. Choose **JSON** format
5. **Download and save the JSON file securely**

### Step 4: Grant API Access in Play Console

1. Go back to [Google Play Console](https://play.google.com/console)
2. Navigate to **Setup** → **API access**
3. Link to Google Cloud project if not already linked
4. Under **Service accounts**, click **Grant access** for your service account
5. Grant permissions:
   - **View financial data**: ✅
   - **Manage orders**: ✅
   - **View app information**: ✅

6. Click **Invite user** and confirm

### Step 5: Enable Google Play Developer API

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to **APIs & Services** → **Library**
3. Search for **Google Play Android Developer API**
4. Click **Enable**

---

## Firebase Configuration

### Step 1: Set Environment Variables

You need to configure Firebase Functions with your store credentials.

#### Set Apple Shared Secret:

```bash
firebase functions:config:set apple.shared_secret="YOUR_APPLE_SHARED_SECRET"
```

Replace `YOUR_APPLE_SHARED_SECRET` with the shared secret from App Store Connect.

#### Set Google Play Service Account:

```bash
firebase functions:config:set google.play_service_account="$(cat path/to/service-account.json | jq -c .)"
```

Replace `path/to/service-account.json` with the path to your service account JSON file.

#### Set Android Package Name:

```bash
firebase functions:config:set android.package_name="com.stepzsync.app"
```

Replace with your actual Android package name.

### Step 2: Update Package Name in Code

Edit `/lib/services/subscription_validation_service.dart`:

```dart
// Line 78: Update with your actual package name
const packageName = 'com.your.actual.package';
```

### Step 3: Deploy Firestore Security Rules

```bash
firebase deploy --only firestore:rules
```

This will deploy the updated security rules that prevent users from writing subscription data directly.

### Step 4: Deploy Cloud Functions

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

This will deploy:
- `validateAppleReceipt` - Validates iOS purchases
- `validateGooglePlayPurchase` - Validates Android purchases
- `restorePurchases` - Restores previous purchases
- `validateAllSubscriptions` - Daily subscription check (scheduled)
- `notifyExpiringSubscriptions` - Daily expiry notifications (scheduled)

---

## Testing

### Testing on iOS (Sandbox)

1. **Create Sandbox Test Users:**
   - Go to **App Store Connect** → **Users and Access** → **Sandbox Testers**
   - Click **+** to create test users
   - Use unique email addresses (can be fake, e.g., test1@test.com)

2. **Sign Out of Real Apple ID:**
   - On your iOS device: Settings → App Store → Sign Out

3. **Run the App:**
   - Install the app from Xcode (not TestFlight)
   - When prompted to purchase, sign in with sandbox test account
   - Purchases will be free in sandbox mode

4. **Testing Scenarios:**
   - ✅ Purchase Premium 1
   - ✅ Purchase Premium 2
   - ✅ Purchase Lifetime
   - ✅ Restore purchases
   - ✅ Upgrade from Premium 1 to Premium 2
   - ✅ Cancel subscription (Manage Subscriptions in Settings)

### Testing on Android (Internal Testing)

1. **Create Internal Testing Track:**
   - Go to **Google Play Console** → **Testing** → **Internal testing**
   - Create a new release
   - Upload your APK/AAB
   - Add test users (their Gmail addresses)

2. **Enable License Testing:**
   - Go to **Setup** → **License testing**
   - Add test Gmail accounts
   - Set license response to **RESPOND_NORMALLY**

3. **Install from Play Store:**
   - Send testers the opt-in link
   - They must opt-in and install from Play Store
   - Sandbox mode: Purchases are free for test accounts

4. **Testing Scenarios:**
   - ✅ Purchase Premium 1
   - ✅ Purchase Premium 2
   - ✅ Purchase Lifetime
   - ✅ Cancel subscription (Google Play → Subscriptions)
   - ✅ Validate server-side receipt

### Testing Cloud Functions Locally

```bash
firebase emulators:start --only functions,firestore
```

Then update your Flutter app to point to the emulator:

```dart
// In main.dart (debug mode only)
if (kDebugMode) {
  FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
}
```

---

## Deployment

### Step 1: Final Code Review

- [ ] Remove any debug/testing overrides
- [ ] Verify all product IDs match store configuration
- [ ] Confirm package name is correct
- [ ] Check Firebase config is set

### Step 2: Deploy Backend

```bash
# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Cloud Functions
firebase deploy --only functions

# Verify deployment
firebase functions:log
```

### Step 3: Build and Upload Apps

**iOS:**
```bash
cd ios
pod install
cd ..
flutter build ipa --release
```

Upload to App Store Connect via Xcode or Transporter.

**Android:**
```bash
flutter build appbundle --release
```

Upload to Google Play Console.

### Step 4: Submit for Review

1. **Apple**: Submit app for review with in-app purchases
2. **Google**: Submit app to production track
3. Monitor review status (usually 1-3 days)

### Step 5: Monitor and Verify

After launch, monitor:
- Firebase Functions logs: `firebase functions:log`
- Firestore subscription documents
- User complaints/support tickets
- Revenue in store dashboards

---

## Common Issues & Solutions

### Issue: "Product not found" error

**Solution:**
- Verify product IDs match exactly between code and store
- Ensure products are approved in store
- For iOS, clear app data and reinstall
- For Android, wait 2-4 hours after creating products

### Issue: Server validation fails

**Solution:**
- Check Firebase Functions logs: `firebase functions:log`
- Verify environment variables are set: `firebase functions:config:get`
- Ensure service account has correct permissions (Google Play)
- Check Apple shared secret is correct

### Issue: Subscription not updating in app

**Solution:**
- Check Firestore security rules allow Cloud Function writes
- Verify user is authenticated
- Check real-time listener is active in subscription_controller.dart
- Force refresh: Pull to refresh on subscription screen

### Issue: Scheduled functions not running

**Solution:**
- Upgrade to Firebase Blaze (pay-as-you-go) plan
- Verify functions are deployed: `firebase functions:list`
- Check Cloud Scheduler in Google Cloud Console
- Enable Cloud Scheduler API if needed

---

## Support & Resources

### Official Documentation
- [Apple In-App Purchase](https://developer.apple.com/in-app-purchase/)
- [Google Play Billing](https://developer.android.com/google/play/billing)
- [Firebase Cloud Functions](https://firebase.google.com/docs/functions)
- [Flutter in_app_purchase](https://pub.dev/packages/in_app_purchase)

### Price Tiers
- [Apple Pricing Matrix](https://developer.apple.com/help/app-store-connect/reference/app-store-pricing)
- [Google Play Pricing](https://support.google.com/googleplay/android-developer/table/3541286)

### Testing
- [Apple Sandbox Testing](https://developer.apple.com/documentation/storekit/in-app_purchase/testing_in-app_purchases_with_sandbox)
- [Google Play Testing](https://developer.android.com/google/play/billing/test)

---

## Checklist

### Pre-Launch
- [ ] Apple products created and approved
- [ ] Google Play products created and activated
- [ ] Firebase config variables set
- [ ] Firestore security rules deployed
- [ ] Cloud Functions deployed and tested
- [ ] Sandbox testing complete (iOS)
- [ ] Internal testing complete (Android)
- [ ] Subscription UI tested
- [ ] Purchase flow works end-to-end
- [ ] Server validation works
- [ ] Restore purchases works

### Launch
- [ ] App submitted to App Store
- [ ] App submitted to Google Play
- [ ] Monitoring alerts set up
- [ ] Support documentation ready
- [ ] Pricing confirmed
- [ ] Subscription benefits clearly communicated

### Post-Launch
- [ ] Monitor daily subscription validation logs
- [ ] Check for failed validations
- [ ] Review user feedback
- [ ] Track conversion rates
- [ ] Monitor revenue
- [ ] Handle refund requests

---

**Created**: January 2025
**App Version**: 1.1.0+13
**Last Updated**: 2025-01-XX

For questions or issues, contact the development team.
