import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/text_styles.dart';
import '../../core/models/race_data_model.dart';
import '../../services/race_invite_service.dart';
import '../../services/friends_service.dart';
import '../../models/friend_models.dart';
import '../../config/app_colors.dart';
import '../common/profile_image_widget.dart';

class FriendSelectorDialog extends StatefulWidget {
  final RaceData race;

  const FriendSelectorDialog({
    super.key,
    required this.race,
  });

  @override
  State<FriendSelectorDialog> createState() => _FriendSelectorDialogState();
}

class _FriendSelectorDialogState extends State<FriendSelectorDialog> {
  final RaceInviteService _inviteService = RaceInviteService();

  final RxList<Friend> friendsList = <Friend>[].obs;
  final RxList<String> selectedUsers = <String>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSending = false.obs;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadFriends() async {
    isLoading.value = true;
    try {
      final friends = await FriendsService.getFriends();
      friendsList.assignAll(friends);
    } catch (e) {
      Get.snackbar('Error', 'Failed to load friends');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> _checkIfAlreadyParticipant(String userId) async {
    try {
      final participantDoc = await FirebaseFirestore.instance
          .collection('races')
          .doc(widget.race.id)
          .collection('participants')
          .doc(userId)
          .get();
      return participantDoc.exists;
    } catch (e) {
      debugPrint('Error checking participant status: $e');
      return false;
    }
  }

  Future<void> _shareRace() async {
    if (selectedUsers.isEmpty) {
      Get.snackbar(
        'Error',
        'Please select at least one friend to share with',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isSending.value = true;
    int successCount = 0;
    int failCount = 0;
    int skippedCount = 0;

    for (final userId in selectedUsers) {
      final friend = friendsList.firstWhere((f) => f.friendId == userId);

      // Check if friend already has a pending invite for this race
      final hasExistingInvite = await _inviteService.hasInviteForRace(
        widget.race.id!,
        userId,
      );

      if (hasExistingInvite) {
        debugPrint('⚠️ User $userId already has a pending invite for race ${widget.race.id}');
        skippedCount++;
        continue;
      }

      // Check if friend is already a participant in the race
      final isAlreadyParticipant = await _checkIfAlreadyParticipant(userId);
      if (isAlreadyParticipant) {
        debugPrint('⚠️ User $userId is already a participant in race ${widget.race.id}');
        skippedCount++;
        continue;
      }

      final success = await _inviteService.sendPrivateRaceInvite(
        race: widget.race,
        toUserId: userId,
        toUserName: friend.friendName ?? '',
        message: 'Check out this race and join me!',
      );

      if (success) {
        successCount++;
      } else {
        failCount++;
      }
    }

    isSending.value = false;

    if (successCount > 0) {
      Get.back(); // Close the dialog
      final message = 'Shared race with $successCount friend${successCount > 1 ? 's' : ''}' +
          (failCount > 0 ? '. $failCount failed' : '') +
          (skippedCount > 0 ? '. $skippedCount already invited/joined' : '') +
          '.';
      Get.snackbar(
        'Success!',
        message,
        backgroundColor: const Color(0xFF35B555),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } else if (skippedCount > 0 && failCount == 0) {
      Get.back(); // Close the dialog
      Get.snackbar(
        'Already Shared',
        'Selected friend${skippedCount > 1 ? 's have' : ' has'} already been invited or joined this race.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      Get.snackbar(
        'Error',
        'Failed to share race. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.white,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
          maxWidth: 350,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(),

            // Race info card
            _buildRaceInfoCard(),

            // Friends list
            Flexible(
              child: _buildFriendsList(),
            ),

            // Share button
            _buildShareButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.appColor.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.appColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.share,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Share Race',
              style: AppTextStyles.heroHeading.copyWith(
                fontSize: 18,
                color: AppColors.appColor,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 22),
            onPressed: () => Get.back(),
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  Widget _buildRaceInfoCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.appColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.appColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.race.title ?? 'Unknown Race',
            style: AppTextStyles.cardHeading.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.appColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildRaceDetailChip(
                Icons.straighten,
                '${(widget.race.totalDistance ?? 0.0).toStringAsFixed(1)} km',
                const Color(0xFF35B555),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRaceDetailChip(
                  Icons.location_on,
                  widget.race.startAddress ?? 'Unknown Location',
                  AppColors.appColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRaceDetailChip(IconData icon, String text, Color color) {
    return Container(
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
    );
  }

  Widget _buildFriendsList() {
    return Obx(() {
      if (isLoading.value) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.appColor),
            ),
          ),
        );
      }

      if (friendsList.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 56,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No friends yet',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add friends to share races with them',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.grey[500],
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shrinkWrap: true,
        itemCount: friendsList.length,
        itemBuilder: (context, index) {
          final friend = friendsList[index];
          final friendId = friend.friendId ?? '';

          return Obx(() {
            final isSelected = selectedUsers.contains(friendId);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.appColor.withValues(alpha: 0.08)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.appColor
                      : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                leading: ProfileImageWidget(
                  imageUrl: friend.friendProfilePicture?.isNotEmpty == true
                      ? friend.friendProfilePicture
                      : null,
                  size: 40,
                ),
                title: Text(
                  friend.friendName ?? 'Unknown Friend',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: friend.friendUsername?.isNotEmpty == true
                    ? Text(
                        '@${friend.friendUsername}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      )
                    : null,
                trailing: isSelected
                    ? Icon(
                        Icons.check_circle,
                        color: AppColors.appColor,
                        size: 24,
                      )
                    : Icon(
                        Icons.radio_button_unchecked,
                        color: Colors.grey[400],
                        size: 24,
                      ),
                onTap: () {
                  if (isSelected) {
                    selectedUsers.remove(friendId);
                  } else {
                    selectedUsers.add(friendId);
                  }
                },
              ),
            );
          });
        },
      );
    });
  }

  Widget _buildShareButton() {
    return Obx(() {
      final hasSelection = selectedUsers.isNotEmpty;

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: hasSelection && !isSending.value ? _shareRace : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.appColor,
              disabledBackgroundColor: Colors.grey[350],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: isSending.value
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        hasSelection
                            ? 'Share with ${selectedUsers.length} friend${selectedUsers.length > 1 ? 's' : ''}'
                            : 'Select friends to share',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      );
    });
  }
}
