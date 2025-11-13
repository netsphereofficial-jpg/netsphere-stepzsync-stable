import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_notification_service.dart';

class UnifiedNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static StreamSubscription<QuerySnapshot>? _notificationSubscription;

  // Track sent notifications to prevent duplicates
  static const String _sentNotificationsKey = 'sent_notification_ids';
  static const int _notificationExpiryHours = 24;

  /// Start monitoring all notifications (friends, chat, etc.) from Firebase
  static Future<void> startMonitoring() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        return;
      }

      log('🔄 Starting unified notification monitoring for user: $currentUserId');

      // Cancel any existing subscription
      await stopMonitoring();

      // Listen for new notifications for current user

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

    } catch (e) {
    }
  }

  /// Stop monitoring all notifications
  static Future<void> stopMonitoring() async {
    try {
      await _notificationSubscription?.cancel();
      _notificationSubscription = null;
    } catch (e) {
    }
  }

  /// Handle notification updates from Firebase
  static void _handleNotificationUpdates(QuerySnapshot snapshot) {
    try {

      for (var change in snapshot.docChanges) {

        if (change.type == DocumentChangeType.added) {
          _processNewNotification(change.doc);
        }
      }
    } catch (e) {
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

      // Check if this notification has already been sent
      final notificationId = doc.id;
      final alreadySent = await _hasNotificationBeenSent(notificationId);

      if (alreadySent) {
        log('⏭️ Notification already sent, skipping: $type - $title (ID: $notificationId)');
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

      // Mark this notification as sent
      await _markNotificationAsSent(notificationId);

      // Don't mark as read immediately - keep it unread so it shows in the notification bell

    } catch (e) {
      log('❌ Error processing notification: $e');
    }
  }

  /// Manually check for unread notifications
  /// DISABLED - This method was causing duplicate notifications on app restart
  /// Now we rely ONLY on real-time listener (startMonitoring) to prevent replays
  static Future<void> checkForUnreadNotifications() async {
    log('ℹ️ checkForUnreadNotifications() disabled - using real-time listener only');
    // Do nothing - real-time listener will handle all new notifications
    return;

    // OLD CODE (DISABLED):
    // try {
    //   final currentUserId = _auth.currentUser?.uid;
    //   if (currentUserId == null) return;
    //
    //   final query = await _firestore
    //       .collection('user_notifications')
    //       .where('userId', isEqualTo: currentUserId)
    //       .where('isRead', isEqualTo: false)
    //       .get();
    //
    //   log('📋 Found ${query.docs.length} unread notifications');
    //
    //   for (var doc in query.docs) {
    //     await _processNewNotification(doc);
    //   }
    // } catch (e) {
    //   log('❌ Error checking for unread notifications: $e');
    // }
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
    } catch (e) {
      log('❌ Error clearing friend notifications: $e');
    }
  }

  /// Check if a notification has already been sent (duplicate detection)
  static Future<bool> _hasNotificationBeenSent(String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sentNotifications = prefs.getStringList(_sentNotificationsKey) ?? [];

      // Format: "notificationId:timestamp"
      for (final entry in sentNotifications) {
        final parts = entry.split(':');
        if (parts.length == 2 && parts[0] == notificationId) {
          // Check if notification is still within expiry window
          final timestamp = int.tryParse(parts[1]);
          if (timestamp != null) {
            final sentTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
            final now = DateTime.now();
            final difference = now.difference(sentTime);

            if (difference.inHours < _notificationExpiryHours) {
              return true; // Still within expiry window, consider it sent
            }
          }
        }
      }

      return false;
    } catch (e) {
      log('❌ Error checking sent notifications: $e');
      return false; // On error, allow notification to be sent
    }
  }

  /// Mark a notification as sent to prevent duplicates
  static Future<void> _markNotificationAsSent(String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var sentNotifications = prefs.getStringList(_sentNotificationsKey) ?? [];

      // Add new notification with current timestamp
      final now = DateTime.now().millisecondsSinceEpoch;
      sentNotifications.add('$notificationId:$now');

      // Clean up expired entries
      sentNotifications = _cleanupExpiredNotifications(sentNotifications);

      // Save back to preferences
      await prefs.setStringList(_sentNotificationsKey, sentNotifications);

      log('✅ Marked notification as sent: $notificationId');
    } catch (e) {
      log('❌ Error marking notification as sent: $e');
    }
  }

  /// Clean up expired notification entries (older than 24 hours)
  static List<String> _cleanupExpiredNotifications(List<String> notifications) {
    final now = DateTime.now();
    final validNotifications = <String>[];

    for (final entry in notifications) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        final timestamp = int.tryParse(parts[1]);
        if (timestamp != null) {
          final sentTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final difference = now.difference(sentTime);

          // Keep only notifications within expiry window
          if (difference.inHours < _notificationExpiryHours) {
            validNotifications.add(entry);
          }
        }
      }
    }

    return validNotifications;
  }

  /// Clear all sent notification tracking (useful for debugging)
  static Future<void> clearSentNotificationTracking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sentNotificationsKey);
      log('✅ Cleared sent notification tracking');
    } catch (e) {
      log('❌ Error clearing sent notification tracking: $e');
    }
  }
}