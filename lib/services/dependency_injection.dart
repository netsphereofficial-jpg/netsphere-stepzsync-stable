import 'package:get/get.dart';
import 'preferences_service.dart';
import 'firebase_service.dart';
import 'firebase_subscription_service.dart';
import 'background_service.dart';
import 'pending_requests_service.dart';
import 'step_tracking_service.dart';
import 'pedometer_service.dart';
import 'pedometer_permission_monitor.dart';
import 'health_sync_service.dart';
import 'health_sync_coordinator.dart';
import 'race_step_reconciliation_service.dart';
import 'database_controller.dart';
import 'race_bot_service.dart';
import 'cache_service.dart';
import 'race_step_sync_service.dart';
import '../screens/home/homepage_screen/controllers/homepage_data_service.dart';

class DependencyInjection {
  static void setup() {
    // Register Firebase service as immediate singleton
    // Firebase is already initialized at this point
    Get.put<FirebaseService>(FirebaseService(), permanent: true);

    // ✅ Register CacheService for non-critical data caching (performance optimization)
    // SAFE: Never caches real-time race data, only browsing/viewing data
    Get.put<CacheService>(CacheService(), permanent: true);

    // Register Firebase Subscription service as lazy singleton
    // Only initialize when user logs in and reaches home
    Get.lazyPut<FirebaseSubscriptionService>(() =>
        FirebaseSubscriptionService(), fenix: true);

    // Register RaceBotService as lazy permanent singleton
    // This ensures bot simulations persist across navigation
    Get.lazyPut<RaceBotService>(() => RaceBotService(), fenix: true);

    // Register PreferencesService as a lazy singleton
    // This will only initialize when first accessed
    Get.lazyPut<PreferencesService>(() => PreferencesService(), fenix: true);

    // Register BackgroundService as lazy singleton
    // Only initialize when user logs in (not needed on login screen)

    // Register PendingRequestsService as lazy singleton
    // Only initialize when user logs in (not needed on login screen)
    Get.lazyPut<PendingRequestsService>(() => PendingRequestsService(),
        fenix: true);

    // Register PedometerPermissionMonitor as immediate permanent singleton
    // Starts checking permission status immediately after app startup
    // Shows blocking dialog if permission not granted (market standard)
    Get.put<PedometerPermissionMonitor>(PedometerPermissionMonitor(), permanent: true);

    // Register PedometerService as lazy permanent singleton
    // Will be initialized when StepTrackingService starts
    // Provides real-time step counting via device sensors
    Get.lazyPut<PedometerService>(() => PedometerService(), fenix: true);

    // Register HealthSyncService as lazy permanent singleton
    // Will be initialized on first access (when health sync is triggered)
    // This syncs HealthKit/Health Connect data on cold starts
    Get.lazyPut<HealthSyncService>(() => HealthSyncService(), fenix: true);

    // ✅ CRITICAL: Register HealthSyncCoordinator as IMMEDIATE permanent singleton
    // This MUST be registered BEFORE StepTrackingService to prevent step loss
    // Coordinates all health-to-race step propagation with deduplication
    // Registered immediately (not lazy) to ensure availability during cold start
    Get.put<HealthSyncCoordinator>(HealthSyncCoordinator(), permanent: true);

    // ✅ NEW ARCHITECTURE: Register RaceStepReconciliationService as IMMEDIATE permanent singleton
    // Uses Cloud Functions for server-side baseline management
    // Replaces client-side delta calculation with simple total data sync
    // Eliminates app restart bugs, day rollover bugs, and double-counting bugs
    Get.put<RaceStepReconciliationService>(RaceStepReconciliationService(), permanent: true);

    // Register StepTrackingService as lazy permanent singleton
    // Will be initialized on first access (dashboard screen)
    // This ensures race tracking persists across all navigation
    // Depends on: PedometerService, HealthSyncService, HealthSyncCoordinator
    Get.lazyPut<StepTrackingService>(() => StepTrackingService(), fenix: true);

    // Register RaceStepSyncService as lazy permanent singleton
    // ❌ DISABLED: Old client-side race step sync - now using Cloud Functions
    // The Cloud Function (syncHealthDataToRaces) handles ALL step distribution server-side
    // This eliminates baseline bugs, day rollover issues, and race conditions
    // See: lib/services/race_step_reconciliation_service.dart for new implementation
    // Get.lazyPut<RaceStepSyncService>(() => RaceStepSyncService(), fenix: true);

    // Register HomepageDataService as lazy permanent singleton
    // Will be initialized on first access (dashboard screen)
    // This prevents duplicate StepTrackingService instances during navigation
    Get.lazyPut<HomepageDataService>(() => HomepageDataService(), fenix: true);
  }
}
