import 'package:stepzsync/models/xp_models.dart';

/// Leaderboard metadata and configuration models
///
/// Note: Core leaderboard models (LeaderboardEntry, UserXP) are in xp_models.dart
/// This file contains supplementary models for leaderboard features

/// Represents leaderboard statistics and metadata
class LeaderboardStats {
  final int totalUsers;
  final int totalXP;
  final int averageXP;
  final int highestXP;
  final int totalRacesCompleted;
  final String? topUser;
  final int? topUserXP;
  final DateTime lastUpdated;

  LeaderboardStats({
    required this.totalUsers,
    required this.totalXP,
    required this.averageXP,
    required this.highestXP,
    required this.totalRacesCompleted,
    this.topUser,
    this.topUserXP,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'totalUsers': totalUsers,
      'totalXP': totalXP,
      'averageXP': averageXP,
      'highestXP': highestXP,
      'totalRacesCompleted': totalRacesCompleted,
      'topUser': topUser,
      'topUserXP': topUserXP,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory LeaderboardStats.fromJson(Map<String, dynamic> json) {
    return LeaderboardStats(
      totalUsers: json['totalUsers'] ?? 0,
      totalXP: json['totalXP'] ?? 0,
      averageXP: json['averageXP'] ?? 0,
      highestXP: json['highestXP'] ?? 0,
      totalRacesCompleted: json['totalRacesCompleted'] ?? 0,
      topUser: json['topUser'],
      topUserXP: json['topUserXP'],
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'LeaderboardStats(totalUsers: $totalUsers, averageXP: $averageXP, topUser: $topUser)';
  }
}

/// Represents a leaderboard page with pagination info
class LeaderboardPage {
  final List<LeaderboardEntry> entries;
  final int pageNumber;
  final int pageSize;
  final int totalEntries;
  final bool hasMore;

  LeaderboardPage({
    required this.entries,
    required this.pageNumber,
    required this.pageSize,
    required this.totalEntries,
    required this.hasMore,
  });

  /// Check if there's a next page
  bool get hasNextPage => hasMore;

  /// Check if there's a previous page
  bool get hasPreviousPage => pageNumber > 1;

  /// Get total number of pages
  int get totalPages => (totalEntries / pageSize).ceil();

  Map<String, dynamic> toJson() {
    return {
      'entries': entries.map((e) => e.toJson()).toList(),
      'pageNumber': pageNumber,
      'pageSize': pageSize,
      'totalEntries': totalEntries,
      'hasMore': hasMore,
    };
  }

  @override
  String toString() {
    return 'LeaderboardPage(page: $pageNumber/$totalPages, entries: ${entries.length})';
  }
}

/// Represents user's position change in leaderboard
class RankChange {
  final String userId;
  final int previousRank;
  final int currentRank;
  final int change; // Positive = improved, Negative = dropped
  final DateTime timestamp;

  RankChange({
    required this.userId,
    required this.previousRank,
    required this.currentRank,
    DateTime? timestamp,
  })  : change = previousRank - currentRank,
        timestamp = timestamp ?? DateTime.now();

  /// Check if rank improved
  bool get improved => change > 0;

  /// Check if rank dropped
  bool get dropped => change < 0;

  /// Check if rank stayed same
  bool get unchanged => change == 0;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'previousRank': previousRank,
      'currentRank': currentRank,
      'change': change,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory RankChange.fromJson(Map<String, dynamic> json) {
    return RankChange(
      userId: json['userId'] ?? '',
      previousRank: json['previousRank'] ?? 0,
      currentRank: json['currentRank'] ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  @override
  String toString() {
    if (improved) {
      return 'RankChange(‘ $change: #$previousRank ’ #$currentRank)';
    } else if (dropped) {
      return 'RankChange(“ ${change.abs()}: #$previousRank ’ #$currentRank)';
    } else {
      return 'RankChange(’ unchanged: #$currentRank)';
    }
  }
}

/// Leaderboard view configuration
class LeaderboardConfig {
  final String scope; // 'global', 'country', 'city', 'friends'
  final String? filterValue; // Country/city name if applicable
  final String? seasonId; // Null for lifetime leaderboard
  final int pageSize;
  final bool showOnlyActive; // Show only users active in last X days

  const LeaderboardConfig({
    required this.scope,
    this.filterValue,
    this.seasonId,
    this.pageSize = 50,
    this.showOnlyActive = false,
  });

  LeaderboardConfig copyWith({
    String? scope,
    String? filterValue,
    String? seasonId,
    int? pageSize,
    bool? showOnlyActive,
  }) {
    return LeaderboardConfig(
      scope: scope ?? this.scope,
      filterValue: filterValue ?? this.filterValue,
      seasonId: seasonId ?? this.seasonId,
      pageSize: pageSize ?? this.pageSize,
      showOnlyActive: showOnlyActive ?? this.showOnlyActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scope': scope,
      'filterValue': filterValue,
      'seasonId': seasonId,
      'pageSize': pageSize,
      'showOnlyActive': showOnlyActive,
    };
  }

  @override
  String toString() {
    return 'LeaderboardConfig(scope: $scope, filter: $filterValue, season: $seasonId)';
  }
}

/// User's leaderboard achievements
class LeaderboardAchievement {
  final String id;
  final String title;
  final String description;
  final String iconUrl;
  final DateTime earnedAt;
  final String category; // 'rank', 'xp', 'streak', etc.

  const LeaderboardAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconUrl,
    required this.earnedAt,
    required this.category,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'iconUrl': iconUrl,
      'earnedAt': earnedAt.toIso8601String(),
      'category': category,
    };
  }

  factory LeaderboardAchievement.fromJson(Map<String, dynamic> json) {
    return LeaderboardAchievement(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      iconUrl: json['iconUrl'] ?? '',
      earnedAt: json['earnedAt'] != null
          ? DateTime.parse(json['earnedAt'])
          : DateTime.now(),
      category: json['category'] ?? 'general',
    );
  }

  @override
  String toString() {
    return 'Achievement($title - $category)';
  }
}
