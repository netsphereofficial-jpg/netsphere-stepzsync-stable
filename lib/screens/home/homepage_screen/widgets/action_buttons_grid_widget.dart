import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../utils/guest_utils.dart';
import '../../../../widgets/guest_upgrade_dialog.dart';

class ActionButtonsGridWidget extends StatelessWidget {
  final RxInt totalRaceCount;
  final RxInt activeJoinedRaceCount;
  final RxInt quickRaceCount;
  final RxInt pendingInvitesCount;
  final VoidCallback? onBeforeNavigate;

  const ActionButtonsGridWidget({
    super.key,
    required this.totalRaceCount,
    required this.activeJoinedRaceCount,
    required this.quickRaceCount,
    required this.pendingInvitesCount,
    this.onBeforeNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> actions = [
      {
        'title': 'Quick race',
        'icon': Icons.flash_on,
        'bgColor': const Color(0xFFEAEFFC),
        'iconColor': const Color(0xFF3665F9),
        'onTap': () => Get.toNamed('/quick-race'),
        'showCount': true,
        'countType': 'quick',
        'guestAccess': true, // ✅ Allow for guests
        'featureName': 'quick_race',
      },
      {
        'title': 'Active Races',
        'icon': Icons.directions_run,
        'bgColor': const Color(0xFFE8FEEA),
        'iconColor': const Color(0xFF35B555),
        'onTap': () => Get.toNamed('/active-races'),
        'showCount': true,
        'countType': 'joined',
        'guestAccess': true, // ✅ Allow for guests
        'featureName': 'active_races_view',
      },
      {
        'title': 'Race',
        'icon': Icons.flag,
        'bgColor': const Color(0xFFEAEFFC),
        'iconColor': const Color(0xFF3665F9),
        'onTap': () => Get.toNamed('/race'),
        'showCount': true,
        'countType': 'total',
        'guestAccess': false, // 🔒 Restrict for guests - only Quick Race and Active Races are allowed
        'featureName': 'Race',
      },
      {
        'title': 'Marathon',
        'icon': Icons.emoji_events,
        'bgColor': const Color(0xFFE8FEEA),
        'iconColor': const Color(0xFF35B555),
        'onTap': () => Get.toNamed('/marathon-races'),
        'showCount': false,
        'guestAccess': false, // 🔒 Restrict for guests
        'featureName': 'marathon',
      },
      {
        'title': 'Race invites',
        'icon': Icons.mail,
        'bgColor': const Color(0xFFEAEFFC),
        'iconColor': const Color(0xFF3665F9),
        'onTap': () => Get.toNamed('/race-invites'),
        'showCount': true,
        'countType': 'invites',
        'guestAccess': false, // 🔒 Restrict for guests
        'featureName': 'race_invites',
      },
      {
        'title': 'Hall of fame',
        'icon': Icons.star,
        'bgColor': const Color(0xFFE8FEEA),
        'iconColor': const Color(0xFF35B555),
        'onTap': () => Get.toNamed('/hall-of-fame'),
        'showCount': false,
        'guestAccess': true, // ✅ Free for all users
        'featureName': 'hall_of_fame',
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the aspect ratio based on available space
        final aspectRatio = constraints.maxWidth > constraints.maxHeight ? 1.3 : 1.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 1.1,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
        final action = actions[index];
        return _buildActionButton(
          action['title'],
          action['icon'],
          action['bgColor'],
          action['iconColor'],
          action['onTap'],
          showCount: action['showCount'] ?? false,
          countType: action['countType'] ?? '',
          guestAccess: action['guestAccess'] ?? false,
          featureName: action['featureName'] ?? '',
        );
          },
        );
      },
    );
  }

  Widget _buildActionButton(
      String title,
      IconData icon,
      Color bgColor,
      Color iconColor,
      VoidCallback onTap, {
        bool showCount = false,
        String countType = '',
        bool guestAccess = false,
        String featureName = '',
      }) {
    // Check if this button should be locked for guests
    final isLocked = GuestUtils.isGuest() && !guestAccess;

    return InkWell(
      onTap: () {
        // If locked for guests, show upgrade dialog instead
        if (isLocked) {
          GuestUpgradeDialog.show(featureName: title);
        } else {
          // Call onBeforeNavigate callback before navigating (e.g., to close dropdowns)
          onBeforeNavigate?.call();
          onTap();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: iconColor, size: 40),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: AppTextStyles.buttonText.copyWith(fontSize: 14),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Lock icon for restricted features
          if (isLocked)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          // Count badge
          if (showCount && !isLocked)
            Positioned(
              top: 4,
              right: 4,
              child: Obx(() {
                final count = countType == 'joined' ? activeJoinedRaceCount.value :
                countType == 'quick' ? quickRaceCount.value :
                countType == 'invites' ? pendingInvitesCount.value :
                totalRaceCount.value;
                return count > 0
                    ? Container(
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ).animate(onPlay: (controller) => controller.repeat())
                    .scale(
                  begin: const Offset(1.0, 1.0),
                  end: const Offset(1.1, 1.1),
                  duration: 1000.ms,
                  curve: Curves.easeInOut,
                )
                    .then()
                    .scale(
                  begin: const Offset(1.1, 1.1),
                  end: const Offset(1.0, 1.0),
                  duration: 1000.ms,
                  curve: Curves.easeInOut,
                )
                    : const SizedBox.shrink();
              }),
            ),
        ],
      ),
    );
  }
}

class ActionButtonsGridSkeletonWidget extends StatelessWidget {
  const ActionButtonsGridSkeletonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.15,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildShimmerContainer(width: 42, height: 42),
              const SizedBox(height: 8),
              _buildShimmerContainer(width: 60, height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmerContainer({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          colors: [
            Colors.grey.withValues(alpha: 0.2),
            Colors.grey.withValues(alpha: 0.4),
            Colors.grey.withValues(alpha: 0.2),
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment(-1.0, 0.0),
          end: Alignment(1.0, 0.0),
        ),
      ),
    ).animate(onPlay: (controller) => controller.repeat())
        .shimmer(
      duration: 1500.ms,
      colors: [
        Colors.grey.withValues(alpha: 0.2),
        Colors.white.withValues(alpha: 0.4),
        Colors.grey.withValues(alpha: 0.2),
      ],
    );
  }
}