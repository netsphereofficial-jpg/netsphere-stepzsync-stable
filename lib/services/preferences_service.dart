import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _onboardingCompleteKey = 'onboarding_complete';
  static const String _permissionsGrantedKey = 'permissions_granted';
  static const String _firstLaunchKey = 'first_launch';
  static const String _notificationRequestedKey = 'notification_requested';

  // Health sync preferences
  static const String _healthPermissionsGrantedKey = 'health_permissions_granted';
  static const String _healthSyncEnabledKey = 'health_sync_enabled';
  static const String _lastHealthSyncTimestampKey = 'last_health_sync_timestamp';

  // Background sync preferences
  static const String _backgroundSyncEnabledKey = 'background_sync_enabled';
  static const String _backgroundSyncIntervalKey = 'background_sync_interval';
  static const String _backgroundLocationDialogShownKey = 'background_location_dialog_shown';

  // Premium dialog tracking
  static const String _appOpenCountKey = 'app_open_count';
  static const String _premiumDialogShownCountKey = 'premium_dialog_shown_count';

  SharedPreferences? _preferences;
  bool _isInitialized = false;

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      _preferences = await SharedPreferences.getInstance();
      _isInitialized = true;
    }
  }

  // Onboarding status
  Future<bool> get isOnboardingComplete async {
    await _ensureInitialized();
    return _preferences?.getBool(_onboardingCompleteKey) ?? false;
  }

  Future<void> setOnboardingComplete(bool value) async {
    await _ensureInitialized();
    await _preferences?.setBool(_onboardingCompleteKey, value);
  }

  // Permissions status
  Future<bool> get arePermissionsGranted async {
    await _ensureInitialized();
    return _preferences?.getBool(_permissionsGrantedKey) ?? false;
  }

  Future<void> setPermissionsGranted(bool value) async {
    await _ensureInitialized();
    await _preferences?.setBool(_permissionsGrantedKey, value);
  }

  // First launch detection
  Future<bool> get isFirstLaunch async {
    await _ensureInitialized();
    return _preferences?.getBool(_firstLaunchKey) ?? true;
  }

  Future<void> setFirstLaunch(bool value) async {
    await _ensureInitialized();
    await _preferences?.setBool(_firstLaunchKey, value);
  }

  // Notification permission request tracking
  Future<bool> hasRequestedNotificationPermission() async {
    await _ensureInitialized();
    return _preferences?.getBool(_notificationRequestedKey) ?? false;
  }

  Future<void> setHasRequestedNotificationPermission(bool value) async {
    await _ensureInitialized();
    await _preferences?.setBool(_notificationRequestedKey, value);
  }

  // Complete onboarding process
  Future<void> completeOnboarding() async {
    await setOnboardingComplete(true);
    await setFirstLaunch(false);
  }

  // Reset for testing purposes
  Future<void> resetOnboarding() async {
    await _ensureInitialized();
    await _preferences?.remove(_onboardingCompleteKey);
    await _preferences?.remove(_permissionsGrantedKey);
    await _preferences?.remove(_firstLaunchKey);
  }

  // Get onboarding status for flow decisions
  Future<OnboardingStatus> getOnboardingStatus() async {
    final firstLaunch = await isFirstLaunch;
    final onboardingComplete = await isOnboardingComplete;

    if (firstLaunch) {
      return OnboardingStatus.firstTime;
    } else if (!onboardingComplete) {
      return OnboardingStatus.permissionsPending;
    } else {
      return OnboardingStatus.completed;
    }
  }

  // ========================================
  // Health Sync Preferences
  // ========================================

  /// Check if health permissions were granted
  Future<bool> get hasHealthPermissionsGranted async {
    await _ensureInitialized();
    return _preferences?.getBool(_healthPermissionsGrantedKey) ?? false;
  }

  /// Set health permissions granted status
  Future<void> setHealthPermissionsGranted(bool value) async {
    await _ensureInitialized();
    await _preferences?.setBool(_healthPermissionsGrantedKey, value);
  }

  /// Check if health sync is enabled
  Future<bool> get isHealthSyncEnabled async {
    await _ensureInitialized();
    return _preferences?.getBool(_healthSyncEnabledKey) ?? true; // Default enabled
  }

  /// Set health sync enabled status
  Future<void> setHealthSyncEnabled(bool value) async {
    await _ensureInitialized();
    await _preferences?.setBool(_healthSyncEnabledKey, value);
  }

  /// Get last health sync timestamp (milliseconds since epoch)
  Future<int?> getLastHealthSyncTimestamp() async {
    await _ensureInitialized();
    return _preferences?.getInt(_lastHealthSyncTimestampKey);
  }

  /// Set last health sync timestamp (milliseconds since epoch)
  Future<void> setLastHealthSyncTimestamp(int timestamp) async {
    await _ensureInitialized();
    await _preferences?.setInt(_lastHealthSyncTimestampKey, timestamp);
  }

  /// Get time since last health sync
  Future<Duration?> getTimeSinceLastSync() async {
    final lastSync = await getLastHealthSyncTimestamp();
    if (lastSync == null) return null;

    final lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSync);
    final now = DateTime.now();
    return now.difference(lastSyncTime);
  }

  /// Clear all health sync data (for testing/debugging)
  Future<void> clearHealthSyncData() async {
    await _ensureInitialized();
    await _preferences?.remove(_healthPermissionsGrantedKey);
    await _preferences?.remove(_healthSyncEnabledKey);
    await _preferences?.remove(_lastHealthSyncTimestampKey);
  }

  // Background sync preferences

  /// Get background sync enabled status
  Future<bool> getBackgroundSyncEnabled() async {
    await _ensureInitialized();
    return _preferences?.getBool(_backgroundSyncEnabledKey) ?? false;
  }

  /// Set background sync enabled status
  Future<void> setBackgroundSyncEnabled(bool value) async {
    await _ensureInitialized();
    await _preferences?.setBool(_backgroundSyncEnabledKey, value);
  }

  /// Get background sync interval in minutes
  Future<int> getBackgroundSyncInterval() async {
    await _ensureInitialized();
    return _preferences?.getInt(_backgroundSyncIntervalKey) ?? 1; // Default: 1 minute
  }

  /// Set background sync interval in minutes
  Future<void> setBackgroundSyncInterval(int minutes) async {
    await _ensureInitialized();
    if (minutes < 1 || minutes > 30) {
      throw ArgumentError('Sync interval must be between 1 and 30 minutes');
    }
    await _preferences?.setInt(_backgroundSyncIntervalKey, minutes);
  }

  /// Clear background sync data
  Future<void> clearBackgroundSyncData() async {
    await _ensureInitialized();
    await _preferences?.remove(_backgroundSyncEnabledKey);
    await _preferences?.remove(_backgroundSyncIntervalKey);
  }

  // Background location dialog tracking

  /// Check if background location dialog has been shown
  Future<bool> hasShownBackgroundLocationDialog() async {
    await _ensureInitialized();
    return _preferences?.getBool(_backgroundLocationDialogShownKey) ?? false;
  }

  /// Set background location dialog as shown
  Future<void> setBackgroundLocationDialogShown(bool value) async {
    await _ensureInitialized();
    await _preferences?.setBool(_backgroundLocationDialogShownKey, value);
  }

  // ========================================
  // Premium Dialog Tracking
  // ========================================

  /// Get the total app open count
  Future<int> getAppOpenCount() async {
    await _ensureInitialized();
    return _preferences?.getInt(_appOpenCountKey) ?? 0;
  }

  /// Increment app open count (call on every app launch)
  Future<void> incrementAppOpenCount() async {
    await _ensureInitialized();
    final count = await getAppOpenCount();
    await _preferences?.setInt(_appOpenCountKey, count + 1);
  }

  /// Get premium dialog shown count
  Future<int> getPremiumDialogShownCount() async {
    await _ensureInitialized();
    return _preferences?.getInt(_premiumDialogShownCountKey) ?? 0;
  }

  /// Increment premium dialog shown count
  Future<void> incrementPremiumDialogShownCount() async {
    await _ensureInitialized();
    final count = await getPremiumDialogShownCount();
    await _preferences?.setInt(_premiumDialogShownCountKey, count + 1);
  }

  /// Check if premium dialog should be shown
  /// Shows on 1st app open, then every 3rd time after that (1st, 4th, 7th, 10th, etc.)
  /// Also checks if before expiration date (Jan 1, 2026)
  Future<bool> shouldShowPremiumDialog() async {
    final count = await getAppOpenCount();

    // Show on 1st open, or every 3rd open after that (4th, 7th, 10th, etc.)
    // Pattern: 1, 4, 7, 10, 13, 16... (count == 1 or (count - 1) % 3 == 0)
    bool shouldShow = false;

    if (count == 1) {
      // First time opening the app
      shouldShow = true;
    } else if (count > 1 && (count - 1) % 3 == 0) {
      // Every 3rd time after first (4th, 7th, 10th, etc.)
      shouldShow = true;
    }

    if (shouldShow) {
      // Check if before expiration date (Jan 1, 2026)
      final expirationDate = DateTime(2026, 1, 1);
      final now = DateTime.now();

      return now.isBefore(expirationDate);
    }

    return false;
  }

  /// Clear premium dialog tracking (for testing)
  Future<void> clearPremiumDialogTracking() async {
    await _ensureInitialized();
    await _preferences?.remove(_appOpenCountKey);
    await _preferences?.remove(_premiumDialogShownCountKey);
  }
}

enum OnboardingStatus {
  firstTime,
  permissionsPending,
  completed,
}