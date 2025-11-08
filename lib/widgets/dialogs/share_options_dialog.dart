import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/text_styles.dart';
import '../../core/models/race_data_model.dart';
import '../../services/race_share_service.dart';
import '../../config/app_colors.dart';
import 'friend_selector_dialog.dart';

/// Bottom sheet dialog showing share options
class ShareOptionsDialog extends StatelessWidget {
  final RaceData race;

  const ShareOptionsDialog({
    super.key,
    required this.race,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.appColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.share,
                    color: AppColors.appColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Share Race',
                    style: AppTextStyles.heroHeading.copyWith(
                      fontSize: 18,
                      color: Colors.grey[900],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Share options
          _buildShareOption(
            context: context,
            icon: Icons.people,
            title: 'Share with Friends',
            subtitle: 'Send invite to your StepzSync friends',
            color: AppColors.appColor,
            onTap: () {
              Get.back(); // Close options dialog
              showDialog(
                context: context,
                builder: (context) => FriendSelectorDialog(race: race),
              );
            },
          ),

          _buildShareOption(
            context: context,
            icon: Icons.ios_share,
            title: 'Share to Other Apps',
            subtitle: 'WhatsApp, Messages, social media, etc.',
            color: const Color(0xFF35B555),
            onTap: () async {
              Get.back(); // Close options dialog
              await RaceShareService.shareExternally(race);
            },
          ),

          // Bottom padding
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildShareOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
