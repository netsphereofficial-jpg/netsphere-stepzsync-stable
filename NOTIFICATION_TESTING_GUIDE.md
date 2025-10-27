# Cloud Functions Push Notification Testing Guide

## 📋 Overview

This guide explains how to test the new server-side push notification system implemented using Firebase Cloud Functions. The system is currently in **Phase 1 (Testing)** before full migration from client-side to server-side notifications.

## 🎯 What's Been Implemented

### 1. **FCM Service Module** (`functions/notifications/core/fcmService.js`)
   - Core notification sending functionality
   - Handles both iOS (APNS) and Android (FCM) platforms
   - Functions:
     - `sendNotification(fcmToken, notification, data)` - Send to single device
     - `sendNotificationToUser(userId, notification, data)` - Send to user by userId
     - `sendBatchNotifications(notifications)` - Send to multiple devices
     - `sendNotificationToUsers(userIds, notification, data)` - Send to multiple users

### 2. **Test Endpoints** (`functions/notifications/test/testNotification.js`)
   - 4 callable Cloud Functions for testing:
     - `testNotification` - Send custom notification to userId or FCM token
     - `testNotificationHTTP` - HTTP endpoint for testing
     - `quickTestNotification` - Quick test to specific FCM token
     - `testNotificationToMe` - Test notification to authenticated user

### 3. **Flutter Test Screen** (`lib/screens/test/notification_test_screen.dart`)
   - User-friendly UI for testing Cloud Functions notifications
   - Features:
     - Display current user ID and FCM token
     - Quick test button for instant notification
     - Custom notification form (title + body)
     - Result display with success/error messages
     - Copy FCM token to clipboard

## 🚀 How to Test

### Method 1: Using Flutter Test Screen (Recommended)

1. **Add Test Screen to Your App Navigation**

   First, add the test screen import to your home screen or settings:

   ```dart
   import 'package:stepzsync/screens/test/notification_test_screen.dart';

   // In your settings or debug menu:
   ListTile(
     leading: Icon(Icons.notifications_active),
     title: Text('Test Push Notifications'),
     onTap: () => Get.to(() => NotificationTestScreen()),
   )
   ```

2. **Navigate to Test Screen**
   - Open the app on your iOS device
   - Navigate to the test screen
   - Your User ID and FCM token will be displayed

3. **Run Quick Test**
   - Click **"Send Test Notification"** button
   - Check your device for the notification (should appear even in foreground)

4. **Run Custom Test**
   - Enter a custom title (e.g., "Hello World")
   - Enter a custom body (e.g., "Testing Cloud Functions!")
   - Click **"Send Custom Notification"**
   - Notification should appear on your device

### Method 2: Using Firebase Console

1. **Go to Firebase Console**
   - Open https://console.firebase.google.com/project/stepzsync-750f9/functions

2. **Find the Function**
   - Locate `testNotificationToMe` function
   - Click on it → "Testing" tab

3. **Call the Function**
   - Make sure you're logged in to the app
   - Click "Run the function" (no parameters needed)
   - Check your device for notification

### Method 3: Using HTTP Endpoint (for advanced testing)

```bash
# Get your current user's ID and test
curl -X POST https://us-central1-stepzsync-750f9.cloudfunctions.net/testNotificationHTTP \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "YOUR_USER_ID_HERE",
    "title": "Test from cURL",
    "body": "This is a test notification from command line"
  }'
```

## 📱 Expected Behavior

### ✅ Success Indicators:
1. **Console Logs:**
   ```
   🧪 Testing notification to authenticated user...
   📤 Sending notification to token: xxxxx...
   ✅ Notification sent successfully: projects/stepzsync-750f9/messages/xxxxx
   ```

2. **Device Notification:**
   - Notification appears with title and body
   - Shows even when app is in foreground
   - Sound and badge should work
   - Tapping notification should work (no navigation yet)

3. **Flutter UI:**
   - Success message displays in green box
   - Shows message ID from FCM
   - Snackbar appears: "Notification sent! Check your device."

### ❌ Possible Errors:

#### Error: "User has no FCM token"
**Cause:** FCM token not saved to Firestore
**Fix:**
- Log out and log back in to the app
- Check Firestore `user_profiles/{userId}` for `fcmToken` field
- If missing, run the app and it should save automatically

#### Error: "Invalid or expired FCM token"
**Cause:** Token was invalidated
**Fix:**
- Delete the app and reinstall
- Log in again to generate new FCM token

#### Error: "User not authenticated"
**Cause:** Not logged in
**Fix:** Make sure you're logged in to the app

## 🔍 Debugging

### Check FCM Token in Firestore
1. Open Firebase Console → Firestore Database
2. Navigate to `user_profiles/{your_user_id}`
3. Verify `fcmToken` field exists and has a value
4. Check `fcmTokenUpdatedAt` timestamp

### Check Cloud Function Logs
1. Open Firebase Console → Functions
2. Click on any test function
3. Go to "Logs" tab
4. Look for:
   - `📤 Sending notification to token: ...`
   - `✅ Notification sent successfully: ...`
   - Or error messages starting with `❌`

### Check iOS Device Logs
1. Open Xcode → Window → Devices and Simulators
2. Select your device
3. Open Console
4. Filter for "stepzsync" or "FCM"
5. Look for notification delivery logs

## 📊 Testing Checklist

Before moving to Phase 2 (Migration), verify:

- [ ] Notifications appear when app is in **foreground**
- [ ] Notifications appear when app is in **background**
- [ ] Notifications appear when app is **closed/terminated**
- [ ] Notification sound works correctly
- [ ] Notification badge works correctly
- [ ] FCM tokens are being saved to Firestore consistently
- [ ] Multiple users can receive notifications simultaneously
- [ ] Invalid tokens are handled gracefully (no crashes)
- [ ] Cloud Functions complete within 2-5 seconds
- [ ] No errors in Cloud Function logs

## 📈 Success Metrics (Phase 1)

Target metrics for this testing phase:

- **Delivery Rate:** 100% (all sent notifications delivered)
- **Latency:** < 2 seconds (from function call to notification received)
- **Error Rate:** < 1% (handling invalid tokens gracefully)
- **Foreground Display:** 100% (notifications visible even in foreground)

## 🔄 Next Steps (Phase 2 - Partial Migration)

Once testing is successful:

1. **Create Firestore Triggers**
   - Trigger notifications automatically on friend requests
   - Trigger notifications on race invites
   - Trigger notifications on race start

2. **Remove Client-Side Notification Code**
   - Gradually remove LocalNotificationService calls
   - Replace with Cloud Function triggers
   - Measure app size reduction

3. **Add Notification Queue**
   - Implement retry logic for failed notifications
   - Add batch processing for multiple recipients
   - Monitor queue performance

## 🛠️ Troubleshooting

### Notification Not Appearing

1. **Check Notification Permissions**
   ```dart
   // In Flutter, verify permissions
   final status = await Permission.notification.status;
   print('Notification permission: $status');
   ```

2. **Check iOS Settings**
   - Settings → Notifications → StepzSync
   - Ensure "Allow Notifications" is enabled
   - Check alert style is set to "Banners" or "Alerts"

3. **Check UNUserNotificationCenter Delegate**
   - Verify `ios/Runner/AppDelegate.swift` has:
   ```swift
   UNUserNotificationCenter.current().delegate = self
   ```

### Cloud Function Timing Out

1. **Check Function Logs**
   - Look for timeout errors in Firebase Console → Functions → Logs

2. **Verify FCM Token Validity**
   - Invalid tokens can cause delays
   - Check Firestore for valid `fcmToken` values

3. **Monitor Function Execution Time**
   - Should complete within 2-5 seconds
   - If longer, check network connectivity

## 📞 Testing Support

If you encounter issues:

1. **Check Firestore:** Verify `fcmToken` exists in `user_profiles/{userId}`
2. **Check Logs:** Review Cloud Function logs in Firebase Console
3. **Check Device:** Ensure notification permissions are granted
4. **Test Token:** Use `quickTestNotification` with known-good FCM token

## 🎉 Success Criteria

You've successfully completed Phase 1 testing when:

✅ You can send notifications from Cloud Functions
✅ Notifications appear on your physical iOS device
✅ Notifications work in foreground, background, and terminated states
✅ No errors in Cloud Function logs
✅ FCM tokens are consistently saved to Firestore
✅ Test screen works correctly

Once all criteria are met, you're ready for **Phase 2: Partial Migration** of notification logic to server-side! 🚀

---

## 📁 Project Structure

```
functions/
├── notifications/
│   ├── core/
│   │   └── fcmService.js          # Core FCM sending logic
│   └── test/
│       └── testNotification.js    # Test endpoints
└── index.js                       # Main exports

lib/
└── screens/
    └── test/
        └── notification_test_screen.dart  # Flutter test UI
```

## 🔗 Deployed Functions

All functions are deployed to: `us-central1-stepzsync-750f9`

- `testNotification` (callable)
- `testNotificationHTTP` (HTTP)
- `quickTestNotification` (callable)
- `testNotificationToMe` (callable)

---

**Last Updated:** 2025-10-10
**Phase:** 1 (Testing)
**Status:** Ready for Testing ✅
