import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../utils/health_permissions_helper.dart';
import 'samsung_health_onboarding_dialog.dart';

/// Comprehensive health permission handler that shows appropriate UI based on device state
class HealthPermissionHandlerDialog {
  static final _helper = HealthPermissionsHelper();

  /// Show the appropriate permission dialog based on current state
  ///
  /// This method:
  /// 1. Validates health setup
  /// 2. Shows Samsung Health onboarding if needed
  /// 3. Requests permissions
  /// 4. Handles denials gracefully
  /// 5. Provides deep links to settings when needed
  static Future<bool> requestPermissions({
    bool showOnboarding = true,
  }) async {
    // Validate current setup
    final validation = await _helper.validateHealthSetup();

    // Handle different scenarios
    switch (validation.reason) {
      case HealthPermissionValidationReason.valid:
        // Already has permissions
        _showSuccessSnackbar();
        return true;

      case HealthPermissionValidationReason.guestUser:
        _showGuestUserMessage();
        return false;

      case HealthPermissionValidationReason.healthConnectNotInstalled:
        await _showHealthConnectNotInstalledDialog(validation);
        return false;

      case HealthPermissionValidationReason.healthKitNotAvailable:
        _showHealthKitNotAvailableMessage();
        return false;

      case HealthPermissionValidationReason.maxDenialsReached:
        await _showMaxDenialsDialog(validation);
        return false;

      case HealthPermissionValidationReason.permissionsDenied:
        return await _handlePermissionRequest(validation, showOnboarding);

      case HealthPermissionValidationReason.unknownError:
        _showErrorMessage('Unknown error occurred');
        return false;
    }
  }

  /// Handle permission request flow with onboarding
  static Future<bool> _handlePermissionRequest(
    HealthPermissionValidationResult validation,
    bool showOnboarding,
  ) async {
    // Show Samsung Health onboarding if needed
    if (showOnboarding &&
        validation.shouldShowSamsungHealthGuide &&
        await _helper.shouldShowOnboarding()) {
      final shouldContinue = await SamsungHealthOnboardingDialog.show();

      if (shouldContinue != true) {
        return false;
      }
    }

    // Request permissions
    final granted = await _helper.requestHealthPermissions(skipOnboarding: true);

    if (granted) {
      _showSuccessSnackbar();
      return true;
    } else {
      // Check if max denials reached after this attempt
      if (!await _helper.shouldShowPermissionRequest()) {
        _showMaxDenialsMessage();
      } else {
        _showPermissionDeniedMessage(validation);
      }
      return false;
    }
  }

  /// Show dialog when Health Connect is not installed
  static Future<void> _showHealthConnectNotInstalledDialog(
    HealthPermissionValidationResult validation,
  ) async {
    await Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Get.theme.colorScheme.error,
            ),
            const SizedBox(width: 8),
            const Text('Health Connect Required'),
          ],
        ),
        content: Text(validation.message),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Get.back();
              await _helper.openHealthConnectInPlayStore();
            },
            icon: const Icon(Icons.download),
            label: const Text('Install'),
          ),
        ],
      ),
    );
  }

  /// Show dialog when max denials reached
  static Future<void> _showMaxDenialsDialog(
    HealthPermissionValidationResult validation,
  ) async {
    await Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.settings,
              color: Get.theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('Enable in Settings'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'ve declined permissions multiple times. Please enable them manually in Health Connect settings.',
              style: Get.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (validation.hasSamsungHealth) ...[
              Text(
                'For Samsung devices:',
                style: Get.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text('1. Connect Samsung Health to Health Connect'),
              const Text('2. Open Health Connect settings'),
              const Text('3. Enable StepzSync permissions'),
            ] else ...[
              const Text('1. Open Health Connect app'),
              const Text('2. Go to App permissions'),
              const Text('3. Find StepzSync'),
              const Text('4. Enable all data types'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          if (validation.hasSamsungHealth)
            TextButton(
              onPressed: () async {
                await _helper.openSamsungHealthApp();
              },
              child: const Text('Open Samsung Health'),
            ),
          ElevatedButton.icon(
            onPressed: () async {
              Get.back();
              await _helper.openHealthSettings();
            },
            icon: const Icon(Icons.settings),
            label: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // Snackbar and message methods
  static void _showSuccessSnackbar() {
    Get.snackbar(
      'Success',
      'Health permissions granted! Your fitness data will now sync.',
      icon: const Icon(Icons.check_circle, color: Colors.green),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.withOpacity(0.1),
      colorText: Colors.green[700],
      duration: const Duration(seconds: 3),
    );
  }

  static void _showGuestUserMessage() {
    Get.snackbar(
      'Guest Mode',
      'Sign in to sync your fitness data with Health Connect',
      icon: const Icon(Icons.person_outline),
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
    );
  }

  static void _showHealthKitNotAvailableMessage() {
    Get.snackbar(
      'Health Not Available',
      'Apple Health is not available on this device',
      icon: const Icon(Icons.error_outline),
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
    );
  }

  static void _showMaxDenialsMessage() {
    Get.snackbar(
      'Manual Setup Required',
      'Please enable permissions in Health Connect settings',
      icon: const Icon(Icons.settings),
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
      mainButton: TextButton(
        onPressed: () => _helper.openHealthSettings(),
        child: const Text('Open Settings'),
      ),
    );
  }

  static void _showPermissionDeniedMessage(
    HealthPermissionValidationResult validation,
  ) {
    Get.snackbar(
      'Permission Denied',
      validation.hasSamsungHealth
          ? 'Connect Samsung Health to Health Connect, then try again'
          : 'Health permissions are required for fitness tracking',
      icon: const Icon(Icons.block),
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
      mainButton: validation.hasSamsungHealth
          ? TextButton(
              onPressed: () => _helper.openSamsungHealthApp(),
              child: const Text('Open Samsung Health'),
            )
          : null,
    );
  }

  static void _showErrorMessage(String message) {
    Get.snackbar(
      'Error',
      message,
      icon: const Icon(Icons.error_outline, color: Colors.red),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.withOpacity(0.1),
      duration: const Duration(seconds: 3),
    );
  }

  /// Show a simple info dialog with setup instructions
  static Future<void> showSetupInstructions({bool isSamsungDevice = false}) async {
    final helper = HealthPermissionsHelper();
    final validation = await helper.validateHealthSetup();

    await Get.dialog(
      AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline),
            SizedBox(width: 8),
            Text('Setup Instructions'),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            validation.hasSamsungHealth
                ? helper.getSamsungHealthSetupMessage()
                : await helper.getPermissionDenialMessage(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Close'),
          ),
          if (validation.hasSamsungHealth)
            ElevatedButton(
              onPressed: () async {
                Get.back();
                await helper.openSamsungHealthApp();
              },
              child: const Text('Open Samsung Health'),
            )
          else
            ElevatedButton(
              onPressed: () async {
                Get.back();
                await helper.openHealthSettings();
              },
              child: const Text('Open Settings'),
            ),
        ],
      ),
    );
  }
}
