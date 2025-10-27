import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a competition season in the app
class Season {
  final String id;
  final String name;
  final int number;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final bool isCurrent;
  final String? description;
  final String? rewardDescription;
  final DateTime? createdAt;

  Season({
    required this.id,
    required this.name,
    required this.number,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.isCurrent = false,
    this.description,
    this.rewardDescription,
    this.createdAt,
  });

  /// Check if the season is currently ongoing
  bool get isOngoing {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate) && isActive;
  }

  /// Check if the season has ended
  bool get hasEnded {
    return DateTime.now().isAfter(endDate);
  }

  /// Get season duration in days
  int get durationDays {
    return endDate.difference(startDate).inDays;
  }

  /// Get remaining days if season is ongoing
  int? get remainingDays {
    if (!isOngoing) return null;
    return endDate.difference(DateTime.now()).inDays;
  }

  /// Get progress percentage (0-100)
  double get progressPercentage {
    if (!isOngoing) {
      return hasEnded ? 100.0 : 0.0;
    }
    final total = endDate.difference(startDate).inDays;
    final elapsed = DateTime.now().difference(startDate).inDays;
    return (elapsed / total * 100).clamp(0.0, 100.0);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'number': number,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isActive': isActive,
      'isCurrent': isCurrent,
      'description': description,
      'rewardDescription': rewardDescription,
      'createdAt': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'number': number,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
      'isCurrent': isCurrent,
      'description': description,
      'rewardDescription': rewardDescription,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      number: json['number'] ?? 1,
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      isActive: json['isActive'] ?? true,
      isCurrent: json['isCurrent'] ?? false,
      description: json['description'],
      rewardDescription: json['rewardDescription'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  factory Season.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Season(
      id: doc.id,
      name: data['name'] ?? '',
      number: data['number'] ?? 1,
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      isCurrent: data['isCurrent'] ?? false,
      description: data['description'],
      rewardDescription: data['rewardDescription'],
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
    );
  }

  Season copyWith({
    String? id,
    String? name,
    int? number,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    bool? isCurrent,
    String? description,
    String? rewardDescription,
    DateTime? createdAt,
  }) {
    return Season(
      id: id ?? this.id,
      name: name ?? this.name,
      number: number ?? this.number,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      isCurrent: isCurrent ?? this.isCurrent,
      description: description ?? this.description,
      rewardDescription: rewardDescription ?? this.rewardDescription,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Season(id: $id, name: $name, number: $number, isOngoing: $isOngoing)';
  }
}

/// Represents a user's XP data for a specific season
class SeasonXP {
  final String userId;
  final String seasonId;
  final int seasonXP;
  final int seasonRank;
  final int? globalSeasonRank;
  final int racesCompleted;
  final int racesWon;
  final int podiumFinishes;
  final DateTime? lastUpdated;

  SeasonXP({
    required this.userId,
    required this.seasonId,
    this.seasonXP = 0,
    this.seasonRank = 0,
    this.globalSeasonRank,
    this.racesCompleted = 0,
    this.racesWon = 0,
    this.podiumFinishes = 0,
    this.lastUpdated,
  });

  /// Calculate level from season XP
  int get level {
    return (seasonXP / 1000).floor() + 1;
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'seasonId': seasonId,
      'seasonXP': seasonXP,
      'seasonRank': seasonRank,
      'globalSeasonRank': globalSeasonRank,
      'racesCompleted': racesCompleted,
      'racesWon': racesWon,
      'podiumFinishes': podiumFinishes,
      'lastUpdated': lastUpdated?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'seasonId': seasonId,
      'seasonXP': seasonXP,
      'seasonRank': seasonRank,
      'globalSeasonRank': globalSeasonRank,
      'racesCompleted': racesCompleted,
      'racesWon': racesWon,
      'podiumFinishes': podiumFinishes,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  factory SeasonXP.fromJson(Map<String, dynamic> json) {
    return SeasonXP(
      userId: json['userId'] ?? '',
      seasonId: json['seasonId'] ?? '',
      seasonXP: json['seasonXP'] ?? 0,
      seasonRank: json['seasonRank'] ?? 0,
      globalSeasonRank: json['globalSeasonRank'],
      racesCompleted: json['racesCompleted'] ?? 0,
      racesWon: json['racesWon'] ?? 0,
      podiumFinishes: json['podiumFinishes'] ?? 0,
      lastUpdated: json['lastUpdated'] != null ? DateTime.parse(json['lastUpdated']) : null,
    );
  }

  factory SeasonXP.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SeasonXP(
      userId: data['userId'] ?? doc.id,
      seasonId: data['seasonId'] ?? '',
      seasonXP: data['seasonXP'] ?? 0,
      seasonRank: data['seasonRank'] ?? 0,
      globalSeasonRank: data['globalSeasonRank'],
      racesCompleted: data['racesCompleted'] ?? 0,
      racesWon: data['racesWon'] ?? 0,
      podiumFinishes: data['podiumFinishes'] ?? 0,
      lastUpdated: data['lastUpdated'] != null ? (data['lastUpdated'] as Timestamp).toDate() : null,
    );
  }

  SeasonXP copyWith({
    String? userId,
    String? seasonId,
    int? seasonXP,
    int? seasonRank,
    int? globalSeasonRank,
    int? racesCompleted,
    int? racesWon,
    int? podiumFinishes,
    DateTime? lastUpdated,
  }) {
    return SeasonXP(
      userId: userId ?? this.userId,
      seasonId: seasonId ?? this.seasonId,
      seasonXP: seasonXP ?? this.seasonXP,
      seasonRank: seasonRank ?? this.seasonRank,
      globalSeasonRank: globalSeasonRank ?? this.globalSeasonRank,
      racesCompleted: racesCompleted ?? this.racesCompleted,
      racesWon: racesWon ?? this.racesWon,
      podiumFinishes: podiumFinishes ?? this.podiumFinishes,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() {
    return 'SeasonXP(userId: $userId, seasonId: $seasonId, seasonXP: $seasonXP, rank: $seasonRank)';
  }
}