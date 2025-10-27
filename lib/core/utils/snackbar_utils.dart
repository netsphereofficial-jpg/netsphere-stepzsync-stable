import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../utils/quick_validation.dart';

// Snackbar functionality replaced with quick validation for critical messages
class SnackbarUtils {
  static void showError(String title, String message) {
    // Only show validation for critical errors (login, auth, validation)
    if (_isCriticalError(title, message)) {
      try {
        final context = Get.context;
        if (context != null) {
          QuickValidation.showError(context, message);
        } else {
          // Fallback - just print for debugging
          print('Critical Error: $message');
        }
      } catch (e) {
        // Safe fallback if GetX context fails
        print('Critical Error: $message');
      }
    }
    // Other errors are silent
  }

  static void showSuccess(String title, String message) {
    // Only show validation for critical success (login, profile save)
    if (_isCriticalSuccess(title, message)) {
      try {
        final context = Get.context;
        if (context != null) {
          QuickValidation.showSuccess(context, message);
        } else {
          // Fallback - just print for debugging
          print('Critical Success: $message');
        }
      } catch (e) {
        // Safe fallback if GetX context fails
        print('Critical Success: $message');
      }
    }
    // Other success messages are silent
  }

  static void showInfo(String title, String message) {
    // Info messages are silent - no quick validation needed
  }

  static void showWarning(String title, String message) {
    // Only show validation for critical warnings (permissions, etc)
    if (_isCriticalWarning(title, message)) {
      try {
        final context = Get.context;
        if (context != null) {
          QuickValidation.showWarning(context, message);
        } else {
          // Fallback - just print for debugging
          print('Critical Warning: $message');
        }
      } catch (e) {
        // Safe fallback if GetX context fails
        print('Critical Warning: $message');
      }
    }
    // Other warnings are silent
  }

  // Helper methods to determine if a message is critical
  static bool _isCriticalError(String title, String message) {
    final criticalKeywords = [
      'login', 'error', 'failed', 'invalid', 'required', 'validation',
      'password', 'email', 'mobile', 'auth', 'permission'
    ];

    final combined = '$title $message'.toLowerCase();
    return criticalKeywords.any((keyword) => combined.contains(keyword));
  }

  static bool _isCriticalSuccess(String title, String message) {
    final criticalKeywords = [
      'login', 'welcome', 'account created', 'profile saved', 'registered'
    ];

    final combined = '$title $message'.toLowerCase();
    return criticalKeywords.any((keyword) => combined.contains(keyword));
  }

  static bool _isCriticalWarning(String title, String message) {
    final criticalKeywords = [
      'permission', 'required', 'denied', 'camera', 'location'
    ];

    final combined = '$title $message'.toLowerCase();
    return criticalKeywords.any((keyword) => combined.contains(keyword));
  }
}