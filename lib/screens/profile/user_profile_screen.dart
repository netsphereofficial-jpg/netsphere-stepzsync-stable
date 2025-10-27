import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../controllers/user_profile_controller.dart';
import '../../models/profile_models.dart';
import '../../models/friend_models.dart';

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(UserProfileController());
    final String userId = Get.arguments as String;

    // Load profile on screen init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🔍 UserProfileScreen: Loading profile for userId: $userId');
      controller.loadProfile(userId);
    });

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (controller.profile.value == null) {
          return _buildErrorState(context);
        }

        final profile = controller.profile.value!;

        return RefreshIndicator(
          onRefresh: controller.refreshProfile,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
            children: [
              // Profile Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Profile Picture
                    Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.appColor.withValues(alpha: 0.3),
                            AppColors.appColor.withValues(alpha: 0.1),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.appColor.withValues(alpha: 0.3),
                            blurRadius: 16,
                            spreadRadius: 4,
                          ),
                        ],
                        image: profile.profilePicture != null
                            ? DecorationImage(
                                image: NetworkImage(profile.profilePicture!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: profile.profilePicture == null
                          ? Icon(
                              Icons.person_rounded,
                              color: AppColors.appColor,
                              size: 48,
                            )
                          : null,
                    ),

                    const SizedBox(height: 16),

                    // Name
                    Text(
                      profile.fullName,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    // Username
                    if (profile.username != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '@${profile.username!}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: AppColors.appColor.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Action Buttons
                    if (!controller.isOwnProfile()) ...[
                      Obx(() => _buildActionButtons()),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Profile Details
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Location
                    if (profile.location.isNotEmpty) ...[
                      _buildDetailRow(
                        Icons.location_on,
                        'Location',
                        profile.location,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Age (calculated from date of birth)
                    if (profile.dateOfBirth != null) ...[
                      _buildDetailRow(
                        Icons.cake,
                        'Age',
                        '${_calculateAge(profile.dateOfBirth!)} years old',
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Gender
                    if (profile.gender.isNotEmpty) ...[
                      _buildDetailRow(
                        Icons.person,
                        'Gender',
                        _formatGender(profile.gender),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Height
                    if (profile.height > 0) ...[
                      _buildDetailRow(
                        Icons.height,
                        'Height',
                        '${profile.height.toInt()} ${profile.heightUnit}',
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Weight
                    if (profile.weight > 0) ...[
                      _buildDetailRow(
                        Icons.fitness_center,
                        'Weight',
                        '${profile.weight.toInt()} ${profile.weightUnit}',
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Phone Number (hidden for non-premium users)
                    if (profile.phoneNumber.isNotEmpty) ...[
                      _buildDetailRow(
                        Icons.phone,
                        'Phone',
                        _formatPhoneNumber(profile.countryCode, profile.phoneNumber),
                      ),
                    ],
                  ],
                ),
              ),

            ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final controller = Get.find<UserProfileController>();

    return RefreshIndicator(
      onRefresh: controller.refreshProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_off_rounded,
                    size: 48,
                    color: Colors.red[400],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Profile Not Found',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'This user profile could not be loaded. The user may not exist or there might be a connection issue.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: controller.refreshProfile,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.appColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color,
              color.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ] else ...[
              Icon(icon, color: Colors.white, size: 16),
            ],
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.appColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: AppColors.appColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  int _calculateAge(DateTime dateOfBirth) {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  String _formatGender(String genderValue) {
    final gender = Gender.fromValue(genderValue);
    return gender?.label ?? genderValue.capitalize!;
  }

  String _formatPhoneNumber(String countryCode, String phoneNumber) {
    // TODO: Check if user has premium subscription
    bool isPremiumUser = false; // Replace with actual premium check

    if (isPremiumUser) {
      return '$countryCode $phoneNumber';
    } else {
      // Hide phone number with asterisks for non-premium users
      final maskedNumber = phoneNumber.length > 4
          ? phoneNumber.substring(0, 2) + '*' * (phoneNumber.length - 4) + phoneNumber.substring(phoneNumber.length - 2)
          : '*' * phoneNumber.length;
      return '$countryCode $maskedNumber';
    }
  }

  Widget _buildActionButtons() {
    final controller = Get.find<UserProfileController>();

    if (controller.areFriends()) {
      // Show Remove Friend and Message buttons for friends
      return Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.person_remove,
              label: controller.isRemovingFriend.value ? 'Removing...' : 'Remove',
              color: Colors.red,
              isLoading: controller.isRemovingFriend.value,
              onTap: !controller.isRemovingFriend.value
                  ? () => _showRemoveFriendDialog(controller)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: Icons.message,
              label: 'Message',
              color: Colors.blue,
              onTap: () {
                // TODO: Open chat
                Get.snackbar('Message', 'Chat feature coming soon!');
              },
            ),
          ),
        ],
      );
    } else if (controller.isRequestPending()) {
      // Show status for pending requests
      if (controller.friendshipStatus.value == FriendshipStatus.requestSent) {
        return _buildActionButton(
          icon: Icons.schedule,
          label: 'Sent',
          color: Colors.orange,
          onTap: null, // Disabled
        );
      } else {
        return _buildActionButton(
          icon: Icons.schedule,
          label: 'Received',
          color: Colors.orange,
          onTap: null, // Disabled - they need to go to friend requests to accept
        );
      }
    } else if (controller.canSendFriendRequest()) {
      // Show Add Friend button for non-friends
      return _buildActionButton(
        icon: Icons.person_add,
        label: controller.isSendingRequest.value ? 'Sending...' : 'Add Friend',
        color: AppColors.appColor,
        isLoading: controller.isSendingRequest.value,
        onTap: !controller.isSendingRequest.value
            ? () => controller.sendFriendRequest()
            : null,
      );
    } else {
      // Fallback - shouldn't happen but just in case
      return const SizedBox();
    }
  }

  void _showRemoveFriendDialog(UserProfileController controller) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              'Remove Friend',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove ${controller.profile.value?.fullName} from your friends?',
          style: GoogleFonts.poppins(),
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
            onPressed: () {
              Get.back();
              controller.removeFriend();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Remove',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

}