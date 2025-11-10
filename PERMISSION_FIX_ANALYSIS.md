# Permission Request Issues - Root Cause Analysis & Fix

## Problem Summary
User reports that notification permission is being requested **when the app starts**, not during onboarding. All three onboarding screens show "Permission Granted" without showing Android system dialogs.

## Root Causes Identified

### Issue 1: Notification Permission Requested on App Startup
**Location:** `lib/screens/login_screen.dart:233`

```dart
// Lines 225-243
final status = await Permission.notification.request();
```

This is being called after login/signup when navigating to the home screen, **BEFORE** the onboarding flow.

### Issue 2: Deprecated Method Still Being Called
**Location:** `lib/services/permission_manager.dart:79`

The deprecated `requestAllPermissions()` method calls:
```dart
final localPermissions = await LocalNotificationService.requestPermissions();
```

This method is marked as `@Deprecated` but might still be called somewhere in the codebase.

### Issue 3: Permission Status Checks Return Cached Values
According to Flutter permission_handler best practices and the official examples, calling `.request()` directly **will show the system dialog** unless:
1. The permission is already granted (Android caches this)
2. The permission is permanently denied
3. The app doesn't have proper Info.plist entries (iOS only)

**Current Problem:** The user's device likely has permissions cached as "granted" from previous app installations/tests.

## Key Insights from Research

### From Official permission_handler Documentation:
1. **Simple pattern works best:**
   ```dart
   final status = await Permission.notification.request();
   ```
   This **automatically shows the system dialog** if permission is not granted.

2. **Do NOT check status before requesting:**
   The old pattern (check status → request if not granted) can cause issues with cached status values.

3. **Permanently denied handling:**
   Only after getting `isPermanentlyDenied` should you redirect to settings:
   ```dart
   if (status.isPermanentlyDenied) {
     await openAppSettings();
   }
   ```

### Best Practices from 2024 Research:
1. **Explain why you need permission** - Show rationale BEFORE requesting
2. **Request contextually** - Request when user performs action needing permission
3. **Handle errors gracefully** - Don't crash if denied
4. **Platform-specific handling** - iOS needs Info.plist descriptions

## Why Current Implementation Fails

### Problem with OnboardingController
Even though we removed status checks, the `LocalNotificationService.requestPermissions()` method we're calling is designed for **Android only**:

```dart
// lib/services/local_notification_service.dart:492-542
final AndroidFlutterLocalNotificationsPlugin? androidImplementation = ...
if (androidImplementation != null) {
  granted = await androidImplementation.requestNotificationsPermission() ?? false;
}
```

This method:
1. Returns immediately if permission is already granted (cached by Android)
2. Doesn't work on iOS (returns false)
3. Is designed for the old flow, not onboarding

### Problem with Activity Permission
The code calls:
```dart
final status = await Permission.activityRecognition.request();
```

This SHOULD show the dialog, but returns immediately with `isGranted = true` if the permission was previously granted and cached.

## The Real Issue: Permission Caching

Android (and iOS) cache permission status in system memory. Even after:
- Uninstalling the app
- Running `adb shell pm clear`
- Revoking in Settings

**The permission status can remain cached** until:
1. Device reboot
2. System cache is cleared
3. App is signed with different signature

This is why user sees "Already Granted" - the permissions ARE actually granted at the OS level.

## Solution

### 1. Remove Login Screen Permission Request
The notification permission request in `login_screen.dart` needs to be removed entirely. Permissions should ONLY be requested during onboarding.

### 2. Use permission_handler Directly (Not LocalNotificationService)
Instead of calling `LocalNotificationService.requestPermissions()`, the onboarding should call `Permission.notification.request()` directly.

### 3. Don't Check Status Before Requesting
The official pattern is simply:
```dart
final status = await Permission.notification.request();
```

If permission is already granted, this returns immediately with `isGranted = true` without showing dialog (by design).

### 4. For Testing: Force Permission Revocation
To properly test, user needs to:
```bash
# Uninstall app completely
adb uninstall com.health.stepzsync.stepzsync

# Clear all app data from system
adb shell pm clear com.health.stepzsync.stepzsync

# Reboot device to clear permission cache
adb reboot

# After reboot, install fresh APK
flutter install
```

## Recommended Fix

### File: `lib/controllers/onboarding_controller.dart`

Change notification permission request to use permission_handler directly:

```dart
/// Request notification permission (Screen 1)
Future<void> requestNotificationPermission() async {
  if (isRequesting.value) return;

  isRequesting.value = true;

  try {
    // Request permission using permission_handler directly
    final status = await Permission.notification.request();

    if (status.isGranted) {
      notificationGranted.value = true;
      await OnboardingService.resetDenialCount(PermissionType.notification);

      Get.snackbar(
        'Permission Granted',
        'You\'ll now receive important race updates',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF27AE60),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      await Future.delayed(const Duration(milliseconds: 500));
      moveToNextScreen();
    } else if (status.isPermanentlyDenied) {
      await _showSettingsRedirect(PermissionType.notification);
    } else {
      await _handleNotificationDenied();
    }
  } catch (e) {
    print('Error requesting notification permission: $e');
    _showPermissionExplanation(PermissionType.notification);
  } finally {
    isRequesting.value = false;
  }
}
```

### File: `lib/screens/login_screen.dart`

Remove the entire notification permission request block (lines 225-243).

### File: `lib/services/permission_manager.dart`

Ensure `requestAllPermissions()` is never called during app startup. It should only be used in specific contexts after onboarding.

## Expected Behavior After Fix

### On Fresh Install (No Permissions Granted):
1. User opens app → Splash → Onboarding Screen 1 (Notifications)
2. User taps "Enable Notifications"
3. **Android system dialog appears**
4. User grants/denies
5. Move to Screen 2 (Activity Recognition)
6. User taps "Enable Step Tracking"
7. **Android system dialog appears**
8. Continue to Screen 3 (Health)

### On Subsequent Opens (Permissions Already Granted):
1. User opens app → Splash → **Skip onboarding** → Home Screen
2. No permission requests (already completed)

### On Subsequent Opens (Permissions Denied/Revoked):
1. User opens app → Splash → Onboarding (shows again)
2. Requests permissions again

## Testing on Device with Cached Permissions

If permissions are already granted on the test device, the system dialogs **will NOT appear** (this is correct Android/iOS behavior).

To test properly:
1. Completely uninstall app
2. Reboot device
3. Install fresh APK
4. First launch should show all permission dialogs

## Summary of Changes Needed

1. ✅ Already done: Removed status checks in OnboardingController
2. ✅ Already done: Disabled PedometerPermissionMonitor auto-checks
3. ✅ Already done: Disabled LocalNotificationService auto-request
4. ❌ **TO DO**: Remove permission request from `login_screen.dart`
5. ❌ **TO DO**: Change OnboardingController to use `Permission.notification.request()` instead of `LocalNotificationService.requestPermissions()`
6. ❌ **TO DO**: Verify `permission_manager.requestAllPermissions()` is not called during startup
