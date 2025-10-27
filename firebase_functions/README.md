# Firebase Cloud Functions for StepzSync

This directory contains Firebase Cloud Functions that handle server-side calculations and reduce client-side load.

## Functions Overview

### 1. `calculateOverallStats`
**Type:** Firestore Trigger
**Purpose:** Automatically recalculates `overall_stats` whenever `daily_stats` changes

**Triggers on:**
```
users/{userId} document updates
```

**What it does:**
- Monitors changes to `daily_stats` field
- Calculates total steps, distance, calories
- Counts active days
- Updates `overall_stats` automatically

**Benefits:**
- ✅ Reduces client-side computation
- ✅ Ensures data consistency
- ✅ Real-time updates
- ✅ No manual calculation needed

---

### 2. `scheduledStatsRecalculation`
**Type:** Scheduled Function (Cron Job)
**Purpose:** Daily recalculation of all users' stats for data integrity

**Schedule:** Every day at 2:00 AM UTC

**What it does:**
- Runs through all users in the database
- Recalculates overall_stats from daily_stats
- Ensures data consistency across all users
- Processes in batches to handle large datasets

**Benefits:**
- ✅ Fixes any data inconsistencies
- ✅ Runs automatically
- ✅ No app downtime required

---

### 3. `recalculateUserStats`
**Type:** HTTP Callable Function
**Purpose:** Manual trigger for stats recalculation

**Usage from Flutter:**
```dart
final functions = FirebaseFunctions.instance;
final callable = functions.httpsCallable('recalculateUserStats');

try {
  final result = await callable.call({
    'userId': 'user_id_here', // Optional, defaults to current user
  });

  print('Stats recalculated: ${result.data}');
} catch (e) {
  print('Error: $e');
}
```

---

## Setup & Deployment

### Prerequisites
1. Install Firebase CLI:
```bash
npm install -g firebase-tools
```

2. Login to Firebase:
```bash
firebase login
```

3. Initialize Firebase Functions (if not already done):
```bash
firebase init functions
```

### Installation
1. Navigate to your Firebase functions directory:
```bash
cd functions
```

2. Copy `calculateOverallStats.js` to your functions directory:
```bash
cp ../firebase_functions/calculateOverallStats.js ./index.js
```

3. Install dependencies:
```bash
npm install
```

### Deployment

Deploy all functions:
```bash
firebase deploy --only functions
```

Deploy specific function:
```bash
firebase deploy --only functions:calculateOverallStats
firebase deploy --only functions:scheduledStatsRecalculation
firebase deploy --only functions:recalculateUserStats
```

---

## Configuration

### Environment Variables
If needed, set environment variables:
```bash
firebase functions:config:set someservice.key="THE API KEY"
```

### Region Configuration
To deploy to a specific region, modify the function:
```javascript
exports.calculateOverallStats = functions
  .region('us-central1') // Add region here
  .firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    // ... function code
  });
```

---

## Monitoring

### View Logs
```bash
firebase functions:log
```

### View Specific Function Logs
```bash
firebase functions:log --only calculateOverallStats
```

### Firebase Console
Monitor function execution, errors, and performance:
https://console.firebase.google.com/project/YOUR_PROJECT_ID/functions

---

## Cost Considerations

### Free Tier Limits (Spark Plan):
- **Invocations:** 2 million/month
- **Compute time:** 400,000 GB-seconds/month
- **Network egress:** 5 GB/month

### Blaze Plan (Pay as you go):
- First 2 million invocations free
- $0.40 per million invocations after that
- Compute time: $0.0000025 per GB-second

### Estimated Cost:
For a typical app with 10,000 active users:
- Trigger function: ~300,000 invocations/month → **FREE**
- Scheduled function: ~30 invocations/month → **FREE**
- Total: Well within free tier

---

## Testing

### Test Locally (Firebase Emulator)
```bash
firebase emulators:start --only functions,firestore
```

### Test with cURL (HTTP Callable)
```bash
curl -X POST \
  https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/recalculateUserStats \
  -H "Content-Type: application/json" \
  -d '{"data": {"userId": "test_user_id"}}'
```

---

## Troubleshooting

### Function not triggering:
1. Check Firebase Console logs
2. Verify Firestore security rules allow function access
3. Ensure document path matches: `users/{userId}`

### Performance issues:
1. Monitor execution time in console
2. Consider batching for large datasets
3. Add indexes for complex queries

### Deployment errors:
```bash
# Clear cache and redeploy
rm -rf node_modules
npm install
firebase deploy --only functions
```

---

## Migration Strategy

### For Existing Users:
1. Deploy the functions
2. Run one-time migration to trigger recalculation:
```dart
// In your Flutter app
Future<void> migrateAllUsersStats() async {
  // This will trigger the function for all users
  final users = await FirebaseFirestore.instance.collection('users').get();

  for (var doc in users.docs) {
    // Just update a dummy field to trigger the function
    await doc.reference.update({'_migration_trigger': DateTime.now()});
  }
}
```

---

## Best Practices

1. **Error Handling:** Functions include try-catch blocks to prevent crashes
2. **Batching:** Scheduled function processes users in batches of 100
3. **Logging:** Comprehensive console.log statements for debugging
4. **Graceful Failures:** Functions return null on error instead of throwing
5. **Idempotency:** Functions can be safely retried without side effects

---

## Support

For issues or questions:
1. Check Firebase Console logs
2. Review function execution history
3. Test with Firebase Emulator
4. Contact: [Your support email]
