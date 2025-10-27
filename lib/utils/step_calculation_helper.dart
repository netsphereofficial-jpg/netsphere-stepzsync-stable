/// Step Calculation Helper
/// Provides personalized step-based calculations (distance, calories, active time)
/// Falls back to defaults for guest users or missing profile data

import '../models/profile_models.dart';

class StepCalculationHelper {
  // Default constants for guest users or missing profile data
  static const double _defaultStepLengthMeters = 0.78;
  static const double _defaultCaloriesPerStep = 0.05;
  static const double _defaultWeightKg = 70.0; // Average adult weight
  static const double _defaultHeightCm = 170.0; // Average adult height

  // Average walking speeds for MET calculation
  static const Map<String, double> _walkingMET = {
    'very_slow': 2.0,  // < 3 km/h
    'slow': 2.8,       // 3-4 km/h
    'normal': 3.5,     // 4-5 km/h
    'brisk': 4.3,      // 5-6 km/h
    'fast': 5.0,       // 6+ km/h
  };

  /// Calculate personalized step length based on height
  /// Formula: step_length = height * 0.415 (standard biomechanics formula)
  /// Falls back to default for guest users
  static double calculateStepLength(UserProfile? userProfile) {
    if (userProfile == null || userProfile.height == 0) {
      return _defaultStepLengthMeters;
    }

    double heightInCm = userProfile.height;

    // Convert to cm if height is in inches
    if (userProfile.heightUnit.toLowerCase() == 'inches') {
      heightInCm = userProfile.height * 2.54;
    }

    // Calculate step length: height * 0.415 / 100 (to convert cm to meters)
    final stepLength = (heightInCm * 0.415) / 100;

    // Sanity check: step length should be between 0.5m and 1.2m
    return stepLength.clamp(0.5, 1.2);
  }

  /// Calculate distance in kilometers from steps
  /// Uses personalized step length if profile available
  /// STEP-BASED ONLY (no GPS tracking)
  static double calculateDistance({
    required int steps,
    UserProfile? userProfile,
  }) {
    // Calculate from steps using personalized step length
    final stepLength = calculateStepLength(userProfile);
    final distanceMeters = steps * stepLength;
    final distanceKm = distanceMeters / 1000;

    return distanceKm;
  }

  /// Calculate calories burned using enhanced MET (Metabolic Equivalent) formula
  /// Takes into account: weight, speed, age, gender, and steps
  /// Falls back to simple calculation for guest users
  static int calculateCalories({
    required int steps,
    required double distanceKm,
    required int activeTimeMinutes,
    UserProfile? userProfile,
  }) {
    // For guest users or missing profile data, use simple calculation
    if (userProfile == null || userProfile.weight == 0) {
      return (steps * _defaultCaloriesPerStep).round();
    }

    double weightKg = userProfile.weight;

    // Convert to kg if weight is in lbs
    if (userProfile.weightUnit.toLowerCase() == 'lbs') {
      weightKg = userProfile.weight * 0.453592;
    }

    // Calculate average speed (km/h)
    double avgSpeed = 0.0;
    if (activeTimeMinutes > 0) {
      final hours = activeTimeMinutes / 60.0;
      avgSpeed = distanceKm / hours;
    } else {
      // Estimate speed: average person walks ~5 km/h
      avgSpeed = 5.0;
    }

    // Determine MET value based on walking speed
    double MET;
    if (avgSpeed < 3) {
      MET = _walkingMET['very_slow']!;
    } else if (avgSpeed < 4) {
      MET = _walkingMET['slow']!;
    } else if (avgSpeed < 5) {
      MET = _walkingMET['normal']!;
    } else if (avgSpeed < 6) {
      MET = _walkingMET['brisk']!;
    } else {
      MET = _walkingMET['fast']!;
    }

    // Apply age factor (metabolism decreases ~2% per decade after 25)
    double ageFactor = 1.0;
    if (userProfile.dateOfBirth != null) {
      final age = DateTime.now().difference(userProfile.dateOfBirth!).inDays ~/ 365;
      if (age > 25) {
        ageFactor = 1.0 - ((age - 25) * 0.002);
      }
    }

    // Apply gender factor (women burn ~10% fewer calories on average)
    double genderFactor = 1.0;
    if (userProfile.gender.toLowerCase() == 'female' ||
        userProfile.gender == '2') {
      genderFactor = 0.9;
    }

    // Calculate calories using MET formula
    // Formula: calories = (weight_kg * MET * duration_minutes * factors) / 60
    final durationMinutes = activeTimeMinutes > 0 ? activeTimeMinutes : (steps / 100).toDouble();
    final calories = (weightKg * MET * durationMinutes * ageFactor * genderFactor) / 60;

    return calories.round();
  }

  /// Estimate active time from steps
  /// Uses average walking cadence (steps per minute)
  /// Average person walks at ~100-115 steps/minute
  static int estimateActiveTime({
    required int steps,
    int? actualActiveTimeMinutes, // Use actual if available
  }) {
    // If actual active time is available, use it
    if (actualActiveTimeMinutes != null && actualActiveTimeMinutes > 0) {
      return actualActiveTimeMinutes;
    }

    // Estimate using average cadence of 100 steps per minute
    const averageCadence = 100; // steps per minute
    final estimatedMinutes = (steps / averageCadence).round();

    return estimatedMinutes;
  }

  /// Calculate average speed in km/h
  static double calculateAverageSpeed({
    required double distanceKm,
    required int activeTimeMinutes,
  }) {
    if (activeTimeMinutes == 0) return 0.0;

    final hours = activeTimeMinutes / 60.0;
    final speed = distanceKm / hours;

    return speed;
  }

  /// Calculate pace (minutes per kilometer)
  static double calculatePace({
    required double distanceKm,
    required int activeTimeMinutes,
  }) {
    if (distanceKm == 0) return 0.0;

    final paceMinPerKm = activeTimeMinutes / distanceKm;

    return paceMinPerKm;
  }

  /// Calculate cadence (steps per minute)
  static double calculateCadence({
    required int steps,
    required int activeTimeMinutes,
  }) {
    if (activeTimeMinutes == 0) return 0.0;

    final cadence = steps / activeTimeMinutes;

    return cadence;
  }

  /// Calculate stride length (distance per step in meters)
  static double calculateStrideLength({
    required int steps,
    required double distanceKm,
  }) {
    if (steps == 0) return 0.0;

    final distanceMeters = distanceKm * 1000;
    final strideLength = distanceMeters / steps;

    return strideLength;
  }

  /// Get calculation quality indicator
  /// Helps UI show user how accurate the stats are
  /// STEP-BASED ONLY (no GPS)
  static String getCalculationQuality({
    bool hasUserProfile = false,
    bool hasActualActiveTime = false,
  }) {
    if (hasUserProfile && hasActualActiveTime) {
      return 'high'; // Personalized + actual walking time
    } else if (hasUserProfile) {
      return 'good'; // Personalized estimates
    } else if (hasActualActiveTime) {
      return 'medium'; // Default profile + actual time
    } else {
      return 'basic'; // Guest user / default estimates
    }
  }

  /// Format duration from minutes to HH:mm
  static String formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  /// Calculate all metrics at once for efficiency
  /// Returns a map with all calculated values
  /// STEP-BASED ONLY (no GPS tracking)
  static Map<String, dynamic> calculateAllMetrics({
    required int steps,
    UserProfile? userProfile,
    int? actualActiveTimeMinutes,
  }) {
    // Calculate distance from steps
    final distance = calculateDistance(
      steps: steps,
      userProfile: userProfile,
    );

    // Calculate or estimate active time
    final activeTime = estimateActiveTime(
      steps: steps,
      actualActiveTimeMinutes: actualActiveTimeMinutes,
    );

    // Calculate calories
    final calories = calculateCalories(
      steps: steps,
      distanceKm: distance,
      activeTimeMinutes: activeTime,
      userProfile: userProfile,
    );

    // Calculate speed and pace
    final avgSpeed = calculateAverageSpeed(
      distanceKm: distance,
      activeTimeMinutes: activeTime,
    );

    final pace = calculatePace(
      distanceKm: distance,
      activeTimeMinutes: activeTime,
    );

    // Calculate cadence and stride length
    final cadence = calculateCadence(
      steps: steps,
      activeTimeMinutes: activeTime,
    );

    final strideLength = calculateStrideLength(
      steps: steps,
      distanceKm: distance,
    );

    // Get quality indicator (step-based only)
    final quality = getCalculationQuality(
      hasUserProfile: userProfile != null && userProfile.weight > 0,
      hasActualActiveTime: actualActiveTimeMinutes != null && actualActiveTimeMinutes > 0,
    );

    return {
      'steps': steps,
      'distance_km': double.parse(distance.toStringAsFixed(2)),
      'calories': calories,
      'active_time_minutes': activeTime,
      'active_time_formatted': formatDuration(activeTime),
      'avg_speed_kmh': double.parse(avgSpeed.toStringAsFixed(1)),
      'pace_min_per_km': double.parse(pace.toStringAsFixed(1)),
      'cadence': double.parse(cadence.toStringAsFixed(1)),
      'stride_length_meters': double.parse(strideLength.toStringAsFixed(2)),
      'calculation_quality': quality,
      'is_personalized': userProfile != null && userProfile.weight > 0,
    };
  }
}
