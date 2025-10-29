import 'dart:math';

/// Geohash utility for location-based filtering and radius queries
///
/// Geohash is a geocoding system that encodes latitude/longitude into a short string.
/// Characters in the geohash string represent progressively smaller areas:
/// - 1 char: ±2,500 km
/// - 2 char: ±630 km
/// - 3 char: ±78 km
/// - 4 char: ±20 km
/// - 5 char: ±2.4 km (city-level precision)
/// - 6 char: ±0.61 km
/// - 7 char: ±0.076 km
class GeohashUtils {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Generate a geohash from latitude and longitude
  ///
  /// [lat] - Latitude (-90 to 90)
  /// [lon] - Longitude (-180 to 180)
  /// [precision] - Number of characters in the geohash (default: 5 for city-level)
  ///
  /// Returns a geohash string (e.g., "9q8yy" for San Francisco)
  static String encode(double lat, double lon, {int precision = 5}) {
    if (lat < -90 || lat > 90) {
      throw ArgumentError('Latitude must be between -90 and 90');
    }
    if (lon < -180 || lon > 180) {
      throw ArgumentError('Longitude must be between -180 and 180');
    }

    final List<int> bits = [];
    double latMin = -90.0, latMax = 90.0;
    double lonMin = -180.0, lonMax = 180.0;
    bool isEven = true;

    final int maxBits = precision * 5;

    while (bits.length < maxBits) {
      if (isEven) {
        // Process longitude
        final double mid = (lonMin + lonMax) / 2;
        if (lon > mid) {
          bits.add(1);
          lonMin = mid;
        } else {
          bits.add(0);
          lonMax = mid;
        }
      } else {
        // Process latitude
        final double mid = (latMin + latMax) / 2;
        if (lat > mid) {
          bits.add(1);
          latMin = mid;
        } else {
          bits.add(0);
          latMax = mid;
        }
      }
      isEven = !isEven;
    }

    // Convert bits to geohash string
    final StringBuffer geohash = StringBuffer();
    for (int i = 0; i < bits.length; i += 5) {
      int value = 0;
      for (int j = 0; j < 5 && i + j < bits.length; j++) {
        value = (value << 1) | bits[i + j];
      }
      geohash.write(_base32[value]);
    }

    return geohash.toString();
  }

  /// Decode a geohash into latitude and longitude
  ///
  /// Returns a map with 'lat' and 'lon' keys
  static Map<String, double> decode(String geohash) {
    final List<int> bits = [];

    // Convert geohash string to bits
    for (int i = 0; i < geohash.length; i++) {
      final int value = _base32.indexOf(geohash[i].toLowerCase());
      if (value == -1) {
        throw ArgumentError('Invalid geohash character: ${geohash[i]}');
      }

      for (int j = 4; j >= 0; j--) {
        bits.add((value >> j) & 1);
      }
    }

    double latMin = -90.0, latMax = 90.0;
    double lonMin = -180.0, lonMax = 180.0;
    bool isEven = true;

    for (final int bit in bits) {
      if (isEven) {
        // Process longitude
        final double mid = (lonMin + lonMax) / 2;
        if (bit == 1) {
          lonMin = mid;
        } else {
          lonMax = mid;
        }
      } else {
        // Process latitude
        final double mid = (latMin + latMax) / 2;
        if (bit == 1) {
          latMin = mid;
        } else {
          latMax = mid;
        }
      }
      isEven = !isEven;
    }

    return {
      'lat': (latMin + latMax) / 2,
      'lon': (lonMin + lonMax) / 2,
    };
  }

  /// Get all neighboring geohashes for radius queries
  ///
  /// Returns a list of geohashes including the center and all 8 neighbors.
  /// This allows querying races within approximately the same area.
  ///
  /// Example:
  /// ```dart
  /// final neighbors = GeohashUtils.getNeighbors('9q8yy');
  /// // Use in Firestore: .where('geohash', 'in', neighbors)
  /// ```
  static List<String> getNeighbors(String geohash) {
    final List<String> neighbors = [geohash];

    try {
      neighbors.add(getNeighbor(geohash, 'top'));
      neighbors.add(getNeighbor(geohash, 'bottom'));
      neighbors.add(getNeighbor(geohash, 'left'));
      neighbors.add(getNeighbor(geohash, 'right'));
      neighbors.add(getNeighbor(geohash, 'topleft'));
      neighbors.add(getNeighbor(geohash, 'topright'));
      neighbors.add(getNeighbor(geohash, 'bottomleft'));
      neighbors.add(getNeighbor(geohash, 'bottomright'));
    } catch (e) {
      // If error getting neighbors, return just center
      print('⚠️ Error getting geohash neighbors: $e');
    }

    return neighbors;
  }

  /// Get a specific neighbor of a geohash
  ///
  /// [direction] can be: 'top', 'bottom', 'left', 'right',
  ///                     'topleft', 'topright', 'bottomleft', 'bottomright'
  static String getNeighbor(String geohash, String direction) {
    final Map<String, double> center = decode(geohash);
    final double lat = center['lat']!;
    final double lon = center['lon']!;

    // Estimate the cell size based on geohash length
    final double cellSize = _getCellSize(geohash.length);

    double newLat = lat;
    double newLon = lon;

    switch (direction.toLowerCase()) {
      case 'top':
        newLat += cellSize;
        break;
      case 'bottom':
        newLat -= cellSize;
        break;
      case 'left':
        newLon -= cellSize;
        break;
      case 'right':
        newLon += cellSize;
        break;
      case 'topleft':
        newLat += cellSize;
        newLon -= cellSize;
        break;
      case 'topright':
        newLat += cellSize;
        newLon += cellSize;
        break;
      case 'bottomleft':
        newLat -= cellSize;
        newLon -= cellSize;
        break;
      case 'bottomright':
        newLat -= cellSize;
        newLon += cellSize;
        break;
      default:
        throw ArgumentError('Invalid direction: $direction');
    }

    // Clamp to valid ranges
    newLat = newLat.clamp(-90.0, 90.0);
    newLon = newLon.clamp(-180.0, 180.0);

    return encode(newLat, newLon, precision: geohash.length);
  }

  /// Calculate approximate distance between two coordinates (Haversine formula)
  ///
  /// Returns distance in kilometers
  static double distance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371.0; // km

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Check if two coordinates are within a certain radius
  ///
  /// [radiusKm] - Radius in kilometers
  static bool isWithinRadius(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
    double radiusKm,
  ) {
    return distance(lat1, lon1, lat2, lon2) <= radiusKm;
  }

  /// Get recommended geohash precision for a given radius
  ///
  /// Returns the number of characters for the geohash
  static int getPrecisionForRadius(double radiusKm) {
    if (radiusKm >= 2500) return 1;
    if (radiusKm >= 630) return 2;
    if (radiusKm >= 78) return 3;
    if (radiusKm >= 20) return 4;
    if (radiusKm >= 2.4) return 5;
    if (radiusKm >= 0.61) return 6;
    return 7;
  }

  // Private helper methods

  static double _toRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  static double _getCellSize(int precision) {
    // Approximate cell sizes for different precision levels
    const List<double> cellSizes = [
      2500.0,  // 1 char
      630.0,   // 2 char
      78.0,    // 3 char
      20.0,    // 4 char
      2.4,     // 5 char
      0.61,    // 6 char
      0.076,   // 7 char
      0.019,   // 8 char
    ];

    return precision > 0 && precision <= cellSizes.length
        ? cellSizes[precision - 1]
        : 2.4; // Default to city-level
  }
}

/// Extension methods for easier geohash operations
extension GeohashCoordinates on Map<String, double> {
  /// Convert lat/lon map to geohash
  String toGeohash({int precision = 5}) {
    final double? lat = this['lat'] ?? this['latitude'];
    final double? lon = this['lon'] ?? this['longitude'];

    if (lat == null || lon == null) {
      throw ArgumentError('Map must contain lat/lon or latitude/longitude keys');
    }

    return GeohashUtils.encode(lat, lon, precision: precision);
  }
}
