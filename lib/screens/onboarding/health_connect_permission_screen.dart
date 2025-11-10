import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../controllers/onboarding_controller.dart';
import '../../services/onboarding_service.dart';
import '../../widgets/dialogs/health_permission_handler_dialog.dart';

/// Onboarding screen for health connect permission
/// Follows the design pattern of My Races/All Races screens
class HealthConnectPermissionScreen extends StatefulWidget {
  const HealthConnectPermissionScreen({super.key});

  @override
  State<HealthConnectPermissionScreen> createState() => _HealthConnectPermissionScreenState();
}

class _HealthConnectPermissionScreenState extends State<HealthConnectPermissionScreen>
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

  /// Handle connect health data button press
  Future<void> _handleConnectHealthData() async {
    final controller = Get.find<OnboardingController>();

    // Use the comprehensive HealthPermissionHandlerDialog
    // This handles all the complex scenarios:
    // - Health Connect not installed
    // - Samsung Health setup
    // - Permission denials
    // - Settings redirects
    final granted = await HealthPermissionHandlerDialog.requestPermissions(
      showOnboarding: true,
    );

    if (granted) {
      // Permission granted successfully
      await controller.onPermissionResult(
        granted: true,
        permissionType: PermissionType.health,
      );
    } else {
      // Permission denied or not available - this is optional, so we still complete onboarding
      // User can enable it later from settings
      await controller.completeOnboarding();
    }
  }

  /// Handle skip button press
  Future<void> _handleSkip() async {
    final controller = Get.find<OnboardingController>();
    // This is the last screen, so skip will complete onboarding
    await controller.completeOnboarding();
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
          'Step 3 of 3',
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
              Icons.favorite,
              size: 50,
              color: AppColors.neonYellow,
            ),
          ),
          const SizedBox(height: 32),

          // Title
          Text(
            'Connect to\nHealth Data',
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
            'Integrate with Health Connect to sync your fitness data and get a complete picture of your wellness journey.',
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
            icon: Icons.sync,
            title: 'Seamless Data Sync',
            description: 'Automatically sync steps, distance, and calories',
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            icon: Icons.insights,
            title: 'Health Insights',
            description: 'Get personalized insights based on your health data',
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            icon: Icons.security,
            title: 'Privacy Protected',
            description: 'Your health data is encrypted and secure',
          ),
          const SizedBox(height: 24),

          // Optional badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.appColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.appColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'This permission is optional',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.appColor,
                  ),
                ),
              ],
            ),
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
        // Connect health data button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _handleConnectHealthData,
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
                  Icons.favorite,
                  size: 20,
                  color: AppColors.buttonBlack,
                ),
                const SizedBox(width: 8),
                Text(
                  'Connect Health Data',
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
