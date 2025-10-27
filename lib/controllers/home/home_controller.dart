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
    _startDeferredServices();
  }



  /// Initialize friend notification service
  Future<void> _initializeFriendNotifications() async {
    try {
      print('🔄 HomeController: Initializing notification services...');

      // Start monitoring all notifications from Firebase (friends, chat, etc.)
      await UnifiedNotificationService.startMonitoring();
      print('✅ HomeController: Notification monitoring started');

      // Check for any unread notifications on startup
      await UnifiedNotificationService.checkForUnreadNotifications();
      print('✅ HomeController: Checked for unread notifications');
    } catch (e) {
      print('❌ Error initializing friend notifications: $e');
    }
  }

  /// ✅ OPTIMIZATION: Start deferred services that were moved from main.dart
  /// These services are not critical for app startup and can be initialized
  /// after the home screen is displayed to the user
  void _startDeferredServices() {
    // Run in background to avoid blocking UI
    Future.microtask(() async {
      try {
        print('🚀 [DEFERRED] Starting deferred background services...');

        // Start automatic race start monitoring for scheduled races
        // This was moved from main.dart to avoid blocking app startup
        try {
          RaceStateMachine.startScheduledRaceMonitoring();
          print('✅ [DEFERRED] Race monitoring started');
        } catch (e) {
          print('❌ [DEFERRED] Failed to start race monitoring: $e');
        }

        // Background Step Sync Service (only if user has enabled it in settings)
        // This was moved from main.dart to avoid blocking app startup
        try {
          if (Get.isRegistered<BackgroundStepSyncService>()) {
            final bgSyncService = Get.find<BackgroundStepSyncService>();
            print('✅ [DEFERRED] Background sync service already initialized');
          } else {
            print('ℹ️ [DEFERRED] Background sync will initialize when user enables it');
          }
        } catch (e) {
          print('❌ [DEFERRED] Background sync service error: $e');
        }

        print('✅ [DEFERRED] All deferred services started successfully');
      } catch (e) {
        print('❌ [DEFERRED] Error starting deferred services: $e');
      }
    });
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