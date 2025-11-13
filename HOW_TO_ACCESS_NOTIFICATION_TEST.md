# 🧪 How to Access Notification Test Screen

There are **5 easy ways** to access the notification test screen. Choose whichever works best for you!

---

## Method 1: Using Flutter DevTools Console (Quickest!)

1. Run your app in debug mode
2. Open Flutter DevTools console
3. Type this command:
   ```dart
   Get.toNamed('/notification-test');
   ```
4. Press Enter
5. ✅ Test screen opens immediately!

---

## Method 2: Add Floating Action Button (Recommended for Development)

Add this to your **homepage** or **main navigation screen**:

### Step 1: Import the FAB widget
```dart
import '../widgets/notification_test_fab.dart';
```

### Step 2: Add FAB to your Scaffold
```dart
Scaffold(
  body: YourBodyWidget(),
  floatingActionButton: NotificationTestFAB(), // ← Add this!
)
```

### Step 3: Run the app
- You'll see a purple floating button at the bottom-right
- Tap it to open the test screen
- ✅ Quick access from anywhere!

**File location:** `lib/widgets/notification_test_fab.dart` (already created!)

---

## Method 3: Add to Profile/Settings Screen Menu

If you have a profile or settings screen with a menu, add this:

### Step 1: Import
```dart
import '../widgets/notification_test_fab.dart';
```

### Step 2: Add menu item
```dart
PopupMenuButton<String>(
  onSelected: NotificationTestMenuItem.handleSelection,
  itemBuilder: (context) => [
    // Your existing menu items...
    NotificationTestMenuItem.menuItem,
  ],
)
```

### Step 3: Tap the menu
- Find "Test Notifications" option
- Tap it
- ✅ Test screen opens!

---

## Method 4: Add Debug Button to Action Grid

Add a test button to your homepage action buttons:

### Find your action buttons grid
Location: `lib/screens/home/homepage_screen/widgets/action_buttons_grid_widget.dart`

### Add this button (in debug mode only):
```dart
// Add to your button list
if (kDebugMode) { // Only show in debug builds
  {
    'icon': Icons.bug_report,
    'label': 'Test Notifications',
    'color': Colors.deepPurple,
    'onTap': () => Get.toNamed('/notification-test'),
  },
}
```

---

## Method 5: Programmatic Navigation (From Anywhere in Code)

From **anywhere** in your Flutter code, just call:

```dart
import 'package:get/get.dart';

// Then anywhere:
Get.toNamed('/notification-test');

// Or if you want to use the test service directly:
import 'package:stepzsync/services/notification_test_service.dart';

// Quick test (3 notifications)
await NotificationTestService.quickTest();

// All 24 notifications
await NotificationTestService.testAllNotifications();

// Specific category
await NotificationTestService.testRaceNotificationsOnly();
```

---

## 🎯 EASIEST METHOD FOR RIGHT NOW

### Using Dart DevTools Console:

1. **Run your app** in debug mode
2. **Look for the console** at the bottom of VS Code or Android Studio
3. **Type:**
   ```dart
   import 'package:get/get.dart';
   Get.toNamed('/notification-test');
   ```
4. **Press Enter**
5. ✅ **Done!** The test screen opens immediately

### Alternative - Add a Temporary Button:

Add this **anywhere** in your app temporarily:

```dart
// Add to any screen (like homepage)
ElevatedButton(
  onPressed: () => Get.toNamed('/notification-test'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.deepPurple,
  ),
  child: Text('🧪 Test Notifications'),
)
```

---

## 📱 Once You're on the Test Screen

You'll see:
- **Quick Test** - Sends 3 notifications (one from each category)
- **Test All** - Sends all 24 notification types
- **Race Only** - Tests race notifications
- **Social Only** - Tests friend/social notifications
- **Individual Tests** - Test specific notification types

### How to Test:
1. Tap any test button
2. Check your **notification tray**
3. Tap each notification
4. Verify it navigates to the correct screen

---

## 🚀 Quick Copy-Paste Solution

Want the fastest solution? Add this to your **homepage_screen.dart**:

### At the top of the file:
```dart
import 'package:flutter/foundation.dart'; // For kDebugMode
```

### In your build method, add a FAB:
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: YourExistingBody(),

    // Add this FAB (only shows in debug mode)
    floatingActionButton: kDebugMode
        ? FloatingActionButton(
            backgroundColor: Colors.deepPurple,
            child: Icon(Icons.notifications_active),
            onPressed: () => Get.toNamed('/notification-test'),
          )
        : null,
  );
}
```

This adds a purple button that:
- ✅ Only appears in debug mode
- ✅ Disappears in production builds
- ✅ Opens test screen with one tap

---

## 🎨 Visual Guide

```
┌─────────────────────────────────┐
│  Your App Homepage              │
│                                 │
│  [Normal content here]          │
│                                 │
│                                 │
│                          ┌────┐ │
│                          │ 🔔 │ │ ← Floating Action Button
│                          └────┘ │   (Only in debug mode)
│  ┌───┬───┬───┬───┬───┐         │
│  │   │   │   │   │   │         │
│  └───┴───┴───┴───┴───┘         │ ← Bottom Navigation
└─────────────────────────────────┘
```

When you tap the 🔔 button → Opens Test Screen!

---

## ✅ Recommendation

**For Development:** Use Method 2 (Floating Action Button)
- Quick access
- Clean code
- Auto-hides in production

**For Quick Testing Now:** Use Method 1 (DevTools Console)
- No code changes needed
- Instant access
- Just type the command

**For Production:** Remove or hide all test access
- Set `isDebugMode = false` in NotificationTestFAB
- Or wrap with `kDebugMode` check

---

## Need Help?

If you're stuck, just:

1. Open **VS Code** or **Android Studio**
2. Run the app
3. Open the **Debug Console** (usually at bottom)
4. Type: `Get.toNamed('/notification-test');`
5. Press **Enter**

The test screen will open! 🎉
