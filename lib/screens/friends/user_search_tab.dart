import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../controllers/friends_controller.dart';
import '../../models/friend_models.dart';
import '../../widgets/auth/auth_button.dart';
import '../profile/user_profile_screen.dart';

class UserSearchTab extends StatelessWidget {
  const UserSearchTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<FriendsController>();

    return Obx(() {
      if (controller.isLoadingSearch.value) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Searching...'),
            ],
          ),
        );
      }

      if (controller.searchResults.isEmpty && controller.searchQuery.value.isNotEmpty) {
        return _buildNoResultsState(controller.searchQuery.value);
      }

      if (controller.searchResults.isEmpty) {
        return _buildSearchPrompt();
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: controller.searchResults.length,
        itemBuilder: (context, index) {
          final user = controller.searchResults[index];
          return _buildUserCard(user, controller);
        },
      );
    });
  }

  Widget _buildSearchPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Search for Friends',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a name or username to find people',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(String query) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Results Found',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No users found for "$query".\nTry a different search term.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserSearchResult user, FriendsController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey[50]!,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.appColor.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                // Enhanced Profile Picture
                Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _navigateToProfile(user.id),
                      child: Container(
                        height: 64,
                        width: 64,
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
                              color: AppColors.appColor.withOpacity(0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                          image: user.profilePicture != null
                              ? DecorationImage(
                                  image: NetworkImage(user.profilePicture!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: user.profilePicture == null
                            ? Icon(
                                Icons.person_rounded,
                                color: AppColors.appColor,
                                size: 32,
                              )
                            : null,
                      ),
                    ),
                    // Friendship Status Ring
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _getStatusColor(user.friendshipStatus),
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 16),

                // Enhanced User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.fullName,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Friendship Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(user.friendshipStatus).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getStatusColor(user.friendshipStatus).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _getStatusText(user.friendshipStatus),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _getStatusColor(user.friendshipStatus),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (user.username != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.alternate_email,
                              size: 14,
                              color: AppColors.appColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              user.username!,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: AppColors.appColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              user.location.isNotEmpty ? user.location : 'Location not available',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Enhanced Profile Button
                GestureDetector(
                  onTap: () => _navigateToProfile(user.id),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.appColor.withOpacity(0.1),
                          AppColors.appColor.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.appColor.withOpacity(0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.appColor.withOpacity(0.1),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person_search_rounded,
                      color: AppColors.appColor,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Action Button
            _buildActionButton(user, controller),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(FriendshipStatus status) {
    switch (status) {
      case FriendshipStatus.none:
        return Colors.grey;
      case FriendshipStatus.requestSent:
        return Colors.orange;
      case FriendshipStatus.requestReceived:
        return Colors.blue;
      case FriendshipStatus.friends:
        return Colors.green;
      case FriendshipStatus.blocked:
        return Colors.red;
    }
  }

  String _getStatusText(FriendshipStatus status) {
    switch (status) {
      case FriendshipStatus.none:
        return 'NEW';
      case FriendshipStatus.requestSent:
        return 'SENT';
      case FriendshipStatus.requestReceived:
        return 'PENDING';
      case FriendshipStatus.friends:
        return 'FRIENDS';
      case FriendshipStatus.blocked:
        return 'BLOCKED';
    }
  }

  void _navigateToProfile(String userId) {
    Get.to(() => UserProfileScreen(), arguments: userId);
  }

  Widget _buildActionButton(UserSearchResult user, FriendsController controller) {
    return Obx(() {
      final isLoading = controller.isRequestActionLoading(user.id);

      switch (user.friendshipStatus) {
        case FriendshipStatus.none:
          return SizedBox(
            width: double.infinity,
            child: AuthButton(
              text: 'Add Friend',
              onPressed: isLoading ? (){} : () => controller.sendFriendRequest(user),
              isLoading: isLoading,
              backgroundColor: AppColors.appColor,
              textColor: Colors.white,
              icon: Icons.person_add,
            ),
          );

        case FriendshipStatus.requestSent:
          return SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isLoading ? null : () => controller.cancelFriendRequest(user),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.orange[400]!),
                backgroundColor: Colors.orange[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(0, 44),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                  ] else ...[
                    Icon(Icons.schedule, size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    isLoading ? 'Cancelling...' : 'Request Sent',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
            ),
          );

        case FriendshipStatus.requestReceived:
          return Row(
            children: [
              Expanded(
                child: AuthButton(
                  text: 'Accept',
                  onPressed: isLoading ? (){} : () {
                    // Find the request and accept it
                    final request = controller.receivedRequests.firstWhereOrNull(
                      (req) => req.senderId == user.id,
                    );
                    if (request != null) {
                      controller.acceptFriendRequest(request);
                    }
                  },
                  isLoading: isLoading,
                  backgroundColor: AppColors.appColor,
                  textColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: isLoading ? null : () {
                    final request = controller.receivedRequests.firstWhereOrNull(
                      (req) => req.senderId == user.id,
                    );
                    if (request != null) {
                      controller.declineFriendRequest(request);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[400]!),
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

        case FriendshipStatus.friends:
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Already Friends',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          );

        case FriendshipStatus.blocked:
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.block, color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Blocked',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
          );
      }
    });
  }
}