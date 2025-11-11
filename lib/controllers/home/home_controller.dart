import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../services/friend_notification_service.dart';
import '../../services/preferences_service.dart';
import '../../utils/guest_utils.dart';
import '../../services/race_state_machine.dart';
import '../../services/background_step_sync_service.dart';

class HomeController extends GetxController with GetSingleTickerProviderStateMixin {
  var selectedIndex = 0.obs;
  late AnimationController fabAnimationController;
  late Animation<double> fabScaleAnimation;
  late Animation<double> fabRotationAnimation;

  @override
  void onInit() {
    super.onInit();
    fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    fabScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: fabAnimationController,
      curve: Curves.elasticOut,
    ));

    fabRotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * 3.14159, // Full rotation
    ).animate(CurvedAnimation(
      parent: fabAnimationController,
      curve: Curves.easeInOut,
    ));

    // Request notification permission on first home screen load (one-time)

    // Initialize friend notification monitoring
    _initializeFriendNotifications();

    // ✅ OPTIMIZATION: Start deferred services after home screen loads
    // These were moved from main.dart to improve startup time
  }



  /// Initialize friend notification service
  Future<void> _initializeFriendNotifications() async {
    try {

      // Start monitoring all notifications from Firebase (friends, chat, etc.)
      await UnifiedNotificationService.startMonitoring();

      // Check for any unread notifications on startup
      await UnifiedNotificationService.checkForUnreadNotifications();
    } catch (e) {
    }
  }

  void changeIndex(int index) {
    selectedIndex.value = index;
    
    // Trigger FAB animation when center button is tapped
    if (index == 2) {
      fabAnimationController.forward().then((_) {
        fabAnimationController.reverse();
      });
    }
  }
  
  @override
  void onClose() {
    fabAnimationController.dispose();
    // Stop notification monitoring
    UnifiedNotificationService.stopMonitoring();
    super.onClose();
  }
}


void showSnackbar(String title, String message) {
  if (title.isEmpty) {
  } else {
    SnackbarUtils.showInfo(title, message);
  }
}