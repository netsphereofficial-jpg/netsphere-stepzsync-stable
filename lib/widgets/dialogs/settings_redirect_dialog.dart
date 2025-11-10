import 'package:flutter/material.dart';
import 'dart:io';
import '../../services/onboarding_service.dart';

/// Dialog shown when user has denied a permission multiple times
/// Provides instructions to manually enable permission in device settings
class SettingsRedirectDialog extends StatelessWidget {
  final PermissionType permissionType;
  final VoidCallback onOpenSettings;

  const SettingsRedirectDialog({
    Key? key,
    required this.permissionType,
    required this.onOpenSettings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final content = _getContentForPermissionType();

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE74C3C).withOpacity(0.1), // Light red
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.settings_outlined,
              color: Color(0xFFE74C3C), // Error red
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Enable in Settings',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2759FF), // Primary blue
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content.description,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Color(0xFF3F4E75), // Label color
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Follow these steps:',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3F4E75),
            ),
          ),
          const SizedBox(height: 12),
          ...content.steps.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final step = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2759FF), // Primary blue
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '$index',
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: Color(0xFF3F4E75),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
      actions: [
        ElevatedButton.icon(
          onPressed: onOpenSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2759FF), // Primary blue
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          icon: const Icon(Icons.settings, size: 18),
          label: const Text(
            'Open Settings',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// Get content based on permission type and platform
  _DialogContent _getContentForPermissionType() {
    switch (permissionType) {
      case PermissionType.notification:
        return _DialogContent(
          description: 'To receive race updates and notifications, you need to enable permission in your device settings.',
          steps: Platform.isIOS
              ? [
                  'Open Settings app',
                  'Scroll down and tap "StepzSync"',
                  'Tap "Notifications"',
                  'Toggle "Allow Notifications" ON',
                  'Return to StepzSync',
                ]
              : [
                  'Open Settings app',
                  'Tap "Apps" or "Applications"',
                  'Find and tap "StepzSync"',
                  'Tap "Notifications"',
                  'Enable "All notifications"',
                  'Return to StepzSync',
                ],
        );

      case PermissionType.activity:
        final permissionName = Platform.isIOS ? 'Motion & Fitness' : 'Physical Activity';
        return _DialogContent(
          description: 'Step tracking requires $permissionName permission. Please enable it in settings to use the app.',
          steps: Platform.isIOS
              ? [
                  'Open Settings app',
                  'Scroll down and tap "Privacy & Security"',
                  'Tap "Motion & Fitness"',
                  'Find "StepzSync" and toggle it ON',
                  'Return to StepzSync',
                ]
              : [
                  'Open Settings app',
                  'Tap "Apps" or "Applications"',
                  'Find and tap "StepzSync"',
                  'Tap "Permissions"',
                  'Tap "Physical Activity" or "Body Sensors"',
                  'Select "Allow"',
                  'Return to StepzSync',
                ],
        );

      case PermissionType.health:
        final appName = Platform.isIOS ? 'HealthKit' : 'Health Connect';
        return _DialogContent(
          description: 'To sync your health data, you need to grant access to $appName in your device settings.',
          steps: Platform.isIOS
              ? [
                  'Open Settings app',
                  'Scroll down and tap "Health"',
                  'Tap "Data Access & Devices"',
                  'Tap "StepzSync"',
                  'Enable the health data you want to share',
                  'Return to StepzSync',
                ]
              : [
                  'Make sure Health Connect app is installed',
                  'Open Health Connect app',
                  'Tap "App permissions"',
                  'Find and tap "StepzSync"',
                  'Enable data types (Steps, Heart Rate, etc.)',
                  'Return to StepzSync',
                ],
        );
    }
  }
}

/// Model for dialog content
class _DialogContent {
  final String description;
  final List<String> steps;

  _DialogContent({
    required this.description,
    required this.steps,
  });
}
