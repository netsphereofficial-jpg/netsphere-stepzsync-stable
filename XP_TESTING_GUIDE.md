# XP & Leaderboard Testing Guide

## 🚀 Quick Start - Inject Test Data

Your user ID: `ANk2bEJYKNRkYKTQXetqn8hzUzj1`

### Method 1: Use the Purple FAB Button (EASIEST ✅)

1. **Hot reload your app** - You should now see a **purple floating action button** with a science icon (🧪) on the bottom-right of your home screen
2. **Tap the purple button** - This opens the XP Test Screen
3. **Click "Inject Complete Test Scenario"** - This button injects everything at once
4. **Wait 5-10 seconds** - The data will be created in Firebase
5. **Done!** Navigate to the Leaderboard screen to see your data

### Method 2: Add to main.dart (One-Time Run)

Add this to `lib/main.dart` (temporarily):

```dart
import 'package:stepzsync/utils/init_test_data.dart';  // Add import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseService = FirebaseService();
  await firebaseService.ensureInitialized();

  DependencyInjection.setup();

  // 🧪 INJECT TEST DATA (Run once, then comment out!)
  await initTestData();
  // ⬆️ COMMENT OUT AFTER FIRST RUN ⬆️

  await PermissionManager.initializeNotificationServices();
  // ... rest of code
}
```

**Important:** Remove or comment out `await initTestData();` after the first run!

### Method 3: Direct Code (Anywhere)

Add this code anywhere in your app (e.g., in a debug button):

```dart
import '../utils/init_test_data.dart';

// In your button's onPressed:
ElevatedButton(
  onPressed: () async {
    await initTestData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Test data injected!')),
    );
  },
  child: Text('Inject XP Test Data'),
)
```

---

## 📊 What Gets Created

After running the test data injection:

### Your User Data
- **User ID:** ANk2bEJYKNRkYKTQXetqn8hzUzj1
- **XP:** 3,500 (Level 4)
- **Races Completed:** 10
- **Races Won:** 2
- **Podium Finishes:** 5
- **Location:** Mumbai, India

### Test Leaderboard
- **50 test users** with varying XP levels (0-50,000 XP)
- **Realistic distribution** (more users at lower levels)
- **Multiple countries:** India, USA, UK, Australia, Canada
- **Multiple cities:** Mumbai, Delhi, Bangalore, etc.

### Test Race
- **1 completed race** (12.5 km)
- **5 participants** (you + 4 test users)
- **Top 3 finishers** with XP awarded
- **XP Results:**
  - 1st Place: ~850 XP (250 participation + 500 placement + 100 bonus)
  - 2nd Place: ~550 XP (250 participation + 300 placement)
  - 3rd Place: ~450 XP (250 participation + 200 placement)

---

## 🔍 Verify Data in Firebase Console

Check these collections in Firebase:

1. **user_xp/ANk2bEJYKNRkYKTQXetqn8hzUzj1**
   - Should show 3,500 XP, Level 4

2. **user_xp** collection
   - Should have ~51 documents (50 test users + your user)

3. **xp_transactions** collection
   - Should have XP transaction records

4. **race_xp_results** collection
   - Should have race XP results for completed race

5. **races** collection
   - Should have 1 test race (ID starts with "test_race_")

---

## 🎮 Test the Features

After injecting data:

1. **Navigate to Leaderboard Screen**
   - You should see yourself ranked among 51 users
   - Your XP badge should display in the header

2. **Switch Between Tabs**
   - **City Tab:** See Mumbai leaderboard
   - **Country Tab:** See India leaderboard
   - **Global Tab:** See all users

3. **Check Your Rank**
   - "Your Rank: #XX" should appear below the header
   - Your entry should be highlighted in orange

4. **View Podium**
   - Top 3 users displayed on podium
   - Beautiful animations

5. **Scroll the List**
   - Infinite scroll with pagination
   - Pull to refresh

---

## 🧹 Cleanup Test Data

When you're done testing:

### Option 1: Use the Test Screen
1. Tap the purple FAB button
2. Scroll to the bottom
3. Click "Clear All Test Data"
4. Confirm deletion

### Option 2: Direct Code
```dart
import '../utils/init_test_data.dart';

await cleanupTestData();
```

This removes all test users and races but keeps your real user data.

---

## 📱 Firebase Collections Structure

```
Firebase Firestore:
├── user_xp/
│   ├── ANk2bEJYKNRkYKTQXetqn8hzUzj1 (your XP data)
│   ├── test_user_0
│   ├── test_user_1
│   └── ... (50 test users)
│
├── xp_transactions/
│   └── (transaction records)
│
├── race_xp_results/
│   └── test_race_{timestamp}_{userId}
│
├── races/
│   └── test_race_{timestamp}
│
├── race_participants/
│   └── test_race_{timestamp}/
│       └── participants/
│
└── users/
    ├── ANk2bEJYKNRkYKTQXetqn8hzUzj1
    └── test_user_* (50 test users)
```

---

## 🐛 Troubleshooting

### Purple Button Not Showing?
- Hot reload the app
- Make sure you're in **debug mode** (not release build)
- The button only appears in debug builds

### No Data in Firebase?
- Check Firebase Console logs
- Check device logs for error messages
- Verify Firebase rules allow writes
- Make sure you have internet connection

### App Crashes?
- Check logs for error messages
- Verify all imports are correct
- Try a full restart instead of hot reload

### Data Not Showing in Leaderboard?
- Wait a few seconds for data to sync
- Pull to refresh on leaderboard screen
- Check if `updateAllRanks()` was called
- Verify user_xp documents have data

---

## 📝 Important Notes

1. **Run injection only once** - Running multiple times creates duplicate data
2. **Test data is marked** - All test users have IDs starting with `test_user_`
3. **Easy cleanup** - All test data can be removed with one button
4. **Debug only** - Purple FAB only shows in debug mode
5. **Real data safe** - Your real user data (`ANk2bEJYKNRkYKTQXetqn8hzUzj1`) won't be deleted during cleanup

---

## ✅ Next Steps

After testing:

1. **Remove test code** from main.dart if you added it
2. **Keep the purple FAB** for easy future testing
3. **Implement subscription gating** in `LeaderboardController.canAccessTab()`
4. **Add XP badge to profile screen** using `XPBadge` widget
5. **Create XP gain animations** after race completion
6. **Set up Cloud Functions** to run `updateAllRanks()` periodically

---

## 📞 Need Help?

If you encounter issues:
1. Check the device logs (I/flutter messages)
2. Check Firebase Console for data
3. Verify all files were created correctly
4. Try a full app restart

Happy Testing! 🎉