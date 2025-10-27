# Health Sync Testing Guide 🏥

## Quick Reference: What to Look For

### ✅ SUCCESS - What You SHOULD See

#### Console Logs (On Cold Start):
```
🔄 [LIFECYCLE] Cold start detected (app was killed)
🔄 [LIFECYCLE] App lifecycle manager initialized
🔄 [LIFECYCLE] Registered cold start callback (1 total)
🔄 [LIFECYCLE] App already resumed - triggering callback immediately  ← KEY LOG!
🏥 [MAIN_NAV] Cold start detected, triggering health sync...
🏥 [HOMEPAGE_DATA] Starting health sync on cold start...
🏥 [HEALTH_SYNC] Initializing health sync service...
🏥 [HEALTH_SYNC] Starting health data sync...
🏥 [HEALTH_SYNC] ✅ Sync completed successfully
🏥 [HEALTH_SYNC] Today: XXXX steps
🏥 [HEALTH_SYNC] Overall: XXXX steps (XX days)
```

#### UI Elements:
1. **HealthKit Permission Dialog** (iOS only - first time):
   - Shows list of health data types
   - Step Count, Distance, Active Energy, etc.
   - "Allow" button at bottom

2. **Health Sync Dialog** (after permissions granted):
   - Animated health icon (pulsing)
   - Progress messages:
     - "Connecting to HealthKit..."
     - "Syncing health data..."
     - "Updating your profile..."
     - "✅ Sync complete!"
   - Shows synced data count (e.g., "31 days synced")

3. **Homepage Updates**:
   - Step count updates
   - Distance updates
   - Calories updates
   - Charts populate with historical data

---

### ❌ FAILURE - What You Should NOT See

#### Bad Console Logs:
```
🔄 [LIFECYCLE] Cold start detected (app was killed)
🔄 [LIFECYCLE] Registered cold start callback (1 total)
← Missing: "App already resumed - triggering callback immediately"
← Missing: Any health sync logs

❌ THIS MEANS THE FIX DIDN'T WORK
```

#### Error Logs to Watch For:
```
❌ Error transitioning to active: ...
❌ Error fetching health data: ...
❌ Sync failed: ...
❌ Health services not available
```

---

## Step-by-Step Testing

### Test 1: Fresh Install (Clean Slate)
1. **Delete app completely** from device
2. **Reinstall from Xcode** (`flutter run`)
3. **Open app** → Login/Signup
4. **Watch console** for cold start logs
5. **Expected**: Permission dialog → Health sync dialog → Data syncs

### Test 2: Cold Start (Kill & Reopen)
1. **Kill app** (swipe away from app switcher)
2. **Wait 5 seconds**
3. **Reopen app**
4. **Watch console** for:
   - `🔄 [LIFECYCLE] App already resumed - triggering callback immediately`
5. **Expected**: Health sync triggers immediately

### Test 3: Background Resume (Quick)
1. **Put app in background** (home button / swipe up)
2. **Wait 5-10 seconds**
3. **Resume app**
4. **Watch console** for:
   - `🔄 [LIFECYCLE] App was paused for X seconds`
   - Should NOT trigger health sync
5. **Expected**: Just logs resume, no sync

### Test 4: Background Resume (Long - 30+ min)
1. **Put app in background**
2. **Wait 30+ minutes**
3. **Resume app**
4. **Watch console** for:
   - `🔄 [LIFECYCLE] App was paused for X minutes (treat as cold start)`
   - Should trigger health sync
5. **Expected**: Health sync dialog appears

### Test 5: Guest User (Should Skip)
1. **Login as guest** (if guest mode exists)
2. **Watch console** for:
   - `🏥 [MAIN_NAV] Skipping health sync for guest user`
3. **Expected**: No permission dialogs, no sync

---

## Debugging Checklist

### If Health Sync Doesn't Trigger:

- [ ] Check for **"App already resumed - triggering callback immediately"** log
  - If missing: The fix didn't apply (file save issue?)

- [ ] Check for **"Registered cold start callback"** log
  - If missing: MainNavigationScreen didn't initialize properly

- [ ] Check for **"Cold start detected"** log
  - If missing: AppLifecycleManager didn't initialize

- [ ] Check device permissions:
  - iOS: Settings → StepzSync → Health → Enable all
  - Android: Settings → Apps → Health Connect → Enable

- [ ] Check for error logs starting with ❌

### If Permission Dialog Doesn't Show:

- [ ] Check if permissions already granted (Settings app)
- [ ] Try denying all permissions in Settings, then reopen app
- [ ] Check for: `🏥 [HEALTH_SYNC] Health permissions not granted yet`

### If Data Doesn't Sync:

- [ ] Check HealthKit/Health Connect has data
  - iOS: Open Health app → Verify steps exist
  - Android: Open Health Connect → Verify steps exist

- [ ] Check sync result logs:
  - Look for: `🏥 [HEALTH_SYNC] Today: XXXX steps`
  - If shows 0 steps: No data in HealthKit for today

- [ ] Check database save logs:
  - Look for: `✅ Saved XX days to database`

---

## Expected Execution Flow

```
1. App Launch (Cold Start)
   ↓
2. AppLifecycleManager.initialize()
   - Detects: isColdStart = true
   - Detects: currentState = resumed
   ↓
3. MainNavigationScreen.initState()
   ↓
4. _initializeLifecycleManager()
   ↓
5. registerColdStartCallback()
   - Adds callback to list
   - ✅ CHECKS: isColdStart && currentState == resumed
   - ✅ EXECUTES callback immediately!
   ↓
6. _handleColdStart() in MainNavigationScreen
   ↓
7. HomepageDataService.syncHealthDataOnColdStart()
   ↓
8. Check permissions → Request if needed
   ↓
9. Show HealthSyncDialog
   ↓
10. HealthSyncService.syncHealthData()
    ↓
11. Fetch data from HealthKit/Health Connect
    ↓
12. Save to database (StepMetrics)
    ↓
13. Update Firebase user profile
    ↓
14. Show success message
```

---

## Key Files Modified (For Reference)

1. **lib/utils/app_lifecycle_manager.dart:164-179**
   - Added immediate callback execution logic

2. **lib/config/health_config.dart**
   - Fixed `MOVE_MINUTES` → `EXERCISE_TIME`

3. **lib/services/health_sync_service.dart**
   - Fixed database integration with `StepMetrics`

4. **lib/screens/bottom_navigation/main_navigation_screen.dart**
   - Fixed nullable type issue

---

## Performance Expectations

- **Cold Start Sync**: 2-5 seconds for 30 days of data
- **Permission Dialog**: Appears within 1 second
- **Database Save**: <1 second for 30 records
- **Firebase Update**: 1-2 seconds

---

## Common Issues & Solutions

### Issue: "App already resumed" log missing
**Solution**:
- Clean build: `flutter clean && flutter build ios`
- Force restart Xcode
- Delete app from device and reinstall

### Issue: Permission denied
**Solution**:
- iOS: Settings → Privacy → Health → StepzSync → Enable all
- Android: Settings → Apps → Health Connect → Permissions → Enable

### Issue: No data syncing (0 steps)
**Solution**:
- Open Health app (iOS) or Health Connect (Android)
- Add some manual steps for today
- Kill and reopen StepzSync app

### Issue: Database save errors
**Solution**:
- Check console for specific error
- Verify `DatabaseController` is initialized
- Check `StepMetrics` model matches database schema

---

## Success Criteria ✅

Your health sync is working correctly if:

1. ✅ Cold start logs show callback firing immediately
2. ✅ Permission dialog appears (first time only)
3. ✅ Health sync dialog shows with animations
4. ✅ Data syncs successfully (see step counts update)
5. ✅ Database save succeeds (30 days of data)
6. ✅ Firebase profile updates with health data
7. ✅ Homepage charts populate with historical data

---

**Last Updated**: After fixing callback timing issue in AppLifecycleManager
**Next Test**: Kill app → Reopen → Watch for immediate callback execution 🎯
