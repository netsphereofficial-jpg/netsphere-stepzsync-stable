import 'package:flutter/material.dart';

/// Location category for quick race starting points
enum LocationCategory {
  currentLocation,
  monuments,
  malls,
  parks,
  sports,
  waterside,
}

/// Extension for LocationCategory to get display information
extension LocationCategoryExtension on LocationCategory {
  String get displayName {
    switch (this) {
      case LocationCategory.currentLocation:
        return 'Current Location';
      case LocationCategory.monuments:
        return 'Monuments & Landmarks';
      case LocationCategory.malls:
        return 'Shopping Malls';
      case LocationCategory.parks:
        return 'Parks & Recreation';
      case LocationCategory.sports:
        return 'Sports Grounds';
      case LocationCategory.waterside:
        return 'Waterside';
    }
  }

  String get description {
    switch (this) {
      case LocationCategory.currentLocation:
        return 'Start from where you are';
      case LocationCategory.monuments:
        return 'Historic sites and landmarks';
      case LocationCategory.malls:
        return 'Shopping centers nearby';
      case LocationCategory.parks:
        return 'Parks and green spaces';
      case LocationCategory.sports:
        return 'Stadiums and sports venues';
      case LocationCategory.waterside:
        return 'Lakes, rivers, and beaches';
    }
  }

  IconData get icon {
    switch (this) {
      case LocationCategory.currentLocation:
        return Icons.my_location;
      case LocationCategory.monuments:
        return Icons.account_balance;
      case LocationCategory.malls:
        return Icons.shopping_bag;
      case LocationCategory.parks:
        return Icons.park;
      case LocationCategory.sports:
        return Icons.sports_soccer;
      case LocationCategory.waterside:
        return Icons.water;
    }
  }

  Color get color {
    switch (this) {
      case LocationCategory.currentLocation:
        return const Color(0xFF4285F4); // Google Blue
      case LocationCategory.monuments:
        return const Color(0xFF8E44AD); // Purple
      case LocationCategory.malls:
        return const Color(0xFFE67E22); // Orange
      case LocationCategory.parks:
        return const Color(0xFF27AE60); // Green
      case LocationCategory.sports:
        return const Color(0xFFE74C3C); // Red
      case LocationCategory.waterside:
        return const Color(0xFF3498DB); // Light Blue
    }
  }
}

/// Model for a place result from Google Places API
class PlaceResult {
  final String id;
  final String displayName;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final List<String> types;

  PlaceResult({
    required this.id,
    required this.displayName,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    required this.types,
  });

  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>;
    final displayName = json['displayName'] as Map<String, dynamic>?;

    return PlaceResult(
      id: json['id'] as String? ?? '',
      displayName: displayName?['text'] as String? ?? 'Unknown Place',
      formattedAddress: json['formattedAddress'] as String? ?? '',
      latitude: (location['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (location['longitude'] as num?)?.toDouble() ?? 0.0,
      types: (json['types'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  /// Parse from legacy Places API response
  factory PlaceResult.fromLegacyJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;

    return PlaceResult(
      id: json['place_id'] as String? ?? '',
      displayName: json['name'] as String? ?? 'Unknown Place',
      formattedAddress: json['vicinity'] as String? ?? '',
      latitude: (location?['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (location?['lng'] as num?)?.toDouble() ?? 0.0,
      types: (json['types'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': {'text': displayName},
      'formattedAddress': formattedAddress,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'types': types,
    };
  }

  /// Get primary type for display
  String get primaryType {
    if (types.isEmpty) return 'Place';
    return types.first;
  }

  @override
  String toString() {
    return 'PlaceResult(name: $displayName, address: $formattedAddress)';
  }
}

/// Model for selected start location in quick race
class QuickRaceStartLocation {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final LocationCategory category;

  QuickRaceStartLocation({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.category,
  });

  factory QuickRaceStartLocation.fromCurrentLocation({
    required String address,
    required double latitude,
    required double longitude,
  }) {
    return QuickRaceStartLocation(
      name: 'Current Location',
      address: address,
      latitude: latitude,
      longitude: longitude,
      category: LocationCategory.currentLocation,
    );
  }

  factory QuickRaceStartLocation.fromPlaceResult({
    required PlaceResult place,
    required LocationCategory category,
  }) {
    return QuickRaceStartLocation(
      name: place.displayName,
      address: place.formattedAddress,
      latitude: place.latitude,
      longitude: place.longitude,
      category: category,
    );
  }

  bool get isCurrentLocation => category == LocationCategory.currentLocation;

  @override
  String toString() {
    return 'QuickRaceStartLocation(name: $name, category: ${category.displayName})';
  }
}
