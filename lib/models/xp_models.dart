import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user's total XP and ranking information
class UserXP {
  final String userId;
  final int totalXP;
  final int level;
  final int? globalRank;
  final int? countryRank;
  final int? cityRank;
  final String? country;
  final String? city;
  final int racesCompleted;
  final int racesWon;
  final int podiumFinishes; // Top 3 finishes
  final DateTime? lastUpdated;
  final DateTime? createdAt;

  UserXP({
    required this.userId,
    this.totalXP = 0,
    this.level = 1,
    this.globalRank,
    this.countryRank,
    this.cityRank,
    this.country,
    this.city,
    this.racesCompleted = 0,
    this.racesWon = 0,
    this.podiumFinishes = 0,
    this.lastUpdated,
    this.createdAt,
  });

  /// Calculate level from total XP (every 1000 XP = 1 level)
  static int calculateLevel(int xp) {
    return (xp / 1000).floor() + 1;
  }

  /// Calculate XP needed for next level
  int get xpForNextLevel {
    return level * 1000;
  }

  /// Calculate XP progress within current level (0.0 to 1.0)
  double get levelProgress {
    final xpInCurrentLevel = totalXP % 1000;
    return xpInCurrentLevel / 1000.0;
  }

  /// Calculate XP remaining to next level
  int get xpToNextLevel {
    return xpForNextLevel - (totalXP % 1000);
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'totalXP': totalXP,
      'level': level,
      'globalRank': globalRank,
      'countryRank': countryRank,
      'cityRank': cityRank,
      'country': country,
      'city': city,
      'racesCompleted': racesCompleted,
      'racesWon': racesWon,
      'podiumFinishes': podiumFinishes,
      'lastUpdated': lastUpdated?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'createdAt': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'totalXP': totalXP,
      'level': level,
      'globalRank': globalRank,
      'countryRank': countryRank,
      'cityRank': cityRank,
      'country': country,
      'city': city,
      'racesCompleted': racesCompleted,
      'racesWon': racesWon,
      'podiumFinishes': podiumFinishes,
      'lastUpdated': FieldValue.serverTimestamp(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory UserXP.fromJson(Map<String, dynamic> json) {
    return UserXP(
      userId: json['userId'] ?? '',
      totalXP: json['totalXP'] ?? 0,
      level: json['level'] ?? 1,
      globalRank: json['globalRank'],
      countryRank: json['countryRank'],
      cityRank: json['cityRank'],
      country: json['country'],
      city: json['city'],
      racesCompleted: json['racesCompleted'] ?? 0,
      racesWon: json['racesWon'] ?? 0,
      podiumFinishes: json['podiumFinishes'] ?? 0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }

  factory UserXP.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserXP(
      userId: doc.id,
      totalXP: data['totalXP'] ?? 0,
      level: data['level'] ?? 1,
      globalRank: data['globalRank'],
      countryRank: data['countryRank'],
      cityRank: data['cityRank'],
      country: data['country'],
      city: data['city'],
      racesCompleted: data['racesCompleted'] ?? 0,
      racesWon: data['racesWon'] ?? 0,
      podiumFinishes: data['podiumFinishes'] ?? 0,
      lastUpdated: data['lastUpdated'] != null
          ? (data['lastUpdated'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  UserXP copyWith({
    String? userId,
    int? totalXP,
    int? level,
    int? globalRank,
    int? countryRank,
    int? cityRank,
    String? country,
    String? city,
    int? racesCompleted,
    int? racesWon,
    int? podiumFinishes,
    DateTime? lastUpdated,
    DateTime? createdAt,
  }) {
    return UserXP(
      userId: userId ?? this.userId,
      totalXP: totalXP ?? this.totalXP,
      level: level ?? this.level,
      globalRank: globalRank ?? this.globalRank,
      countryRank: countryRank ?? this.countryRank,
      cityRank: cityRank ?? this.cityRank,
      country: country ?? this.country,
      city: city ?? this.city,
      racesCompleted: racesCompleted ?? this.racesCompleted,
      racesWon: racesWon ?? this.racesWon,
      podiumFinishes: podiumFinishes ?? this.podiumFinishes,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'UserXP(userId: $userId, totalXP: $totalXP, level: $level, globalRank: $globalRank)';
  }
}

/// Represents XP earned from a specific race
class RaceXPResult {
  final String raceId;
  final String userId;
  final int participationXP;
  final int placementXP;
  final int bonusXP;
  final int totalXP;
  final int rank;
  final double distance;
  final double avgSpeed;
  final String raceTitle;
  final DateTime earnedAt;
  final XPBreakdown breakdown;

  RaceXPResult({
    required this.raceId,
    required this.userId,
    required this.participationXP,
    required this.placementXP,
    required this.bonusXP,
    required this.totalXP,
    required this.rank,
    required this.distance,
    required this.avgSpeed,
    required this.raceTitle,
    DateTime? earnedAt,
    required this.breakdown,
  }) : earnedAt = earnedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'raceId': raceId,
      'userId': userId,
      'participationXP': participationXP,
      'placementXP': placementXP,
      'bonusXP': bonusXP,
      'totalXP': totalXP,
      'rank': rank,
      'distance': distance,
      'avgSpeed': avgSpeed,
      'raceTitle': raceTitle,
      'earnedAt': earnedAt.toIso8601String(),
      'breakdown': breakdown.toJson(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'raceId': raceId,
      'userId': userId,
      'participationXP': participationXP,
      'placementXP': placementXP,
      'bonusXP': bonusXP,
      'totalXP': totalXP,
      'rank': rank,
      'distance': distance,
      'avgSpeed': avgSpeed,
      'raceTitle': raceTitle,
      'earnedAt': Timestamp.fromDate(earnedAt),
      'breakdown': breakdown.toJson(),
    };
  }

  factory RaceXPResult.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RaceXPResult(
      raceId: data['raceId'] ?? '',
      userId: data['userId'] ?? '',
      participationXP: data['participationXP'] ?? 0,
      placementXP: data['placementXP'] ?? 0,
      bonusXP: data['bonusXP'] ?? 0,
      totalXP: data['totalXP'] ?? 0,
      rank: data['rank'] ?? 0,
      distance: (data['distance'] ?? 0.0).toDouble(),
      avgSpeed: (data['avgSpeed'] ?? 0.0).toDouble(),
      raceTitle: data['raceTitle'] ?? '',
      earnedAt: (data['earnedAt'] as Timestamp).toDate(),
      breakdown: XPBreakdown.fromJson(data['breakdown'] ?? {}),
    );
  }

  @override
  String toString() {
    return 'RaceXPResult(raceId: $raceId, userId: $userId, totalXP: $totalXP, rank: $rank)';
  }
}

/// Detailed breakdown of XP calculation
class XPBreakdown {
  final int baseXP;
  final double distanceMultiplier;
  final int participationXP;
  final int placementXP;
  final int bonusXP;
  final String bonusReason;

  XPBreakdown({
    required this.baseXP,
    required this.distanceMultiplier,
    required this.participationXP,
    required this.placementXP,
    this.bonusXP = 0,
    this.bonusReason = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'baseXP': baseXP,
      'distanceMultiplier': distanceMultiplier,
      'participationXP': participationXP,
      'placementXP': placementXP,
      'bonusXP': bonusXP,
      'bonusReason': bonusReason,
    };
  }

  factory XPBreakdown.fromJson(Map<String, dynamic> json) {
    return XPBreakdown(
      baseXP: json['baseXP'] ?? 0,
      distanceMultiplier: (json['distanceMultiplier'] ?? 1.0).toDouble(),
      participationXP: json['participationXP'] ?? 0,
      placementXP: json['placementXP'] ?? 0,
      bonusXP: json['bonusXP'] ?? 0,
      bonusReason: json['bonusReason'] ?? '',
    );
  }
}

/// Represents an individual XP transaction (for history/audit trail)
class XPTransaction {
  final String? id;
  final String userId;
  final int xpAmount;
  final String source; // 'race_completion', 'bonus', 'penalty', etc.
  final String? sourceId; // Race ID or other reference
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  XPTransaction({
    this.id,
    required this.userId,
    required this.xpAmount,
    required this.source,
    this.sourceId,
    required this.description,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'xpAmount': xpAmount,
      'source': source,
      'sourceId': sourceId,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'xpAmount': xpAmount,
      'source': source,
      'sourceId': sourceId,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }

  factory XPTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return XPTransaction(
      id: doc.id,
      userId: data['userId'] ?? '',
      xpAmount: data['xpAmount'] ?? 0,
      source: data['source'] ?? '',
      sourceId: data['sourceId'],
      description: data['description'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      metadata: data['metadata'],
    );
  }

  @override
  String toString() {
    return 'XPTransaction(userId: $userId, xpAmount: $xpAmount, source: $source, timestamp: $timestamp)';
  }
}

/// Leaderboard entry combining user info with XP data
class LeaderboardEntry {
  final String userId;
  final String userName;
  final String? profilePicture;
  final int totalXP;
  final int level;
  final int rank;
  final int racesCompleted;
  final int racesWon;
  final int podiumFinishes;
  final String? country;
  final String? city;

  LeaderboardEntry({
    required this.userId,
    required this.userName,
    this.profilePicture,
    required this.totalXP,
    required this.level,
    required this.rank,
    this.racesCompleted = 0,
    this.racesWon = 0,
    this.podiumFinishes = 0,
    this.country,
    this.city,
  });

  factory LeaderboardEntry.fromUserXP(UserXP userXP, {
    required String userName,
    String? profilePicture,
    required int rank,
  }) {
    return LeaderboardEntry(
      userId: userXP.userId,
      userName: userName,
      profilePicture: profilePicture,
      totalXP: userXP.totalXP,
      level: userXP.level,
      rank: rank,
      racesCompleted: userXP.racesCompleted,
      racesWon: userXP.racesWon,
      podiumFinishes: userXP.podiumFinishes,
      country: userXP.country,
      city: userXP.city,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'profilePicture': profilePicture,
      'totalXP': totalXP,
      'level': level,
      'rank': rank,
      'racesCompleted': racesCompleted,
      'racesWon': racesWon,
      'podiumFinishes': podiumFinishes,
      'country': country,
      'city': city,
    };
  }

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? 'Unknown',
      profilePicture: json['profilePicture'],
      totalXP: json['totalXP'] ?? 0,
      level: json['level'] ?? 1,
      rank: json['rank'] ?? 0,
      racesCompleted: json['racesCompleted'] ?? 0,
      racesWon: json['racesWon'] ?? 0,
      podiumFinishes: json['podiumFinishes'] ?? 0,
      country: json['country'],
      city: json['city'],
    );
  }

  @override
  String toString() {
    return 'LeaderboardEntry(rank: $rank, userName: $userName, totalXP: $totalXP)';
  }
}