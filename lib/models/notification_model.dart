class NotificationModel {
  final int id;
  final String? firebaseId; // Original Firebase document ID for deletion
  final String title;
  final String message;
  final String category;
  final String notificationType;
  final String icon;
  final String time;
  final String? thumbnail; // URL or asset path for thumbnail
  final String? userId; // User ID for friend requests, race participants
  final String? userName; // User name for display
  final String? raceId; // Race ID for race-related notifications
  final String? raceName; // Race name for display
  final Map<String, dynamic>? metadata; // Additional data like rank, time, etc.
  bool isRead;
  bool isSelected;

  NotificationModel({
    required this.id,
    this.firebaseId,
    required this.title,
    required this.message,
    required this.category,
    required this.notificationType,
    required this.icon,
    required this.time,
    this.thumbnail,
    this.userId,
    this.userName,
    this.raceId,
    this.raceName,
    this.metadata,
    this.isRead = false,
    this.isSelected = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final originalId = json['id'];
    return NotificationModel(
      id: _parseId(originalId),
      firebaseId: originalId is String ? originalId : null,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      category: json['category'] ?? 'General',
      notificationType: json['notificationType'] ?? 'General',
      icon: json['icon'] ?? '🔔',
      time: json['time'] ?? '',
      thumbnail: json['thumbnail'],
      userId: json['userId'],
      userName: json['userName'],
      raceId: json['raceId'],
      raceName: json['raceName'],
      metadata: json['metadata'],
      isRead: json['isRead'] ?? false,
      isSelected: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'category': category,
      'notificationType': notificationType,
      'icon': icon,
      'time': time,
      'thumbnail': thumbnail,
      'userId': userId,
      'userName': userName,
      'raceId': raceId,
      'raceName': raceName,
      'metadata': metadata,
      'isRead': isRead,
    };
  }

  /// Helper method to parse ID from either String or int
  static int _parseId(dynamic id) {
    print('🔍 Parsing ID: $id (type: ${id.runtimeType})');

    if (id == null) {
      print('📝 ID is null, returning 0');
      return 0;
    }

    if (id is int) {
      print('📝 ID is int: $id');
      return id;
    }

    if (id is String) {
      // Generate a hash-based ID from the string
      final hashId = id.hashCode.abs() % 2147483647; // Keep within 32-bit range
      print('📝 ID is string: $id, converted to hash: $hashId');
      return hashId;
    }

    print('❌ Unknown ID type: ${id.runtimeType}, returning 0');
    return 0;
  }
}

List<NotificationModel> parseNotifications(List<dynamic> data) {
  return data.map((json) => NotificationModel.fromJson(json)).toList();
}