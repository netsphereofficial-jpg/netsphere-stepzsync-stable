# 🚀 Cloud Functions Deployment Guide for StepzSync

This guide will help you deploy the race participant management Cloud Functions.

---

## 📋 Prerequisites

1. **Firebase CLI installed**
   ```bash
   npm install -g firebase-tools
   ```

2. **Firebase project initialized**
   - You should already have a Firebase project for StepzSync
   - Project ID: (check your `firebase_options.dart` file)

3. **Node.js installed**
   - Version 18 or higher recommended
   - Check: `node --version`

---

## 🔧 Step-by-Step Deployment

### Step 1: Initialize Firebase Functions (First Time Only)

```bash
cd /Users/nikhil/StudioProjects/stepzsync_latest

# Login to Firebase
firebase login

# Initialize Functions in your project
firebase init functions
```

**When prompted:**
- Select your existing Firebase project (stepzsync)
- Language: **JavaScript** (not TypeScript)
- ESLint: **No** (or Yes, your choice)
- Install dependencies: **Yes**

This will create a `functions/` directory with:
```
functions/
├── package.json
├── index.js
└── node_modules/
```

---

### Step 2: Merge Cloud Functions Code

You now have TWO sets of functions:
1. `firebase_functions/calculateOverallStats.js` (existing stats functions)
2. `firebase_functions/raceParticipantFunctions.js` (new race functions)

**Merge them into one `functions/index.js` file:**

```bash
# Navigate to functions directory
cd functions

# Backup the default index.js
mv index.js index.js.backup

# Create new combined index.js
cat > index.js << 'EOF'
/**
 * StepzSync Cloud Functions
 * Combined: Stats calculation + Race participant management
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();
const db = admin.firestore();

// ========================================
// STATS CALCULATION FUNCTIONS
// ========================================

exports.calculateOverallStats = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const userId = context.params.userId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    const beforeDailyStats = beforeData.daily_stats || {};
    const afterDailyStats = afterData.daily_stats || {};

    if (JSON.stringify(beforeDailyStats) === JSON.stringify(afterDailyStats)) {
      console.log(\`No changes to daily_stats for user \${userId}, skipping...\`);
      return null;
    }

    console.log(\`Recalculating overall_stats for user \${userId}\`);

    try {
      let totalSteps = 0;
      let totalDistance = 0.0;
      let totalCalories = 0;
      let daysActive = 0;

      for (const [date, dayData] of Object.entries(afterDailyStats)) {
        totalSteps += dayData.steps || 0;
        totalDistance += dayData.distance || 0.0;
        totalCalories += dayData.calories || 0;
        daysActive++;
      }

      const overallStats = {
        total_steps: totalSteps,
        total_distance: totalDistance,
        total_calories: totalCalories,
        days_active: daysActive,
        last_updated: admin.firestore.FieldValue.serverTimestamp(),
        calculated_by: 'cloud_function',
      };

      await db.collection('users').doc(userId).update({
        overall_stats: overallStats,
      });

      console.log(\`Successfully updated overall_stats for user \${userId}\`);
      return null;
    } catch (error) {
      console.error(\`Error calculating overall_stats for user \${userId}:\`, error);
      return null;
    }
  });

// ========================================
// RACE PARTICIPANT MANAGEMENT FUNCTIONS
// ========================================

exports.onParticipantJoined = functions.firestore
  .document('races/{raceId}/participants/{userId}')
  .onCreate(async (snap, context) => {
    const raceId = context.params.raceId;
    const userId = context.params.userId;
    const participantData = snap.data();

    console.log(\`✅ Participant \${userId} joined race \${raceId}\`);

    try {
      const raceRef = db.collection('races').doc(raceId);
      const raceDoc = await raceRef.get();

      if (!raceDoc.exists) {
        console.error(\`Race \${raceId} not found\`);
        return null;
      }

      const updateData = {
        participantCount: admin.firestore.FieldValue.increment(1),
        lastParticipantJoinedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (participantData.steps && participantData.steps > 0) {
        updateData.activeParticipantCount = admin.firestore.FieldValue.increment(1);
      }

      await raceRef.update(updateData);
      console.log(\`✅ Race \${raceId} participant count incremented\`);
      return null;
    } catch (error) {
      console.error(\`❌ Error incrementing participant count for race \${raceId}:\`, error);
      return null;
    }
  });

exports.onParticipantLeft = functions.firestore
  .document('races/{raceId}/participants/{userId}')
  .onDelete(async (snap, context) => {
    const raceId = context.params.raceId;
    const userId = context.params.userId;
    const participantData = snap.data();

    console.log(\`🚪 Participant \${userId} left race \${raceId}\`);

    try {
      const raceRef = db.collection('races').doc(raceId);
      const raceDoc = await raceRef.get();

      if (!raceDoc.exists) {
        console.warn(\`Race \${raceId} not found (may have been deleted)\`);
        return null;
      }

      const updateData = {
        participantCount: admin.firestore.FieldValue.increment(-1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (participantData.steps && participantData.steps > 0) {
        updateData.activeParticipantCount = admin.firestore.FieldValue.increment(-1);
      }

      await raceRef.update(updateData);
      console.log(\`✅ Race \${raceId} participant count decremented\`);
      return null;
    } catch (error) {
      console.error(\`❌ Error decrementing participant count for race \${raceId}:\`, error);
      return null;
    }
  });

exports.onParticipantUpdated = functions.firestore
  .document('races/{raceId}/participants/{userId}')
  .onUpdate(async (change, context) => {
    const raceId = context.params.raceId;
    const userId = context.params.userId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    try {
      const raceRef = db.collection('races').doc(raceId);
      const updateData = {};

      const wasActive = beforeData.steps && beforeData.steps > 0;
      const isActive = afterData.steps && afterData.steps > 0;

      if (!wasActive && isActive) {
        updateData.activeParticipantCount = admin.firestore.FieldValue.increment(1);
        console.log(\`🏃 Participant \${userId} is now active in race \${raceId}\`);
      }

      const wasCompleted = beforeData.isCompleted || false;
      const isCompleted = afterData.isCompleted || false;

      if (!wasCompleted && isCompleted) {
        updateData.completedParticipantCount = admin.firestore.FieldValue.increment(1);
        if (isActive) {
          updateData.activeParticipantCount = admin.firestore.FieldValue.increment(-1);
        }
        console.log(\`🏆 Participant \${userId} completed race \${raceId}\`);
      }

      if (afterData.rank === 1 && beforeData.rank !== 1) {
        updateData.topParticipant = {
          userId: userId,
          userName: afterData.userName || afterData.displayName || 'Unknown',
          steps: afterData.steps || 0,
          distance: afterData.distance || 0,
          rank: 1,
          profilePicture: afterData.profilePicture || null,
        };
        console.log(\`🏆 New leader in race \${raceId}: \${updateData.topParticipant.userName}\`);
      }

      if (Object.keys(updateData).length > 0) {
        updateData.updatedAt = admin.firestore.FieldValue.serverTimestamp();
        await raceRef.update(updateData);
      }

      return null;
    } catch (error) {
      console.error(\`❌ Error updating race \${raceId} from participant update:\`, error);
      return null;
    }
  });

exports.onRaceStatusChanged = functions.firestore
  .document('races/{raceId}')
  .onUpdate(async (change, context) => {
    const raceId = context.params.raceId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    const oldStatus = beforeData.statusId;
    const newStatus = afterData.statusId;

    if (oldStatus === newStatus) return null;

    console.log(\`📊 Race \${raceId} status changed: \${oldStatus} → \${newStatus}\`);

    try {
      if (newStatus === 3 && oldStatus !== 3) {
        console.log(\`🏁 Race "\${afterData.title}" started! ID: \${raceId}\`);
        if (afterData.activeParticipantCount === undefined) {
          await change.after.ref.update({
            activeParticipantCount: 0,
            raceStartedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      if (newStatus === 4 && oldStatus !== 4) {
        console.log(\`🏆 Race "\${afterData.title}" completed! ID: \${raceId}\`);
        const participantsSnapshot = await db
          .collection('races')
          .doc(raceId)
          .collection('participants')
          .orderBy('rank')
          .get();

        const totalParticipants = participantsSnapshot.size;
        const completedParticipants = participantsSnapshot.docs.filter(
          doc => doc.data().isCompleted
        ).length;

        await change.after.ref.update({
          raceCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
          finalParticipantCount: totalParticipants,
          finalCompletedCount: completedParticipants,
          completionRate: totalParticipants > 0 ? (completedParticipants / totalParticipants * 100) : 0,
        });

        console.log(\`✅ Race \${raceId} final stats: \${completedParticipants}/\${totalParticipants} completed\`);
      }

      return null;
    } catch (error) {
      console.error(\`❌ Error handling status change for race \${raceId}:\`, error);
      return null;
    }
  });

// ========================================
// UTILITY FUNCTIONS
// ========================================

exports.migrateExistingRaces = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  console.log('🔧 Starting migration of existing races...');

  try {
    const racesSnapshot = await db.collection('races').get();
    let migratedCount = 0;
    let errorCount = 0;

    for (const raceDoc of racesSnapshot.docs) {
      const raceId = raceDoc.id;

      try {
        const participantsSnapshot = await db
          .collection('races')
          .doc(raceId)
          .collection('participants')
          .get();

        const participantCount = participantsSnapshot.size;
        let activeCount = 0;
        let completedCount = 0;
        let topParticipant = null;

        participantsSnapshot.docs.forEach(doc => {
          const pData = doc.data();
          if (pData.steps && pData.steps > 0) activeCount++;
          if (pData.isCompleted) completedCount++;

          if (pData.rank === 1) {
            topParticipant = {
              userId: doc.id,
              userName: pData.userName || pData.displayName || 'Unknown',
              steps: pData.steps || 0,
              distance: pData.distance || 0,
              rank: 1,
            };
          }
        });

        const updateData = {
          participantCount: participantCount,
          activeParticipantCount: activeCount,
          completedParticipantCount: completedCount,
        };

        if (topParticipant) {
          updateData.topParticipant = topParticipant;
        }

        await raceDoc.ref.update(updateData);
        migratedCount++;
        console.log(\`✅ Migrated race \${raceId}: \${participantCount} participants\`);
      } catch (error) {
        errorCount++;
        console.error(\`❌ Error migrating race \${raceId}:\`, error);
      }
    }

    console.log(\`🎉 Migration complete: \${migratedCount} races migrated, \${errorCount} errors\`);

    return {
      success: true,
      migratedCount: migratedCount,
      errorCount: errorCount,
      totalRaces: racesSnapshot.size,
    };
  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw new functions.https.HttpsError('internal', 'Migration failed');
  }
});
EOF
```

---

### Step 3: Deploy Functions to Firebase

```bash
# Make sure you're in the project root
cd /Users/nikhil/StudioProjects/stepzsync_latest

# Deploy ALL functions
firebase deploy --only functions

# OR deploy specific functions (faster for testing)
firebase deploy --only functions:onParticipantJoined,onParticipantLeft,onParticipantUpdated,onRaceStatusChanged
```

**Expected output:**
```
✔  functions[onParticipantJoined(us-central1)] Successful create operation.
✔  functions[onParticipantLeft(us-central1)] Successful create operation.
✔  functions[onParticipantUpdated(us-central1)] Successful create operation.
✔  functions[onRaceStatusChanged(us-central1)] Successful create operation.

✔  Deploy complete!
```

---

### Step 4: Run Migration for Existing Races

After deploying, you need to add the denormalized fields to existing races.

**Option A: From Flutter App (Recommended)**

1. Add this code to your Flutter app (temporary - run once):

```dart
import 'package:cloud_functions/cloud_functions.dart';

Future<void> migrateExistingRaces() async {
  try {
    final functions = FirebaseFunctions.instance;
    final callable = functions.httpsCallable('migrateExistingRaces');

    print('🔧 Starting race migration...');
    final result = await callable.call();

    print('✅ Migration complete!');
    print('Migrated: ${result.data['migratedCount']} races');
    print('Errors: ${result.data['errorCount']}');
  } catch (e) {
    print('❌ Migration failed: $e');
  }
}
```

2. Call it from a debug screen or main.dart:
```dart
// Add a button in your debug/settings screen
ElevatedButton(
  onPressed: () => migrateExistingRaces(),
  child: Text('Migrate Existing Races'),
)
```

**Option B: From Firebase Console**

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to Functions → migrateExistingRaces
4. Click "Run function" (might require Blaze plan)

---

## 🔍 Verify Functions Are Working

### Check Firebase Console

1. Go to Firebase Console → Functions
2. You should see all 5 functions listed:
   - `calculateOverallStats`
   - `onParticipantJoined` ← NEW
   - `onParticipantLeft` ← NEW
   - `onParticipantUpdated` ← NEW
   - `onRaceStatusChanged` ← NEW
   - `migrateExistingRaces` ← NEW

### Test Participant Join

1. In your app, join a race
2. Go to Firebase Console → Firestore → races → [raceId]
3. You should see `participantCount` automatically increment!

### View Logs

```bash
# View all function logs
firebase functions:log

# View specific function logs
firebase functions:log --only onParticipantJoined

# Follow logs in real-time
firebase functions:log --only onParticipantJoined --follow
```

---

## 💰 Cost Estimate

**Free Tier (Spark Plan):**
- 2M function invocations/month
- You'll stay within this easily

**Your Estimated Usage:**
- 100 users joining/leaving races per day = 3,000/month
- Participant updates during races = ~10,000/month
- **Total: ~13,000/month** (well under 2M free tier)

**Cost: $0/month** for your current scale

---

## 🐛 Troubleshooting

### Functions not deploying

```bash
# Check Firebase CLI version
firebase --version

# Update if needed
npm install -g firebase-tools@latest

# Re-authenticate
firebase logout
firebase login
```

### Functions not triggering

1. **Check Firestore Rules** - Functions need permission to read/write:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /races/{raceId}/participants/{userId} {
         allow read, write: if true; // Allow functions to access
       }
     }
   }
   ```

2. **Check Function Logs**:
   ```bash
   firebase functions:log --only onParticipantJoined
   ```

### Migration fails

- Make sure you're authenticated when calling the function
- Check that races exist in Firestore
- Review error logs in Firebase Console

---

## ✅ Next Steps

After functions are deployed and migration is complete:

1. ✅ Cloud Functions deployed and working
2. ⏭️ Add denormalized fields to Flutter race model
3. ⏭️ Fix RacesListController (remove N+1 query)
4. ⏭️ Add Firestore indexes
5. ⏭️ Test real-time updates

---

## 📞 Support

If you encounter issues:
1. Check Firebase Console logs
2. Review function execution history
3. Test with Firebase Emulator locally first
4. Check this guide's troubleshooting section

Good luck! 🚀
