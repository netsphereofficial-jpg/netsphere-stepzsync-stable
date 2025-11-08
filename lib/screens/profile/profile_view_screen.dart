import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../config/assets/icons.dart';
import '../../config/app_colors.dart';
import '../../controllers/profile/profile_view_controller.dart';
import '../../widgets/dialogs/logout_dialog.dart';
import '../../widgets/common/profile_image_widget.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../friends/friends_screen.dart';
import '../login_screen.dart';
import '../subscription/subscription_screen.dart';
import '../race/completed_races_screen.dart';
import '../../utils/guest_utils.dart';
import '../../widgets/guest_upgrade_dialog.dart';

class ProfileViewScreen extends StatelessWidget {
  final ProfileViewController controller = Get.put(ProfileViewController());

  ProfileViewScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    controller.setUserDetails();

    return Scaffold(
      backgroundColor: Color(0xffE8E8F8),
      appBar: CustomAppBar(
        title: "Profile",
        isBack: false,
        backgroundColor: Colors.white,
        titleColor: AppColors.appColor,
        showGradient: false,
        showMenuIcon: true,
        titleStyle: GoogleFonts.roboto(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.appColor,
        ),
        onMenuClick: () {
          HapticFeedback.lightImpact();
          _showHelpSupportMenu(context);
        },
      ),
      body: RefreshIndicator(
        onRefresh: controller.refreshProfile,
        color: AppColors.appColor,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
            SizedBox(height: 20),
            // Profile Picture
            Center(
              child: Stack(
                children: [
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.appColor,
                          AppColors.primary,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.appColor.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Obx(() {
                      return ProfileImageWidget(
                        imageUrl: controller.profilePic.value,
                        size: 100,
                        borderColor: Colors.white,
                        borderWidth: 4,
                      );
                    }),
                  ),
                  // Edit button
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(25),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              // Check if guest user trying to edit profile
                              if (GuestUtils.isGuest()) {
                                GuestUpgradeDialog.show(featureName: 'Profile Edit');
                                return;
                              }
                              showImageSourcePicker(context, (source) async {
                                final file = await controller.pickImage(source);
                                if (file != null) {
                                  await controller.uploadImage(file);
                                }
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.appColor,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.appColor.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                        // Lock icon for guests
                        if (GuestUtils.isGuest())
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.5),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.lock,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            _buildProfileDetails(controller),
            SizedBox(height: 12),
            // Quick Actions Grid
            buildProfileRow(
              icon: IconPaths.shoesBlack,
              label: "Completed Races",
              showBadge: true,
              badgeText: "Track your race history",
              onTap: () {
                Get.to(() => CompletedRacesScreen());
              },
            ),
            buildProfileRow(
              icon: IconPaths.friendsIcon,
              label: "Friends & Social",
              showBadge: true,
              badgeText: "Connect with other runners",
              onTap: () {
                Get.to(() => FriendsScreen());
              },
            ),
            buildProfileRow(
              icon: IconPaths.achievement,
              label: "My Achievements",
              showBadge: true,
              badgeText: "View your fitness milestones",
              onTap: () {
                Get.toNamed('/achievements');
              },
            ),
            // Temporarily hidden for testing
            Visibility(
              visible: false,
              child: buildProfileRow(
                icon: IconPaths.card,
                label: "Subscription Plans",
                showBadge: true,
                badgeText: "Manage your premium features",
                onTap: () {
                  Get.to(() => SubscriptionScreen());
                },
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    ));
  }

  Widget buildProfileRow({
    required String icon,
    required String label,
    VoidCallback? onTap,
    bool isDestructive = false,
    bool showBadge = false,
    String badgeText = "",
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (onTap != null) {
              HapticFeedback.lightImpact();
              onTap();
            }
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Enhanced icon container
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDestructive
                              ? Colors.red.withValues(alpha: 0.1)
                              : AppColors.appColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SvgPicture.asset(
                          icon,
                          width: 20,
                          height: 20,
                          colorFilter: ColorFilter.mode(
                            isDestructive ? Colors.red : AppColors.primary,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: isDestructive ? Colors.red : AppColors.buttonBlack,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (showBadge) ...[
                              SizedBox(height: 4),
                              Text(
                                badgeText,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.greyColor2,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Enhanced arrow with color
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.iconGrey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate()
      .fadeIn(duration: 400.ms, delay: Duration(milliseconds: 100))
      .slideX(begin: 0.2, end: 0, duration: 400.ms, delay: Duration(milliseconds: 100));
  }

  Widget _buildProfileDetails(ProfileViewController controller) {
    return Obx(
      () => controller.isLoading.value
          ? _buildProfileDetailsShimmer()
          : Container(
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              padding: EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 25,
                    spreadRadius: 0,
                    offset: Offset(0, 10),
                  ),
                  BoxShadow(
                    color: AppColors.appColor.withValues(alpha: 0.15),
                    blurRadius: 40,
                    spreadRadius: -5,
                    offset: Offset(0, 20),
                  ),
                ],
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // Name with subscription badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          controller.name.value.capitalizeFirst??"",
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(width: 8),
                      // Subscription Icon - Clickable
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Get.to(() => SubscriptionScreen());
                          },
                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.appColor,
                                  AppColors.primary,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.appColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.workspace_premium_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'FREE',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Email with icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.email_rounded,
                        size: 16,
                        color: AppColors.greyColor2,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          controller.email.value,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.greyColor2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  // Location with icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: AppColors.greyColor2,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          controller.location.value,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.greyColor2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate()
              .fadeIn(duration: 600.ms, delay: 100.ms)
              .slideY(begin: 0.2, end: 0, duration: 600.ms, delay: 100.ms),
    );
  }

  Widget _buildProfileDetailsShimmer() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            spreadRadius: 0,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          SizedBox(height: 12),
          Container(
            width: 180,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          SizedBox(height: 8),
          Container(
            width: 200,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          SizedBox(height: 6),
          Container(
            width: 160,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    ).animate(onPlay: (controller) => controller.repeat())
      .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.6));
  }

  void showImageSourcePicker(
    BuildContext context,
    Function(ImageSource) onPick,
  ) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  onPick(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  onPick(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpSupportMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 20),
                // Title
                Text(
                  'Help & Support',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 20),
                // Help & Support Option
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.appColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SvgPicture.asset(
                      IconPaths.headphone,
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        AppColors.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  title: Text(
                    'Help & Support',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Get assistance with any issues',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.greyColor2,
                    ),
                  ),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to support
                  },
                ),
                // Sign Out Option
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SvgPicture.asset(
                      IconPaths.logoutIcon,
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        Colors.red,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  title: Text(
                    'Sign Out',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  subtitle: Text(
                    'Securely log out of your account',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.greyColor2,
                    ),
                  ),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.red),
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => LogoutDialog(
                        onCancel: () => Navigator.of(context).pop(),
                        onConfirm: () {
                          Navigator.of(context).pop();
                          controller.logoutApiCall();
                        },
                        onCreateAccount: GuestUtils.isGuest()
                            ? () {
                                Navigator.of(context).pop();
                                // Navigate to login screen for account creation
                                Get.offAll(() => LoginScreen());
                              }
                            : null,
                      ),
                    );
                  },
                ),
                // Delete Account Option
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.delete_forever_rounded,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    'Delete Account',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  subtitle: Text(
                    'Permanently delete your account and data',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.greyColor2,
                    ),
                  ),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.red),
                  onTap: () {
                    Navigator.pop(context);
                    controller.showDeleteAccountDialog(context);
                  },
                ),
                SizedBox(height: 20),
                // App Version Info
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.fitness_center_rounded,
                            color: AppColors.appColor,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'StepzSync',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      FutureBuilder<String>(
                        future: controller.getAppVersion(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Container(
                              width: 60,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(7),
                              ),
                            );
                          } else if (snapshot.hasError) {
                            return Text(
                              'Version: Unknown',
                              style: GoogleFonts.poppins(
                                color: AppColors.lightGray,
                                fontSize: 12,
                              ),
                            );
                          } else {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Version ${snapshot.data}',
                                  style: GoogleFonts.poppins(
                                    color: AppColors.lightGray,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.neonGreen.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'LATEST',
                                    style: GoogleFonts.poppins(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                      SizedBox(height: 8),
                      Text(
                        '© 2024 All rights reserved',
                        style: GoogleFonts.poppins(
                          color: AppColors.lightGray,
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}