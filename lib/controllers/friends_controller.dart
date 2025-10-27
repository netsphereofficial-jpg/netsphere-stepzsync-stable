import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/friend_models.dart';
import '../services/friends_service.dart';
import '../core/utils/snackbar_utils.dart';

class FriendsController extends GetxController {
  // Tab management
  final selectedTabIndex = 0.obs;
  final PageController pageController = PageController();

  // Search functionality
  final searchController = TextEditingController();
  final searchResults = <UserSearchResult>[].obs;
  final isSearching = false.obs;
  final searchQuery = ''.obs;

  // Friends data
  final friends = <Friend>[].obs;
  final receivedRequests = <FriendRequest>[].obs;
  final sentRequests = <FriendRequest>[].obs;

  // Loading states
  final isLoadingFriends = false.obs;
  final isLoadingRequests = false.obs;
  final isLoadingSearch = false.obs;
  final requestActionLoading = <String, bool>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadFriendsData();

    // Setup search debouncing
    searchController.addListener(() {
      searchQuery.value = searchController.text;
      if (searchController.text.isEmpty) {
        searchResults.clear();
        isSearching.value = false;
      } else {
        _debounceSearch();
      }
    });
  }

  @override
  void onClose() {
    searchController.dispose();
    pageController.dispose();
    super.onClose();
  }

  // Tab management
  void changeTab(int index) {
    selectedTabIndex.value = index;
    pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void onPageChanged(int index) {
    selectedTabIndex.value = index;
  }

  // Load all friends data
  Future<void> loadFriendsData() async {
    await Future.wait([
      loadFriends(),
      loadReceivedRequests(),
      loadSentRequests(),
    ]);
  }

  // Load friends list
  Future<void> loadFriends() async {
    try {
      isLoadingFriends.value = true;
      final result = await FriendsService.getFriends();
      friends.value = result;
    } catch (e) {
      print("$e");
      SnackbarUtils.showError('Error', 'Failed to load friends: ${e.toString()}');
    } finally {
      isLoadingFriends.value = false;
    }
  }

  // Load received requests
  Future<void> loadReceivedRequests() async {
    try {
      isLoadingRequests.value = true;
      final result = await FriendsService.getReceivedRequests();
      receivedRequests.value = result;
    } catch (e) {
      print(e);
      SnackbarUtils.showError('Error', 'Failed to load requests: ${e.toString()}');
    } finally {
      isLoadingRequests.value = false;
    }
  }

  // Load sent requests
  Future<void> loadSentRequests() async {
    try {
      final result = await FriendsService.getSentRequests();
      sentRequests.value = result;
    } catch (e) {
      SnackbarUtils.showError('Error', 'Failed to load sent requests: ${e.toString()}');
      print(e);

    }
  }

  // Search functionality
  void _debounceSearch() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (searchController.text == searchQuery.value && searchQuery.value.isNotEmpty) {
        searchUsers();
      }
    });
  }

  Future<void> searchUsers() async {
    final query = searchQuery.value.trim();
    if (query.isEmpty) return;

    try {
      isLoadingSearch.value = true;
      isSearching.value = true;
      final results = await FriendsService.searchUsers(query);
      searchResults.value = results;
    } catch (e) {
      SnackbarUtils.showError('Search Error', e.toString());
    } finally {
      isLoadingSearch.value = false;
    }
  }

  void clearSearch() {
    searchController.clear();
    searchResults.clear();
    isSearching.value = false;
    searchQuery.value = '';
  }

  // Friend request actions
  Future<void> sendFriendRequest(UserSearchResult user) async {
    try {
      requestActionLoading[user.id] = true;
      requestActionLoading.refresh();

      await FriendsService.sendFriendRequest(user.id, user.fullName, user.username);

      // Update user status in search results
      final index = searchResults.indexWhere((u) => u.id == user.id);
      if (index != -1) {
        searchResults[index] = UserSearchResult(
          id: user.id,
          fullName: user.fullName,
          username: user.username,
          profilePicture: user.profilePicture,
          email: user.email,
          location: user.location,
          friendshipStatus: FriendshipStatus.requestSent,
        );
        searchResults.refresh();
      }

      SnackbarUtils.showSuccess('Success', 'Friend request sent to ${user.fullName}');
      await loadSentRequests();
    } catch (e) {
      SnackbarUtils.showError('Error', 'Failed to send friend request: ${e.toString()}');
    } finally {
      requestActionLoading[user.id] = false;
      requestActionLoading.refresh();
    }
  }

  Future<void> acceptFriendRequest(FriendRequest request) async {
    try {
      requestActionLoading[request.id!] = true;
      requestActionLoading.refresh();

      await FriendsService.acceptFriendRequest(request.id!);

      SnackbarUtils.showSuccess('Success', 'You are now friends with ${request.senderName}');

      // Refresh all data
      await loadFriendsData();
    } catch (e) {
      SnackbarUtils.showError('Error', 'Failed to accept friend request: ${e.toString()}');
    } finally {
      requestActionLoading[request.id!] = false;
      requestActionLoading.refresh();
    }
  }

  Future<void> declineFriendRequest(FriendRequest request) async {
    try {
      requestActionLoading[request.id!] = true;
      requestActionLoading.refresh();

      await FriendsService.declineFriendRequest(request.id!);

      SnackbarUtils.showInfo('Declined', 'Friend request from ${request.senderName} declined');

      await loadReceivedRequests();
    } catch (e) {
      SnackbarUtils.showError('Error', 'Failed to decline friend request: ${e.toString()}');
    } finally {
      requestActionLoading[request.id!] = false;
      requestActionLoading.refresh();
    }
  }

  Future<void> cancelFriendRequest(UserSearchResult user) async {
    try {
      requestActionLoading[user.id] = true;
      requestActionLoading.refresh();

      await FriendsService.cancelFriendRequest(user.id);

      // Update user status in search results
      final index = searchResults.indexWhere((u) => u.id == user.id);
      if (index != -1) {
        searchResults[index] = UserSearchResult(
          id: user.id,
          fullName: user.fullName,
          username: user.username,
          profilePicture: user.profilePicture,
          email: user.email,
          location: user.location,
          friendshipStatus: FriendshipStatus.none,
        );
        searchResults.refresh();
      }

      SnackbarUtils.showInfo('Cancelled', 'Friend request to ${user.fullName} cancelled');
      await loadSentRequests();
    } catch (e) {
      SnackbarUtils.showError('Error', 'Failed to cancel friend request: ${e.toString()}');
    } finally {
      requestActionLoading[user.id] = false;
      requestActionLoading.refresh();
    }
  }

  Future<void> removeFriend(Friend friend) async {
    try {
      // Show confirmation dialog
      final confirmed = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Remove Friend'),
          content: Text('Are you sure you want to remove ${friend.friendName} from your friends list?'),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      requestActionLoading[friend.id!] = true;
      requestActionLoading.refresh();

      await FriendsService.removeFriend(friend.friendId);

      SnackbarUtils.showInfo('Removed', '${friend.friendName} removed from friends');
      await loadFriends();
    } catch (e) {
      SnackbarUtils.showError('Error', 'Failed to remove friend: ${e.toString()}');
    } finally {
      requestActionLoading[friend.id!] = false;
      requestActionLoading.refresh();
    }
  }

  // Utility methods
  bool isRequestActionLoading(String id) {
    return requestActionLoading[id] ?? false;
  }

  int get friendsCount => friends.length;
  int get receivedRequestsCount => receivedRequests.length;
  int get sentRequestsCount => sentRequests.length;

  // Refresh data
  @override
  Future<void> refresh() async {
    await loadFriendsData();
    if (searchQuery.value.isNotEmpty) {
      await searchUsers();
    }
  }
}