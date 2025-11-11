import 'dart:developer';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/achievement_models.dart';
import '../models/xp_models.dart';
import '../models/user_overall_stats.dart';
import '../models/season_model.dart';
import '../utils/achievements_data.dart';
import '../services/xp_service.dart';
import '../services/season_service.dart';
import '../services/step_tracking_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Controller for managing achievements state
class AchievementsController extends GetxController {
  final XPService _xpService = XPService();
  final SeasonService _seasonService = SeasonService();

  // Observable state
  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isFirstVisit = false.obs;

  // Achievement data
  final RxList<Achievement> unlockedAchievements = <Achievement>[].obs;
  final RxList<Achievement> lockedAchievements = <Achievement>[].obs;
  final RxInt selectedCategoryIndex = 0.obs;

  // User data for criteria checking
  UserXP? _userXP;
  UserOverallStats? _userStats;
  SeasonXP? _seasonXP;

  // Stats
  final RxInt unlockedCount = 0.obs;
  final RxInt totalCount = 40.obs; // Total achievements
  final RxDouble completionPercentage = 0.0.obs;
  Achievement? _latestUnlocked;

  @override
  void onInit() {
    super.onInit();
    loadAchievements();
  }

  /// Load all achievements and calculate unlocked ones
  Future<void> loadAchievements() async {
    try {
      isLoading.value = true;
      hasError.value = false;


      // Check if first visit
      isFirstVisit.value = await _checkFirstVisit();

      // Get current user
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Load user data
      _userXP = await _xpService.getUserXP(userId);

      _userStats = await _getUserOverallStats(userId);

      _seasonXP = await _getSeasonXP(userId);

      // Calculate achievements
      _calculateAchievements();

    } catch (e, stackTrace) {

      hasError.value = true;
      errorMessage.value = 'Failed to load achievements';
    } finally {
      isLoading.value = false;
    }
  }

  /// Calculate which achievements are unlocked
  void _calculateAchievements() {
    if (_userXP == null) {
      log('⚠️ UserXP is null, cannot calculate achievements');
      return;
    }

    unlockedAchievements.clear();
    lockedAchievements.clear();

    for (final achievement in allAchievements) {
      final isUnlocked = achievement.isUnlocked(_userXP!, _userStats, _seasonXP);

      if (isUnlocked) {
        unlockedAchievements.add(achievement);
        _latestUnlocked ??= achievement; // Track first one as latest
      } else {
        lockedAchievements.add(achievement);
      }
    }

    // Update stats
    unlockedCount.value = unlockedAchievements.length;
    completionPercentage.value =
        (unlockedCount.value / totalCount.value) * 100;

    log('🏆 Calculated achievements:');
    log('   Unlocked: ${unlockedAchievements.length}');
    log('   Locked: ${lockedAchievements.length}');
  }

  /// Get user overall stats
  Future<UserOverallStats?> _getUserOverallStats(String userId) async {
    try {
      // Try to get from StepTrackingService if available
      if (Get.isRegistered<StepTrackingService>()) {
        final stepService = Get.find<StepTrackingService>();
        return UserOverallStats(
          userId: userId.hashCode, // Use hashCode for int userId
          totalSteps: stepService.overallSteps.value,
          totalDistance: stepService.overallDistance.value,
          totalCalories: 0,
          avgSpeed: 0.0,
          totalDays: stepService.overallDays.value,
          firstInstallDate: DateTime.now(),
        );
      }

      // Fallback to empty stats
      log('⚠️ StepTrackingService not available, using default stats');
      return UserOverallStats(
        userId: userId.hashCode,
        totalSteps: 0,
        totalDistance: 0.0,
        totalCalories: 0,
        avgSpeed: 0.0,
        totalDays: 1,
        firstInstallDate: DateTime.now(),
      );
    } catch (e) {
      log('⚠️ Could not load overall stats: $e');
      return null;
    }
  }

  /// Get season XP for current season
  Future<SeasonXP?> _getSeasonXP(String userId) async {
    try {
      final currentSeason = await _seasonService.getCurrentSeason();
      if (currentSeason == null) {
        log('⚠️ No current season found');
        return null;
      }

      return await _seasonService.getUserSeasonXP(userId, currentSeason.id);
    } catch (e) {
      log('⚠️ Could not load season XP: $e');
      return null;
    }
  }

  /// Check if this is the first time visiting achievements
  Future<bool> _checkFirstVisit() async {
    final prefs = await SharedPreferences.getInstance();
    final hasVisited = prefs.getBool('achievements_visited') ?? false;
    if (!hasVisited) {
      log('🎉 First visit to achievements!');
      await prefs.setBool('achievements_visited', true);
      return true;
    }
    return false;
  }

  /// Mark celebration as shown
  void markCelebrationShown() {
    isFirstVisit.value = false;
  }

  /// Change selected category
  void selectCategory(int index) {
    selectedCategoryIndex.value = index;
    log('📂 Selected category index: $index');
  }

  /// Get achievements for current category
  List<Achievement> get filteredAchievements {
    final category = AchievementCategory.values[selectedCategoryIndex.value];

    final unlocked =
        unlockedAchievements.where((a) => a.category == category).toList();
    final locked =
        lockedAchievements.where((a) => a.category == category).toList();

    // Sort unlocked by tier (platinum first), then locked by tier
    unlocked.sort((a, b) => b.tier.index.compareTo(a.tier.index));
    locked.sort((a, b) => b.tier.index.compareTo(a.tier.index));

    return [...unlocked, ...locked];
  }

  /// Get count for current category
  String get categoryCount {
    final category = AchievementCategory.values[selectedCategoryIndex.value];
    final unlocked =
        unlockedAchievements.where((a) => a.category == category).length;
    final total = allAchievements.where((a) => a.category == category).length;
    return '$unlocked/$total';
  }

  /// Get latest unlocked achievement
  Achievement? get latestUnlocked => _latestUnlocked;

  /// Retry loading
  Future<void> retry() async {
    await loadAchievements();
  }

  /// Get progress for an achievement
  double getAchievementProgress(Achievement achievement) {
    if (_userXP == null) return 0.0;
    return achievement.getProgress(_userXP!, _userStats, _seasonXP);
  }

  @override
  void onClose() {
    log('🔴 AchievementsController disposed');
    super.onClose();
  }
}
