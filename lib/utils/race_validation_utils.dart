import 'dart:developer' as dev;

/// Validation utilities for race step calculations
///
/// Provides sanity checks to detect anomalous data that could indicate:
/// - Duplicate step counting
/// - Data corruption
/// - Sensor errors
/// - Potential abuse
class RaceValidationUtils {
  // Validation thresholds
  static const int MAX_STEPS_PER_MINUTE = 200; // Fast running
  static const int MAX_STEPS_PER_SYNC = 10000; // Absolute maximum per sync
  static const double MAX_SPEED_KMH = 20.0; // Fast running speed
  static const double MAX_DISTANCE_MULTIPLIER = 1.1; // Allow 10% overshoot

  /// Validate step delta is reasonable given the time elapsed
  ///
  /// Returns validation result with error/warning messages
  static ValidationResult validateStepDelta({
    required int previousSteps,
    required int newSteps,
    required Duration timeSinceLastSync,
  }) {
    final delta = newSteps - previousSteps;

    // Allow negative deltas (pedometer resets are OK)
    if (delta < 0) {
      return ValidationResult.warning(
        'Negative step delta: $delta steps (pedometer reset?)',
      );
    }

    // Check against absolute maximum
    if (delta > MAX_STEPS_PER_SYNC) {
      return ValidationResult.error(
        'Step delta exceeds absolute maximum: $delta > $MAX_STEPS_PER_SYNC steps',
        suggestedFix: 'Cap delta at $MAX_STEPS_PER_SYNC steps',
      );
    }

    // Check steps per minute rate
    final minutes = timeSinceLastSync.inMinutes.clamp(1, 60);
    final stepsPerMinute = delta / minutes;

    if (stepsPerMinute > MAX_STEPS_PER_MINUTE) {
      return ValidationResult.error(
        'Step rate too high: ${stepsPerMinute.toInt()} steps/min (max: $MAX_STEPS_PER_MINUTE)',
        suggestedFix: 'Cap rate at ${MAX_STEPS_PER_MINUTE * minutes} steps for $minutes minute(s)',
      );
    }

    return ValidationResult.ok();
  }

  /// Validate distance doesn't exceed race total distance
  ///
  /// Allows small overshoot for GPS/calculation errors
  static ValidationResult validateDistance({
    required double participantDistance,
    required double raceTotalDistance,
  }) {
    if (participantDistance > raceTotalDistance * MAX_DISTANCE_MULTIPLIER) {
      return ValidationResult.error(
        'Distance exceeds race limit: ${participantDistance.toStringAsFixed(2)}km > ${raceTotalDistance.toStringAsFixed(2)}km (${MAX_DISTANCE_MULTIPLIER}x)',
        suggestedFix: 'Cap distance at ${(raceTotalDistance * MAX_DISTANCE_MULTIPLIER).toStringAsFixed(2)}km',
      );
    }

    return ValidationResult.ok();
  }

  /// Validate average speed is realistic for walking/running
  ///
  /// Checks against maximum human running speed
  static ValidationResult validateSpeed({
    required double distanceKm,
    required Duration duration,
  }) {
    if (duration.inSeconds == 0) {
      return ValidationResult.ok(); // Can't calculate speed yet
    }

    final hours = duration.inMinutes / 60.0;
    final speedKmh = distanceKm / hours;

    if (speedKmh > MAX_SPEED_KMH) {
      return ValidationResult.error(
        'Speed too high: ${speedKmh.toStringAsFixed(1)} km/h (max: $MAX_SPEED_KMH km/h)',
        suggestedFix: 'Possible data corruption or teleportation detected',
      );
    }

    return ValidationResult.ok();
  }

  /// Validate all race metrics at once
  ///
  /// Returns a list of validation results for easy logging
  static List<ValidationResult> validateAll({
    required int previousSteps,
    required int newSteps,
    required Duration timeSinceLastSync,
    required double participantDistance,
    required double raceTotalDistance,
    String? raceTitle,
  }) {
    final results = <ValidationResult>[];

    // Validate step delta
    final stepResult = validateStepDelta(
      previousSteps: previousSteps,
      newSteps: newSteps,
      timeSinceLastSync: timeSinceLastSync,
    );
    if (!stepResult.isValid || stepResult.level == ValidationLevel.warning) {
      results.add(stepResult);
    }

    // Validate distance
    final distanceResult = validateDistance(
      participantDistance: participantDistance,
      raceTotalDistance: raceTotalDistance,
    );
    if (!distanceResult.isValid) {
      results.add(distanceResult);
    }

    // Validate speed
    final speedResult = validateSpeed(
      distanceKm: participantDistance,
      duration: timeSinceLastSync,
    );
    if (!speedResult.isValid) {
      results.add(speedResult);
    }

    // Log all issues
    if (results.isNotEmpty) {
      dev.log('⚠️ [VALIDATION] Issues detected for race: ${raceTitle ?? "Unknown"}');
      for (final result in results) {
        dev.log('   ${result.level == ValidationLevel.error ? "❌" : "⚠️"} ${result.message}');
        if (result.suggestedFix != null) {
          dev.log('      → ${result.suggestedFix}');
        }
      }
    }

    return results;
  }

  /// Check if any validation result is an error (not just warning)
  static bool hasErrors(List<ValidationResult> results) {
    return results.any((r) => !r.isValid);
  }

  /// Get all error messages from validation results
  static List<String> getErrorMessages(List<ValidationResult> results) {
    return results
        .where((r) => !r.isValid && r.message != null)
        .map((r) => r.message!)
        .toList();
  }

  /// Get all warning messages from validation results
  static List<String> getWarningMessages(List<ValidationResult> results) {
    return results
        .where((r) => r.isValid && r.level == ValidationLevel.warning && r.message != null)
        .map((r) => r.message!)
        .toList();
  }
}

/// Result of a validation check
class ValidationResult {
  final bool isValid;
  final String? message;
  final String? suggestedFix;
  final ValidationLevel level;

  ValidationResult.ok()
      : isValid = true,
        message = null,
        suggestedFix = null,
        level = ValidationLevel.ok;

  ValidationResult.warning(this.message, {this.suggestedFix})
      : isValid = true,
        level = ValidationLevel.warning;

  ValidationResult.error(this.message, {this.suggestedFix})
      : isValid = false,
        level = ValidationLevel.error;

  @override
  String toString() {
    if (isValid && level == ValidationLevel.ok) {
      return 'ValidationResult(OK)';
    }
    return 'ValidationResult(${level.name.toUpperCase()}: $message${suggestedFix != null ? " → $suggestedFix" : ""})';
  }
}

/// Validation severity level
enum ValidationLevel {
  ok,
  warning,
  error,
}
