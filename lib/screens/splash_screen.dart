import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'login_screen.dart';

/// Simplified Splash Screen - Market Standard (1 second)
/// Based on research: TikTok/Instagram pattern
/// No forced authentication - user chooses Login/Signup/Guest
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

  /// Display splash for 1 second (market standard), then navigate to login
  void _startTimer() async {
    // Show branding for 1 second only (market standard for frequent-use apps)
    await Future.delayed(Duration(seconds: 1));

    if (mounted) {
      // Navigate directly to LoginScreen
      // User can choose: Login, Signup, or Continue as Guest
      Get.off(() => LoginScreen());
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
