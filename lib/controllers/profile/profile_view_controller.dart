import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/profile_models.dart';
import '../../services/profile/profile_service.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../screens/login_screen.dart';
import '../../config/app_colors.dart';

class ProfileViewController extends GetxController {
  // Observable variables
  var name = ''.obs;
  var email = ''.obs;
  var location = ''.obs;
  var profilePic = ''.obs;
  var friends = 0.obs;
  var distanceCovered = 0.0.obs;
  var racesWon = 0.obs;
  var xp = 0.obs;
  var isLoading = false.obs;

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void onInit() {
    super.onInit();
    setUserDetails();
  }

  /// Set user details from profile
  Future<void> setUserDetails() async {
    try {
      isLoading.value = true;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _setDefaultValues();
        return;
      }

      // Get profile from service
      final result = await ProfileService.getProfile();

      if (result.success && result.data != null) {
        final profile = result.data as UserProfile;
        _populateFromProfile(profile);
      } else {
        // Set basic user info from Firebase Auth
        name.value = user.displayName ?? 'User';
        email.value = user.email ?? '';
        profilePic.value = user.photoURL ?? '';
        _setDefaultValues();
      }
    } catch (e) {
      print('Error setting user details: $e');
      _setDefaultValues();
    } finally {
      isLoading.value = false;
    }
  }

  void _populateFromProfile(UserProfile profile) {
    name.value = profile.fullName;
    email.value = profile.email;
    location.value = profile.location;
    profilePic.value = profile.profilePicture ?? '';

    // Enhanced stats with realistic demo data
    friends.value = 24; // Demo: friends count
    distanceCovered.value = 847.3; // Demo: distance in km
    racesWon.value = 12; // Demo: races won
    xp.value = 3450; // Demo: XP points
  }

  void _setDefaultValues() {
    final user = FirebaseAuth.instance.currentUser;
    name.value = user?.displayName ?? 'Fitness Enthusiast';
    email.value = user?.email ?? 'user@stepzsync.com';
    profilePic.value = user?.photoURL ?? '';
    location.value = 'Add your location';
    // Demo values for better showcase
    friends.value = 15;
    distanceCovered.value = 234.7;
    racesWon.value = 3;
    xp.value = 1250;
  }

  /// Pick image from camera or gallery
  Future<File?> pickImage(ImageSource source) async {
    try {
      // Check appropriate permission based on source
      if (source == ImageSource.camera) {
        var cameraPermission = await Permission.camera.status;
        if (cameraPermission.isDenied) {
          cameraPermission = await Permission.camera.request();
        }

        if (cameraPermission.isPermanentlyDenied) {
          SnackbarUtils.showError('Permission Required', 'Camera permission is required. Please enable it in Settings.');
          await openAppSettings();
          return null;
        }

        if (!cameraPermission.isGranted) {
          SnackbarUtils.showError('Permission Denied', 'Camera permission is required to take photos.');
          return null;
        }
      }

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      SnackbarUtils.showError('Error', 'Failed to pick image: ${e.toString()}');
      return null;
    }
  }

  /// Upload image to Firebase Storage
  Future<void> uploadImage(File imageFile) async {
    try {
      isLoading.value = true;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        SnackbarUtils.showError('Error', 'User not authenticated');
        return;
      }

      // Create a reference to the storage location
      final ref = _storage.ref().child('profile_pictures/${user.uid}.jpg');

      // Upload the file
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update profile picture in Firestore
      final result = await ProfileService.updateProfileField('profilePicture', downloadUrl);

      if (result.success) {
        profilePic.value = downloadUrl;

        // Also update Firebase Auth profile
        await user.updatePhotoURL(downloadUrl);

        SnackbarUtils.showSuccess('Success', 'Profile picture updated successfully');
      } else {
        SnackbarUtils.showError('Error', result.error ?? 'Failed to update profile picture');
      }
    } catch (e) {
      SnackbarUtils.showError('Error', 'Failed to upload image: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  /// Get app version
  Future<String> getAppVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      return '1.0.0';
    }
  }

  /// Logout functionality
  Future<void> logoutApiCall() async {
    try {
      isLoading.value = true;

      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      // Clear any cached data
      Get.delete<ProfileViewController>();

      // Navigate to login screen
      Get.offAll(() => LoginScreen());

      SnackbarUtils.showSuccess('Success', 'Logged out successfully');
    } catch (e) {
      SnackbarUtils.showError('Error', 'Failed to logout: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  /// Refresh profile data
  Future<void> refreshProfile() async {
    await setUserDetails();
  }

  /// Show delete account confirmation dialog
  void showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_rounded,
              color: Colors.red,
              size: 28,
            ),
            SizedBox(width: 12),
            Text(
              'Delete Account?',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.red,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action cannot be undone. Your account and all associated data will be permanently deleted:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.buttonBlack,
              ),
            ),
            SizedBox(height: 16),
            _buildDeleteItem('Profile information'),
            _buildDeleteItem('Race history and statistics'),
            _buildDeleteItem('Friends and connections'),
            _buildDeleteItem('Messages and notifications'),
            _buildDeleteItem('All personal data'),
            SizedBox(height: 16),
            Text(
              'Are you sure you want to continue?',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.greyColor2,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Delete Account',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.close,
            color: Colors.red,
            size: 16,
          ),
          SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.buttonBlack,
            ),
          ),
        ],
      ),
    );
  }

  /// Delete user account
  Future<void> _deleteAccount() async {
    try {
      isLoading.value = true;

      // Show loading dialog
      Get.dialog(
        PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.appColor),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Deleting account...',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Call the delete account service
      final result = await ProfileService.deleteUserAccount();

      // Close loading dialog
      Get.back();

      if (result.success) {
        // Show success message
        SnackbarUtils.showSuccess(
          'Account Deleted',
          'Your account has been permanently deleted',
        );

        // Navigate to login screen
        Get.offAll(() => LoginScreen());
      } else {
        // Show error message
        SnackbarUtils.showError(
          'Deletion Failed',
          result.error ?? 'Failed to delete account. Please try again.',
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Get.isDialogOpen == true) {
        Get.back();
      }

      SnackbarUtils.showError(
        'Error',
        'An unexpected error occurred: ${e.toString()}',
      );
    } finally {
      isLoading.value = false;
    }
  }
}