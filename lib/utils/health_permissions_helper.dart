import 'dart:io';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/health_config.dart';
import '../utils/guest_utils.dart';

/// Helper class for managing health permissions (HealthKit/Health Connect)
class HealthPermissionsHelper {
  final Health _health = Health();

  // SharedPreferences keys for permission denial tracking
  static const String _permissionDenialCountKey = 'health_permission_denial_count';
  static const String _showOnboardingKey = 'show_health_onboarding';

  // Constants
  static const int maxConsecutiveDenials = 2;
  static const String samsungHealthPackage = 'com.sec.android.app.shealth';
  static const String healthConnectPackage = 'com.google.android.apps.healthdata';

  /// Check if Samsung Health is installed on the device (Android only)
  Future<bool> isSamsungHealthInstalled() async {
    if (!Platform.isAndroid) return false;

    try {
      // Note: android_intent_plus doesn't have a direct check method
      // We assume Samsung Health is installed on Samsung devices
      // This is a best-effort detection
      return true;
    } catch (e) {
      print('${HealthConfig.logPrefix} Samsung Health not detected: $e');
      return false;
    }
  }

  /// Check if Health Connect is installed (Android only)
  Future<bool> isHealthConnectInstalled() async {
    if (!Platform.isAndroid) return false;

    try {
      final isAvailable = await _health.isDataTypeAvailable(HealthDataType.STEPS);
      return isAvailable;
    } catch (e) {
      print('${HealthConfig.logPrefix} Health Connect not available: $e');
      return false;
    }
  }

  /// Check if health services are available on this device
  Future<bool> isHealthAvailable() async {
    try {
      // Guest users don't need health permissions
      if (GuestUtils.isGuest()) {
        return false;
      }

      // Check if Health Connect (Android) or HealthKit (iOS) is available
      if (Platform.isAndroid) {
        // Health Connect requires Android 9.0+ (API 28+)
        return await isHealthConnectInstalled();
      } else if (Platform.isIOS) {
        // HealthKit is available on all iOS devices
        return true;
      }
      return false;
    } catch (e) {
      print('${HealthConfig.logPrefix} Error checking health availability: $e');
      return false;
    }
  }

  /// Check if we have all required health permissions
  Future<bool> hasHealthPermissions() async {
    try {
      if (GuestUtils.isGuest()) return false;

      final hasPermissions = await _health.hasPermissions(
        HealthConfig.dataTypes,
        permissions: HealthConfig.permissions,
      );

      return hasPermissions ?? false;
    } catch (e) {
      print('${HealthConfig.logPrefix} Error checking health permissions: $e');
      return false;
    }
  }

  /// Get permission denial count
  Future<int> _getPermissionDenialCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_permissionDenialCountKey) ?? 0;
  }

  /// Increment permission denial count
  Future<void> _incrementPermissionDenialCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = await _getPermissionDenialCount();
    await prefs.setInt(_permissionDenialCountKey, count + 1);
  }

  /// Reset permission denial count (called when permissions are granted)
  Future<void> _resetPermissionDenialCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_permissionDenialCountKey, 0);
  }

  /// Check if we should show the permission request or direct to settings
  Future<bool> shouldShowPermissionRequest() async {
    final denialCount = await _getPermissionDenialCount();
    return denialCount < maxConsecutiveDenials;
  }

  /// Check if onboarding should be shown before requesting permissions
  Future<bool> shouldShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showOnboardingKey) ?? true;
  }

  /// Mark onboarding as shown
  Future<void> markOnboardingShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showOnboardingKey, false);
  }

  /// Request health permissions from the user with smart denial handling
  ///
  /// Returns true if all permissions granted, false otherwise
  Future<bool> requestHealthPermissions({bool skipOnboarding = false}) async {
    try {
      if (GuestUtils.isGuest()) {
        print('${HealthConfig.logPrefix} Skipping health permissions for guest user');
        return false;
      }

      // Check if we should show onboarding first
      if (!skipOnboarding && await shouldShowOnboarding()) {
        print('${HealthConfig.logPrefix} 💡 Onboarding should be shown before requesting permissions');
        print('${HealthConfig.logPrefix} 💡 Call markOnboardingShown() after showing onboarding UI');
        // Return false to indicate permissions not yet requested
        // The UI layer should show onboarding and call this method again with skipOnboarding=true
        return false;
      }

      // Check if we've exceeded consecutive denials
      if (!await shouldShowPermissionRequest()) {
        print('${HealthConfig.logPrefix} ⚠️ Maximum consecutive denials reached');
        print('${HealthConfig.logPrefix} 💡 User must enable permissions manually in settings');
        return false;
      }

      print('${HealthConfig.logPrefix} Requesting health permissions...');

      // On Android, first request activity recognition permission
      if (Platform.isAndroid) {
        final activityStatus = await Permission.activityRecognition.status;
        if (!activityStatus.isGranted) {
          final result = await Permission.activityRecognition.request();
          if (!result.isGranted) {
            print('${HealthConfig.logPrefix} Activity recognition permission denied');
            await _incrementPermissionDenialCount();
            return false;
          }
        }
      }

      // Request health data permissions
      final granted = await _health.requestAuthorization(
        HealthConfig.dataTypes,
        permissions: HealthConfig.permissions,
      );

      if (granted) {
        print('${HealthConfig.logPrefix} ✅ Health permissions granted successfully');
        await _resetPermissionDenialCount();
      } else {
        print('${HealthConfig.logPrefix} ❌ Health permissions denied by user');
        await _incrementPermissionDenialCount();

        // Check if this was the last allowed denial
        final denialCount = await _getPermissionDenialCount();
        if (denialCount >= maxConsecutiveDenials) {
          print('${HealthConfig.logPrefix} ⚠️ Maximum consecutive denials reached ($denialCount)');
          print('${HealthConfig.logPrefix} 💡 User will be directed to settings for future attempts');
        }
      }

      return granted;
    } catch (e) {
      print('${HealthConfig.logPrefix} ❌ Error requesting health permissions: $e');
      await _incrementPermissionDenialCount();

      // Provide helpful error message based on platform
      if (Platform.isAndroid) {
        print('${HealthConfig.logPrefix} 💡 Make sure Health Connect is installed from Play Store');
        print('${HealthConfig.logPrefix} 💡 User can enable permissions manually in Health Connect app');
      } else if (Platform.isIOS) {
        print('${HealthConfig.logPrefix} 💡 User can enable permissions in Settings > Privacy > Health');
      }

      return false;
    }
  }

  /// Get detailed permission status for each data type
  Future<Map<HealthDataType, bool>> getDetailedPermissionStatus() async {
    final Map<HealthDataType, bool> statusMap = {};

    for (final dataType in HealthConfig.dataTypes) {
      try {
        final hasPermission = await _health.hasPermissions(
          [dataType],
          permissions: [HealthDataAccess.READ],
        );
        statusMap[dataType] = hasPermission ?? false;
      } catch (e) {
        statusMap[dataType] = false;
      }
    }

    return statusMap;
  }

  /// Open Health Connect app directly (Android only)
  Future<bool> openHealthConnectApp() async {
    if (!Platform.isAndroid) return false;

    try {
      print('${HealthConfig.logPrefix} Opening Health Connect app...');

      final intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: healthConnectPackage,
      );

      await intent.launch();
      return true;
    } catch (e) {
      print('${HealthConfig.logPrefix} Failed to open Health Connect: $e');
      return false;
    }
  }

  /// Open Health Connect permissions screen for this app (Android only)
  Future<bool> openHealthConnectPermissions() async {
    if (!Platform.isAndroid) return false;

    try {
      print('${HealthConfig.logPrefix} Opening Health Connect permissions...');

      // Try to open Health Connect with VIEW_PERMISSION_USAGE action
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW_PERMISSION_USAGE',
        package: healthConnectPackage,
        category: 'android.intent.category.HEALTH_PERMISSIONS',
      );

      await intent.launch();
      return true;
    } catch (e) {
      print('${HealthConfig.logPrefix} Failed to open permissions screen, trying app: $e');
      // Fallback to opening the app directly
      return await openHealthConnectApp();
    }
  }

  /// Open Samsung Health app (Android only)
  Future<bool> openSamsungHealthApp() async {
    if (!Platform.isAndroid) return false;

    try {
      print('${HealthConfig.logPrefix} Opening Samsung Health app...');

      final intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: samsungHealthPackage,
      );

      await intent.launch();
      return true;
    } catch (e) {
      print('${HealthConfig.logPrefix} Failed to open Samsung Health: $e');
      return false;
    }
  }

  /// Open Play Store to install Health Connect
  Future<bool> openHealthConnectInPlayStore() async {
    if (!Platform.isAndroid) return false;

    try {
      print('${HealthConfig.logPrefix} Opening Play Store for Health Connect...');

      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'market://details?id=$healthConnectPackage',
      );

      await intent.launch();
      return true;
    } catch (e) {
      print('${HealthConfig.logPrefix} Failed to open Play Store: $e');
      // Try web fallback
      final webIntent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'https://play.google.com/store/apps/details?id=$healthConnectPackage',
      );
      try {
        await webIntent.launch();
        return true;
      } catch (e2) {
        print('${HealthConfig.logPrefix} Failed to open web Play Store: $e2');
        return false;
      }
    }
  }

  /// Open health app settings (Health Connect on Android, Health on iOS)
  Future<void> openHealthSettings() async {
    try {
      if (Platform.isAndroid) {
        // Try to open Health Connect permissions directly
        final opened = await openHealthConnectPermissions();
        if (!opened) {
          print('${HealthConfig.logPrefix} Opening app settings as fallback...');
          await openAppSettings();
        }
      } else if (Platform.isIOS) {
        // On iOS, we can't directly open Health app
        // User must manually go to Settings > Privacy > Health
        print('${HealthConfig.logPrefix} Please enable permissions in Settings > Privacy > Health > StepzSync');
        await openAppSettings();
      }
    } catch (e) {
      print('${HealthConfig.logPrefix} Error opening health settings: $e');
    }
  }

  /// Get a user-friendly message for permission denial
  Future<String> getPermissionDenialMessage() async {
    if (Platform.isAndroid) {
      final hasSamsungHealth = await isSamsungHealthInstalled();

      if (hasSamsungHealth) {
        return 'StepzSync needs access to Health Connect to sync your fitness data.\n\n'
            '📱 For Samsung Devices:\n'
            '1. Open Samsung Health app\n'
            '2. Tap Settings (⚙️) > Health Connect\n'
            '3. Enable data sync with Health Connect\n'
            '4. Return here and tap "Grant Permissions"\n\n'
            'Alternative method:\n'
            '1. Open Health Connect app\n'
            '2. Go to App permissions\n'
            '3. Find StepzSync and enable all data types';
      } else {
        return 'StepzSync needs access to Health Connect to sync your fitness data.\n\n'
            'To enable:\n'
            '1. Open Health Connect app\n'
            '2. Go to App permissions\n'
            '3. Find StepzSync\n'
            '4. Enable all data types';
      }
    } else if (Platform.isIOS) {
      return 'StepzSync needs access to Apple Health to sync your fitness data.\n\n'
          'To enable:\n'
          '1. Go to Settings > Privacy & Security\n'
          '2. Tap Health\n'
          '3. Find StepzSync\n'
          '4. Enable all data categories';
    }
    return 'Health permissions required to sync fitness data';
  }

  /// Get a user-friendly message for Health Connect not installed (Android)
  Future<String> getHealthNotInstalledMessage() async {
    final hasSamsungHealth = await isSamsungHealthInstalled();

    if (hasSamsungHealth) {
      return 'Health Connect is required to sync your fitness data.\n\n'
          '📱 Samsung Health is detected on your device!\n\n'
          'Setup steps:\n'
          '1. Install Health Connect from Play Store\n'
          '2. Open Samsung Health\n'
          '3. Go to Settings > Health Connect\n'
          '4. Enable data sync\n'
          '5. Return to StepzSync';
    } else {
      return 'Health Connect is not installed on your device.\n\n'
          'To use health sync:\n'
          '1. Open Google Play Store\n'
          '2. Search for "Health Connect"\n'
          '3. Install the app\n'
          '4. Reopen StepzSync';
    }
  }

  /// Get Samsung Health setup guide message
  String getSamsungHealthSetupMessage() {
    return '📱 Samsung Health Setup Required\n\n'
        'To sync your fitness data, you need to:\n\n'
        '1️⃣ Connect Samsung Health to Health Connect:\n'
        '   • Open Samsung Health\n'
        '   • Tap Settings (⚙️)\n'
        '   • Select "Health Connect"\n'
        '   • Enable data sync\n\n'
        '2️⃣ Grant StepzSync permissions:\n'
        '   • Return to this app\n'
        '   • Tap "Grant Permissions"\n'
        '   • Allow all data types\n\n'
        '💡 This is a one-time setup required by Android for privacy.';
  }

  /// Validate that Health services are properly configured
  Future<HealthPermissionValidationResult> validateHealthSetup() async {
    // Skip for guest users
    if (GuestUtils.isGuest()) {
      return HealthPermissionValidationResult(
        isValid: false,
        reason: HealthPermissionValidationReason.guestUser,
        message: 'Guest users cannot sync health data',
        hasSamsungHealth: false,
      );
    }

    // Check if health is available
    final isAvailable = await isHealthAvailable();
    final hasSamsungHealth = Platform.isAndroid ? await isSamsungHealthInstalled() : false;

    if (!isAvailable) {
      if (Platform.isAndroid) {
        return HealthPermissionValidationResult(
          isValid: false,
          reason: HealthPermissionValidationReason.healthConnectNotInstalled,
          message: await getHealthNotInstalledMessage(),
          hasSamsungHealth: hasSamsungHealth,
        );
      } else {
        return HealthPermissionValidationResult(
          isValid: false,
          reason: HealthPermissionValidationReason.healthKitNotAvailable,
          message: 'HealthKit is not available on this device',
          hasSamsungHealth: false,
        );
      }
    }

    // Check permissions
    final hasPermissions = await hasHealthPermissions();
    if (!hasPermissions) {
      // Check if user has exceeded denial limit
      final shouldShowRequest = await shouldShowPermissionRequest();
      final denialCount = await _getPermissionDenialCount();

      return HealthPermissionValidationResult(
        isValid: false,
        reason: shouldShowRequest
            ? HealthPermissionValidationReason.permissionsDenied
            : HealthPermissionValidationReason.maxDenialsReached,
        message: await getPermissionDenialMessage(),
        hasSamsungHealth: hasSamsungHealth,
        denialCount: denialCount,
      );
    }

    // All checks passed
    return HealthPermissionValidationResult(
      isValid: true,
      reason: HealthPermissionValidationReason.valid,
      message: 'Health sync is ready',
      hasSamsungHealth: hasSamsungHealth,
    );
  }
}

/// Result of health permission validation
class HealthPermissionValidationResult {
  final bool isValid;
  final HealthPermissionValidationReason reason;
  final String message;
  final bool hasSamsungHealth;
  final int denialCount;

  HealthPermissionValidationResult({
    required this.isValid,
    required this.reason,
    required this.message,
    required this.hasSamsungHealth,
    this.denialCount = 0,
  });

  /// Whether Samsung Health setup guidance should be shown
  bool get shouldShowSamsungHealthGuide =>
      hasSamsungHealth &&
      (reason == HealthPermissionValidationReason.permissionsDenied ||
          reason == HealthPermissionValidationReason.healthConnectNotInstalled);

  /// Whether user should be directed to settings instead of permission dialog
  bool get shouldDirectToSettings =>
      reason == HealthPermissionValidationReason.maxDenialsReached;
}

/// Reasons why health permissions might not be valid
enum HealthPermissionValidationReason {
  valid,
  guestUser,
  healthConnectNotInstalled,
  healthKitNotAvailable,
  permissionsDenied,
  maxDenialsReached,
  unknownError,
}
