import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../models/chat_models.dart';
import '../models/race_chat_models.dart';
import '../models/friend_models.dart';
import '../core/models/race_data_model.dart';
import '../services/unified_notification_service.dart';
import 'dart:developer';

class ChatController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Observable lists and states
  final RxList<ChatRoom> chatRooms = <ChatRoom>[].obs;
  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final RxList<Friend> friends = <Friend>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMessages = false.obs;
  final RxBool isSendingMessage = false.obs;

  // Current chat
  final Rx<ChatRoom?> currentChatRoom = Rx<ChatRoom?>(null);
  final RxString currentChatId = ''.obs;

  // Race chat properties
  final RxList<RaceChatRoom> raceChatRooms = <RaceChatRoom>[].obs;
  final RxList<RaceChatMessage> raceMessages = <RaceChatMessage>[].obs;
  final Rx<RaceChatRoom?> currentRaceChatRoom = Rx<RaceChatRoom?>(null);
  final RxString currentRaceChatId = ''.obs;
  final RxBool isLoadingRaceMessages = false.obs;
  final RxBool isSendingRaceMessage = false.obs;

  // Streams
  StreamSubscription<QuerySnapshot>? _chatRoomsSubscription;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<QuerySnapshot>? _raceChatRoomsSubscription;
  StreamSubscription<QuerySnapshot>? _raceMessagesSubscription;

  @override
  void onInit() {
    super.onInit();
    _loadFriends();
    _listenToChatRooms();
    _listenToRaceChatRooms();
  }

  @override
  void onClose() {
    _chatRoomsSubscription?.cancel();
    _messagesSubscription?.cancel();
    _raceChatRoomsSubscription?.cancel();
    _raceMessagesSubscription?.cancel();
    super.onClose();
  }

  // Get current user
  String? get currentUserId => _auth.currentUser?.uid;
  String get currentUserName => _auth.currentUser?.displayName ?? 'User';

  Future<void> _loadFriends() async {
    try {
      isLoading.value = true;
      final currentUser = currentUserId;
      if (currentUser == null) return;

      final querySnapshot = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: currentUser)
          .get();

      friends.clear();
      for (var doc in querySnapshot.docs) {
        try {
          friends.add(Friend.fromFirestore(doc));
        } catch (e) {
          print('Error parsing friend ${doc.id}: $e');
        }
      }
    } catch (e) {
      print('Error loading friends: $e');
      Get.snackbar('Error', 'Failed to load friends');
    } finally {
      isLoading.value = false;
    }
  }

  void _listenToChatRooms() {
    final currentUser = currentUserId;
    if (currentUser == null) return;

    _chatRoomsSubscription = _firestore
        .collection('chat_rooms')
        .where('participant1Id', isEqualTo: currentUser)
        .snapshots()
        .listen((snapshot) {
      _updateChatRoomsFromSnapshot(snapshot);
    });

    // Also listen to chats where current user is participant2
    _firestore
        .collection('chat_rooms')
        .where('participant2Id', isEqualTo: currentUser)
        .snapshots()
        .listen((snapshot) {
      _updateChatRoomsFromSnapshot(snapshot);
    });
  }

  void _updateChatRoomsFromSnapshot(QuerySnapshot snapshot) {
    try {
      for (var docChange in snapshot.docChanges) {
        final chatRoom = ChatRoom.fromFirestore(docChange.doc);

        switch (docChange.type) {
          case DocumentChangeType.added:
          case DocumentChangeType.modified:
            final index = chatRooms.indexWhere((room) => room.id == chatRoom.id);
            if (index != -1) {
              chatRooms[index] = chatRoom;
            } else {
              chatRooms.add(chatRoom);
            }
            break;
          case DocumentChangeType.removed:
            chatRooms.removeWhere((room) => room.id == chatRoom.id);
            break;
        }
      }

      // Sort chat rooms by last message timestamp
      chatRooms.sort((a, b) {
        if (a.lastMessageTimestamp == null && b.lastMessageTimestamp == null) {
          return b.updatedAt.compareTo(a.updatedAt);
        }
        if (a.lastMessageTimestamp == null) return 1;
        if (b.lastMessageTimestamp == null) return -1;
        return b.lastMessageTimestamp!.compareTo(a.lastMessageTimestamp!);
      });
    } catch (e) {
      // Handle error silently in production
    }
  }

  void _listenToRaceChatRooms() {
    final currentUser = currentUserId;
    if (currentUser == null) return;

    _raceChatRoomsSubscription?.cancel();

    _raceChatRoomsSubscription = _firestore
        .collection('race_chat_rooms')
        .where('participantIds', arrayContains: currentUser)
        .snapshots()
        .listen((snapshot) {
      try {
        for (var docChange in snapshot.docChanges) {
          final raceChatRoom = RaceChatRoom.fromFirestore(docChange.doc);

          switch (docChange.type) {
            case DocumentChangeType.added:
            case DocumentChangeType.modified:
              final index = raceChatRooms.indexWhere((room) => room.id == raceChatRoom.id);
              if (index != -1) {
                raceChatRooms[index] = raceChatRoom;
              } else {
                raceChatRooms.add(raceChatRoom);
              }
              break;
            case DocumentChangeType.removed:
              raceChatRooms.removeWhere((room) => room.id == raceChatRoom.id);
              break;
          }
        }

        // Sort race chat rooms by last message timestamp or creation date
        raceChatRooms.sort((a, b) {
          if (a.lastMessageTimestamp == null && b.lastMessageTimestamp == null) {
            return b.createdAt.compareTo(a.createdAt);
          }
          if (a.lastMessageTimestamp == null) return 1;
          if (b.lastMessageTimestamp == null) return -1;
          return b.lastMessageTimestamp!.compareTo(a.lastMessageTimestamp!);
        });
      } catch (e) {
        log('❌ Error updating race chat rooms: $e');
      }
    });
  }

  Future<ChatRoom?> createOrGetChatRoom(String friendId, String friendName, String? friendProfilePicture) async {
    try {
      final currentUser = currentUserId;
      if (currentUser == null) return null;

      // Generate consistent chat room ID
      final chatId = _generateChatId(currentUser, friendId);

      // Check if chat room already exists
      final existingChat = await _firestore
          .collection('chat_rooms')
          .doc(chatId)
          .get();

      if (existingChat.exists) {
        return ChatRoom.fromFirestore(existingChat);
      }

      // Create new chat room
      final chatRoom = ChatRoom(
        id: chatId,
        participant1Id: currentUser,
        participant1Name: currentUserName,
        participant1ProfilePicture: _auth.currentUser?.photoURL,
        participant2Id: friendId,
        participant2Name: friendName,
        participant2ProfilePicture: friendProfilePicture,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('chat_rooms')
          .doc(chatId)
          .set(chatRoom.toJson());

      return chatRoom;
    } catch (e) {
      Get.snackbar('Error', 'Failed to create chat room');
      return null;
    }
  }

  String _generateChatId(String userId1, String userId2) {
    // Generate consistent chat ID by sorting user IDs
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  void openChat(ChatRoom chatRoom) {
    currentChatRoom.value = chatRoom;
    currentChatId.value = chatRoom.id!;
    messages.clear();
    _listenToMessages(chatRoom.id!);
    _markMessagesAsRead(chatRoom.id!);
  }

  void closeChat() {
    _messagesSubscription?.cancel();
    currentChatRoom.value = null;
    currentChatId.value = '';
    messages.clear();
  }

  void _listenToMessages(String chatId) {
    _messagesSubscription?.cancel();

    isLoadingMessages.value = true;
    _messagesSubscription = _firestore
        .collection('chat_messages')
        .where('chatId', isEqualTo: chatId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      try {
        messages.clear();
        for (var doc in snapshot.docs) {
          messages.add(ChatMessage.fromFirestore(doc));
        }
        isLoadingMessages.value = false;
      } catch (e) {
        isLoadingMessages.value = false;
      }
    });
  }

  Future<void> sendMessage(String messageText, {String? replyToMessageId, String? replyToMessage}) async {
    try {
      final currentUser = currentUserId;
      final chatRoom = currentChatRoom.value;

      if (currentUser == null || chatRoom == null || messageText.trim().isEmpty) {
        return;
      }

      isSendingMessage.value = true;

      final message = ChatMessage(
        chatId: chatRoom.id!,
        senderId: currentUser,
        senderName: currentUserName,
        senderProfilePicture: _auth.currentUser?.photoURL,
        receiverId: chatRoom.getOtherParticipantId(currentUser),
        message: messageText.trim(),
        type: MessageType.text,
        timestamp: DateTime.now(),
        replyToMessageId: replyToMessageId,
        replyToMessage: replyToMessage,
      );

      // Add message to collection
      await _firestore
          .collection('chat_messages')
          .add(message.toJson());

      // Update chat room with last message
      final isCurrentUserParticipant1 = chatRoom.participant1Id == currentUser;

      await _firestore
          .collection('chat_rooms')
          .doc(chatRoom.id!)
          .update({
        'lastMessage': messageText.trim(),
        'lastMessageSenderId': currentUser,
        'lastMessageTimestamp': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        // Increment unread count for the other participant
        isCurrentUserParticipant1 ? 'unreadCount2' : 'unreadCount1':
            FieldValue.increment(1),
      });

      // ✅ Notification sent automatically by Cloud Function (onChatMessageCreated)
      // See: functions/notifications/triggers/chatTriggers.js:26-52

    } catch (e) {
      Get.snackbar('Error', 'Failed to send message');
    } finally {
      isSendingMessage.value = false;
    }
  }

  Future<void> _markMessagesAsRead(String chatId) async {
    try {
      final currentUser = currentUserId;
      if (currentUser == null) return;

      final chatRoom = currentChatRoom.value;
      if (chatRoom == null) return;

      // Reset unread count for current user
      final isCurrentUserParticipant1 = chatRoom.participant1Id == currentUser;

      await _firestore
          .collection('chat_rooms')
          .doc(chatId)
          .update({
        isCurrentUserParticipant1 ? 'unreadCount1' : 'unreadCount2': 0,
      });

      // Mark messages as read
      final batch = _firestore.batch();
      final unreadMessages = await _firestore
          .collection('chat_messages')
          .where('chatId', isEqualTo: chatId)
          .where('receiverId', isEqualTo: currentUser)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      // Handle error silently
    }
  }

  int get totalUnreadMessages {
    final currentUser = currentUserId;
    if (currentUser == null) return 0;

    return chatRooms.fold<int>(0, (total, chatRoom) {
      return total + chatRoom.getUnreadCount(currentUser);
    });
  }

  Future<void> refreshChats() async {
    await _loadFriends();
    // Chat rooms are already being listened to, so no need to reload them
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _firestore
          .collection('chat_messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete message');
    }
  }

  Future<void> deleteChatRoom(String chatId) async {
    try {
      // Delete all messages in the chat room
      final messages = await _firestore
          .collection('chat_messages')
          .where('chatId', isEqualTo: chatId)
          .get();

      final batch = _firestore.batch();
      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }

      // Delete the chat room
      batch.delete(_firestore.collection('chat_rooms').doc(chatId));

      await batch.commit();

      // If this is the current chat, close it
      if (currentChatId.value == chatId) {
        closeChat();
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete chat');
    }
  }

  // ================= RACE CHAT METHODS =================

  /// Create or get race chat room for a specific race
  Future<RaceChatRoom?> createOrGetRaceChatRoom(RaceData race) async {
    try {
      final currentUser = currentUserId;
      if (currentUser == null || race.id == null) return null;

      final raceChatId = 'race_${race.id}';

      // Check if race chat room already exists
      final existingRaceChat = await _firestore
          .collection('race_chat_rooms')
          .doc(raceChatId)
          .get();

      if (existingRaceChat.exists) {
        // Update existing race chat room with current participants
        final existingRoom = RaceChatRoom.fromFirestore(existingRaceChat);
        await _updateRaceChatRoomParticipants(race, existingRoom);

        // Fetch the updated room
        final updatedRaceChat = await _firestore
            .collection('race_chat_rooms')
            .doc(raceChatId)
            .get();
        return RaceChatRoom.fromFirestore(updatedRaceChat);
      }

      // Get all race participants
      final participantIds = <String>[];
      final participantNames = <String, String>{};
      final participantProfilePictures = <String, String?>{};
      final unreadCounts = <String, int>{};

      // Add organizer
      if (race.organizerUserId != null) {
        participantIds.add(race.organizerUserId!);
        participantNames[race.organizerUserId!] = race.organizerName ?? 'Organizer';
        participantProfilePictures[race.organizerUserId!] = null;
        unreadCounts[race.organizerUserId!] = 0;
      }

      // Add participants
      if (race.participants != null) {
        for (final participant in race.participants!) {
          if (participant.userId != null && !participantIds.contains(participant.userId)) {
            participantIds.add(participant.userId!);
            participantNames[participant.userId!] = participant.userName ?? 'Participant';
            participantProfilePictures[participant.userId!] = participant.userProfilePicture;
            unreadCounts[participant.userId!] = 0;
          }
        }
      }

      // Create new race chat room
      final raceChatRoom = RaceChatRoom(
        id: raceChatId,
        raceId: race.id!,
        raceTitle: race.title ?? 'Race Chat',
        participantIds: participantIds,
        participantNames: participantNames,
        participantProfilePictures: participantProfilePictures,
        unreadCounts: unreadCounts,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('race_chat_rooms')
          .doc(raceChatId)
          .set(raceChatRoom.toJson());

      return raceChatRoom;
    } catch (e) {
      log('❌ Error creating race chat room: $e');
      Get.snackbar('Error', 'Failed to create race chat room');
      return null;
    }
  }

  /// Open race chat and start listening to messages
  void openRaceChat(RaceChatRoom raceChatRoom) {
    currentRaceChatRoom.value = raceChatRoom;
    currentRaceChatId.value = raceChatRoom.id!;
    raceMessages.clear();
    _listenToRaceMessages(raceChatRoom.id!);
    _markRaceMessagesAsRead(raceChatRoom.id!, raceChatRoom.raceId);
  }

  /// Close race chat and stop listening
  void closeRaceChat() {
    _raceMessagesSubscription?.cancel();
    currentRaceChatRoom.value = null;
    currentRaceChatId.value = '';
    raceMessages.clear();
  }

  /// Listen to race messages in real-time
  void _listenToRaceMessages(String raceChatId) {
    _raceMessagesSubscription?.cancel();

    isLoadingRaceMessages.value = true;
    _raceMessagesSubscription = _firestore
        .collection('race_chat_messages')
        .where('raceChatId', isEqualTo: raceChatId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      try {
        raceMessages.clear();
        for (var doc in snapshot.docs) {
          raceMessages.add(RaceChatMessage.fromFirestore(doc));
        }
        isLoadingRaceMessages.value = false;
      } catch (e) {
        isLoadingRaceMessages.value = false;
        log('❌ Error loading race messages: $e');
      }
    });
  }

  /// Send a message to race chat
  Future<void> sendRaceMessage(String messageText, {String? replyToMessageId, String? replyToMessage}) async {
    try {
      final currentUser = currentUserId;
      final raceChatRoom = currentRaceChatRoom.value;

      if (currentUser == null || raceChatRoom == null || messageText.trim().isEmpty) {
        return;
      }

      isSendingRaceMessage.value = true;

      final message = RaceChatMessage(
        raceChatId: raceChatRoom.id!,
        raceId: raceChatRoom.raceId,
        senderId: currentUser,
        senderName: currentUserName,
        senderProfilePicture: _auth.currentUser?.photoURL,
        message: messageText.trim(),
        type: MessageType.text,
        timestamp: DateTime.now(),
        replyToMessageId: replyToMessageId,
        replyToMessage: replyToMessage,
      );

      // Add message to collection
      await _firestore
          .collection('race_chat_messages')
          .add(message.toJson());

      // Update race chat room with last message and increment unread counts
      final updatedUnreadCounts = Map<String, int>.from(raceChatRoom.unreadCounts);
      for (String participantId in raceChatRoom.participantIds) {
        if (participantId != currentUser) {
          updatedUnreadCounts[participantId] = (updatedUnreadCounts[participantId] ?? 0) + 1;
        }
      }

      await _firestore
          .collection('race_chat_rooms')
          .doc(raceChatRoom.id!)
          .update({
        'lastMessage': messageText.trim(),
        'lastMessageSenderId': currentUser,
        'lastMessageTimestamp': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'unreadCounts': updatedUnreadCounts,
      });

      // ✅ Notification sent automatically by Cloud Function (onRaceChatMessageCreated)
      // See: functions/notifications/triggers/chatTriggers.js:60-116

    } catch (e) {
      log('❌ Error sending race message: $e');
      Get.snackbar('Error', 'Failed to send message');
    } finally {
      isSendingRaceMessage.value = false;
    }
  }

  /// Mark race messages as read for current user
  Future<void> _markRaceMessagesAsRead(String raceChatId, String raceId) async {
    try {
      final currentUser = currentUserId;
      if (currentUser == null) return;

      // Reset unread count for current user
      await _firestore
          .collection('race_chat_rooms')
          .doc(raceChatId)
          .update({
        'unreadCounts.$currentUser': 0,
      });

      // Mark messages as read (not implemented for race chat yet - would need receiverId array)
      // This is optional since we're using unreadCounts at room level
    } catch (e) {
      log('❌ Error marking race messages as read: $e');
    }
  }

  /// Get total unread race messages for current user
  int get totalUnreadRaceMessages {
    final currentUser = currentUserId;
    if (currentUser == null) return 0;

    return raceChatRooms.fold<int>(0, (total, raceChatRoom) {
      return total + raceChatRoom.getUnreadCount(currentUser);
    });
  }

  /// Get unread count for specific race
  int getUnreadRaceMessageCount(String raceId) {
    final currentUser = currentUserId;
    if (currentUser == null) return 0;

    final raceChatRoom = raceChatRooms.firstWhereOrNull(
      (room) => room.raceId == raceId,
    );

    return raceChatRoom?.getUnreadCount(currentUser) ?? 0;
  }

  // ================= NOTIFICATION METHODS =================
  // ✅ All chat notifications are now handled by Cloud Functions!
  // See: functions/notifications/triggers/chatTriggers.js
  //
  // Automatic triggers:
  // - onChatMessageCreated: Sends notification when chat_messages doc is created
  // - onRaceChatMessageCreated: Sends notifications to all race participants when race_chat_messages doc is created

  /// Update race chat room participants when race data changes
  Future<void> _updateRaceChatRoomParticipants(RaceData race, RaceChatRoom existingRoom) async {
    try {
      // Get all current race participants
      final participantIds = <String>[];
      final participantNames = <String, String>{};
      final participantProfilePictures = <String, String?>{};
      final unreadCounts = <String, int>{};

      // Add organizer
      if (race.organizerUserId != null) {
        participantIds.add(race.organizerUserId!);
        participantNames[race.organizerUserId!] = race.organizerName ?? 'Organizer';
        participantProfilePictures[race.organizerUserId!] = null;
        // Preserve existing unread count or default to 0
        unreadCounts[race.organizerUserId!] = existingRoom.unreadCounts[race.organizerUserId!] ?? 0;
      }

      // Add participants
      if (race.participants != null) {
        for (final participant in race.participants!) {
          if (participant.userId != null && !participantIds.contains(participant.userId)) {
            participantIds.add(participant.userId!);
            participantNames[participant.userId!] = participant.userName ?? 'Participant';
            participantProfilePictures[participant.userId!] = participant.userProfilePicture;
            // Preserve existing unread count or default to 0
            unreadCounts[participant.userId!] = existingRoom.unreadCounts[participant.userId!] ?? 0;
          }
        }
      }

      // Only update if participant list has changed
      if (!_areParticipantListsEqual(participantIds, existingRoom.participantIds)) {
        await _firestore
            .collection('race_chat_rooms')
            .doc(existingRoom.id)
            .update({
          'participantIds': participantIds,
          'participantNames': participantNames,
          'participantProfilePictures': participantProfilePictures,
          'unreadCounts': unreadCounts,
          'updatedAt': DateTime.now().toIso8601String(),
        });

        log('✅ Updated race chat room participants: ${participantIds.length} participants');
      }
    } catch (e) {
      log('❌ Error updating race chat room participants: $e');
    }
  }

  /// Check if two participant lists are equal
  bool _areParticipantListsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;

    // Sort both lists for comparison
    final sortedList1 = [...list1]..sort();
    final sortedList2 = [...list2]..sort();

    for (int i = 0; i < sortedList1.length; i++) {
      if (sortedList1[i] != sortedList2[i]) return false;
    }

    return true;
  }

}