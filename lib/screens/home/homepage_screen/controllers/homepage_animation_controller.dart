import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomepageAnimationController extends GetxController with GetTickerProviderStateMixin {
  // Animation controllers
  late AnimationController outerProgressController;
  late AnimationController middleProgressController;
  late AnimationController pulseController;
  late AnimationController gradientController;
  late AnimationController ballController;
  late AnimationController syncProgressController; // For sync progress ring

  // Animation values
  late Animation<double> pulseAnimation;
  late Animation<double> gradientAnimation;
  late Animation<double> ballAnimation;

  // State
  final RxBool isWalking = false.obs;
  final RxBool isSecondaryDataLoaded = false.obs;

  @override
  void onInit() {
    super.onInit();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Circular progress controllers
    outerProgressController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    middleProgressController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    // Pulse controller for walking indication
    pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: pulseController,
      curve: Curves.easeInOut,
    ));

    // Gradient rotation controller - smooth continuous rotation
    gradientController = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    );

    gradientAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * pi,
    ).animate(CurvedAnimation(
      parent: gradientController,
      curve: Curves.linear,
    ));

    // Ball animation controller - smooth oscillating movement
    ballController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    ballAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: ballController,
      curve: Curves.easeInOutSine,
    ));

    // Sync progress controller - for manual sync animation
    syncProgressController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
  }

  void startAnimations() {
    // Only start animations after secondary data is loaded
    if (!isSecondaryDataLoaded.value) return;

    try {
      // Start animations conditionally
      if (!gradientController.isAnimating) {
        gradientController.repeat();
      }

      if (!ballController.isAnimating) {
        ballController.repeat(reverse: true);
      }

      // Only start pulse when actually walking
      if (isWalking.value && !pulseController.isAnimating) {
        pulseController.repeat(reverse: true);
      }
    } catch (e) {
      // Controllers might be disposed, just silently ignore
      // This prevents crashes during hot restart or navigation
    }
  }

  void startPulseAnimation() {
    try {
      if (!pulseController.isAnimating) {
        pulseController.repeat(reverse: true);
      }
    } catch (e) {
      // Controller might be disposed, silently ignore
    }
  }

  void stopPulseAnimation() {
    try {
      if (pulseController.isAnimating) {
        pulseController.stop();
        pulseController.reset();
      }
    } catch (e) {
      // Controller might be disposed, silently ignore
    }
  }

  void setWalkingState(bool walking) {
    try {
      isWalking.value = walking;
      if (walking) {
        startPulseAnimation();
      } else {
        stopPulseAnimation();
      }
    } catch (e) {
      // Error setting walking state, silently ignore
    }
  }

  void setSecondaryDataLoaded(bool loaded) {
    isSecondaryDataLoaded.value = loaded;
    if (loaded) {
      startAnimations();
    }
  }

  void startSyncAnimation() {
    try {
      if (!syncProgressController.isAnimating) {
        syncProgressController.repeat();
      }
    } catch (e) {
      // Controller might be disposed, silently ignore
    }
  }

  void stopSyncAnimation() {
    try {
      if (syncProgressController.isAnimating) {
        syncProgressController.stop();
        syncProgressController.reset();
      }
    } catch (e) {
      // Controller might be disposed, silently ignore
    }
  }

  @override
  void onClose() {
    // Stop animations before disposing
    outerProgressController.stop();
    middleProgressController.stop();
    pulseController.stop();
    gradientController.stop();
    ballController.stop();
    syncProgressController.stop();

    // Dispose animation controllers
    outerProgressController.dispose();
    middleProgressController.dispose();
    pulseController.dispose();
    gradientController.dispose();
    ballController.dispose();
    syncProgressController.dispose();

    super.onClose();
  }
}