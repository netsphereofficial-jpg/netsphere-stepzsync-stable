import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Floating Action Button for quick access to notification test screen
/// This is a development-only widget - remove or hide in production
class NotificationTestFAB extends StatelessWidget {
  const NotificationTestFAB({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    bool isDebugMode = true; // Set to false for production

    if (!isDebugMode) {
      return SizedBox.shrink();
    }

    return Positioned(
      right: 16,
      bottom: 100, // Above the bottom navigation
      child: FloatingActionButton(
        heroTag: 'notification_test_fab',
        backgroundColor: Colors.deepPurple,
        child: Icon(Icons.notifications_active, color: Colors.white),
        tooltip: 'Test Notifications',
        onPressed: () {
          Get.toNamed('/notification-test');
        },
      ),
    );
  }
}

/// Alternative: Simple Icon Button (can be placed in any app bar or widget)
class NotificationTestButton extends StatelessWidget {
  final Color? color;
  final double? size;

  const NotificationTestButton({
    Key? key,
    this.color,
    this.size = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.bug_report,
        color: color ?? Colors.deepPurple,
        size: size,
      ),
      tooltip: 'Test Notifications',
      onPressed: () {
        Get.toNamed('/notification-test');
      },
    );
  }
}

/// Alternative: Menu Item
class NotificationTestMenuItem {
  static PopupMenuItem<String> get menuItem {
    return PopupMenuItem<String>(
      value: 'test_notifications',
      child: Row(
        children: [
          Icon(Icons.notifications_active, color: Colors.deepPurple),
          SizedBox(width: 12),
          Text('Test Notifications'),
        ],
      ),
    );
  }

  static void handleSelection(String value) {
    if (value == 'test_notifications') {
      Get.toNamed('/notification-test');
    }
  }
}
