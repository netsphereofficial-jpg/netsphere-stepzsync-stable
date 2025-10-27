import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../config/app_colors.dart';
import '../../models/notification_model.dart';
import '../../controllers/notification_controller.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../core/utils/common_methods.dart';

class NotificationListScreen extends StatelessWidget {
  NotificationListScreen({super.key});
  final controller = Get.put(NotificationController());

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Scaffold(
        backgroundColor: Color(0xffE8E8F8),
        appBar: CustomAppBar(
          iconData:
              controller.selectionMode.value ? Icons.close : Icons.arrow_back_ios_new_rounded,
          title:
              controller.selectionMode.value
                  ? "${controller.selectedSize()} selected"
                  : "Notifications",
          isBack: true,
          circularBackButton: !controller.selectionMode.value,
          backButtonCircleColor: AppColors.neonYellow,
          backButtonIconColor: Colors.black,
          backgroundColor: Colors.white,
          titleColor: AppColors.appColor,
          showGradient: false,
          titleStyle: GoogleFonts.roboto(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.appColor,
          ),
          onBackClick: () {
            if (controller.selectionMode.value) {
              controller.selectionMode.value = false;
              controller.unselectAll();
            } else {
              Get.back();
            }
          },
          actions:
              controller.selectionMode.value
                  ? [
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: Colors.white,
                      ),
                      onSelected: (String value) {
                        switch (value) {
                          case 'clearSelected':
                            controller.deleteSelected();
                            break;
                          case 'clearAll':
                            controller.deleteAll();
                            break;
                        }
                      },
                      itemBuilder:
                          (BuildContext context) => [
                            PopupMenuItem<String>(
                              value: 'clearSelected',
                              child: Text('Clear selected'),
                            ),
                            PopupMenuItem<String>(
                              value: 'clearAll',
                              child: Text('Clear all'),
                            ),
                          ],
                    ),
                  ]
                  : [
                    InkWell(
                      onTap: () {
                        if (controller.allNotifications.isEmpty) {
                          showSnackbar('', "Notification list is empty!");
                          return;
                        }
                        controller.selectionMode.value = true;
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Center(
                          child: Text(
                            "Clear",
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Obx(
                    () => ToggleButton(
                      label: 'All',
                      selected: controller.activeTab.value == 'All',
                      onTap: () => controller.setTab('All'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Obx(
                    () => ToggleButton(
                      label: 'Unread',
                      selected: controller.activeTab.value == 'Unread',
                      onTap: () => controller.setTab('Unread'),
                    ),
                  ),
                  const Spacer(),
                  Visibility(
                    visible: !controller.selectionMode.value,
                    child: GestureDetector(
                      onTap: controller.markAllRead,
                      child: Row(
                        children: [
                          Icon(Icons.done, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'Mark all as read',
                            style: GoogleFonts.poppins(
                              color: AppColors.buttonBlack,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Obx(
                  () =>
                      controller.allNotifications.isNotEmpty
                          ? ListView(
                            children:
                                controller.groupedNotifications.entries
                                    .map(
                                      (entry) => NotificationGroup(
                                        title: entry.key,
                                        notifications: entry.value,
                                      ),
                                    )
                                    .toList(),
                          )
                          : Center(
                            child: Text(
                              "Notification list is empty!",
                              style: GoogleFonts.poppins(
                                color: AppColors.buttonBlack,
                              ),
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class ToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const ToggleButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2759FF) : Colors.white,
          border: Border.all(color: const Color(0xFF2759FF)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF2759FF),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class NotificationGroup extends StatelessWidget {
  final String title;
  final List<NotificationModel> notifications;

  const NotificationGroup({
    super.key,
    required this.title,
    required this.notifications,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...notifications.map((n) => NotificationCard(n)).toList(),
      ],
    );
  }
}

class NotificationCard extends StatelessWidget {
  final NotificationModel model;
  const NotificationCard(this.model, {super.key});

  @override
  Widget build(BuildContext context) {
    final controller =
        Get.isRegistered<NotificationController>()
            ? Get.find<NotificationController>()
            : Get.put(NotificationController());
    return GestureDetector(
      onLongPress: () {
        controller.selectionMode.value = true;
        model.isSelected = true;
        controller.allNotifications.refresh();
      },
      onTap: () {
        if (controller.selectionMode.value) {
          model.isSelected = !model.isSelected;
          controller.allNotifications.refresh();
        } else {
          // Mark as read when tapped
          if (!model.isRead && model.firebaseId != null) {
            controller.singleReadNotificationByFirebaseId(model.firebaseId!);
          }
          // Handle navigation based on notification type
          controller.onNotificationClick(model);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: model.isRead ? Colors.white : const Color(0xFFEAF2FD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                model.isSelected ? const Color(0xFF2759FF) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon or Thumbnail
            _buildNotificationIcon(model),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          model.title,
                          style: TextStyle(
                            fontWeight: model.isRead ? FontWeight.w400 : FontWeight.w600,
                            color: model.isRead ? Colors.black87 : Colors.black,
                          ),
                        ),
                      ),
                      if (!model.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  Text(
                    model.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: model.isRead ? Colors.black54 : Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Additional metadata row for race/friend notifications
                  if (model.metadata != null) ...[
                    _buildMetadataRow(model),
                    const SizedBox(height: 4),
                  ],

                  Text(
                    model.time,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Obx(
              () =>
                  controller.selectionMode.value
                      ? Checkbox(
                        value: model.isSelected,
                        onChanged: (val) {
                          model.isSelected = val ?? false;
                          controller.allNotifications.refresh();
                        },
                      )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(NotificationModel model) {
    if (model.thumbnail != null && model.thumbnail!.isNotEmpty) {
      if (model.thumbnail!.startsWith('assets/')) {
        // SVG asset
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getIconBackgroundColor(model.notificationType),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SvgPicture.asset(
              model.thumbnail!,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                _getIconColor(model.notificationType),
                BlendMode.srcIn,
              ),
            ),
          ),
        );
      } else {
        // Network image or other types
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: NetworkImage(model.thumbnail!),
              fit: BoxFit.cover,
            ),
          ),
        );
      }
    } else {
      // Fallback to emoji icon
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _getIconBackgroundColor(model.notificationType),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            model.icon,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      );
    }
  }

  Widget _buildMetadataRow(NotificationModel model) {
    final metadata = model.metadata!;
    List<Widget> chips = [];

    switch (model.notificationType) {
      case 'InviteRace':
        if (metadata['distance'] != null) {
          chips.add(_buildMetadataChip('${metadata['distance']}km', Icons.straighten));
        }
        if (metadata['participants'] != null) {
          chips.add(_buildMetadataChip('${metadata['participants']} participants', Icons.group));
        }
        break;
      case 'RaceWon':
        if (metadata['rank'] != null) {
          chips.add(_buildMetadataChip('Rank #${metadata['rank']}', Icons.emoji_events));
        }
        if (metadata['xpEarned'] != null) {
          chips.add(_buildMetadataChip('+${metadata['xpEarned']} XP', Icons.star));
        }
        break;
      case 'OvertakingParticipant':
        if (metadata['yourRank'] != null) {
          chips.add(_buildMetadataChip('Now #${metadata['yourRank']}', Icons.trending_up));
        }
        break;
      case 'FriendRequest':
        if (metadata['mutualFriends'] != null) {
          chips.add(_buildMetadataChip('${metadata['mutualFriends']} mutual friends', Icons.people));
        }
        break;
      case 'HallOfFame':
        if (metadata['xpEarned'] != null) {
          chips.add(_buildMetadataChip('+${metadata['xpEarned']} XP', Icons.star));
        }
        break;
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      children: chips.take(2).toList(), // Limit to 2 chips to avoid overflow
    );
  }

  Widget _buildMetadataChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getIconBackgroundColor(String notificationType) {
    switch (notificationType) {
      case 'InviteRace':
      case 'RaceBegin':
      case 'RaceParticipant':
        return Colors.blue.withOpacity(0.1);
      case 'RaceWon':
      case 'RaceWinnerCrossing':
        return Colors.amber.withOpacity(0.1);
      case 'OvertakingParticipant':
        return Colors.orange.withOpacity(0.1);
      case 'FriendRequest':
        return Colors.purple.withOpacity(0.1);
      case 'Marathon':
      case 'ActiveMarathon':
        return Colors.red.withOpacity(0.1);
      case 'HallOfFame':
        return Colors.green.withOpacity(0.1);
      case 'EndTimer':
        return Colors.orange.withOpacity(0.1);
      case 'RaceOver':
        return Colors.grey.withOpacity(0.1);
      default:
        return AppColors.appColor.withOpacity(0.1);
    }
  }

  Color _getIconColor(String notificationType) {
    switch (notificationType) {
      case 'InviteRace':
      case 'RaceBegin':
      case 'RaceParticipant':
        return Colors.blue;
      case 'RaceWon':
      case 'RaceWinnerCrossing':
        return Colors.amber.shade700;
      case 'OvertakingParticipant':
        return Colors.orange;
      case 'FriendRequest':
        return Colors.purple;
      case 'Marathon':
      case 'ActiveMarathon':
        return Colors.red;
      case 'HallOfFame':
        return Colors.green;
      case 'EndTimer':
        return Colors.orange;
      case 'RaceOver':
        return Colors.grey.shade600;
      default:
        return AppColors.appColor;
    }
  }
}