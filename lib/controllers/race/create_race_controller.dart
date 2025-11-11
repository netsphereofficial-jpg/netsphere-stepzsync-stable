import 'dart:developer';
import 'dart:math' as dart_math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/models/race_data_model.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../screens/active_races/active_races_screen.dart';
import '../../screens/home/homepage_screen/controllers/homepage_data_service.dart';
import '../../services/auth/firebase_auth_service.dart';
import '../../services/firebase_service.dart';
import '../../services/health_sync_service.dart';
import '../../services/xp_service.dart';
// ❌ REMOVED: import '../../utils/notification_helpers.dart'; - no longer needed
import '../../screens/races/create_race/race_summary_screen.dart';

class CreateRaceController extends GetxController {
  // Text controllers
  final titleController = TextEditingController();
  final startController = TextEditingController();
  final endController = TextEditingController();
  final scheduleTimeController = TextEditingController();

  // Focus nodes
  final titleFocus = FocusNode();

  // Observable variables
  final RxString startAddress = ''.obs;
  final RxString endAddress = ''.obs;
  final RxString routeDistance = ''.obs;
  final RxString raceType = 'Public'.obs;
  final RxInt totalParticipants = 10.obs;
  final RxInt participantLimit = 2.obs;
  final RxString raceStoppingTime = '1 hours'.obs;
  final RxString genderPref = 'No preference'.obs;
  final Rx<DateTime> selectedDateTime = DateTime.now()
      .add(Duration(minutes: 30))
      .obs;

  // Location coordinates - Initialize with Delhi coordinates to prevent ZERO_RESULTS
  final RxDouble? startLat = RxDouble(28.6139);
  final RxDouble? startLng = RxDouble(77.2090);
  final RxDouble? endLat = RxDouble(28.6139);
  final RxDouble? endLng = RxDouble(77.2090);

  // Loading state
  final RxBool isLoading = false.obs;
  final RxBool isLoadingCurrentLocation = false.obs;

  // Firebase service
  late final FirebaseService _firebaseService;

  @override
  void onInit() {
    super.onInit();
    _firebaseService = Get.find<FirebaseService>();
    _initializeScheduleTime();
    _setupTextControllerListeners();
    _loadCurrentLocationAsStart();
  }

  void _setupTextControllerListeners() {
    // Listen to startAddress changes with debouncing
    debounce(
      startAddress,
      (address) {
        if (startController.text != address) {
          startController.text = address;
        }
      },
      time: Duration(milliseconds: 300),
    );

    // Listen to endAddress changes with debouncing
    debounce(
      endAddress,
      (address) {
        if (endController.text != address) {
          endController.text = address;
        }
      },
      time: Duration(milliseconds: 300),
    );
  }

  void _initializeScheduleTime() {
    final dateTime = selectedDateTime.value;
    final formattedDate = DateFormat('dd/MM/yyyy').format(dateTime);
    final formattedTime = DateFormat('hh:mm a').format(dateTime);
    scheduleTimeController.text = '$formattedDate at $formattedTime';
  }

  Future<void> _loadCurrentLocationAsStart() async {
    try {
      isLoadingCurrentLocation.value = true;

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        log('Location permission denied, using default location');
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        log('Location services are disabled, using default location');
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );

      // Update start coordinates
      startLat?.value = position.latitude;
      startLng?.value = position.longitude;

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address =
            '${placemark.name ?? ''}, ${placemark.locality ?? ''}, ${placemark.administrativeArea ?? ''}, ${placemark.country ?? ''}'
                .replaceAll(
                  RegExp(r'^,\s*|,\s*$'),
                  '',
                ) // Remove leading/trailing commas
                .replaceAll(RegExp(r',\s*,'), ','); // Remove double commas

        startAddress.value = address.trim();

        log('Current location set as start point: $address');

        // Auto-generate random end location after setting start
        await generateRandomEndLocation(position.latitude, position.longitude);
      }
    } catch (e) {
      log('Error getting current location: $e');
      // Keep default Delhi coordinates if current location fails
    } finally {
      isLoadingCurrentLocation.value = false;
    }
  }

  /// Generate random end location 1-5 km from start point
  Future<void> generateRandomEndLocation(double startLat, double startLng) async {
    try {
      // Generate random distance between 1.0 and 5.0 km
      final random = dart_math.Random();
      final randomDistance = 1.0 + random.nextDouble() * 4.0; // 1.0 - 5.0 km

      // Generate random bearing (0-360 degrees)
      final randomBearing = random.nextDouble() * 360.0;

      // Calculate destination coordinates
      final destination = _calculateDestination(
        startLat,
        startLng,
        randomDistance,
        randomBearing,
      );

      // Update end coordinates
      endLat!.value = destination['lat']!;
      endLng!.value = destination['lng']!;

      // Reverse geocode to get address
      try {
        final placemarks = await placemarkFromCoordinates(
          destination['lat']!,
          destination['lng']!,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final address = [
            place.street,
            place.subLocality,
            place.locality,
            place.administrativeArea,
          ].where((s) => s != null && s.isNotEmpty).join(', ');

          endAddress.value = address.isNotEmpty ? address : 'Random Location';
          endController.text = endAddress.value;
        }
      } catch (e) {
        endAddress.value = 'Random Location (${randomDistance.toStringAsFixed(2)} km away)';
        endController.text = endAddress.value;
        log('Error reverse geocoding random location: $e');
      }

      // Calculate and update distance
      final distance = _calculateDistance(startLat, startLng, endLat!.value, endLng!.value);
      routeDistance.value = distance.toStringAsFixed(2);

      log('Generated random end location: ${randomDistance.toStringAsFixed(2)} km away at bearing $randomBearing°');
    } catch (e) {
      log('Error generating random end location: $e');
      SnackbarUtils.showError(
        'Location Error',
        'Failed to generate random end location',
      );
    }
  }

  /// Calculate destination point given start point, distance and bearing
  Map<String, double> _calculateDestination(
    double lat1,
    double lon1,
    double distance,
    double bearing,
  ) {
    const double earthRadius = 6371.0; // km

    // Convert to radians
    final lat1Rad = lat1 * dart_math.pi / 180.0;
    final lon1Rad = lon1 * dart_math.pi / 180.0;
    final bearingRad = bearing * dart_math.pi / 180.0;

    // Calculate destination latitude
    final lat2Rad = dart_math.asin(
      dart_math.sin(lat1Rad) * dart_math.cos(distance / earthRadius) +
      dart_math.cos(lat1Rad) * dart_math.sin(distance / earthRadius) * dart_math.cos(bearingRad)
    );

    // Calculate destination longitude
    final lon2Rad = lon1Rad + dart_math.atan2(
      dart_math.sin(bearingRad) * dart_math.sin(distance / earthRadius) * dart_math.cos(lat1Rad),
      dart_math.cos(distance / earthRadius) - dart_math.sin(lat1Rad) * dart_math.sin(lat2Rad)
    );

    // Convert back to degrees
    final lat2 = lat2Rad * 180.0 / dart_math.pi;
    final lon2 = lon2Rad * 180.0 / dart_math.pi;

    return {'lat': lat2, 'lng': lon2};
  }

  /// Set end location to current GPS location
  Future<void> setEndLocationToCurrent() async {
    try {
      isLoading.value = true;

      // Check location services
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        SnackbarUtils.showWarning(
          'Location Services Disabled',
          'Please enable location services to use current location',
        );
        return;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          SnackbarUtils.showWarning(
            'Permission Denied',
            'Location permission is required to use current location',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        SnackbarUtils.showWarning(
          'Permission Denied',
          'Please enable location permission in settings',
        );
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );

      // Update end coordinates
      endLat!.value = position.latitude;
      endLng!.value = position.longitude;

      // Reverse geocode to get address
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final address = [
            place.street,
            place.subLocality,
            place.locality,
            place.administrativeArea,
          ].where((s) => s != null && s.isNotEmpty).join(', ');

          endAddress.value = address.isNotEmpty ? address : 'Current Location';
          endController.text = endAddress.value;
        }
      } catch (e) {
        endAddress.value = 'Current Location';
        endController.text = endAddress.value;
        log('Error reverse geocoding current location: $e');
      }

      // Calculate distance if start location is set
      if (startLat!.value != 0 && startLng!.value != 0) {
        final distance = _calculateDistance(
          startLat!.value,
          startLng!.value,
          endLat!.value,
          endLng!.value,
        );
        routeDistance.value = distance.toStringAsFixed(2);
      }

      SnackbarUtils.showSuccess(
        'Location Updated',
        'End location set to your current location',
      );
    } catch (e) {
      log('Error getting current location for end point: $e');
      SnackbarUtils.showError(
        'Location Error',
        'Failed to get current location',
      );
    } finally {
      isLoading.value = false;
    }
  }

  void incrementParticipants() {
    if (totalParticipants.value < 20) {
      totalParticipants.value++;
      if (participantLimit.value > totalParticipants.value) {
        participantLimit.value = totalParticipants.value;
      }
      _updateRaceTypeBasedOnParticipants();
    }
  }

  void decrementParticipants() {
    if (totalParticipants.value > 1) {
      // Allow single participant for solo races
      totalParticipants.value--;
      if (participantLimit.value > totalParticipants.value) {
        participantLimit.value = totalParticipants.value;
      }
      _updateRaceTypeBasedOnParticipants();
    }
  }

  void _updateRaceTypeBasedOnParticipants() {
    if (totalParticipants.value == 1) {
      raceType.value = 'Solo';
      participantLimit.value = 1; // Auto-set limit to 1 for solo
    } else if (totalParticipants.value <= 5) {
      if (raceType.value == 'Solo') {
        raceType.value =
            'Private'; // Switch from Solo to Private for small groups
      }
    } else if (totalParticipants.value <= 15) {
      if (raceType.value == 'Solo') {
        raceType.value =
            'Public'; // Switch from Solo to Public for medium groups
      }
    } else {
      if (raceType.value == 'Solo') {
        raceType.value =
            'Public'; // Switch from Solo to Public for large groups
      }
    }
  }

  void incrementLimitParticipants() {
    if (participantLimit.value < totalParticipants.value) {
      participantLimit.value++;
    }
  }

  void decrementLimitParticipants() {
    final minLimit = raceType.value == 'Solo' ? 1 : 2;
    if (participantLimit.value > minLimit) {
      participantLimit.value--;
    }
  }

  String getParticipantGuidance() {
    if (totalParticipants.value == 1) {
      return 'Perfect for solo training! Challenge yourself with a personal race.';
    } else if (totalParticipants.value <= 3) {
      return 'Perfect for competing with a friend! Small group races are more intimate.';
    } else if (totalParticipants.value <= 10) {
      return 'Excellent group size! Perfect balance between competition and fun.';
    } else if (totalParticipants.value <= 15) {
      return 'Large community event! Get ready for an exciting competitive atmosphere.';
    } else {
      return 'Marathon-scale event! Perfect for serious competitive racing with many participants.';
    }
  }

  String getDistanceEncouragement() {
    if (routeDistance.value.isEmpty) return '';

    final distance = double.tryParse(routeDistance.value) ?? 0.0;
    if (distance < 1) {
      return 'Perfect for a quick sprint!';
    } else if (distance < 5) {
      return 'Great distance for a fun run!';
    } else if (distance < 10) {
      return 'Excellent workout distance!';
    } else if (distance < 21) {
      return 'Serious challenge ahead!';
    } else {
      return 'Epic marathon-style race!';
    }
  }

  String getStoppingTimeGuidance() {
    if (routeDistance.value.isEmpty)
      return 'Timer starts after the first participant finishes.';

    final distance = double.tryParse(routeDistance.value) ?? 0.0;
    if (distance < 0.5) {
      return 'Very short distance - 5 minutes for a quick sprint!';
    } else if (distance < 2) {
      return 'Short distance - 1 hour should be plenty for everyone to finish!';
    } else if (distance < 10) {
      return 'Good distance - 12 hours gives everyone a fair chance.';
    } else {
      return 'Long distance - 24 hours ensures no one gets left behind.';
    }
  }

  void smartUpdateStoppingTime() {
    if (routeDistance.value.isEmpty) return;

    final distance = double.tryParse(routeDistance.value) ?? 0.0;
    if (distance < 0.5 && raceStoppingTime.value != '5 mins') {
      raceStoppingTime.value = '5 mins';
    } else if (distance >= 0.5 && distance < 2 && raceStoppingTime.value != '1 hours') {
      raceStoppingTime.value = '1 hours';
    } else if (distance >= 2 &&
        distance < 10 &&
        raceStoppingTime.value == '1 hours') {
      raceStoppingTime.value = '12 hours';
    } else if (distance >= 10 && raceStoppingTime.value != '24 hours') {
      raceStoppingTime.value = '24 hours';
    }
  }

  double getCompletionProgress() {
    int completed = 0;
    int total = 7; // Total required fields

    if (titleController.text.trim().isNotEmpty) completed++;
    if (startAddress.value.isNotEmpty) completed++;
    if (endAddress.value.isNotEmpty) completed++;
    if (raceType.value.isNotEmpty) completed++;
    if (scheduleTimeController.text.isNotEmpty) completed++;
    if (genderPref.value.isNotEmpty) completed++;
    if (totalParticipants.value >= 1) completed++;

    return completed / total;
  }

  String getCompletionMessage() {
    final progress = getCompletionProgress();
    if (progress == 1.0) {
      return 'Ready to create your race!';
    } else if (progress >= 0.7) {
      return 'Almost there! Just a few more details.';
    } else if (progress >= 0.4) {
      return 'Good progress! Keep going.';
    } else {
      return 'Let\'s build your perfect race!';
    }
  }

  void _showSuccessDialog(RaceData race, String raceId) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.green.withOpacity(0.05)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 48,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Race Created Successfully!',
                style: Get.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Race Name', race.title ?? 'Unknown'),
                    _buildInfoRow(
                      'Participants',
                      '${race.maxParticipants ?? 0}',
                    ),
                    if ((race.totalDistance ?? 0) > 0)
                      _buildInfoRow(
                        'Distance',
                        '${race.totalDistance?.toStringAsFixed(2)} km',
                      ),
                    _buildInfoRow(
                      'Schedule',
                      race.raceScheduleTime ?? 'Not scheduled',
                    ),
                    _buildInfoRow('Race ID', raceId.substring(0, 12) + '...'),
                  ],
                ),
              ),
              SizedBox(height: 20),
              // Show invite button for private races
              if (race.isPrivate == true) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Get.back(); // Close dialog first
                      // TODO: Navigate to InviteUsersScreen when needed
                      // Get.to(() => InviteUsersScreen(race: race));
                    },
                    icon: Icon(Icons.people, color: Colors.white),
                    label: Text(
                      'Invite Friends',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2759FF),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _handleDoneAction(),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text('Done'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleCreateAnotherAction(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Create Another',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: 13,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _handleDoneAction() {
    // Close the success dialog first
    Get.back();

    // Navigate to active races screen WITH navigation stack preserved
    // This allows users to navigate back and maintains app flow
    Get.to(() => ActiveRacesScreen());
  }

  void _handleCreateAnotherAction() {
    // Close dialog first
    Get.back(); // Close dialog
  }

  void _resetFormForNewRace() {
    // Clear all form fields
    titleController.clear();
    startController.clear();
    endController.clear();
    scheduleTimeController.clear();

    // Reset all observable values
    startAddress.value = '';
    endAddress.value = '';
    routeDistance.value = '';

    // Reset to defaults
    raceType.value = 'Public';
    totalParticipants.value = 10;
    participantLimit.value = 2;
    raceStoppingTime.value = '1 hours';
    genderPref.value = 'No preference';
    selectedDateTime.value = DateTime.now().add(Duration(minutes: 30));

    // Reset coordinates to Delhi
    startLat?.value = 28.6139;
    startLng?.value = 77.2090;
    endLat?.value = 28.6139;
    endLng?.value = 77.2090;

    // Reinitialize schedule time
    _initializeScheduleTime();

    // Show encouraging feedback
    Get.snackbar(
      'Ready for Next Race!',
      'Form cleared and ready for your next awesome race!',
      backgroundColor: Colors.blue.withOpacity(0.1),
      colorText: Colors.blue[800],
      borderRadius: 12,
      margin: EdgeInsets.all(16),
      duration: Duration(seconds: 2),
    );
  }

  Future<void> pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDateTime.value,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) {
      selectedDateTime.value = DateTime(
        picked.year,
        picked.month,
        picked.day,
        selectedDateTime.value.hour,
        selectedDateTime.value.minute,
      );
      _updateScheduleTimeDisplay();
    }
  }

  Future<void> pickTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedDateTime.value),
    );
    if (picked != null) {
      selectedDateTime.value = DateTime(
        selectedDateTime.value.year,
        selectedDateTime.value.month,
        selectedDateTime.value.day,
        picked.hour,
        picked.minute,
      );
      _updateScheduleTimeDisplay();
    }
  }

  void _updateScheduleTimeDisplay() {
    final dateTime = selectedDateTime.value;
    final formattedDate = DateFormat('dd/MM/yyyy').format(dateTime);
    final formattedTime = DateFormat('hh:mm a').format(dateTime);
    scheduleTimeController.text = '$formattedDate at $formattedTime';
  }

  bool validateDateTime(DateTime dateTime) {
    final now = DateTime.now();

    // ✅ Allow scheduling races at any time (even in the past for testing)
    // Only warn if the time is in the past
    if (dateTime.isBefore(now)) {
      SnackbarUtils.showWarning(
        'Past Time Selected',
        'You selected a time in the past. The race can be started immediately.',
      );
      // Don't block - just show warning
    }
    return true; // Always allow
  }

  void showRaceSummaryDialog() {
    if (!_validateRaceDetails()) return;

    // Navigate to race summary screen instead of showing dialog
    Get.to(
      () => RaceSummaryScreen(
        controller: this,
        onConfirm: _createRaceConfirmed,
      ),
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 300),
    );
  }

  Future<void> _createRaceConfirmed() async {
    if (!_validateRaceDetails()) return;

    try {
      isLoading.value = true;

      // Get current user
      final currentUser = await FirebaseAuthService.currentUser;
      if (currentUser == null) {
        SnackbarUtils.showError(
          'Authentication Error',
          'Please login to create a race',
        );
        return;
      }

      // Validate coordinates for non-solo races
      if (raceType.value != 'Solo') {
        if (startLat?.value == null ||
            startLng?.value == null ||
            endLat?.value == null ||
            endLng?.value == null) {
          SnackbarUtils.showError(
            'Location Error',
            'Unable to get location coordinates. Please try selecting locations again.',
          );
          return;
        }
      }

      // Parse distance
      double distance = 0.0;
      if (routeDistance.value.isNotEmpty) {
        distance = double.tryParse(routeDistance.value) ?? 0.0;
      }

      // Set defaults for Solo and Marathon races
      String finalGenderPref = genderPref.value;
      String finalRaceStoppingTime = raceStoppingTime.value;
      int finalTotalParticipants = totalParticipants.value;
      int finalParticipantLimit = participantLimit.value;

      if (raceType.value == 'Solo') {
        // For solo races, set default values for hidden fields
        finalGenderPref = 'No preference'; // Default for solo races
        finalRaceStoppingTime = '5 mins'; // Default for solo races
        finalTotalParticipants = 1;
        finalParticipantLimit = 1;
      } else if (raceType.value == 'Marathon') {
        // For marathon races, no time limit (open-ended endurance challenge)
        finalRaceStoppingTime = 'No limit'; // Marathon has no time limit
      }

      // ✅ CRITICAL FIX: Capture baseline for race creator at race creation time
      // This ensures organizer has a baseline even if they're offline when race auto-starts
      print('📊 [CREATE_RACE] Capturing baseline for race creator...');

      // Get health service for baseline capture
      int baselineSteps = 0;
      double baselineDistance = 0.0;
      int baselineCalories = 0;
      DateTime baselineTimestamp = DateTime.now();
      bool baselineCaptured = false;

      try {
        if (Get.isRegistered<HealthSyncService>()) {
          final healthService = Get.find<HealthSyncService>();

          // Retry up to 3 times with 2-second delays to avoid zero baseline
          for (int attempt = 1; attempt <= 3 && !baselineCaptured; attempt++) {
            print('📊 [CREATE_RACE] Baseline capture attempt $attempt/3...');

            // Try to get current health data for baseline
            final now = DateTime.now();
            final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
            final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
            final healthData = await healthService.getHealthDataForDateRange(todayStart, todayEnd);

            if (healthData != null) {
              final steps = healthData['steps'] ?? 0;
              final distance = (healthData['distance'] ?? 0.0).toDouble();
              final calories = healthData['calories'] ?? 0;

              // ✅ VALIDATION: Only accept non-zero baseline
              // Zero baseline causes drift where ALL future steps get added to race
              if (steps > 0 || distance > 0 || calories > 0) {
                baselineSteps = steps;
                baselineDistance = distance;
                baselineCalories = calories;
                baselineCaptured = true;
                print('✅ [CREATE_RACE] Creator baseline captured: $baselineSteps steps, ${baselineDistance.toStringAsFixed(2)} km, $baselineCalories kcal');
                break;
              } else {
                print('⚠️ [CREATE_RACE] Attempt $attempt: Health data is all zeros - retrying...');
                if (attempt < 3) {
                  await Future.delayed(Duration(seconds: 2));
                }
              }
            } else {
              print('⚠️ [CREATE_RACE] Attempt $attempt: Health data not available - retrying...');
              if (attempt < 3) {
                await Future.delayed(Duration(seconds: 2));
              }
            }
          }

          if (!baselineCaptured) {
            print('⚠️ [CREATE_RACE] Could not capture valid baseline after 3 attempts');
            print('   This race will have zero baseline - baseline will be captured when user starts race manually');
            print('   OR when user opens app after auto-start and periodic sync runs');
          }
        }
      } catch (e) {
        print('⚠️ [CREATE_RACE] Could not capture creator baseline: $e');
        // Continue without baseline - will be captured on race start or first sync
      }

      // Create participant for the race creator using new model
      final creatorParticipant = Participant(
        userId: currentUser.uid,
        userName:
            currentUser.displayName ??
            currentUser.email?.split('@')[0] ??
            'User',
        distance: 0.0,
        remainingDistance: distance,
        rank: 1,
        steps: 0,
        status: 'joined',
        lastUpdated: DateTime.now(),
        calories: 0,
        avgSpeed: 0.0,
        isCompleted: false,
        baselineSteps: baselineSteps,
        baselineDistance: baselineDistance,
        baselineCalories: baselineCalories,
        baselineTimestamp: baselineTimestamp,
      );

      // Convert schedule time to proper format for database
      // ✅ FIX: Use actual schedule DateTime for raceScheduleTime field
      DateTime? actualScheduleTime;
      String formattedScheduleTimeDisplay;

      if (raceType.value == 'Solo') {
        formattedScheduleTimeDisplay = 'Available anytime';
        actualScheduleTime = null; // Solo races don't have a schedule time
      } else if (raceType.value == 'Marathon') {
        formattedScheduleTimeDisplay = 'Open-ended'; // Marathon has no schedule
        actualScheduleTime = null; // Marathon races don't have a schedule time
      } else {
        final dateTime = selectedDateTime.value;
        formattedScheduleTimeDisplay = DateFormat(
          'dd-MM-yyyy hh:mm a',
        ).format(dateTime);
        actualScheduleTime = dateTime; // Store actual DateTime for Cloud Function
      }

      // Map race type to appropriate values
      int raceTypeId = raceType.value == 'Solo'
          ? 1
          : raceType.value == 'Private'
          ? 2
          : raceType.value == 'Marathon'
          ? 4
          : 3; // Public (default)
      bool isPrivate = raceType.value == 'Private';

      // Map gender preference to ID
      int genderPreferenceId = finalGenderPref == 'Male'
          ? 1
          : finalGenderPref == 'Female'
          ? 2
          : 0;

      // Parse duration from raceStoppingTime
      // Duration timer starts ONLY when first participant finishes the race
      int durationMins;
      int durationHrs;

      if (finalRaceStoppingTime == 'No limit') {
        // Marathon: No time limit (set to a very high value like 999 days)
        durationMins = 999 * 24 * 60; // 999 days in minutes
        durationHrs = 999 * 24; // 999 days in hours
      } else if (finalRaceStoppingTime.contains('mins')) {
        // Parse minutes (e.g., "5 mins" -> 5 minutes)
        durationMins = int.tryParse(finalRaceStoppingTime.split(' ')[0]) ?? 5;
        durationHrs = 1; // Keep for backward compatibility, but durationMins is preferred
      } else if (finalRaceStoppingTime.contains('hours')) {
        // Parse hours and convert to minutes (e.g., "1 hours" -> 60 minutes)
        durationHrs = int.tryParse(finalRaceStoppingTime.split(' ')[0]) ?? 1;
        durationMins = durationHrs * 60;
      } else {
        // Default: 1 hour = 60 minutes
        durationHrs = 1;
        durationMins = 60;
      }

      // Create race using new RaceData model
      // NOTE: participants array is DEPRECATED - we use subcollection instead
      final race = RaceData(
        title: titleController.text.trim(),
        raceTypeId: raceTypeId,
        maxParticipants: finalTotalParticipants,
        minParticipants: finalParticipantLimit,
        joinedParticipants: 1,
        // Creator is auto-joined
        startLat: startLat?.value ?? 0.0,
        startLong: startLng?.value ?? 0.0,
        endLat: endLat?.value ?? 0.0,
        endLong: endLng?.value ?? 0.0,
        startAddress: startAddress.value,
        endAddress: endAddress.value,
        isPrivate: isPrivate,
        raceScheduleTime: formattedScheduleTimeDisplay, // Display format for UI
        raceDeadline: formattedScheduleTimeDisplay,
        // Same as schedule for now
        durationHrs: durationHrs,
        durationMins: durationMins,
        genderPreferenceId: genderPreferenceId,
        organizerUserId: currentUser.uid,
        organizerName:
            currentUser.displayName ??
            currentUser.email?.split('@')[0] ??
            'User',
        totalDistance: distance,
        statusId: formattedScheduleTimeDisplay.isNotEmpty ? 1 : 0,
        // statusId: 1 = Scheduled (has schedule time), statusId: 0 = Created (no schedule)
        status: formattedScheduleTimeDisplay.isNotEmpty ? 'scheduled' : 'created',
        currentRank: null,
        distanceCovered: 0.0,
        remainingDistance: distance,
        participants: null, // NOT USED - kept for backward compatibility
        leaderPreview: null, // Will be populated when race starts
      );

      // Save to Firestore using new methods
      await _firebaseService.ensureInitialized();

      // Create the race document
      final raceCollection = _firebaseService.firestore.collection('races');
      final raceDocRef = await raceCollection.add(race.toFirestore());
      final raceId = raceDocRef.id;

      // Update the race document with the generated ID and actual schedule time
      final updateData = {
        'id': raceId, // Store the actual Firestore document ID string
        'createdAt': FieldValue.serverTimestamp(),
      };

      // ✅ FIX: Store actual Timestamp for auto-start to work correctly
      if (actualScheduleTime != null) {
        updateData['raceScheduleTime'] = Timestamp.fromDate(actualScheduleTime);
      }

      await raceDocRef.update(updateData);

      // Add participant to race's participants subcollection
      await raceDocRef
          .collection('participants')
          .doc(currentUser.uid)
          .set(creatorParticipant.toFirestore());

      // Alternatively, if you have a dedicated createRace method:
      // final raceId = await _firebaseService.createRaceWithModel(race, creatorParticipant, currentUser.uid);

      // ❌ REMOVED: Race creation notifications are no longer sent per requirements
      // await NotificationHelpers.sendRaceCreationConfirmation(...)

      log('Race created with ID: $raceId');
      log(
        'Creator auto-joined as participant with comprehensive data structure',
      );

      // 🎁 Award XP for creating and joining the race
      try {
        log('🎯 Awarding XP to race creator: ${currentUser.uid}');

        final xpService = XPService();

        // Award create race XP (15 XP)
        await xpService.awardCreateRaceXP(
          userId: currentUser.uid,
          raceId: raceId,
          raceTitle: race.title ?? 'Race',
        );

        // Award join race XP (10 XP)
        await xpService.awardJoinRaceXP(
          userId: currentUser.uid,
          raceId: raceId,
          raceTitle: race.title ?? 'Race',
        );

        // Award first race XP if this is their first race (50 XP one-time)
        await xpService.awardFirstRaceXP(
          userId: currentUser.uid,
          raceId: raceId,
          raceTitle: race.title ?? 'Race',
        );

        log('✅ Awarded XP to race creator (create + join + first race bonus if applicable)');
      } catch (e, stackTrace) {
        log('⚠️ Failed to award XP to creator: $e');
        log('Stack trace: $stackTrace');
        // Don't block race creation if XP fails
      }

      // Navigate based on race type
      _handleDirectNavigation(race, raceId);
    } catch (e) {
      SnackbarUtils.showError(
        'Error',
        'Failed to create race: ${e.toString()}',
      );
      log('Error creating race: $e');
    } finally {
      isLoading.value = false;
    }
  }

  bool _validateRaceDetails() {
    final title = titleController.text.trim();

    if (title.isEmpty) {
      SnackbarUtils.showError('Validation Error', 'Please enter race title');
      return false;
    }

    if (startAddress.value.isEmpty) {
      SnackbarUtils.showError('Validation Error', 'Please add starting point');
      return false;
    }

    if (endAddress.value.isEmpty) {
      SnackbarUtils.showError('Validation Error', 'Please add ending point');
      return false;
    }

    if (raceType.value.isEmpty) {
      SnackbarUtils.showError('Validation Error', 'Please choose race type');
      return false;
    }

    // Schedule time is only required for non-Solo and non-Marathon races
    if (raceType.value != 'Solo' && raceType.value != 'Marathon') {
      if (scheduleTimeController.text.isEmpty) {
        SnackbarUtils.showError(
          'Validation Error',
          'Please schedule the race time',
        );
        return false;
      }

      if (!validateDateTime(selectedDateTime.value)) {
        return false;
      }
    }

    // Distance validation removed - allow any distance for races

    return true;
  }

  /// Handle direct navigation after race creation
  void _handleDirectNavigation(RaceData race, String raceId) {
    // Notify homepage to update active race count immediately
    _notifyHomepageOfRaceCreation();

    // Close RaceSummaryScreen first (if it's open)
    // Then navigate to ActiveRacesScreen
    Get.back(); // Close summary screen

    // Small delay to let the snackbar show and screen transition complete
    Future.delayed(Duration(milliseconds: 500), () {
      Get.to(() => ActiveRacesScreen());
    });
  }

  /// Notify homepage data service to refresh active race count after race creation
  void _notifyHomepageOfRaceCreation() {
    try {
      // Import homepage data service
      final homepageDataService = Get.find<HomepageDataService>();
      // Trigger immediate refresh of active joined race count
      homepageDataService.loadActiveJoinedRaceCount();
      print('Notified homepage of race creation - updating active race count');
    } catch (e) {
      // Homepage service might not be initialized yet, that's okay
      print(
        'Homepage service not found, race count will update on next refresh',
      );
    }
  }

  /// Auto-suggest end point within 2km of current location
  Future<void> _autoSuggestEndPoint() async {
    try {
      if (startLat?.value == null || startLng?.value == null) return;

      final startLatValue = startLat!.value;
      final startLngValue = startLng!.value;

      // Generate a random point within 2km radius
      final randomEndPoint = _generateRandomPointWithin2km(
        startLatValue,
        startLngValue,
      );

      // Update end coordinates
      endLat?.value = randomEndPoint['lat']!;
      endLng?.value = randomEndPoint['lng']!;

      // Get address for the suggested end point
      List<Placemark> placemarks = await placemarkFromCoordinates(
        randomEndPoint['lat']!,
        randomEndPoint['lng']!,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address =
            '${placemark.name ?? ''}, ${placemark.locality ?? ''}, ${placemark.administrativeArea ?? ''}, ${placemark.country ?? ''}'
                .replaceAll(RegExp(r'^,\s*|,\s*$'), '')
                .replaceAll(RegExp(r',\s*,'), ',');

        endAddress.value = address.trim();

        // Calculate and set distance
        final distance = _calculateDistance(
          startLatValue,
          startLngValue,
          randomEndPoint['lat']!,
          randomEndPoint['lng']!,
        );
        routeDistance.value = distance.toStringAsFixed(2);

        // Smart update stopping time based on distance
        smartUpdateStoppingTime();

        log(
          'Auto-suggested end point: $address (${distance.toStringAsFixed(2)}km away)',
        );

        // Show suggestion feedback
      }
    } catch (e) {
      log('Error auto-suggesting end point: $e');
    }
  }

  /// Generate a random point within 2km radius
  Map<String, double> _generateRandomPointWithin2km(
    double centerLat,
    double centerLng,
  ) {
    const double earthRadius = 6371000; // Earth radius in meters
    const double maxDistance = 2000; // 2km in meters

    // Generate random distance (0 to 2km) and bearing (0 to 360 degrees)
    final random = dart_math.Random();
    final distance = random.nextDouble() * maxDistance;
    final bearing = random.nextDouble() * 2 * dart_math.pi;

    // Convert to radians
    final lat1 = centerLat * dart_math.pi / 180;
    final lng1 = centerLng * dart_math.pi / 180;

    // Calculate new coordinates
    final lat2 = dart_math.asin(
      dart_math.sin(lat1) * dart_math.cos(distance / earthRadius) +
          dart_math.cos(lat1) *
              dart_math.sin(distance / earthRadius) *
              dart_math.cos(bearing),
    );

    final lng2 =
        lng1 +
        dart_math.atan2(
          dart_math.sin(bearing) *
              dart_math.sin(distance / earthRadius) *
              dart_math.cos(lat1),
          dart_math.cos(distance / earthRadius) -
              dart_math.sin(lat1) * dart_math.sin(lat2),
        );

    return {'lat': lat2 * 180 / dart_math.pi, 'lng': lng2 * 180 / dart_math.pi};
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371; // Earth radius in kilometers

    final dLat = (lat2 - lat1) * dart_math.pi / 180;
    final dLng = (lng2 - lng1) * dart_math.pi / 180;

    final a =
        dart_math.sin(dLat / 2) * dart_math.sin(dLat / 2) +
        dart_math.cos(lat1 * dart_math.pi / 180) *
            dart_math.cos(lat2 * dart_math.pi / 180) *
            dart_math.sin(dLng / 2) *
            dart_math.sin(dLng / 2);

    final c = 2 * dart_math.atan2(dart_math.sqrt(a), dart_math.sqrt(1 - a));

    return earthRadius * c;
  }

  @override
  void onClose() {
    titleController.dispose();
    startController.dispose();
    endController.dispose();
    scheduleTimeController.dispose();
    titleFocus.dispose();
    super.onClose();
  }
}
