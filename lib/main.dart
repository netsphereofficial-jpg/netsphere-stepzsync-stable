/*
 * STEPZSYNC DESIGN SYSTEM v2.0 - CLEAN MINIMALIST
 * ================================================
 *
 * COLOR PALETTE:
 * -------------
 * Primary Color:     #2759FF (RGB: 39, 89, 255)  - Main headings, buttons, links
 * Secondary Color:   #7788B3 (RGB: 119, 136, 179) - Subtitles, secondary text
 * Label Color:       #3F4E75 (RGB: 63, 78, 117)  - Field labels, hints
 * Field Background:  #EFF2F8 (RGB: 239, 242, 248) - Text field backgrounds
 * Background:        #FFFFFF (White)              - Screen background
 *
 * TYPOGRAPHY:
 * -----------
 * Main Heading:   Roboto Bold 34      - Screen titles
 * Subtitle:       Roboto Regular 12   - Screen descriptions
 * Field Label:    Poppins 12          - Input labels
 * Button Text:    Roboto Bold 16      - Button labels
 * Body Text:      Poppins Regular 14  - General content
 *
 * SPACING SYSTEM:
 * --------------
 * Screen Padding:     24px horizontal, 32px vertical
 * Section Spacing:    40px between major sections
 * Field Spacing:      16px between fields
 * Label-Field Gap:    8px
 * Button Height:      56px
 *
 * BORDER RADIUS:
 * -------------
 * Text Fields:    12px
 * Buttons:        12px
 * Cards:          16px
 *
 * DESIGN PRINCIPLES:
 * -----------------
 * 1. NO animations, NO gradients, NO shadows
 * 2. White background for all screens
 * 3. Clean, minimalist aesthetic
 * 4. Everything fits on one screen (no scrolling)
 * 5. Left-aligned headings and labels
 * 6. Text fields with NO borders (only background color)
 * 7. Consistent spacing throughout
 *
 * REUSABLE COMPONENTS:
 * -------------------
 * - AuthTextField:      Text input with label
 * - AuthButton:         Primary action button
 * - AuthDivider:        "or" divider for social login
 * - SocialLoginButton:  Circular logo buttons
 *
 * SCREEN STRUCTURE (Login/Signup/Forgot/OTP/Profile):
 * --------------------------------------------------
 * Scaffold (white)
 *   SafeArea
 *     Padding (24h, 32v)
 *       Column
 *         Main Heading (Roboto Bold 34, #2759FF, left)
 *         Subtitle (Roboto Regular 12, #7788B3, left)
 *         SizedBox(40)
 *         Form Fields
 *         Action Button
 *         Divider (if needed)
 *         Social Options (if needed)
 *         Bottom Link
 *
 * USAGE:
 * ------
 * Import: import 'package:stepzsync/config/design_system.dart';
 * Colors: AppDesignColors.primary, AppDesignColors.secondary, etc.
 * Styles: AppTextStyles.heading, AppTextStyles.subtitle, etc.
 * Widgets: AuthTextField(...), AuthButton(...), etc.
 */

import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:stepzsync/config/app_colors.dart';
import 'package:stepzsync/routes/app_routes.dart';
import 'package:stepzsync/services/auth_wrapper.dart';
import 'package:stepzsync/services/dependency_injection.dart';
import 'package:stepzsync/services/firebase_push_notification_service.dart';
import 'package:stepzsync/services/firebase_service.dart';
import 'package:stepzsync/services/race_state_machine.dart';
import 'package:stepzsync/services/local_notification_service.dart';
import 'package:stepzsync/services/background_step_sync_service.dart';
import 'package:stepzsync/services/race_step_sync_service.dart';
import 'package:stepzsync/services/admob_service.dart';
import 'package:stepzsync/controllers/race/race_map_controller.dart';

void main() async {
  // Initialize Sentry for crash reporting and performance monitoring
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://d68ccd6f430770ef47af850a1deeeccb@o4510167218847744.ingest.us.sentry.io/4510167221338112';
      options.tracesSampleRate = 1.0; // Capture 100% of transactions in dev
      options.environment = 'development'; // Change to 'production' for release
      options.enableAutoSessionTracking = true;
      options.attachScreenshot = true;
      options.attachViewHierarchy = true;

      // Performance monitoring
      options.enableAutoPerformanceTracing = true;
      options.profilesSampleRate = 1.0;

      // Error handling
      options.beforeSend = (event, hint) {
        // Filter out non-critical errors
        return event;
      };
    },
    appRunner: () async {
      // WidgetsFlutterBinding is initialized by SentryFlutter.init automatically

      try {
        // ✅ OPTIMIZATION: Initialize Firebase and Season Service
        // These run sequentially for now to ensure stability
        print('🚀 [STARTUP] Starting initialization...');

        final firebaseService = FirebaseService();
        await firebaseService.ensureInitialized();
        print('✅ [STARTUP] Firebase initialized');

        // Initialize AdMob for rewarded ads (non-blocking)
        if (!kIsWeb) {
          AdMobService.initialize().catchError((e) {
            print('⚠️ Failed to initialize AdMob: $e');
            return null;
          });
          // Preload first ad in background
          Future.microtask(() {
            AdMobService().loadRewardedAd();
          });
        }

        // ✅ DEFERRED: Season Service initialization moved to LeaderboardController
        // This saves ~200-500ms on startup since seasons are only needed when
        // user opens the leaderboard screen (bottom nav index 1)
        // SeasonService will auto-initialize when LeaderboardController loads

        // Setup dependency injection (fast, non-blocking)
        // StepTrackingService will request permission internally before starting pedometer
        DependencyInjection.setup();
        print('✅ [STARTUP] Dependency injection configured');

        // ✅ DEFERRED: Race monitoring will start after home screen loads
        // This is moved to HomeController to avoid blocking app startup
        // RaceStateMachine.startScheduledRaceMonitoring();

        // ✅ OPTIMIZATION: Mobile-specific services (not available on web)
        // Initialize only critical services, defer non-critical ones
        if (!kIsWeb) {
          // Set up background message handler for Firebase (fast, non-blocking)
          FirebaseMessaging.onBackgroundMessage(
            FirebasePushNotificationService.handleBackgroundMessage,
          );

          // ✅ OPTIMIZATION: Initialize notification services in parallel
          // These are independent and can run concurrently
          print('🔔 [STARTUP] Initializing notification services...');

          await Future.wait([
            // Local notification service (sets up channels)
            LocalNotificationService.initialize().catchError((e) {
              print('⚠️ Failed to initialize Local Notification Service: $e');
              return null; // Don't block app startup if local notifications fail
            }),
            // Firebase push notification service (gets FCM token)
            FirebasePushNotificationService.initialize().catchError((e) {
              print('⚠️ Failed to initialize Firebase Push Notification Service: $e');
              return null; // Don't block app startup if FCM fails
            }),
          ]);

          print('✅ [STARTUP] Notification services initialized');

          // ✅ OPTIMIZATION: Preload common race marker icons in background (non-blocking)
          // This prevents 180ms icon generation delay when opening race map
          // Runs asynchronously, doesn't block app startup
          Future.microtask(() {
            MarkerIconPreloader.preloadCommonRankIcons();
          });

          // ✅ DEFERRED: Background services will initialize lazily when needed
          // These services are not needed until user enables them or joins a race
          // Moving them to lazy initialization saves 2-4 seconds on startup

          // Background Step Sync Service → Initialized when user enables in settings
          // Race Step Sync Service → Initialized when user joins/creates a race
          // Both are now lazy-loaded via dependency injection

          print('🚀 [STARTUP] Mobile services initialization complete');
        }

        // Enable Firebase Performance Monitoring
        FirebasePerformance.instance.setPerformanceCollectionEnabled(true);

        print('✅ [STARTUP] All initialization complete - launching app');
        runApp(MyApp());
      } catch (e, stackTrace) {
        print('❌ [STARTUP] Critical error during initialization: $e');
        print('📍 [STARTUP] Stack trace: $stackTrace');
        // Rethrow to let Sentry capture it
        rethrow;
      }
    },
  );
}

/*
 * RACE DATABASE STRUCTURE & STATUS MANAGEMENT
 * ==========================================
 *
 * When a race is created, the following database structure is generated:
 *
 * 1. MAIN RACE DOCUMENT: races/{raceId}
 * {
 *   "title": "Race Name",
 *   "statusId": 0,                    // Race status (see status meanings below)
 *   "raceDeadline": null,             // Deadline for race completion
 *   "actualStartTime": null,          // When race actually started
 *   "actualEndTime": null,            // When race actually ended
 *   "createdAt": "timestamp",
 *   "updatedAt": "timestamp",
 *   "currentParticipants": 1,         // Current joined participants
 *   "totalParticipants": 10,          // Maximum allowed participants
 *   "isCompleted": false,
 *   "createdBy": "userId",
 *   "startAddress": "...",
 *   "endAddress": "...",
 *   "totalDistance": 2.5,
 *   // ... all other race fields
 * }
 *
 * 2. RACE PARTICIPANTS: race_participants/{raceId}/participants/{userId}
 * {
 *   "userId": "creator_id",
 *   "raceId": "race_id",
 *   "status": "joined",               // Participant status
 *   "steps": 0,                       // Real-time step tracking
 *   "distance": 0.0,                  // Distance covered
 *   "calories": 0,                    // Calories burned
 *   "avgSpeed": 0.0,                  // Average speed
 *   "rank": 1,                        // Current rank
 *   "isCompleted": false,
 *   "joinedAt": "timestamp"
 * }
 *
 * 3. USER RACES: user_races/{userId}/races/{raceId}
 * {
 *   "userId": "creator_id",
 *   "raceId": "race_id",
 *   "role": "creator",                // creator | participant
 *   "status": "joined",               // joined | left | completed
 *   "joinedAt": "timestamp"
 * }
 *
 *
 * RACE STATUS IDs & MEANINGS:
 * ===========================
 * 0 = CREATED      - Race created, organizer can start race
 * 1 = READY        - Race ready to start (organizer can start race)
 * 2 = COUNTDOWN    - 10-second countdown before race starts
 * 3 = ACTIVE       - Race is currently running
 * 4 = COMPLETED    - Race finished
 * 5 = LOADING      - Loading/Progress state
 * 6 = DEADLINE     - Race with active deadline timer
 * 7 = CANCELLED    - Race cancelled
 *
 * RACE LIFECYCLE (SIMPLIFIED - NO COUNTDOWN):
 * ==========================================
 * 1. Creation     -> statusId: 0/1 (created/ready) - organizer can start immediately
 * 2. Start        -> statusId: 3 (active) - organizer clicks start, race begins immediately
 * 3. Completion   -> statusId: 4 (completed) - race ends
 *
 * UI BEHAVIOR BY STATUS:
 * =====================
 * Status 0/1: Show "Start Race" button (organizer) / "Waiting for organizer" (participants)
 * Status 2: (SKIPPED) - No countdown, goes directly to status 3
 * Status 3/6: Show real-time race stats and participant tracking
 * Status 4: Show "Race completed. Check winner list" button
 * Status 5: Show loading indicator
 *
 * STATUS CHANGE METHODS (FirebaseService):
 * =======================================
 * - updateRaceStatus(raceId, statusId)     - Change race status
 * - setRaceDeadline(raceId, deadline)      - Set deadline (status -> 6)
 * - startRace(raceId)                      - Start race (status -> 3)
 * - finishRace(raceId)                     - Finish race (status -> 4)
 * - startRaceCountdown(raceId)             - Begin countdown (status -> 2)
 * - getRaceStatusStream(raceId)            - Real-time status monitoring
 *
 * CREATOR AUTO-JOIN:
 * ==================
 * When a race is created, the creator is automatically:
 * - Added to race_participants with role="creator" and status="joined"
 * - Added to user_races with role="creator"
 * - Initialized with default progress values (steps=0, distance=0, etc.)
 */

/*
 * SUBSCRIPTION SYSTEM & FEATURE MANAGEMENT
 * ========================================
 *
 * The app implements a 3-tier subscription model with feature gating:
 *
 * SUBSCRIPTION TIERS:
 * ==================
 * 🆓 FREE PLAN (City Access):
 * - City-only races, Join up to 3 races, Create up to 2 races
 * - Basic statistics, BPM tracking, Basic breathing mode
 * - Basic 1-on-1 chat (no history), Basic race invites
 * - ❌ No marathons, leaderboards, or Hall of Fame
 *
 * ⭐ PREMIUM 1 (Country Access) - $9.99/month:
 * - City + Country races, Join up to 7 races, Create up to 7 races
 * - Local/Country marathons, Advanced statistics + filters
 * - Heart-rate zones + recovery insights, Full breathing pack
 * - Local/Country leaderboards, Country-level race invites
 * - ❌ No Hall of Fame or global features
 *
 * 🏆 PREMIUM 2 (World/Elite Access) - $19.99/month:
 * - Global races worldwide, Join/Create up to 20 races
 * - International marathons, Advanced global statistics
 * - Elite breathing pack + custom rhythms, Advanced chat
 * - Global/regional/age-group leaderboards, Hall of Fame
 * - Exclusive global invites + team battles
 *
 * FEATURE MANAGEMENT IMPLEMENTATION:
 * ====s==============================
 *
 * 1. CENTRALIZED FEATURE GATING:
 * - Use FeatureService.canAccessFeature(FeatureType) before showing features
 * - Check FeatureService.getFeatureLimit(FeatureType) for numeric limits
 * - Example: if (!FeatureService.canAccessFeature(FeatureType.globalRaces)) { showUpgradePrompt(); }
 *
 * 2. UI-LEVEL CONTROLS:
 * - Conditional widget rendering based on subscription tier
 * - Feature locked overlays for premium-only content
 * - Smart upgrade prompts when limits are reached
 * - Example: Stack([AdvancedStatsWidget(), if(!hasPremium) FeatureLockedOverlay()])
 *
 * 3. API-LEVEL VALIDATION:
 * - Server-side subscription verification for all API calls
 * - Prevent feature abuse from modified client apps
 * - Throw SubscriptionRequiredException for blocked features
 * - Example: if (!canCreateRace()) throw SubscriptionRequiredException();
 *
 * 4. CROSS-PLATFORM PAYMENT INTEGRATION:
 * - iOS: Apple In-App Purchases via StoreKit
 * - Android: Google Play Billing integration
 * - Unified payment flow with platform-specific UI
 * - Purchase validation and subscription restoration
 *
 * 5. FEATURE USAGE TRACKING:
 * - Track when users hit feature limits (analytics for conversion)
 * - Monitor which blocked features drive the most upgrades
 * - A/B test upgrade prompt messaging and placement
 *
 * IMPLEMENTATION FILES:
 * ====================
 * - lib/models/subscription_models.dart        - Subscription data models
 * - lib/services/payment_service.dart          - Cross-platform payment handling
 * - lib/controllers/subscription_controller.dart - Subscription state management
 * - lib/screens/subscription/subscription_screen.dart - Subscription UI
 * - lib/services/feature_service.dart          - Feature gating logic (TO BE CREATED)
 *
 * TESTING STRATEGY:
 * ================
 * - Mock different subscription states for comprehensive testing
 * - Test feature access across all subscription tiers
 * - Verify upgrade prompts appear at correct limits
 * - Test payment flows on both iOS and Android platforms
 */

class MyApp extends StatefulWidget {
  MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: "StepzSync",
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: AppColors.lightColorScheme,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: AppColors.lightColorScheme,
      ),
      home: AuthWrapper(),
      getPages: AppRoutes.routes,
      // builder: EasyLoading.init(),
    );
  }
}
