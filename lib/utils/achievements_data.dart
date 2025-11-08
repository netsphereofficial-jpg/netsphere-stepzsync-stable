import '../models/achievement_models.dart';

/// All achievements in the app
final List<Achievement> allAchievements = [
  // ===== RACING ACHIEVEMENTS =====
  Achievement(
    id: 'first_race',
    title: 'First Steps',
    description: 'Complete your first race',
    category: AchievementCategory.racing,
    tier: AchievementTier.bronze,
    iconEmoji: '🏁',
    checkCriteria: (userXP, stats, seasonXP) => userXP.racesCompleted >= 1,
    getProgressText: (userXP, stats, seasonXP) =>
        userXP.racesCompleted >= 1 ? 'Unlocked!' : 'Complete 1 race',
    getCurrentProgress: (userXP, stats, seasonXP) => userXP.racesCompleted,
    targetValue: 1,
  ),

  Achievement(
    id: 'podium_finisher',
    title: 'Podium Finisher',
    description: 'Finish in top 3 for the first time',
    category: AchievementCategory.racing,
    tier: AchievementTier.bronze,
    iconEmoji: '🥉',
    checkCriteria: (userXP, stats, seasonXP) => userXP.podiumFinishes >= 1,
    getProgressText: (userXP, stats, seasonXP) =>
        userXP.podiumFinishes >= 1 ? 'Unlocked!' : 'Finish in top 3 once',
    getCurrentProgress: (userXP, stats, seasonXP) => userXP.podiumFinishes,
    targetValue: 1,
  ),

  Achievement(
    id: 'champion',
    title: 'Champion',
    description: 'Win your first race',
    category: AchievementCategory.racing,
    tier: AchievementTier.silver,
    iconEmoji: '🏆',
    checkCriteria: (userXP, stats, seasonXP) => userXP.racesWon >= 1,
    getProgressText: (userXP, stats, seasonXP) =>
        userXP.racesWon >= 1 ? 'Unlocked!' : 'Win 1 race',
    getCurrentProgress: (userXP, stats, seasonXP) => userXP.racesWon,
    targetValue: 1,
  ),

  Achievement(
    id: 'hat_trick',
    title: 'Hat Trick',
    description: 'Win 3 races',
    category: AchievementCategory.racing,
    tier: AchievementTier.silver,
    iconEmoji: '🎩',
    checkCriteria: (userXP, stats, seasonXP) => userXP.racesWon >= 3,
    getProgressText: (userXP, stats, seasonXP) => userXP.racesWon >= 3
        ? 'Unlocked!'
        : 'Win ${3 - userXP.racesWon} more races',
    getCurrentProgress: (userXP, stats, seasonXP) => userXP.racesWon,
    targetValue: 3,
  ),

  Achievement(
    id: 'serial_winner',
    title: 'Serial Winner',
    description: 'Win 5 races',
    category: AchievementCategory.racing,
    tier: AchievementTier.silver,
    iconEmoji: '🔥',
    checkCriteria: (userXP, stats, seasonXP) => userXP.racesWon >= 5,
    getProgressText: (userXP, stats, seasonXP) => userXP.racesWon >= 5
        ? 'Unlocked!'
        : '${userXP.racesWon}/5 races won',
    getCurrentProgress: (userXP, stats, seasonXP) => userXP.racesWon,
    targetValue: 5,
  ),

  Achievement(
    id: 'dominator',
    title: 'Dominator',
    description: 'Win 10 races',
    category: AchievementCategory.racing,
    tier: AchievementTier.gold,
    iconEmoji: '👑',
    checkCriteria: (userXP, stats, seasonXP) => userXP.racesWon >= 10,
    getProgressText: (userXP, stats, seasonXP) => userXP.racesWon >= 10
        ? 'Unlocked!'
        : '${userXP.racesWon}/10 races won',
    getCurrentProgress: (userXP, stats, seasonXP) => userXP.racesWon,
    targetValue: 10,
  ),

  Achievement(
    id: 'legend',
    title: 'Legend',
    description: 'Win 25 races',
    category: AchievementCategory.racing,
    tier: AchievementTier.gold,
    iconEmoji: '⭐',
    checkCriteria: (userXP, stats, seasonXP) => userXP.racesWon >= 25,
    getProgressText: (userXP, stats, seasonXP) => userXP.racesWon >= 25
        ? 'Unlocked!'
        : '${userXP.racesWon}/25 races won',
    getCurrentProgress: (userXP, stats, seasonXP) => userXP.racesWon,
    targetValue: 25,
  ),

  Achievement(
    id: 'podium_regular',
    title: 'Podium Regular',
    description: 'Finish in top 3 ten times',
    category: AchievementCategory.racing,
    tier: AchievementTier.silver,
    iconEmoji: '🥈',
    checkCriteria: (userXP, stats, seasonXP) => userXP.podiumFinishes >= 10,
    getProgressText: (userXP, stats, seasonXP) => userXP.podiumFinishes >= 10
        ? 'Unlocked!'
        : '${userXP.podiumFinishes}/10 podiums',
    getCurrentProgress: (userXP, stats, seasonXP) => userXP.podiumFinishes,
    targetValue: 10,
  ),

  Achievement(
    id: 'podium_pro',
    title: 'Podium Pro',
    description: 'Finish in top 3 twenty-five times',
    category: AchievementCategory.racing,
    tier: AchievementTier.gold,
    iconEmoji: '🥇',
    checkCriteria: (userXP, stats, seasonXP) => userXP.podiumFinishes >= 25,
    getProgressText: (userXP, stats, seasonXP) => userXP.podiumFinishes >= 25
        ? 'Unlocked!'
        : '${userXP.podiumFinishes}/25 podiums',
    getCurrentProgress: (userXP, stats, seasonXP) => userXP.podiumFinishes,
    targetValue: 25,
  ),

  Achievement(
    id: 'century_club',
    title: 'Century Club',
    description: 'Complete 100 races',
    category: AchievementCategory.racing,
    tier: AchievementTier.gold,
    iconEmoji: '💯',
    checkCriteria: (userXP, stats, seasonXP) => userXP.racesCompleted >= 100,
    getProgressText: (userXP, stats, seasonXP) => userXP.racesCompleted >= 100
        ? 'Unlocked!'
        : '${userXP.racesCompleted}/100 races',
    getCurrentProgress: (userXP, stats, seasonXP) => userXP.racesCompleted,
    targetValue: 100,
  ),

  Achievement(
    id: 'marathon_racer',
    title: 'Marathon Racer',
    description: 'Complete 250 races',
    category: AchievementCategory.racing,
    tier: AchievementTier.platinum,
    iconEmoji: '🎖️',
    checkCriteria: (userXP, stats, seasonXP) => userXP.racesCompleted >= 250,
    getProgressText: (userXP, stats, seasonXP) => userXP.racesCompleted >= 250
        ? 'Unlocked!'
        : '${userXP.racesCompleted}/250 races',
    getCurrentProgress: (userXP, stats, seasonXP) => userXP.racesCompleted,
    targetValue: 250,
  ),

  // ===== XP & LEVELS ACHIEVEMENTS =====
  Achievement(
    id: 'xp_novice',
    title: 'XP Novice',
    description: 'Earn 1,000 XP',
    category: AchievementCategory.xp,
    tier: AchievementTier.bronze,
    iconEmoji: '⚡',
    checkCriteria: (userXP, stats, seasonXP) => userXP.totalXP >= 1000,
    getProgressText: (userXP, stats, seasonXP) =>
        userXP.totalXP >= 1000 ? 'Unlocked!' : '${userXP.totalXP}/1,000 XP',
    getCurrentProgress: (userXP, stats, seasonXP) => userXP.totalXP,
    targetValue: 1000,
  ),

  Achievement(
    id: 'xp_apprentice',
    title: 'XP Apprentice',
    description: 'Earn 5,000 XP',
    category: AchievementCategory.xp,
    tier: AchievementTier.bronze,
    iconEmoji: '✨',
    checkCriteria: (userXP, stats, seasonXP) => userXP.totalXP >= 5000,
    getProgressText: (userXP, stats, seasonXP) =>
        userXP.totalXP >= 5000 ? 'Unlocked!' : '${userXP.totalXP}/5,000 XP',
    getCurrentProgress: (userXP, stats, seasonXP) => userXP.totalXP,
    targetValue: 5000,
  ),

  Achievement(
    id: 'xp_master',
    title: 'XP Master',
    description: 'Earn 10,000 XP',
    category: AchievementCategory.xp,
    tier: AchievementTier.silver,
    iconEmoji: '💫',
    checkCriteria: (userXP, stats, seasonXP) => userXP.totalXP >= 10000,
    getProgressText: (userXP, stats, seasonXP) =>
        userXP.totalXP >= 10000 ? 'Unlocked!' : '${userXP.totalXP}/10,000 XP',
    getCurrentProgress: (userXP, stats, seasonXP) => userXP.totalXP,
    targetValue: 10000,
  ),

  Achievement(
    id: 'xp_expert',
    title: 'XP Expert',
    description: 'Earn 25,000 XP',
    category: AchievementCategory.xp,
    tier: AchievementTier.silver,
    iconEmoji: '🌟',
    checkCriteria: (userXP, stats, seasonXP) => userXP.totalXP >= 25000,
    getProgressText: (userXP, stats, seasonXP) =>
        userXP.totalXP >= 25000 ? 'Unlocked!' : '${userXP.totalXP}/25,000 XP',
    getCurrentProgress: (userXP, stats, seasonXP) => userXP.totalXP,
    targetValue: 25000,
  ),

  Achievement(
    id: 'xp_legend',
    title: 'XP Legend',
    description: 'Earn 50,000 XP',
    category: AchievementCategory.xp,
    tier: AchievementTier.gold,
    iconEmoji: '🌠',
    checkCriteria: (userXP, stats, seasonXP) => userXP.totalXP >= 50000,
    getProgressText: (userXP, stats, seasonXP) =>
        userXP.totalXP >= 50000 ? 'Unlocked!' : '${userXP.totalXP}/50,000 XP',
    getCurrentProgress: (userXP, stats, seasonXP) => userXP.totalXP,
    targetValue: 50000,
  ),

  Achievement(
    id: 'xp_titan',
    title: 'XP Titan',
    description: 'Earn 100,000 XP',
    category: AchievementCategory.xp,
    tier: AchievementTier.platinum,
    iconEmoji: '💥',
    checkCriteria: (userXP, stats, seasonXP) => userXP.totalXP >= 100000,
    getProgressText: (userXP, stats, seasonXP) => userXP.totalXP >= 100000
        ? 'Unlocked!'
        : '${userXP.totalXP}/100,000 XP',
    getCurrentProgress: (userXP, stats, seasonXP) => userXP.totalXP,
    targetValue: 100000,
  ),

  Achievement(
    id: 'level_5',
    title: 'Level 5',
    description: 'Reach level 5',
    category: AchievementCategory.xp,
    tier: AchievementTier.bronze,
    iconEmoji: '5️⃣',
    checkCriteria: (userXP, stats, seasonXP) => userXP.level >= 5,
    getProgressText: (userXP, stats, seasonXP) =>
        userXP.level >= 5 ? 'Unlocked!' : 'Reach level 5',
    getCurrentProgress: (userXP, stats, seasonXP) => userXP.level,
    targetValue: 5,
  ),

  Achievement(
    id: 'level_10',
    title: 'Level 10',
    description: 'Reach level 10',
    category: AchievementCategory.xp,
    tier: AchievementTier.silver,
    iconEmoji: '🔟',
    checkCriteria: (userXP, stats, seasonXP) => userXP.level >= 10,
    getProgressText: (userXP, stats, seasonXP) =>
        userXP.level >= 10 ? 'Unlocked!' : 'Reach level 10',
    getCurrentProgress: (userXP, stats, seasonXP) => userXP.level,
    targetValue: 10,
  ),

  Achievement(
    id: 'level_25',
    title: 'Level 25',
    description: 'Reach level 25',
    category: AchievementCategory.xp,
    tier: AchievementTier.gold,
    iconEmoji: '🎯',
    checkCriteria: (userXP, stats, seasonXP) => userXP.level >= 25,
    getProgressText: (userXP, stats, seasonXP) =>
        userXP.level >= 25 ? 'Unlocked!' : 'Reach level 25',
    getCurrentProgress: (userXP, stats, seasonXP) => userXP.level,
    targetValue: 25,
  ),

  Achievement(
    id: 'level_50',
    title: 'Level 50',
    description: 'Reach level 50',
    category: AchievementCategory.xp,
    tier: AchievementTier.platinum,
    iconEmoji: '💎',
    checkCriteria: (userXP, stats, seasonXP) => userXP.level >= 50,
    getProgressText: (userXP, stats, seasonXP) =>
        userXP.level >= 50 ? 'Unlocked!' : 'Reach level 50',
    getCurrentProgress: (userXP, stats, seasonXP) => userXP.level,
    targetValue: 50,
  ),

  // ===== DISTANCE & ACTIVITY ACHIEVEMENTS =====
  Achievement(
    id: 'first_km',
    title: 'First Kilometer',
    description: 'Run 1 km total',
    category: AchievementCategory.distance,
    tier: AchievementTier.bronze,
    iconEmoji: '👟',
    checkCriteria: (userXP, stats, seasonXP) =>
        stats != null && stats.totalDistance >= 1.0,
    getProgressText: (userXP, stats, seasonXP) => stats != null &&
            stats.totalDistance >= 1.0
        ? 'Unlocked!'
        : 'Run 1 km',
    getCurrentProgress: (userXP, stats, seasonXP) =>
        stats?.totalDistance.toInt() ?? 0,
    targetValue: 1,
  ),

  Achievement(
    id: '10k_runner',
    title: '10K Runner',
    description: 'Run 10 km total',
    category: AchievementCategory.distance,
    tier: AchievementTier.bronze,
    iconEmoji: '🏃',
    checkCriteria: (userXP, stats, seasonXP) =>
        stats != null && stats.totalDistance >= 10.0,
    getProgressText: (userXP, stats, seasonXP) => stats != null &&
            stats.totalDistance >= 10.0
        ? 'Unlocked!'
        : '${stats?.totalDistance.toStringAsFixed(1) ?? 0}/10 km',
    getCurrentProgress: (userXP, stats, seasonXP) =>
        stats?.totalDistance.toInt() ?? 0,
    targetValue: 10,
  ),

  Achievement(
    id: 'half_marathon',
    title: 'Half Marathon',
    description: 'Run 21.1 km total',
    category: AchievementCategory.distance,
    tier: AchievementTier.silver,
    iconEmoji: '🏃‍♂️',
    checkCriteria: (userXP, stats, seasonXP) =>
        stats != null && stats.totalDistance >= 21.1,
    getProgressText: (userXP, stats, seasonXP) => stats != null &&
            stats.totalDistance >= 21.1
        ? 'Unlocked!'
        : '${stats?.totalDistance.toStringAsFixed(1) ?? 0}/21.1 km',
    getCurrentProgress: (userXP, stats, seasonXP) =>
        stats?.totalDistance.toInt() ?? 0,
    targetValue: 21,
  ),

  Achievement(
    id: 'marathon_runner',
    title: 'Marathon Runner',
    description: 'Run 42.2 km total',
    category: AchievementCategory.distance,
    tier: AchievementTier.silver,
    iconEmoji: '🏅',
    checkCriteria: (userXP, stats, seasonXP) =>
        stats != null && stats.totalDistance >= 42.2,
    getProgressText: (userXP, stats, seasonXP) => stats != null &&
            stats.totalDistance >= 42.2
        ? 'Unlocked!'
        : '${stats?.totalDistance.toStringAsFixed(1) ?? 0}/42.2 km',
    getCurrentProgress: (userXP, stats, seasonXP) =>
        stats?.totalDistance.toInt() ?? 0,
    targetValue: 42,
  ),

  Achievement(
    id: 'century_rider',
    title: 'Century Rider',
    description: 'Run 100 km total',
    category: AchievementCategory.distance,
    tier: AchievementTier.gold,
    iconEmoji: '🚀',
    checkCriteria: (userXP, stats, seasonXP) =>
        stats != null && stats.totalDistance >= 100.0,
    getProgressText: (userXP, stats, seasonXP) => stats != null &&
            stats.totalDistance >= 100.0
        ? 'Unlocked!'
        : '${stats?.totalDistance.toStringAsFixed(1) ?? 0}/100 km',
    getCurrentProgress: (userXP, stats, seasonXP) =>
        stats?.totalDistance.toInt() ?? 0,
    targetValue: 100,
  ),

  Achievement(
    id: 'distance_demon',
    title: 'Distance Demon',
    description: 'Run 500 km total',
    category: AchievementCategory.distance,
    tier: AchievementTier.gold,
    iconEmoji: '🔥',
    checkCriteria: (userXP, stats, seasonXP) =>
        stats != null && stats.totalDistance >= 500.0,
    getProgressText: (userXP, stats, seasonXP) => stats != null &&
            stats.totalDistance >= 500.0
        ? 'Unlocked!'
        : '${stats?.totalDistance.toStringAsFixed(0) ?? 0}/500 km',
    getCurrentProgress: (userXP, stats, seasonXP) =>
        stats?.totalDistance.toInt() ?? 0,
    targetValue: 500,
  ),

  Achievement(
    id: 'ultra_athlete',
    title: 'Ultra Athlete',
    description: 'Run 1,000 km total',
    category: AchievementCategory.distance,
    tier: AchievementTier.platinum,
    iconEmoji: '⚡',
    checkCriteria: (userXP, stats, seasonXP) =>
        stats != null && stats.totalDistance >= 1000.0,
    getProgressText: (userXP, stats, seasonXP) => stats != null &&
            stats.totalDistance >= 1000.0
        ? 'Unlocked!'
        : '${stats?.totalDistance.toStringAsFixed(0) ?? 0}/1,000 km',
    getCurrentProgress: (userXP, stats, seasonXP) =>
        stats?.totalDistance.toInt() ?? 0,
    targetValue: 1000,
  ),

  Achievement(
    id: 'step_starter',
    title: 'Step Starter',
    description: 'Take 10,000 steps',
    category: AchievementCategory.distance,
    tier: AchievementTier.bronze,
    iconEmoji: '👣',
    checkCriteria: (userXP, stats, seasonXP) =>
        stats != null && stats.totalSteps >= 10000,
    getProgressText: (userXP, stats, seasonXP) => stats != null &&
            stats.totalSteps >= 10000
        ? 'Unlocked!'
        : '${stats?.totalSteps ?? 0}/10,000 steps',
    getCurrentProgress: (userXP, stats, seasonXP) => stats?.totalSteps ?? 0,
    targetValue: 10000,
  ),

  Achievement(
    id: 'step_master',
    title: 'Step Master',
    description: 'Take 100,000 steps',
    category: AchievementCategory.distance,
    tier: AchievementTier.silver,
    iconEmoji: '🦶',
    checkCriteria: (userXP, stats, seasonXP) =>
        stats != null && stats.totalSteps >= 100000,
    getProgressText: (userXP, stats, seasonXP) => stats != null &&
            stats.totalSteps >= 100000
        ? 'Unlocked!'
        : '${stats?.totalSteps ?? 0}/100,000 steps',
    getCurrentProgress: (userXP, stats, seasonXP) => stats?.totalSteps ?? 0,
    targetValue: 100000,
  ),

  Achievement(
    id: 'step_million',
    title: 'Step Million',
    description: 'Take 1,000,000 steps',
    category: AchievementCategory.distance,
    tier: AchievementTier.gold,
    iconEmoji: '🌟',
    checkCriteria: (userXP, stats, seasonXP) =>
        stats != null && stats.totalSteps >= 1000000,
    getProgressText: (userXP, stats, seasonXP) => stats != null &&
            stats.totalSteps >= 1000000
        ? 'Unlocked!'
        : '${stats?.totalSteps ?? 0}/1,000,000 steps',
    getCurrentProgress: (userXP, stats, seasonXP) => stats?.totalSteps ?? 0,
    targetValue: 1000000,
  ),

  Achievement(
    id: 'step_legend',
    title: 'Step Legend',
    description: 'Take 10,000,000 steps',
    category: AchievementCategory.distance,
    tier: AchievementTier.platinum,
    iconEmoji: '💫',
    checkCriteria: (userXP, stats, seasonXP) =>
        stats != null && stats.totalSteps >= 10000000,
    getProgressText: (userXP, stats, seasonXP) => stats != null &&
            stats.totalSteps >= 10000000
        ? 'Unlocked!'
        : '${stats?.totalSteps ?? 0}/10,000,000 steps',
    getCurrentProgress: (userXP, stats, seasonXP) => stats?.totalSteps ?? 0,
    targetValue: 10000000,
  ),

  // ===== CONSISTENCY ACHIEVEMENTS =====
  Achievement(
    id: 'active_week',
    title: 'Active Week',
    description: 'Stay active for 7 days',
    category: AchievementCategory.consistency,
    tier: AchievementTier.bronze,
    iconEmoji: '📅',
    checkCriteria: (userXP, stats, seasonXP) =>
        stats != null && stats.totalDays >= 7,
    getProgressText: (userXP, stats, seasonXP) =>
        stats != null && stats.totalDays >= 7
            ? 'Unlocked!'
            : '${stats?.totalDays ?? 0}/7 days',
    getCurrentProgress: (userXP, stats, seasonXP) => stats?.totalDays ?? 0,
    targetValue: 7,
  ),

  Achievement(
    id: 'active_month',
    title: 'Active Month',
    description: 'Stay active for 30 days',
    category: AchievementCategory.consistency,
    tier: AchievementTier.silver,
    iconEmoji: '🗓️',
    checkCriteria: (userXP, stats, seasonXP) =>
        stats != null && stats.totalDays >= 30,
    getProgressText: (userXP, stats, seasonXP) =>
        stats != null && stats.totalDays >= 30
            ? 'Unlocked!'
            : '${stats?.totalDays ?? 0}/30 days',
    getCurrentProgress: (userXP, stats, seasonXP) => stats?.totalDays ?? 0,
    targetValue: 30,
  ),

  Achievement(
    id: 'active_quarter',
    title: 'Active Quarter',
    description: 'Stay active for 90 days',
    category: AchievementCategory.consistency,
    tier: AchievementTier.gold,
    iconEmoji: '📆',
    checkCriteria: (userXP, stats, seasonXP) =>
        stats != null && stats.totalDays >= 90,
    getProgressText: (userXP, stats, seasonXP) =>
        stats != null && stats.totalDays >= 90
            ? 'Unlocked!'
            : '${stats?.totalDays ?? 0}/90 days',
    getCurrentProgress: (userXP, stats, seasonXP) => stats?.totalDays ?? 0,
    targetValue: 90,
  ),

  Achievement(
    id: 'active_year',
    title: 'Active Year',
    description: 'Stay active for 365 days',
    category: AchievementCategory.consistency,
    tier: AchievementTier.platinum,
    iconEmoji: '🎊',
    checkCriteria: (userXP, stats, seasonXP) =>
        stats != null && stats.totalDays >= 365,
    getProgressText: (userXP, stats, seasonXP) =>
        stats != null && stats.totalDays >= 365
            ? 'Unlocked!'
            : '${stats?.totalDays ?? 0}/365 days',
    getCurrentProgress: (userXP, stats, seasonXP) => stats?.totalDays ?? 0,
    targetValue: 365,
  ),

  // ===== ELITE & RANKINGS ACHIEVEMENTS =====
  Achievement(
    id: 'top_100',
    title: 'Top 100 Global',
    description: 'Reach top 100 globally',
    category: AchievementCategory.elite,
    tier: AchievementTier.silver,
    iconEmoji: '🌍',
    checkCriteria: (userXP, stats, seasonXP) =>
        userXP.globalRank != null && userXP.globalRank! <= 100,
    getProgressText: (userXP, stats, seasonXP) =>
        userXP.globalRank != null && userXP.globalRank! <= 100
            ? 'Unlocked!'
            : 'Reach top 100 globally',
  ),

  Achievement(
    id: 'top_50',
    title: 'Top 50 Global',
    description: 'Reach top 50 globally',
    category: AchievementCategory.elite,
    tier: AchievementTier.gold,
    iconEmoji: '🌏',
    checkCriteria: (userXP, stats, seasonXP) =>
        userXP.globalRank != null && userXP.globalRank! <= 50,
    getProgressText: (userXP, stats, seasonXP) =>
        userXP.globalRank != null && userXP.globalRank! <= 50
            ? 'Unlocked!'
            : 'Reach top 50 globally',
  ),

  Achievement(
    id: 'top_10',
    title: 'Top 10 Global',
    description: 'Reach top 10 globally',
    category: AchievementCategory.elite,
    tier: AchievementTier.platinum,
    iconEmoji: '🏆',
    checkCriteria: (userXP, stats, seasonXP) =>
        userXP.globalRank != null && userXP.globalRank! <= 10,
    getProgressText: (userXP, stats, seasonXP) =>
        userXP.globalRank != null && userXP.globalRank! <= 10
            ? 'Unlocked!'
            : 'Reach top 10 globally',
  ),

  Achievement(
    id: 'country_leader',
    title: 'Country Leader',
    description: 'Reach top 10 in your country',
    category: AchievementCategory.elite,
    tier: AchievementTier.gold,
    iconEmoji: '🏳️',
    checkCriteria: (userXP, stats, seasonXP) =>
        userXP.countryRank != null && userXP.countryRank! <= 10,
    getProgressText: (userXP, stats, seasonXP) =>
        userXP.countryRank != null && userXP.countryRank! <= 10
            ? 'Unlocked!'
            : 'Reach top 10 in your country',
  ),

  Achievement(
    id: 'local_hero',
    title: 'Local Hero',
    description: 'Reach top 5 in your city',
    category: AchievementCategory.elite,
    tier: AchievementTier.silver,
    iconEmoji: '🏙️',
    checkCriteria: (userXP, stats, seasonXP) =>
        userXP.cityRank != null && userXP.cityRank! <= 5,
    getProgressText: (userXP, stats, seasonXP) =>
        userXP.cityRank != null && userXP.cityRank! <= 5
            ? 'Unlocked!'
            : 'Reach top 5 in your city',
  ),

  Achievement(
    id: 'season_champion',
    title: 'Season Champion',
    description: 'Rank #1 in seasonal XP',
    category: AchievementCategory.elite,
    tier: AchievementTier.platinum,
    iconEmoji: '👑',
    checkCriteria: (userXP, stats, seasonXP) =>
        seasonXP != null && seasonXP.seasonRank == 1,
    getProgressText: (userXP, stats, seasonXP) =>
        seasonXP != null && seasonXP.seasonRank == 1
            ? 'Unlocked!'
            : 'Rank #1 in season',
  ),
];
