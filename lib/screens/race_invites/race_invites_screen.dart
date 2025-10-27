import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';
import '../../config/assets/icons.dart';
import '../../core/constants/text_styles.dart';
import '../../models/race_invite_model.dart';
import '../../services/race_invite_service.dart';
import '../../widgets/common/profile_image_widget.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../utils/race_button_utils.dart';
import '../../services/pending_requests_service.dart';

class RaceInvitesScreen extends StatefulWidget {
  const RaceInvitesScreen({super.key});

  @override
  State<RaceInvitesScreen> createState() => _RaceInvitesScreenState();
}

class _RaceInvitesScreenState extends State<RaceInvitesScreen>
    with SingleTickerProviderStateMixin {
  final RaceInviteService _inviteService = RaceInviteService();
  late TabController _tabController;
  final RxMap<String, bool> loadingStates = <String, bool>{}.obs;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xffE8E8F8),
      appBar: CustomAppBar(
        title: "Race Invites",
        isBack: true,
        circularBackButton: true,
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
      ),
      body: Container(
        child: Stack(
          children: [
            // Main content
            Positioned.fill(
              child: Column(
                children: [
                  // Custom Tab Bar
                  _buildCustomTabBar(),
                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildReceivedInvites(),
                        _buildSentInvites(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 50,
      child: Row(
        children: [
          // Filter-style label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff2759FF), Color(0xff2759FF).withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.mail,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  'Invites',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Tab buttons
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: Color(0xff2759FF).withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: LinearGradient(
                    colors: [
                      Color(0xff2759FF).withValues(alpha: 0.1),
                      Color(0xff2759FF).withValues(alpha: 0.05)
                    ],
                  ),
                  border: Border.all(
                    color: Color(0xff2759FF).withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                labelColor: Color(0xff2759FF),
                unselectedLabelColor: Colors.grey[600],
                labelStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(text: 'Received'),
                  Tab(text: 'Sent'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedInvites() {
    debugPrint('📱 Building received invites tab');

    return StreamBuilder<List<RaceInviteModel>>(
      stream: _inviteService.getReceivedInvites(),
      builder: (context, snapshot) {
        debugPrint('🔄 StreamBuilder state: ${snapshot.connectionState}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('⏳ Waiting for received invites data...');
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint('❌ StreamBuilder error: ${snapshot.error}');
          debugPrint('📍 Error stack trace: ${snapshot.stackTrace}');
          return _buildErrorState('Error loading invites: ${snapshot.error}');
        }

        if (snapshot.hasData) {
          final invites = snapshot.data ?? [];
          debugPrint('📦 Received invites data: ${invites.length} invites');

          for (int i = 0; i < invites.length; i++) {
            debugPrint('📝 Invite $i: ${invites[i].raceTitle} from ${invites[i].fromUserName}');
          }

          if (invites.isEmpty) {
            debugPrint('📭 No received invites to display');
            return _buildEmptyState(
              'No Invites Received',
              'You haven\'t received any race invites yet',
              Icons.mail_outline,
            );
          }

          debugPrint('🎉 Building ListView with ${invites.length} received invites');
          return RefreshIndicator(
            onRefresh: () async {
              debugPrint('🔄 Refreshing received invites...');
              setState(() {});
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: invites.length,
              itemBuilder: (context, index) {
                debugPrint('🏠 Building invite card $index');
                return _buildInviteCard(invites[index], isReceived: true);
              },
            ),
          );
        }

        debugPrint('⚠️ Unexpected StreamBuilder state');
        return _buildErrorState('Unexpected state');
      },
    );
  }

  Widget _buildSentInvites() {
    debugPrint('📤 Building sent invites tab');

    return StreamBuilder<List<RaceInviteModel>>(
      stream: _inviteService.getSentInvites(),
      builder: (context, snapshot) {
        debugPrint('🔄 Sent StreamBuilder state: ${snapshot.connectionState}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('⏳ Waiting for sent invites data...');
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint('❌ Sent StreamBuilder error: ${snapshot.error}');
          debugPrint('📍 Sent error stack trace: ${snapshot.stackTrace}');
          return _buildErrorState('Error loading sent invites: ${snapshot.error}');
        }

        if (snapshot.hasData) {
          final invites = snapshot.data ?? [];
          debugPrint('📤 Sent invites data: ${invites.length} invites');

          for (int i = 0; i < invites.length; i++) {
            debugPrint('📝 Sent invite $i: ${invites[i].raceTitle} to ${invites[i].toUserName}');
          }

          if (invites.isEmpty) {
            debugPrint('📭 No sent invites to display');
            return _buildEmptyState(
              'No Invites Sent',
              'You haven\'t sent any race invites yet',
              Icons.send,
            );
          }

          debugPrint('🎉 Building ListView with ${invites.length} sent invites');
          return RefreshIndicator(
            onRefresh: () async {
              debugPrint('🔄 Refreshing sent invites...');
              setState(() {});
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: invites.length,
              itemBuilder: (context, index) {
                debugPrint('🏠 Building sent invite card $index');
                return _buildInviteCard(invites[index], isReceived: false);
              },
            ),
          );
        }

        debugPrint('⚠️ Unexpected sent StreamBuilder state');
        return _buildErrorState('Unexpected state');
      },
    );
  }

  Widget _buildInviteCard(RaceInviteModel invite, {required bool isReceived}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: invite.statusColor.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Header with user info and status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: invite.statusColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                // Profile image
                ProfileImageWidget(
                  imageUrl: invite.fromUserImageUrl.isNotEmpty
                    ? invite.fromUserImageUrl
                    : null,
                  size: 45,
                  borderColor: invite.statusColor,
                  borderWidth: 2,
                ),
                const SizedBox(width: 12),

                // User name and time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isReceived
                          ? (invite.isJoinRequest
                              ? '${invite.fromUserName} wants to join'
                              : '${invite.fromUserName} invited you')
                          : 'Invited ${invite.toUserName}',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        invite.timeAgo,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Status badge - enhanced for sent invites
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(invite, isReceived),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusText(invite, isReceived),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Race details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Race title with join request indicator
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        invite.raceTitle,
                        style: AppTextStyles.cardHeading.copyWith(
                          color: Colors.black,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    if (invite.isJoinRequest) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2759FF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF2759FF).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.login,
                              size: 12,
                              color: const Color(0xFF2759FF),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Join Request',
                              style: TextStyle(
                                fontSize: 10,
                                color: const Color(0xFF2759FF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Race details in clean format
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem(
                        icon: Icons.location_on,
                        label: 'Location',
                        value: invite.raceLocation,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDetailItem(
                        icon: Icons.straighten,
                        label: 'Distance',
                        value: '${invite.raceDistance.toStringAsFixed(1)} km',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem(
                        icon: Icons.calendar_today,
                        label: 'Date',
                        value: invite.raceDate,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDetailItem(
                        icon: Icons.access_time,
                        label: 'Time',
                        value: invite.raceTime,
                      ),
                    ),
                  ],
                ),

                // Message (if exists)
                if (invite.message != null && invite.message!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.message,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            invite.message!,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action buttons for received invites
                if (isReceived && invite.status == InviteStatus.pending) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Obx(() => ElevatedButton.icon(
                            onPressed: loadingStates[invite.id!] == true
                              ? null
                              : () => _acceptInvite(invite.id!),
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: Text(invite.isJoinRequest ? 'Approve' : 'Accept'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF35B555),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          )),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Obx(() => ElevatedButton.icon(
                            onPressed: loadingStates[invite.id!] == true
                              ? null
                              : () => _declineInvite(invite.id!),
                            icon: const Icon(Icons.cancel, size: 18),
                            label: const Text('Decline'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFFE74C3C),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              side: const BorderSide(
                                color: Color(0xFFE74C3C),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          )),
                        ),
                      ],
                    ),
                  ),
                ],


              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 14,
          color: Color(0xff2759FF).withValues(alpha: 0.7),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF2759FF).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 50,
                color: const Color(0xFF2759FF),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTextStyles.heroHeading.copyWith(
                fontSize: 20,
                color: const Color(0xFF2759FF),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Oops!',
              style: AppTextStyles.heroHeading.copyWith(
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptInvite(String inviteId) async {
    loadingStates[inviteId] = true;
    try {
      final success = await _inviteService.acceptInvite(inviteId);
      if (success) {
        Get.snackbar(
          'Success!',
          'Race invite accepted successfully',
          backgroundColor: const Color(0xFF35B555),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
      } else {
        Get.snackbar(
          'Error',
          'Failed to accept invite. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'An unexpected error occurred',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      loadingStates[inviteId] = false;
    }
  }

  Future<void> _declineInvite(String inviteId) async {
    loadingStates[inviteId] = true;
    try {
      final success = await _inviteService.declineInvite(inviteId);
      if (success) {
        Get.snackbar(
          'Declined',
          'Race invite declined',
          backgroundColor: const Color(0xFFE74C3C),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
      } else {
        Get.snackbar(
          'Error',
          'Failed to decline invite. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'An unexpected error occurred',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      loadingStates[inviteId] = false;
    }
  }

  /// Navigate to race details screen where consistent UI logic is applied
  void _viewRaceDetails(String? raceId) {
    if (raceId == null || raceId.isEmpty) {
      Get.snackbar(
        'Error',
        'Race details not available',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    // Navigate to race details screen where the consistent race button logic applies
    Get.toNamed('/race-details/$raceId');
  }

  /// Get consistent status text for invite cards
  String _getStatusText(RaceInviteModel invite, bool isReceived) {
    if (!isReceived && invite.isJoinRequest) {
      // For sent join requests, use consistent terminology
      try {
        final pendingService = Get.find<PendingRequestsService>();
        final hasPending = pendingService.hasPendingRequest(invite.raceId);

        if (invite.status == InviteStatus.pending && hasPending) {
          return 'Requested';
        }
      } catch (e) {
        // Service not available, continue with default
      }
    }

    // Default to original status text
    return invite.statusText;
  }

  /// Get consistent status color for invite cards
  Color _getStatusColor(RaceInviteModel invite, bool isReceived) {
    if (!isReceived && invite.isJoinRequest) {
      // For sent join requests, use consistent colors
      try {
        final pendingService = Get.find<PendingRequestsService>();
        final hasPending = pendingService.hasPendingRequest(invite.raceId);

        if (invite.status == InviteStatus.pending && hasPending) {
          return Colors.orange; // Consistent with the "Requested" state
        }
      } catch (e) {
        // Service not available, continue with default
      }
    }

    // Default to original status color
    return invite.statusColor;
  }
}