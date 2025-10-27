import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../controllers/friends_controller.dart';
import '../../models/friend_models.dart';
import '../../widgets/auth/auth_button.dart';
import '../profile/user_profile_screen.dart';

class FriendRequestsTab extends StatelessWidget {
  final bool isReceived;

  const FriendRequestsTab({super.key, required this.isReceived});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<FriendsController>();

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: Obx(() {
        if (controller.isLoadingRequests.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = isReceived
            ? controller.receivedRequests
            : controller.sentRequests;

        if (requests.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _buildRequestCard(request, controller);
          },
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.appColor.withOpacity(0.1),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.appColor.withOpacity(0.2),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              isReceived ? Icons.person_add_outlined : Icons.schedule_outlined,
              size: 48,
              color: AppColors.appColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isReceived ? 'No Friend Requests' : 'No Sent Requests',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              isReceived
                  ? 'You don\'t have any pending friend requests.\nWhen someone sends you a request, it will appear here.'
                  : 'You haven\'t sent any friend requests yet.\nSearch for people and send them friend requests.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(FriendRequest request, FriendsController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Profile Picture
                GestureDetector(
                  onTap: () => _navigateToProfile(request.senderId),
                  child: Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.appColor.withOpacity(0.2),
                          AppColors.appColor.withOpacity(0.05),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.appColor.withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                      image: request.senderProfilePicture != null
                          ? DecorationImage(
                              image: NetworkImage(request.senderProfilePicture!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: request.senderProfilePicture == null
                        ? Icon(
                            Icons.person_rounded,
                            color: AppColors.appColor,
                            size: 28,
                          )
                        : null,
                  ),
                ),

                const SizedBox(width: 12),

                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              request.senderName,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Request Type Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isReceived
                                  ? AppColors.appColor.withOpacity(0.1)
                                  : Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isReceived
                                    ? AppColors.appColor.withOpacity(0.3)
                                    : Colors.orange[200]!,
                              ),
                            ),
                            child: Text(
                              isReceived ? 'RECEIVED' : 'SENT',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isReceived
                                    ? AppColors.appColor
                                    : Colors.orange[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (request.senderUsername != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '@${request.senderUsername!}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.appColor.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        _formatDate(request.createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Profile Button
                GestureDetector(
                  onTap: () => _navigateToProfile(request.senderId),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.appColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.appColor.withOpacity(0.2),
                      ),
                    ),
                    child: Icon(
                      Icons.person_search_rounded,
                      color: AppColors.appColor,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),

            if (isReceived) ...[
              const SizedBox(height: 16),
              // Action Buttons for received requests
              Obx(() {
                final isLoading = controller.isRequestActionLoading(request.id!);

                return Row(
                  children: [
                    Expanded(
                      child: AuthButton(
                        text: 'Accept',
                        onPressed: isLoading
                            ? () {}
                            : () => controller.acceptFriendRequest(request),
                        isLoading: isLoading,
                        backgroundColor: AppColors.appColor,
                        textColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isLoading
                            ? null
                            : () => controller.declineFriendRequest(request),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey[400]!),
                          backgroundColor: Colors.grey[50],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(0, 44),
                        ),
                        child: Text(
                          'Decline',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ] else ...[
              const SizedBox(height: 12),
              // Status for sent requests
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      color: Colors.orange[600],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Waiting for response...',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.orange[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _navigateToProfile(String userId) {
    Get.to(() => UserProfileScreen(), arguments: userId);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inHours < 1) {
      return 'Just now';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}