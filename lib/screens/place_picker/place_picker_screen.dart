import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:place_picker_google/place_picker_google.dart';
import 'dart:math' as dart_math;
import '../../config/app_colors.dart';
import '../../controllers/race/create_race_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/auth/auth_button.dart';

class PlacePickerScreen extends StatefulWidget {
  final bool isStart;

  const PlacePickerScreen({super.key, required this.isStart});

  @override
  State<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends State<PlacePickerScreen> {
  final controller = Get.find<CreateRaceController>();

  @override
  Widget build(BuildContext context) {
    return PlacePicker(
      enableNearbyPlaces: false,
      showSearchInput: true,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,

      // Custom back button with consistent app theme
      backWidgetBuilder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.appColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        );
      },

      // Search input with consistent app theme
      searchInputDecorationConfig: SearchInputDecorationConfig(
        filled: true,
        fillColor: Colors.white,
        hintText: widget.isStart
            ? 'Search for starting location...'
            : 'Search for ending location...',
        hintStyle: GoogleFonts.poppins(
          color: AppColors.lightGray,
          fontSize: 16,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.appColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.appColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.appColor,
            width: 2,
          ),
        ),
        prefixIcon: Container(
          margin: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.appColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.search_rounded,
            color: AppColors.appColor,
            size: 20,
          ),
        ),
      ),

      // API Key configuration
      apiKey: AppConstants.GOOGLE_MAP_API_KEY, // Replace with your actual API key

      // Initial location
      initialLocation: LatLng(
        widget.isStart
            ? controller.startLat?.value ?? 28.6139 // Default to Delhi
            : controller.endLat?.value ?? 28.6139,
        widget.isStart
            ? controller.startLng?.value ?? 77.2090
            : controller.endLng?.value ?? 77.2090,
      ),

      // Custom selected place widget with minimal design
      selectedPlaceWidgetBuilder: (ctx, state, result) {
        return SafeArea(
          top: false,
          child: Container(
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Icon(
                    widget.isStart ? Icons.radio_button_checked : Icons.location_on,
                    color: AppColors.appColor,
                    size: 28,
                  ),

                  SizedBox(height: 12),

                  // Confirm button only
                  AuthButton(
                    text: "Confirm Location",
                    onPressed: () {
                      if (result == null) {
                        Get.snackbar(
                          'Error',
                          'Please select a location on the map',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                          borderRadius: 12,
                          margin: EdgeInsets.all(16),
                        );
                        return;
                      }

                      _updateLocation(result);
                      Navigator.of(context).pop();
                    },
                    icon: Icons.check_circle_rounded,
                    backgroundColor: AppColors.appColor,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _updateLocation(LocationResult result) {
    // Validate location result
    if (result.latLng == null || result.formattedAddress == null) {
      Get.snackbar(
        'Error',
        'Invalid location selected. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        borderRadius: 12,
        margin: EdgeInsets.all(16),
      );
      return;
    }

    if (widget.isStart) {
      // Update start location
      controller.startAddress.value = result.formattedAddress!;
      controller.startLat?.value = result.latLng!.latitude;
      controller.startLng?.value = result.latLng!.longitude;

      // Auto-generate random end location 1-5 km away
      controller.generateRandomEndLocation(
        result.latLng!.latitude,
        result.latLng!.longitude,
      );
    } else {
      // Update end location
      controller.endAddress.value = result.formattedAddress!;
      controller.endLat?.value = result.latLng!.latitude;
      controller.endLng?.value = result.latLng!.longitude;

      // Calculate distance if both locations are set
      _calculateDistance();
    }
  }

  void _calculateDistance() {
    // Only calculate if both start and end points are set
    if (controller.startLat?.value != 0.0 && 
        controller.startLng?.value != 0.0 &&
        controller.endLat?.value != 0.0 && 
        controller.endLng?.value != 0.0) {
      
      // Simple distance calculation using Haversine formula
      double distance = _haversineDistance(
        controller.startLat!.value,
        controller.startLng!.value,
        controller.endLat!.value,
        controller.endLng!.value,
      );
      
      controller.routeDistance.value = distance.toStringAsFixed(2);
      
      // Smart update stopping time based on distance
      controller.smartUpdateStoppingTime();
    }
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth radius in kilometers

    // Convert degrees to radians
    double lat1Rad = lat1 * dart_math.pi / 180;
    double lat2Rad = lat2 * dart_math.pi / 180;
    double dLat = (lat2 - lat1) * dart_math.pi / 180;
    double dLon = (lon2 - lon1) * dart_math.pi / 180;

    // Haversine formula
    double a = dart_math.sin(dLat / 2) * dart_math.sin(dLat / 2) +
        dart_math.cos(lat1Rad) * dart_math.cos(lat2Rad) *
        dart_math.sin(dLon / 2) * dart_math.sin(dLon / 2);

    double c = 2 * dart_math.atan2(dart_math.sqrt(a), dart_math.sqrt(1 - a));

    return earthRadius * c;
  }
}

