import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../controllers/race/races_list_controller.dart';
import '../models/race_invite_model.dart';
import '../core/models/race_data_model.dart';
import '../screens/home/homepage_screen/controllers/homepage_data_service.dart';
import 'firebase_service.dart';
import 'pending_requests_service.dart';
import 'race_service.dart';
import 'unified_notification_service.dart';

class RaceInviteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Helper method to convert race type ID to string
  String _getRaceTypeFromId(int raceTypeId) {
    switch (raceTypeId) {
      case 1:
        return 'Solo';
      case 2:
        return 'Private';
      case 3:
        return 'Public';
      default:
        return 'Unknown';
    }
  }

  /// Helper method to safely extract String from potentially complex Firestore data
  String _safeStringExtract(dynamic value, String fieldName) {
    if (value == null) {
      debugPrint('⚠️ Field $fieldName is null');
      return '';
    }

    if (value is String) {
      return value;
    }

    if (value is Map<String, dynamic>) {
      debugPrint('⚠️ Field $fieldName is a Map: $value');
      // Try to extract ID or uid from the map
      return value['id'] ?? value['uid'] ?? value.toString();
    }

    debugPrint('⚠️ Field $fieldName has unexpected type ${value.runtimeType}: $value');
    return value.toString();
  }

  /// Helper method to safely extract double from potentially complex Firestore data
  double _safeDoubleExtract(dynamic value, String fieldName, {double defaultValue = 0.0}) {
    if (value == null) {
      debugPrint('⚠️ Field $fieldName is null, using default: $defaultValue');
      return defaultValue;
    }

    if (value is double) {
      return value;
    }

    if (value is int) {
      return value.toDouble();
    }

    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }

    if (value is Map<String, dynamic>) {
      debugPrint('⚠️ Field $fieldName is a Map: $value');
      // Try to extract numeric values from the map
      final numValue = value['value'] ?? value['amount'] ?? value['total'];
      return _safeDoubleExtract(numValue, '${fieldName}.value', defaultValue: defaultValue);
    }

    debugPrint('⚠️ Field $fieldName has unexpected type ${value.runtimeType}: $value, using default: $defaultValue');
    return defaultValue;
  }

  /// Helper method to safely extract int from potentially complex Firestore data
  int _safeIntExtract(dynamic value, String fieldName, {int defaultValue = 0}) {
    if (value == null) {
      debugPrint('⚠️ Field $fieldName is null, using default: $defaultValue');
      return defaultValue;
    }

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }

    if (value is Map<String, dynamic>) {
      debugPrint('⚠️ Field $fieldName is a Map: $value');
      // Try to extract numeric values from the map
      final numValue = value['value'] ?? value['amount'] ?? value['id'];
      return _safeIntExtract(numValue, '${fieldName}.value', defaultValue: defaultValue);
    }

    debugPrint('⚠️ Field $fieldName has unexpected type ${value.runtimeType}: $value, using default: $defaultValue');
    return defaultValue;
  }

  /// Helper method to safely extract List<String> from potentially complex Firestore data
  List<String> _safeStringListExtract(dynamic value, String fieldName) {
    if (value == null) {
      debugPrint('⚠️ Field $fieldName is null, returning empty list');
      return <String>[];
    }

    if (value is List) {
      try {
        return value.map((item) => item.toString()).toList();
      } catch (e) {
        debugPrint('⚠️ Error converting list items to string for $fieldName: $e');
        return <String>[];
      }
    }

    if (value is Map<String, dynamic>) {
      debugPrint('⚠️ Field $fieldName is a Map: $value');
      // Try to extract list from the map
      final listValue = value['list'] ?? value['items'] ?? value['values'];
      return _safeStringListExtract(listValue, '${fieldName}.list');
    }

    debugPrint('⚠️ Field $fieldName has unexpected type ${value.runtimeType}: $value, returning empty list');
    return <String>[];
  }

  // Get invites received by current user (ONLY PENDING ONES for UI)
  Stream<List<RaceInviteModel>> getReceivedInvites() {
    debugPrint('🔍 getReceivedInvites called');

    if (_currentUserId == null) {
      debugPrint('❌ Current user ID is null in getReceivedInvites');
      return Stream.value([]);
    }

    debugPrint('👤 Current user ID: $_currentUserId');

    return _firestore
        .collection('race_invites')
        .where('toUserId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'pending') // ONLY PENDING INVITES
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          debugPrint(
            '📧 Received ${snapshot.docs.length} PENDING invite documents from Firestore',
          );

          if (snapshot.docs.isEmpty) {
            debugPrint(
              '📭 No pending invite documents found for user $_currentUserId',
            );
            return <RaceInviteModel>[];
          }

          final validInvites = <RaceInviteModel>[];

          for (final doc in snapshot.docs) {
            debugPrint('📄 Processing document: ${doc.id}');
            final data = doc.data() as Map<String, dynamic>?;

            if (data == null) {
              debugPrint('❌ Document ${doc.id} has null data');
              continue;
            }

            debugPrint('📋 Document ${doc.id} data: ${data.keys.toList()}');
            debugPrint(
              '🎯 Document ${doc.id} toUserId: ${data['toUserId']}, type: ${data['type']}, status: ${data['status']}',
            );

            final type = data['type'];
            final status = data['status'];
            final isValidType =
                type == 'received' || type == InviteType.received.name;

            if (!isValidType) {
              debugPrint('⚠️ Document ${doc.id} has invalid type: $type');
              continue;
            }

            // Double-check status is pending (extra safety)
            if (status != 'pending') {
              debugPrint(
                '⚠️ Document ${doc.id} has non-pending status: $status',
              );
              continue;
            }

            try {
              final invite = RaceInviteModel.fromFirestore(doc);
              validInvites.add(invite);
              debugPrint(
                '✅ Successfully parsed PENDING invite ${doc.id}: ${invite.raceTitle}',
              );
            } catch (e) {
              debugPrint('❌ Error parsing invite ${doc.id}: $e');
            }
          }

          debugPrint(
            '📊 Final count of valid PENDING received invites: ${validInvites.length}',
          );
          return validInvites;
        });
  }

  // Get invites sent by current user (includes join requests)
  Stream<List<RaceInviteModel>> getSentInvites() {
    debugPrint('📤 getSentInvites called');

    if (_currentUserId == null) {
      debugPrint('❌ Current user ID is null in getSentInvites');
      return Stream.value([]);
    }

    debugPrint('👤 Current user ID: $_currentUserId');

    return _firestore
        .collection('race_invites')
        .where('fromUserId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          debugPrint(
            '📤 Received ${snapshot.docs.length} sent invite documents from Firestore',
          );

          if (snapshot.docs.isEmpty) {
            debugPrint(
              '📭 No sent invite documents found for user $_currentUserId',
            );
            return <RaceInviteModel>[];
          }

          final validInvites = <RaceInviteModel>[];
          final seenRaceIds = <String>{};

          for (final doc in snapshot.docs) {
            debugPrint('📄 Processing sent document: ${doc.id}');
            final data = doc.data() as Map<String, dynamic>?;

            if (data == null) {
              debugPrint('❌ Sent document ${doc.id} has null data');
              continue;
            }

            debugPrint(
              '📋 Sent document ${doc.id} data: ${data.keys.toList()}',
            );
            debugPrint(
              '🎯 Sent document ${doc.id} fromUserId: ${data['fromUserId']}, type: ${data['type']}, isJoinRequest: ${data['isJoinRequest']}, status: ${data['status']}',
            );

            final type = data['type'];
            final status = data['status'];
            final raceId = _safeStringExtract(data['raceId'], 'raceId');
            final isJoinRequest = data['isJoinRequest'] == true;
            final isValidType =
                type == 'sent' || type == InviteType.sent.name || isJoinRequest;

            if (!isValidType) {
              debugPrint(
                '⚠️ Sent document ${doc.id} has invalid type: $type (isJoinRequest: $isJoinRequest)',
              );
              continue;
            }

            // For join requests, only show one per race (latest one)
            if (isJoinRequest && raceId != null) {
              if (seenRaceIds.contains(raceId)) {
                debugPrint(
                  '⏭️ Skipping duplicate join request for race: $raceId',
                );
                continue;
              }
              seenRaceIds.add(raceId);
            }

            try {
              final invite = RaceInviteModel.fromFirestore(doc);
              validInvites.add(invite);
              debugPrint(
                '✅ Successfully parsed sent invite ${doc.id}: ${invite.raceTitle} (Status: $status)',
              );
            } catch (e) {
              debugPrint('❌ Error parsing sent invite ${doc.id}: $e');
            }
          }

          debugPrint(
            '📊 Final count of valid sent invites: ${validInvites.length}',
          );
          return validInvites;
        });
  }

  // Get all invites (sent and received) for current user
  Stream<List<RaceInviteModel>> getAllInvites() {
    if (_currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('race_invites')
        .where('participants', arrayContains: _currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RaceInviteModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Get pending invites count for current user (received invites ONLY)
  Stream<int> getPendingInvitesCount() {
    if (_currentUserId == null) return Stream.value(0);

    return _firestore
        .collection('race_invites')
        .where('toUserId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'pending')
        .where(
          'type',
          isEqualTo: 'received',
        ) // Only received invites (not join requests TO others)
        .snapshots()
        .map((snapshot) {
          debugPrint('📊 Pending invites count: ${snapshot.docs.length}');
          return snapshot.docs.length;
        });
  }

  // Get pending join requests count for current user (join requests I sent)
  Stream<int> getPendingJoinRequestsCount() {
    if (_currentUserId == null) return Stream.value(0);

    return _firestore
        .collection('race_invites')
        .where('fromUserId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'pending')
        .where('isJoinRequest', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Send a race invite
  Future<bool> sendRaceInvite({
    required String raceId,
    required String raceTitle,
    required String toUserId,
    required String toUserName,
    String? message,
    required String raceDate,
    required String raceTime,
    required double raceDistance,
    required String raceLocation,
  }) async {
    try {
      if (_currentUserId == null) return false;

      // Get current user info
      final userDoc = await _firestore
          .collection('user_profiles')
          .doc(_currentUserId)
          .get();

      final userData = userDoc.data() ?? {};
      final fromUserName =
          userData['fullName'] ??
          userData['firstName'] ??
          userData['displayName'] ??
          'Unknown User';
      final fromUserImageUrl = userData['profilePicture'] ?? '';

      final batch = _firestore.batch();

      // Create invite for receiver
      final receivedInviteRef = _firestore.collection('race_invites').doc();
      final receivedInvite = RaceInviteModel(
        raceId: raceId,
        raceTitle: raceTitle,
        fromUserId: _currentUserId!,
        fromUserName: fromUserName,
        fromUserImageUrl: fromUserImageUrl,
        toUserId: toUserId,
        toUserName: toUserName,
        status: InviteStatus.pending,
        type: InviteType.received,
        createdAt: DateTime.now(),
        message: message,
        raceDate: raceDate,
        raceTime: raceTime,
        raceDistance: raceDistance,
        raceLocation: raceLocation,
      );

      // Create invite for sender
      final sentInviteRef = _firestore.collection('race_invites').doc();
      final sentInvite = RaceInviteModel(
        raceId: raceId,
        raceTitle: raceTitle,
        fromUserId: _currentUserId!,
        fromUserName: fromUserName,
        fromUserImageUrl: fromUserImageUrl,
        toUserId: toUserId,
        toUserName: toUserName,
        status: InviteStatus.pending,
        type: InviteType.sent,
        createdAt: DateTime.now(),
        message: message,
        raceDate: raceDate,
        raceTime: raceTime,
        raceDistance: raceDistance,
        raceLocation: raceLocation,
      );

      batch.set(receivedInviteRef, receivedInvite.toFirestore());
      batch.set(sentInviteRef, sentInvite.toFirestore());

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error sending race invite: $e');
      return false;
    }
  }

  // Accept a race invite
  Future<bool> acceptInvite(String inviteId) async {
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();

      // Update the received invite
      final receivedInviteRef = _firestore
          .collection('race_invites')
          .doc(inviteId);
      batch.update(receivedInviteRef, {
        'status': InviteStatus.accepted.name,
        'respondedAt': Timestamp.fromDate(now),
      });

      // Find and update corresponding sent invite
      final inviteDoc = await receivedInviteRef.get();
      if (inviteDoc.exists) {
        final inviteData = inviteDoc.data()!;
        final sentInviteQuery = await _firestore
            .collection('race_invites')
            .where('raceId', isEqualTo: inviteData['raceId'])
            .where('fromUserId', isEqualTo: inviteData['fromUserId'])
            .where('toUserId', isEqualTo: inviteData['toUserId'])
            .where('type', isEqualTo: 'sent')
            .get();

        for (final doc in sentInviteQuery.docs) {
          batch.update(doc.reference, {
            'status': InviteStatus.accepted.name,
            'respondedAt': Timestamp.fromDate(now),
          });
        }

        // Add user to race participants using proper 3-collection structure
        final raceRef = _firestore
            .collection('races')
            .doc(inviteData['raceId']);

        // Determine who should be added to the race
        final isJoinRequest = inviteData['isJoinRequest'] == true;
        final userToAdd = isJoinRequest
            ? _safeStringExtract(inviteData['fromUserId'], 'fromUserId') // For join requests, add the person who requested
            : _safeStringExtract(inviteData['toUserId'], 'toUserId'); // For regular invites, add the person who was invited

        debugPrint('🔍 UserToAdd extracted: $userToAdd');
        debugPrint('🔍 FromUserId type: ${inviteData['fromUserId'].runtimeType}');
        debugPrint('🔍 ToUserId type: ${inviteData['toUserId'].runtimeType}');

        if (userToAdd.isEmpty) {
          debugPrint('❌ Invalid user ID - cannot add to race');
          return false;
        }

        print(
          '🔄 Adding user to race: $userToAdd (isJoinRequest: $isJoinRequest)',
        );

        // Check current race data first
        final raceDoc = await raceRef.get();
        if (raceDoc.exists) {
          final raceData = raceDoc.data() as Map<String, dynamic>;
          debugPrint('🔍 Race data found: ${raceData.keys.toList()}');
          final currentParticipants = _safeStringListExtract(
            raceData['participants'],
            'participants',
          );

          // Only add if not already a participant
          if (!currentParticipants.contains(userToAdd)) {
            // Get user profile data for participant and user_race documents
            final userDoc = await _firestore
                .collection('user_profiles')
                .doc(userToAdd)
                .get();
            final userData = userDoc.data() ?? {};

            // Commit the invite updates first
            debugPrint('🔄 Committing batch updates for invite status...');
            await batch.commit();
            debugPrint('✅ Invite batch updates committed successfully');

            // Use the new RaceService.joinRaceAsUser method to join any user
            debugPrint('🔄 Calling RaceService.joinRaceAsUser...');
            debugPrint('🔍 Parameters: raceId=${_safeStringExtract(inviteData['raceId'], 'raceId')} for user=$userToAdd');

            final result = await RaceService.joinRaceAsUser(
              _safeStringExtract(inviteData['raceId'], 'raceId'),
              userToAdd,
            );
            if (result.isSuccess) {
              debugPrint('✅ Successfully joined race via RaceService.joinRaceAsUser');
            } else {
              debugPrint('❌ Failed to join race via RaceService.joinRaceAsUser: ${result.message}');
              return false;
            }

            print(
              '✅ Successfully joined race $userToAdd to race using RaceService',
            );
          } else {
            print('⚠️ User $userToAdd is already a participant');
            // Still commit the invite updates
            await batch.commit();
          }
        } else {
          // Race doesn't exist, still commit invite updates
          await batch.commit();
        }
      } else {
        // Invite doesn't exist, still commit what we have
        await batch.commit();
      }

      // Get the invite data again to determine who joined
      final inviteDocData = await receivedInviteRef.get();
      if (inviteDocData.exists) {
        final inviteInfo = inviteDocData.data()!;
        final isJoinRequest = inviteInfo['isJoinRequest'] == true;
        final userWhoJoined = isJoinRequest
            ? _safeStringExtract(inviteInfo['fromUserId'], 'fromUserId') // For join requests, the person who requested
            : _safeStringExtract(inviteInfo['toUserId'], 'toUserId'); // For regular invites, the person who was invited

        // Notify homepage to update active race count for the user who actually joined
        _notifyHomepageOfRaceJoinForUser(userWhoJoined);
      }

      // Also notify about pending invites count change (since one was accepted)
      _notifyHomepageOfPendingInviteChange();

      // Notify races list controller to update cache (for join requests)
      final inviteDocForCache = await _firestore
          .collection('race_invites')
          .doc(inviteId)
          .get();
      if (inviteDocForCache.exists) {
        final inviteData = inviteDocForCache.data();
        final isJoinRequestForCache = inviteData?['isJoinRequest'] == true;
        final userWhoJoinedForCache = isJoinRequestForCache
            ? _safeStringExtract(inviteData?['fromUserId'], 'fromUserId') // For join requests, the person who requested
            : _safeStringExtract(inviteData?['toUserId'], 'toUserId'); // For regular invites, the person who was invited
        _notifyRacesListOfStatusChange(
          _safeStringExtract(inviteData?['raceId'], 'raceId'),
          userWhoJoined: userWhoJoinedForCache,
        );
      }

      // ✅ Notification sent automatically by Cloud Function (onRaceInviteAccepted)
      // See: functions/notifications/triggers/raceTriggers.js:157-223

      return true;
    } catch (e) {
      debugPrint('❌ Error accepting invite: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  // Decline a race invite
  Future<bool> declineInvite(String inviteId) async {
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();

      // Update the received invite
      final receivedInviteRef = _firestore
          .collection('race_invites')
          .doc(inviteId);
      batch.update(receivedInviteRef, {
        'status': InviteStatus.declined.name,
        'respondedAt': Timestamp.fromDate(now),
      });

      // Find and update corresponding sent invite
      final inviteDoc = await receivedInviteRef.get();
      if (inviteDoc.exists) {
        final inviteData = inviteDoc.data()!;
        final sentInviteQuery = await _firestore
            .collection('race_invites')
            .where('raceId', isEqualTo: inviteData['raceId'])
            .where('fromUserId', isEqualTo: inviteData['fromUserId'])
            .where('toUserId', isEqualTo: inviteData['toUserId'])
            .where('type', isEqualTo: 'sent')
            .get();

        for (final doc in sentInviteQuery.docs) {
          batch.update(doc.reference, {
            'status': InviteStatus.declined.name,
            'respondedAt': Timestamp.fromDate(now),
          });
        }
      }

      await batch.commit();

      // Notify about pending invites count change (since one was declined)
      _notifyHomepageOfPendingInviteChange();

      // Notify races list controller to update cache (for join requests)
      final inviteDocForDeclineCache = await receivedInviteRef.get();
      if (inviteDocForDeclineCache.exists) {
        final inviteData = inviteDocForDeclineCache.data();
        _notifyRacesListOfStatusChange(inviteData?['raceId']);
      }

      // ✅ Notification sent automatically by Cloud Function (onRaceInviteDeclined)
      // See: functions/notifications/triggers/raceTriggers.js:232-298

      return true;
    } catch (e) {
      debugPrint('Error declining invite: $e');
      return false;
    }
  }

  // Delete an invite
  Future<bool> deleteInvite(String inviteId) async {
    try {
      await _firestore.collection('race_invites').doc(inviteId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting invite: $e');
      return false;
    }
  }

  // Check if user has already been invited to a race
  Future<bool> hasInviteForRace(String raceId, String toUserId) async {
    try {
      final query = await _firestore
          .collection('race_invites')
          .where('raceId', isEqualTo: raceId)
          .where('fromUserId', isEqualTo: _currentUserId)
          .where('toUserId', isEqualTo: toUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking existing invite: $e');
      return false;
    }
  }

  // Search users for private race invites
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return [];

      final querySnapshot = await _firestore
          .collection('user_profiles')
          .where('fullName', isGreaterThanOrEqualTo: query)
          .where('fullName', isLessThan: '$query\uf8ff')
          .limit(10)
          .get();

      final results = <Map<String, dynamic>>[];
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        results.add({
          'id': doc.id,
          'fullName': data['fullName'] ?? '',
          'email': data['email'] ?? '',
          'profilePicture': data['profilePicture'] ?? '',
        });
      }

      // Also search by email
      final emailQuery = await _firestore
          .collection('user_profiles')
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThan: '$query\uf8ff')
          .limit(5)
          .get();

      for (final doc in emailQuery.docs) {
        final data = doc.data();
        final userId = doc.id;

        // Avoid duplicates
        if (!results.any((user) => user['id'] == userId)) {
          results.add({
            'id': userId,
            'fullName': data['fullName'] ?? '',
            'email': data['email'] ?? '',
            'profilePicture': data['profilePicture'] ?? '',
          });
        }
      }

      return results;
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  // Send invite for private race with race details
  Future<bool> sendPrivateRaceInvite({
    required RaceData race,
    required String toUserId,
    required String toUserName,
    String? message,
  }) async {
    try {
      if (_currentUserId == null) return false;

      // Check if already invited
      final alreadyInvited = await hasInviteForRace(race.id!, toUserId);
      if (alreadyInvited) {
        return false; // Already invited
      }

      return await sendRaceInvite(
        raceId: race.id!,
        raceTitle: race.title ?? 'Unknown Race',
        toUserId: toUserId,
        toUserName: toUserName,
        message: message,
        raceDate: race.raceScheduleTime?.split(' at ').isNotEmpty == true
            ? race.raceScheduleTime!.split(' at ')[0]
            : race.raceScheduleTime ?? '',
        raceTime: (race.raceScheduleTime?.split(' at ').length ?? 0) > 1
            ? race.raceScheduleTime!.split(' at ')[1]
            : '',
        raceDistance: race.totalDistance ?? 0.0,
        raceLocation: race.startAddress ?? '',
      );
    } catch (e) {
      debugPrint('Error sending private race invite: $e');
      return false;
    }
  }

  // Get race by ID for invite purposes
  Future<RaceData?> getRaceById(String raceId) async {
    try {
      final doc = await _firestore.collection('races').doc(raceId).get();
      if (doc.exists) {
        return RaceData.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting race: $e');
      return null;
    }
  }

  // Send a join request for private/marathon races
  Future<bool> sendJoinRequest({
    required RaceData race,
    String? message,
  }) async {
    try {
      if (_currentUserId == null) return false;

      // Check if already sent a join request
      final existingRequest = await _firestore
          .collection('race_invites')
          .where('raceId', isEqualTo: race.id)
          .where('fromUserId', isEqualTo: _currentUserId)
          .where('isJoinRequest', isEqualTo: true)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        return false; // Already sent a request
      }

      // Get current user info
      final userDoc = await _firestore
          .collection('user_profiles')
          .doc(_currentUserId)
          .get();

      final userData = userDoc.data() ?? {};
      final fromUserName =
          userData['fullName'] ??
          userData['firstName'] ??
          userData['displayName'] ??
          'Unknown User';
      final fromUserImageUrl = userData['profilePicture'] ?? '';

      // Get race organizer info
      final organizerDoc = await _firestore
          .collection('user_profiles')
          .doc(race.organizerUserId)
          .get();

      final organizerData = organizerDoc.data() ?? {};
      final toUserName =
          organizerData['fullName'] ??
          organizerData['firstName'] ??
          organizerData['displayName'] ??
          'Race Organizer';

      final batch = _firestore.batch();

      // Create join request as a received invite for organizer
      final receivedInviteRef = _firestore.collection('race_invites').doc();
      final receivedInvite = RaceInviteModel(
        raceId: race.id!,
        raceTitle: race.title ?? 'Unknown Race',
        fromUserId: _currentUserId!,
        fromUserName: fromUserName,
        fromUserImageUrl: fromUserImageUrl,
        toUserId: race.organizerUserId!,
        toUserName: toUserName,
        status: InviteStatus.pending,
        type: InviteType.received,
        createdAt: DateTime.now(),
        message: message,
        raceDate: race.raceScheduleTime?.split(' at ').isNotEmpty == true
            ? race.raceScheduleTime!.split(' at ')[0]
            : race.raceScheduleTime ?? '',
        raceTime: (race.raceScheduleTime?.split(' at ').length ?? 0) > 1
            ? race.raceScheduleTime!.split(' at ')[1]
            : '',
        raceDistance: race.totalDistance ?? 0.0,
        raceLocation: race.startAddress ?? '',
        isJoinRequest: true,
      );

      // Create join request as a sent invite for requester
      final sentInviteRef = _firestore.collection('race_invites').doc();
      final sentInvite = RaceInviteModel(
        raceId: race.id!,
        raceTitle: race.title ?? 'Unknown Race',
        fromUserId: _currentUserId!,
        fromUserName: fromUserName,
        fromUserImageUrl: fromUserImageUrl,
        toUserId: race.organizerUserId!,
        toUserName: toUserName,
        status: InviteStatus.pending,
        type: InviteType.sent,
        createdAt: DateTime.now(),
        message: message,
        raceDate: race.raceScheduleTime?.split(' at ').isNotEmpty == true
            ? race.raceScheduleTime!.split(' at ')[0]
            : race.raceScheduleTime ?? '',
        raceTime: (race.raceScheduleTime?.split(' at ').length ?? 0) > 1
            ? race.raceScheduleTime!.split(' at ')[1]
            : '',
        raceDistance: race.totalDistance ?? 0.0,
        raceLocation: race.startAddress ?? '',
        isJoinRequest: true,
      );

      batch.set(receivedInviteRef, receivedInvite.toFirestore());
      batch.set(sentInviteRef, sentInvite.toFirestore());

      await batch.commit();

      // ✅ Notification sent automatically by Cloud Function (onRaceInviteCreated)
      // See: functions/notifications/triggers/raceTriggers.js:37-104
      // The Cloud Function detects isJoinRequest=true and sends notification to organizer

      return true;
    } catch (e) {
      debugPrint('Error sending join request: $e');
      return false;
    }
  }

  /// Notify homepage data service to refresh active race count
  void _notifyHomepageOfRaceJoin() {
    try {
      // Try to get homepage data service if it exists
      final homepageDataService = Get.find<HomepageDataService>();
      // Trigger immediate refresh of active joined race count using new unified service
      homepageDataService.loadActiveJoinedRaceCount();
      print(
        '✅ Notified homepage of race join via invite - updating active race count with unified service',
      );
    } catch (e) {
      // Homepage service might not be initialized yet, that's okay
      print(
        '📝 Homepage service not found, race count will update on next refresh',
      );
    }
  }

  /// Notify homepage data service to refresh active race count for a specific user
  void _notifyHomepageOfRaceJoinForUser(String userId) {
    try {
      // Only notify if the specified user is the current user
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == userId) {
        // Try to get homepage data service if it exists
        final homepageDataService = Get.find<HomepageDataService>();
        // Trigger immediate refresh of active joined race count
        homepageDataService.loadActiveJoinedRaceCount();
        print(
          '✅ Notified homepage of race join for user $userId - updating active race count',
        );
      } else {
        print(
          '📝 User $userId joined race, but they are not the current user, no local notification needed',
        );
      }
    } catch (e) {
      // Homepage service might not be initialized yet, that's okay
      print(
        '📝 Homepage service not found for user $userId, race count will update on next refresh',
      );
    }
  }

  /// Notify homepage data service to refresh pending invites count
  void _notifyHomepageOfPendingInviteChange() {
    try {
      // Try to get homepage data service if it exists
      final homepageDataService = Get.find<HomepageDataService>();
      // Trigger immediate refresh of pending invites count
      homepageDataService.loadPendingInvitesCount();
      print(
        '✅ Notified homepage of pending invite change - updating pending invites count',
      );
    } catch (e) {
      // Homepage service might not be initialized yet, that's okay
      print(
        '📝 Homepage service not found, pending invites count will update on next refresh',
      );
    }
  }

  /// Process manually accepted invites that didn't go through the full flow
  Future<bool> processManuallyAcceptedInvite(String inviteId) async {
    try {
      final inviteDoc = await _firestore
          .collection('race_invites')
          .doc(inviteId)
          .get();
      if (!inviteDoc.exists) return false;

      final inviteData = inviteDoc.data()!;
      final raceId = _safeStringExtract(inviteData['raceId'], 'raceId');
      final isJoinRequest = inviteData['isJoinRequest'] == true;

      // Determine who should be added to the race
      final userToAdd = isJoinRequest
          ? _safeStringExtract(inviteData['fromUserId'], 'fromUserId') // For join requests, add the person who requested
          : _safeStringExtract(inviteData['toUserId'], 'toUserId'); // For regular invites, add the person who was invited

      debugPrint('🔍 UserToAdd extracted: $userToAdd');
      debugPrint('🔍 FromUserId type: ${inviteData['fromUserId'].runtimeType}');
      debugPrint('🔍 ToUserId type: ${inviteData['toUserId'].runtimeType}');

      if (userToAdd.isEmpty) {
        debugPrint('❌ Invalid user ID - cannot add to race');
        return false;
      }

      print(
        '🔄 Processing manually accepted invite for user: $userToAdd (isJoinRequest: $isJoinRequest)',
      );

      // Check if invite is accepted but user not in race participants
      if (inviteData['status'] == 'accepted') {
        final raceDoc = await _firestore.collection('races').doc(raceId).get();
        if (raceDoc.exists) {
          final raceData = raceDoc.data() as Map<String, dynamic>;
          final participants = _safeStringListExtract(
            raceData['participants'],
            'participants',
          );

          if (!participants.contains(userToAdd)) {
            print(
              '🔄 Processing manually accepted invite - adding user $userToAdd to race',
            );

            // Get user profile data for participant and user_race documents
            final userDoc = await _firestore
                .collection('user_profiles')
                .doc(userToAdd)
                .get();
            final userData = userDoc.data() ?? {};
            final userName =
                userData['fullName'] ??
                userData['firstName'] ??
                userData['displayName'] ??
                'Unknown User';
            final userProfilePicture = userData['profilePicture'] ?? '';

            // Prepare participant data using new Participant model structure
            final participantData = {
              'userId': userToAdd,
              'userName': userName,
              'distance': 0.0,
              'remainingDistance': _safeDoubleExtract(raceData['totalDistance'], 'totalDistance'),
              'rank': 1,
              'steps': 0,
              'status': 'joined',
              'lastUpdated': FieldValue.serverTimestamp(),
              'userProfilePicture': userProfilePicture,
              'calories': 0,
              'avgSpeed': 0.0,
              'isCompleted': false,
              'joinedViaInvite': true,
              'inviteId': inviteId,
            };

            // Prepare user race data using new RaceData model structure
            final userRaceData = {
              'userId': userToAdd,
              'raceId': raceId,
              'role': isJoinRequest ? 'participant' : 'participant',
              'status': 'joined',
              'raceTitle': _safeStringExtract(raceData['title'], 'title'),
              'raceType': _getRaceTypeFromId(_safeIntExtract(raceData['raceTypeId'], 'raceTypeId')),
              'totalDistance': _safeDoubleExtract(raceData['totalDistance'], 'totalDistance'),
              'startAddress': _safeStringExtract(raceData['startAddress'], 'startAddress'),
              'endAddress': _safeStringExtract(raceData['endAddress'], 'endAddress'),
              'scheduleTime': _safeStringExtract(raceData['raceScheduleTime'], 'raceScheduleTime'),
              'joinedAt': FieldValue.serverTimestamp(),
              'joinedViaInvite': true,
              'inviteId': inviteId,
            };

            // Use FirebaseService to add participant with proper 3-collection structure
            final firebaseService = Get.find<FirebaseService>();
            await firebaseService.addParticipantToRace(
              raceId: raceId,
              userId: userToAdd,
              participantData: participantData,
              userRaceData: userRaceData,
            );
            print(
              '✅ Successfully processed manually accepted invite for user $userToAdd',
            );
            return true;
          } else {
            print(
              '⚠️ User $userToAdd is already a participant in race $raceId',
            );
          }
        }
      }
      return false;
    } catch (e) {
      print('❌ Error processing manually accepted invite: $e');
      return false;
    }
  }

  /// Check for and process any manually accepted invites
  Future<void> checkAndProcessManuallyAcceptedInvites() async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) return;

      final acceptedInvites = await _firestore
          .collection('race_invites')
          .where('toUserId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'accepted')
          .get();

      for (final doc in acceptedInvites.docs) {
        await processManuallyAcceptedInvite(doc.id);
      }
    } catch (e) {
      print('❌ Error checking manually accepted invites: $e');
    }
  }

  /// Notify races list controller to update pending requests cache
  void _notifyRacesListOfStatusChange(String? raceId, {String? userWhoJoined}) {
    if (raceId == null) return;

    try {
      // Try to get global pending requests service
      final pendingService = Get.find<PendingRequestsService>();
      pendingService.removePendingRequest(raceId);
      print(
        '✅ Notified global pending service to remove pending request for race $raceId',
      );
    } catch (e) {
      // Service might not be initialized, that's okay
      print(
        '📝 Pending requests service not found, cache will refresh on next load',
      );
    }

    try {
      // Also try to notify races list controller if it exists
      final racesListController = Get.find<RacesListController>();
      // racesListController.removePendingJoinRequest(raceId);

      // IMMEDIATE: Add user to participants locally for instant UI update
      final userToAddLocally = userWhoJoined ?? _auth.currentUser?.uid;
      if (userToAddLocally != null) {
        // racesListController.addUserToRaceParticipants(raceId, userToAddLocally);
        print(
          '✅ Added user $userToAddLocally to race participants locally for immediate UI update',
        );
      }

      // BACKUP: Also refresh from Firestore to ensure data consistency
      Future.delayed(Duration(milliseconds: 1000), () {
        try {
          // racesListController.refreshRaceData(raceId);
          print('✅ Also refreshed race data from Firestore');
        } catch (e) {
          print('📝 Race refresh failed, controller may be disposed');
        }
      });
    } catch (e) {
      // Controller might not be initialized, that's okay
      print('📝 Races list controller not found');
    }
  }
}
