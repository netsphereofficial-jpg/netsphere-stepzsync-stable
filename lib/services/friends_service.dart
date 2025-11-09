import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/friend_models.dart';
import '../models/profile_models.dart';
import 'xp_service.dart';
import 'dart:developer';

class FriendsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get currentUserId => _auth.currentUser?.uid;

  // Search users by name or username
  static Future<List<UserSearchResult>> searchUsers(String query) async {
    if (query.trim().isEmpty || currentUserId == null) return [];

    try {
      final currentUser = currentUserId!;

      // Search by full name
      final nameQuery = await _firestore
          .collection('user_profiles')
          .where('fullName', isGreaterThanOrEqualTo: query)
          .where('fullName', isLessThan: query + '\uf8ff')
          .limit(20)
          .get();

      // Search by username (using lowercase field for case-insensitive search)
      final usernameQuery = await _firestore
          .collection('user_profiles')
          .where('usernameLower', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('usernameLower', isLessThan: query.toLowerCase() + '\uf8ff')
          .limit(20)
          .get();

      // Combine results and remove duplicates
      final Map<String, UserProfile> userMap = {};

      for (var doc in nameQuery.docs) {
        if (doc.id != currentUser) {
          userMap[doc.id] = UserProfile.fromFirestore(doc);
        }
      }

      for (var doc in usernameQuery.docs) {
        if (doc.id != currentUser) {
          userMap[doc.id] = UserProfile.fromFirestore(doc);
        }
      }

      // Get friendship status for each user
      final results = <UserSearchResult>[];
      for (var profile in userMap.values) {
        final status = await getFriendshipStatus(profile.id!);
        results.add(UserSearchResult.fromUserProfile(profile, status));
      }

      return results;
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  // Check username availability (case-insensitive)
  static Future<bool> isUsernameAvailable(String username) async {
    try {
      final query = await _firestore
          .collection('user_profiles')
          .where('usernameLower', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();

      // Also check if it's the current user's existing username
      if (query.docs.isNotEmpty && currentUserId != null) {
        // If the username belongs to the current user, it's available for them to keep
        final existingDoc = query.docs.first;
        if (existingDoc.id == currentUserId) {
          return true;
        }
      }

      return query.docs.isEmpty;
    } catch (e) {
      throw Exception('Failed to check username availability: $e');
    }
  }

  // Get friendship status between current user and another user
  static Future<FriendshipStatus> getFriendshipStatus(String userId) async {
    if (currentUserId == null) return FriendshipStatus.none;

    try {
      final currentUser = currentUserId!;

      // Check if already friends
      final friendsQuery = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: currentUser)
          .where('friendId', isEqualTo: userId)
          .limit(1)
          .get();

      if (friendsQuery.docs.isNotEmpty) {
        return FriendshipStatus.friends;
      }

      // Check for pending requests
      final sentRequestQuery = await _firestore
          .collection('friend_requests')
          .where('senderId', isEqualTo: currentUser)
          .where('receiverId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (sentRequestQuery.docs.isNotEmpty) {
        return FriendshipStatus.requestSent;
      }

      final receivedRequestQuery = await _firestore
          .collection('friend_requests')
          .where('senderId', isEqualTo: userId)
          .where('receiverId', isEqualTo: currentUser)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (receivedRequestQuery.docs.isNotEmpty) {
        return FriendshipStatus.requestReceived;
      }

      return FriendshipStatus.none;
    } catch (e) {
      throw Exception('Failed to get friendship status: $e');
    }
  }

  // Send friend request
  static Future<void> sendFriendRequest(String receiverId, String receiverName, String? receiverUsername) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final currentUser = currentUserId!;

      // Get current user profile for sender info
      final userDoc = await _firestore.collection('user_profiles').doc(currentUser).get();
      if (!userDoc.exists) throw Exception('User profile not found');

      final userProfile = UserProfile.fromFirestore(userDoc);

      final request = FriendRequest(
        senderId: currentUser,
        receiverId: receiverId,
        senderName: userProfile.fullName,
        senderUsername: userProfile.username,
        senderProfilePicture: userProfile.profilePicture,
        status: FriendRequestStatus.pending,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('friend_requests').add(request.toJson());

      // ✅ Notification will be sent automatically by Cloud Function (onFriendRequestCreated)

      log('✅ Friend request sent from ${userProfile.fullName} to $receiverName');
    } catch (e) {
      throw Exception('Failed to send friend request: $e');
    }
  }

  // Accept friend request
  static Future<void> acceptFriendRequest(String requestId) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final currentUser = currentUserId!;

      // Get request details
      final requestDoc = await _firestore.collection('friend_requests').doc(requestId).get();
      if (!requestDoc.exists) throw Exception('Friend request not found');

      final request = FriendRequest.fromFirestore(requestDoc);

      // Update request status
      await _firestore.collection('friend_requests').doc(requestId).update({
        'status': FriendRequestStatus.accepted.value,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Get sender profile
      final senderDoc = await _firestore.collection('user_profiles').doc(request.senderId).get();
      final senderProfile = UserProfile.fromFirestore(senderDoc);

      // Get receiver profile
      final receiverDoc = await _firestore.collection('user_profiles').doc(currentUser).get();
      final receiverProfile = UserProfile.fromFirestore(receiverDoc);

      // Add to friends collection (both directions)
      final batch = _firestore.batch();

      // Add sender as friend of receiver
      final friend1 = Friend(
        userId: currentUser,
        friendId: request.senderId,
        friendName: senderProfile.fullName,
        friendUsername: senderProfile.username,
        friendProfilePicture: senderProfile.profilePicture,
        createdAt: DateTime.now(),
      );

      // Add receiver as friend of sender
      final friend2 = Friend(
        userId: request.senderId,
        friendId: currentUser,
        friendName: receiverProfile.fullName,
        friendUsername: receiverProfile.username,
        friendProfilePicture: receiverProfile.profilePicture,
        createdAt: DateTime.now(),
      );

      batch.set(_firestore.collection('friends').doc(), friend1.toJson());
      batch.set(_firestore.collection('friends').doc(), friend2.toJson());

      await batch.commit();

      // ✅ Notification will be sent automatically by Cloud Function (onFriendRequestAccepted)

      // 🎁 Award friend XP to both users (20 XP each)
      try {
        final xpService = XPService();

        // Award XP to the person who accepted
        await xpService.awardAddFriendXP(
          userId: currentUser,
          friendId: request.senderId,
          friendName: senderProfile.fullName,
        );

        // Award XP to the person who sent the request
        await xpService.awardAddFriendXP(
          userId: request.senderId,
          friendId: currentUser,
          friendName: receiverProfile.fullName,
        );

        log('✅ Awarded friend XP to both users');
      } catch (e) {
        log('⚠️ Failed to award friend XP: $e');
        // Don't block friend acceptance if XP fails
      }

      log('✅ Friend request accepted: ${receiverProfile.fullName} accepted ${senderProfile.fullName}\'s request');
    } catch (e) {
      throw Exception('Failed to accept friend request: $e');
    }
  }

  // Decline friend request
  static Future<void> declineFriendRequest(String requestId) async {
    try {
      // Get request details first for notification
      final requestDoc = await _firestore.collection('friend_requests').doc(requestId).get();
      if (requestDoc.exists) {
        final request = FriendRequest.fromFirestore(requestDoc);

        // Get decliner profile
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId != null) {
          }
      }

      // ✅ Notification will be sent automatically by Cloud Function (onFriendRequestDeclined)

      await _firestore.collection('friend_requests').doc(requestId).update({
        'status': FriendRequestStatus.declined.value,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      log('✅ Friend request declined and notification sent');
    } catch (e) {
      throw Exception('Failed to decline friend request: $e');
    }
  }

  // Get friends list
  static Future<List<Friend>> getFriends() async {
    if (currentUserId == null) return [];

    try {
      final query = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: currentUserId)
          .orderBy('friendName')
          .get();

      return query.docs.map((doc) => Friend.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get friends: $e');
    }
  }

  // Get received friend requests
  static Future<List<FriendRequest>> getReceivedRequests() async {
    if (currentUserId == null) return [];

    try {
      final query = await _firestore
          .collection('friend_requests')
          .where('receiverId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) => FriendRequest.fromFirestore(doc)).toList();
    } catch (e) {
      // Fallback: If index is still building, use simple query and sort in memory
      if (e.toString().contains('index is currently building')) {
        try {
          final fallbackQuery = await _firestore
              .collection('friend_requests')
              .where('receiverId', isEqualTo: currentUserId)
              .where('status', isEqualTo: 'pending')
              .get();

          final requests = fallbackQuery.docs.map((doc) => FriendRequest.fromFirestore(doc)).toList();
          requests.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort in memory
          return requests;
        } catch (fallbackError) {
          throw Exception('Failed to get received requests: $fallbackError');
        }
      }
      throw Exception('Failed to get received requests: $e');
    }
  }

  // Get sent friend requests
  static Future<List<FriendRequest>> getSentRequests() async {
    if (currentUserId == null) return [];

    try {
      final query = await _firestore
          .collection('friend_requests')
          .where('senderId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) => FriendRequest.fromFirestore(doc)).toList();
    } catch (e) {
      // Fallback: If index is still building, use simple query and sort in memory
      if (e.toString().contains('index is currently building')) {
        try {
          final fallbackQuery = await _firestore
              .collection('friend_requests')
              .where('senderId', isEqualTo: currentUserId)
              .where('status', isEqualTo: 'pending')
              .get();

          final requests = fallbackQuery.docs.map((doc) => FriendRequest.fromFirestore(doc)).toList();
          requests.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort in memory
          return requests;
        } catch (fallbackError) {
          throw Exception('Failed to get sent requests: $fallbackError');
        }
      }
      throw Exception('Failed to get sent requests: $e');
    }
  }

  // Remove friend
  static Future<void> removeFriend(String friendId) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final currentUser = currentUserId!;
      final batch = _firestore.batch();

      // Remove both directions of friendship
      final friend1Query = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: currentUser)
          .where('friendId', isEqualTo: friendId)
          .get();

      final friend2Query = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: friendId)
          .where('friendId', isEqualTo: currentUser)
          .get();

      for (var doc in friend1Query.docs) {
        batch.delete(doc.reference);
      }

      for (var doc in friend2Query.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      // ✅ Notification will be sent automatically by Cloud Function (onFriendRemoved)

      log('✅ Friend removed: $currentUser removed $friendId');
    } catch (e) {
      throw Exception('Failed to remove friend: $e');
    }
  }

  // Cancel sent friend request
  static Future<void> cancelFriendRequest(String receiverId) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    try {
      final query = await _firestore
          .collection('friend_requests')
          .where('senderId', isEqualTo: currentUserId)
          .where('receiverId', isEqualTo: receiverId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (var doc in query.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      throw Exception('Failed to cancel friend request: $e');
    }
  }

  // ================= NOTIFICATION METHODS =================
  // ✅ All friend notifications are now handled by Cloud Functions!
  // See: functions/notifications/triggers/friendTriggers.js
  //
  // Automatic triggers:
  // - onFriendRequestCreated: Sends notification when friend_requests doc is created
  // - onFriendRequestAccepted: Sends notification when status changes to 'accepted'
  // - onFriendRequestDeclined: Sends notification when status changes to 'declined'
  // - onFriendRemoved: Sends notification when friends doc is deleted
}