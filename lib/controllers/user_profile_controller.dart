import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/profile_models.dart';
import '../models/friend_models.dart';
import '../services/user_profile_service.dart';
import '../services/friends_service.dart';

class UserProfileController extends GetxController {
  var isLoading = true.obs;
  var isStatsLoading = false.obs;
  var profile = Rx<UserProfile?>(null);
  var userStats = Rx<Map<String, dynamic>>({});
  var currentUserId = '';
  var friendshipStatus = FriendshipStatus.none.obs;

  Future<void> loadProfile(String userId) async {
    try {
      print('🚀 UserProfileController: Loading profile for $userId');
      isLoading.value = true;
      currentUserId = userId;

      // Fetch user profile from Firebase
      final userProfile = await UserProfileService.getUserProfile(userId);

      if (userProfile != null) {
        profile.value = userProfile;
        print('✅ UserProfileController: Profile loaded successfully');

        // Load friendship status and stats in parallel
        _loadFriendshipStatus(userId);
        _loadUserStats(userId);
      } else {
        print('❌ UserProfileController: Profile not found');
        profile.value = null;
      }
    } catch (e) {
      print('❌ UserProfileController: Error loading profile: $e');
      profile.value = null;

      // Show error to user
      Get.snackbar(
        'Error',
        'Failed to load profile. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error.withValues(alpha: 0.8),
        colorText: Get.theme.colorScheme.onError,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadUserStats(String userId) async {
    try {
      isStatsLoading.value = true;
      print('📊 UserProfileController: Loading stats for $userId');

      final stats = await UserProfileService.getUserStats(userId);
      userStats.value = stats;

      print('✅ UserProfileController: Stats loaded successfully');
    } catch (e) {
      print('❌ UserProfileController: Error loading stats: $e');
      userStats.value = {};
    } finally {
      isStatsLoading.value = false;
    }
  }

  Future<void> _loadFriendshipStatus(String userId) async {
    try {
      print('🤝 UserProfileController: Loading friendship status for $userId');
      final status = await FriendsService.getFriendshipStatus(userId);
      friendshipStatus.value = status;
      print('✅ UserProfileController: Friendship status loaded: ${status.value}');
    } catch (e) {
      print('❌ UserProfileController: Error loading friendship status: $e');
      friendshipStatus.value = FriendshipStatus.none;
    }
  }

  var isSendingRequest = false.obs;

  Future<void> sendFriendRequest() async {
    if (profile.value == null || isSendingRequest.value) return;

    try {
      isSendingRequest.value = true;

      print('🤝 UserProfileController: Sending friend request to ${profile.value!.fullName}');

      await FriendsService.sendFriendRequest(
        profile.value!.id!,
        profile.value!.fullName,
        profile.value!.username,
      );

      print('✅ UserProfileController: Friend request sent successfully');

      // Update friendship status
      friendshipStatus.value = FriendshipStatus.requestSent;

      Get.snackbar(
        'Success',
        'Friend request sent to ${profile.value!.fullName}!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.primaryColor.withValues(alpha: 0.9),
        colorText: Get.theme.colorScheme.onPrimary,
        duration: const Duration(seconds: 3),
        icon: Icon(
          Icons.check_circle_outline,
          color: Colors.white,
        ),
      );
    } catch (e) {
      print('❌ UserProfileController: Error sending friend request: $e');

      String errorMessage = 'Failed to send friend request';
      if (e.toString().contains('User profile not found')) {
        errorMessage = 'User profile not found';
      } else if (e.toString().contains('already exists')) {
        errorMessage = 'Friend request already sent';
      }

      Get.snackbar(
        'Error',
        errorMessage,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error.withValues(alpha: 0.9),
        colorText: Get.theme.colorScheme.onError,
        duration: const Duration(seconds: 3),
        icon: const Icon(
          Icons.error_outline,
          color: Colors.white,
        ),
      );
    } finally {
      isSendingRequest.value = false;
    }
  }

  /// Refresh profile data
  Future<void> refreshProfile() async {
    if (currentUserId.isNotEmpty) {
      await loadProfile(currentUserId);
    }
  }

  /// Remove friend
  var isRemovingFriend = false.obs;

  Future<void> removeFriend() async {
    if (profile.value == null || isRemovingFriend.value) return;

    try {
      isRemovingFriend.value = true;

      print('💔 UserProfileController: Removing friend ${profile.value!.fullName}');

      await FriendsService.removeFriend(profile.value!.id!);

      // Update friendship status
      friendshipStatus.value = FriendshipStatus.none;

      print('✅ UserProfileController: Friend removed successfully');

      Get.snackbar(
        'Success',
        'Removed ${profile.value!.fullName} from friends',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.primaryColor.withValues(alpha: 0.9),
        colorText: Get.theme.colorScheme.onPrimary,
        duration: const Duration(seconds: 3),
        icon: Icon(
          Icons.check_circle_outline,
          color: Colors.white,
        ),
      );
    } catch (e) {
      print('❌ UserProfileController: Error removing friend: $e');

      Get.snackbar(
        'Error',
        'Failed to remove friend',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error.withValues(alpha: 0.9),
        colorText: Get.theme.colorScheme.onError,
        duration: const Duration(seconds: 3),
        icon: const Icon(
          Icons.error_outline,
          color: Colors.white,
        ),
      );
    } finally {
      isRemovingFriend.value = false;
    }
  }

  /// Check if current user can send friend request to this profile
  bool canSendFriendRequest() {
    if (profile.value == null) return false;

    final currentUser = UserProfileService.currentUserId;
    if (currentUser == null) return false;

    // Can't send request to yourself
    if (currentUser == profile.value!.id) return false;

    // Can only send request if no relationship exists
    return friendshipStatus.value == FriendshipStatus.none;
  }

  /// Check if users are friends
  bool areFriends() {
    return friendshipStatus.value == FriendshipStatus.friends;
  }

  /// Check if request is pending (sent or received)
  bool isRequestPending() {
    return friendshipStatus.value == FriendshipStatus.requestSent ||
           friendshipStatus.value == FriendshipStatus.requestReceived;
  }

  /// Check if viewing own profile
  bool isOwnProfile() {
    if (profile.value == null) return false;
    final currentUser = UserProfileService.currentUserId;
    return currentUser == profile.value!.id;
  }
}