import 'dart:developer';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:location/location.dart';
import 'package:android_intent_plus/android_intent.dart';
import '../utils/guest_utils.dart';

class PermissionService {
  static final Location _location = Location();

  /// Request location permissions when needed (for races/workouts)
  static Future<bool> requestLocationPermissions() async {
    try {
      log("📍 [PERM] Requesting location permissions...");

      // Skip location permission for guest users
      if (GuestUtils.isGuest()) {
        log("ℹ️ [PERM] Skipping location permission for guest user");
        return false;
      }

      // Check if location service is enabled first
      bool serviceEnabled = await _location.serviceEnabled();
      log("📊 [PERM] Location service enabled: $serviceEnabled");

      if (!serviceEnabled) {
        log("📱 [PERM] Requesting location service to be enabled...");
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          log("❌ [PERM] Location service not enabled by user");
          return false;
        }
      }

      if (Platform.isIOS) {
        return await _requestiOSLocationPermissions();
      } else {
        return await _requestAndroidLocationPermissions();
      }
    } catch (e) {
      log("❌ [PERM] Error requesting location permissions: $e");
      return false;
    }
  }

  static Future<bool> _requestiOSLocationPermissions() async {
    try {
      log("🍎 [PERM] Requesting iOS location permissions...");

      // First request "when in use" permission
      var whenInUseStatus = await Permission.locationWhenInUse.status;
      log("📊 [PERM] Current 'when in use' status: $whenInUseStatus");

      if (!whenInUseStatus.isGranted) {
        whenInUseStatus = await Permission.locationWhenInUse.request();
        log("📊 [PERM] 'When in use' request result: $whenInUseStatus");
      }

      if (whenInUseStatus.isGranted) {
        // Then request "always" for background
        var alwaysStatus = await Permission.locationAlways.status;
        log("📊 [PERM] Current 'always' status: $alwaysStatus");

        if (!alwaysStatus.isGranted) {
          alwaysStatus = await Permission.locationAlways.request();
          log("📊 [PERM] 'Always' request result: $alwaysStatus");
        }

        if (alwaysStatus.isGranted) {
          log("✅ [PERM] iOS location permissions granted (always)");
          return true;
        } else {
          log("⚠️ [PERM] iOS 'always' denied, but 'when in use' granted");
          return true; // Still usable for foreground
        }
      } else {
        log("❌ [PERM] iOS location permission denied");
        return false;
      }
    } catch (e) {
      log("❌ [PERM] iOS location permission error: $e");
      return false;
    }
  }

  static Future<bool> _requestAndroidLocationPermissions() async {
    try {
      log("🤖 [PERM] Requesting Android location permissions...");

      // Request precise location first
      var preciseStatus = await Permission.location.status;
      log("📊 [PERM] Current precise location status: $preciseStatus");

      if (!preciseStatus.isGranted) {
        preciseStatus = await Permission.location.request();
        log("📊 [PERM] Precise location request result: $preciseStatus");
      }

      if (preciseStatus.isGranted) {
        // Request background location for Android 10+
        var backgroundStatus = await Permission.locationAlways.status;
        log("📊 [PERM] Current background location status: $backgroundStatus");

        if (!backgroundStatus.isGranted) {
          backgroundStatus = await Permission.locationAlways.request();
          log("📊 [PERM] Background location request result: $backgroundStatus");
        }

        if (backgroundStatus.isGranted) {
          log("✅ [PERM] Android location permissions granted (background)");
          return true;
        } else {
          log("⚠️ [PERM] Android background location denied, using foreground only");
          return true; // Still usable for foreground
        }
      } else {
        log("❌ [PERM] Android location permission denied");
        return false;
      }
    } catch (e) {
      log("❌ [PERM] Android location permission error: $e");
      return false;
    }
  }

  /// Request notification permissions when needed
  static Future<bool> requestNotificationPermissions() async {
    try {
      log("📱 [PERM] Requesting notification permissions...");

      if (Platform.isAndroid) {
        final permissionStatus = await Permission.notification.status;
        if (!permissionStatus.isGranted) {
          final granted = await Permission.notification.request();
          if (!granted.isGranted) {
            log('❌ [PERM] Android notification permission denied');
            return false;
          }
        }
        log('✅ [PERM] Android notification permissions granted');
        return true;
      } else {
        // iOS notification permissions are handled by flutter_local_notifications
        log('🍎 [PERM] iOS notification permissions handled by flutter_local_notifications');
        return true;
      }
    } catch (e) {
      log("❌ [PERM] Error requesting notification permissions: $e");
      return false;
    }
  }

  /// Request battery optimization exemption (Android only)
  static Future<bool> requestBatteryOptimizationExemption() async {
    try {
      if (Platform.isAndroid) {
        log("🔋 [PERM] Requesting battery optimization exemption...");
        final status = await Permission.ignoreBatteryOptimizations.request();
        if (status.isGranted) {
          log("✅ [PERM] Battery optimization exemption granted");
          return true;
        } else {
          log("⚠️ [PERM] Battery optimization exemption denied - app may be killed in background");
          return false;
        }
      }
      return true; // iOS doesn't need this
    } catch (e) {
      log("❌ [PERM] Error requesting battery optimization exemption: $e");
      return false;
    }
  }

  /// Request camera permission when needed
  static Future<bool> requestCameraPermission() async {
    try {
      log("📷 [PERM] Requesting camera permission...");

      var cameraPermission = await Permission.camera.status;
      if (cameraPermission.isDenied) {
        cameraPermission = await Permission.camera.request();
      }

      if (cameraPermission.isGranted) {
        log("✅ [PERM] Camera permission granted");
        return true;
      } else {
        log("❌ [PERM] Camera permission denied");
        return false;
      }
    } catch (e) {
      log("❌ [PERM] Error requesting camera permission: $e");
      return false;
    }
  }

  /// Check if a specific permission is granted
  static Future<bool> isPermissionGranted(Permission permission) async {
    try {
      final status = await permission.status;
      return status.isGranted;
    } catch (e) {
      log("❌ [PERM] Error checking permission status: $e");
      return false;
    }
  }

  /// Open app settings for manual permission management
  static Future<void> openPermissionSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      log("❌ [PERM] Error opening app settings: $e");
    }
  }

  /// Request unrestricted background execution (Android aggressive mode)
  static Future<bool> requestUnrestrictedBackgroundExecution() async {
    try {
      if (Platform.isAndroid) {
        log("🔋 [PERM] Requesting unrestricted background execution...");

        // 1. First request foreground location permission
        var foregroundStatus = await Permission.location.status;
        log("📊 [PERM] Foreground location status: $foregroundStatus");

        if (!foregroundStatus.isGranted) {
          foregroundStatus = await Permission.location.request();
          log("📊 [PERM] Foreground location result: $foregroundStatus");
        }

        if (!foregroundStatus.isGranted) {
          log("❌ [PERM] Foreground location denied - cannot proceed");
          return false;
        }

        // 2. Request battery optimization exemption
        var batteryStatus = await Permission.ignoreBatteryOptimizations.status;
        log("📊 [PERM] Battery optimization status: $batteryStatus");

        if (!batteryStatus.isGranted) {
          batteryStatus = await Permission.ignoreBatteryOptimizations.request();
          log("📊 [PERM] Battery optimization exemption result: $batteryStatus");

          // If still not granted, open settings
          if (!batteryStatus.isGranted) {
            log("🔋 [PERM] Opening battery optimization settings...");
            await openBatteryOptimizationSettings();
          }
        }

        // 3. Request "Always Allow" location for background
        var alwaysLocationStatus = await Permission.locationAlways.status;
        log("📊 [PERM] Location always status: $alwaysLocationStatus");

        if (!alwaysLocationStatus.isGranted) {
          alwaysLocationStatus = await Permission.locationAlways.request();
          log("📊 [PERM] Location always result: $alwaysLocationStatus");
        }

        // 4. Verify final status
        final finalBatteryStatus = await Permission.ignoreBatteryOptimizations.status;
        final finalLocationStatus = await Permission.locationAlways.status;

        log("📊 [PERM] Final battery status: $finalBatteryStatus");
        log("📊 [PERM] Final location always status: $finalLocationStatus");

        // Return true only if background location is granted
        final success = finalLocationStatus.isGranted;
        if (success) {
          log("✅ [PERM] Unrestricted background execution granted");
        } else {
          log("❌ [PERM] Background location not granted - background sync will not work");
          log("💡 [PERM] User must go to Settings → StepzSync → Location → Always");
        }
        return success;
      } else {
        // iOS: Use proper two-step permission flow (When In Use → Always)
        log("🍎 [PERM] Requesting iOS background location (two-step flow)...");

        // Step 1: Request "When In Use" permission first
        var whenInUseStatus = await Permission.locationWhenInUse.status;
        log("📊 [PERM] Current 'When In Use' status: $whenInUseStatus");

        if (!whenInUseStatus.isGranted) {
          log("📱 [PERM] Requesting 'When In Use' permission...");
          whenInUseStatus = await Permission.locationWhenInUse.request();
          log("📊 [PERM] 'When In Use' request result: $whenInUseStatus");
        }

        if (!whenInUseStatus.isGranted) {
          log("❌ [PERM] iOS 'When In Use' permission denied");
          return false;
        }

        log("✅ [PERM] iOS 'When In Use' permission granted");

        // Step 2: Now request "Always" permission
        var alwaysStatus = await Permission.locationAlways.status;
        log("📊 [PERM] Current 'Always' status: $alwaysStatus");

        if (!alwaysStatus.isGranted) {
          log("📱 [PERM] Requesting 'Always Allow' permission...");
          alwaysStatus = await Permission.locationAlways.request();
          log("📊 [PERM] 'Always' request result: $alwaysStatus");
        }

        if (alwaysStatus.isGranted) {
          log("✅ [PERM] iOS 'Always' permission granted - background location enabled");
          return true;
        } else {
          log("⚠️ [PERM] iOS 'Always' denied, but 'When In Use' is granted");
          log("💡 [PERM] User can change to 'Always Allow' in Settings → StepzSync → Location");
          return false; // Need "Always" for background sync
        }
      }
    } catch (e) {
      log("❌ [PERM] Error requesting unrestricted background: $e");
      return false;
    }
  }

  /// Open battery optimization settings (Android)
  static Future<void> openBatteryOptimizationSettings() async {
    if (Platform.isAndroid) {
      try {
        log("🔋 [PERM] Opening battery optimization settings...");
        const intent = AndroidIntent(
          action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
        );
        await intent.launch();
      } catch (e) {
        log("❌ [PERM] Error opening battery settings: $e");
      }
    }
  }

  /// Check if background location permission is granted
  static Future<bool> hasBackgroundLocationPermission() async {
    try {
      final status = await Permission.locationAlways.status;
      return status.isGranted;
    } catch (e) {
      log("❌ [PERM] Error checking background location: $e");
      return false;
    }
  }

  /// Request "Always Allow" location permission specifically
  static Future<bool> requestAlwaysLocationPermission() async {
    try {
      log("📍 [PERM] Requesting 'Always Allow' location permission...");

      if (Platform.isAndroid) {
        // Android: First ensure foreground location is granted
        var foregroundStatus = await Permission.location.status;
        if (!foregroundStatus.isGranted) {
          foregroundStatus = await Permission.location.request();
        }

        if (!foregroundStatus.isGranted) {
          log("❌ [PERM] Foreground location denied");
          return false;
        }

        // Then request background location
        var alwaysStatus = await Permission.locationAlways.status;
        if (!alwaysStatus.isGranted) {
          alwaysStatus = await Permission.locationAlways.request();
        }

        log("📊 [PERM] Android 'Always' location result: $alwaysStatus");
        return alwaysStatus.isGranted;
      } else {
        // iOS: Request "Always" directly
        var alwaysStatus = await Permission.locationAlways.status;
        if (!alwaysStatus.isGranted) {
          alwaysStatus = await Permission.locationAlways.request();
        }

        log("📊 [PERM] iOS 'Always' location result: $alwaysStatus");
        return alwaysStatus.isGranted;
      }
    } catch (e) {
      log("❌ [PERM] Error requesting always location: $e");
      return false;
    }
  }
}