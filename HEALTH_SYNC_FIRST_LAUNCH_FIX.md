# Health Sync First Launch Fix

## Issue Description

Health sync was not starting on the first app launch after installation, but worked correctly after killing and reopening the app.

## Root Cause

The newly implemented health permission system introduced an onboarding check that was blocking background health sync:

1. On first launch, `requestHealthPermissions()` checks `shouldShowOnboarding()`
2. Returns `true` on first launch → method returns `false` immediately
3. HomepageDataService treats this as "permission denied" and stops sync
4. **No retry mechanism** - sync never starts until app is reopened

### Log Evidence

```
🏥 [HOMEPAGE_DATA] Requesting health permissions in background...
🏥 [HEALTH_SYNC] 💡 Onboarding should be shown before requesting permissions
🏥 [HOMEPAGE_DATA] Health permissions denied by user
```

## Solution Implemented

Added `skipOnboarding` parameter to allow background operations to bypass onboarding check:

### Files Modified

#### 1. `lib/services/health_sync_service.dart`
```dart
/// Request health permissions
///
/// [skipOnboarding] - If true, skips the onboarding check for background sync operations
Future<bool> requestPermissions({bool skipOnboarding = false}) async {
  try {
    if (GuestUtils.isGuest()) return false;

    final granted = await _permissionsHelper.requestHealthPermissions(
      skipOnboarding: skipOnboarding,
    );
    hasPermissions.value = granted;

    if (granted) {
      await _preferencesService.setHealthPermissionsGranted(true);
    }

    return granted;
  } catch (e) {
    print('${HealthConfig.logPrefix} Error requesting permissions: $e');
    return false;
  }
}
```

#### 2. `lib/screens/home/homepage_screen/controllers/homepage_data_service.dart`
```dart
// ✅ FIX: Skip onboarding for background sync on cold start
// Onboarding will be shown when user explicitly enables health sync via UI
final granted = await _healthSyncService!.requestPermissions(skipOnboarding: true);
```

## How It Works

### Background Sync (Cold Start)
- Called automatically on app launch
- Uses `skipOnboarding: true`
- Proceeds directly to permission request
- No UI interruption

### User-Initiated Sync (Settings)
- Called when user taps "Enable Health Sync" button
- Uses default `skipOnboarding: false`
- Shows onboarding dialog
- Educates user about the feature

## Benefits

1. **Fixes first launch issue** - Health sync now starts immediately on cold start
2. **Preserves user education** - Onboarding still shows for explicit user actions
3. **No breaking changes** - Existing onboarding system remains intact
4. **Better UX** - Background operations don't interrupt user flow

## Testing Checklist

- [ ] Fresh install - health sync starts on first launch
- [ ] Kill and reopen - sync continues working
- [ ] User enables health sync in settings - onboarding shows
- [ ] Permissions denied - appropriate error handling
- [ ] Guest mode - no health sync attempts

## Related Files

- `lib/utils/health_permissions_helper.dart` - Contains onboarding logic
- `lib/widgets/dialogs/samsung_health_onboarding_dialog.dart` - Onboarding UI
- `lib/widgets/dialogs/health_permission_handler_dialog.dart` - Permission handler

## Commit Message

```
fix(health-sync): Health sync now starts on first app launch

- Added skipOnboarding parameter to requestPermissions()
- Background sync bypasses onboarding check on cold start
- Onboarding still shows for user-initiated actions
- Fixes issue where sync only worked after killing/reopening app

Fixes #[issue-number]
```

## Date Fixed

2025-10-23

## Fixed By

Claude Code (Assistant)
