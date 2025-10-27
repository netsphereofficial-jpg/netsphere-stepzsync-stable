# Step Calculation Helper - Integration Guide

## Quick Start

### 1. Import the Helper
```dart
import 'package:stepzsync_latest/utils/step_calculation_helper.dart';
import 'package:stepzsync_latest/models/profile_models.dart';
```

### 2. Get User Profile (if available)
```dart
// For authenticated users
final userId = FirebaseAuth.instance.currentUser?.uid;
UserProfile? userProfile;

if (userId != null) {
  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(userId)
        .get();

    if (userDoc.exists) {
      userProfile = UserProfile.fromFirestore(userDoc);
    }
  } catch (e) {
    print('Failed to load profile: $e');
    // userProfile remains null - will use defaults
  }
}

// For guest users, userProfile stays null
```

### 3. Calculate All Metrics
```dart
final metrics = StepCalculationHelper.calculateAllMetrics(
  steps: 10212,
  userProfile: userProfile, // null for guests
  gpsDistance: null, // optional: provide if GPS tracking enabled
  actualActiveTimeMinutes: null, // optional: from walking sessions
);

// Access calculated values
final distanceKm = metrics['distance_km']; // 7.85
final calories = metrics['calories']; // 320
final activeTime = metrics['active_time_minutes']; // 102
final speed = metrics['avg_speed_kmh']; // 4.6
final quality = metrics['calculation_quality']; // 'high', 'good', 'medium', or 'basic'
final isPersonalized = metrics['is_personalized']; // true or false
```

---

## Integration Examples

### Example 1: Replace Existing Calculation in StepTrackingService

**Before (hardcoded constants):**
```dart
// OLD CODE - DON'T USE
todayDistance.value = (calculatedTodaySteps * _averageStepLength / 1000);
todayCalories.value = (calculatedTodaySteps * _caloriesPerStep).round();
todayActiveTime.value = (calculatedTodaySteps / 100).round();
```

**After (personalized):**
```dart
// NEW CODE - Use StepCalculationHelper
final metrics = StepCalculationHelper.calculateAllMetrics(
  steps: calculatedTodaySteps,
  userProfile: _userProfile, // store profile in service
  gpsDistance: _gpsDistance, // from location tracking
  actualActiveTimeMinutes: _actualWalkingTime, // from pedometer status
);

todayDistance.value = metrics['distance_km'];
todayCalories.value = metrics['calories'];
todayActiveTime.value = metrics['active_time_minutes'];
```

---

### Example 2: Homepage Stats Display with Quality Indicator

```dart
class StatsCard extends StatelessWidget {
  final Map<String, dynamic> metrics;

  Widget build(BuildContext context) {
    final quality = metrics['calculation_quality'];
    final isPersonalized = metrics['is_personalized'];

    return Column(
      children: [
        // Stats display
        Text('${metrics['distance_km']} km'),
        Text('${metrics['calories']} kcal'),
        Text('${metrics['active_time_formatted']}'),

        // Quality indicator
        if (!isPersonalized)
          Tooltip(
            message: 'Complete your profile for more accurate stats',
            child: Icon(
              Icons.info_outline,
              color: Colors.orange,
              size: 16,
            ),
          ),

        // Quality badge
        _buildQualityBadge(quality),
      ],
    );
  }

  Widget _buildQualityBadge(String quality) {
    final badges = {
      'high': ('🎯', 'Highly Accurate', Colors.green),
      'good': ('✓', 'Good Accuracy', Colors.blue),
      'medium': ('~', 'Estimated', Colors.orange),
      'basic': ('?', 'Basic Estimate', Colors.grey),
    };

    final badge = badges[quality]!;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badge.$3.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(badge.$1, style: TextStyle(fontSize: 12)),
          SizedBox(width: 4),
          Text(
            badge.$2,
            style: TextStyle(
              fontSize: 10,
              color: badge.$3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
```

---

### Example 3: Profile Completion Prompt

```dart
class ProfileCompletionBanner extends StatelessWidget {
  final Map<String, dynamic> metrics;

  Widget build(BuildContext context) {
    // Only show if using basic calculations
    if (metrics['calculation_quality'] != 'basic') {
      return SizedBox.shrink();
    }

    return Card(
      color: Colors.blue.shade50,
      child: ListTile(
        leading: Icon(Icons.account_circle, color: Colors.blue),
        title: Text('Get More Accurate Stats'),
        subtitle: Text(
          'Complete your profile to get personalized distance and calorie calculations',
        ),
        trailing: Icon(Icons.arrow_forward),
        onTap: () {
          // Navigate to profile completion
          Get.to(() => ProfileScreen());
        },
      ),
    );
  }
}
```

---

### Example 4: Individual Metric Calculations

If you need just one metric:

```dart
// Calculate only distance
final distance = StepCalculationHelper.calculateDistance(
  steps: 10000,
  userProfile: userProfile,
  gpsDistance: null,
);

// Calculate only calories
final calories = StepCalculationHelper.calculateCalories(
  steps: 10000,
  distanceKm: 7.8,
  activeTimeMinutes: 100,
  userProfile: userProfile,
);

// Calculate speed
final speed = StepCalculationHelper.calculateAverageSpeed(
  distanceKm: 7.8,
  activeTimeMinutes: 100,
);

// Calculate cadence
final cadence = StepCalculationHelper.calculateCadence(
  steps: 10000,
  activeTimeMinutes: 100,
);
```

---

### Example 5: Race Stats Calculation

```dart
class RaceStatsCalculator {
  static Map<String, dynamic> calculateRaceMetrics({
    required int raceSteps,
    required UserProfile? userProfile,
    required int elapsedMinutes,
    double? gpsDistance,
  }) {
    final metrics = StepCalculationHelper.calculateAllMetrics(
      steps: raceSteps,
      userProfile: userProfile,
      gpsDistance: gpsDistance,
      actualActiveTimeMinutes: elapsedMinutes,
    );

    // Add race-specific metrics
    return {
      ...metrics,
      'rank': calculateRank(raceSteps), // your logic
      'progress_percentage': calculateProgress(raceSteps), // your logic
      'estimated_finish_time': estimateFinishTime(
        currentSteps: raceSteps,
        targetSteps: 10000,
        avgSpeed: metrics['avg_speed_kmh'],
      ),
    };
  }
}
```

---

## Testing Different Scenarios

### Test 1: Guest User (No Profile)
```dart
final metrics = StepCalculationHelper.calculateAllMetrics(
  steps: 5000,
  userProfile: null, // Guest user
);

// Expected:
// - distance: ~3.9 km (using default 0.78m step length)
// - calories: ~250 (using default weight 70kg)
// - quality: 'basic'
// - is_personalized: false
```

### Test 2: User with Profile
```dart
final userProfile = UserProfile(
  height: 180, // cm
  heightUnit: 'cms',
  weight: 80, // kg
  weightUnit: 'Kgs',
  gender: 'male',
  dateOfBirth: DateTime(1990, 1, 1), // 35 years old
  // ... other fields
);

final metrics = StepCalculationHelper.calculateAllMetrics(
  steps: 5000,
  userProfile: userProfile,
);

// Expected:
// - distance: ~3.74 km (personalized: 180cm * 0.415 = 74.7cm step length)
// - calories: ~280 (personalized: 80kg, male, age 35)
// - quality: 'medium'
// - is_personalized: true
```

### Test 3: User with GPS and Walking Sessions
```dart
final metrics = StepCalculationHelper.calculateAllMetrics(
  steps: 5000,
  userProfile: userProfile,
  gpsDistance: 4.2, // km from GPS
  actualActiveTimeMinutes: 55, // from pedometer sessions
);

// Expected:
// - distance: 4.2 km (GPS overrides calculation)
// - calories: ~300 (accurate: real speed = 4.2/0.92 = 4.56 kmh)
// - quality: 'high'
// - is_personalized: true
```

---

## Migration Checklist

### StepTrackingService Integration
- [ ] Import `StepCalculationHelper`
- [ ] Store `UserProfile` in service (load on init)
- [ ] Replace hardcoded `_averageStepLength` usage
- [ ] Replace hardcoded `_caloriesPerStep` usage
- [ ] Replace active time estimation formula
- [ ] Add GPS distance tracking (optional)
- [ ] Add walking session duration tracking (optional)

### Homepage Integration
- [ ] Update `homepage_data_service.dart` to use new calculations
- [ ] Add quality indicator to stats card
- [ ] Show profile completion prompt for guest users
- [ ] Display personalized badge for profile users

### Database Updates
- [ ] Store `calculation_quality` in daily_stats
- [ ] Store `is_personalized` flag
- [ ] Add `calculation_version` field (for future migrations)

---

## Best Practices

### 1. Cache User Profile
```dart
class StepTrackingService extends GetxController {
  UserProfile? _cachedUserProfile;
  Timer? _profileRefreshTimer;

  @override
  void onInit() {
    super.onInit();
    _loadUserProfile();

    // Refresh profile every 30 minutes
    _profileRefreshTimer = Timer.periodic(
      Duration(minutes: 30),
      (_) => _loadUserProfile(),
    );
  }

  Future<void> _loadUserProfile() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('user_profiles')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          _cachedUserProfile = UserProfile.fromFirestore(userDoc);
          print('✅ User profile loaded for personalized calculations');
        }
      } catch (e) {
        print('⚠️ Failed to load user profile: $e');
      }
    }
  }
}
```

### 2. Handle Unit Conversions
```dart
// Helper already handles this!
// Height: cms ↔ inches
// Weight: kgs ↔ lbs

// Example: User enters 5'10" (70 inches)
final profile = UserProfile(
  height: 70,
  heightUnit: 'inches', // automatically converted to cm
  weight: 165,
  weightUnit: 'lbs', // automatically converted to kg
  // ...
);

// StepCalculationHelper will convert:
// 70 inches → 177.8 cm → step length 73.6 cm
// 165 lbs → 74.8 kg → calories calculation
```

### 3. Provide Feedback to User
```dart
// Show user how their stats improved with profile
class ProfileImpactDialog extends StatelessWidget {
  final Map<String, dynamic> beforeMetrics; // Guest calculations
  final Map<String, dynamic> afterMetrics; // Personalized

  Widget build(BuildContext context) {
    final calorieDiff = afterMetrics['calories'] - beforeMetrics['calories'];
    final distanceDiff = afterMetrics['distance_km'] - beforeMetrics['distance_km'];

    return AlertDialog(
      title: Text('🎯 More Accurate Stats!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Your personalized stats are ready:'),
          SizedBox(height: 16),
          _buildDiff('Distance', '$distanceDiff km'),
          _buildDiff('Calories', '$calorieDiff kcal'),
          SizedBox(height: 16),
          Text(
            'Your actual height and weight give you more precise measurements!',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
```

---

## Troubleshooting

### Issue: Stats seem wrong
**Solution**: Check calculation quality
```dart
if (metrics['calculation_quality'] == 'basic') {
  print('Using default values - user has no profile');
} else if (metrics['calculation_quality'] == 'medium') {
  print('Using profile but no GPS/sessions - estimates only');
} else {
  print('High quality: profile + GPS/sessions');
}
```

### Issue: Guest users see zeros
**Solution**: Verify fallback logic
```dart
final metrics = StepCalculationHelper.calculateAllMetrics(
  steps: steps,
  userProfile: null, // This should work
);

// Should return non-zero values using defaults
assert(metrics['distance_km'] > 0);
assert(metrics['calories'] > 0);
```

### Issue: Performance concerns
**Solution**: Call `calculateAllMetrics` once per update
```dart
// BAD: Multiple calls
final distance = StepCalculationHelper.calculateDistance(...);
final calories = StepCalculationHelper.calculateCalories(...);
final speed = StepCalculationHelper.calculateAverageSpeed(...);

// GOOD: Single call
final metrics = StepCalculationHelper.calculateAllMetrics(...);
final distance = metrics['distance_km'];
final calories = metrics['calories'];
final speed = metrics['avg_speed_kmh'];
```

---

## Next Steps

1. ✅ Test with guest user (no profile)
2. ✅ Test with authenticated user (with profile)
3. ✅ Test with GPS enabled
4. ✅ Add quality indicators to UI
5. ✅ Show profile completion prompt
6. ⏳ Monitor accuracy in production
7. ⏳ Gather user feedback
8. ⏳ Deploy Phase 3 (Cloud Functions) when ready

---

**Last Updated**: 2025-10-11
**Helper Version**: 1.0
**Location**: `lib/utils/step_calculation_helper.dart`
