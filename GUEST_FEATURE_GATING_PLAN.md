# Guest Login - Feature Gating Plan

## 📱 App Structure Overview

### **Bottom Navigation Tabs:**
1. 🏠 **Home** - Homepage with stats and action buttons
2. 🏆 **Leaderboard** - Global rankings
3. ➕ **Create Race** - Create custom races
4. 💬 **Chat** - Chat with friends
5. 👤 **Profile** - User profile view/edit

### **Homepage Action Buttons:**
1. ⚡ Quick Race (1v5 with bots)
2. 🏁 Active Races
3. 🏃 Marathon
4. 📨 Race Invites
5. 🎖️ Hall of Fame
6. 🔔 Notifications (header)

### **Route Features:**
- Active Races Screen
- Race Details/Map Screen
- Marathon Screen
- Race Invites Screen
- Hall of Fame Screen
- Notifications Screen

---

## 🎯 Recommended Feature Gating Strategy

### ✅ **ALLOWED for Guests** (Free Trial Experience)

#### **Core Racing Features:**
- ✅ **Home Tab** - Full access to homepage
- ✅ **Quick Race 1v5** - Try racing with bots (best demo feature!)
- ✅ **Active Races (View Only)** - See ongoing races they participated in
- ✅ **Race Map** - View race progress in real-time
- ✅ **Step Tracking** - See their steps count
- ✅ **Statistics** - View their own stats (Today/7d/30d/90d)

**Reasoning:** Let guests experience the core value proposition - racing and step tracking. This hooks them before asking for signup.

---

### 🔒 **RESTRICTED for Guests** (Requires Account)

#### **Social Features:**
- 🔒 **Leaderboard Tab** - Requires account to compete
- 🔒 **Chat Tab** - Need identity to message
- 🔒 **Create Race Tab** - Need account to organize races
- 🔒 **Race Invites** - Need friends/account to receive invites
- 🔒 **Notifications** - Account required for personalized alerts
- 🔒 **Profile Edit** - Guest profile is auto-generated

#### **Advanced Features:**
- 🔒 **Marathon** - Premium racing mode
- 🔒 **Hall of Fame** - Achievement system
- 🔒 **Create Custom Race** - Organizing races
- 🔒 **Send Race Invites** - Inviting others

**Reasoning:** These features require social interaction, personalization, or long-term engagement - perfect upgrade incentives.

---

## 🎨 UX Implementation Plan

### **Phase 1: Silent Restrictions** (Recommended)
**Goal:** Let guests explore without constant "upgrade" nags

**Implementation:**
1. **Home Tab** - Fully accessible
2. **Leaderboard Tab** - Show lock icon + "Sign up to compete"
3. **Create Race Tab** - Show lock icon + "Sign up to create races"
4. **Chat Tab** - Show lock icon + "Sign up to chat"
5. **Profile Tab** - Show view-only mode with "Sign up to edit" button

**User Flow:**
```
Guest clicks locked tab
  ↓
Overlay/Dialog appears:
  "Sign Up to Unlock This Feature"
  [Benefits of signing up]
  [Sign Up Button] [Maybe Later]
```

---

### **Phase 2: Guest Banner** (Gentle Reminder)
**Goal:** Persistent but non-intrusive signup reminder

**Implementation:**
```dart
// At top of home screen
Container(
  padding: EdgeInsets.all(12),
  color: AppColors.appColor.withOpacity(0.1),
  child: Row(
    children: [
      Icon(Icons.person_outline, color: AppColors.appColor),
      Expanded(
        child: Text(
          '👋 You\'re in Guest Mode! Sign up to unlock all features.',
          style: TextStyle(fontSize: 12),
        ),
      ),
      TextButton(
        child: Text('Sign Up'),
        onPressed: () => showSignUpDialog(),
      ),
    ],
  ),
)
```

**Placement:**
- Top of Homepage (dismissible)
- OR sticky at bottom of screen

---

### **Phase 3: Lock Icons** (Visual Indicators)
**Goal:** Clear visual feedback on restricted features

**Implementation:**
```dart
// Bottom nav bar
BottomNavigationBarItem(
  icon: Stack(
    children: [
      Icon(Icons.leaderboard),
      if (GuestUtils.isGuest())
        Positioned(
          right: 0,
          top: 0,
          child: Icon(
            Icons.lock,
            size: 12,
            color: Colors.orange,
          ),
        ),
    ],
  ),
  label: 'Leaderboard',
)
```

---

## 🔧 Technical Implementation

### **Step 1: Update GuestUtils**

```dart
// lib/utils/guest_utils.dart

static bool isFeatureAvailableToGuest(String featureName) {
  switch (featureName) {
    // ✅ ALLOWED
    case 'home_screen':
      return true;
    case 'quick_race':
      return true;
    case 'active_races_view':
      return true;
    case 'race_map':
      return true;
    case 'step_tracking':
      return true;
    case 'statistics_view':
      return true;

    // 🔒 RESTRICTED
    case 'leaderboard':
      return false;
    case 'create_race':
      return false;
    case 'chat':
      return false;
    case 'profile_edit':
      return false;
    case 'race_invites':
      return false;
    case 'notifications':
      return false;
    case 'marathon':
      return false;
    case 'hall_of_fame':
      return false;
    case 'send_invites':
      return false;

    default:
      return false; // Default: restrict
  }
}
```

---

### **Step 2: Update Bottom Navigation**

```dart
// lib/screens/bottom_navigation/main_navigation_screen.dart

Widget _getCurrentScreen(int index) {
  // Check guest access before switching tabs
  final Map<int, String> tabFeatures = {
    0: 'home_screen',
    1: 'leaderboard',
    2: 'create_race',
    3: 'chat',
    4: 'profile_view', // Allow view, restrict edit
  };

  if (GuestUtils.isGuest() &&
      !GuestUtils.isFeatureAvailableToGuest(tabFeatures[index]!)) {
    // Show upgrade dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showUpgradeDialog(tabFeatures[index]!);
      controller.changeIndex(0); // Return to home
    });
    return HomepageScreen(key: const ValueKey('home'));
  }

  switch (index) {
    case 0: return HomepageScreen(key: const ValueKey('home'));
    case 1: return LeaderboardScreen(key: const ValueKey('leaderboard'));
    case 2: return CreateRaceScreen(key: const ValueKey('create'));
    case 3: return ChatListScreen(key: const ValueKey('chat'));
    case 4: return ProfileViewScreen(key: const ValueKey('profile'));
    default: return HomepageScreen(key: const ValueKey('home'));
  }
}
```

---

### **Step 3: Update Action Buttons**

```dart
// lib/screens/home/homepage_screen/widgets/action_buttons_grid_widget.dart

final Map<String, dynamic> buttons = [
  {
    'title': 'Quick race',
    'icon': IconPaths.quickRace,
    'onTap': () => _handleQuickRace(), // Allowed
    'guestAccess': true, // ✅ Allow
  },
  {
    'title': 'Active Races',
    'icon': IconPaths.activeRaces,
    'onTap': () => _handleActiveRaces(), // Allowed
    'guestAccess': true, // ✅ Allow
  },
  {
    'title': 'Marathon',
    'icon': IconPaths.marathon,
    'onTap': () => _handleMarathon(),
    'guestAccess': false, // 🔒 Restrict
  },
  {
    'title': 'Race invites',
    'icon': IconPaths.raceInvites,
    'onTap': () => _handleRaceInvites(),
    'guestAccess': false, // 🔒 Restrict
  },
  {
    'title': 'Hall of fame',
    'icon': IconPaths.hallOfFame,
    'onTap': () => _handleHallOfFame(),
    'guestAccess': false, // 🔒 Restrict
  },
];

// In build method:
GestureDetector(
  onTap: () {
    if (!button['guestAccess'] && GuestUtils.isGuest()) {
      _showUpgradeDialog(button['title']);
      return;
    }
    button['onTap']();
  },
  child: // ... button widget
)
```

---

## 📊 Upgrade Dialog Design

```dart
void _showUpgradeDialog(String featureName) {
  Get.dialog(
    AlertDialog(
      title: Row(
        children: [
          Icon(Icons.lock_open, color: AppColors.appColor),
          SizedBox(width: 8),
          Text('Unlock ${featureName}'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create a free account to unlock:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          _buildBenefit('🏆 Global Leaderboard'),
          _buildBenefit('💬 Chat with Friends'),
          _buildBenefit('🏁 Create Custom Races'),
          _buildBenefit('📨 Send & Receive Invites'),
          _buildBenefit('🎖️ Achievements & Badges'),
          _buildBenefit('🔔 Real-time Notifications'),
          SizedBox(height: 12),
          Text(
            'Your progress will be saved!',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: Text('Maybe Later'),
        ),
        ElevatedButton(
          onPressed: () {
            Get.back();
            Get.to(() => LoginScreen()); // Show login/signup
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.appColor,
          ),
          child: Text('Sign Up Free'),
        ),
      ],
    ),
  );
}

Widget _buildBenefit(String text) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(Icons.check_circle, size: 16, color: Colors.green),
        SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 14)),
      ],
    ),
  );
}
```

---

## 🎯 Suggested Workflow

### **For Guest Users:**

**Day 1 Experience:**
1. ✅ Open app → Auto guest login (4 seconds)
2. ✅ See homepage with steps tracking
3. ✅ Try "Quick Race 1v5" (best demo!)
4. ✅ See their race in "Active Races"
5. 🔒 Try to check "Leaderboard" → Upgrade prompt
6. 🔒 Try to "Chat" → Upgrade prompt

**Conversion Trigger:**
- After 2-3 Quick Races → Show upgrade banner
- When trying restricted feature → Upgrade dialog
- After 24 hours → Push notification (if allowed)

---

### **Account Upgrade (Link Anonymous Account):**

```dart
Future<void> upgradeGuestAccount() async {
  try {
    showDialog(context, 'Upgrading your account...');

    // User signs in with Google/Apple/Email
    final credential = await signInWithGoogle(); // or Apple

    // Link anonymous account with real credential
    final user = await FirebaseAuth.instance.currentUser
        ?.linkWithCredential(credential);

    // Update profile with real data
    await ProfileService.updateProfileField('fullName', user?.displayName);
    await ProfileService.updateProfileField('email', user?.email);
    await ProfileService.updateProfileField('profileCompleted', true);

    Get.back(); // Close dialog

    SnackbarUtils.showSuccess(
      'Account Upgraded!',
      'All features unlocked. Your progress is saved!',
    );

    // Refresh UI to unlock features
    AuthWrapper.clearCache();
    Get.offAll(() => HomeScreen());

  } catch (e) {
    print('❌ Error upgrading: $e');
    SnackbarUtils.showError('Upgrade Failed', e.toString());
  }
}
```

---

## 📈 Analytics to Track

**Guest Behavior:**
- How many guests try Quick Race?
- Which restricted feature do they click most?
- How long before they upgrade?
- Conversion rate: Guest → Account

**Key Metrics:**
```dart
// Log guest actions
analytics.logEvent('guest_tried_quick_race');
analytics.logEvent('guest_clicked_leaderboard'); // Restricted
analytics.logEvent('guest_upgraded_account');
```

---

## 🚀 Implementation Priority

### **Phase 1: Core Restrictions** (Now)
- ✅ Bottom nav tab checks
- ✅ Action button gating
- ✅ Basic upgrade dialog

### **Phase 2: Polish UX** (Next)
- Guest banner at top
- Lock icons on restricted tabs
- Better upgrade dialog with benefits

### **Phase 3: Advanced** (Later)
- Account upgrade flow
- Data migration verification
- A/B test different prompts

---

## 💡 Key Recommendations

### **DO:**
✅ Let guests try Quick Race (your best feature!)
✅ Show locked features with clear upgrade path
✅ Preserve all guest data when upgrading
✅ Keep upgrade prompts friendly and benefit-focused
✅ Allow viewing but restrict editing in Profile

### **DON'T:**
❌ Block too much - guests need value
❌ Show popup every time they click restricted feature
❌ Make upgrade mandatory immediately
❌ Lose their data when converting
❌ Hide that features exist

---

## 🎨 Visual Mockup

```
┌─────────────────────────────────┐
│ 👋 Guest Mode - Sign up to      │
│    unlock all features! [Sign Up]│ ← Banner (dismissible)
├─────────────────────────────────┤
│                                 │
│  📊 Statistics                  │
│  Steps Today: 1,234             │ ← Allowed
│                                 │
│  ┌──────┐ ┌──────┐ ┌──────┐   │
│  │⚡Quick│ │🏁Active│ │🏃Marathon│ │
│  │ Race │ │Races  │ │  🔒  │   │ ← Lock icon
│  └──────┘ └──────┘ └──────┘   │
│                                 │
└─────────────────────────────────┘

Bottom Nav:
[🏠 Home] [🏆 🔒] [➕ 🔒] [💬 🔒] [👤 Profile]
           ↑        ↑        ↑
        Locked    Locked   Locked
```

---

This plan balances giving guests a great trial experience while creating clear upgrade incentives. Would you like me to implement any specific part first?
