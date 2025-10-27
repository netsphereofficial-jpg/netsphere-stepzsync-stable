# Cloud Functions - What's Currently Deployed

## Overview
Your app uses Firebase Cloud Functions to handle server-side logic. Here's exactly what they're doing:

---

## ✅ Currently Deployed Cloud Functions

### 1. **`calculateOverallStats`** (Firestore Trigger)
**Location**: `functions/functions/functions/index.js` (lines 18-67)

**Trigger**: When any user document updates in `users/{userId}`

**What it does**:
- Monitors changes to `daily_stats` field
- Automatically recalculates overall statistics
- Updates `overall_stats` field with:
  - `total_steps`: Sum of all daily steps
  - `total_distance`: Sum of all daily distances
  - `total_calories`: Sum of all daily calories
  - `days_active`: Count of days with activity
  - `last_updated`: Timestamp
  - `calculated_by`: 'cloud_function' (for tracking)

**Why server-side**:
- ✅ Single source of truth
- ✅ Prevents client manipulation
- ✅ Ensures data consistency across devices
- ✅ Automatic recalculation when history changes

**Example**:
```javascript
// User completes a day with 10,000 steps
// Client writes to: users/{userId}/daily_stats/2025-10-11
daily_stats: {
  "2025-10-11": { steps: 10000, distance: 7.8, calories: 500 }
}

// Cloud Function automatically triggers and calculates:
overall_stats: {
  total_steps: 10000,
  total_distance: 7.8,
  total_calories: 500,
  days_active: 1,
  last_updated: "2025-10-11T10:30:00Z",
  calculated_by: "cloud_function"
}
```

---

### 2. **`onParticipantJoined`** (Firestore Trigger)
**Location**: `functions/functions/functions/index.js` (lines 73-108)

**Trigger**: When a participant joins a race (`races/{raceId}/participants/{userId}` created)

**What it does**:
- Increments `participantCount` for the race
- Increments `activeParticipantCount` if participant has steps > 0
- Updates `lastParticipantJoinedAt` timestamp
- Updates `updatedAt` timestamp

**Why server-side**:
- ✅ Atomic counter updates (prevent race conditions)
- ✅ Accurate participant tracking
- ✅ Can't be manipulated by client

---

### 3. **`onParticipantLeft`** (Firestore Trigger)
**Location**: `functions/functions/functions/index.js` (lines 110-144)

**Trigger**: When a participant leaves a race (`races/{raceId}/participants/{userId}` deleted)

**What it does**:
- Decrements `participantCount` for the race
- Decrements `activeParticipantCount` if participant had steps > 0
- Updates `updatedAt` timestamp

**Why server-side**:
- ✅ Ensures accurate counts when users leave
- ✅ Prevents negative counts or corruption

---

### 4. **`onParticipantUpdated`** (Firestore Trigger)
**Location**: `functions/functions/functions/index.js` (lines 146-199)

**Trigger**: When participant data updates (`races/{raceId}/participants/{userId}` updated)

**What it does**:
- Tracks when participant becomes active (steps > 0)
- Increments `activeParticipantCount` when first steps recorded
- Tracks race completion:
  - Increments `completedParticipantCount`
  - Decrements `activeParticipantCount` for completed users
- Updates `topParticipant` (rank #1 participant):
  - Stores: userId, userName, steps, distance, rank, profilePicture
  - Shows on race leaderboard/cards

**Why server-side**:
- ✅ Real-time leaderboard updates
- ✅ Accurate completion tracking
- ✅ Prevents cheating (client can't set own rank)

---

### 5. **`onRaceStatusChanged`** (Firestore Trigger)
**Location**: `functions/functions/functions/index.js` (lines 201-255)

**Trigger**: When race `statusId` field changes in `races/{raceId}`

**What it does**:

#### When race starts (statusId → 3):
- Sets `activeParticipantCount` to 0 if undefined
- Records `raceStartedAt` timestamp

#### When race completes (statusId → 4):
- Counts total participants
- Counts completed participants
- Calculates completion rate: `(completed / total) * 100`
- Records final stats:
  - `raceCompletedAt`: Timestamp
  - `finalParticipantCount`: Total who participated
  - `finalCompletedCount`: Total who finished
  - `completionRate`: Percentage

**Why server-side**:
- ✅ Immutable race completion records
- ✅ Accurate analytics
- ✅ Can't be tampered with after completion

---

### 6. **`migrateExistingRaces`** (HTTP Callable Function)
**Location**: `functions/functions/functions/index.js` (lines 261-335)

**Trigger**: Manual call from client (admin/developer only)

**What it does**:
- One-time migration utility
- Recalculates counts for all existing races:
  - `participantCount`
  - `activeParticipantCount`
  - `completedParticipantCount`
  - `topParticipant`
- Returns migration report

**When to use**:
- After deploying new race features
- To fix data inconsistencies
- Database cleanup/recovery

**Example call**:
```dart
final callable = FirebaseFunctions.instance.httpsCallable('migrateExistingRaces');
final result = await callable.call();
print('Migrated ${result.data['migratedCount']} races');
```

---

## 📊 What Client Manages (NOT Cloud Functions)

### ✅ Client-Side Calculations (Using StepCalculationHelper)
1. **Distance Calculation** (STEP-BASED ONLY)
   - Personalized step length from height
   - Formula: `distance = steps * (height * 0.415) / 100 / 1000`
   - Guest fallback: `distance = steps * 0.78 / 1000`

2. **Calorie Calculation**
   - MET-based formula
   - Personalized: weight, age, gender, speed
   - Guest fallback: `calories = steps * 0.05`

3. **Active Time Estimation**
   - From walking sessions if available
   - Fallback: `activeTime = steps / 100` (minutes)

4. **Speed, Pace, Cadence**
   - All derived from steps and time
   - No GPS tracking needed

### ✅ Client-Side Data Management
1. **Real-time step tracking** (device pedometer)
2. **Local SQLite caching** (offline support)
3. **UI state management** (loading, animations)
4. **Race session tracking** (active races)
5. **Batch sync to Firebase** (every 10 seconds)

---

## 🚫 What Cloud Functions DON'T Do

1. ❌ **Real-time step counting** (client-only, device sensors)
2. ❌ **Distance calculation** (client-side, no GPS)
3. ❌ **Calorie calculation** (client-side, personalized)
4. ❌ **Active time tracking** (client-side, pedometer)
5. ❌ **UI/UX logic** (client-only)

---

## 💰 Cost Breakdown

### Current Usage (per month):
```
Assumption: 1000 active users, 100 races/month

Function                    | Invocations/month | Cost
---------------------------|-------------------|--------
calculateOverallStats      | ~30,000          | $0.01
onParticipantJoined        | ~500             | $0.00
onParticipantLeft          | ~200             | $0.00
onParticipantUpdated       | ~50,000          | $0.02
onRaceStatusChanged        | ~200             | $0.00
migrateExistingRaces       | ~1 (manual)      | $0.00
---------------------------|-------------------|--------
TOTAL                      | ~80,900          | $0.03/month
```

**Free Tier**: 2,000,000 invocations/month
**Your usage**: ~80,900/month (~4% of free tier)
**Cost**: Effectively **$0** (well within free tier)

---

## 📈 Recommended Future Cloud Functions (Optional)

### Phase 3 - Enhanced Server-Side Calculations

#### `enhanceStepMetrics` (Proposed)
**Purpose**: Server-calculated verified stats

```javascript
exports.enhanceStepMetrics = functions.firestore
  .document('users/{userId}/raw_steps/{date}')
  .onWrite(async (change, context) => {
    const stepData = change.after.data();
    const userProfile = await getUserProfile(userId);

    // Server-side calculation (same logic as client)
    const metrics = {
      distance: calculateDistance(stepData.steps, userProfile),
      calories: calculateCalories(stepData.steps, userProfile),
      activeTime: calculateActiveTime(stepData.walking_sessions),
      // ... more metrics
    };

    // Write verified metrics
    await db.collection('users').doc(userId)
      .collection('calculated_metrics').doc(date)
      .set(metrics);
  });
```

**Benefits**:
- ✅ Tamper-proof stats
- ✅ Algorithm updates without app updates
- ✅ Consistent across all users
- ✅ Analytics-ready

**When to deploy**:
- When you need verified stats for leaderboards
- To prevent cheating in competitive features
- For advanced analytics

---

## 🎯 Current Architecture Summary

### What Happens When User Takes Steps:

```
1. Device Pedometer
   ↓
2. StepTrackingService (client)
   - Captures steps
   - Calculates: distance, calories, active time
   - Updates UI immediately
   ↓
3. Batch Sync (every 10s)
   ↓
4. Firebase: users/{userId}/daily_stats/{date}
   ↓
5. Cloud Function: calculateOverallStats (trigger)
   - Recalculates overall_stats
   - Updates: total_steps, total_distance, days_active
   ↓
6. Client reads updated overall_stats
   - Shows on homepage
   - Displays in profile
```

### Race Flow:

```
1. User joins race
   ↓
2. Client writes: races/{raceId}/participants/{userId}
   ↓
3. Cloud Function: onParticipantJoined (trigger)
   - Updates participantCount
   - Updates activeParticipantCount
   ↓
4. User takes steps during race
   ↓
5. Client updates: races/{raceId}/participants/{userId}.steps
   ↓
6. Cloud Function: onParticipantUpdated (trigger)
   - Updates topParticipant if rank = 1
   - Increments activeParticipantCount if first steps
   ↓
7. Race completes (statusId → 4)
   ↓
8. Cloud Function: onRaceStatusChanged (trigger)
   - Calculates final stats
   - Records completion rate
   - Immutable completion record
```

---

## 📝 Key Takeaways

### ✅ What's Managed by Cloud Functions:
1. Overall stats aggregation (total steps, distance, days)
2. Race participant counting
3. Race leaderboard updates
4. Race completion tracking
5. Final race statistics

### ✅ What's Managed by Client:
1. Real-time step tracking (device pedometer)
2. **Distance calculation (STEP-BASED, no GPS)**
3. Calorie calculation (personalized)
4. Active time tracking
5. Speed, pace, cadence
6. UI/UX and loading states
7. Local caching (SQLite)

### ✅ No GPS Tracking:
- All distance calculations are **purely step-based**
- Uses personalized step length from user height
- Falls back to average (0.78m) for guest users
- No location permissions needed
- Works completely offline

### 💡 Best Practice:
**Client for speed, Server for trust**
- Client calculates for immediate feedback
- Server aggregates for consistency
- Both work together seamlessly

---

**Last Updated**: 2025-10-11
**Deployed Functions**: 6 total
**Monthly Cost**: $0 (within free tier)
**GPS Tracking**: ❌ Not used (step-based only)
