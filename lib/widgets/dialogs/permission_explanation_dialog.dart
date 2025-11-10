import 'package:flutter/material.dart';
import 'dart:io';
import '../../services/onboarding_service.dart';

/// Dialog shown when user denies a permission
/// Explains why the permission is needed and offers retry/skip options
class PermissionExplanationDialog extends StatelessWidget {
  final PermissionType permissionType;
  final VoidCallback onRetry;
  final VoidCallback? onSkip; // Null means no skip option (mandatory permission)

  const PermissionExplanationDialog({
    Key? key,
    required this.permissionType,
    required this.onRetry,
    this.onSkip,
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
              color: content.iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              content.icon,
              color: content.iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              content.title,
              style: const TextStyle(
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
            'Why we need this:',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3F4E75),
            ),
          ),
          const SizedBox(height: 8),
          ...content.reasons.map((reason) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: Color(0xFF27AE60), // Success green
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reason,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: Color(0xFF3F4E75),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          if (content.isMandatory) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE74C3C).withOpacity(0.1), // Light red
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: Color(0xFFE74C3C), // Error red
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This permission is required for the app to work.',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Color(0xFFE74C3C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        // Skip button (if allowed)
        if (onSkip != null)
          TextButton(
            onPressed: onSkip,
            child: const Text(
              'Skip',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Color(0xFF7788B3), // Secondary blue
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        // Retry button
        ElevatedButton(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2759FF), // Primary blue
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text(
            'Try Again',
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

  /// Get content based on permission type
  _DialogContent _getContentForPermissionType() {
    switch (permissionType) {
      case PermissionType.notification:
        return _DialogContent(
          icon: Icons.notifications_outlined,
          iconColor: const Color(0xFFCDFF49), // Neon yellow
          title: 'Notification Permission',
          description: 'Enable notifications to stay updated on race events, friend activities, and achievements.',
          reasons: [
            'Get notified when races start and end',
            'Receive friend race invites and challenges',
            'Celebrate achievements and milestones',
            'Stay connected with the racing community',
          ],
          isMandatory: false,
        );

      case PermissionType.activity:
        final platformText = Platform.isIOS ? 'Motion & Fitness' : 'Activity Recognition';
        return _DialogContent(
          icon: Icons.directions_run,
          iconColor: const Color(0xFF2759FF), // Primary blue
          title: '$platformText Permission',
          description: 'This permission is essential for step counting and race participation.',
          reasons: [
            'Count your steps accurately throughout the day',
            'Track your progress in real-time during races',
            'Calculate distance walked and calories burned',
            'Compete fairly with other users',
          ],
          isMandatory: true,
        );

      case PermissionType.health:
        final platformText = Platform.isIOS ? 'HealthKit' : 'Health Connect';
        return _DialogContent(
          icon: Icons.favorite_border,
          iconColor: const Color(0xFF27AE60), // Success green
          title: '$platformText Connection',
          description: 'Connect your health data for comprehensive fitness tracking and insights.',
          reasons: [
            'Import heart rate data from your devices',
            'Sync calories and active energy automatically',
            'Get detailed performance analytics',
            'Track your overall health trends',
          ],
          isMandatory: false,
        );
    }
  }
}

/// Model for dialog content
class _DialogContent {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final List<String> reasons;
  final bool isMandatory;

  _DialogContent({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.reasons,
    required this.isMandatory,
  });
}
