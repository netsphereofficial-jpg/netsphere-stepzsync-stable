# New User Database Structure - StepzSync

## Overview
This document explains how the Firebase database structure is automatically created for new users in StepzSync.

---

## Initialization Flow

### 1. User Registration/Login
When a new user completes registration:
```dart
// Called after user profile is created
StepTrackingService.initializeUserStepTracking();
// OR
StepTrackingService.createNewUserProfile();
```

### 2. Automatic Detection
The system automatically detects new users:
```dart
_loadUserStepData() {
  // Tries to load existing data
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .get();

  if (!userDoc.exists) {
    // New user detected → Initialize
    await _initializeNewUser();
  }
}
```

---

## Initial Firebase Document Structure

### Complete Structure Created:
```javascript
{
  // Document: /users/{userId}

  "step_tracking": {
    "install_date": "2025-10-02T12:00:00.000Z",
    "device_baseline": 1000,           // Current device step count
    "previous_days_total": 0,          //累積from previous days
    "last_device_reading": 1000,
    "last_sync": "2025-10-02T12:00:00.000Z",
    "today_baseline": 1000,            // Today's starting point
    "last_baseline_date": "2025-10-02"
  },

  "overall_stats": {
    "total_steps": 0,                  // Starts at 0
    "total_distance": 0.0,             // In kilometers
    "days_active": 1,                  // First day = 1
    "last_updated": "2025-10-02T12:00:00.000Z"
  },

  "daily_stats": {
    "2025-10-02": {                    // Today's date
      "steps": 0,
      "distance": 0.0,
      "calories": 0,
      "active_time": 0,
      "baseline_used": 1000,
      "last_updated": "2025-10-02T12:00:00.000Z"
    }
  }
}
```

---

## Initialization Process Details

### Step 1: Get Device Baseline
```dart
// Get current device step count
final currentDeviceSteps = await _getCurrentDeviceSteps();
// Example: Device shows 1000 steps → baseline = 1000
```

**Purpose:** We need to know the device's current step count so we can track only NEW steps from this point forward.

**Example:**
- Device shows: 1000 steps
- User registers: baseline = 1000
- User walks 50 steps: device = 1050
- **User's actual steps in app: 1050 - 1000 = 50 steps** ✅

---

### Step 2: Set Initial Values
```dart
_deviceBaseline = currentDeviceSteps;        // 1000
_todayDeviceBaseline = currentDeviceSteps;   // 1000
_previousDaysTotal = 0;                       // No previous days yet
_lastDeviceReading = currentDeviceSteps;      // 1000
_installDate = DateTime.now();                // Registration date
```

---

### Step 3: Create Firebase Document
```dart
await _createInitialFirebaseDoc();
```

This creates the complete structure shown above in Firebase Firestore at:
```
/users/{userId}
```

---

## Daily Updates Structure

### Day 1 (Registration Day - 2025-10-02):
```javascript
{
  "daily_stats": {
    "2025-10-02": {
      "steps": 50,              // User walked 50 steps
      "distance": 0.039,        // ~39 meters
      "calories": 2,
      "active_time": 1,         // 1 minute
      "baseline_used": 1000,
      "last_updated": "2025-10-02T14:30:00.000Z"
    }
  },
  "overall_stats": {
    "total_steps": 50,
    "total_distance": 0.039,
    "days_active": 1
  }
}
```

### Day 2 (Next Day - 2025-10-03):
```javascript
{
  "daily_stats": {
    "2025-10-02": {             // Yesterday's data preserved
      "steps": 50,
      ...
    },
    "2025-10-03": {             // NEW: Today's data added
      "steps": 120,
      "distance": 0.0936,
      "calories": 6,
      "active_time": 2,
      "baseline_used": 1050,    // Yesterday's end = today's baseline
      "last_updated": "2025-10-03T16:00:00.000Z"
    }
  },
  "overall_stats": {
    "total_steps": 170,         // 50 + 120
    "total_distance": 0.1326,   // Sum of all days
    "days_active": 2            // Automatically counts daily_stats entries
  }
}
```

### Day 3 (2025-10-04):
```javascript
{
  "daily_stats": {
    "2025-10-02": {...},        // Day 1 preserved
    "2025-10-03": {...},        // Day 2 preserved
    "2025-10-04": {             // Day 3 added
      "steps": 200,
      ...
    }
  },
  "overall_stats": {
    "total_steps": 370,         // 50 + 120 + 200
    "total_distance": 0.2886,
    "days_active": 3            // Grows automatically
  }
}
```

---

## Key Features of This Structure

### ✅ Clean Nested Structure
- All daily data lives inside `daily_stats` map
- Each day is a key: `"YYYY-MM-DD"`
- Easy to query and count

### ✅ Automatic Day Counting
```dart
// Days active = count of daily_stats entries
final daysActive = dailyStats?.length ?? 1;
```

### ✅ Historical Data Preserved
- Every day's data is kept permanently
- Can generate analytics for any time period
- Supports filters: Last 7/30/90 days

### ✅ Baseline Tracking
- Each day stores its baseline
- Prevents double-counting across day changes
- Handles device reboots correctly

---

## Database Growth Over Time

### Storage Example:
```
New User:     ~500 bytes
After 30 days:  ~15 KB
After 1 year:  ~180 KB
After 10 years: ~1.8 MB (still very small!)
```

**Firestore Costs (Blaze Plan):**
- Storage: $0.18/GB/month
- For 1000 users with 1 year of data:
  - Storage: 180 KB × 1000 = 180 MB = 0.18 GB
  - Cost: **$0.032/month** (essentially free!)

---

## Syncing Strategy

### Real-Time Sync (Every 10 seconds):
```dart
// Updates Firebase with latest data
'daily_stats': {
  todayString: {
    'steps': todaySteps.value,
    'distance': todayDistance.value,
    'calories': todayCalories.value,
    'active_time': todayActiveTime.value,
    'baseline_used': _todayDeviceBaseline,
    'last_updated': now.toIso8601String(),
  }
}
```

### Day Change Detection:
```dart
if (dateChanged) {
  // Preserve yesterday's data
  _previousDaysTotal = yesterdaySteps;

  // Reset today's counters
  _todayDeviceBaseline = currentDeviceSteps;

  // Create new daily_stats entry for today
  // Old days are automatically preserved in Firebase
}
```

---

## SQLite Local Database

In addition to Firebase, data is also stored locally in SQLite:

### Tables Created:

**1. daily_step_metrics**
```sql
CREATE TABLE daily_step_metrics (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  date TEXT NOT NULL,
  steps INTEGER NOT NULL,
  distance REAL NOT NULL,
  calories REAL NOT NULL,
  active_time INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE(user_id, date)
);
```

**2. user_overall_stats**
```sql
CREATE TABLE user_overall_stats (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL UNIQUE,
  first_install_date TEXT NOT NULL,
  total_days INTEGER NOT NULL,
  total_steps INTEGER NOT NULL,
  total_distance REAL NOT NULL,
  total_calories REAL NOT NULL
);
```

**3. step_history**
```sql
CREATE TABLE step_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  date TEXT NOT NULL,
  steps INTEGER NOT NULL,
  timestamp TEXT NOT NULL,
  UNIQUE(user_id, date)
);
```

---

## Migration from Firebase to Local DB

Historical data from Firebase is automatically migrated to local SQLite:

```dart
// Runs once on app initialization
await migrateHistoricalDataToDatabase();

// Copies all daily_stats entries from Firebase → SQLite
// Enables fast local queries for analytics/filters
```

---

## Firebase Cloud Functions (Optional)

You can deploy Cloud Functions to automatically calculate `overall_stats`:

### Trigger Function:
```javascript
// Runs whenever daily_stats changes
exports.calculateOverallStats = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const dailyStats = change.after.data().daily_stats || {};

    let totalSteps = 0;
    let totalDistance = 0;
    let daysActive = 0;

    for (const dayData of Object.values(dailyStats)) {
      totalSteps += dayData.steps || 0;
      totalDistance += dayData.distance || 0;
      daysActive++;
    }

    await change.after.ref.update({
      overall_stats: {
        total_steps: totalSteps,
        total_distance: totalDistance,
        days_active: daysActive,
        last_updated: FieldValue.serverTimestamp(),
      }
    });
  });
```

See `firebase_functions/README.md` for deployment instructions.

---

## Summary

### For New Users:
1. ✅ **Automatic initialization** on first login
2. ✅ **Clean nested structure** from day 1
3. ✅ **Baseline tracking** prevents double-counting
4. ✅ **Dual storage**: Firebase (cloud) + SQLite (local)
5. ✅ **Real-time sync** every 10 seconds
6. ✅ **Historical data preserved** forever
7. ✅ **Analytics ready** (Last 7/30/90 days filters)
8. ✅ **Scalable** - handles years of data efficiently

### Production Ready:
- ✅ No manual setup required
- ✅ Works offline (SQLite)
- ✅ Syncs when online (Firebase)
- ✅ Cost-effective ($0.032/month for 1000 users)
- ✅ Clean, maintainable code
- ✅ Backward compatible

---

## Code Reference

**Initialization:** `lib/services/step_tracking_service.dart:1374-1401`
**Structure Creation:** `lib/services/step_tracking_service.dart:250-284`
**Daily Sync:** `lib/services/step_tracking_service.dart:960-999`
**Day Change:** `lib/services/step_tracking_service.dart:385-510`

---

## Questions?

For detailed implementation, see:
- `lib/services/step_tracking_service.dart`
- `lib/services/database_controller.dart`
- `firebase_functions/calculateOverallStats.js`
- `firebase_functions/README.md`
