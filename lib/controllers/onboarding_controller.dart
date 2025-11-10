import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../screens/login_screen.dart';
import '../services/onboarding_service.dart';

/// Controller for managing onboarding flow
/// Handles navigation between permission screens and completion
class OnboardingController extends GetxController {
  // Page controller for PageView
  final PageController pageController = PageController();

  // Current page index (0-2)
  final RxInt currentPage = 0.obs;

  // Total number of onboarding screens
  static const int totalPages = 3;

  // Track if animation is in progress
  final RxBool isAnimating = false.obs;

  @override
  void onInit() {
    super.onInit();
    pageController.addListener(_onPageChanged);
  }

  @override
  void onClose() {
    pageController.removeListener(_onPageChanged);
    pageController.dispose();
    super.onClose();
  }

  /// Listen to page changes
  void _onPageChanged() {
    if (pageController.hasClients) {
      final page = pageController.page?.round() ?? 0;
      if (currentPage.value != page) {
        currentPage.value = page;
      }
    }
  }

  /// Navigate to next page
  Future<void> nextPage() async {
    if (isAnimating.value) return;

    if (currentPage.value < totalPages - 1) {
      isAnimating.value = true;
      await pageController.animateToPage(
        currentPage.value + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      isAnimating.value = false;
    } else {
      // Last page - complete onboarding
      await completeOnboarding();
    }
  }

  /// Navigate to previous page
  Future<void> previousPage() async {
    if (isAnimating.value) return;

    if (currentPage.value > 0) {
      isAnimating.value = true;
      await pageController.animateToPage(
        currentPage.value - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      isAnimating.value = false;
    }
  }

  /// Skip current permission and go to next page
  Future<void> skipPermission() async {
    await nextPage();
  }

  /// Complete onboarding and navigate to login
  Future<void> completeOnboarding() async {
    // Mark onboarding as completed
    await OnboardingService.completeOnboarding();

    // Navigate to login screen
    Get.off(() => LoginScreen());
  }

  /// Handle permission request result
  /// This will be called from the individual onboarding screens
  Future<void> onPermissionResult({
    required bool granted,
    required PermissionType permissionType,
  }) async {
    if (granted) {
      // Permission granted - reset denial count and move to next screen
      await OnboardingService.resetDenialCount(permissionType);
      await nextPage();
    } else {
      // Permission denied - increment denial count
      await OnboardingService.incrementDenialCount(permissionType);

      // Check if max denials reached
      final maxReached = await OnboardingService.hasReachedMaxDenials(permissionType);

      if (maxReached) {
        // Show settings redirect dialog
        // TODO: Show SettingsRedirectDialog
        // For now, just move to next screen
        await nextPage();
      } else {
        // Show explanation dialog
        // TODO: Show PermissionExplanationDialog
        // For now, just move to next screen
        await nextPage();
      }
    }
  }

  /// Get progress percentage (0.0 to 1.0)
  double get progressPercentage => (currentPage.value + 1) / totalPages;

  /// Check if on first page
  bool get isFirstPage => currentPage.value == 0;

  /// Check if on last page
  bool get isLastPage => currentPage.value == totalPages - 1;
}
