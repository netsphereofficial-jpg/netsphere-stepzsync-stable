import 'package:get/get.dart';
import '../services/race_service.dart';
import '../models/race_models.dart';

class RaceCreationController extends GetxController {
  var isCreatingRaces = false.obs;
  var createdRaces = <RaceModel>[].obs;
  var errorMessage = ''.obs;

  /// Create races based on location
  Future<bool> createLocationBasedRaces({
    required String city,
    required String location,
    required double latitude,
    required double longitude,
  }) async {
    try {
      isCreatingRaces.value = true;
      errorMessage.value = '';

      final response = await RaceService.createLocationBasedRaces(
        city: city,
        location: location,
        latitude: latitude,
        longitude: longitude,
      );

      if (response.success && response.data != null) {
        createdRaces.value = response.data!;
        return true;
      } else {
        errorMessage.value = response.message ?? "";
        return false;
      }
    } catch (e) {
      errorMessage.value = 'Failed to create races: $e';
      return false;
    } finally {
      isCreatingRaces.value = false;
    }
  }

  /// Get races by city
  Future<void> getRacesByCity(String city) async {
    try {
      final response = await RaceService.getRacesByCity(city);
      if (response.success && response.data != null) {
        createdRaces.value = response.data!;
      }
    } catch (e) {
      print('Error getting races by city: $e');
    }
  }

  /// Clear races
  void clearRaces() {
    createdRaces.clear();
    errorMessage.value = '';
  }

  @override
  void onClose() {
    clearRaces();
    super.onClose();
  }
}