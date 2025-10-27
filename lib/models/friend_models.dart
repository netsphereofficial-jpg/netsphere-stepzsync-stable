import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_models.dart';

class FriendRequest {
  final String? id;
  final String senderId;
  final String receiverId;
  final String senderName;
  final String? senderUsername;
  final String? senderProfilePicture;
  final FriendRequestStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  FriendRequest({
    this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    this.senderUsername,
    this.senderProfilePicture,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'senderName': senderName,
      'senderUsername': senderUsername,
      'senderProfilePicture': senderProfilePicture,
      'status': status.value,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory FriendRequest.fromJson(Map<String, dynamic> json, {String? id}) {
    return FriendRequest(
      id: id,
      senderId: json['senderId'] ?? '',
      receiverId: json['receiverId'] ?? '',
      senderName: json['senderName'] ?? '',
      senderUsername: json['senderUsername'],
      senderProfilePicture: json['senderProfilePicture'],
      status: FriendRequestStatus.fromValue(json['status'] ?? 'pending'),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  factory FriendRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FriendRequest.fromJson(data, id: doc.id);
  }

  FriendRequest copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? senderName,
    String? senderUsername,
    String? senderProfilePicture,
    FriendRequestStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FriendRequest(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      senderName: senderName ?? this.senderName,
      senderUsername: senderUsername ?? this.senderUsername,
      senderProfilePicture: senderProfilePicture ?? this.senderProfilePicture,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Friend {
  final String? id;
  final String userId;
  final String friendId;
  final String friendName;
  final String? friendUsername;
  final String? friendProfilePicture;
  final DateTime createdAt;

  Friend({
    this.id,
    required this.userId,
    required this.friendId,
    required this.friendName,
    this.friendUsername,
    this.friendProfilePicture,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'friendId': friendId,
      'friendName': friendName,
      'friendUsername': friendUsername,
      'friendProfilePicture': friendProfilePicture,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Friend.fromJson(Map<String, dynamic> json, {String? id}) {
    return Friend(
      id: id,
      userId: json['userId'] ?? '',
      friendId: json['friendId'] ?? '',
      friendName: json['friendName'] ?? '',
      friendUsername: json['friendUsername'],
      friendProfilePicture: json['friendProfilePicture'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  factory Friend.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Friend.fromJson(data, id: doc.id);
  }
}

class UserSearchResult {
  final String id;
  final String fullName;
  final String? username;
  final String? profilePicture;
  final String email;
  final String location;
  final FriendshipStatus friendshipStatus;

  UserSearchResult({
    required this.id,
    required this.fullName,
    this.username,
    this.profilePicture,
    required this.email,
    required this.location,
    required this.friendshipStatus,
  });

  factory UserSearchResult.fromUserProfile(
    UserProfile profile,
    FriendshipStatus status,
  ) {
    return UserSearchResult(
      id: profile.id!,
      fullName: profile.fullName,
      username: profile.username,
      profilePicture: profile.profilePicture,
      email: profile.email,
      location: profile.location,
      friendshipStatus: status,
    );
  }
}

enum FriendRequestStatus {
  pending('pending'),
  accepted('accepted'),
  declined('declined');

  const FriendRequestStatus(this.value);
  final String value;

  static FriendRequestStatus fromValue(String value) {
    for (FriendRequestStatus status in FriendRequestStatus.values) {
      if (status.value == value) return status;
    }
    return FriendRequestStatus.pending;
  }
}

enum FriendshipStatus {
  none('none'),
  requestSent('request_sent'),
  requestReceived('request_received'),
  friends('friends'),
  blocked('blocked');

  const FriendshipStatus(this.value);
  final String value;

  static FriendshipStatus fromValue(String value) {
    for (FriendshipStatus status in FriendshipStatus.values) {
      if (status.value == value) return status;
    }
    return FriendshipStatus.none;
  }
}