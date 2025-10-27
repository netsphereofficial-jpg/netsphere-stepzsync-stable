# How to Integrate the New Health Permission System

## Quick Start

Replace your existing health permission requests with this simple line:

```dart
import 'package:stepzsync/widgets/dialogs/health_permission_handler_dialog.dart';

// Anywhere you need to request health permissions:
final granted = await HealthPermissionHandlerDialog.requestPermissions();
```

That's it! The system automatically:
- ✅ Detects Samsung Health
- ✅ Shows onboarding if needed
- ✅ Handles permission denials
- ✅ Provides deep links
- ✅ Shows contextual messages

## Example Integration Points

### 1. In Your Health Sync Toggle

```dart
// In your settings or profile screen
import 'package:stepzsync/widgets/dialogs/health_permission_handler_dialog.dart';

Switch(
  value: isHealthSyncEnabled,
  onChanged: (value) async {
    if (value) {
      // Request permissions before enabling
      final granted = await HealthPermissionHandlerDialog.requestPermissions();

      if (granted) {
        setState(() {
          isHealthSyncEnabled = true;
        });
        // Start health sync
        await healthSyncService.startSync();
      }
    } else {
      setState(() {
        isHealthSyncEnabled = false;
      });
      // Stop health sync
      await healthSyncService.stopSync();
    }
  },
)
```

### 2. In Your Onboarding Flow

```dart
// During app onboarding
import 'package:stepzsync/widgets/dialogs/health_permission_handler_dialog.dart';

ElevatedButton(
  onPressed: () async {
    final granted = await HealthPermissionHandlerDialog.requestPermissions();

    if (granted) {
      // Move to next onboarding step
      nextPage();
    } else {
      // Let user skip for now
      showSkipOption();
    }
  },
  child: Text('Enable Health Sync'),
)
```

### 3. In Your Settings Screen

```dart
// Settings screen with permission management
import 'package:stepzsync/widgets/dialogs/health_permission_handler_dialog.dart';
import 'package:stepzsync/utils/health_permissions_helper.dart';

ListTile(
  leading: Icon(Icons.health_and_safety),
  title: Text('Health Permissions'),
  subtitle: FutureBuilder<bool>(
    future: HealthPermissionsHelper().hasHealthPermissions(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return Text('Loading...');
      }
      return Text(
        snapshot.data! ? 'Enabled' : 'Not enabled',
        style: TextStyle(
          color: snapshot.data! ? Colors.green : Colors.orange,
        ),
      );
    },
  ),
  trailing: Icon(Icons.chevron_right),
  onTap: () async {
    final helper = HealthPermissionsHelper();
    final hasPermissions = await helper.hasHealthPermissions();

    if (hasPermissions) {
      // Show option to manage permissions
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Health Permissions'),
          content: Text('Permissions are currently enabled. You can manage them in Health Connect settings.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await helper.openHealthSettings();
              },
              child: Text('Open Settings'),
            ),
          ],
        ),
      );
    } else {
      // Request permissions
      await HealthPermissionHandlerDialog.requestPermissions();
    }
  },
)
```

### 4. Show Setup Instructions

```dart
// Show helpful instructions to users
import 'package:stepzsync/widgets/dialogs/health_permission_handler_dialog.dart';

TextButton(
  onPressed: () {
    HealthPermissionHandlerDialog.showSetupInstructions();
  },
  child: Text('How to set up health sync?'),
)
```

## Finding Existing Permission Requests

Search your codebase for these patterns and replace them:

### Pattern 1: Direct Health API calls
```dart
// OLD:
final health = Health();
await health.requestAuthorization([...]);

// NEW:
await HealthPermissionHandlerDialog.requestPermissions();
```

### Pattern 2: Using HealthPermissionsHelper directly
```dart
// OLD:
final helper = HealthPermissionsHelper();
await helper.requestHealthPermissions();

// NEW:
await HealthPermissionHandlerDialog.requestPermissions();
```

### Pattern 3: Custom permission dialogs
```dart
// OLD:
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Enable Health Sync'),
    // ... custom dialog
  ),
);

// NEW:
await HealthPermissionHandlerDialog.requestPermissions();
```

## Files to Update

Check these common locations in your app:

1. **Onboarding screens**
   - `lib/screens/onboarding/`
   - Look for health permission requests during first launch

2. **Settings screens**
   - `lib/screens/settings/`
   - `lib/screens/profile/`
   - Health sync toggles and permission management

3. **Health sync dialogs**
   - `lib/widgets/dialogs/health_sync_dialog.dart` ✅ (Already using helper)
   - Update to use new handler if needed

4. **Homepage/Dashboard**
   - `lib/screens/home/`
   - Any health sync prompts or status indicators

5. **Profile/Account screens**
   - Any permission status displays
   - Health data settings

## Testing Checklist

After integration, test these scenarios:

- [ ] Fresh install - shows onboarding correctly
- [ ] Samsung device - detects Samsung Health
- [ ] Non-Samsung device - works without Samsung-specific UI
- [ ] Permission granted - shows success message
- [ ] Permission denied once - can retry
- [ ] Permission denied twice - can retry
- [ ] Permission denied three times - directs to settings
- [ ] Settings screen - shows correct permission status
- [ ] Deep links work - Samsung Health and Health Connect open correctly

## Need More Control?

If you need fine-grained control, use the helper directly:

```dart
import 'package:stepzsync/utils/health_permissions_helper.dart';

final helper = HealthPermissionsHelper();

// Check Samsung Health
final hasSamsung = await helper.isSamsungHealthInstalled();

// Check current status
final validation = await helper.validateHealthSetup();

// Open Samsung Health directly
await helper.openSamsungHealthApp();

// Open Health Connect
await helper.openHealthConnectApp();

// Show custom onboarding
if (validation.shouldShowSamsungHealthGuide) {
  await SamsungHealthOnboardingDialog.show();
}
```

## Common Issues

### Issue: "Maximum denials reached" message
**Solution:** The user has denied permissions 3+ times. Guide them to settings:
```dart
await helper.openHealthSettings();
```

### Issue: Samsung Health button doesn't work
**Solution:** Check if Samsung Health is actually installed:
```dart
final installed = await helper.isSamsungHealthInstalled();
if (!installed) {
  // Show message that Samsung Health is not available
}
```

### Issue: Health Connect not found
**Solution:** Direct user to install from Play Store:
```dart
await helper.openHealthConnectInPlayStore();
```

## Questions?

Refer to:
- **SAMSUNG_HEALTH_PERMISSION_IMPROVEMENTS.md** - Full documentation
- Code comments in the helper files
- Test on a physical Samsung device for best results
