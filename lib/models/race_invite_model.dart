import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum InviteStatus { pending, accepted, declined }

enum InviteType { sent, received }

class RaceInviteModel {
  final String? id;
  final String raceId;
  final String raceTitle;
  final String fromUserId;
  final String fromUserName;
  final String fromUserImageUrl;
  final String toUserId;
  final String toUserName;
  final InviteStatus status;
  final InviteType type;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? message;
  final String raceDate;
  final String raceTime;
  final double raceDistance;
  final String raceLocation;
  final bool isJoinRequest;

  RaceInviteModel({
    this.id,
    required this.raceId,
    required this.raceTitle,
    required this.fromUserId,
    required this.fromUserName,
    this.fromUserImageUrl = '',
    required this.toUserId,
    required this.toUserName,
    required this.status,
    required this.type,
    required this.createdAt,
    this.respondedAt,
    this.message,
    required this.raceDate,
    required this.raceTime,
    required this.raceDistance,
    required this.raceLocation,
    this.isJoinRequest = false,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'raceId': raceId,
      'raceTitle': raceTitle,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'fromUserImageUrl': fromUserImageUrl,
      'toUserId': toUserId,
      'toUserName': toUserName,
      'status': status.name,
      'type': type.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'message': message,
      'raceDate': raceDate,
      'raceTime': raceTime,
      'raceDistance': raceDistance,
      'raceLocation': raceLocation,
      'isJoinRequest': isJoinRequest,
    };
  }

  factory RaceInviteModel.fromFirestore(DocumentSnapshot doc) {
    debugPrint('📄 Parsing invite document: ${doc.id}');

    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      debugPrint('❌ Document ${doc.id} has null data');
      throw Exception('Document data is null');
    }

    debugPrint('📋 Document ${doc.id} raw data: $data');

    // Handle createdAt field safely
    DateTime createdAt;
    try {
      if (data['createdAt'] is Timestamp) {
        createdAt = (data['createdAt'] as Timestamp).toDate();
        debugPrint('⏰ Parsed createdAt as Timestamp: $createdAt');
      } else if (data['createdAt'] is String) {
        createdAt = DateTime.parse(data['createdAt']);
        debugPrint('⏰ Parsed createdAt as String: $createdAt');
      } else {
        createdAt = DateTime.now(); // Fallback
        debugPrint('⚠️ Used fallback createdAt: $createdAt');
      }
    } catch (e) {
      createdAt = DateTime.now(); // Fallback if parsing fails
      debugPrint('❌ Failed to parse createdAt, using fallback: $e');
    }

    // Handle respondedAt field safely
    DateTime? respondedAt;
    try {
      if (data['respondedAt'] is Timestamp) {
        respondedAt = (data['respondedAt'] as Timestamp).toDate();
        debugPrint('⏰ Parsed respondedAt as Timestamp: $respondedAt');
      } else if (data['respondedAt'] is String) {
        respondedAt = DateTime.parse(data['respondedAt']);
        debugPrint('⏰ Parsed respondedAt as String: $respondedAt');
      }
    } catch (e) {
      respondedAt = null;
      debugPrint('⚠️ Failed to parse respondedAt: $e');
    }

    final statusString = data['status'] ?? 'pending';
    final typeString = data['type'] ?? 'received';

    debugPrint('🏷️ Status: $statusString, Type: $typeString');

    final invite = RaceInviteModel(
      id: doc.id,
      raceId: data['raceId'] ?? '',
      raceTitle: data['raceTitle'] ?? 'Unknown Race',
      fromUserId: data['fromUserId'] ?? '',
      fromUserName: data['fromUserName'] ?? 'Unknown User',
      fromUserImageUrl: data['fromUserImageUrl'] ?? '',
      toUserId: data['toUserId'] ?? '',
      toUserName: data['toUserName'] ?? 'Unknown User',
      status: InviteStatus.values.firstWhere(
        (e) => e.name == statusString,
        orElse: () => InviteStatus.pending,
      ),
      type: InviteType.values.firstWhere(
        (e) => e.name == typeString,
        orElse: () => InviteType.received,
      ),
      createdAt: createdAt,
      respondedAt: respondedAt,
      message: data['message'],
      raceDate: data['raceDate'] ?? '',
      raceTime: data['raceTime'] ?? '',
      raceDistance: (data['raceDistance'] ?? 0.0).toDouble(),
      raceLocation: data['raceLocation'] ?? 'Unknown Location',
      isJoinRequest: data['isJoinRequest'] ?? false,
    );

    debugPrint('✅ Successfully created invite model: ${invite.raceTitle} from ${invite.fromUserName}');
    return invite;
  }

  RaceInviteModel copyWith({
    String? id,
    String? raceId,
    String? raceTitle,
    String? fromUserId,
    String? fromUserName,
    String? fromUserImageUrl,
    String? toUserId,
    String? toUserName,
    InviteStatus? status,
    InviteType? type,
    DateTime? createdAt,
    DateTime? respondedAt,
    String? message,
    String? raceDate,
    String? raceTime,
    double? raceDistance,
    String? raceLocation,
    bool? isJoinRequest,
  }) {
    return RaceInviteModel(
      id: id ?? this.id,
      raceId: raceId ?? this.raceId,
      raceTitle: raceTitle ?? this.raceTitle,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUserName: fromUserName ?? this.fromUserName,
      fromUserImageUrl: fromUserImageUrl ?? this.fromUserImageUrl,
      toUserId: toUserId ?? this.toUserId,
      toUserName: toUserName ?? this.toUserName,
      status: status ?? this.status,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      message: message ?? this.message,
      raceDate: raceDate ?? this.raceDate,
      raceTime: raceTime ?? this.raceTime,
      raceDistance: raceDistance ?? this.raceDistance,
      raceLocation: raceLocation ?? this.raceLocation,
      isJoinRequest: isJoinRequest ?? this.isJoinRequest,
    );
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${difference.inDays ~/ 7}w ago';
    }
  }

  String get statusText {
    switch (status) {
      case InviteStatus.pending:
        return 'Pending';
      case InviteStatus.accepted:
        return 'Accepted';
      case InviteStatus.declined:
        return 'Declined';
    }
  }

  Color get statusColor {
    switch (status) {
      case InviteStatus.pending:
        return const Color(0xFF2759FF);
      case InviteStatus.accepted:
        return const Color(0xFF35B555);
      case InviteStatus.declined:
        return const Color(0xFFE74C3C);
    }
  }
}