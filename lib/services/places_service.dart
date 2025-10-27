import 'dart:convert';
import 'dart:developer';
import 'package:dio/dio.dart';
import '../core/constants/app_constants.dart';
import '../models/place_model.dart';

/// Service for interacting with Google Places API
/// Uses Nearby Search to find points of interest
class PlacesService {
  static final PlacesService _instance = PlacesService._internal();
  factory PlacesService() => _instance;
  PlacesService._internal();

  final Dio _dio = Dio();
  // Using legacy API for better compatibility
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

  /// Search for nearby places of specific types
  ///
  /// [latitude] and [longitude] define the center point
  /// [radius] is the search radius in meters (max 50000)
  /// [placeTypes] is a list of place types to search for
  /// [maxResults] limits the number of results (default 5)
  Future<List<PlaceResult>> searchNearbyPlaces({
    required double latitude,
    required double longitude,
    required List<String> placeTypes,
    double radius = 5000, // 5km default
    int maxResults = 5,
  }) async {
    try {
      log('🔍 Searching for nearby places at ($latitude, $longitude)');
      log('📍 Place types: $placeTypes, radius: ${radius}m');

      // Legacy API uses pipe-separated types
      final typesParam = placeTypes.join('|');

      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'location': '$latitude,$longitude',
          'radius': radius.toInt(),
          'type': typesParam,
          'key': AppConstants.GOOGLE_MAP_API_KEY,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;

        if (data['status'] == 'OK') {
          final results = (data['results'] as List? ?? [])
              .take(maxResults)
              .map((place) => PlaceResult.fromLegacyJson(place))
              .toList();

          log('✅ Found ${results.length} places');
          return results;
        } else {
          log('⚠️ API returned status: ${data['status']}');
          return [];
        }
      } else {
        log('❌ API Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      log('❌ Error searching nearby places: $e');
      return [];
    }
  }

  /// Get nearby places by location type category
  Future<List<PlaceResult>> getPlacesByCategory({
    required double latitude,
    required double longitude,
    required LocationCategory category,
    double radius = 5000,
    int maxResults = 5,
  }) async {
    final placeTypes = _getPlaceTypesForCategory(category);
    return searchNearbyPlaces(
      latitude: latitude,
      longitude: longitude,
      placeTypes: placeTypes,
      radius: radius,
      maxResults: maxResults,
    );
  }

  /// Map location categories to Google Places API types
  List<String> _getPlaceTypesForCategory(LocationCategory category) {
    switch (category) {
      case LocationCategory.monuments:
        return ['tourist_attraction', 'museum', 'landmark'];
      case LocationCategory.malls:
        return ['shopping_mall', 'department_store'];
      case LocationCategory.parks:
        return ['park', 'campground', 'hiking_area', 'national_park'];
      case LocationCategory.sports:
        return ['stadium', 'gym', 'sports_complex', 'sports_club'];
      case LocationCategory.waterside:
        return ['natural_feature', 'park']; // Will need to filter results
      case LocationCategory.currentLocation:
        return []; // Not used for API calls
    }
  }

  /// Get user-friendly name for place type
  static String getPlaceTypeName(String placeType) {
    final typeMap = {
      'tourist_attraction': 'Tourist Attraction',
      'museum': 'Museum',
      'landmark': 'Landmark',
      'shopping_mall': 'Shopping Mall',
      'department_store': 'Department Store',
      'park': 'Park',
      'campground': 'Campground',
      'hiking_area': 'Hiking Area',
      'national_park': 'National Park',
      'stadium': 'Stadium',
      'gym': 'Gym',
      'sports_complex': 'Sports Complex',
      'sports_club': 'Sports Club',
      'natural_feature': 'Natural Feature',
    };
    return typeMap[placeType] ?? placeType;
  }

  /// Find interesting POIs near user's location for route generation
  /// Returns best POI to use as a waypoint for the race
  Future<PlaceResult?> findBestPOIForRoute({
    required double userLat,
    required double userLng,
    required double raceDistanceKm,
  }) async {
    try {
      log('🔍 Finding best POI for ${raceDistanceKm}km race near ($userLat, $userLng)');

      // Search radius should be approximately half the race distance
      // so POI can be used as a midpoint
      final searchRadiusMeters = (raceDistanceKm * 1000) / 2;

      // Get all interesting place types
      final allPlaceTypes = [
        'tourist_attraction',
        'park',
        'shopping_mall',
        'stadium',
        'museum',
        'landmark',
        'natural_feature',
      ];

      final places = await searchNearbyPlaces(
        latitude: userLat,
        longitude: userLng,
        placeTypes: allPlaceTypes,
        radius: searchRadiusMeters,
        maxResults: 10,
      );

      if (places.isEmpty) {
        log('⚠️ No POIs found within radius');
        return null;
      }

      // Sort by distance to get the most suitable POI
      places.sort((a, b) {
        final distA = _calculateDistance(userLat, userLng, a.latitude, a.longitude);
        final distB = _calculateDistance(userLat, userLng, b.latitude, b.longitude);
        return distA.compareTo(distB);
      });

      // Return the best POI (closest to half race distance)
      final targetDistance = raceDistanceKm / 2;
      PlaceResult? bestPOI;
      double bestDifference = double.infinity;

      for (var place in places) {
        final distance = _calculateDistance(userLat, userLng, place.latitude, place.longitude);
        final difference = (distance - targetDistance).abs();

        if (difference < bestDifference) {
          bestDifference = difference;
          bestPOI = place;
        }
      }

      if (bestPOI != null) {
        log('✅ Found best POI: ${bestPOI.displayName}');
      }

      return bestPOI;
    } catch (e) {
      log('❌ Error finding best POI: $e');
      return null;
    }
  }

  /// Calculate distance between two coordinates in kilometers
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth radius in kilometers

    final lat1Rad = lat1 * 3.14159265359 / 180;
    final lat2Rad = lat2 * 3.14159265359 / 180;
    final dLat = (lat2 - lat1) * 3.14159265359 / 180;
    final dLon = (lon2 - lon1) * 3.14159265359 / 180;

    final a = (dLat / 2).abs() * (dLat / 2).abs() +
        lat1Rad.abs() * lat2Rad.abs() *
        (dLon / 2).abs() * (dLon / 2).abs();

    final c = 2 * (a.abs()).clamp(0.0, 1.0);

    return earthRadius * c;
  }
}
