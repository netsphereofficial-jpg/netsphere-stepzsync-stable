import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/text_styles.dart';
import '../../models/race_invite_model.dart';
import '../../services/race_invite_service.dart';
import '../../widgets/common/profile_image_widget.dart';
import '../../routes/app_routes.dart';

class RaceInvitesWidget extends StatelessWidget {
  const RaceInvitesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🏠 Building RaceInvitesWidget for home screen');
    final RaceInviteService inviteService = RaceInviteService();

    return StreamBuilder<List<RaceInviteModel>>(
      stream: inviteService.getReceivedInvites(),
      builder: (context, snapshot) {
        debugPrint('🏠 Home widget StreamBuilder state: ${snapshot.connectionState}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('⏳ Home widget: Loading invites...');
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          debugPrint('❌ Home widget error: ${snapshot.error}');
          debugPrint('📍 Home widget stack trace: ${snapshot.stackTrace}');
          return const SizedBox.shrink();
        }

        if (snapshot.hasData) {
          final allInvites = snapshot.data ?? [];
          debugPrint('🏠 Home widget received ${allInvites.length} total invites');

          final pendingInvites = allInvites
              .where((invite) => invite.status == InviteStatus.pending)
              .take(2) // Show max 2 invites in home
              .toList();

          debugPrint('🏠 Home widget filtered to ${pendingInvites.length} pending invites');

          for (int i = 0; i < pendingInvites.length; i++) {
            debugPrint('🏠 Home pending invite $i: ${pendingInvites[i].raceTitle} from ${pendingInvites[i].fromUserName}');
          }

          if (pendingInvites.isEmpty) {
            debugPrint('🏠 Home widget: No pending invites to show');
            return const SizedBox.shrink();
          }

          debugPrint('🎉 Home widget: Building invite cards container');
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Race Invites',
                      style: AppTextStyles.heroHeading.copyWith(fontSize: 20),
                    ),
                    GestureDetector(
                      onTap: () {
                        debugPrint('👆 Home widget: "View All" tapped');
                        Get.toNamed(AppRoutes.raceInvites);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2759FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View All',
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFF2759FF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: const Color(0xFF2759FF),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Invites list
                ...pendingInvites.asMap().entries.map((entry) {
                  final index = entry.key;
                  final invite = entry.value;
                  debugPrint('🏠 Home widget: Building card for invite ${invite.id}');
                  return _buildInviteCard(invite, inviteService)
                      .animate(delay: Duration(milliseconds: index * 100))
                      .slideX(begin: 0.2, end: 0)
                      .fadeIn();
                }),
              ],
            ),
          );
        }

        debugPrint('⚠️ Home widget: Unexpected state');
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildInviteCard(RaceInviteModel invite, RaceInviteService inviteService) {
    final RxBool isProcessing = false.obs;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF2759FF).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              ProfileImageWidget(
                imageUrl: invite.fromUserImageUrl.isNotEmpty
                    ? invite.fromUserImageUrl
                    : null,
                size: 35,
                borderColor: const Color(0xFF2759FF),
                borderWidth: 2,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${invite.fromUserName} invited you',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      invite.timeAgo,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2759FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'NEW',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Race info
          Text(
            invite.raceTitle,
            style: AppTextStyles.cardHeading.copyWith(
              color: Colors.black87,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Race details chips
          Row(
            children: [
              _buildMiniChip(Icons.straighten, '${invite.raceDistance.toStringAsFixed(1)}km'),
              const SizedBox(width: 8),
              _buildMiniChip(Icons.calendar_today, invite.raceDate),
            ],
          ),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: Obx(() => ElevatedButton(
                  onPressed: isProcessing.value
                      ? null
                      : () => _acceptInvite(invite.id!, inviteService, isProcessing),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF35B555),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Accept',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Obx(() => OutlinedButton(
                  onPressed: isProcessing.value
                      ? null
                      : () => _declineInvite(invite.id!, inviteService, isProcessing),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE74C3C),
                    side: const BorderSide(
                      color: Color(0xFFE74C3C),
                      width: 1,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Decline',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2759FF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: const Color(0xFF2759FF),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: const Color(0xFF2759FF),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(onPlay: (controller) => controller.repeat())
      .shimmer(duration: 1500.ms);
  }

  Future<void> _acceptInvite(
    String inviteId,
    RaceInviteService inviteService,
    RxBool isProcessing,
  ) async {
    isProcessing.value = true;
    try {
      final success = await inviteService.acceptInvite(inviteId);
      if (success) {
        Get.snackbar(
          'Success!',
          'Race invite accepted successfully',
          backgroundColor: const Color(0xFF35B555),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2),
        );
      } else {
        _showErrorSnackbar('Failed to accept invite');
      }
    } catch (e) {
      _showErrorSnackbar('An error occurred');
    } finally {
      isProcessing.value = false;
    }
  }

  Future<void> _declineInvite(
    String inviteId,
    RaceInviteService inviteService,
    RxBool isProcessing,
  ) async {
    isProcessing.value = true;
    try {
      final success = await inviteService.declineInvite(inviteId);
      if (success) {
        Get.snackbar(
          'Declined',
          'Race invite declined',
          backgroundColor: const Color(0xFFE74C3C),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2),
        );
      } else {
        _showErrorSnackbar('Failed to decline invite');
      }
    } catch (e) {
      _showErrorSnackbar('An error occurred');
    } finally {
      isProcessing.value = false;
    }
  }

  void _showErrorSnackbar(String message) {
    Get.snackbar(
      'Error',
      message,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 2),
    );
  }
}