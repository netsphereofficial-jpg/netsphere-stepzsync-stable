import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String? id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String? senderProfilePicture;
  final String receiverId;
  final String message;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;
  final String? replyToMessageId;
  final String? replyToMessage;

  ChatMessage({
    this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    this.senderProfilePicture,
    required this.receiverId,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.replyToMessageId,
    this.replyToMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderProfilePicture': senderProfilePicture,
      'receiverId': receiverId,
      'message': message,
      'type': type.value,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'replyToMessageId': replyToMessageId,
      'replyToMessage': replyToMessage,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json, {String? id}) {
    return ChatMessage(
      id: id,
      chatId: json['chatId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      senderProfilePicture: json['senderProfilePicture'],
      receiverId: json['receiverId'] ?? '',
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

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage.fromJson(data, id: doc.id);
  }

  ChatMessage copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    String? senderProfilePicture,
    String? receiverId,
    String? message,
    MessageType? type,
    DateTime? timestamp,
    bool? isRead,
    String? replyToMessageId,
    String? replyToMessage,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderProfilePicture: senderProfilePicture ?? this.senderProfilePicture,
      receiverId: receiverId ?? this.receiverId,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToMessage: replyToMessage ?? this.replyToMessage,
    );
  }
}

class ChatRoom {
  final String? id;
  final String participant1Id;
  final String participant1Name;
  final String? participant1ProfilePicture;
  final String participant2Id;
  final String participant2Name;
  final String? participant2ProfilePicture;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final DateTime? lastMessageTimestamp;
  final int unreadCount1; // Unread count for participant1
  final int unreadCount2; // Unread count for participant2
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatRoom({
    this.id,
    required this.participant1Id,
    required this.participant1Name,
    this.participant1ProfilePicture,
    required this.participant2Id,
    required this.participant2Name,
    this.participant2ProfilePicture,
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageTimestamp,
    this.unreadCount1 = 0,
    this.unreadCount2 = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'participant1Id': participant1Id,
      'participant1Name': participant1Name,
      'participant1ProfilePicture': participant1ProfilePicture,
      'participant2Id': participant2Id,
      'participant2Name': participant2Name,
      'participant2ProfilePicture': participant2ProfilePicture,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageTimestamp': lastMessageTimestamp?.toIso8601String(),
      'unreadCount1': unreadCount1,
      'unreadCount2': unreadCount2,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ChatRoom.fromJson(Map<String, dynamic> json, {String? id}) {
    return ChatRoom(
      id: id,
      participant1Id: json['participant1Id'] ?? '',
      participant1Name: json['participant1Name'] ?? '',
      participant1ProfilePicture: json['participant1ProfilePicture'],
      participant2Id: json['participant2Id'] ?? '',
      participant2Name: json['participant2Name'] ?? '',
      participant2ProfilePicture: json['participant2ProfilePicture'],
      lastMessage: json['lastMessage'],
      lastMessageSenderId: json['lastMessageSenderId'],
      lastMessageTimestamp: json['lastMessageTimestamp'] != null
          ? DateTime.parse(json['lastMessageTimestamp'])
          : null,
      unreadCount1: json['unreadCount1'] ?? 0,
      unreadCount2: json['unreadCount2'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoom.fromJson(data, id: doc.id);
  }

  // Helper methods
  String getOtherParticipantId(String currentUserId) {
    return currentUserId == participant1Id ? participant2Id : participant1Id;
  }

  String getOtherParticipantName(String currentUserId) {
    return currentUserId == participant1Id ? participant2Name : participant1Name;
  }

  String? getOtherParticipantProfilePicture(String currentUserId) {
    return currentUserId == participant1Id
        ? participant2ProfilePicture
        : participant1ProfilePicture;
  }

  int getUnreadCount(String currentUserId) {
    return currentUserId == participant1Id ? unreadCount1 : unreadCount2;
  }

  ChatRoom copyWith({
    String? id,
    String? participant1Id,
    String? participant1Name,
    String? participant1ProfilePicture,
    String? participant2Id,
    String? participant2Name,
    String? participant2ProfilePicture,
    String? lastMessage,
    String? lastMessageSenderId,
    DateTime? lastMessageTimestamp,
    int? unreadCount1,
    int? unreadCount2,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      participant1Id: participant1Id ?? this.participant1Id,
      participant1Name: participant1Name ?? this.participant1Name,
      participant1ProfilePicture: participant1ProfilePicture ?? this.participant1ProfilePicture,
      participant2Id: participant2Id ?? this.participant2Id,
      participant2Name: participant2Name ?? this.participant2Name,
      participant2ProfilePicture: participant2ProfilePicture ?? this.participant2ProfilePicture,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      unreadCount1: unreadCount1 ?? this.unreadCount1,
      unreadCount2: unreadCount2 ?? this.unreadCount2,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum MessageType {
  text('text'),
  system('system');

  const MessageType(this.value);
  final String value;

  static MessageType fromValue(String value) {
    for (MessageType type in MessageType.values) {
      if (type.value == value) return type;
    }
    return MessageType.text;
  }
}