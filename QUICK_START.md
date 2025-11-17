# StepzSync Subscription - Quick Start Guide

## ⚡ 5-Minute Setup Overview

### Your 3 Subscription Plans

1. **Free** - City races only
2. **Premium 1 (Countrywide)** - $9.99/month - Product ID: `premium_1_monthly`
3. **Premium 2 (Worldwide)** - $19.99/month - Product ID: `premium_2_monthly`
4. **Lifetime Premium** - $299 one-time - Product ID: `lifetime_premium`

### Payment Method

You're using **App Store (iOS)** and **Google Play (Android)** - these are the ONLY allowed payment methods for in-app subscriptions per Apple and Google policies.

**NOT** using direct Apple Pay/Google Pay buttons - those are only for physical goods or services outside app stores.

---

## ✅ What's Already Done

- ✅ All code implemented and tested
- ✅ Server-side validation (Cloud Functions)
- ✅ Security rules deployed
- ✅ Client integration complete
- ✅ Subscription UI ready
- ✅ Documentation complete

---

## 🚀 What You Need to Do (30 minutes)

### Step 1: Configure Firebase (5 min)

```bash
# Set Apple shared secret
firebase functions:config:set apple.shared_secret="YOUR_SECRET_FROM_APP_STORE_CONNECT"

# Set Google Play service account
firebase functions:config:set google.play_service_account="$(cat service-account.json | jq -c .)"

# Set Android package name
firebase functions:config:set android.package_name="com.stepzsync.app"

# Deploy functions
firebase deploy --only functions
```

### Step 2: App Store Connect (10 min)

1. Create 3 in-app purchases:
   - `premium_1_monthly` - $9.99/month (auto-renewable subscription)
   - `premium_2_monthly` - $19.99/month (auto-renewable subscription)
   - `lifetime_premium` - $299 (non-consumable)

2. Get shared secret: App Information → App-Specific Shared Secret

3. Submit for review

### Step 3: Google Play Console (15 min)

1. Create 2 subscriptions:
   - `premium_1_monthly` - $9.99/month
   - `premium_2_monthly` - $19.99/month

2. Create 1 in-app product:
   - `lifetime_premium` - $299

3. Set up service account:
   - Google Cloud Console → Create Service Account
   - Download JSON key
   - Grant API access in Play Console

4. Enable Google Play Developer API

---

## 📱 Testing (30 minutes)

### iOS Sandbox
1. Create test user in App Store Connect
2. Sign out of real Apple ID
3. Install from Xcode
4. Test purchase (free in sandbox)

### Android Internal Testing
1. Upload APK to internal track
2. Add test Gmail accounts
3. Install from Play Store link
4. Test purchase (free for test accounts)

---

## 📄 Full Documentation

- **SUBSCRIPTION_SETUP_GUIDE.md** - Complete setup guide (every detail)
- **SUBSCRIPTION_IMPLEMENTATION_SUMMARY.md** - What was implemented
- **FIREBASE_CONFIG_COMMANDS.sh** - Configuration helper script

---

## 🆘 Quick Troubleshooting

**"Product not found"**
→ Product IDs must match exactly: `premium_1_monthly`, `premium_2_monthly`, `lifetime_premium`

**"Validation failed"**
→ Check Firebase config: `firebase functions:config:get`
→ Check logs: `firebase functions:log`

**"No purchases to restore"**
→ Normal if user hasn't purchased anything yet

**Scheduled functions not running**
→ Upgrade to Firebase Blaze plan (required for scheduled functions)

---

## 📞 Need Help?

1. Read **SUBSCRIPTION_SETUP_GUIDE.md** (comprehensive guide)
2. Check Firebase Functions logs
3. Verify product IDs match in stores and code
4. Confirm Firebase config is set

---

## 🎯 Launch Checklist

- [ ] Firebase config set ✓
- [ ] Cloud Functions deployed ✓
- [ ] App Store products created ⏳
- [ ] Play Store products created ⏳
- [ ] Service accounts configured ⏳
- [ ] iOS sandbox tested ⏳
- [ ] Android internal tested ⏳
- [ ] App submitted for review ⏳

---

**You're almost there!** 🎉

The hardest part (code implementation) is done. Just need to configure the app stores!
