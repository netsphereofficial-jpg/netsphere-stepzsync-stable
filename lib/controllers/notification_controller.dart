import 'package:get/get.dart';

import '../core/utils/common_methods.dart';
import '../models/notification_model.dart';
import '../services/notification_repository.dart';
import '../services/unified_notification_service.dart';

class TranslationKeys {
  static const String internetError = 'internetError';
}

extension TranslationExtension on String {
  String get tr {
    switch (this) {
      case 'internetError':
        return 'No internet connection';
      default:
        return this;
    }
  }
}

class NotificationController extends GetxController {
  final NotificationRepository _notificationRepository =
      NotificationRepository();
  final allNotifications = <NotificationModel>[].obs;

  var activeTab = 'All'.obs;
  var selectionMode = false.obs;

  void setTab(String tab) {
    activeTab.value = tab;
    getNotificationList(tab == "Unread" ? false : null);
  }

  void markAllRead() async {
    if (allNotifications.isEmpty) {
      showSnackbar('', "Notification list is empty!");
      return;
    }
    await markReadNotificationsByFirebaseIds([], true);
  }

  @override
  void onInit() {
    getNotificationList(null);
    super.onInit();
  }

  void deleteAll() async {
    if (allNotifications.isEmpty) {
      showSnackbar('', "Notification list is empty!");
      return;
    }
    await deleteNotificationsByFirebaseIds([], true);
  }

  int selectedSize() =>
      allNotifications.where((item) => item.isSelected).length;

  void deleteSelected() async {
    var selectedList = <String>[];
    for (var n in allNotifications) {
      if (n.isSelected && n.firebaseId != null) {
        selectedList.add(n.firebaseId!);
      }
    }

    await deleteNotificationsByFirebaseIds(selectedList, false);
  }

  void readSelected() async {
    var selectedList = <String>[];
    for (var n in allNotifications) {
      if (n.isSelected && n.firebaseId != null) {
        selectedList.add(n.firebaseId!);
      }
    }
    await markReadNotificationsByFirebaseIds(selectedList, false);
  }

  Map<String, List<NotificationModel>> get groupedNotifications {
    final filtered = allNotifications.where(
      (n) => activeTab.value == 'All' ? true : n.isRead == false,
    );
    final grouped = <String, List<NotificationModel>>{};
    for (var n in filtered) {
      grouped[n.category] = [...(grouped[n.category] ?? []), n];
    }
    return grouped;
  }

  void unselectAll() {
    for (var item in allNotifications) {
      item.isSelected = false;
    }
    allNotifications.refresh();
  }

  Future<void> getNotificationList(bool? isRead) async {
    try {
      print('🔄 Loading notifications - isRead filter: $isRead');

      // Use real Firebase notifications
      if (!await isNetworkAvailable()) {
        print('❌ No internet connection available');
        showSnackbar('', TranslationKeys.internetError);
        return;
      }

      print('📡 Calling notification repository...');
      var response = await _notificationRepository.getNotificationList(isRead);

      if (response != null) {
        print('📦 Repository response: ${response['status']} - ${response['message']}');

        if (response['status'] == 200) {
          if (response['data'] != null) {
            final notifications = parseNotifications(response['data'] ?? []);
            allNotifications.value = notifications;
            print('✅ Successfully loaded ${notifications.length} notifications');
          } else {
            allNotifications.clear();
            print('📭 No notification data received');
          }
        } else {
          final errorMessage = response['message'] ?? 'Failed to load notifications';
          print('❌ Repository error: $errorMessage');

          // Check for Firebase index error
          if (errorMessage.contains('index')) {
            print('🔥 FIREBASE INDEX ERROR DETECTED:');
            print('🔗 Please create the required index using this link:');
            print('   Error: $errorMessage');

            showSnackbar('Firebase Index Required',
              'Please check console for index creation link');
          } else {
            showSnackbar('', errorMessage);
          }
        }
      } else {
        allNotifications.clear();
        print('❌ Repository returned null response');
      }

      // Fallback to static notifications for development (comment this out in production)
      // allNotifications.value = StaticNotificationsService.getFilteredNotifications(isRead);
    } catch (e, stackTrace) {
      print('💥 Exception in getNotificationList: $e');
      print('📍 Stack trace: $stackTrace');

      // Check for specific Firebase errors
      if (e.toString().contains('index')) {
        print('🔥 FIREBASE INDEX ERROR IN EXCEPTION:');
        print('🔗 Error details: $e');
        showSnackbar('Firebase Index Required',
          'Please check console for index creation details');
      } else {
        showSnackbar('Error', 'Failed to load notifications: ${e.toString()}');
      }

      allNotifications.clear();
    }
  }

  Future<void> markReadNotificationsByFirebaseIds(List<String> firebaseIds, bool all) async {
    if (!await isNetworkAvailable()) {
      showSnackbar('', TranslationKeys.internetError);
      return;
    }
    var response = await _notificationRepository.markAsReadByFirebaseIds(firebaseIds);
    if (response != null) {
      if (response['status'] == 200) {
        for (var n in allNotifications) {
          if (all) {
            n.isRead = true;
          } else {
            if (n.isSelected) {
              n.isRead = true;
            }
          }
        }
        selectionMode.value = false;
        allNotifications.refresh();
        showSnackbar("", response['message']);
      } else {
        showSnackbar("", response['message']);
      }
    }
  }

  Future<void> markReadNotifications(List<int> list, bool all) async {
    if (!await isNetworkAvailable()) {
      showSnackbar('', TranslationKeys.internetError);
      return;
    }
    var response = await _notificationRepository.markAsReadApi(list);
    if (response != null) {
      if (response['status'] == 200) {
        for (var n in allNotifications) {
          if (all) {
            n.isRead = true;
          } else {
            if (n.isSelected) {
              n.isRead = true;
            }
          }
        }
        selectionMode.value = false;
        allNotifications.refresh();
        showSnackbar("", response['message']);
      } else {
        showSnackbar("", response['message']);
      }
    }
  }

  Future<void> singleReadNotificationByFirebaseId(String firebaseId) async {
    if (!await isNetworkAvailable()) {
      showSnackbar('', TranslationKeys.internetError);
      return;
    }
    var response = await _notificationRepository.markAsReadByFirebaseIds([firebaseId]);
    if (response != null) {
      if (response['status'] == 200) {
        for (var n in allNotifications) {
          if (n.firebaseId == firebaseId) {
            n.isRead = true;
          }
        }
        allNotifications.refresh();
      } else {
        showSnackbar("", response['message']);
      }
    }
  }

  Future<void> singleReadNotifications(var id) async {
    if (!await isNetworkAvailable()) {
      showSnackbar('', TranslationKeys.internetError);
      return;
    }
    var response = await _notificationRepository.markAsReadApi([id]);
    if (response != null) {
      if (response['status'] == 200) {
        for (var n in allNotifications) {
          if (n.id == id) {
            n.isRead = true;
          }
        }
        allNotifications.refresh();
      } else {
        print('${response['message']}');
        showSnackbar("", response['message']);
      }
    }
  }

  Future<void> deleteNotificationsByFirebaseIds(List<String> firebaseIds, bool all) async {
    if (!await isNetworkAvailable()) {
      showSnackbar('', TranslationKeys.internetError);
      return;
    }
    var response = await _notificationRepository.deleteNotificationsByFirebaseIds(firebaseIds);
    if (response != null) {
      if (response['status'] == 200) {
        if (all) {
          allNotifications.clear();
        } else {
          final filtered = allNotifications
              .where((n) => !n.isSelected)
              .toList();
          allNotifications.value = filtered;
        }
        selectionMode.value = false;
        allNotifications.refresh();

        showSnackbar("", response['message']);
      } else {
        showSnackbar("", response['message']);
      }
    }
  }

  Future<void> deleteNotifications(List<int> list, bool all) async {
    if (!await isNetworkAvailable()) {
      showSnackbar('', TranslationKeys.internetError);
      return;
    }
    var response = await _notificationRepository.deleteNotificationApi(list);
    if (response != null) {
      if (response['status'] == 200) {
        if (all) {
          allNotifications.clear();
        } else {
          final filtered = allNotifications
              .where((n) => !n.isSelected)
              .toList();
          allNotifications.value = filtered;
        }
        selectionMode.value = false;
        allNotifications.refresh();

        showSnackbar("", response['message']);
      } else {
        showSnackbar("", response['message']);
      }
    }
  }

  void onNotificationClick(NotificationModel model) {
    switch (model.notificationType) {
      case "InviteRace":
        // Navigate to race details or race invite screen
        if (model.raceId != null) {
          Get.toNamed('/race', arguments: {'raceId': model.raceId});
        }
        break;
      case "RaceParticipant":
      case "RaceBegin":
      case "RaceOver":
      case "RaceWon":
      case "RaceWinnerCrossing":
      case "OvertakingParticipant":
      case "EndTimer":
        // Navigate to active races or race details
        if (model.raceId != null) {
          Get.toNamed('/active-races', arguments: {'raceId': model.raceId});
        } else {
          Get.toNamed('/active-races');
        }
        break;
      case "Marathon":
      case "ActiveMarathon":
        // Navigate to marathon screen
        Get.toNamed('/marathon');
        break;
      case "FriendRequest":
        // Navigate to friends screen
        Get.toNamed('/friends');
        break;
      case "HallOfFame":
        // Navigate to hall of fame
        Get.toNamed('/hall-of-fame');
        break;
      case "General":
      default:
        // Default action or no navigation
        break;
    }
  }

  // MARK: - Unified Notification Methods

  /// Create notification that saves to list AND sends push notification
  Future<void> createUnifiedNotification({
    required String title,
    required String message,
    required String notificationType,
    String category = 'General',
    String icon = '🔔',
    String? thumbnail,
    String? userId,
    String? userName,
    String? raceId,
    String? raceName,
    Map<String, dynamic>? metadata,
  }) async {
    await UnifiedNotificationService.createAndPushNotification(
      title: title,
      message: message,
      notificationType: notificationType,
      category: category,
      icon: icon,
      thumbnail: thumbnail,
      userId: userId,
      userName: userName,
      raceId: raceId,
      raceName: raceName,
      metadata: metadata,
    );
  }

  /// Push notification for existing notification in the list
  Future<void> pushExistingNotification(NotificationModel notification) async {
    await UnifiedNotificationService.pushExistingNotification(notification);
  }

  /// Refresh notifications and optionally push recent unread ones
  Future<void> refreshWithPush({bool pushRecent = false}) async {
    await UnifiedNotificationService.refreshNotificationsWithPush(
      pushRecent: pushRecent,
    );
  }

  // MARK: - Convenient unified notification methods

  /// Send race invite (saves + pushes)
  Future<void> sendRaceInvite({
    required String title,
    required String message,
    required String raceId,
    required String raceName,
    String? inviterName,
    String? inviterUserId,
  }) async {
    await UnifiedNotificationService.sendRaceInviteNotification(
      title: title,
      message: message,
      raceId: raceId,
      raceName: raceName,
      inviterName: inviterName,
      inviterUserId: inviterUserId,
    );
  }

  /// Send race start notification (saves + pushes)
  Future<void> sendRaceStart({
    required String title,
    required String message,
    required String raceId,
    required String raceName,
  }) async {
    await UnifiedNotificationService.sendRaceStartNotification(
      title: title,
      message: message,
      raceId: raceId,
      raceName: raceName,
    );
  }

  /// Send race won notification (saves + pushes)
  Future<void> sendRaceWon({
    required String title,
    required String message,
    required String raceId,
    required String raceName,
    required int rank,
    int? xpEarned,
  }) async {
    await UnifiedNotificationService.sendRaceWonNotification(
      title: title,
      message: message,
      raceId: raceId,
      raceName: raceName,
      rank: rank,
      xpEarned: xpEarned,
    );
  }

  /// Send friend request notification (saves + pushes)
  Future<void> sendFriendRequest({
    required String title,
    required String message,
    required String fromUserId,
    required String fromUserName,
    String? thumbnail,
    int? mutualFriends,
  }) async {
    await UnifiedNotificationService.sendFriendRequestNotification(
      title: title,
      message: message,
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      thumbnail: thumbnail,
      mutualFriends: mutualFriends,
    );
  }

  /// Send achievement notification (saves + pushes)
  Future<void> sendAchievement({
    required String title,
    required String message,
    String type = 'HallOfFame',
    int? xpEarned,
  }) async {
    await UnifiedNotificationService.sendAchievementNotification(
      title: title,
      message: message,
      type: type,
      xpEarned: xpEarned,
    );
  }

  /// Send marathon notification (saves + pushes)
  Future<void> sendMarathon({
    required String title,
    required String message,
    bool isActive = false,
  }) async {
    await UnifiedNotificationService.sendMarathonNotification(
      title: title,
      message: message,
      isActive: isActive,
    );
  }

  /// Send general notification (saves + pushes)
  Future<void> sendGeneral({
    required String title,
    required String message,
    String icon = '🔔',
  }) async {
    await UnifiedNotificationService.sendGeneralNotification(
      title: title,
      message: message,
      icon: icon,
    );
  }

  /// Test method to create sample unified notifications
  Future<void> createTestUnifiedNotifications() async {
    await UnifiedNotificationService.createTestNotifications();
  }
}
