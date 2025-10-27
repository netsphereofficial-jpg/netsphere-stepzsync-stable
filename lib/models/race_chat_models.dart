import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_models.dart';

class RaceChatMessage {
  final String? id;
  final String raceChatId;
  final String raceId;
  final String senderId;
  final String senderName;
  final String? senderProfilePicture;
  final String message;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;
  final String? replyToMessageId;
  final String? replyToMessage;

  RaceChatMessage({
    this.id,
    required this.raceChatId,
    required this.raceId,
    required this.senderId,
    required this.senderName,
    this.senderProfilePicture,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.replyToMessageId,
    this.replyToMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'raceChatId': raceChatId,
      'raceId': raceId,
      'senderId': senderId,
      'senderName': senderName,
      'senderProfilePicture': senderProfilePicture,
      'message': message,
      'type': type.value,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'replyToMessageId': replyToMessageId,
      'replyToMessage': replyToMessage,
    };
  }

  factory RaceChatMessage.fromJson(Map<String, dynamic> json, {String? id}) {
    return RaceChatMessage(
      id: id,
      raceChatId: json['raceChatId'] ?? '',
      raceId: json['raceId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      senderProfilePicture: json['senderProfilePicture'],
      message: json['message'] ?? '',
      type: MessageType.fromValue(json['type'] ?? 'text'),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isRead: json['isRead'] ?? false,
      replyToMessageId: json['replyToMessageId'],
      replyToMessage: json['replyToMessage'],
    );
  }

  factory RaceChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RaceChatMessage.fromJson(data, id: doc.id);
  }

  RaceChatMessage copyWith({
    String? id,
    String? raceChatId,
    String? raceId,
    String? senderId,
    String? senderName,
    String? senderProfilePicture,
    String? message,
    MessageType? type,
    DateTime? timestamp,
    bool? isRead,
    String? replyToMessageId,
    String? replyToMessage,
  }) {
    return RaceChatMessage(
      id: id ?? this.id,
      raceChatId: raceChatId ?? this.raceChatId,
      raceId: raceId ?? this.raceId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderProfilePicture: senderProfilePicture ?? this.senderProfilePicture,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToMessage: replyToMessage ?? this.replyToMessage,
    );
  }
}

class RaceChatRoom {
  final String? id;
  final String raceId;
  final String raceTitle;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String?> participantProfilePictures;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final DateTime? lastMessageTimestamp;
  final Map<String, int> unreadCounts;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  RaceChatRoom({
    this.id,
    required this.raceId,
    required this.raceTitle,
    required this.participantIds,
    required this.participantNames,
    required this.participantProfilePictures,
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageTimestamp,
    required this.unreadCounts,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'raceId': raceId,
      'raceTitle': raceTitle,
      'participantIds': participantIds,
      'participantNames': participantNames,
      'participantProfilePictures': participantProfilePictures,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageTimestamp': lastMessageTimestamp?.toIso8601String(),
      'unreadCounts': unreadCounts,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory RaceChatRoom.fromJson(Map<String, dynamic> json, {String? id}) {
    return RaceChatRoom(
      id: id,
      raceId: json['raceId'] ?? '',
      raceTitle: json['raceTitle'] ?? '',
      participantIds: List<String>.from(json['participantIds'] ?? []),
      participantNames: Map<String, String>.from(json['participantNames'] ?? {}),
      participantProfilePictures: Map<String, String?>.from(json['participantProfilePictures'] ?? {}),
      lastMessage: json['lastMessage'],
      lastMessageSenderId: json['lastMessageSenderId'],
      lastMessageTimestamp: json['lastMessageTimestamp'] != null
          ? DateTime.parse(json['lastMessageTimestamp'])
          : null,
      unreadCounts: Map<String, int>.from(json['unreadCounts'] ?? {}),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      isActive: json['isActive'] ?? true,
    );
  }

  factory RaceChatRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RaceChatRoom.fromJson(data, id: doc.id);
  }

  int getUnreadCount(String userId) {
    return unreadCounts[userId] ?? 0;
  }

  String getParticipantName(String userId) {
    return participantNames[userId] ?? 'Unknown';
  }

  String? getParticipantProfilePicture(String userId) {
    return participantProfilePictures[userId];
  }

  RaceChatRoom copyWith({
    String? id,
    String? raceId,
    String? raceTitle,
    List<String>? participantIds,
    Map<String, String>? participantNames,
    Map<String, String?>? participantProfilePictures,
    String? lastMessage,
    String? lastMessageSenderId,
    DateTime? lastMessageTimestamp,
    Map<String, int>? unreadCounts,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return RaceChatRoom(
      id: id ?? this.id,
      raceId: raceId ?? this.raceId,
      raceTitle: raceTitle ?? this.raceTitle,
      participantIds: participantIds ?? this.participantIds,
      participantNames: participantNames ?? this.participantNames,
      participantProfilePictures: participantProfilePictures ?? this.participantProfilePictures,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}