import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // Get notification list
  Future<Map<String, dynamic>?> getNotificationList(bool? isRead) async {
    try {
      print('🔥 NotificationRepository: Starting getNotificationList with isRead: $isRead');

      if (currentUserId == null) {
        print('❌ User not authenticated');
        return {
          'status': 401,
          'message': 'User not authenticated',
        };
      }

      print('👤 Current user ID: $currentUserId');

      Query query = _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUserId)
          .orderBy('createdAt', descending: true);

      if (isRead != null) {
        query = query.where('isRead', isEqualTo: isRead);
        print('🔍 Added isRead filter: $isRead');
      }

      final querySnapshot = await query.get();

      final notifications = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = data['createdAt'] as Timestamp?;

        final notification = {
          'id': doc.id,
          'title': data['title'] ?? '',
          'message': data['message'] ?? '',
          'category': data['category'] ?? 'General',
          'notificationType': data['notificationType'] ?? 'General',
          'icon': data['icon'] ?? '🔔',
          'time': createdAt != null
              ? _formatNotificationTime(createdAt.toDate())
              : 'Just now',
          'thumbnail': data['thumbnail'],
          'userId': data['relatedUserId'],
          'userName': data['userName'],
          'raceId': data['raceId'],
          'raceName': data['raceName'],
          'metadata': data['metadata'],
          'isRead': data['isRead'] ?? false,
        };

        print('📋 Created notification JSON: $notification');
        return notification;
      }).toList();

      print('✅ Successfully parsed ${notifications.length} notifications');

      return {
        'status': 200,
        'message': 'Notifications retrieved successfully',
        'data': notifications,
      };
    } catch (e, stackTrace) {
      print('💥 Firebase Error in getNotificationList: $e');
      print('📍 Stack trace: $stackTrace');

      // Check for specific Firebase index errors
      String errorMessage = 'Failed to get notifications: $e';

      if (e.toString().contains('index')) {
        print('');
        print('🔥🔥🔥 FIREBASE INDEX ERROR DETECTED 🔥🔥🔥');
        print('');
        print('📋 REQUIRED INDEX CREATION:');
        print('🔗 Go to Firebase Console > Firestore > Indexes');
        print('📄 Collection: notifications');
        print('🔍 Required fields:');
        print('   1. userId (Ascending)');
        print('   2. createdAt (Descending)');
        print('   3. isRead (Ascending) - if filtering by read status');
        print('');
        print('🚀 OR use this direct link if provided in error:');
        print('   Error details: $e');
        print('');
        print('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
        print('');

        errorMessage = 'Firebase index required. Check console for details.';
      }

      return {
        'status': 500,
        'message': errorMessage,
      };
    }
  }

  // Mark notifications as read by Firebase document IDs
  Future<Map<String, dynamic>?> markAsReadByFirebaseIds(List<String> firebaseIds) async {
    try {
      if (currentUserId == null) {
        return {
          'status': 401,
          'message': 'User not authenticated',
        };
      }

      final batch = _firestore.batch();

      if (firebaseIds.isEmpty) {
        // Mark all notifications as read for current user
        final querySnapshot = await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: currentUserId)
            .where('isRead', isEqualTo: false)
            .get();

        for (final doc in querySnapshot.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
      } else {
        // Mark specific notifications as read using Firebase document IDs
        for (final firebaseId in firebaseIds) {
          final docRef = _firestore.collection('notifications').doc(firebaseId);
          batch.update(docRef, {'isRead': true});
        }
      }

      await batch.commit();

      return {
        'status': 200,
        'message': 'Notifications marked as read successfully',
      };
    } catch (e) {
      print(e.toString());
      return {
        'status': 500,
        'message': 'Failed to mark notifications as read: $e',
      };
    }
  }

  // Mark notifications as read (legacy method - keeping for compatibility)
  Future<Map<String, dynamic>?> markAsReadApi(List<int> notificationIds) async {
    try {
      if (currentUserId == null) {
        return {
          'status': 401,
          'message': 'User not authenticated',
        };
      }

      final batch = _firestore.batch();

      if (notificationIds.isEmpty) {
        // Mark all notifications as read for current user
        final querySnapshot = await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: currentUserId)
            .where('isRead', isEqualTo: false)
            .get();

        for (final doc in querySnapshot.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
      } else {
        // Mark specific notifications as read
        for (final id in notificationIds) {
          final docRef = _firestore.collection('notifications').doc(id.toString());
          batch.update(docRef, {'isRead': true});
        }
      }

      await batch.commit();

      return {
        'status': 200,
        'message': 'Notifications marked as read successfully',
      };
    } catch (e) {
      print(e.toString());
      return {
        'status': 500,
        'message': 'Failed to mark notifications as read: $e',
      };
    }
  }

  // Delete notifications by Firebase document IDs
  Future<Map<String, dynamic>?> deleteNotificationsByFirebaseIds(List<String> firebaseIds) async {
    try {
      if (currentUserId == null) {
        return {
          'status': 401,
          'message': 'User not authenticated',
        };
      }

      final batch = _firestore.batch();

      if (firebaseIds.isEmpty) {
        // Delete all notifications for current user
        final querySnapshot = await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: currentUserId)
            .get();

        for (final doc in querySnapshot.docs) {
          batch.delete(doc.reference);
        }
      } else {
        // Delete specific notifications using their Firebase document IDs
        for (final firebaseId in firebaseIds) {
          final docRef = _firestore.collection('notifications').doc(firebaseId);
          batch.delete(docRef);
        }
      }

      await batch.commit();

      return {
        'status': 200,
        'message': 'Notifications deleted successfully',
      };
    } catch (e) {
      return {
        'status': 500,
        'message': 'Failed to delete notifications: $e',
      };
    }
  }

  // Delete notifications (legacy method - keeping for compatibility)
  Future<Map<String, dynamic>?> deleteNotificationApi(List<int> notificationIds) async {
    try {
      if (currentUserId == null) {
        return {
          'status': 401,
          'message': 'User not authenticated',
        };
      }

      final batch = _firestore.batch();

      if (notificationIds.isEmpty) {
        // Delete all notifications for current user
        final querySnapshot = await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: currentUserId)
            .get();

        for (final doc in querySnapshot.docs) {
          batch.delete(doc.reference);
        }
      } else {
        // Delete specific notifications
        for (final id in notificationIds) {
          final docRef = _firestore.collection('notifications').doc(id.toString());
          batch.delete(docRef);
        }
      }

      await batch.commit();

      return {
        'status': 200,
        'message': 'Notifications deleted successfully',
      };
    } catch (e) {
      return {
        'status': 500,
        'message': 'Failed to delete notifications: $e',
      };
    }
  }

  // Helper method to format notification time
  String _formatNotificationTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  // Create a new notification
  Future<Map<String, dynamic>?> createNotification({
    required String title,
    required String message,
    String category = 'General',
    String notificationType = 'General',
    String icon = '🔔',
    String? thumbnail,
    String? userId,
    String? userName,
    String? raceId,
    String? raceName,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      print('📝 Creating notification: $title - $message');

      if (currentUserId == null) {
        print('❌ User not authenticated for notification creation');
        return {
          'status': 401,
          'message': 'User not authenticated',
        };
      }

      print('👤 Creating notification for user: ${userId ?? currentUserId}');

      final notificationData = {
        'userId': userId ?? currentUserId,
        'title': title,
        'message': message,
        'category': category,
        'notificationType': notificationType,
        'icon': icon,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add optional fields if provided
      if (thumbnail != null) notificationData['thumbnail'] = thumbnail;
      if (userId != null) notificationData['relatedUserId'] = userId;
      if (userName != null) notificationData['userName'] = userName;
      if (raceId != null) notificationData['raceId'] = raceId;
      if (raceName != null) notificationData['raceName'] = raceName;
      if (metadata != null) notificationData['metadata'] = metadata;

      print('📤 Saving notification to Firestore...');
      final docRef = await _firestore.collection('notifications').add(notificationData);

      print('✅ Notification created successfully with ID: ${docRef.id}');

      return {
        'status': 200,
        'message': 'Notification created successfully',
        'data': {'id': docRef.id},
      };
    } catch (e, stackTrace) {
      print('💥 Error creating notification: $e');
      print('📍 Stack trace: $stackTrace');

      return {
        'status': 500,
        'message': 'Failed to create notification: $e',
      };
    }
  }

  // Create a sample notification (for testing)
  Future<void> createSampleNotification({
    required String title,
    required String message,
    String category = 'General',
    String notificationType = 'General',
    String icon = '🔔',
  }) async {
    await createNotification(
      title: title,
      message: message,
      category: category,
      notificationType: notificationType,
      icon: icon,
    );
  }

  // Batch create notifications
  Future<List<Map<String, dynamic>?>> createBatchNotifications(
    List<Map<String, dynamic>> notifications,
  ) async {
    final results = <Map<String, dynamic>?>[];

    for (final notif in notifications) {
      final result = await createNotification(
        title: notif['title'] ?? '',
        message: notif['message'] ?? '',
        category: notif['category'] ?? 'General',
        notificationType: notif['notificationType'] ?? 'General',
        icon: notif['icon'] ?? '🔔',
        thumbnail: notif['thumbnail'],
        userId: notif['userId'],
        userName: notif['userName'],
        raceId: notif['raceId'],
        raceName: notif['raceName'],
        metadata: notif['metadata'],
      );
      results.add(result);

      // Small delay between batch operations to avoid overwhelming Firestore
      await Future.delayed(Duration(milliseconds: 100));
    }

    return results;
  }
}