import 'dart:async';
import 'dart:developer';
import 'package:location/location.dart';

/// Background location service to keep app alive in background
/// This service starts location tracking when location permission is granted
/// The location icon will appear in the status bar when active
class BackgroundLocationService {
  static final BackgroundLocationService _instance = BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  final Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  bool _isTracking = false;

  /// Check if location tracking is active
  bool get isTracking => _isTracking;

  /// Start background location tracking
  /// This will show the location icon in the status bar
  Future<bool> startBackgroundTracking() async {
    try {
      if (_isTracking) {
        log('📍 [BACKGROUND_LOCATION] Already tracking, skipping');
        return true;
      }

      log('📍 [BACKGROUND_LOCATION] Starting background location tracking...');

      // Check if location service is enabled
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        log('❌ [BACKGROUND_LOCATION] Location service not enabled');
        return false;
      }

      // Check permission status
      PermissionStatus hasPermission = await _location.hasPermission();
      if (hasPermission != PermissionStatus.granted &&
          hasPermission != PermissionStatus.grantedLimited) {
        log('❌ [BACKGROUND_LOCATION] Location permission not granted');
        return false;
      }

      // Configure location settings for background tracking
      await _location.changeSettings(
        accuracy: LocationAccuracy.low, // Low accuracy to save battery
        interval: 60000, // Update every 60 seconds
        distanceFilter: 100, // Only update if moved 100 meters
      );

      // Enable background mode
      await _location.enableBackgroundMode(enable: true);

      // Start listening to location updates
      _locationSubscription = _location.onLocationChanged.listen(
        (LocationData location) {
          // Just receive location updates to keep app alive
          // We don't need to do anything with the location data
          log('📍 [BACKGROUND_LOCATION] Location update received (keeps app alive)');
        },
        onError: (error) {
          log('❌ [BACKGROUND_LOCATION] Error: $error');
        },
      );

      _isTracking = true;
      log('✅ [BACKGROUND_LOCATION] Background tracking started - location icon should appear');
      return true;
    } catch (e) {
      log('❌ [BACKGROUND_LOCATION] Failed to start tracking: $e');
      return false;
    }
  }

  /// Stop background location tracking
  /// This will remove the location icon from the status bar
  Future<void> stopBackgroundTracking() async {
    try {
      if (!_isTracking) {
        log('📍 [BACKGROUND_LOCATION] Not tracking, skipping stop');
        return;
      }

      log('📍 [BACKGROUND_LOCATION] Stopping background location tracking...');

      await _locationSubscription?.cancel();
      _locationSubscription = null;

      await _location.enableBackgroundMode(enable: false);

      _isTracking = false;
      log('✅ [BACKGROUND_LOCATION] Background tracking stopped');
    } catch (e) {
      log('❌ [BACKGROUND_LOCATION] Failed to stop tracking: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopBackgroundTracking();
  }
}
