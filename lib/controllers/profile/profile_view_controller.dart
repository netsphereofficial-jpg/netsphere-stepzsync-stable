import 'dart:io';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../models/profile_models.dart';
import '../../services/profile/profile_service.dart';
import '../../services/profile/profile_image_upload_queue.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../screens/login_screen.dart';
import '../../config/app_colors.dart';
import '../../screens/home/homepage_screen/controllers/homepage_data_service.dart';

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
  var uploadProgress = 0.0.obs;
  var localImageFile = Rxn<File>(); // For showing image immediately
  var uploadStatusMessage = ''.obs; // Status message for user feedback
  var isRetrying = false.obs; // Flag for retry state

  final ImagePicker _picker = ImagePicker();
  final ProfileImageUploadQueue _uploadQueue = ProfileImageUploadQueue();
  StreamSubscription<UploadState>? _uploadStateSubscription;

  @override
  void onInit() {
    super.onInit();
    setUserDetails();
    _initializeUploadQueue();
  }

  @override
  void onClose() {
    _uploadStateSubscription?.cancel();
    super.onClose();
  }

  /// Initialize upload queue and listen to state changes
  void _initializeUploadQueue() {
    _uploadQueue.initialize();

    // Listen to upload state changes
    _uploadStateSubscription = _uploadQueue.uploadStateStream.listen((state) {
      _handleUploadStateChange(state);
    });

    // Check if there's a pending upload to resume
    final currentState = _uploadQueue.currentUploadState;
    if (currentState != null) {
      _handleUploadStateChange(currentState);
    }
  }

  /// Handle upload state changes
  void _handleUploadStateChange(UploadState state) {
    uploadProgress.value = state.progress;
    uploadStatusMessage.value = state.statusMessage;

    switch (state.status) {
      case UploadStatus.uploading:
        isRetrying.value = false;
        break;
      case UploadStatus.retrying:
        isRetrying.value = true;
        break;
      case UploadStatus.networkError:
        isRetrying.value = false;
        // Show subtle notification that we're waiting for network
        if (uploadStatusMessage.value.isNotEmpty) {
          _showNetworkWaitingSnackbar();
        }
        break;
      case UploadStatus.success:
        isRetrying.value = false;
        uploadProgress.value = 0.0;
        uploadStatusMessage.value = '';
        break;
      case UploadStatus.failed:
      case UploadStatus.cancelled:
        isRetrying.value = false;
        uploadProgress.value = 0.0;
        break;
    }
  }

  /// Show network waiting snackbar (only once)
  bool _networkSnackbarShown = false;
  void _showNetworkWaitingSnackbar() {
    if (_networkSnackbarShown) return;
    _networkSnackbarShown = true;

    SnackbarUtils.showInfo(
      'Network Issue',
      'Upload paused. Will resume automatically when connected.',
    );

    // Reset flag after 10 seconds
    Future.delayed(Duration(seconds: 10), () {
      _networkSnackbarShown = false;
    });
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
      _setDefaultValues();
    } finally {
      isLoading.value = false;
    }
  }

  void _populateFromProfile(UserProfile profile) {
    // Use username if available (same as homepage), otherwise fallback to fullName or displayName
    name.value = profile.username ?? profile.fullName;
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

  /// Upload image to Firebase Storage with robust error handling and retry logic
  Future<void> uploadImage(File imageFile) async {
    try {
      // OPTIMISTIC UI: Show image immediately from local file
      localImageFile.value = imageFile;
      uploadProgress.value = 0.01; // Show a tiny progress to indicate upload started

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        SnackbarUtils.showError('Error', 'User not authenticated');
        localImageFile.value = null;
        return;
      }

      // Queue upload with retry logic and network recovery
      await _uploadQueue.queueUpload(
        imageFile: imageFile,
        oldImageUrl: profilePic.value.isNotEmpty ? profilePic.value : null,
        onProgress: (progress) {
          uploadProgress.value = progress;
        },
        onSuccess: (downloadUrl) async {
          // Clear cache to force fresh image load
          try {
            final cacheManager = DefaultCacheManager();
            await cacheManager.removeFile(downloadUrl);
          } catch (e) {
            print('Cache clear error: $e');
          }

          // Update network URL (switch from local to network image)
          profilePic.value = downloadUrl;
          localImageFile.value = null; // Clear local file now that we have network URL

          // Update homepage data service to refresh image there too
          try {
            final homepageService = Get.find<HomepageDataService>();
            await homepageService.loadUserProfile();
          } catch (e) {
            print('Homepage refresh error: $e');
          }

          // Success! Show subtle success indication
          uploadStatusMessage.value = '';
        },
        onError: (error) {
          // Only revert optimistic update if it's an unrecoverable error
          if (!error.contains('retry') && !error.contains('network')) {
            localImageFile.value = null;
            uploadProgress.value = 0.0;
            SnackbarUtils.showError('Upload Failed', error);
          }
          // For recoverable errors (network issues, retries), keep showing the local image
        },
      );
    } catch (e) {
      // Unexpected error - revert optimistic update
      localImageFile.value = null;
      uploadProgress.value = 0.0;
      SnackbarUtils.showError('Error', 'Failed to start upload: ${e.toString()}');
    }
  }

  /// Cancel ongoing upload
  Future<void> cancelUpload() async {
    await _uploadQueue.cancelUpload();
    localImageFile.value = null;
    uploadProgress.value = 0.0;
    uploadStatusMessage.value = '';
    SnackbarUtils.showInfo('Upload Cancelled', 'Image upload has been cancelled');
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