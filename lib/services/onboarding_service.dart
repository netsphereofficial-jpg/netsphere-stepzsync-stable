import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

/// Service to manage onboarding state and permission tracking
/// Determines whether user should see onboarding screens based on:
/// - Whether they've completed onboarding before
/// - Current permission grant status
class OnboardingService {
  // SharedPreferences keys
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyNotificationDeniedCount = 'notification_permission_denied_count';
  static const String _keyActivityDeniedCount = 'activity_permission_denied_count';
  static const String _keyHealthDeniedCount = 'health_permission_denied_count';

  // Maximum allowed denials before redirecting to settings
  static const int maxDenialCount = 2;

  /// Check if user should see onboarding screens
  /// Returns true if:
  /// - User hasn't completed onboarding AND
  /// - At least one required permission is not granted
  static Future<bool> shouldShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if user explicitly completed onboarding
    final hasCompleted = prefs.getBool(_keyOnboardingCompleted) ?? false;

    // If completed, check if all permissions are still granted
    if (hasCompleted) {
      final allPermissionsGranted = await _checkAllPermissionsGranted();

      // Show onboarding again if permissions were revoked
      if (!allPermissionsGranted) {
        await resetOnboardingStatus();
        return true;
      }

      return false;
    }

    // First time user - show onboarding
    return true;
  }

  /// Check if all required permissions are granted
  static Future<bool> _checkAllPermissionsGranted() async {
    // Check notification permission
    final notificationGranted = await Permission.notification.isGranted;

    // Check activity recognition permission (platform-specific)
    bool activityGranted;
    if (Platform.isAndroid) {
      activityGranted = await Permission.activityRecognition.isGranted;
    } else {
      activityGranted = await Permission.sensors.isGranted; // iOS Motion & Fitness
    }

    // Health permission check is optional - we don't block if not granted
    // Users can skip health permission in onboarding

    return notificationGranted && activityGranted;
  }

  /// Mark onboarding as completed
  static Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingCompleted, true);
  }

  /// Reset onboarding status (useful for testing or if permissions revoked)
  static Future<void> resetOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingCompleted, false);
  }

  /// Get denial count for a specific permission type
  static Future<int> getDenialCount(PermissionType type) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKeyForPermissionType(type);
    return prefs.getInt(key) ?? 0;
  }

  /// Increment denial count for a specific permission type
  static Future<void> incrementDenialCount(PermissionType type) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKeyForPermissionType(type);
    final currentCount = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, currentCount + 1);
  }

  /// Reset denial count for a specific permission type
  static Future<void> resetDenialCount(PermissionType type) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKeyForPermissionType(type);
    await prefs.setInt(key, 0);
  }

  /// Check if user has reached maximum denials for a permission
  static Future<bool> hasReachedMaxDenials(PermissionType type) async {
    final count = await getDenialCount(type);
    return count >= maxDenialCount;
  }

  /// Get SharedPreferences key for permission type
  static String _getKeyForPermissionType(PermissionType type) {
    switch (type) {
      case PermissionType.notification:
        return _keyNotificationDeniedCount;
      case PermissionType.activity:
        return _keyActivityDeniedCount;
      case PermissionType.health:
        return _keyHealthDeniedCount;
    }
  }

  /// Clear all onboarding data (useful for testing)
  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOnboardingCompleted);
    await prefs.remove(_keyNotificationDeniedCount);
    await prefs.remove(_keyActivityDeniedCount);
    await prefs.remove(_keyHealthDeniedCount);
  }
}

/// Enum for permission types tracked in onboarding
enum PermissionType {
  notification,
  activity,
  health,
}
