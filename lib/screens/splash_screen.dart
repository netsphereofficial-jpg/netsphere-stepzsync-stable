import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/onboarding_service.dart';
import '../services/auth_wrapper.dart';
import 'onboarding/onboarding_screen.dart';

/// Simplified Splash Screen - 2.5 seconds with onboarding check
/// Flow: Splash → Onboarding (first-time) OR AuthWrapper (returning)
/// AuthWrapper checks Firebase Auth state and routes accordingly
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  /// Display splash for 2.5 seconds, check onboarding status, then navigate
  void _startTimer() async {
    // Show branding for 2.5 seconds
    await Future.delayed(Duration(milliseconds: 2500));

    if (mounted) {
      // Check if user needs to see onboarding
      final shouldShowOnboarding = await OnboardingService.shouldShowOnboarding();

      if (shouldShowOnboarding) {
        // First-time user: Navigate to onboarding screens
        Get.off(() => OnboardingScreen());
      } else {
        // Returning user: Navigate to AuthWrapper
        // AuthWrapper will check Firebase Auth state and route accordingly:
        // - Logged in → HomeScreen
        // - Not logged in → LoginScreen
        Get.off(() => AuthWrapper());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Transform.scale(
          scale: 1.15, // Zoom in by 15% to ensure edges are covered
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                fit: BoxFit.cover,
                image: AssetImage(
                  'assets/background/Splash Screen-2.png',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
