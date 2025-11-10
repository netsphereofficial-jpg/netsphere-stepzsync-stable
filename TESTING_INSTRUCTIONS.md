# Testing Onboarding Flow

## Problem
The onboarding screens are showing "Permission Granted" without asking because:
1. Permissions are already granted on your test device
2. The onboarding controller checks permission status BEFORE requesting

## Solution

### Step 1: Clear App Data (Revoke Permissions)

**Option A: Via Android Settings (Recommended)**
1. Open Settings → Apps → StepzSync
2. Tap "Permissions"
3. For each permission (Notifications, Physical Activity):
   - Tap the permission
   - Select "Don't allow" or "Deny"
4. Go back to Apps → StepzSync → Storage
5. Tap "Clear Data" (this clears SharedPreferences including onboarding status)
6. Restart the app

**Option B: Via ADB Command (Faster)**
```bash
# Clear app data and revoke permissions
adb shell pm clear com.health.stepzsync.stepzsync

# Or manually revoke specific permissions
adb shell pm revoke com.health.stepzsync.stepzsync android.permission.POST_NOTIFICATIONS
adb shell pm revoke com.health.stepzsync.stepzsync android.permission.ACTIVITY_RECOGNITION
```

### Step 2: Run the App
```bash
flutter run
```

### Step 3: Test Each Screen

**Screen 1: Notification Permission**
- Should show notification permission screen
- Tap "Enable Notifications"
- Android system dialog should appear asking for notification permission
- Grant permission
- Should move to next screen automatically

**Screen 2: Activity Recognition Permission** (MANDATORY)
- Should show activity tracking screen
- Tap "Enable Step Tracking"
- Android system dialog should appear asking for physical activity permission
- Grant permission
- Should move to next screen automatically

**Screen 3: Health Connect Permission** (OPTIONAL)
- Should show health connection screen
- Tap "Connect Health" to grant, or "Skip for Now" to skip
- If Health Connect app is installed, should show Health Connect permission screen
- Complete or skip

**After All Screens:**
- Should navigate to AuthWrapper (login screen)
- No more permission prompts should appear

## What Was Fixed

### 1. LocalNotificationService (lib/services/local_notification_service.dart)
- Removed automatic permission request from `initialize()` method
- Set iOS DarwinInitializationSettings to NOT auto-request permissions
- Permissions now only requested via onboarding

### 2. PedometerPermissionMonitor (lib/services/pedometer_permission_monitor.dart)
- Disabled automatic permission checking every 2 seconds
- Disabled showing permission dialog automatically
- Disabled checks on app resume
- Now only checks silently to set initial state

### 3. OnboardingController (lib/controllers/onboarding_controller.dart)
- Added status checks BEFORE requesting to avoid re-requesting granted permissions
- Added try-catch error handling
- Only shows system dialog if permission is not already granted

## Expected Logs

When testing, you should see logs like:
```
🔔 LocalNotificationService initialized: true
ℹ️ Notification permissions will be requested during onboarding
ℹ️ Activity recognition permission not granted - will be requested in onboarding
✅ PedometerPermissionMonitor: Initialized (auto-checks disabled for onboarding)
```

You should NOT see:
```
🔔 Requesting notification permissions...
⚠️ Activity recognition permission not granted (permanently denied: false)
🚨 Showing pedometer permission dialog
```

## If Onboarding Still Doesn't Show

Run this Dart code in your app to force-reset onboarding:

```dart
import 'package:shared_preferences/shared_preferences.dart';

Future<void> resetOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_completed', false);
  await prefs.setInt('notification_permission_denied_count', 0);
  await prefs.setInt('activity_permission_denied_count', 0);
  await prefs.setInt('health_permission_denied_count', 0);
  print('✅ Onboarding reset - restart app');
}
```

Or use this ADB command to clear only SharedPreferences:
```bash
adb shell run-as com.health.stepzsync.stepzsync rm -rf /data/data/com.health.stepzsync.stepzsync/shared_prefs
```

## Troubleshooting

### Issue: "Permission Granted" popup without system dialog
**Cause:** Permissions already granted on device
**Fix:** Clear app data or revoke permissions manually (see Step 1)

### Issue: Onboarding screens not showing at all
**Cause:** Onboarding marked as completed in SharedPreferences
**Fix:** Clear app data or reset onboarding status (see above)

### Issue: System dialog not appearing
**Cause:** Permission status check returning "already granted"
**Fix:** Revoke permissions in Android Settings before testing

## Production Behavior

In production (user's first install):
1. User installs app → No permissions granted
2. User opens app → Splash screen → Onboarding screens
3. User grants permissions on each screen
4. Onboarding completes → Never shows again
5. If user revokes permissions → Onboarding shows again
