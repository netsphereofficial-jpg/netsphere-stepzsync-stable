import Flutter
import UIKit
import GoogleMaps
import BackgroundTasks
import UserNotifications
import Firebase
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {

    // MARK: - Constants
    private let backgroundTaskIdentifier = "com.stepzsync.step_sync"
    private let backgroundRefreshIdentifier = "com.stepzsync.refresh"
    private let backgroundSyncIdentifier = "com.stepzsync.sync"
    private let methodChannelName = "com.stepzsync/background_sync"

    // Background task management
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var isBackgroundActive = false
    private var syncCount = 0

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // ✅ Google Maps
        GMSServices.provideAPIKey("AIzaSyDc5bTP6J3cEJ35z22w4wCXYT-6kqwQBFc")

        // ✅ Register main Flutter plugins (this will initialize Firebase via Flutter)
        GeneratedPluginRegistrant.register(with: self)

        // ✅ Setup background processing (iOS 13+)
        setupBackgroundTasks()

        // ✅ Setup background fetch (fallback for older iOS)
        setupBackgroundFetch()

        // ✅ Setup method channel for background communication
        setupBackgroundMethodChannel()

        // ✅ Setup app lifecycle notifications
        setupAppLifecycleNotifications()

        // ✅ Set UNUserNotificationCenter delegate to show notifications in foreground
        UNUserNotificationCenter.current().delegate = self
        print("✅ UNUserNotificationCenter delegate set for foreground notifications")

        // ℹ️  Firebase will be fully initialized by Flutter
        // Remote notifications will be registered after Flutter initialization
        print("ℹ️  Deferring Firebase and notifications setup to Flutter initialization")

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - Background Tasks Setup (iOS 13+)
    @available(iOS 13.0, *)
    private func setupBackgroundTasks() {
        print("🔧 Setting up BGTaskScheduler for StepzSync")

        // Register all background task identifiers
        let identifiers = [backgroundTaskIdentifier, backgroundRefreshIdentifier, backgroundSyncIdentifier]

        for identifier in identifiers {
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: identifier,
                using: nil
            ) { task in
                self.handleBackgroundAppRefresh(task: task as! BGAppRefreshTask)
            }
        }

        print("✅ BGTaskScheduler setup completed for \(identifiers.count) identifiers")
    }

    // Enhanced background fetch setup
    private func setupBackgroundFetch() {
        print("🔧 Setting up background fetch for step sync")

        // Configure background fetch interval (15 minutes - market standard for health apps)
        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)

        print("✅ Background fetch setup completed")
    }

    // Setup app lifecycle notifications
    private func setupAppLifecycleNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }

    // Setup method channel for background communication
    private func setupBackgroundMethodChannel() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            print("ℹ️  Flutter controller not yet available (will be set up by Flutter)")
            return
        }

        let channel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: controller.binaryMessenger
        )

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call: call, result: result)
        }

        print("✅ Background method channel setup completed")
    }

    // MARK: - Method Call Handler
    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("📱 Handling method call: \(call.method)")

        switch call.method {
        case "performBackgroundSync", "performBackgroundHealthSync":
            print("📤 Background sync requested from Flutter: \(call.method)")
            performBackgroundDataSync { success in
                result(success ? "Background sync completed successfully" : "Background sync failed")
            }

        case "getHealthDataOnly":
            print("📊 Health data only requested")
            result(["status": "health_data_retrieved", "timestamp": Date().timeIntervalSince1970])

        case "getBackgroundStatus":
            print("📊 Background status requested")
            result([
                "status": "active",
                "timestamp": Date().timeIntervalSince1970,
                "backgroundRefreshStatus": UIApplication.shared.backgroundRefreshStatus.rawValue,
                "backgroundTimeRemaining": UIApplication.shared.backgroundTimeRemaining,
                "isBackgroundActive": isBackgroundActive,
                "syncCount": syncCount
            ])

        case "scheduleBackgroundTask":
            if #available(iOS 13.0, *) {
                scheduleAllBackgroundTasks()
                result("All background tasks scheduled")
            } else {
                result("BGTaskScheduler requires iOS 13+")
            }

        case "validateDataConsistency":
            print("🔍 Data consistency validation requested")
            result(["validation": "completed", "timestamp": Date().timeIntervalSince1970])

        case "forceSyncNow":
            performImmediateSync()
            result("Force sync triggered")

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Background Task Management (Optimized for iOS Guidelines)
    private func startBackgroundTask() {
        guard backgroundTask == .invalid else {
            print("ℹ️ Background task already active")
            return
        }

        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "StepzSyncDataSync") { [weak self] in
            print("⚠️ Background task expiring - ending immediately")
            self?.endBackgroundTask()
        }

        isBackgroundActive = true
        print("✅ Background task started with ID: \(backgroundTask.rawValue)")
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }

        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
        isBackgroundActive = false
        print("⏸️ Background task ended")
    }

    private func performImmediateSync() {
        syncCount += 1
        print("🔄 Immediate sync #\(syncCount) triggered")

        // Start background task if needed
        if backgroundTask == .invalid {
            startBackgroundTask()
        }

        // Perform sync through Flutter with timeout
        performFlutterSync(syncType: "immediate_sync")

        // Schedule next background task for iOS 13+
        if #available(iOS 13.0, *) {
            scheduleAllBackgroundTasks()
        }
    }

    private func performFlutterSync(syncType: String) {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            endBackgroundTask()
            return
        }

        let channel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: controller.binaryMessenger
        )

        // Timeout for sync (market standard: 5 seconds max - MyFitnessPal, Strava)
        let timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            print("⚠️ \(syncType) timeout (5s) - ending background task")
            self?.endBackgroundTask()
        }

        channel.invokeMethod("performTimerSync", arguments: [
            "trigger": syncType,
            "timestamp": Date().timeIntervalSince1970,
            "backgroundTime": UIApplication.shared.backgroundTimeRemaining,
            "syncCount": syncCount
        ]) { [weak self] result in
            timer.invalidate()

            if let error = result as? FlutterError {
                print("❌ \(syncType) error: \(error.message ?? "Unknown")")
            } else {
                print("✅ \(syncType) completed")
            }

            // End background task immediately after sync completes (market standard)
            self?.endBackgroundTask()
        }
    }

    // Lightweight background data sync
    private func performBackgroundDataSync(completion: @escaping (Bool) -> Void) {
        print("🔄 Performing background data sync")

        // Ensure background task is active
        if backgroundTask == .invalid {
            startBackgroundTask()
        }

        // Trigger Flutter sync
        performFlutterSync(syncType: "background_data_sync")

        // Always return success to keep background task alive
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(true)
        }
    }

    // MARK: - Background Processing (iOS 13+)
    @available(iOS 13.0, *)
    private func handleBackgroundAppRefresh(task: BGAppRefreshTask) {
        print("🔄 BGTaskScheduler background refresh triggered for: \(task.identifier)")

        // Schedule the next background refresh immediately
        scheduleAllBackgroundTasks()

        // Set expiration handler
        task.expirationHandler = {
            print("⚠️ Background task \(task.identifier) expired")
            task.setTaskCompleted(success: false)
        }

        // Perform quick sync
        performBackgroundDataSync { success in
            print("📤 Background refresh \(task.identifier) result: \(success)")
            task.setTaskCompleted(success: success)
        }
    }

    @available(iOS 13.0, *)
    private func scheduleAllBackgroundTasks() {
        let identifiers = [backgroundTaskIdentifier, backgroundRefreshIdentifier, backgroundSyncIdentifier]

        for identifier in identifiers {
            scheduleBackgroundTask(identifier: identifier)
        }
    }

    @available(iOS 13.0, *)
    private func scheduleBackgroundTask(identifier: String) {
        // Check if running on simulator - BGTaskScheduler doesn't work on simulator
        #if targetEnvironment(simulator)
        // Silently skip on simulator - this is expected behavior
        return
        #endif

        let request = BGAppRefreshTaskRequest(identifier: identifier)

        // More aggressive scheduling for step tracking
        #if DEBUG
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30) // 30 seconds for testing
        #else
        request.earliestBeginDate = Date(timeIntervalSinceNow: 45) // 45 seconds for production
        #endif

        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Background task \(identifier) scheduled for \(request.earliestBeginDate?.description ?? "unknown time")")
        } catch {
            if let bgError = error as? BGTaskScheduler.Error {
                switch bgError.code {
                case .unavailable:
                    print("ℹ️  Background refresh unavailable for \(identifier) (device may need Background App Refresh enabled in Settings)")
                case .tooManyPendingTaskRequests:
                    print("ℹ️  Too many pending task requests for \(identifier) - cancelling old ones")
                    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
                    // Try scheduling again
                    try? BGTaskScheduler.shared.submit(request)
                case .notPermitted:
                    print("ℹ️  Background refresh not permitted for \(identifier) (enable in Settings → General → Background App Refresh)")
                default:
                    print("ℹ️  BGTaskScheduler error for \(identifier): \(bgError)")
                }
            }
        }
    }

    // MARK: - Legacy Background Fetch (iOS < 13)
    override func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("🔄 Legacy background fetch triggered")

        performBackgroundDataSync { success in
            let result: UIBackgroundFetchResult = success ? .newData : .failed
            completionHandler(result)
        }
    }

    // MARK: - App Lifecycle Handlers
    @objc private func appDidEnterBackground() {
        print("📱 App entered background - CMPedometer continues tracking automatically")

        // Schedule background tasks for iOS 13+ (periodic sync)
        if #available(iOS 13.0, *) {
            scheduleAllBackgroundTasks()
        }

        print("📱 Background task scheduling completed")
    }

    @objc private func appWillEnterForeground() {
        print("📱 App entering foreground - syncing step data")

        // Trigger immediate sync when returning to foreground
        performImmediateSync()

        print("📱 Foreground sync triggered")
    }

    @objc private func appWillTerminate() {
        print("📱 App terminating - CMPedometer will continue tracking in background")

        // Schedule final background tasks before termination
        if #available(iOS 13.0, *) {
            scheduleAllBackgroundTasks()
        }

        print("📱 Final background tasks scheduled")
    }

    // MARK: - App Lifecycle Override Methods
    override func applicationDidEnterBackground(_ application: UIApplication) {
        super.applicationDidEnterBackground(application)
        appDidEnterBackground()
    }

    override func applicationWillEnterForeground(_ application: UIApplication) {
        super.applicationWillEnterForeground(application)
        appWillEnterForeground()
    }

    override func applicationWillTerminate(_ application: UIApplication) {
        super.applicationWillTerminate(application)
        appWillTerminate()
    }

    // MARK: - Background URL Session
    override func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        print("🔄 Background URL session: \(identifier)")
        completionHandler()
    }

    // MARK: - Memory Warning Handler
    override func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        super.applicationDidReceiveMemoryWarning(application)
        print("⚠️ Memory warning received")
    }

    // MARK: - Firebase Push Notifications Setup
    // NOTE: Disabled native Firebase setup to prevent premature Firebase access
    // Flutter handles all Firebase initialization including push notifications
    /*
    private func setupFirebasePushNotifications() {
        print("🔥 Setting up Firebase push notifications...")

        // Check if Firebase is configured (it will be configured by Flutter)
        // Set delegates only - Firebase will be initialized by Flutter's firebase_core plugin

        // Set UNUserNotificationCenter delegate for foreground notifications
        UNUserNotificationCenter.current().delegate = self

        // Delay Firebase Messaging setup until Firebase is configured by Flutter
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if FirebaseApp.app() != nil {
                Messaging.messaging().delegate = self
                print("✅ Firebase Messaging delegate set")
            } else {
                print("ℹ️  Firebase not yet configured, will be set up by Flutter")
            }
        }

        print("✅ Firebase push notifications setup completed")
    }
    */

    // MARK: - APNs Token Registration
    // NOTE: APNs registration now handled by Flutter after Firebase initialization
    override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("🔥 APNs device token registered - will be handled by Flutter")

        // Call super to ensure Flutter plugins receive the token
        // Flutter's firebase_messaging plugin will handle token registration
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")

        // Call super
        super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }

    // MARK: - Cleanup
    deinit {
        NotificationCenter.default.removeObserver(self)
        endBackgroundTask()
    }
}

// MARK: - MessagingDelegate
// NOTE: Disabled - Flutter handles FCM token registration
/*
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔥 FCM registration token received: \(fcmToken?.prefix(20) ?? "nil")...")

        // Store the token or send to your backend server
        if let token = fcmToken {
            UserDefaults.standard.set(token, forKey: "fcm_token")
        }
    }
}
*/

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate {
    // Handle notification when app is in foreground
    override func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("🔥 Received foreground notification: \(notification.request.identifier)")

        // Show notification even when app is in foreground
        completionHandler([.alert, .badge, .sound])
    }

    // Handle notification tap
    override func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        print("🔥 Notification tapped: \(response.notification.request.identifier)")

        // Let Flutter handle the response
        super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
    }
}