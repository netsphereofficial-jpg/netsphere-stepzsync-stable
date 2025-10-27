import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

/// Persistent permission dialog for pedometer/activity recognition
/// Shows a blocking dialog when permission is not granted
/// Follows iOS and Android platform-specific UI patterns
class PedometerPermissionDialog {
  static bool _isShowing = false;

  /// Show the permission dialog (non-dismissible)
  static void show({
    required bool isPermanentlyDenied,
  }) {
    if (_isShowing) {
      print('📱 Permission dialog already showing, skipping duplicate');
      return;
    }

    _isShowing = true;
    print('🚨 Showing pedometer permission dialog (permanently denied: $isPermanentlyDenied)');

    Get.dialog(
      PopScope(
        canPop: false, // Prevent back button dismissal
        child: Platform.isIOS
            ? _buildIOSDialog(isPermanentlyDenied)
            : _buildAndroidDialog(isPermanentlyDenied),
      ),
      barrierDismissible: false, // Prevent tap outside to dismiss
      barrierColor: Colors.black87, // Strong barrier to emphasize importance
    );
  }

  /// Dismiss the permission dialog
  static void dismiss() {
    if (_isShowing) {
      _isShowing = false;
      Get.back();
      print('✅ Permission dialog dismissed');
    }
  }

  /// iOS-style Cupertino dialog
  static Widget _buildIOSDialog(bool isPermanentlyDenied) {
    return CupertinoAlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.location_fill,
            color: CupertinoColors.systemBlue,
            size: 24,
          ),
          SizedBox(width: 8),
          Text('Motion & Fitness Required'),
        ],
      ),
      content: Column(
        children: [
          SizedBox(height: 12),
          Text(
            isPermanentlyDenied
                ? 'StepzSync needs access to Motion & Fitness to track your steps accurately.\n\nPlease enable it in Settings → StepzSync → Motion & Fitness.'
                : 'StepzSync tracks your daily steps using your device\'s motion sensors.\n\nThis permission is required for the app to function properly.',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
      actions: [
        if (isPermanentlyDenied)
          CupertinoDialogAction(
            child: Text('Open Settings'),
            onPressed: () async {
              await openAppSettings();
              // Don't dismiss - will be dismissed when permission is granted
            },
          )
        else
          CupertinoDialogAction(
            child: Text('Grant Permission'),
            isDefaultAction: true,
            onPressed: () async {
              final status = await Permission.activityRecognition.request();
              if (status.isGranted) {
                dismiss();
              } else if (status.isPermanentlyDenied) {
                // Update dialog to show settings option
                dismiss();
                show(isPermanentlyDenied: true);
              }
            },
          ),
      ],
    );
  }

  /// Android-style Material dialog
  static Widget _buildAndroidDialog(bool isPermanentlyDenied) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.directions_walk,
              color: Colors.blue,
              size: 24,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Physical Activity Required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isPermanentlyDenied
                ? 'StepzSync needs permission to access your physical activity data to track your steps.\n\nTo continue using the app, please:'
                : 'StepzSync tracks your daily steps using your device\'s activity sensors.',
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
          if (isPermanentlyDenied) ...[
            SizedBox(height: 16),
            _buildInstructionStep(
              '1',
              'Tap "Open Settings" below',
            ),
            SizedBox(height: 8),
            _buildInstructionStep(
              '2',
              'Find "StepzSync" in the app list',
            ),
            SizedBox(height: 8),
            _buildInstructionStep(
              '3',
              'Enable "Physical activity" permission',
            ),
            SizedBox(height: 8),
            _buildInstructionStep(
              '4',
              'Return to the app',
            ),
          ] else ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This permission is required for the app to function properly.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (isPermanentlyDenied)
          TextButton(
            onPressed: () async {
              await openAppSettings();
              // Don't dismiss - will be dismissed when permission is granted
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Open Settings'),
          )
        else
          TextButton(
            onPressed: () async {
              final status = await Permission.activityRecognition.request();
              if (status.isGranted) {
                dismiss();
              } else if (status.isPermanentlyDenied) {
                // Update dialog to show settings option
                dismiss();
                show(isPermanentlyDenied: true);
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Grant Permission'),
          ),
      ],
    );
  }

  /// Helper to build instruction steps for Android settings
  static Widget _buildInstructionStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
