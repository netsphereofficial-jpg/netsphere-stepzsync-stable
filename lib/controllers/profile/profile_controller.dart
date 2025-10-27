import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/utils/snackbar_utils.dart';
import '../../core/utils/common_methods.dart';
import '../../models/profile_models.dart';
import '../../screens/home_screen/home_screen.dart';
import '../../services/firebase_storage_service.dart';
import '../../services/friends_service.dart';
import '../../services/local_notification_service.dart';
import '../../services/profile/profile_service.dart';

enum UsernameStatus { none, checking, available, taken, invalid }

class ProfileController extends GetxController {
  // Text controllers
  final nameCtr = TextEditingController();
  final usernameCtr = TextEditingController();
  final dobController = TextEditingController();
  final locationCtr = TextEditingController();
  final heightCtr = TextEditingController();
  final weightCtr = TextEditingController();

  // Observable variables
  var gender = ''.obs;
  var selectedDate = Rxn<DateTime>();
  var isLoading = false.obs;
  var isAuthorized = false.obs;

  // Username validation
  var usernameStatus = UsernameStatus.none.obs;
  var isCheckingUsername = false.obs;

  // Profile image related
  var selectedProfileImage = Rxn<File>();
  var profileImageUrl = RxnString();
  var isUploadingImage = false.obs;
  final ImagePicker _imagePicker = ImagePicker();

  // Height related
  var useCm = true.obs;
  var selectedMetric = 'cms'.obs;
  var selectedCmInt = 170.obs;
  var selectedCmDecimal = 0.obs;
  var selectedFeet = 5.obs;
  var selectedInches = 7.obs;

  // Weight related
  var useKg = true.obs;
  var selectedUnit = 'Kgs'.obs;
  var selectedKg = 70.obs;
  var selectedLbs = 154.obs;

  // Location coordinates
  double _currentLatitude = 0.0;
  double _currentLongitude = 0.0;

  @override
  void onInit() {
    super.onInit();
    _initializeDefaults();
    _loadExistingProfile();
    _setupUsernameListener();

    // Initialize profile data from arguments if provided (e.g., from social sign-ins)
    final arguments = Get.arguments;
    if (arguments != null && arguments is Map) {
      final name = arguments['name'] as String?;
      final email = arguments['email'] as String?;
      final photoUrl = arguments['photoUrl'] as String?;
      final provider = arguments['provider'] as String?;

      // Set name if available and field is empty
      if (name != null && name.isNotEmpty && nameCtr.text.isEmpty) {
        nameCtr.text = name.capitalizeWords();
      }

      // Set profile image URL if available from social sign-in
      if (photoUrl != null && photoUrl.isNotEmpty) {
        profileImageUrl.value = photoUrl;
      }

      // Note: email is typically managed by Firebase Auth, so we don't set it here
      // but we could use it for validation or display purposes if needed
    }
  }

  void _initializeDefaults() {
    updateHeightDisplay();
    updateWeightDisplay();
  }

  /// Initialize name if provided
  void initializeName(String? name) {
    if (name != null && name.isNotEmpty) {
      nameCtr.text = name.capitalizeWords();
    }
  }

  /// Load existing profile from Firestore
  Future<void> _loadExistingProfile() async {
    final result = await ProfileService.getProfile();
    if (result.success && result.data != null) {
      final profile = result.data as UserProfile;
      _populateFromProfile(profile);
    }
  }

  void _populateFromProfile(UserProfile profile) {
    nameCtr.text = profile.fullName;
    usernameCtr.text = profile.username ?? '';
    gender.value = profile.gender;
    locationCtr.text = profile.location;

    // Profile image
    profileImageUrl.value = profile.profilePicture;

    if (profile.dateOfBirth != null) {
      selectedDate.value = profile.dateOfBirth;
      dobController.text = _formatDate(profile.dateOfBirth!);
    }

    // Height - only populate if non-zero, otherwise keep defaults
    if (profile.height > 0) {
      if (profile.heightUnit == 'cms') {
        useCm.value = true;
        selectedMetric.value = 'cms';
        final heightParts = profile.height.toString().split('.');
        selectedCmInt.value = int.parse(heightParts[0]);
        selectedCmDecimal.value = heightParts.length > 1
            ? int.parse(heightParts[1].substring(0, 1))
            : 0;
      } else {
        useCm.value = false;
        selectedMetric.value = 'inches';
        selectedFeet.value = (profile.height / 12).floor();
        selectedInches.value = (profile.height % 12).round();
      }
    }

    // Weight - only populate if non-zero, otherwise keep defaults
    if (profile.weight > 0) {
      if (profile.weightUnit == 'Kgs') {
        useKg.value = true;
        selectedUnit.value = 'Kgs';
        selectedKg.value = profile.weight.round();
      } else {
        useKg.value = false;
        selectedUnit.value = 'Lbs';
        selectedLbs.value = profile.weight.round();
      }
    }

    isAuthorized.value = profile.healthKitEnabled;
    updateHeightDisplay();
    updateWeightDisplay();
  }

  /// Setup username validation listener
  void _setupUsernameListener() {
    usernameCtr.addListener(() {
      final username = usernameCtr.text.trim();
      if (username.isEmpty) {
        usernameStatus.value = UsernameStatus.none;
        return;
      }

      if (!_isValidUsername(username)) {
        usernameStatus.value = UsernameStatus.invalid;
        return;
      }

      _debounceUsernameCheck(username);
    });
  }

  /// Validate username format
  bool _isValidUsername(String username) {
    if (username.length < 3 || username.length > 20) return false;
    if (username.startsWith('_') || username.endsWith('_')) return false;
    return RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username);
  }

  /// Debounced username availability check
  void _debounceUsernameCheck(String username) {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (usernameCtr.text.trim() == username) {
        _checkUsernameAvailability(username);
      }
    });
  }

  /// Check username availability
  Future<void> _checkUsernameAvailability(String username) async {
    try {
      isCheckingUsername.value = true;
      usernameStatus.value = UsernameStatus.checking;

      final isAvailable = await FriendsService.isUsernameAvailable(username);

      usernameStatus.value = isAvailable
          ? UsernameStatus.available
          : UsernameStatus.taken;
    } catch (e) {
      usernameStatus.value = UsernameStatus.none;
      SnackbarUtils.showError('Error', 'Failed to check username availability');
    } finally {
      isCheckingUsername.value = false;
    }
  }

  /// Date picker
  Future<void> selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: Get.context!,
      initialDate: selectedDate.value ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      selectedDate.value = picked;
      dobController.text = _formatDate(picked);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  /// Pick profile image from gallery
  Future<void> pickImageFromGallery() async {
    try {
      // Check photo library permission first
      var photoPermission = await Permission.photos.status;
      if (photoPermission.isDenied) {
        photoPermission = await Permission.photos.request();
      }

      if (photoPermission.isPermanentlyDenied) {
        SnackbarUtils.showError(
          'Permission Required',
          'Photo library permission is required. Please enable it in Settings.',
        );
        await openAppSettings();
        return;
      }

      if (!photoPermission.isGranted && !photoPermission.isLimited) {
        SnackbarUtils.showError(
          'Permission Denied',
          'Photo library permission is required to select photos.',
        );
        return;
      }

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        selectedProfileImage.value = File(pickedFile.path);
        // Clear any existing URL as we have a new local image
        profileImageUrl.value = null;
      }
    } catch (e) {
      SnackbarUtils.showError('Error', 'Failed to pick image from gallery');
    }
  }

  /// Pick profile image from camera
  Future<void> pickImageFromCamera() async {
    try {
      // Check camera permission first
      var cameraPermission = await Permission.camera.status;
      if (cameraPermission.isDenied) {
        cameraPermission = await Permission.camera.request();
      }

      if (cameraPermission.isPermanentlyDenied) {
        SnackbarUtils.showError(
          'Permission Required',
          'Camera permission is required. Please enable it in Settings.',
        );
        await openAppSettings();
        return;
      }

      if (!cameraPermission.isGranted) {
        SnackbarUtils.showError(
          'Permission Denied',
          'Camera permission is required to take photos.',
        );
        return;
      }

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        selectedProfileImage.value = File(pickedFile.path);
        // Clear any existing URL as we have a new local image
        profileImageUrl.value = null;
      }
    } catch (e) {
      SnackbarUtils.showError('Error', 'Failed to take photo: ${e.toString()}');
    }
  }

  /// Show image picker options
  void showImagePickerOptions() {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Profile Picture',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Get.back();
                      pickImageFromCamera();
                    },
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 32,
                            color: Colors.grey[600],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Camera',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Get.back();
                      pickImageFromGallery();
                    },
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.photo_library,
                            size: 32,
                            color: Colors.grey[600],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Gallery',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (selectedProfileImage.value != null ||
                (profileImageUrl.value?.isNotEmpty ?? false)) ...[
              SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Get.back();
                  removeProfileImage();
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Remove Picture',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Remove profile image
  void removeProfileImage() {
    selectedProfileImage.value = null;
    profileImageUrl.value = null;
  }

  /// Upload profile image to Firebase Storage
  Future<String?> _uploadProfileImage() async {
    if (selectedProfileImage.value == null) return profileImageUrl.value;

    try {
      isUploadingImage.value = true;

      final result = await FirebaseStorageService.updateProfileImage(
        selectedProfileImage.value!,
        profileImageUrl.value,
      );

      if (result.success) {
        final newImageUrl = result.data as String;
        profileImageUrl.value = newImageUrl;
        // Clear the local file as it's now uploaded
        selectedProfileImage.value = null;
        return newImageUrl;
      } else {
        SnackbarUtils.showError('Upload Failed', result.error!);
        return null;
      }
    } catch (e) {
      SnackbarUtils.showError('Error', 'Failed to upload image');
      return null;
    } finally {
      isUploadingImage.value = false;
    }
  }

  /// Get current location
  Future<void> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        SnackbarUtils.showError(
          'Location Error',
          'Location services are disabled',
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          SnackbarUtils.showError(
            'Location Error',
            'Location permissions are denied',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        SnackbarUtils.showError(
          'Location Error',
          'Location permissions are permanently denied',
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      // Store coordinates for race creation
      _currentLatitude = position.latitude;
      _currentLongitude = position.longitude;

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        locationCtr.text =
            '${place.locality}, ${place.administrativeArea}, ${place.country}';
      }
    } catch (e) {
      SnackbarUtils.showError(
        'Location Error',
        'Failed to get current location',
      );
    }
  }

  /// Height and weight unit management
  void setUnit(String unit, bool isWeight) {
    if (isWeight) {
      selectedUnit.value = unit;
      useKg.value = unit == 'Kgs';
    } else {
      selectedMetric.value = unit;
      useCm.value = unit == 'cms';
    }

    if (isWeight) {
      updateWeightDisplay();
    } else {
      updateHeightDisplay();
    }
  }

  void updateHeightDisplay() {
    if (selectedMetric.value == 'cms' || useCm.value) {
      heightCtr.text = '${selectedCmInt.value}.${selectedCmDecimal.value} cm';
    } else {
      heightCtr.text = '${selectedFeet.value}\' ${selectedInches.value}"';
    }
  }

  void updateWeightDisplay() {
    if (selectedUnit.value == 'Kgs' || useKg.value) {
      weightCtr.text = '${selectedKg.value} Kgs';
    } else {
      weightCtr.text = '${selectedLbs.value} Lbs';
    }
  }

  /// Health permission request (iOS only)
  Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      // TODO: Implement HealthKit permission request
      isAuthorized.value = true;
      return true;
    }
    return false;
  }

  /// Fetch health data (iOS only)
  Future<bool> fetchHealthData() async {
    if (Platform.isIOS && isAuthorized.value) {
      // TODO: Implement HealthKit data fetching
      return true;
    }
    return false;
  }

  /// Validation
  bool _validateInputs() {
    if (nameCtr.text.trim().isEmpty) {
      SnackbarUtils.showError(
        'Validation Error',
        'Please enter your full name',
      );
      return false;
    }

    // Username validation
    final username = usernameCtr.text.trim();
    if (username.isNotEmpty) {
      if (!_isValidUsername(username)) {
        SnackbarUtils.showError(
          'Validation Error',
          'Username must be 3-20 characters long and contain only letters, numbers, and underscores',
        );
        return false;
      }
      if (usernameStatus.value == UsernameStatus.taken) {
        SnackbarUtils.showError(
          'Validation Error',
          'Username is already taken',
        );
        return false;
      }
      if (usernameStatus.value == UsernameStatus.checking) {
        SnackbarUtils.showError(
          'Validation Error',
          'Please wait while we check username availability',
        );
        return false;
      }
    }

    if (gender.value.isEmpty) {
      SnackbarUtils.showError('Validation Error', 'Please select your gender');
      return false;
    }

    if (selectedDate.value == null) {
      SnackbarUtils.showError(
        'Validation Error',
        'Please select your date of birth',
      );
      return false;
    }

    if (locationCtr.text.trim().isEmpty) {
      SnackbarUtils.showError('Validation Error', 'Please enter your location');
      return false;
    }

    return true;
  }

  /// Create UserProfile object from current data
  UserProfile _createProfileFromData({String? profilePictureUrl}) {
    double height;
    if (selectedMetric.value == 'cms') {
      height = double.parse(
        '${selectedCmInt.value}.${selectedCmDecimal.value}',
      );
    } else {
      height = (selectedFeet.value * 12) + selectedInches.value.toDouble();
    }

    double weight = selectedUnit.value == 'Kgs'
        ? selectedKg.value.toDouble()
        : selectedLbs.value.toDouble();

    // Get email from Firebase Auth
    final currentUser = FirebaseAuth.instance.currentUser;
    final userEmail = currentUser?.email ?? '';

    return UserProfile(
      email: userEmail,
      fullName: nameCtr.text.trim().capitalizeWords(),
      username: usernameCtr.text.trim().isEmpty
          ? null
          : usernameCtr.text.trim().toLowerCase(),
      phoneNumber: '',
      countryCode: '',
      gender: gender.value,
      dateOfBirth: selectedDate.value,
      location: locationCtr.text.trim(),
      height: height,
      heightUnit: selectedMetric.value,
      weight: weight,
      weightUnit: selectedUnit.value,
      healthKitEnabled: isAuthorized.value,
      profileCompleted: true,
      // This will be set in the service
      profilePicture: profilePictureUrl ?? profileImageUrl.value,
    );
  }

  /// Submit profile details
  Future<void> addDetailsClick() async {
    if (isLoading.value) return;

    if (!_validateInputs()) return;

    try {
      isLoading.value = true;
      HapticFeedback.lightImpact();

      // Upload image first if there's a new one selected
      String? finalImageUrl;
      if (selectedProfileImage.value != null) {
        finalImageUrl = await _uploadProfileImage();
        if (finalImageUrl == null) {
          // Image upload failed, don't proceed
          return;
        }
      } else {
        // Use existing image URL if no new image selected
        finalImageUrl = profileImageUrl.value;
      }

      final profile = _createProfileFromData(profilePictureUrl: finalImageUrl);
      final result = await ProfileService.saveProfile(profile);

      if (result.success) {
        SnackbarUtils.showSuccess('Success!', 'Profile saved successfully');

        // Send welcome notification
        await _sendWelcomeNotification();

        // Cleanup old profile images
        FirebaseStorageService.cleanupOldProfileImages();

        await Future.delayed(Duration(milliseconds: 1500));
        // Navigate to race creation progress screen, then home
        _navigateToRaceCreation();
      } else {
        SnackbarUtils.showError('Save Failed', result.error!);
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      SnackbarUtils.showError('Error', 'An unexpected error occurred');
      HapticFeedback.heavyImpact();
    } finally {
      isLoading.value = false;
    }
  }

  /// Navigate to race creation progress and then home
  void _navigateToRaceCreation() {
    // Get current location for race creation
    final currentLocation = locationCtr.text.trim();
    if (currentLocation.isEmpty) {
      // If no location, go directly to home
      Get.offAll(() => HomeScreen());
      return;
    }

    // Navigate directly to home screen
    Get.offAll(() => HomeScreen());
  }

  /// Send welcome notification after profile completion
  Future<void> _sendWelcomeNotification() async {
    try {
      final userName = nameCtr.text.trim();

      await LocalNotificationService.sendGeneralNotification(
        title: "Welcome to StepzSync! 🎉",
        message:
            "Hi $userName! Your profile is complete. Start your fitness journey now!",
        icon: "🎉",
      );
    } catch (e) {
      // Don't block the flow if notification fails
      debugPrint('Failed to send welcome notification: $e');
    }
  }

  @override
  void onClose() {
    nameCtr.dispose();
    usernameCtr.dispose();
    dobController.dispose();
    locationCtr.dispose();
    heightCtr.dispose();
    weightCtr.dispose();
    super.onClose();
  }
}
