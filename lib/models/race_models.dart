import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/models/race_data_model.dart';

class RaceModel {
  final String? id;
  final String title;
  final String orgName;
  final DateTime createdTime;
  final String startAddress;
  final String endAddress;
  final String raceType;
  final double totalDistance;
  final String genderPrefrence;
  final String raceStoppingTime;
  final int totalParticipant;
  final int partcipantLimit;
  final String scheduleTime;
  final double startLatitude;
  final double startLongitude;
  final double endLatitude;
  final double endLongitude;
  final String? bannerUrl;
  final String? createdBy;
  final List<Participant>? participants;
  final String? status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final bool? hasBot; // Quick race with bot competitors
  final List<String>? botParticipants; // Bot participant IDs
  // Race Status Management
  final int statusId; // 0=pending, 2=countdown, 3=active, 4=completed, 6=deadline
  final DateTime? raceDeadline; // Deadline for race completion
  final DateTime? actualStartTime; // When race actually started
  final DateTime? actualEndTime; // When race actually ended

  RaceModel({
    this.id,
    required this.title,
    required this.orgName,
    required this.createdTime,
    required this.startAddress,
    required this.endAddress,
    required this.raceType,
    required this.totalDistance,
    required this.genderPrefrence,
    required this.raceStoppingTime,
    required this.totalParticipant,
    required this.partcipantLimit,
    required this.scheduleTime,
    required this.startLatitude,
    required this.startLongitude,
    required this.endLatitude,
    required this.endLongitude,
    this.bannerUrl,
    this.createdBy,
    this.participants,
    this.status = 'scheduled',
    this.startedAt,
    this.endedAt,
    this.hasBot = false,
    this.botParticipants,
    // Race Status Management
    this.statusId = 0, // Default to pending
    this.raceDeadline,
    this.actualStartTime,
    this.actualEndTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'orgName': orgName,
      'createdTime': createdTime.toIso8601String(),
      'startAddress': startAddress,
      'endAddress': endAddress,
      'raceType': raceType,
      'totalDistance': totalDistance,
      'genderPrefrence': genderPrefrence,
      'raceStoppingTime': raceStoppingTime,
      'totalParticipant': totalParticipant,
      'partcipantLimit': partcipantLimit,
      'scheduleTime': scheduleTime,
      'startLatitude': startLatitude,
      'startLongitude': startLongitude,
      'endLatitude': endLatitude,
      'endLongitude': endLongitude,
      'bannerUrl': bannerUrl,
      'createdBy': createdBy,
      'participants': participants?.map((p) => p.toJson()).toList() ?? [],
      'status': status,
      'startedAt': startedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'hasBot': hasBot,
      'botParticipants': botParticipants ?? [],
      // Race Status Management
      'statusId': statusId,
      'raceDeadline': raceDeadline?.toIso8601String(),
      'actualStartTime': actualStartTime?.toIso8601String(),
      'actualEndTime': actualEndTime?.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'orgName': orgName,
      'createdTime': Timestamp.fromDate(createdTime),
      'startAddress': startAddress,
      'endAddress': endAddress,
      'raceType': raceType,
      'totalDistance': totalDistance,
      'genderPrefrence': genderPrefrence,
      'raceStoppingTime': raceStoppingTime,
      'totalParticipant': totalParticipant,
      'partcipantLimit': partcipantLimit,
      'scheduleTime': scheduleTime,
      'startLatitude': startLatitude,
      'startLongitude': startLongitude,
      'endLatitude': endLatitude,
      'endLongitude': endLongitude,
      'bannerUrl': bannerUrl,
      'createdBy': createdBy,
      'participants': participants?.map((p) => p.toFirestore()).toList() ?? [],
      'status': status,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'hasBot': hasBot,
      'botParticipants': botParticipants ?? [],
      // Race Status Management
      'statusId': statusId,
      'raceDeadline': raceDeadline != null ? Timestamp.fromDate(raceDeadline!) : null,
      'actualStartTime': actualStartTime != null ? Timestamp.fromDate(actualStartTime!) : null,
      'actualEndTime': actualEndTime != null ? Timestamp.fromDate(actualEndTime!) : null,
    };
  }

  factory RaceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RaceModel(
      id: doc.id,
      title: data['title'] ?? '',
      orgName: data['orgName'] ?? '',
      createdTime: (data['createdTime'] as Timestamp).toDate(),
      startAddress: data['startAddress'] ?? '',
      endAddress: data['endAddress'] ?? '',
      raceType: data['raceType'] ?? '',
      totalDistance: (data['totalDistance'] ?? 0.0).toDouble(),
      genderPrefrence: data['genderPrefrence'] ?? '',
      raceStoppingTime: data['raceStoppingTime'] ?? '',
      totalParticipant: data['totalParticipant'] ?? 0,
      partcipantLimit: data['partcipantLimit'] ?? 0,
      scheduleTime: data['scheduleTime'] ?? '',
      startLatitude: (data['startLatitude'] ?? 0.0).toDouble(),
      startLongitude: (data['startLongitude'] ?? 0.0).toDouble(),
      endLatitude: (data['endLatitude'] ?? 0.0).toDouble(),
      endLongitude: (data['endLongitude'] ?? 0.0).toDouble(),
      bannerUrl: data['bannerUrl'],
      createdBy: data['createdBy'],
      participants: data['participants'] != null
          ? RaceData.parseParticipants(data['participants'], (data['totalDistance'] ?? 0.0).toDouble())
          : null,
      status: data['status'] ?? 'scheduled',
      startedAt: data['startedAt'] != null ? (data['startedAt'] as Timestamp).toDate() : null,
      endedAt: data['endedAt'] != null ? (data['endedAt'] as Timestamp).toDate() : null,
      hasBot: data['hasBot'] ?? false,
      botParticipants: data['botParticipants'] != null ? List<String>.from(data['botParticipants']) : null,
      // Race Status Management
      statusId: data['statusId'] ?? 0,
      raceDeadline: data['raceDeadline'] != null ? (data['raceDeadline'] as Timestamp).toDate() : null,
      actualStartTime: data['actualStartTime'] != null ? (data['actualStartTime'] as Timestamp).toDate() : null,
      actualEndTime: data['actualEndTime'] != null ? (data['actualEndTime'] as Timestamp).toDate() : null,
    );
  }

  RaceModel copyWith({
    String? id,
    String? title,
    String? orgName,
    DateTime? createdTime,
    String? startAddress,
    String? endAddress,
    String? raceType,
    double? totalDistance,
    String? genderPrefrence,
    String? raceStoppingTime,
    int? totalParticipant,
    int? partcipantLimit,
    String? scheduleTime,
    double? startLatitude,
    double? startLongitude,
    double? endLatitude,
    double? endLongitude,
    String? bannerUrl,
    String? createdBy,
    List<Participant>? participants,
    String? status,
    DateTime? startedAt,
    DateTime? endedAt,
    bool? hasBot,
    List<String>? botParticipants,
    // Race Status Management
    int? statusId,
    DateTime? raceDeadline,
    DateTime? actualStartTime,
    DateTime? actualEndTime,
  }) {
    return RaceModel(
      id: id ?? this.id,
      title: title ?? this.title,
      orgName: orgName ?? this.orgName,
      createdTime: createdTime ?? this.createdTime,
      startAddress: startAddress ?? this.startAddress,
      endAddress: endAddress ?? this.endAddress,
      raceType: raceType ?? this.raceType,
      totalDistance: totalDistance ?? this.totalDistance,
      genderPrefrence: genderPrefrence ?? this.genderPrefrence,
      raceStoppingTime: raceStoppingTime ?? this.raceStoppingTime,
      totalParticipant: totalParticipant ?? this.totalParticipant,
      partcipantLimit: partcipantLimit ?? this.partcipantLimit,
      scheduleTime: scheduleTime ?? this.scheduleTime,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      createdBy: createdBy ?? this.createdBy,
      participants: participants ?? this.participants,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      hasBot: hasBot ?? this.hasBot,
      botParticipants: botParticipants ?? this.botParticipants,
      // Race Status Management
      statusId: statusId ?? this.statusId,
      raceDeadline: raceDeadline ?? this.raceDeadline,
      actualStartTime: actualStartTime ?? this.actualStartTime,
      actualEndTime: actualEndTime ?? this.actualEndTime,
    );
  }

  @override
  String toString() {
    return 'RaceModel(id: $id, title: $title, orgName: $orgName, createdTime: $createdTime, startAddress: $startAddress, endAddress: $endAddress, raceType: $raceType, totalDistance: $totalDistance, genderPrefrence: $genderPrefrence, raceStoppingTime: $raceStoppingTime, totalParticipant: $totalParticipant, partcipantLimit: $partcipantLimit, scheduleTime: $scheduleTime, startLatitude: $startLatitude, startLongitude: $startLongitude, endLatitude: $endLatitude, endLongitude: $endLongitude, bannerUrl: $bannerUrl, createdBy: $createdBy, participants: $participants, status: $status)';
  }
}

class RaceParticipantModel {
  final String userId;
  final String raceId;
  final int steps;
  final double distance;
  final int calories;
  final double avgSpeed;
  final bool isCompleted;
  final String status; // joined, active, completed, left
  final int rank;
  final DateTime joinedAt;
  final DateTime? completedAt;
  final DateTime? lastUpdated;
  // Additional fields for SignalR compatibility
  final String? userName;
  final double remainingDistance;
  final String? userProfilePicture;
  final int? stepsAtStart; // Steps at race start for tracking race progress

  RaceParticipantModel({
    required this.userId,
    required this.raceId,
    this.steps = 0,
    this.distance = 0.0,
    this.calories = 0,
    this.avgSpeed = 0.0,
    this.isCompleted = false,
    this.status = 'joined',
    this.rank = 1,
    required this.joinedAt,
    this.completedAt,
    this.lastUpdated,
    // Additional fields for SignalR compatibility
    this.userName,
    this.remainingDistance = 0.0,
    this.userProfilePicture,
    this.stepsAtStart,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'raceId': raceId,
      'steps': steps,
      'distance': distance,
      'calories': calories,
      'avgSpeed': avgSpeed,
      'isCompleted': isCompleted,
      'status': status,
      'rank': rank,
      'joinedAt': joinedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'lastUpdated': lastUpdated?.toIso8601String(),
      // Additional fields for SignalR compatibility
      'userName': userName,
      'remainingDistance': remainingDistance,
      'userProfilePicture': userProfilePicture,
      'stepsAtStart': stepsAtStart,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'raceId': raceId,
      'steps': steps,
      'distance': distance,
      'calories': calories,
      'avgSpeed': avgSpeed,
      'isCompleted': isCompleted,
      'status': status,
      'rank': rank,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'lastUpdated': lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
      // Additional fields for SignalR compatibility
      'userName': userName,
      'remainingDistance': remainingDistance,
      'userProfilePicture': userProfilePicture,
      'stepsAtStart': stepsAtStart,
    };
  }

  factory RaceParticipantModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RaceParticipantModel(
      userId: data['userId'] ?? '',
      raceId: data['raceId'] ?? '',
      steps: data['steps'] ?? 0,
      distance: (data['distance'] ?? 0.0).toDouble(),
      calories: data['calories'] ?? 0,
      avgSpeed: (data['avgSpeed'] ?? 0.0).toDouble(),
      isCompleted: data['isCompleted'] ?? false,
      status: data['status'] ?? 'joined',
      rank: data['rank'] ?? 1,
      joinedAt: (data['joinedAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
      lastUpdated: data['lastUpdated'] != null ? (data['lastUpdated'] as Timestamp).toDate() : null,
      // Additional fields for SignalR compatibility
      userName: data['userName'],
      remainingDistance: (data['remainingDistance'] ?? 0.0).toDouble(),
      userProfilePicture: data['userProfilePicture'],
      stepsAtStart: data['stepsAtStart'],
    );
  }

  factory RaceParticipantModel.fromJson(Map<String, dynamic> json) {
    return RaceParticipantModel(
      userId: json['userId'] ?? '',
      raceId: json['raceId'] ?? '',
      steps: json['steps'] ?? 0,
      distance: (json['distance'] ?? 0.0).toDouble(),
      calories: json['calories'] ?? 0,
      avgSpeed: (json['avgSpeed'] ?? 0.0).toDouble(),
      isCompleted: json['isCompleted'] ?? false,
      status: json['status'] ?? 'joined',
      rank: json['rank'] ?? 1,
      joinedAt: DateTime.parse(json['joinedAt']),
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      lastUpdated: json['lastUpdated'] != null ? DateTime.parse(json['lastUpdated']) : null,
      // Additional fields for SignalR compatibility
      userName: json['userName'],
      remainingDistance: (json['remainingDistance'] ?? 0.0).toDouble(),
      userProfilePicture: json['userProfilePicture'],
      stepsAtStart: json['stepsAtStart'],
    );
  }

  RaceParticipantModel copyWith({
    String? userId,
    String? raceId,
    int? steps,
    double? distance,
    int? calories,
    double? avgSpeed,
    bool? isCompleted,
    String? status,
    int? rank,
    DateTime? joinedAt,
    DateTime? completedAt,
    DateTime? lastUpdated,
    // Additional fields for SignalR compatibility
    String? userName,
    double? remainingDistance,
    String? userProfilePicture,
    int? stepsAtStart,
  }) {
    return RaceParticipantModel(
      userId: userId ?? this.userId,
      raceId: raceId ?? this.raceId,
      steps: steps ?? this.steps,
      distance: distance ?? this.distance,
      calories: calories ?? this.calories,
      avgSpeed: avgSpeed ?? this.avgSpeed,
      isCompleted: isCompleted ?? this.isCompleted,
      status: status ?? this.status,
      rank: rank ?? this.rank,
      joinedAt: joinedAt ?? this.joinedAt,
      completedAt: completedAt ?? this.completedAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      // Additional fields for SignalR compatibility
      userName: userName ?? this.userName,
      remainingDistance: remainingDistance ?? this.remainingDistance,
      userProfilePicture: userProfilePicture ?? this.userProfilePicture,
      stepsAtStart: stepsAtStart ?? this.stepsAtStart,
    );
  }

  @override
  String toString() {
    return 'RaceParticipantModel(userId: $userId, raceId: $raceId, steps: $steps, distance: $distance, calories: $calories, avgSpeed: $avgSpeed, isCompleted: $isCompleted, status: $status, rank: $rank, joinedAt: $joinedAt)';
  }
}

class UserRaceModel {
  final String userId;
  final String raceId;
  final String role; // creator, participant
  final String status; // joined, left, completed
  final DateTime joinedAt;
  final DateTime? leftAt;

  UserRaceModel({
    required this.userId,
    required this.raceId,
    required this.role,
    this.status = 'joined',
    required this.joinedAt,
    this.leftAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'raceId': raceId,
      'role': role,
      'status': status,
      'joinedAt': joinedAt.toIso8601String(),
      'leftAt': leftAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'raceId': raceId,
      'role': role,
      'status': status,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'leftAt': leftAt != null ? Timestamp.fromDate(leftAt!) : null,
    };
  }

  factory UserRaceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserRaceModel(
      userId: data['userId'] ?? '',
      raceId: data['raceId'] ?? '',
      role: data['role'] ?? 'participant',
      status: data['status'] ?? 'joined',
      joinedAt: (data['joinedAt'] as Timestamp).toDate(),
      leftAt: data['leftAt'] != null ? (data['leftAt'] as Timestamp).toDate() : null,
    );
  }

  factory UserRaceModel.fromJson(Map<String, dynamic> json) {
    return UserRaceModel(
      userId: json['userId'] ?? '',
      raceId: json['raceId'] ?? '',
      role: json['role'] ?? 'participant',
      status: json['status'] ?? 'joined',
      joinedAt: DateTime.parse(json['joinedAt']),
      leftAt: json['leftAt'] != null ? DateTime.parse(json['leftAt']) : null,
    );
  }

  UserRaceModel copyWith({
    String? userId,
    String? raceId,
    String? role,
    String? status,
    DateTime? joinedAt,
    DateTime? leftAt,
  }) {
    return UserRaceModel(
      userId: userId ?? this.userId,
      raceId: raceId ?? this.raceId,
      role: role ?? this.role,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      leftAt: leftAt ?? this.leftAt,
    );
  }

  @override
  String toString() {
    return 'UserRaceModel(userId: $userId, raceId: $raceId, role: $role, status: $status, joinedAt: $joinedAt)';
  }
}