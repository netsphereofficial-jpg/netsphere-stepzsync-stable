import '../models/xp_models.dart';
import '../models/user_overall_stats.dart';
import '../models/season_model.dart';

/// Achievement tiers/rarity levels
enum AchievementTier {
  bronze,
  silver,
  gold,
  platinum,
}

/// Achievement categories
enum AchievementCategory {
  racing,
  xp,
  distance,
  consistency,
  elite,
}

/// Achievement model
class Achievement {
  final String id;
  final String title;
  final String description;
  final AchievementCategory category;
  final AchievementTier tier;
  final String iconEmoji;
  final bool Function(UserXP userXP, UserOverallStats? stats, SeasonXP? seasonXP) checkCriteria;
  final String Function(UserXP userXP, UserOverallStats? stats, SeasonXP? seasonXP) getProgressText;
  final int Function(UserXP userXP, UserOverallStats? stats, SeasonXP? seasonXP)? getCurrentProgress;
  final int? targetValue; // For progress bar (e.g., 10 for "Win 10 races")

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.tier,
    required this.iconEmoji,
    required this.checkCriteria,
    required this.getProgressText,
    this.getCurrentProgress,
    this.targetValue,
  });

  /// Check if achievement is unlocked
  bool isUnlocked(UserXP userXP, UserOverallStats? stats, SeasonXP? seasonXP) {
    return checkCriteria(userXP, stats, seasonXP);
  }

  /// Get progress percentage (0.0 to 1.0)
  double getProgress(UserXP userXP, UserOverallStats? stats, SeasonXP? seasonXP) {
    if (isUnlocked(userXP, stats, seasonXP)) return 1.0;
    if (getCurrentProgress == null || targetValue == null) return 0.0;

    final current = getCurrentProgress!(userXP, stats, seasonXP);
    return (current / targetValue!).clamp(0.0, 1.0);
  }
}

/// Extension to get category display name
extension AchievementCategoryExtension on AchievementCategory {
  String get displayName {
    switch (this) {
      case AchievementCategory.racing:
        return 'Racing';
      case AchievementCategory.xp:
        return 'XP & Levels';
      case AchievementCategory.distance:
        return 'Distance';
      case AchievementCategory.consistency:
        return 'Consistency';
      case AchievementCategory.elite:
        return 'Elite';
    }
  }

  String get icon {
    switch (this) {
      case AchievementCategory.racing:
        return '🏁';
      case AchievementCategory.xp:
        return '⚡';
      case AchievementCategory.distance:
        return '👟';
      case AchievementCategory.consistency:
        return '🔥';
      case AchievementCategory.elite:
        return '👑';
    }
  }
}

/// Extension to get tier display name and color
extension AchievementTierExtension on AchievementTier {
  String get displayName {
    switch (this) {
      case AchievementTier.bronze:
        return 'Bronze';
      case AchievementTier.silver:
        return 'Silver';
      case AchievementTier.gold:
        return 'Gold';
      case AchievementTier.platinum:
        return 'Platinum';
    }
  }

  String get emoji {
    switch (this) {
      case AchievementTier.bronze:
        return '🥉';
      case AchievementTier.silver:
        return '🥈';
      case AchievementTier.gold:
        return '🥇';
      case AchievementTier.platinum:
        return '💎';
    }
  }
}
