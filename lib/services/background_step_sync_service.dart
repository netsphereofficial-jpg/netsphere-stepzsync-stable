import 'dart:async';
import 'dart:io';
import 'dart:developer' as dev;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:location/location.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'health_sync_service.dart';
import 'step_tracking_service.dart';
import 'preferences_service.dart';
import 'permission_service.dart';

/// Aggressive Background Step Sync Service
///
/// Keeps app alive in background using location tracking
/// Syncs steps every 1 minute regardless of device state
/// Uses foreground service (Android) and background location (iOS)
class BackgroundStepSyncService extends GetxService {
  // Sync Configuration
  static const Duration SYNC_INTERVAL = Duration(minutes: 1); // Aggressive: 1 minute
  static const int FOREGROUND_NOTIFICATION_ID = 9999;
  static const String NOTIFICATION_CHANNEL_ID = 'background_step_sync';
  static const String NOTIFICATION_CHANNEL_NAME = 'Background Step Sync';

  // Services
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final Location _location = Location();
  final PreferencesService _prefsService = PreferencesService();

  // State
  final RxBool isRunning = false.obs;
  final RxString lastSyncTime = ''.obs;
  final RxInt syncCount = 0.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  // Background tracking
  Timer? _syncTimer;
  StreamSubscription<LocationData>? _locationSubscription;
  bool _isInitialized = false;

  @override
  void onInit() {
    super.onInit();
    dev.log('🔄 [BG_SYNC] BackgroundStepSyncService initialized');
  }

  /// Initialize the background sync service
  Future<void> initialize() async {
    if (_isInitialized) {
      dev.log('⚠️ [BG_SYNC] Already initialized');
      return;
    }

    try {
      dev.log('🚀 [BG_SYNC] Initializing background sync service...');

      // Initialize notifications
      await _initializeNotifications();

      // Check if background sync is enabled in preferences
      final isEnabled = await _prefsService.getBackgroundSyncEnabled();
      if (isEnabled) {
        dev.log('✅ [BG_SYNC] Background sync is enabled in preferences');

        // Only start if permissions are already granted
        final hasPermissions = await PermissionService.hasBackgroundLocationPermission();
        if (hasPermissions) {
          dev.log('✅ [BG_SYNC] Permissions already granted, starting...');
          await startBackgroundSync();
        } else {
          dev.log('⚠️ [BG_SYNC] Permissions not granted yet - waiting for user');
          dev.log('💡 [BG_SYNC] User should enable in Settings');
        }
      } else {
        dev.log('ℹ️ [BG_SYNC] Background sync is disabled in settings');
      }

      _isInitialized = true;
      dev.log('✅ [BG_SYNC] Initialization complete');
    } catch (e) {
      dev.log('❌ [BG_SYNC] Initialization error: $e');
    }
  }

  /// Start aggressive background sync
  Future<bool> startBackgroundSync() async {
    dev.log('🔵 [BG_SYNC] startBackgroundSync() called, isRunning: ${isRunning.value}');

    if (isRunning.value) {
      dev.log('⚠️ [BG_SYNC] Already running, returning true');
      return true;
    }

    try {
      dev.log('🚀 [BG_SYNC] Starting aggressive background sync...');

      // 1. Check and request permissions
      dev.log('🔐 [BG_SYNC] About to check and request permissions...');
      final hasPermissions = await _checkAndRequestPermissions();
      dev.log('🔐 [BG_SYNC] Permission check result: $hasPermissions');

      if (!hasPermissions) {
        dev.log('❌ [BG_SYNC] Permissions not granted - background sync cannot start');
        dev.log('💡 [BG_SYNC] User must manually enable:');
        dev.log('💡 [BG_SYNC] Settings → Apps → StepzSync → Permissions → Location → Allow all the time');
        dev.log('💡 [BG_SYNC] Settings → Apps → StepzSync → Battery → Unrestricted');
        hasError.value = true;
        errorMessage.value = 'Background location permission required.\nPlease enable "Allow all the time" in Settings';
        // Do NOT set background sync enabled to false - let user retry
        return false;
      }

      dev.log('✅ [BG_SYNC] Permissions granted, continuing with setup...');

      // 2. Enable wake lock (keeps device awake)
      if (Platform.isAndroid) {
        await WakelockPlus.enable();
        dev.log('✅ [BG_SYNC] Wake lock enabled');
      }

      // 3. Start location tracking (keeps app alive)
      await _startLocationTracking();

      // 4. Start sync timer (every 1 minute)
      _startSyncTimer();

      // 5. Start foreground service notification (Android)
      if (Platform.isAndroid) {
        await _startForegroundService();
      }

      // 6. Update state
      isRunning.value = true;
      hasError.value = false;
      errorMessage.value = '';
      await _prefsService.setBackgroundSyncEnabled(true);

      dev.log('✅ [BG_SYNC] Background sync started successfully');
      dev.log('📊 [BG_SYNC] Sync interval: ${SYNC_INTERVAL.inMinutes} minute(s)');

      // Perform initial sync immediately
      await _performSync();

      return true;
    } catch (e, stackTrace) {
      dev.log('❌ [BG_SYNC] Start error: $e');
      dev.log('📍 [BG_SYNC] Stack trace: $stackTrace');
      hasError.value = true;
      errorMessage.value = e.toString();
      return false;
    }
  }

  /// Stop background sync
  Future<void> stopBackgroundSync() async {
    if (!isRunning.value) {
      dev.log('⚠️ [BG_SYNC] Not running');
      return;
    }

    try {
      dev.log('🛑 [BG_SYNC] Stopping background sync...');

      // 1. Cancel sync timer
      _syncTimer?.cancel();
      _syncTimer = null;

      // 2. Stop location tracking
      await _locationSubscription?.cancel();
      _locationSubscription = null;

      // 3. Disable wake lock
      if (Platform.isAndroid) {
        await WakelockPlus.disable();
        dev.log('✅ [BG_SYNC] Wake lock disabled');
      }

      // 4. Cancel foreground notification
      if (Platform.isAndroid) {
        await _notificationsPlugin.cancel(FOREGROUND_NOTIFICATION_ID);
      }

      // 5. Update state
      isRunning.value = false;
      await _prefsService.setBackgroundSyncEnabled(false);

      dev.log('✅ [BG_SYNC] Background sync stopped');
    } catch (e) {
      dev.log('❌ [BG_SYNC] Stop error: $e');
    }
  }

  /// Perform step sync (called every 1 minute)
  Future<void> _performSync() async {
    if (!isRunning.value) return;

    try {
      dev.log('🔄 [BG_SYNC] Starting sync #${syncCount.value + 1}...');
      final startTime = DateTime.now();

      // Get services
      final healthSyncService = Get.isRegistered<HealthSyncService>()
          ? Get.find<HealthSyncService>()
          : null;
      final stepTrackingService = Get.isRegistered<StepTrackingService>()
          ? Get.find<StepTrackingService>()
          : null;

      if (healthSyncService == null || stepTrackingService == null) {
        dev.log('⚠️ [BG_SYNC] Services not available yet');
        return;
      }

      // Sync HealthKit/Health Connect
      final healthResult = await healthSyncService.syncHealthData(forceSync: true);
      if (healthResult.isSuccess) {
        dev.log('✅ [BG_SYNC] HealthKit sync completed: ${healthResult.data?.todaySteps ?? 0} steps');
      } else {
        dev.log('⚠️ [BG_SYNC] HealthKit sync failed: ${healthResult.errorMessage}');
      }

      // Sync Pedometer
      await stepTrackingService.syncToFirebase();
      dev.log('✅ [BG_SYNC] Pedometer sync completed');

      // Update stats
      syncCount.value++;
      lastSyncTime.value = _formatTime(DateTime.now());
      hasError.value = false;

      final duration = DateTime.now().difference(startTime);
      dev.log('✅ [BG_SYNC] Sync #${syncCount.value} completed in ${duration.inMilliseconds}ms');

      // Update foreground notification
      if (Platform.isAndroid && isRunning.value) {
        await _updateForegroundNotification();
      }
    } catch (e, stackTrace) {
      dev.log('❌ [BG_SYNC] Sync error: $e');
      dev.log('📍 [BG_SYNC] Stack trace: $stackTrace');
      hasError.value = true;
      errorMessage.value = e.toString();
    }
  }

  /// Start background location tracking (keeps app alive)
  Future<void> _startLocationTracking() async {
    try {
      dev.log('📍 [BG_SYNC] Starting location tracking...');

      // Configure location settings (low accuracy = less battery)
      await _location.changeSettings(
        accuracy: LocationAccuracy.low, // Low accuracy saves battery
        interval: 60000, // Update every 1 minute (matches sync interval)
        distanceFilter: 100, // Update every 100 meters (not critical)
      );

      // Enable background mode
      await _location.enableBackgroundMode(enable: true);

      // Start listening (THIS KEEPS APP ALIVE IN BACKGROUND)
      _locationSubscription = _location.onLocationChanged.listen(
        (LocationData locationData) {
          // We don't actually need the location data
          // The listener just keeps the app alive in background
          dev.log('📍 [BG_SYNC] Location update received (app still alive)');
        },
        onError: (error) {
          dev.log('❌ [BG_SYNC] Location error: $error');
        },
      );

      dev.log('✅ [BG_SYNC] Location tracking started');
    } catch (e) {
      dev.log('❌ [BG_SYNC] Location tracking error: $e');
      rethrow;
    }
  }

  /// Start sync timer (every 1 minute)
  void _startSyncTimer() {
    _syncTimer?.cancel();

    _syncTimer = Timer.periodic(SYNC_INTERVAL, (timer) async {
      dev.log('⏰ [BG_SYNC] Sync timer triggered');
      await _performSync();
    });

    dev.log('✅ [BG_SYNC] Sync timer started (${SYNC_INTERVAL.inMinutes} min interval)');
  }

  /// Check and request all necessary permissions
  Future<bool> _checkAndRequestPermissions() async {
    try {
      dev.log('🔐 [BG_SYNC] Checking permissions...');

      // Check if already granted
      dev.log('🔐 [BG_SYNC] Checking if background location is already granted...');
      final hasBackgroundLocation = await PermissionService.hasBackgroundLocationPermission();
      dev.log('🔐 [BG_SYNC] Background location permission status: $hasBackgroundLocation');

      if (hasBackgroundLocation) {
        dev.log('✅ [BG_SYNC] Background location already granted');
        return true;
      }

      // Request unrestricted background execution
      dev.log('🔐 [BG_SYNC] Requesting unrestricted background execution...');
      final granted = await PermissionService.requestUnrestrictedBackgroundExecution();
      dev.log('🔐 [BG_SYNC] Unrestricted background execution result: $granted');

      if (!granted) {
        dev.log('❌ [BG_SYNC] Background permissions denied');
        return false;
      }

      dev.log('✅ [BG_SYNC] All permissions granted');
      return true;
    } catch (e, stackTrace) {
      dev.log('❌ [BG_SYNC] Permission error: $e');
      dev.log('❌ [BG_SYNC] Stack trace: $stackTrace');
      return false;
    }
  }

  /// Initialize notifications
  Future<void> _initializeNotifications() async {
    try {
      // Android settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(initSettings);

      // Create notification channel (Android)
      if (Platform.isAndroid) {
        const androidChannel = AndroidNotificationChannel(
          NOTIFICATION_CHANNEL_ID,
          NOTIFICATION_CHANNEL_NAME,
          description: 'Keeps step tracking active in background',
          importance: Importance.low,
        );

        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(androidChannel);
      }

      dev.log('✅ [BG_SYNC] Notifications initialized');
    } catch (e) {
      dev.log('❌ [BG_SYNC] Notification init error: $e');
    }
  }

  /// Start foreground service notification (Android)
  Future<void> _startForegroundService() async {
    try {
      const androidDetails = AndroidNotificationDetails(
        NOTIFICATION_CHANNEL_ID,
        NOTIFICATION_CHANNEL_NAME,
        channelDescription: 'Keeps step tracking active in background',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true, // Can't be dismissed
        autoCancel: false,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        FOREGROUND_NOTIFICATION_ID,
        'StepzSync Background Sync',
        'Syncing steps every minute • Last sync: Just now',
        notificationDetails,
      );

      dev.log('✅ [BG_SYNC] Foreground service started');
    } catch (e) {
      dev.log('❌ [BG_SYNC] Foreground service error: $e');
    }
  }

  /// Update foreground notification with latest sync info
  Future<void> _updateForegroundNotification() async {
    try {
      const androidDetails = AndroidNotificationDetails(
        NOTIFICATION_CHANNEL_ID,
        NOTIFICATION_CHANNEL_NAME,
        channelDescription: 'Keeps step tracking active in background',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        FOREGROUND_NOTIFICATION_ID,
        'StepzSync Background Sync',
        'Syncing steps every minute • Last sync: ${lastSyncTime.value} • Total: ${syncCount.value}',
        notificationDetails,
      );
    } catch (e) {
      dev.log('❌ [BG_SYNC] Notification update error: $e');
    }
  }

  /// Format time for display
  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  @override
  void onClose() {
    stopBackgroundSync();
    super.onClose();
  }
}
