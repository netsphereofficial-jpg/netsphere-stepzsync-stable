import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/app_colors.dart';
import '../../controllers/onboarding_controller.dart';
import '../../services/onboarding_service.dart';

/// Onboarding screen for physical activity permission
/// Follows the design pattern of My Races/All Races screens
class ActivityPermissionScreen extends StatefulWidget {
  const ActivityPermissionScreen({super.key});

  @override
  State<ActivityPermissionScreen> createState() => _ActivityPermissionScreenState();
}

class _ActivityPermissionScreenState extends State<ActivityPermissionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _animationController.forward();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Handle allow activity tracking button press
  Future<void> _handleAllowActivityTracking() async {
    final controller = Get.find<OnboardingController>();

    bool granted = false;

    // Request appropriate permission based on platform
    if (Platform.isAndroid) {
      // Request Activity Recognition permission on Android
      final status = await Permission.activityRecognition.request();
      granted = status.isGranted;

      if (status.isPermanentlyDenied) {
        // Show dialog to open settings
        _showPermanentlyDeniedDialog();
        return;
      }
    } else if (Platform.isIOS) {
      // Request Motion & Fitness permission on iOS
      final status = await Permission.sensors.request();
      granted = status.isGranted;

      if (status.isPermanentlyDenied) {
        // Show dialog to open settings
        _showPermanentlyDeniedDialog();
        return;
      }
    }

    // Handle result through controller
    await controller.onPermissionResult(
      granted: granted,
      permissionType: PermissionType.activity,
    );
  }

  /// Show dialog when permission is permanently denied
  void _showPermanentlyDeniedDialog() {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.settings, color: AppColors.appColor),
            const SizedBox(width: 8),
            const Text('Permission Required'),
          ],
        ),
        content: Text(
          Platform.isAndroid
              ? 'Activity Recognition permission is required to track your steps during races.\n\nPlease enable it in Settings > Apps > StepzSync > Permissions.'
              : 'Motion & Fitness permission is required to track your activity during races.\n\nPlease enable it in Settings > StepzSync > Motion & Fitness.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonYellow,
              foregroundColor: AppColors.buttonBlack,
            ),
            child: Text(
              'Open Settings',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Handle skip button press
  Future<void> _handleSkip() async {
    final controller = Get.find<OnboardingController>();
    await controller.skipPermission();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<OnboardingController>();

    return Scaffold(
      backgroundColor: const Color(0xffE8E8F8),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  // Progress indicator
                  _buildProgressIndicator(controller),
                  const SizedBox(height: 48),

                  // Main content card
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildContentCard(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build progress indicator
  Widget _buildProgressIndicator(OnboardingController controller) {
    return Row(
      children: [
        Text(
          'Step 2 of 3',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.appColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: controller.progressPercentage,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.appColor),
              minHeight: 6,
            ),
          ),
        ),
      ],
    );
  }

  /// Build main content card
  Widget _buildContentCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8.0,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Icon container
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.neonYellow.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.directions_run,
              size: 50,
              color: AppColors.neonYellow,
            ),
          ),
          const SizedBox(height: 32),

          // Title
          Text(
            'Track Your\nPhysical Activity',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            'Allow us to track your steps and movement to accurately measure your performance in races and challenges.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // Feature list
          _buildFeatureItem(
            icon: Icons.show_chart,
            title: 'Real-Time Step Tracking',
            description: 'Monitor your steps in real-time during races',
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            icon: Icons.analytics,
            title: 'Performance Analytics',
            description: 'View detailed stats and insights about your activity',
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            icon: Icons.speed,
            title: 'Accurate Race Results',
            description: 'Ensure fair competition with precise step counting',
          ),
        ],
      ),
    );
  }

  /// Build individual feature item
  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.appColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: AppColors.appColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build action buttons
  Widget _buildActionButtons() {
    return Column(
      children: [
        // Allow activity tracking button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _handleAllowActivityTracking,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonYellow,
              foregroundColor: AppColors.buttonBlack,
              elevation: 3,
              shadowColor: AppColors.neonYellow.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.directions_run,
                  size: 20,
                  color: AppColors.buttonBlack,
                ),
                const SizedBox(width: 8),
                Text(
                  'Allow Activity Tracking',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.buttonBlack,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Skip button
        TextButton(
          onPressed: _handleSkip,
          child: Text(
            'Skip for Now',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }
}
