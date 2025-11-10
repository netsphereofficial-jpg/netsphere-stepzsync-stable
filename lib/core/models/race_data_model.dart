import 'package:cloud_firestore/cloud_firestore.dart';

class RaceData {
  String? id;
  String? title;
  int? raceTypeId; // 1=Solo, 2=Private, 3=Public, 4=Marathon, 5=Quick Race
  int? maxParticipants;
  int? minParticipants;
  int? joinedParticipants;
  double? startLat;
  double? startLong;
  double? endLat;
  double? endLong;
  String? startAddress;
  String? endAddress;
  bool? isPrivate;
  String? raceScheduleTime;
  String? raceDeadline;
  int? durationHrs;
  int? durationMins; // Duration in minutes (preferred over durationHrs for accuracy)
  String? raceBanner;
  int? genderPreferenceId;
  String? organizerUserId;
  String? organizerName;
  double? totalDistance;
  int? statusId;
  String? status;
  int? currentRank;
  num? distanceCovered;
  num? remainingDistance;
  double? avgSpeed;
  List<Participant>? participants; // DEPRECATED: Use subcollection instead. Kept for backward compatibility during migration.
  List<Map<String, dynamic>>? leaderPreview; // Top 3 participants cached for quick display

  RaceData({
    this.id,
    this.title,
    this.raceTypeId,
    this.maxParticipants,
    this.minParticipants,
    this.joinedParticipants,
    this.startLat,
    this.startLong,
    this.endLat,
    this.endLong,
    this.startAddress,
    this.endAddress,
    this.isPrivate,
    this.raceScheduleTime,
    this.raceDeadline,
    this.durationHrs,
    this.durationMins,
    this.raceBanner,
    this.genderPreferenceId,
    this.organizerUserId,
    this.organizerName,
    this.totalDistance,
    this.statusId,
    this.status,
    this.currentRank,
    this.distanceCovered,
    this.remainingDistance,
    this.avgSpeed,
    this.participants,
    this.leaderPreview,
  });

  // JSON Serialization
  RaceData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    title = json['title'];
    raceTypeId = json['raceTypeId'];
    maxParticipants = json['maxParticipants'];
    minParticipants = json['minParticipants'];
    joinedParticipants = json['joinedParticipants'];
    startLat = (json['startLat'] as num?)?.toDouble();
    startLong = (json['startLong'] as num?)?.toDouble();
    endLat = (json['endLat'] as num?)?.toDouble();
    endLong = (json['endLong'] as num?)?.toDouble();
    startAddress = json['startAddress'];
    endAddress = json['endAddress'];
    isPrivate = json['isPrivate'];
    raceScheduleTime = json['raceScheduleTime'];
    raceDeadline = json['raceDeadline'];
    durationHrs = json['durationHrs'];
    durationMins = json['durationMins'];
    raceBanner = json['raceBanner'];
    genderPreferenceId = json['genderPreferenceId'];
    organizerUserId = json['organizerUserId'];
    organizerName = json['organizerName'];
    totalDistance = (json['totalDistance'] as num?)?.toDouble();
    statusId = json['statusId'];
    status = json['status'];
    currentRank = json['currentRank'];
    distanceCovered = (json['distanceCovered'] as num?)?.toDouble() ?? 0.0;
    remainingDistance = (json['distanceRemaining'] as num?)?.toDouble() ?? 0.0;
    avgSpeed = (json['avgSpeed'] as num?)?.toDouble() ?? 0.0;
    participants = json['participants'] != null
        ? parseParticipants(json['participants'], (json['totalDistance'] as num?)?.toDouble() ?? 0.0)
        : null;
    leaderPreview = json['leaderPreview'] != null
        ? List<Map<String, dynamic>>.from(json['leaderPreview'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['title'] = title;
    data['raceTypeId'] = raceTypeId;
    data['maxParticipants'] = maxParticipants;
    data['minParticipants'] = minParticipants;
    data['joinedParticipants'] = joinedParticipants;
    data['startLat'] = startLat;
    data['startLong'] = startLong;
    data['endLat'] = endLat;
    data['endLong'] = endLong;
    data['startAddress'] = startAddress;
    data['endAddress'] = endAddress;
    data['isPrivate'] = isPrivate;
    data['raceScheduleTime'] = raceScheduleTime;
    data['raceDeadline'] = raceDeadline;
    data['durationHrs'] = durationHrs;
    data['durationMins'] = durationMins;
    data['raceBanner'] = raceBanner;
    data['genderPreferenceId'] = genderPreferenceId;
    data['organizerUserId'] = organizerUserId;
    data['organizerName'] = organizerName;
    data['totalDistance'] = totalDistance;
    data['statusId'] = statusId;
    data['status'] = status;
    data['currentRank'] = currentRank;
    data['distanceCovered'] = distanceCovered;
    data['distanceRemaining'] = remainingDistance;
    data['avgSpeed'] = avgSpeed;
    if (participants != null) {
      data['participants'] = participants!.map((v) => v.toJson()).toList();
    }
    if (leaderPreview != null) {
      data['leaderPreview'] = leaderPreview;
    }
    return data;
  }

  // Firestore Serialization
  factory RaceData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RaceData.fromFirestoreMap(data, doc.id);
  }

  factory RaceData.fromFirestoreMap(
    Map<String, dynamic> data, [
    String? docId,
  ]) {
    return RaceData(
      id: docId ?? data['id'],
      title: data['title'],
      raceTypeId: data['raceTypeId'],
      maxParticipants: data['maxParticipants'],
      minParticipants: data['minParticipants'],
      joinedParticipants: data['joinedParticipants'],
      startLat: (data['startLat'] as num?)?.toDouble(),
      startLong: (data['startLong'] as num?)?.toDouble(),
      endLat: (data['endLat'] as num?)?.toDouble(),
      endLong: (data['endLong'] as num?)?.toDouble(),
      startAddress: data['startAddress'],
      endAddress: data['endAddress'],
      isPrivate: data['isPrivate'],
      raceScheduleTime: data['raceScheduleTime'] is Timestamp
          ? (data['raceScheduleTime'] as Timestamp).toDate().toIso8601String()
          : data['raceScheduleTime'],
      raceDeadline: data['raceDeadline'] is Timestamp
          ? (data['raceDeadline'] as Timestamp).toDate().toIso8601String()
          : data['raceDeadline'],
      durationHrs: data['durationHrs'],
      durationMins: data['durationMins'],
      raceBanner: data['raceBanner'],
      genderPreferenceId: data['genderPreferenceId'],
      organizerUserId: data['organizerUserId'],
      organizerName: data['organizerName'],
      totalDistance: (data['totalDistance'] as num?)?.toDouble(),
      statusId: data['statusId'],
      status: data['status'],
      currentRank: data['currentRank'],
      distanceCovered: (data['distanceCovered'] as num?)?.toDouble() ?? 0.0,
      remainingDistance: (data['distanceRemaining'] as num?)?.toDouble() ?? 0.0,
      avgSpeed: (data['avgSpeed'] as num?)?.toDouble() ?? 0.0,
      participants: data['participants'] != null
          ? parseParticipants(data['participants'], (data['totalDistance'] as num?)?.toDouble() ?? 0.0)
          : null,
      leaderPreview: data['leaderPreview'] != null
          ? List<Map<String, dynamic>>.from(data['leaderPreview'])
          : null,
    );
  }

  /// Parse participants data - handles both legacy string format and new Participant object format
  static List<Participant> parseParticipants(dynamic participantsData, double totalDistance) {
    if (participantsData is List) {
      return participantsData.map<Participant>((p) {
        if (p is Map<String, dynamic>) {
          // Already in Participant object format - use existing parsing
          return Participant.fromFirestoreMap(p);
        } else if (p is String) {
          // Legacy string format (just user ID) - convert to minimal Participant
          return Participant(
            userId: p,
            userName: 'Unknown User',
            distance: 0.0,
            remainingDistance: totalDistance,
            rank: 1,
            steps: 0,
            status: 'joined',
            lastUpdated: DateTime.now(),
            calories: 0,
            avgSpeed: 0.0,
            isCompleted: false,
          );
        } else {
          // Unexpected format - log error and create placeholder participant
          print('⚠️ Warning: Invalid participant format: ${p.runtimeType} - $p');
          return Participant(
            userId: 'unknown_${DateTime.now().millisecondsSinceEpoch}',
            userName: 'Invalid Participant',
            distance: 0.0,
            remainingDistance: totalDistance,
            rank: 1,
            steps: 0,
            status: 'joined',
            lastUpdated: DateTime.now(),
            calories: 0,
            avgSpeed: 0.0,
            isCompleted: false,
          );
        }
      }).toList();
    }
    return [];
  }

  Map<String, dynamic> toFirestore() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (id != null) data['id'] = id;
    if (title != null) data['title'] = title;
    if (raceTypeId != null) data['raceTypeId'] = raceTypeId;
    if (maxParticipants != null) data['maxParticipants'] = maxParticipants;
    if (minParticipants != null) data['minParticipants'] = minParticipants;
    if (joinedParticipants != null)
      data['joinedParticipants'] = joinedParticipants;
    if (startLat != null) data['startLat'] = startLat;
    if (startLong != null) data['startLong'] = startLong;
    if (endLat != null) data['endLat'] = endLat;
    if (endLong != null) data['endLong'] = endLong;
    if (startAddress != null) data['startAddress'] = startAddress;
    if (endAddress != null) data['endAddress'] = endAddress;
    if (isPrivate != null) data['isPrivate'] = isPrivate;
    if (raceScheduleTime != null) {
      data['raceScheduleTime'] = DateTime.tryParse(raceScheduleTime!) != null
          ? Timestamp.fromDate(DateTime.parse(raceScheduleTime!))
          : raceScheduleTime;
    }
    if (raceDeadline != null) {
      data['raceDeadline'] = DateTime.tryParse(raceDeadline!) != null
          ? Timestamp.fromDate(DateTime.parse(raceDeadline!))
          : raceDeadline;
    }
    if (durationHrs != null) data['durationHrs'] = durationHrs;
    if (durationMins != null) data['durationMins'] = durationMins;
    if (raceBanner != null) data['raceBanner'] = raceBanner;
    if (genderPreferenceId != null)
      data['genderPreferenceId'] = genderPreferenceId;
    if (organizerUserId != null) data['organizerUserId'] = organizerUserId;
    if (organizerName != null) data['organizerName'] = organizerName;
    if (totalDistance != null) data['totalDistance'] = totalDistance;
    if (statusId != null) data['statusId'] = statusId;
    if (status != null) data['status'] = status;
    if (currentRank != null) data['currentRank'] = currentRank;
    if (distanceCovered != null) data['distanceCovered'] = distanceCovered;
    if (remainingDistance != null)
      data['distanceRemaining'] = remainingDistance;
    if (avgSpeed != null) data['avgSpeed'] = avgSpeed;

    // 🚫 IMPORTANT: Do NOT write participants array to main document
    // Participants are stored in subcollection: races/{raceId}/participants/{userId}
    // This reduces database writes by 66% and improves performance
    // if (participants != null) {
    //   data['participants'] = participants!.map((p) => p.toFirestore()).toList();
    // }

    if (leaderPreview != null) {
      data['leaderPreview'] = leaderPreview;
    }
    data['updatedAt'] = FieldValue.serverTimestamp();
    return data;
  }

  // Copy method
  RaceData copyWith({
    String? id,
    String? title,
    int? raceTypeId,
    int? maxParticipants,
    int? minParticipants,
    int? joinedParticipants,
    double? startLat,
    double? startLong,
    double? endLat,
    double? endLong,
    String? startAddress,
    String? endAddress,
    bool? isPrivate,
    String? raceScheduleTime,
    String? raceDeadline,
    int? durationHrs,
    int? durationMins,
    String? raceBanner,
    int? genderPreferenceId,
    String? organizerUserId,
    String? organizerName,
    double? totalDistance,
    int? statusId,
    String? status,
    int? currentRank,
    num? distanceCovered,
    num? remainingDistance,
    List<Participant>? participants,
    List<Map<String, dynamic>>? leaderPreview,
  }) {
    return RaceData(
      id: id ?? this.id,
      title: title ?? this.title,
      raceTypeId: raceTypeId ?? this.raceTypeId,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      minParticipants: minParticipants ?? this.minParticipants,
      joinedParticipants: joinedParticipants ?? this.joinedParticipants,
      startLat: startLat ?? this.startLat,
      startLong: startLong ?? this.startLong,
      endLat: endLat ?? this.endLat,
      endLong: endLong ?? this.endLong,
      startAddress: startAddress ?? this.startAddress,
      endAddress: endAddress ?? this.endAddress,
      isPrivate: isPrivate ?? this.isPrivate,
      raceScheduleTime: raceScheduleTime ?? this.raceScheduleTime,
      raceDeadline: raceDeadline ?? this.raceDeadline,
      durationHrs: durationHrs ?? this.durationHrs,
      durationMins: durationMins ?? this.durationMins,
      raceBanner: raceBanner ?? this.raceBanner,
      genderPreferenceId: genderPreferenceId ?? this.genderPreferenceId,
      organizerUserId: organizerUserId ?? this.organizerUserId,
      organizerName: organizerName ?? this.organizerName,
      totalDistance: totalDistance ?? this.totalDistance,
      statusId: statusId ?? this.statusId,
      status: status ?? this.status,
      currentRank: currentRank ?? this.currentRank,
      distanceCovered: distanceCovered ?? this.distanceCovered,
      remainingDistance: remainingDistance ?? this.remainingDistance,
      participants:
          participants ?? this.participants?.map((p) => p.copyWith()).toList(),
      leaderPreview: leaderPreview ?? this.leaderPreview,
    );
  }

  @override
  String toString() {
    return 'RaceData(id: $id, title: $title, participants: ${participants?.length})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RaceData && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Participant {
  final String userId;
  final String userName;
  final double distance;
  final double remainingDistance;
  final int rank;
  final int steps;
  final String status; // 'joined', 'active', 'completed', 'left'
  final DateTime? lastUpdated;
  final String? userProfilePicture;
  final int calories;
  final double avgSpeed;
  final bool isCompleted;
  final DateTime? completedAt; // When participant finished
  final int? finishOrder; // 1st, 2nd, 3rd finisher, etc.

  // Baseline fields for proper delta calculation
  final int? baselineSteps; // Health Connect steps when user joined race
  final double? baselineDistance; // Health Connect distance when user joined race
  final int? baselineCalories; // Health Connect calories when user joined race
  final DateTime? baselineTimestamp; // When baseline was captured (join time)

  Participant({
    required this.userId,
    required this.userName,
    required this.distance,
    required this.remainingDistance,
    required this.rank,
    required this.steps,
    this.status = 'joined',
    this.lastUpdated,
    this.userProfilePicture,
    this.calories = 0,
    this.avgSpeed = 0.0,
    this.isCompleted = false,
    this.completedAt,
    this.finishOrder,
    this.baselineSteps,
    this.baselineDistance,
    this.baselineCalories,
    this.baselineTimestamp,
  });

  // JSON Serialization
  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      userId: json['userId']?.toString() ?? '',
      userName: json['userName'] ?? '',
      distance: (json['distance'] ?? 0.0).toDouble(),
      remainingDistance: (json['remainingDistance'] ?? 0.0).toDouble(),
      rank: json['rank'] ?? 1,
      steps: json['steps'] ?? 0,
      status: json['status'] ?? 'joined',
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'].toString())
          : null,
      userProfilePicture: json['userProfilePicture'],
      calories: json['calories'] ?? 0,
      avgSpeed: (json['avgSpeed'] ?? 0.0).toDouble(),
      isCompleted: json['isCompleted'] ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'].toString())
          : null,
      finishOrder: json['finishOrder'],
      baselineSteps: json['baselineSteps'],
      baselineDistance: (json['baselineDistance'] ?? 0.0).toDouble(),
      baselineCalories: json['baselineCalories'],
      baselineTimestamp: json['baselineTimestamp'] != null
          ? DateTime.parse(json['baselineTimestamp'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'distance': distance,
      'remainingDistance': remainingDistance,
      'rank': rank,
      'steps': steps,
      'status': status,
      'lastUpdated': lastUpdated?.toIso8601String(),
      'userProfilePicture': userProfilePicture,
      'calories': calories,
      'avgSpeed': avgSpeed,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'finishOrder': finishOrder,
      'baselineSteps': baselineSteps,
      'baselineDistance': baselineDistance,
      'baselineCalories': baselineCalories,
      'baselineTimestamp': baselineTimestamp?.toIso8601String(),
    };
  }

  // Firestore Serialization
  factory Participant.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Participant.fromFirestoreMap(data);
  }

  factory Participant.fromFirestoreMap(Map<String, dynamic> data) {
    return Participant(
      userId: data['userId']?.toString() ?? '',
      userName: data['userName'] ?? '',
      distance: (data['distance'] ?? 0.0).toDouble(),
      remainingDistance: (data['remainingDistance'] ?? 0.0).toDouble(),
      rank: data['rank'] ?? 1,
      steps: data['steps'] ?? 0,
      status: data['status'] ?? 'joined',
      lastUpdated: data['lastUpdated'] != null
          ? (data['lastUpdated'] is Timestamp
                ? (data['lastUpdated'] as Timestamp).toDate()
                : DateTime.parse(data['lastUpdated'].toString()))
          : null,
      userProfilePicture: data['userProfilePicture'],
      calories: data['calories'] ?? 0,
      avgSpeed: (data['avgSpeed'] ?? 0.0).toDouble(),
      isCompleted: data['isCompleted'] ?? false,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] is Timestamp
                ? (data['completedAt'] as Timestamp).toDate()
                : DateTime.parse(data['completedAt'].toString()))
          : null,
      finishOrder: data['finishOrder'],
      baselineSteps: data['baselineSteps'],
      baselineDistance: data['baselineDistance'] != null
          ? (data['baselineDistance']).toDouble()
          : null,
      baselineCalories: data['baselineCalories'],
      baselineTimestamp: data['baselineTimestamp'] != null
          ? (data['baselineTimestamp'] is Timestamp
                ? (data['baselineTimestamp'] as Timestamp).toDate()
                : DateTime.parse(data['baselineTimestamp'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'distance': distance,
      'remainingDistance': remainingDistance,
      'rank': rank,
      'steps': steps,
      'status': status,
      'lastUpdated': lastUpdated != null
          ? Timestamp.fromDate(lastUpdated!)
          : Timestamp.fromDate(DateTime.now()),
      'userProfilePicture': userProfilePicture,
      'calories': calories,
      'avgSpeed': avgSpeed,
      'isCompleted': isCompleted,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'finishOrder': finishOrder,
      'baselineSteps': baselineSteps,
      'baselineDistance': baselineDistance,
      'baselineCalories': baselineCalories,
      'baselineTimestamp': baselineTimestamp != null
          ? Timestamp.fromDate(baselineTimestamp!)
          : null,
    };
  }

  // Legacy method name for backward compatibility
  factory Participant.fromMap(Map<String, dynamic> map) =>
      Participant.fromFirestoreMap(map);

  Map<String, dynamic> toMap() => toFirestore();

  // Copy method
  Participant copyWith({
    String? userId,
    String? userName,
    double? distance,
    double? remainingDistance,
    int? rank,
    int? steps,
    String? status,
    DateTime? lastUpdated,
    String? userProfilePicture,
    int? calories,
    double? avgSpeed,
    bool? isCompleted,
    DateTime? completedAt,
    int? finishOrder,
    int? baselineSteps,
    double? baselineDistance,
    int? baselineCalories,
    DateTime? baselineTimestamp,
  }) {
    return Participant(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      distance: distance ?? this.distance,
      remainingDistance: remainingDistance ?? this.remainingDistance,
      rank: rank ?? this.rank,
      steps: steps ?? this.steps,
      status: status ?? this.status,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      userProfilePicture: userProfilePicture ?? this.userProfilePicture,
      calories: calories ?? this.calories,
      avgSpeed: avgSpeed ?? this.avgSpeed,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      finishOrder: finishOrder ?? this.finishOrder,
      baselineSteps: baselineSteps ?? this.baselineSteps,
      baselineDistance: baselineDistance ?? this.baselineDistance,
      baselineCalories: baselineCalories ?? this.baselineCalories,
      baselineTimestamp: baselineTimestamp ?? this.baselineTimestamp,
    );
  }

  @override
  String toString() {
    return 'Participant(userId: $userId, userName: $userName, distance: $distance, rank: $rank, steps: $steps)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Participant &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;
}


// Extension methods for easier Firestore operations
extension RaceDataFirestore on RaceData {
  /// Save this RaceData to Firestore
  Future<void> saveToFirestore(
    CollectionReference collection, [
    String? docId,
  ]) async {
    if (docId != null) {
      await collection.doc(docId).set(toFirestore());
    } else {
      await collection.add(toFirestore());
    }
  }

  /// Update this RaceData in Firestore
  Future<void> updateInFirestore(
    CollectionReference collection,
    String docId,
  ) async {
    await collection.doc(docId).update(toFirestore());
  }

  /// Fetch participants from subcollection (replaces deprecated participants array)
  /// This should be called when you need the full participants list
  Future<List<Participant>> fetchParticipants(FirebaseFirestore firestore) async {
    if (id == null) return [];

    try {
      final participantsSnapshot = await firestore
          .collection('races')
          .doc(id)
          .collection('participants')
          .orderBy('rank')
          .get();

      return participantsSnapshot.docs
          .map((doc) => Participant.fromFirestoreMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching participants for race $id: $e');
      return [];
    }
  }

  /// Get participant count from subcollection
  Future<int> getParticipantCount(FirebaseFirestore firestore) async {
    if (id == null) return 0;

    try {
      final participantsSnapshot = await firestore
          .collection('races')
          .doc(id)
          .collection('participants')
          .count()
          .get();

      return participantsSnapshot.count ?? 0;
    } catch (e) {
      print('Error getting participant count for race $id: $e');
      return joinedParticipants ?? 0; // Fallback to cached count
    }
  }
}

extension ParticipantFirestore on Participant {
  /// Save this Participant to Firestore
  Future<void> saveToFirestore(
    CollectionReference collection, [
    String? docId,
  ]) async {
    if (docId != null) {
      await collection.doc(docId).set(toFirestore());
    } else {
      await collection.add(toFirestore());
    }
  }

  /// Update this Participant in Firestore
  Future<void> updateInFirestore(
    CollectionReference collection,
    String docId,
  ) async {
    await collection.doc(docId).update(toFirestore());
  }
}

