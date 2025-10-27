import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../routes/app_routes.dart';
import '../../../../widgets/common/profile_image_widget.dart';

class HomepageHeaderWidget extends StatelessWidget {
  final RxString userName;
  final RxString profileImageUrl;
  final RxBool hasUnreadNotifications;

  const HomepageHeaderWidget({
    super.key,
    required this.userName,
    required this.profileImageUrl,
    required this.hasUnreadNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Profile Picture - Dynamic with user image
        Obx(() => ProfileImageWidget(
          imageUrl: profileImageUrl.value.isNotEmpty ? profileImageUrl.value : null,
          size: 64,
          borderColor: const Color(0xFFCDFF49),
          borderWidth: 2,
        )),
        const SizedBox(width: 12),

        // Welcome Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() => Text(
                'Hi, ${userName.value}',
                style: AppTextStyles.heroHeading,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              )),
              Text(
                "It's Time To Challenge Your Limits",
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
        ),

        // Action Icons and Status Indicators
        Row(
          children: [
            Obx(() => _buildIconButton(
              'assets/icons/Group.svg',
              const Color(0xFFCDFF49),
              () {
                Get.toNamed(AppRoutes.notifications);
              },
              hasNotification: hasUnreadNotifications.value,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildIconButton(
      String svgPath,
      Color bgColor,
      VoidCallback onTap, {
        bool hasNotification = false,
      }) {
    return Stack(
      children: [
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: bgColor.withValues(alpha: 0.4),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onTap,
            icon: SvgPicture.asset(
              svgPath,
              width: 22,
              height: 22,
              colorFilter: const ColorFilter.mode(
                Colors.black87,
                BlendMode.srcIn,
              ),
            ),
            padding: EdgeInsets.zero,
          ),
        ),
        if (hasNotification)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}