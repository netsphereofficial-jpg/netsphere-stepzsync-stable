import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/text_styles.dart';
import '../../core/models/race_data_model.dart';
import '../../services/race_invite_service.dart';
import '../../widgets/common/profile_image_widget.dart';

class InviteUsersScreen extends StatefulWidget {
  final RaceData race;

  const InviteUsersScreen({
    super.key,
    required this.race,
  });

  @override
  State<InviteUsersScreen> createState() => _InviteUsersScreenState();
}

class _InviteUsersScreenState extends State<InviteUsersScreen> {
  final RaceInviteService _inviteService = RaceInviteService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  final RxList<Map<String, dynamic>> searchResults = <Map<String, dynamic>>[].obs;
  final RxList<String> selectedUsers = <String>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSearching = false.obs;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.length >= 2) {
      _searchUsers(query);
    } else {
      searchResults.clear();
    }
  }

  Future<void> _searchUsers(String query) async {
    isSearching.value = true;
    try {
      final results = await _inviteService.searchUsers(query);
      searchResults.assignAll(results);
    } catch (e) {
      Get.snackbar('Error', 'Failed to search users');
    } finally {
      isSearching.value = false;
    }
  }

  Future<void> _sendInvites() async {
    if (selectedUsers.isEmpty) {
      Get.snackbar('Error', 'Please select at least one user to invite');
      return;
    }

    isLoading.value = true;
    int successCount = 0;
    int failCount = 0;

    for (final userId in selectedUsers) {
      final user = searchResults.firstWhere((u) => u['id'] == userId);

      final success = await _inviteService.sendPrivateRaceInvite(
        race: widget.race,
        toUserId: userId,
        toUserName: user['fullName'] ?? user['email'],
        message: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
      );

      if (success) {
        successCount++;
      } else {
        failCount++;
      }
    }

    isLoading.value = false;

    if (successCount > 0) {
      Get.snackbar(
        'Success!',
        'Sent $successCount invite${successCount > 1 ? 's' : ''} successfully${failCount > 0 ? '. $failCount failed.' : '.'}',
        backgroundColor: const Color(0xFF35B555),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );

      if (failCount == 0) {
        Get.back(); // Go back if all were successful
      }
    } else {
      Get.snackbar(
        'Error',
        'Failed to send invites. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Invite Friends',
          style: AppTextStyles.heroHeading,
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Race info card
          _buildRaceInfoCard(),

          // Search section
          _buildSearchSection(),

          // Search results
          Expanded(
            child: _buildSearchResults(),
          ),

          // Message input
          _buildMessageInput(),

          // Send invites button
          _buildSendButton(),
        ],
      ),
    );
  }

  Widget _buildRaceInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2759FF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2759FF).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inviting to:',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.race.title ?? 'Unknown Race',
            style: AppTextStyles.cardHeading.copyWith(
              color: const Color(0xFF2759FF),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildRaceDetailChip(
                Icons.location_on,
                widget.race.startAddress ?? 'Unknown Location',
                const Color(0xFF2759FF),
              ),
              const SizedBox(width: 8),
              _buildRaceDetailChip(
                Icons.straighten,
                '${(widget.race.totalDistance ?? 0.0).toStringAsFixed(1)} km',
                const Color(0xFF35B555),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRaceDetailChip(IconData icon, String text, Color color) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search Friends',
            style: AppTextStyles.cardHeading,
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.grey[500],
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: Obx(() => isSearching.value
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const SizedBox.shrink()),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Obx(() {
      if (searchResults.isEmpty && _searchController.text.length >= 2 && !isSearching.value) {
        return const Center(
          child: Text('No users found'),
        );
      }

      if (searchResults.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Search for friends to invite',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Type at least 2 characters to start searching',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: searchResults.length,
        itemBuilder: (context, index) {
          final user = searchResults[index];
          final userId = user['id'] as String;

          return Obx(() {
            final isSelected = selectedUsers.contains(userId);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2759FF).withOpacity(0.1) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF2759FF)
                      : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ListTile(
                leading: ProfileImageWidget(
                  imageUrl: user['profilePicture']?.isNotEmpty == true
                      ? user['profilePicture']
                      : null,
                  size: 40,
                ),
                title: Text(
                  user['fullName'] ?? 'Unknown User',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: user['email']?.isNotEmpty == true
                    ? Text(
                        user['email'],
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.grey[600],
                        ),
                      )
                    : null,
                trailing: isSelected
                    ? const Icon(
                        Icons.check_circle,
                        color: Color(0xFF2759FF),
                      )
                    : const Icon(
                        Icons.radio_button_unchecked,
                        color: Colors.grey,
                      ),
                onTap: () {
                  if (isSelected) {
                    selectedUsers.remove(userId);
                  } else {
                    selectedUsers.add(userId);
                  }
                },
              ),
            );
          });
        },
      );
    });
  }

  Widget _buildMessageInput() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Message (Optional)',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _messageController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add a personal message to your invite...',
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: Colors.grey[500],
              ),
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return Obx(() {
      final hasSelection = selectedUsers.isNotEmpty;

      return Container(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: hasSelection && !isLoading.value ? _sendInvites : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2759FF),
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isLoading.value
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    hasSelection
                        ? 'Send ${selectedUsers.length} Invite${selectedUsers.length > 1 ? 's' : ''}'
                        : 'Select friends to invite',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      );
    });
  }
}