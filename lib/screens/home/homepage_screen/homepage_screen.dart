import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../controllers/notification_controller.dart';
import '../../../services/step_tracking_service.dart';
import 'controllers/homepage_animation_controller.dart';
import 'controllers/homepage_data_service.dart';
import 'widgets/homepage_header_widget.dart';
import 'widgets/overall_stats_card_widget.dart';
import 'widgets/statistics_card_widget.dart';
import 'widgets/flippable_statistics_card.dart';
import 'widgets/action_buttons_grid_widget.dart';

class HomepageScreen extends StatefulWidget {
  const HomepageScreen({super.key});

  @override
  State<HomepageScreen> createState() => _HomepageScreenState();
}

class _HomepageScreenState extends State<HomepageScreen> {
  // Filter state
  String selectedFilter = 'Today';
  final List<String> filters = ['Today', 'Yesterday', 'Last 7 days', 'Last 30 days', 'Last 60 days', 'Last 90 days', 'All time'];
  final RxBool isDropdownOpen = false.obs;
  OverlayEntry? _overlayEntry;

  // Step tracking
  final RxInt _animatedStepCount = 0.obs;

  // Controllers
  late HomepageAnimationController animationController;
  late HomepageDataService dataService;
  late NotificationController notificationController;

  // Notification state
  final RxBool hasUnreadNotifications = false.obs;
  Timer? _notificationRefreshTimer;

  // Listener subscriptions for proper cleanup
  final List<Worker> _listeners = [];

  // Initialization state
  bool _isInitializing = false;
  bool _isDisposed = false;

  // Flip state for dynamic layout
  bool _isCardFlipped = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeCore();
    _setupStepCountListener();
    _setupSyncListeners();
    _setupNavigationListener();
  }

  void _initializeControllers() {
    if (_isInitializing || _isDisposed) {
      print('⏭️ HomepageScreen: Skipping controller initialization (initializing: $_isInitializing, disposed: $_isDisposed)');
      return;
    }

    _isInitializing = true;
    print('🚀 HomepageScreen: Initializing controllers...');

    try {
      // Initialize controllers
      animationController = Get.put(HomepageAnimationController());

      // Use permanent singleton for HomepageDataService to prevent duplicate StepTrackingService instances
      if (Get.isRegistered<HomepageDataService>()) {
        dataService = Get.find<HomepageDataService>();
        print('✅ Found existing HomepageDataService');
      } else {
        dataService = Get.put(HomepageDataService(), permanent: true);
        print('✅ Created new HomepageDataService');
      }

      // Initialize notification controller and setup listeners
      if (Get.isRegistered<NotificationController>()) {
        notificationController = Get.find<NotificationController>();
        print('✅ Found existing NotificationController');
      } else {
        notificationController = Get.put(NotificationController());
        print('✅ Created new NotificationController');
      }

      _setupNotificationListener();
      print('✅ HomepageScreen: Controllers initialized successfully');
    } catch (e) {
      print('❌ HomepageScreen: Error initializing controllers: $e');
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  void _setupNotificationListener() {
    // Listen to notification list changes to update unread status
    // ✅ Store listener for proper disposal
    _listeners.add(
      ever(notificationController.allNotifications, (notifications) {
        if (!_isDisposed) {  // ✅ Guard against disposed state
          hasUnreadNotifications.value = notifications.any((notification) => !notification.isRead);
        }
      })
    );

    // Periodically refresh notifications to catch any real-time updates
    // ✅ Changed from 30s to 2min to reduce Firestore load
    _notificationRefreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (Get.isRegistered<NotificationController>() && !_isDisposed) {
        notificationController.getNotificationList(null);
      }
    });
  }

  Future<void> _initializeCore() async {
    if (_isDisposed) {
      print('⏭️ HomepageScreen: Skipping core initialization - widget disposed');
      return;
    }

    print('🚀 HomepageScreen: Starting core initialization...');
    try {
      // Load critical data first
      await dataService.initializeCriticalData();

      if (_isDisposed) {
        print('⏭️ HomepageScreen: Widget disposed during initialization, skipping secondary data');
        return;
      }

      // Load secondary data asynchronously
      _loadSecondaryDataAsync();
      print('✅ HomepageScreen: Core initialization complete');
    } catch (e) {
      print('❌ HomepageScreen: Error during core initialization: $e');
    }
  }

  void _loadSecondaryDataAsync() {
    if (_isDisposed) {
      print('⏭️ HomepageScreen: Skipping secondary data load - widget disposed');
      return;
    }

    dataService.initializeSecondaryData().then((_) {
      if (!_isDisposed) {
        // Notify animation controller that secondary data is loaded
        animationController.setSecondaryDataLoaded(true);
        print('✅ HomepageScreen: Secondary data loaded successfully');
      } else {
        print('⏭️ HomepageScreen: Widget disposed before secondary data could be applied');
      }
    }).catchError((e) {
      print('❌ HomepageScreen: Error loading secondary data: $e');
    });
  }

  void _setupStepCountListener() {
    // Set initial value immediately if available (use period data)
    _animatedStepCount.value = dataService.periodSteps.value;

    // Listen to period step updates and sync with animated step count
    // ✅ Store listener for proper disposal
    _listeners.add(
      ever(dataService.periodSteps, (int steps) {
        if (!_isDisposed) {  // ✅ Guard against disposed state
          _animatedStepCount.value = steps;
        }
      })
    );

    // Also listen to today's steps for fallback (when "Today" is selected)
    _listeners.add(
      ever(dataService.todaySteps, (int steps) {
        if (!_isDisposed && selectedFilter == 'Today') {  // ✅ Guard against disposed state
          _animatedStepCount.value = steps;
        }
      })
    );

    // Listen to pedestrian status for walking animations
    _listeners.add(
      ever(dataService.pedestrianStatus, (String status) {
        if (!_isDisposed) {  // ✅ Guard against disposed state
          animationController.setWalkingState(status == 'walking');
        }
      })
    );

    // Wait for secondary data to load before initializing period data
    // This ensures StepTrackingService is fully initialized
    _listeners.add(
      ever(dataService.isSecondaryDataLoaded, (bool loaded) {
        if (loaded && !_isDisposed) {
          print('✅ Secondary data loaded - initializing period data for filter: $selectedFilter');
          dataService.loadPeriodData(selectedFilter);
        }
      })
    );
  }

  void _setupSyncListeners() {
    // Get step tracking service for manual sync listening
    final stepTrackingService = Get.find<StepTrackingService>();

    // Listen to manual sync state to control animation
    _listeners.add(
      ever(stepTrackingService.isManualSyncing, (bool syncing) {
        if (!_isDisposed) {
          if (syncing) {
            animationController.startSyncAnimation();
          } else {
            animationController.stopSyncAnimation();
          }
        }
      })
    );

    // Listen to sync success to show success message
    _listeners.add(
      ever(stepTrackingService.syncSuccess, (bool success) {
        if (!_isDisposed && success) {

        }
      })
    );

    // Listen to sync error to show error message
    _listeners.add(
      ever(stepTrackingService.syncError, (bool error) {
        if (!_isDisposed && error && stepTrackingService.syncStatusMessage.value.isNotEmpty) {
          Get.snackbar(
            'Sync Failed',
            stepTrackingService.syncStatusMessage.value,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.withValues(alpha: 0.9),
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
            icon: const Icon(Icons.error, color: Colors.white),
          );
        }
      })
    );
  }

  void _setupNavigationListener() {
    // No longer needed - we use onBeforeNavigate callback instead
    // This is handled by passing a callback to ActionButtonsGridWidget
  }

  @override
  void dispose() {
    print('🗑️ HomepageScreen: Starting disposal...');
    _isDisposed = true;

    // ✅ Clean up all listeners first (CRITICAL: prevents setState after dispose crashes)
    for (var listener in _listeners) {
      listener.dispose();
    }
    _listeners.clear();
    print('✅ Disposed ${_listeners.length} listeners');

    // Clean up overlay
    _hideDropdownOverlay();

    // Cancel notification refresh timer
    _notificationRefreshTimer?.cancel();

    // Controllers are disposed by GetX automatically
    Get.delete<HomepageAnimationController>();
    // Don't delete HomepageDataService as it's permanent and shared
    // Get.delete<HomepageDataService>();
    // Keep NotificationController as it might be shared with other screens

    print('✅ HomepageScreen: Disposal complete');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Stack(
              children: [
                // Background SVG pattern
                Positioned(
                  top: 0,
                  right: 0,
                  child: SvgPicture.asset(
                    'assets/background/Line Pattern.svg',
                    fit: BoxFit.contain,
                    height: size.height * 0.4,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header - Fixed height
                      HomepageHeaderWidget(
                        userName: dataService.userName,
                        profileImageUrl: dataService.profileImageUrl,
                        hasUnreadNotifications: hasUnreadNotifications,
                      ),
                      const SizedBox(height: 24),


                      // Overall Stats Card - Fixed height
                      Obx(() => dataService.isInitialLoading.value
                          ? const OverallStatsCardSkeletonWidget()
                          : OverallStatsCardWidget(
                        overallDays: dataService.overallDays,
                        overallSteps: dataService.overallSteps,
                        overallDistance: dataService.overallDistance,
                      )),
                      const SizedBox(height: 16),

                      // Statistics Card - Fixed height instead of Expanded
                      SizedBox(
                        height: size.height * 0.3,
                        child: Obx(() => dataService.isInitialLoading.value
                            ? _buildStatisticsCardSkeleton(size)
                            : _buildStatisticsCard(size)),
                      ),
                      const SizedBox(height: 16),

                      // Action Buttons Grid - Fixed height instead of Expanded
                      Obx(() => dataService.isSecondaryDataLoaded.value
                          ? ActionButtonsGridWidget(
                        totalRaceCount: dataService.totalRaceCount,
                        activeJoinedRaceCount: dataService.activeJoinedRaceCount,
                        quickRaceCount: dataService.quickRaceCount,
                        pendingInvitesCount: dataService.pendingInvitesCount,
                        onBeforeNavigate: () {
                          // Close dropdown before navigating to race screens
                          if (isDropdownOpen.value) {
                            _hideDropdownOverlay();
                          }
                        },
                      )
                          : const ActionButtonsGridSkeletonWidget()),
                      const SizedBox(height: 16),

                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCard(Size size) {
    return GestureDetector(
      onTap: () {
        // Close dropdown when tapping outside
        if (isDropdownOpen.value) {
          _hideDropdownOverlay();
        }
      },
      child: FlippableStatisticsCard(
        selectedFilter: selectedFilter,
        filters: filters,
        isDropdownOpen: isDropdownOpen,
        onFilterChanged: _onFilterChanged,
        onDropdownToggle: _showDropdownOverlay,
        isLoadingPeriodData: dataService.isLoadingPeriodData,
        periodDistance: dataService.periodDistance,
        periodActiveTime: dataService.periodActiveTime,
        periodCalories: dataService.periodCalories,
        isWalking: animationController.isWalking,
        animatedStepCount: _animatedStepCount,
        currentHeartRate: dataService.currentHeartRate,
        isHeartRateAvailable: dataService.isHeartRateAvailable,
        currentBloodOxygen: dataService.currentBloodOxygen,
        isBloodOxygenAvailable: dataService.isBloodOxygenAvailable,
        currentRespiratoryRate: dataService.currentRespiratoryRate,
        isRespiratoryRateAvailable: dataService.isRespiratoryRateAvailable,
        gradientController: animationController.gradientController,
        ballController: animationController.ballController,
        middleProgressController: animationController.middleProgressController,
        pulseController: animationController.pulseController,
        syncProgressController: animationController.syncProgressController,
        gradientAnimation: animationController.gradientAnimation,
        ballAnimation: animationController.ballAnimation,
        pulseAnimation: animationController.pulseAnimation,
        onFlipStateChanged: (isFlipped) {
          setState(() {
            _isCardFlipped = isFlipped;
          });
        },
      ),
    );
  }

  Widget _buildStatisticsCardSkeleton(Size size) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: const Color(0xFF2759FF),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2759FF).withValues(alpha: 0.3),
            spreadRadius: 2,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Statistics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              _buildShimmerContainer(width: 80, height: 30),
            ],
          ),

          // Skeleton progress circle and stats
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Column Skeleton
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildLoadingCornerStat('Distance', 'assets/icons/distance_icon.svg'),
                      _buildLoadingCornerStat('Heart Rate', 'assets/icons/heart_rate.svg'),
                    ],
                  ),
                ),

                // Center Circle Skeleton
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.withValues(alpha: 0.1),
                      ),
                      child: Center(
                        child: _buildShimmerContainer(width: 80, height: 20),
                      ),
                    ),
                  ),
                ),

                // Right Column Skeleton
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildLoadingCornerStat('Time', 'assets/icons/timer_icon.svg'),
                      _buildLoadingCornerStat('Calories', 'assets/icons/winner_cup.svg'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCornerStat(String label, String svgPath) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SvgPicture.asset(
              svgPath,
              width: 22,
              height: 22,
              colorFilter: ColorFilter.mode(
                const Color(0xFFCDFF49).withValues(alpha: 0.5),
                BlendMode.srcIn,
              ),
            ).animate(onPlay: (controller) => controller.repeat())
                .shimmer(duration: 1500.ms, colors: [
              const Color(0xFFCDFF49).withValues(alpha: 0.3),
              const Color(0xFFCDFF49).withValues(alpha: 0.7),
              const Color(0xFFCDFF49).withValues(alpha: 0.3),
            ]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        _buildShimmerContainer(width: 50, height: 20),
      ],
    );
  }

  Widget _buildShimmerContainer({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          colors: [
            Colors.grey.withValues(alpha: 0.2),
            Colors.grey.withValues(alpha: 0.4),
            Colors.grey.withValues(alpha: 0.2),
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment(-1.0, 0.0),
          end: Alignment(1.0, 0.0),
        ),
      ),
    ).animate(onPlay: (controller) => controller.repeat())
        .shimmer(
      duration: 1500.ms,
      colors: [
        Colors.grey.withValues(alpha: 0.2),
        Colors.white.withValues(alpha: 0.4),
        Colors.grey.withValues(alpha: 0.2),
      ],
    );
  }

  void _onFilterChanged(String filter) {
    if (filters.contains(filter)) {
      setState(() {
        selectedFilter = filter;
      });
      _hideDropdownOverlay();

      // Load period-specific data using enhanced analytics
      dataService.loadPeriodData(filter);
    }
  }

  void _showDropdownOverlay() {
    if (isDropdownOpen.value) {
      _hideDropdownOverlay();
      return;
    }

    isDropdownOpen.value = true;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final screenSize = MediaQuery.of(context).size;
        return Positioned(
          top: 200, // Position below statistics card header
          right: 20,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: filters.map((filter) => _buildDropdownItem(filter)).toList(),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildDropdownItem(String filter) {
    final isSelected = filter == selectedFilter;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _onFilterChanged(filter);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2759FF).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          filter,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? const Color(0xFF2759FF) : Colors.black87,
          ),
        ),
      ),
    );
  }

  void _hideDropdownOverlay() {
    // ✅ Safe overlay removal with try-catch to prevent memory leaks
    try {
      _overlayEntry?.remove();
      _overlayEntry?.dispose();
    } catch (e) {
      // Overlay might already be removed - safe to ignore
      print('⚠️ Overlay already removed or error during removal: $e');
    } finally {
      _overlayEntry = null;
      if (!_isDisposed) {  // ✅ Only update if not disposed
        isDropdownOpen.value = false;
      }
    }
  }
}