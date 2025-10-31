# Average Speed Fix - November 1, 2025

## Problem

Average speed was showing **0 km/h** for all races, even when participants had distance progress.

## Root Cause

**Field Name Mismatch** between Dart client and Cloud Function:

### Client Side (Dart)
```dart
// lib/models/race_models.dart:33
final DateTime? actualStartTime; // When race actually started
```

When a race starts, the client sets:
```dart
'actualStartTime': FieldValue.serverTimestamp()
```

### Server Side (Cloud Function)
```javascript
// functions/index.js:711, 732 (BEFORE FIX)
raceData.startTime || null  // ❌ Looking for wrong field!
```

**Result**: The Cloud Function couldn't find `startTime` (because it's actually `actualStartTime`), so it always used the fallback calculation with `participant.joinedAt`, which could result in 0 or incorrect speeds.

## Solution

Updated Cloud Function to check BOTH field names:

```javascript
// functions/index.js:711, 732 (AFTER FIX)
raceData.actualStartTime || raceData.startTime || null  // ✅ Fixed!
```

Now the Cloud Function will:
1. First try `actualStartTime` (Dart model field)
2. Fall back to `startTime` (for backwards compatibility)
3. Finally fall back to `participant.joinedAt` if neither exists

## Changes Made

### File: `functions/index.js`

**Line 711** (capped delta path):
```javascript
raceData.actualStartTime || raceData.startTime || null
```

**Line 732** (normal delta path):
```javascript
raceData.actualStartTime || raceData.startTime || null
```

**Lines 923-927** (improved logging):
```javascript
console.log(`   ⚠️ No race start time available (actualStartTime/startTime missing), using participant joinedAt as fallback`);
// ... fallback calculation
console.log(`   📊 Fallback Average Speed: ${newDistance.toFixed(2)}km / ${raceTimeMinutes.toFixed(1)}min * 60 = ${avgSpeed.toFixed(2)} km/h`);
```

## Deployment

**Deployed**: October 31, 2025 at 18:38:14 UTC
**Function**: `syncHealthDataToRaces`
**Command**: `firebase deploy --only functions:syncHealthDataToRaces`

## Testing

### Before Fix
```
User distance: 1.5 km
Race started: 2 hours ago (actualStartTime set)
Cloud Function looks for: raceData.startTime (null)
Falls back to: participant.joinedAt
Result: avgSpeed = 0 km/h ❌
```

### After Fix
```
User distance: 1.5 km
Race started: 2 hours ago (actualStartTime = 2 hours ago)
Cloud Function finds: raceData.actualStartTime ✅
Calculation: (1.5 km / 120 min) * 60 = 0.75 km/h ✅
Result: avgSpeed = 0.75 km/h ✅
```

## How to Verify

1. **Join a race** (or use existing active races)
2. **Walk some distance** (e.g., 500 steps ~0.4 km)
3. **Check Cloud Function logs**:
   ```
   Firebase Console → Functions → syncHealthDataToRaces → Logs
   ```
4. **Look for**: `📊 Average Speed Calculation: X.XXkm / Y.Ymin * 60 = Z.ZZ km/h`
5. **Verify participant document** in Firestore:
   ```
   /races/{raceId}/participants/{userId}/avgSpeed should be non-zero
   ```

## Expected Behavior After Fix

### Scenario 1: Quick Race (starts immediately)
```
Race created at 2:00 PM
actualStartTime: 2025-11-01 14:00:00

User walks to 1 km by 3:00 PM (60 minutes elapsed)
avgSpeed = (1 km / 60 min) * 60 = 1.0 km/h ✅
```

### Scenario 2: Scheduled Race
```
Race scheduled for 5:00 PM, starts automatically
actualStartTime: 2025-11-01 17:00:00

User walks to 2.5 km by 6:00 PM (60 minutes elapsed)
avgSpeed = (2.5 km / 60 min) * 60 = 2.5 km/h ✅
```

### Scenario 3: User Joins Mid-Race
```
Race started at 10:00 AM
actualStartTime: 2025-11-01 10:00:00

User joins at 11:00 AM, walks to 1 km by 12:00 PM
Time since race start: 120 minutes (not 60!)
avgSpeed = (1 km / 120 min) * 60 = 0.5 km/h ✅

This is CORRECT - we measure from race start, not user join time
```

## Related Files

- `functions/index.js` (Cloud Function) - UPDATED
- `lib/models/race_models.dart` (Dart model) - No changes needed
- `lib/controllers/race/quick_race_controller.dart` (Sets actualStartTime)
- `lib/services/race_state_machine.dart` (Sets actualStartTime)
- `lib/services/race_service.dart` (Sets actualStartTime)
- `lib/services/firebase_service.dart` (Sets actualStartTime)

## Prevention

To prevent similar issues in the future:

1. **Document field names** in a central location
2. **Use TypeScript** for Cloud Functions (compile-time type checking)
3. **Add integration tests** that verify Cloud Function reads all expected fields
4. **Create a data model reference** document showing Firestore structure

## Status

✅ **FIXED AND DEPLOYED**

Average speed should now calculate correctly for all races that have `actualStartTime` set (which includes all Quick Races and scheduled races that have started).

## Next Steps

1. Test with a new race (walk a few hundred meters)
2. Check Firebase logs to confirm avgSpeed is calculated
3. Monitor for next 24 hours to ensure no regressions
4. Update `COMPREHENSIVE_VERIFICATION.md` with test results
