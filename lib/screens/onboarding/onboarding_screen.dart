import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/onboarding_controller.dart';
import 'activity_permission_screen.dart';
import 'health_connect_permission_screen.dart';
import 'notification_permission_screen.dart';

/// Main onboarding screen that manages the PageView
/// Contains three permission screens with smooth transitions
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize the onboarding controller
    final controller = Get.put(OnboardingController());

    return PopScope(
      // Prevent back button from exiting onboarding
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;

        if (controller.currentPage.value > 0) {
          // Go back to previous page if not on first page
          await controller.previousPage();
        }
        // Don't allow exiting from first page
      },
      child: Scaffold(
        body: PageView(
          controller: controller.pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            NotificationPermissionScreen(),
            ActivityPermissionScreen(),
            HealthConnectPermissionScreen(),
          ],
        ),
      ),
    );
  }
}
