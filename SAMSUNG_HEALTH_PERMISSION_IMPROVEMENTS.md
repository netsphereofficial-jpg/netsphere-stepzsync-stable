# Samsung Health & Health Connect Permission Improvements

## Overview

This document describes the improvements made to health permission handling for Samsung devices and Health Connect integration.

## Problem Statement

Previously, users had to manually:
1. Open Samsung Health app
2. Navigate to Settings > Health Connect
3. Enable data sync
4. Return to StepzSync and grant permissions

This manual process was confusing and led to poor user experience.

## Solution

We've implemented a comprehensive permission handling system that:

✅ **Detects Samsung Health** - Automatically detects if Samsung Health is installed
✅ **Smart Permission Rationale** - Tracks permission denials and shows appropriate UI
✅ **Deep Linking** - Direct links to Samsung Health and Health Connect settings
✅ **Visual Onboarding** - Step-by-step guide for first-time setup
✅ **Contextual Messages** - Samsung-specific instructions when needed

## New Features

### 1. Samsung Health Detection

```dart
final helper = HealthPermissionsHelper();

// Check if Samsung Health is installed
final hasSamsung = await helper.isSamsungHealthInstalled();

// Check if Health Connect is installed
final hasHealthConnect = await helper.isHealthConnectInstalled();
```

### 2. Smart Permission Denial Tracking

The system tracks how many times a user denies permissions:
- **First denial**: Shows standard permission dialog
- **Second denial**: Shows standard permission dialog
- **Third denial onwards**: Directs user to settings instead

```dart
// Check if we should show permission request
final shouldShow = await helper.shouldShowPermissionRequest();

if (shouldShow) {
  // Show permission dialog
  await helper.requestHealthPermissions();
} else {
  // Direct to settings
  await helper.openHealthSettings();
}
```

### 3. Deep Linking Methods

```dart
// Open Health Connect app
await helper.openHealthConnectApp();

// Open Health Connect permissions directly
await helper.openHealthConnectPermissions();

// Open Samsung Health app
await helper.openSamsungHealthApp();

// Open Play Store to install Health Connect
await helper.openHealthConnectInPlayStore();

// Open appropriate health settings (smart method)
await helper.openHealthSettings();
```

### 4. Validation System

```dart
final validation = await helper.validateHealthSetup();

// Check validation result
if (validation.isValid) {
  print('Health sync is ready!');
} else {
  print('Reason: ${validation.reason}');
  print('Message: ${validation.message}');
  print('Has Samsung Health: ${validation.hasSamsungHealth}');

  // Show Samsung Health guide if needed
  if (validation.shouldShowSamsungHealthGuide) {
    // Show onboarding
  }

  // Direct to settings if max denials reached
  if (validation.shouldDirectToSettings) {
    await helper.openHealthSettings();
  }
}
```

## Usage Examples

### Simple Usage (Recommended)

The easiest way to request permissions is using the `HealthPermissionHandlerDialog`:

```dart
import 'package:stepzsync/widgets/dialogs/health_permission_handler_dialog.dart';

// In your button onPressed handler:
final granted = await HealthPermissionHandlerDialog.requestPermissions();

if (granted) {
  print('Permissions granted!');
} else {
  print('Permissions denied or setup incomplete');
}
```

This automatically:
- Validates health setup
- Shows Samsung Health onboarding if needed
- Requests permissions
- Handles denials gracefully
- Provides deep links when needed

### Manual Control

For more control over the flow:

```dart
final helper = HealthPermissionsHelper();

// 1. Validate setup first
final validation = await helper.validateHealthSetup();

// 2. Handle different scenarios
switch (validation.reason) {
  case HealthPermissionValidationReason.healthConnectNotInstalled:
    // Show dialog to install Health Connect
    await helper.openHealthConnectInPlayStore();
    break;

  case HealthPermissionValidationReason.permissionsDenied:
    // Show onboarding if Samsung device
    if (validation.shouldShowSamsungHealthGuide) {
      await SamsungHealthOnboardingDialog.show(
        onContinue: () async {
          await helper.requestHealthPermissions(skipOnboarding: true);
        },
      );
    } else {
      await helper.requestHealthPermissions();
    }
    break;

  case HealthPermissionValidationReason.maxDenialsReached:
    // Direct to settings
    await helper.openHealthSettings();
    break;

  case HealthPermissionValidationReason.valid:
    // Already has permissions!
    print('Ready to sync!');
    break;
}
```

### Show Setup Instructions

```dart
// Show helpful setup instructions
await HealthPermissionHandlerDialog.showSetupInstructions();
```

### In Settings Screen

```dart
// In your app settings screen
ListTile(
  leading: Icon(Icons.health_and_safety),
  title: Text('Health Permissions'),
  subtitle: FutureBuilder<bool>(
    future: helper.hasHealthPermissions(),
    builder: (context, snapshot) {
      final hasPermissions = snapshot.data ?? false;
      return Text(hasPermissions ? 'Enabled' : 'Disabled');
    },
  ),
  trailing: Icon(Icons.chevron_right),
  onTap: () async {
    final hasPermissions = await helper.hasHealthPermissions();

    if (hasPermissions) {
      // Show option to manage or revoke
      await helper.openHealthSettings();
    } else {
      // Request permissions
      await HealthPermissionHandlerDialog.requestPermissions();
    }
  },
)
```

## UI Components

### 1. Samsung Health Onboarding Dialog

Shows a beautiful step-by-step guide for Samsung users:

```dart
await SamsungHealthOnboardingDialog.show(
  onContinue: () {
    // Called when user taps Continue
  },
  onSkip: () {
    // Called when user taps Skip
  },
);
```

### 2. Health Permission Handler Dialog

Comprehensive handler that manages the entire flow:

```dart
// Request permissions with full UI flow
await HealthPermissionHandlerDialog.requestPermissions();

// Show setup instructions
await HealthPermissionHandlerDialog.showSetupInstructions();
```

## Permission Denial Tracking

The system uses SharedPreferences to track:
- Number of consecutive denials
- Last permission request timestamp
- Whether onboarding has been shown

**Reset denial count** when permissions are granted:
```dart
// This happens automatically in requestHealthPermissions()
// But you can also manually reset if needed
await helper._resetPermissionDenialCount(); // Private method
```

## Best Practices

### 1. Request Permissions at the Right Time

❌ **Don't** request on app launch
✅ **Do** request when user tries to enable health sync

```dart
// In your health sync toggle
Switch(
  value: healthSyncEnabled,
  onChanged: (value) async {
    if (value) {
      // Check permissions first
      final hasPermissions = await helper.hasHealthPermissions();

      if (!hasPermissions) {
        final granted = await HealthPermissionHandlerDialog.requestPermissions();
        if (!granted) return;
      }

      // Enable health sync
      setState(() => healthSyncEnabled = true);
    } else {
      // Disable health sync
      setState(() => healthSyncEnabled = false);
    }
  },
)
```

### 2. Provide Settings Access

Always provide a way for users to manage permissions:

```dart
// In your app settings or health sync screen
ElevatedButton.icon(
  onPressed: () => helper.openHealthSettings(),
  icon: Icon(Icons.settings),
  label: Text('Manage Permissions'),
)
```

### 3. Show Status Indicators

Let users know the current state:

```dart
FutureBuilder<HealthPermissionValidationResult>(
  future: helper.validateHealthSetup(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();

    final validation = snapshot.data!;

    return Card(
      child: ListTile(
        leading: Icon(
          validation.isValid ? Icons.check_circle : Icons.error,
          color: validation.isValid ? Colors.green : Colors.orange,
        ),
        title: Text('Health Sync Status'),
        subtitle: Text(validation.message),
      ),
    );
  },
)
```

## Testing on Samsung Devices

### Test Scenarios

1. **Fresh Install** (No Health Connect)
   - Should show install dialog
   - Should deep link to Play Store

2. **Health Connect Installed** (Not connected to Samsung Health)
   - Should show Samsung Health onboarding
   - Should guide through connection process

3. **Health Connect Connected** (No app permissions)
   - Should show permission dialog
   - Should handle denials gracefully

4. **Two Consecutive Denials**
   - Should still show permission dialog
   - Should track denial count

5. **Three Consecutive Denials**
   - Should direct to settings instead
   - Should show helpful message

6. **Permissions Granted**
   - Should reset denial count
   - Should show success message

## Technical Details

### Files Modified/Created

1. **lib/utils/health_permissions_helper.dart** - Enhanced with:
   - Samsung Health detection
   - Permission denial tracking
   - Deep linking methods
   - Improved validation

2. **lib/widgets/dialogs/samsung_health_onboarding_dialog.dart** - New:
   - Visual onboarding flow
   - Step-by-step guide
   - Direct links to Samsung Health

3. **lib/widgets/dialogs/health_permission_handler_dialog.dart** - New:
   - Comprehensive permission handler
   - Automatic flow management
   - Contextual messages

### AndroidManifest.xml

Already configured correctly with:
```xml
<!-- Health Connect configuration -->
<activity-alias
    android:name="ViewPermissionUsageActivity"
    android:exported="true"
    android:targetActivity=".MainActivity"
    android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
    <intent-filter>
        <action android:name="android.intent.action.VIEW_PERMISSION_USAGE" />
        <category android:name="android.intent.category.HEALTH_PERMISSIONS" />
    </intent-filter>
</activity-alias>

<!-- Health Connect app query -->
<queries>
    <package android:name="com.google.android.apps.healthdata" />
</queries>
```

### Dependencies Used

- `android_intent_plus: ^5.1.0` - For deep linking to Samsung Health and Health Connect
- `shared_preferences: ^2.3.5` - For tracking permission denial count
- `health: ^13.2.0` - For Health Connect/HealthKit integration
- `permission_handler: ^12.0.1` - For Android permissions

## Migration Guide

### Updating Existing Code

If you're currently using the old permission system:

**Before:**
```dart
final health = Health();
final granted = await health.requestAuthorization([...]);
```

**After:**
```dart
final granted = await HealthPermissionHandlerDialog.requestPermissions();
```

The new system handles everything automatically!

## Troubleshooting

### Issue: Samsung Health button doesn't open the app

**Solution:** Make sure Samsung Health is installed. Check with:
```dart
final installed = await helper.isSamsungHealthInstalled();
```

### Issue: Health Connect not found

**Solution:** The device may not support Health Connect (requires Android 9+):
```dart
final available = await helper.isHealthConnectInstalled();
if (!available) {
  await helper.openHealthConnectInPlayStore();
}
```

### Issue: Permission dialog shows immediately after denial

**Solution:** This is expected for the first 2 denials. On the 3rd denial, users will be directed to settings.

## Future Enhancements

Possible improvements:
- [ ] Add analytics for permission flow completion rate
- [ ] Implement tutorial video for Samsung Health setup
- [ ] Add support for other health apps (Google Fit, etc.)
- [ ] Improve error messages with device-specific instructions
- [ ] Add permission status widget for dashboard

## Support

For issues or questions:
1. Check this documentation first
2. Review the code comments in the helper files
3. Test on a physical Samsung device (emulator may not have Samsung Health)
4. Check logcat for detailed error messages with prefix `[HEALTH]`
