import 'package:cloud_firestore/cloud_firestore.dart';

class QuickRaceModel {
  final String? id;
  final String title;
  final DateTime createdTime;
  final String raceType;
  final int maxParticipants;
  final int currentParticipants;
  final List<String> participants;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String createdBy;
  final double distance;
  final int duration; // in minutes

  QuickRaceModel({
    this.id,
    required this.title,
    required this.createdTime,
    required this.raceType,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.participants,
    required this.status,
    this.startedAt,
    this.endedAt,
    required this.createdBy,
    required this.distance,
    required this.duration,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'createdTime': Timestamp.fromDate(createdTime),
      'raceType': raceType,
      'maxParticipants': maxParticipants,
      'currentParticipants': currentParticipants,
      'participants': participants,
      'status': status,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'createdBy': createdBy,
      'distance': distance,
      'duration': duration,
    };
  }

  factory QuickRaceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuickRaceModel(
      id: doc.id,
      title: data['title'] ?? '',
      createdTime: (data['createdTime'] as Timestamp).toDate(),
      raceType: data['raceType'] ?? '',
      maxParticipants: data['maxParticipants'] ?? 0,
      currentParticipants: data['currentParticipants'] ?? 0,
      participants: List<String>.from(data['participants'] ?? []),
      status: data['status'] ?? 'waiting',
      startedAt: data['startedAt'] != null ? (data['startedAt'] as Timestamp).toDate() : null,
      endedAt: data['endedAt'] != null ? (data['endedAt'] as Timestamp).toDate() : null,
      createdBy: data['createdBy'] ?? '',
      distance: (data['distance'] ?? 0.0).toDouble(),
      duration: data['duration'] ?? 0,
    );
  }

  QuickRaceModel copyWith({
    String? id,
    String? title,
    DateTime? createdTime,
    String? raceType,
    int? maxParticipants,
    int? currentParticipants,
    List<String>? participants,
    String? status,
    DateTime? startedAt,
    DateTime? endedAt,
    String? createdBy,
    double? distance,
    int? duration,
  }) {
    return QuickRaceModel(
      id: id ?? this.id,
      title: title ?? this.title,
      createdTime: createdTime ?? this.createdTime,
      raceType: raceType ?? this.raceType,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      participants: participants ?? this.participants,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      createdBy: createdBy ?? this.createdBy,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
    );
  }
}