import 'dart:developer';
import 'package:get/get.dart';
import '../models/xp_models.dart';
import '../services/hall_of_fame_service.dart';

/// Controller for managing Hall of Fame state
class HallOfFameController extends GetxController {
  final HallOfFameService _service = HallOfFameService();

  // Observable state
  final RxInt selectedCategoryIndex = 0.obs;
  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  // Data for each category
  final RxList<LeaderboardEntry> topWinners = <LeaderboardEntry>[].obs;
  final RxList<LeaderboardEntry> topPodiumFinishers = <LeaderboardEntry>[].obs;
  final RxList<LeaderboardEntry> topXPEarners = <LeaderboardEntry>[].obs;
  final RxList<SeasonChampion> seasonalChampions = <SeasonChampion>[].obs;

  // Loading states for each category
  final RxBool winnersLoading = true.obs;
  final RxBool podiumLoading = true.obs;
  final RxBool xpLoading = true.obs;
  final RxBool championsLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadAllCategories();
  }

  /// Load all hall of fame categories in parallel
  Future<void> loadAllCategories() async {
    try {
      isLoading.value = true;
      hasError.value = false;

      log('📊 Loading all Hall of Fame categories...');

      // Load all categories in parallel for better performance
      final results = await Future.wait([
        loadTopWinners(),
        loadTopPodiumFinishers(),
        loadTopXPEarners(),
        loadSeasonalChampions(),
      ]);

      log('✅ All Hall of Fame categories loaded successfully');
    } catch (e, stackTrace) {
      log('❌ Error loading Hall of Fame categories: $e');
      log('Stack trace: $stackTrace');
      hasError.value = true;
      errorMessage.value = 'Failed to load Hall of Fame data';
    } finally {
      isLoading.value = false;
    }
  }

  /// Load top winners data
  Future<void> loadTopWinners() async {
    try {
      winnersLoading.value = true;
      final winners = await _service.getTopWinners(limit: 10);
      topWinners.value = winners;
      log('✅ Loaded ${winners.length} top winners');
    } catch (e) {
      log('❌ Error loading top winners: $e');
    } finally {
      winnersLoading.value = false;
    }
  }

  /// Load top podium finishers data
  Future<void> loadTopPodiumFinishers() async {
    try {
      podiumLoading.value = true;
      final finishers = await _service.getTopPodiumFinishers(limit: 10);
      topPodiumFinishers.value = finishers;
      log('✅ Loaded ${finishers.length} top podium finishers');
    } catch (e) {
      log('❌ Error loading top podium finishers: $e');
    } finally {
      podiumLoading.value = false;
    }
  }

  /// Load top XP earners data
  Future<void> loadTopXPEarners() async {
    try {
      xpLoading.value = true;
      final earners = await _service.getTopXPEarners(limit: 10);
      topXPEarners.value = earners;
      log('✅ Loaded ${earners.length} top XP earners');
    } catch (e) {
      log('❌ Error loading top XP earners: $e');
    } finally {
      xpLoading.value = false;
    }
  }

  /// Load seasonal champions data
  Future<void> loadSeasonalChampions() async {
    try {
      championsLoading.value = true;
      final champions = await _service.getSeasonalChampions();
      seasonalChampions.value = champions;
      log('✅ Loaded ${champions.length} seasonal champions');
    } catch (e) {
      log('❌ Error loading seasonal champions: $e');
    } finally {
      championsLoading.value = false;
    }
  }

  /// Change selected category
  void selectCategory(int index) {
    selectedCategoryIndex.value = index;
    log('📂 Selected category index: $index');
  }

  /// Retry loading all data
  Future<void> retry() async {
    await loadAllCategories();
  }

  /// Get current category data based on selected index
  List<dynamic> get currentCategoryData {
    switch (selectedCategoryIndex.value) {
      case 0:
        return topWinners;
      case 1:
        return topPodiumFinishers;
      case 2:
        return topXPEarners;
      case 3:
        return seasonalChampions;
      default:
        return [];
    }
  }

  /// Get current category loading state
  bool get isCurrentCategoryLoading {
    switch (selectedCategoryIndex.value) {
      case 0:
        return winnersLoading.value;
      case 1:
        return podiumLoading.value;
      case 2:
        return xpLoading.value;
      case 3:
        return championsLoading.value;
      default:
        return false;
    }
  }

  /// Get win rate for a user (percentage)
  double getWinRate(LeaderboardEntry entry) {
    if (entry.racesCompleted == 0) return 0.0;
    return (entry.racesWon / entry.racesCompleted * 100);
  }

  /// Get average XP per race
  double getAverageXPPerRace(LeaderboardEntry entry) {
    if (entry.racesCompleted == 0) return 0.0;
    return entry.totalXP / entry.racesCompleted;
  }

  @override
  void onClose() {
    log('🔴 HallOfFameController disposed');
    super.onClose();
  }
}
