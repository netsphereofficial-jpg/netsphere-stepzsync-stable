# Design: 7-Day Free Trial for Subscriptions

## Context

iOS App Store already has 7-day free trials configured as introductory offers on `premium_1_monthly` and `premium_1_yearly`. Google Play needs matching trial configuration. Server-side validation (Cloud Functions) and Dart model do not currently persist trial state to Firestore.

## Products with Trial

| Product ID | Platform | Trial |
|---|---|---|
| `premium_1_monthly` | iOS + Android | 7-day free |
| `premium_1_yearly` | iOS + Android | 7-day free |
| `premium_lifetime_onetime` | iOS + Android | No trial (one-time) |

## Part 1: Google Play Console (Manual)

For both `premium_1_monthly` and `premium_1_yearly` base plans:
- Base plan -> Offers -> Add offer
- Offer type: Free trial
- Duration: 7 days
- Eligibility: New customers (one trial per Google account)

## Part 2: Code Changes

### A. `functions/subscriptions/validators/googleValidator.js`
- Add `isTrialPeriod: paymentState === 2` to `validateGooglePlayPurchase` return object
- Google's paymentState 2 = free_trial

### B. `functions/subscriptions/triggers/purchaseValidation.js`
- Apple path: add `isTrialPeriod: validationResult.isTrialPeriod || false` to subscriptionData
- Google path: add `isTrialPeriod: validationResult.isTrialPeriod || false` to subscriptionData

### C. `lib/models/subscription_models.dart`
- Add `final bool isTrialPeriod;` field to `UserSubscription`
- Parse from Firestore in `fromFirebaseMap()` with `?? false` default
- Write to Firestore in `toFirebaseMap()`
- Include in `copyWith()` and `free()` factory

### D. `scripts/setup_google_play_products.js`
- Add `offerPhases` with 7-day free trial to both subscription configs

## Unchanged Files
- `appleValidator.js` -- already returns `isTrialPeriod`
- `payment_service.dart` -- store purchase sheets handle trial UI natively
- `scheduledValidation.js` -- trial users have `active` status, no special handling

## iOS Backward Compatibility
- Existing `premium_1_monthly` purchases unchanged
- `isTrialPeriod` defaults to `false` for existing Firestore docs
- Apple validator already parses `is_trial_period` correctly
