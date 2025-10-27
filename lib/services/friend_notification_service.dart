import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'local_notification_service.dart';

class UnifiedNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static StreamSubscription<QuerySnapshot>? _notificationSubscription;

  /// Start monitoring all notifications (friends, chat, etc.) from Firebase
  static Future<void> startMonitoring() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        log('❌ No current user for notification monitoring');
        return;
      }

      log('🔄 Starting unified notification monitoring for user: $currentUserId');

      // Cancel any existing subscription
      await stopMonitoring();

      // Listen for new notifications for current user
      log('🎧 Setting up Firebase listener for user: $currentUserId');

      _notificationSubscription = _firestore
          .collection('user_notifications')
          .where('userId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen(
            _handleNotificationUpdates,
            onError: (error) {
              log('❌ Notification stream error: $error');
            },
          );

      log('🎧 Firebase listener setup complete');

      log('✅ Unified notification monitoring started');
    } catch (e) {
      log('❌ Error starting friend notification monitoring: $e');
    }
  }

  /// Stop monitoring all notifications
  static Future<void> stopMonitoring() async {
    try {
      await _notificationSubscription?.cancel();
      _notificationSubscription = null;
      log('🛑 Unified notification monitoring stopped');
    } catch (e) {
      log('❌ Error stopping notification monitoring: $e');
    }
  }

  /// Handle notification updates from Firebase
  static void _handleNotificationUpdates(QuerySnapshot snapshot) {
    try {
      log('📬 Received notification updates: ${snapshot.docChanges.length} changes');

      for (var change in snapshot.docChanges) {
        log('📝 Doc change type: ${change.type}, doc ID: ${change.doc.id}');

        if (change.type == DocumentChangeType.added) {
          _processNewNotification(change.doc);
        }
      }
    } catch (e) {
      log('❌ Error handling notification updates: $e');
    }
  }

  /// Process a new notification (friends, chat, etc.)
  static Future<void> _processNewNotification(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;

      final type = data['type'] as String?;
      final title = data['title'] as String?;
      final message = data['message'] as String?;
      final icon = data['icon'] as String?;
      final category = data['category'] as String?;
      final notificationData = data['data'] as Map<String, dynamic>?;

      if (type == null || title == null || message == null) {
        log('⚠️ Invalid notification data');
        return;
      }

      log('🔔 Processing notification: $type - $title');

      // Show local notification and update controller
      await LocalNotificationService.sendNotificationAndStore(
        title: title,
        message: message,
        notificationType: type,
        category: category ?? 'Social',
        icon: icon ?? '👥',
        metadata: notificationData ?? {},
        storeInLocal: true, // Add to local list
        storeInFirebase: false, // Don't duplicate in Firebase (already exists)
      );

      // Don't mark as read immediately - keep it unread so it shows in the notification bell

      log('✅ Notification processed: $type');
    } catch (e) {
      log('❌ Error processing friend notification: $e');
    }
  }

  /// Manually check for unread notifications
  static Future<void> checkForUnreadNotifications() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      final query = await _firestore
          .collection('user_notifications')
          .where('userId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      log('📋 Found ${query.docs.length} unread notifications');

      for (var doc in query.docs) {
        await _processNewNotification(doc);
      }
    } catch (e) {
      log('❌ Error checking for unread notifications: $e');
    }
  }

  /// Clear all notifications for current user
  static Future<void> clearAllNotifications() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      final query = await _firestore
          .collection('user_notifications')
          .where('userId', isEqualTo: currentUserId)
          .get();

      final batch = _firestore.batch();
      for (var doc in query.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      log('🗑️ Cleared all notifications for user: $currentUserId');
    } catch (e) {
      log('❌ Error clearing friend notifications: $e');
    }
  }
}