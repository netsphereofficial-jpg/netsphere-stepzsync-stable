import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/assets/icons.dart';
import '../../controllers/home/home_controller.dart';
import '../../controllers/leaderboard_controller.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../services/background_service.dart';
import '../home/homepage_screen/homepage_screen.dart';
import '../home/homepage_screen/controllers/homepage_data_service.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../races/create_race/create_race_screen.dart';
import '../chat/chat_list_screen.dart';
import '../profile/profile_view_screen.dart';
import '../login_screen.dart';
import '../../utils/guest_utils.dart';
import '../../utils/app_lifecycle_manager.dart';
import '../../widgets/guest_upgrade_dialog.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  late final HomeController controller;
  late final AppLifecycleManager _lifecycleManager;

  @override
  void initState() {
    super.initState();
    controller = Get.put(HomeController());

    // Initialize app lifecycle manager for cold start detection
    _lifecycleManager = AppLifecycleManager();
    WidgetsBinding.instance.addObserver(this);

    // Initialize lifecycle manager and register cold start callback
    _initializeLifecycleManager();

    // Preload leaderboard data eagerly
    final leaderboardController = Get.put(LeaderboardController());

    // Force load data immediately
    Future.delayed(Duration.zero, () {
      if (leaderboardController.leaderboardEntries.isEmpty) {
        // Data will load automatically via controller's onInit
      }
    });
  }

  /// Initialize lifecycle manager and register cold start callback
  Future<void> _initializeLifecycleManager() async {
    try {
      await _lifecycleManager.initialize();

      // Register cold start callback to trigger health sync
      _lifecycleManager.registerColdStartCallback(() {
        print('🔄 [MAIN_NAV] Cold start detected, triggering health sync...');
        _handleColdStart();
      });

      print('✅ [MAIN_NAV] Lifecycle manager initialized');
    } catch (e) {
      print('❌ [MAIN_NAV] Error initializing lifecycle manager: $e');
    }
  }

  /// Handle cold start - trigger health sync on homepage
  void _handleColdStart() {
    try {
      // Only sync if not a guest user
      if (GuestUtils.isGuest()) {
        print('🏥 [MAIN_NAV] Skipping health sync for guest user');
        return;
      }

      // Wait for context to be available and trigger health sync
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          // Get or create homepage data service
          final dataService = Get.isRegistered<HomepageDataService>()
              ? Get.find<HomepageDataService>()
              : Get.put(HomepageDataService(), permanent: true);

          // Trigger health sync with context
          dataService.syncHealthDataOnColdStart(context);
        }
      });
    } catch (e) {
      print('❌ [MAIN_NAV] Error handling cold start: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _lifecycleManager.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: AppColors.appColor,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackPress(controller);
        }
      },
      child: FutureBuilder<bool>(
        future: _initializeServicesAndCheck(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.connectionState == ConnectionState.done) {
            var isComplete = snapshot.data ?? false;
            if (!isComplete) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                showSnackbar(
                  "",
                  "Please allow activity permission to track steps count!",
                );
              });
            }

            return Scaffold(
              backgroundColor: Colors.white,
              body: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.appColor.withValues(alpha: 0.1),
                      Colors.white,
                      AppColors.appColor.withValues(alpha: 0.05),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
                child: Column(
                  children: [

                    // Main Content
                    Expanded(
                      child: SafeArea(
                        top: false,
                        child: Obx(
                          () => _getCurrentScreen(controller.selectedIndex.value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: SafeArea(
                child: _buildBottomNavBar(controller),
              ),
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  void _handleBackPress(HomeController controller) {
    if (controller.selectedIndex.value != 0) {
      // If not on home tab, navigate to home tab
      controller.changeIndex(0);
    } else {
      // If on home tab, exit app
      SystemNavigator.pop();
    }
  }

  Widget _getCurrentScreen(int index) {
    // Map tabs to feature names
    final Map<int, String> tabFeatures = {
      0: 'home_screen',
      1: 'leaderboard',
      2: 'create_race',
      3: 'chat',
      4: 'profile',
    };

    // Check if guest user is trying to access restricted tab
    if (GuestUtils.isGuest()) {
      final featureName = tabFeatures[index] ?? '';
      if (!GuestUtils.isFeatureAvailableToGuest(featureName)) {
        // Show upgrade dialog and return to home tab
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final featureDisplayNames = {
            'leaderboard': 'Leaderboard',
            'create_race': 'Create Race',
            'chat': 'Chat',
          };
          GuestUpgradeDialog.show(
            featureName: featureDisplayNames[featureName] ?? featureName,
          );
          controller.changeIndex(0); // Return to home
        });
        return HomepageScreen(key: const ValueKey('home'));
      }
    }

    switch (index) {
      case 0:
        return HomepageScreen(key: const ValueKey('home'));
      case 1:
        return LeaderboardScreen(key: const ValueKey('leaderboard'));
      case 2:
        return CreateRaceScreen(key: const ValueKey('create'));
      case 3:
        return ChatListScreen(key: const ValueKey('chat'));
      case 4:
        return ProfileViewScreen(key: const ValueKey('profile'));
      default:
        return HomepageScreen(key: const ValueKey('home'));
    }
  }
}

Widget _buildBottomNavBar(HomeController controller) {
  return Container(
    height: 75,
    margin: const EdgeInsets.only(left: 14, right: 14, bottom: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(25),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Obx(() => Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildNavItem(0, IconPaths.homeSelected, IconPaths.homeunSelected, 'Home', controller),
        _buildNavItem(1, IconPaths.trophySelected, IconPaths.trophyunSelected, 'Leader', controller),
        _buildCenterFAB(controller),
        _buildNavItem(3, IconPaths.messageSelected, IconPaths.messageunSelected, 'Chat', controller),
        _buildNavItem(4, IconPaths.profileSelected, IconPaths.profileunSelected, 'Profile', controller),
      ],
    )),
  );
}

Widget _buildNavItem(int index, String selectedIcon, String unselectedIcon, String label, HomeController controller) {
  final isSelected = controller.selectedIndex.value == index;

  // Check if this tab is locked for guests
  final Map<int, String> tabFeatures = {
    1: 'leaderboard',
    3: 'chat',
  };
  final isLocked = GuestUtils.isGuest() &&
      tabFeatures.containsKey(index) &&
      !GuestUtils.isFeatureAvailableToGuest(tabFeatures[index]!);

  return Expanded(
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          controller.changeIndex(index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with lock indicator
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                        ? const Color(0xFF2759FF).withValues(alpha: 0.1)
                        : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SvgPicture.asset(
                      isSelected ? selectedIcon : unselectedIcon,
                      height: 18,
                      width: 18,
                      colorFilter: ColorFilter.mode(
                        isSelected ? const Color(0xFF2759FF) : Colors.grey.shade600,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  // Lock icon for restricted tabs
                  if (isLocked)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 3),

              // Label
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? const Color(0xFF2759FF) : Colors.grey.shade600,
                ),
              ),

              // Selection indicator
              Container(
                margin: const EdgeInsets.only(top: 2),
                height: 2,
                width: isSelected ? 16 : 0,
                decoration: BoxDecoration(
                  color: const Color(0xFF2759FF),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildCenterFAB(HomeController controller) {
  final isSelected = controller.selectedIndex.value == 2;

  return SizedBox(
    width: 60,
    height: 60,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => controller.changeIndex(2),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF4371FA),
                const Color(0xFF2759FF),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2759FF).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: isSelected
              ? Border.all(color: const Color(0xFF2759FF), width: 2)
              : null,
          ),
          child: Icon(
            Icons.add_rounded,
            size: 28,
            color: Colors.white,
          ),
        ),
      ),
    ),
  );
}



Future<bool> _initializeServicesAndCheck() async {
  try {
    // Enable background location tracking to keep app alive in background
    // This allows steps to sync continuously even when app is minimized
    // final bgService = Get.find<BackgroundService>();
    // await bgService.enableLocationTracking();
    print('✅ Background step syncing enabled');
    return true;
  } catch (e) {
    print('⚠️ Background service failed to start: $e');
    // Continue anyway - foreground tracking still works
    return true;
  }
}



void showSnackbar(String title, String message) {
  if (title.isEmpty) {
  } else {
    SnackbarUtils.showInfo(title, message);
  }
}