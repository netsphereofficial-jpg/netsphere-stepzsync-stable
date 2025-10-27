# AdMob Rewarded Ads Setup Guide - StepzSync

## Overview
Free users must watch a rewarded video ad before viewing race results. Premium users get direct access.

## ✅ Completed Implementation

### 1. **Package Installation**
- ✅ Added `google_mobile_ads: ^5.2.0` to `pubspec.yaml`
- ✅ Installed dependencies with `flutter pub get`

### 2. **Service Architecture**
- ✅ Created `AdMobService` (`lib/services/admob_service.dart`)
  - Singleton pattern for efficient ad management
  - Handles ad loading, showing, and callbacks
  - Automatic ad preloading after each view
  - Graceful error handling

### 3. **Premium User Check**
- ✅ Integrated with `FirebaseSubscriptionService`
- ✅ Checks `currentSubscription.value.isPremium`
- ✅ Premium users bypass ads completely

### 4. **Ad Gate Implementation**
- ✅ Added ad gate in `RaceMapScreen` "View Results" button
- ✅ Shows loading dialog while ad loads
- ✅ Displays rewarded video ad
- ✅ Grants access only after ad completion
- ✅ Fallback: Shows results if ad fails to load (better UX)

### 5. **Initialization**
- ✅ AdMob initialized in `main.dart` during app startup
- ✅ First ad preloaded in background
- ✅ Non-blocking initialization (doesn't slow app startup)

---

## 🚀 Setup Instructions

### Step 1: Create AdMob Account & App

1. Go to https://apps.admob.com/
2. Sign in with your Google account
3. Click **"Apps"** → **"Add App"**
4. Choose platform (Android/iOS)
5. Enter app details:
   - App name: **StepzSync**
   - Add your Play Store URL (Android) or App Store URL (iOS)

### Step 2: Create Rewarded Ad Units

#### For Android:
1. In AdMob dashboard, select your Android app
2. Click **"Ad units"** → **"Add ad unit"**
3. Select **"Rewarded"**
4. Configure:
   - Ad unit name: `race_results_rewarded`
   - Reward amount: 1
   - Reward item: "access"
5. Copy the **Ad Unit ID** (format: `ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY`)

#### For iOS:
1. Repeat the same process for your iOS app
2. Copy the iOS **Ad Unit ID**

### Step 3: Update Ad Unit IDs

Edit `lib/services/admob_service.dart`:

```dart
static String get _rewardedAdUnitId {
  if (Platform.isAndroid) {
    // Replace with your Android rewarded ad unit ID
    return 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY'; // 👈 CHANGE THIS
  } else if (Platform.isIOS) {
    // Replace with your iOS rewarded ad unit ID
    return 'ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ'; // 👈 CHANGE THIS
  }
  throw UnsupportedError('Unsupported platform');
}
```

### Step 4: Add AdMob App ID to Native Config

#### ✅ Android (`android/app/src/main/AndroidManifest.xml`) - ALREADY CONFIGURED:
```xml
<!-- AdMob App ID (Test ID - Replace with your real App ID in production) -->
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-3940256099942544~3347511713"/>
```

**Current status:** Using **test App ID** for development.

**To update for production:**
1. Get your Android App ID from AdMob dashboard
2. Replace the value in `android/app/src/main/AndroidManifest.xml` (line 46)
3. Change from `ca-app-pub-3940256099942544~3347511713` to your real App ID

#### ✅ iOS (`ios/Runner/Info.plist`) - ALREADY CONFIGURED:
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~1458002511</string>
<key>SKAdNetworkItems</key>
<array>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>cstr6suwn9.skadnetwork</string>
    </dict>
</array>
```

**Current status:** Using **test App ID** for development.

**To update for production:**
1. Get your iOS App ID from AdMob dashboard
2. Replace the value in `ios/Runner/Info.plist` (line 70)
3. Change from `ca-app-pub-3940256099942544~1458002511` to your real App ID

**Get your App IDs:**
- Android App ID: In AdMob → Apps → Select app → "App settings"
- iOS App ID: Same process for iOS app

**Note:** The app is currently configured with **Google's official test App IDs**, so it will work without crashing and show test ads.

### Step 5: Update Build Configurations

#### Android (`android/app/build.gradle`):
Ensure minimum SDK version is 21+:
```gradle
android {
    defaultConfig {
        minSdkVersion 21  // Must be 21 or higher
    }
}
```

#### iOS (`ios/Podfile`):
Ensure platform is iOS 12.0+:
```ruby
platform :ios, '12.0'
```

Then run:
```bash
cd ios && pod install && cd ..
```

---

## 🧪 Testing

### Test with Demo Ads (Current Setup)
The app is currently using **test ad unit IDs** which show demo ads:
- Android: `ca-app-pub-3940256099942544/5224354917`
- iOS: `ca-app-pub-3940256099942544/1712485313`

**To test:**
1. Hot restart the app: `flutter run`
2. Complete a race
3. Tap **"View results"** button
4. Should show:
   - "Loading ad..." dialog
   - Rewarded video ad (test ad)
   - After watching, shows race results

### Enable Test Device for Production Ads
When using real ad units, enable test mode for your device:

```dart
// In lib/services/admob_service.dart, update loadRewardedAd():
await RewardedAd.load(
  adUnitId: _rewardedAdUnitId,
  request: AdRequest(
    testDevices: ['YOUR_DEVICE_ID'], // 👈 Add your device ID
  ),
  // ... rest of config
);
```

**Find your device ID:**
- Run app and check console logs
- Look for: "Use AdRequest.Builder.addTestDevice("XXXXXXXX") to get test ads"

---

## 🎯 How It Works

### For Free Users:
1. User completes race
2. Taps "View results" button
3. App checks subscription status → **Free user detected**
4. Shows "Loading ad..." dialog
5. Loads rewarded video ad (if not already loaded)
6. Shows rewarded video ad
7. User watches ad completely → **Rewarded**
8. Navigates to RaceWinnersScreen

### For Premium Users:
1. User completes race
2. Taps "View results" button
3. App checks subscription status → **Premium user detected**
4. **Directly** navigates to RaceWinnersScreen ✨

### Error Handling:
- ❌ **Ad fails to load:** Shows message "Ad failed to load. Showing results anyway..." → Shows results (graceful degradation)
- ❌ **User closes ad early:** Shows message "Please watch the ad to view results" → Doesn't show results
- ✅ **Ad watched completely:** Grants access to results

---

## 📊 Monitoring & Analytics

### AdMob Dashboard
Monitor ad performance:
- **Impressions:** How many ads shown
- **eCPM:** Earnings per 1000 impressions
- **Fill rate:** Percentage of ad requests filled
- **Match rate:** How well ads match your app

### Recommended Metrics to Track:
1. **Ad completion rate:** % of users who watch full ad
2. **Free vs Premium users:** Who sees ads
3. **Revenue per free user:** Average earnings
4. **Conversion rate:** Free → Premium after seeing ads

---

## 💰 Monetization Tips

### Optimization Strategies:
1. **Mediation:** Add multiple ad networks for better fill rates
   - Facebook Audience Network
   - Unity Ads
   - AppLovin

2. **Ad frequency caps:** Don't show too many ads
   - Current: 1 ad per race result view
   - Consider: Max 5 ads per day per user

3. **Premium upsell:** Show benefits after ad
   - "Upgrade to Premium to skip ads!"
   - Offer trial periods

4. **A/B testing:** Test different ad placements
   - Before results vs after race
   - Interstitial vs rewarded

---

## 🔐 Privacy & Compliance

### GDPR (Europe):
AdMob handles GDPR consent automatically via Google's UMP SDK.

### COPPA (Children's Privacy):
If app targets children under 13, mark in AdMob:
```dart
AdRequest(
  contentUrl: 'your_url',
  keywords: ['racing', 'fitness'],
  nonPersonalizedAds: true, // For COPPA compliance
)
```

### App Store Privacy Labels:
Declare in App Store Connect:
- ✅ Advertising Data collected
- ✅ Device ID for ads
- ✅ Usage data for analytics

---

## 🐛 Troubleshooting

### "Ad failed to load"
**Causes:**
1. Test ad units not replaced with real ones
2. App ID not added to AndroidManifest.xml / Info.plist
3. No internet connection
4. AdMob account not verified

**Solutions:**
1. Check console logs for specific error codes
2. Verify App ID in native configs
3. Wait 24-48 hours after creating new ad units
4. Ensure billing is set up in AdMob

### "Ad shows but doesn't grant reward"
**Cause:** `onUserEarnedReward` callback not firing

**Solution:**
1. Ensure user watches **full ad** (not skipping)
2. Check `AdMobService.showRewardedAd()` return value
3. Add logging in callback to debug

### "Multiple ads showing"
**Cause:** Creating new `AdMobService()` instances

**Solution:**
AdMobService is a **singleton** - always use same instance:
```dart
final adService = AdMobService(); // ✅ Correct - gets singleton
```

---

## 📝 Code References

### Key Files:
1. **Service:** `lib/services/admob_service.dart`
2. **Ad Gate:** `lib/screens/race_map/race_map_screen.dart:2190-2336`
3. **Initialization:** `lib/main.dart:129-139`
4. **Subscription Check:** `lib/services/firebase_subscription_service.dart:207`

### Important Methods:
- `AdMobService.initialize()` - Initialize SDK
- `AdMobService.loadRewardedAd()` - Load ad
- `AdMobService.showRewardedAd()` - Show ad & return reward status
- `_handleViewResults()` - Ad gate logic

---

## 🎓 Next Steps

### Phase 1: Testing (Current)
- ✅ Test with demo ads
- ⏳ Verify ad flow for free users
- ⏳ Verify premium users skip ads
- ⏳ Test error scenarios (no internet, ad fail)

### Phase 2: Production Setup
- ⬜ Create AdMob account
- ⬜ Add app to AdMob
- ⬜ Create rewarded ad units
- ⬜ Update ad unit IDs in code
- ⬜ Add App IDs to native configs
- ⬜ Test with real ads (test mode)

### Phase 3: Launch
- ⬜ Verify GDPR/COPPA compliance
- ⬜ Submit app update with ads
- ⬜ Monitor AdMob dashboard
- ⬜ Track revenue and user behavior
- ⬜ Optimize based on data

### Phase 4: Optimization
- ⬜ Add mediation for better fill rates
- ⬜ Implement frequency capping
- ⬜ A/B test ad placements
- ⬜ Add premium upsell prompts
- ⬜ Analyze conversion metrics

---

## 🆘 Support

### Official Resources:
- AdMob Help Center: https://support.google.com/admob
- Flutter AdMob Plugin: https://pub.dev/packages/google_mobile_ads
- AdMob Best Practices: https://admob.google.com/home/resources/

### Common Questions:
**Q: How much can I earn?**
A: Depends on geography, niche, and ad quality. Typical eCPM: $1-$10.

**Q: When will I get paid?**
A: AdMob pays monthly when you reach $100 threshold.

**Q: Can I use other ad networks?**
A: Yes! Use mediation to add Facebook, Unity, AppLovin, etc.

**Q: Will ads slow down my app?**
A: No - AdMob initialization is non-blocking and ads are preloaded.

---

**Created:** 2025-10-23
**Last Updated:** 2025-10-23
**Version:** 1.0
**Maintainer:** StepzSync Team
