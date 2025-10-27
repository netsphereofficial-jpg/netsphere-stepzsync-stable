import 'dart:developer';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/xp_models.dart';
import '../models/season_model.dart';
import '../services/leaderboard_service.dart';
import '../services/xp_service.dart';
import '../services/season_service.dart';
import '../screens/leaderboard/widgets/filter_toggle.dart';

/// Controller for managing leaderboard state and data
class LeaderboardController extends GetxController {
  final LeaderboardService _leaderboardService = LeaderboardService();
  final XPService _xpService = XPService();
  final SeasonService _seasonService = SeasonService();

  // Observable state
  final Rx<LeaderboardFilter> currentFilter = LeaderboardFilter.global.obs;
  final Rx<Season?> selectedSeason = Rx<Season?>(null);
  final RxList<Season> seasons = <Season>[].obs;
  final RxBool isLoadingSeasons = false.obs;
  final RxList<LeaderboardEntry> leaderboardEntries = <LeaderboardEntry>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<UserXP?> currentUserXP = Rx<UserXP?>(null);
  final RxInt currentUserRank = 0.obs;

  // Pagination
  final int pageSize = 50;
  int currentOffset = 0;
  bool hasMore = true;

  // User info
  String? currentUserId;
  List<String> friendIds = []; // TODO: Load from friends service

  @override
  void onInit() {
    super.onInit();
    _initializeUser();
  }

  /// Initialize user data
  Future<void> _initializeUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        currentUserId = user.uid;

        // Get user XP data
        final userXP = await _xpService.getUserXP(user.uid);
        if (userXP != null) {
          currentUserXP.value = userXP;
        }

        // Load seasons first
        await loadSeasons();

        // Load friends list
        await _loadFriends();

        // Only load leaderboard if a season is selected
        if (selectedSeason.value != null) {
          await loadLeaderboard();
        } else {
          log('⚠️ No seasons available, skipping initial leaderboard load');
        }
      }
    } catch (e) {
      log('❌ Error initializing user: $e');
    }
  }

  /// Load all seasons
  /// ✅ OPTIMIZATION: Lazy initialization of SeasonService
  /// This method now initializes default seasons on first call (deferred from app startup)
  Future<void> loadSeasons() async {
    try {
      isLoadingSeasons.value = true;

      // ✅ Initialize default seasons if not already done
      // This was moved from main.dart to defer startup cost
      await _seasonService.initializeDefaultSeasons();
      print('✅ [LEADERBOARD] Season service initialized (lazy load)');

      final loadedSeasons = await _seasonService.getAllSeasons();
      seasons.value = loadedSeasons;

      // Set current season as selected by default
      if (loadedSeasons.isNotEmpty) {
        final currentSeason = loadedSeasons.firstWhere(
          (s) => s.isCurrent,
          orElse: () => loadedSeasons.first,
        );
        selectedSeason.value = currentSeason;
      }
    } catch (e) {
      log('❌ Error loading seasons: $e');
    } finally {
      isLoadingSeasons.value = false;
    }
  }

  /// Load user's friends list
  Future<void> _loadFriends() async {
    if (currentUserId == null) return;

    try {
      // TODO: Implement friends service integration
      // For now, use empty list
      friendIds = [];
      log('📋 Loaded ${friendIds.length} friends');
    } catch (e) {
      log('❌ Error loading friends: $e');
    }
  }

  /// Load leaderboard based on current filter and season
  Future<void> loadLeaderboard({bool refresh = false}) async {
    if (refresh) {
      currentOffset = 0;
      hasMore = true;
      leaderboardEntries.clear();
    }

    if (isLoading.value || !hasMore) return;
    if (selectedSeason.value == null) {
      errorMessage.value = 'No season selected';
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      List<LeaderboardEntry> entries = [];
      final seasonId = selectedSeason.value!.id;

      switch (currentFilter.value) {
        case LeaderboardFilter.global:
          entries = await _leaderboardService.getSeasonLeaderboard(
            seasonId: seasonId,
            limit: pageSize,
            offset: currentOffset,
          );
          break;

        case LeaderboardFilter.friends:
          if (currentUserId != null) {
            if (friendIds.isEmpty) {
              errorMessage.value = 'No friends added yet';
              entries = [];
            } else {
              entries = await _leaderboardService.getFriendsSeasonLeaderboard(
                userId: currentUserId!,
                seasonId: seasonId,
                friendIds: friendIds,
                limit: pageSize,
              );
            }
          }
          break;
      }

      if (entries.isEmpty) {
        hasMore = false;
      } else {
        leaderboardEntries.addAll(entries);
        currentOffset += entries.length;

        if (entries.length < pageSize) {
          hasMore = false;
        }
      }

      // Update current user rank
      await _updateUserRank();

    } catch (e) {
      log('❌ Error loading leaderboard: $e');
      errorMessage.value = 'Failed to load leaderboard. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Load more entries (pagination)
  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore || isLoading.value) return;
    if (selectedSeason.value == null) return;

    isLoadingMore.value = true;

    try {
      List<LeaderboardEntry> entries = [];
      final seasonId = selectedSeason.value!.id;

      switch (currentFilter.value) {
        case LeaderboardFilter.global:
          entries = await _leaderboardService.getSeasonLeaderboard(
            seasonId: seasonId,
            limit: pageSize,
            offset: currentOffset,
          );
          break;

        case LeaderboardFilter.friends:
          if (currentUserId != null && friendIds.isNotEmpty) {
            entries = await _leaderboardService.getFriendsSeasonLeaderboard(
              userId: currentUserId!,
              seasonId: seasonId,
              friendIds: friendIds,
              limit: pageSize,
            );
          }
          break;
      }

      if (entries.isEmpty) {
        hasMore = false;
      } else {
        leaderboardEntries.addAll(entries);
        currentOffset += entries.length;

        if (entries.length < pageSize) {
          hasMore = false;
        }
      }
    } catch (e) {
      log('❌ Error loading more entries: $e');
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// Switch filter (Friends/Global)
  void switchFilter(LeaderboardFilter filter) {
    if (currentFilter.value == filter) return;

    currentFilter.value = filter;
    currentOffset = 0;
    hasMore = true;
    leaderboardEntries.clear();
    loadLeaderboard();
  }

  /// Change selected season
  void changeSeason(Season? season) {
    if (season == null || selectedSeason.value?.id == season.id) return;

    selectedSeason.value = season;
    currentOffset = 0;
    hasMore = true;
    leaderboardEntries.clear();
    loadLeaderboard();
  }

  /// Refresh leaderboard
  Future<void> refresh() async {
    await loadLeaderboard(refresh: true);
  }

  /// Update current user's rank
  Future<void> _updateUserRank() async {
    if (currentUserId == null || selectedSeason.value == null) return;

    try {
      final rank = await _leaderboardService.getUserSeasonRank(
        currentUserId!,
        selectedSeason.value!.id,
      );

      if (rank != null) {
        currentUserRank.value = rank;
      }
    } catch (e) {
      log('❌ Error updating user rank: $e');
    }
  }

  /// Refresh user XP data
  Future<void> refreshUserXP() async {
    if (currentUserId == null) return;

    try {
      final userXP = await _xpService.getUserXP(currentUserId!);
      if (userXP != null) {
        currentUserXP.value = userXP;
      }
    } catch (e) {
      log('❌ Error refreshing user XP: $e');
    }
  }

  /// Search leaderboard
  Future<List<LeaderboardEntry>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    try {
      return await _leaderboardService.searchLeaderboard(
        query: query,
        limit: 20,
      );
    } catch (e) {
      log('❌ Error searching users: $e');
      return [];
    }
  }

  /// Get leaderboard statistics
  Future<Map<String, dynamic>> getStats() async {
    try {
      return await _leaderboardService.getLeaderboardStats();
    } catch (e) {
      log('❌ Error getting stats: $e');
      return {};
    }
  }

  /// Get top 3 entries for podium display
  List<LeaderboardEntry> get topThree {
    if (leaderboardEntries.length >= 3) {
      return leaderboardEntries.sublist(0, 3);
    }
    return leaderboardEntries.toList();
  }

  /// Get remaining entries (after top 3)
  List<LeaderboardEntry> get remainingEntries {
    if (leaderboardEntries.length > 3) {
      return leaderboardEntries.sublist(3);
    }
    return [];
  }

  /// Find current user in leaderboard
  LeaderboardEntry? get currentUserEntry {
    if (currentUserId == null) return null;

    try {
      return leaderboardEntries.firstWhere(
        (entry) => entry.userId == currentUserId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if current user is in top 3
  bool get isUserInTopThree {
    final userEntry = currentUserEntry;
    return userEntry != null && userEntry.rank <= 3;
  }
}