import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:stepzsync/controllers/race/races_list_controller.dart';
import 'package:stepzsync/screens/race_map/race_map_screen.dart';

import '../../config/app_colors.dart';
import '../../config/assets/icons.dart';
import '../../core/models/race_data_model.dart';
import '../vertical_dash_divider.dart';
import '../../utils/guest_utils.dart';
import '../../widgets/guest_upgrade_dialog.dart';
import '../../services/race_share_service.dart';

class RaceCardWidget extends StatefulWidget {
  final RaceData race;

  const RaceCardWidget({super.key, required this.race});

  @override
  State<RaceCardWidget> createState() => _RaceCardWidgetState();
}

class _RaceCardWidgetState extends State<RaceCardWidget>
    with SingleTickerProviderStateMixin {
  final RacesListController controller = Get.find<RacesListController>();
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));

    _elevationAnimation = Tween<double>(
      begin: 4.0,
      end: 8.0,
    ).animate(CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isJoined = controller.isUserInRace(widget.race);
    final isActiveRace = widget.race.statusId == 3; // statusId 3 is "Active"

    // Check if current user has completed their race (important for status 6)
    final currentUserId = controller.auth.currentUser?.uid;
    final currentParticipant = widget.race.participants?.firstWhere(
      (p) => p.userId == currentUserId,
      orElse: () => Participant(
        userId: '', userName: '', distance: 0, remainingDistance: 0,
        rank: 0, steps: 0, calories: 0, avgSpeed: 0.0
      ),
    );
    final userHasCompleted = currentParticipant?.isCompleted ?? false;

    // Determine if we should show completed info:
    // - Race status is 4 (completed) OR
    // - Race status is 6 (deadline) AND user has finished
    final showCompletedInfo = isJoined && (widget.race.statusId == 4 ||
                                           (widget.race.statusId == 6 && userHasCompleted));

    return AnimatedBuilder(
      animation: _hoverController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTap: () => _onCardTap(),
            onTapDown: (_) => _hoverController.forward(),
            onTapUp: (_) => _hoverController.reverse(),
            onTapCancel: () => _hoverController.reverse(),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: _elevationAnimation.value,
                    offset: Offset(0, _elevationAnimation.value * 0.5),
                    spreadRadius: 0,
                  ),
                ],
                border: Border.all(
                  color: AppColors.appColor.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with title and race type badge
                  _buildHeader(),

                  // Route section
                  _buildRouteSection(),

                  // Info section - show different info based on user completion status
                  if (showCompletedInfo)
                    _buildCompletedRaceInfoSection() // User completed - show completion metrics
                  else if (isJoined && (isActiveRace || widget.race.statusId == 6))
                    _buildMetricsInfoSection() // Active race or deadline (user still racing) - show live metrics
                  else
                    _buildInfoSection(), // Not joined - show basic info

                  // Action button
                  _buildActionButton(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Race icon
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.appColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SvgPicture.asset(
              IconPaths.twoFlagsIcon,
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                AppColors.appColor,
                BlendMode.srcIn,
              ),
            ),
          ),
          SizedBox(width: 12),

          // Title and creator
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.race.title ?? 'Untitled Race',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  'by ${widget.race.organizerName ?? 'Unknown Organizer'}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // Share button
          if (RaceShareService.canShareRace(widget.race))
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  RaceShareService.showShareDialog(context, widget.race);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.share,
                    size: 18,
                    color: AppColors.appColor,
                  ),
                ),
              ),
            ),

          // Race type and distance badges
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getRaceTypeColor(),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  controller.getRaceTypeText(widget.race),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  controller.getFormattedDistance(widget.race),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Start location
          Row(
            children: [
              SvgPicture.asset(
                IconPaths.radioIcon,
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(
                  AppColors.appColor,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.race.startAddress ?? 'Start location not set',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Dashed line
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
            child: SizedBox(
              height: 16,
              child: VerticalDashedDivider(
                dashHeight: 2,
                dashSpacing: 2,
                width: 2,
                color: AppColors.appColor.withValues(alpha: 0.4),
              ),
            ),
          ),

          // End location
          Row(
            children: [
              SvgPicture.asset(
                IconPaths.locationIcon,
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(
                  AppColors.appColor,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.race.endAddress ?? 'End location not set',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsInfoSection() {
    final currentUserId = controller.auth.currentUser?.uid;
    final totalDistance = widget.race.totalDistance ?? 1.0;

    // 🐛 DEBUG: Log participant data for debugging
    developer.log('🔍 [RACE_CARD] Looking for participant data:');
    developer.log('   Race: ${widget.race.title} (${widget.race.id})');
    developer.log('   Current User ID: $currentUserId');
    developer.log('   Participants array: ${widget.race.participants != null ? "exists (${widget.race.participants!.length} items)" : "NULL"}');

    if (widget.race.participants != null && widget.race.participants!.isNotEmpty) {
      developer.log('   Participant User IDs in array:');
      for (var p in widget.race.participants!) {
        developer.log('      - ${p.userId} (${p.userName}) - Steps: ${p.steps}, Calories: ${p.calories}, Rank: ${p.rank}');
      }
    }

    // Get current user's participant data
    // 🐛 FIX: Use lastWhere instead of firstWhere to get the most recent participant data
    // This handles cases where duplicate participant entries exist (most recent one has correct data)
    Participant? currentParticipant;
    try {
      currentParticipant = widget.race.participants?.lastWhere(
        (p) => p.userId == currentUserId,
      );
    } catch (e) {
      developer.log('⚠️ [RACE_CARD] Participant NOT FOUND - using default zeros');
      currentParticipant = Participant(
        userId: '', userName: '', distance: 0, remainingDistance: totalDistance,
        rank: 0, steps: 0, calories: 0, avgSpeed: 0.0
      );
    }

    developer.log('   ✅ Current participant found: ${currentParticipant?.userId == currentUserId}');
    if (currentParticipant != null) {
      developer.log('      Steps: ${currentParticipant.steps}, Distance: ${currentParticipant.distance}, Calories: ${currentParticipant.calories}, Rank: ${currentParticipant.rank}, AvgSpeed: ${currentParticipant.avgSpeed}');
    }

    // Use participant data for user-specific metrics
    final remainingDistance = currentParticipant?.remainingDistance ?? totalDistance - (currentParticipant?.distance ?? 0.0);
    final avgSpeed = currentParticipant?.avgSpeed ?? 0.0;
    final currentRank = currentParticipant?.rank ?? 0;
    final calories = currentParticipant?.calories ?? 0;

    // Check if this is a solo race
    final isSoloRace = widget.race.raceTypeId == 1;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Left column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  icon: Icons.speed,
                  label: 'Avg Speed',
                  value: '${avgSpeed.toStringAsFixed(1)} km/h',
                  isIcon: true,
                ),
                SizedBox(height: 8),
                _buildInfoRow(
                  icon: Icons.local_fire_department,
                  label: 'Calories',
                  value: '$calories kcal',
                  isIcon: true,
                ),
              ],
            ),
          ),

          // Right column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Only show rank for competitive races (not solo)
                if (!isSoloRace)
                  _buildInfoRow(
                    icon: Icons.emoji_events,
                    label: 'My Rank',
                    value: currentRank > 0 ? '#$currentRank' : 'N/A',
                    isIcon: true,
                  ),
                if (!isSoloRace)
                  SizedBox(height: 8),
                _buildInfoRow(
                  icon: Icons.track_changes,
                  label: 'Remaining',
                  value: '${remainingDistance.toStringAsFixed(2)} km',
                  isIcon: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedRaceInfoSection() {
    final currentUserId = controller.auth.currentUser?.uid;

    // Get current user's participant data
    // 🐛 FIX: Use lastWhere instead of firstWhere to get the most recent participant data
    Participant? currentParticipant;
    try {
      currentParticipant = widget.race.participants?.lastWhere(
        (p) => p.userId == currentUserId,
      );
    } catch (e) {
      currentParticipant = Participant(
        userId: '', userName: '', distance: 0, remainingDistance: 0,
        rank: 0, steps: 0, calories: 0, avgSpeed: 0.0
      );
    }

    // Get completion metrics
    final finalRank = currentParticipant?.rank ?? 0;
    final distanceCovered = currentParticipant?.distance ?? 0.0;
    final avgSpeed = currentParticipant?.avgSpeed ?? 0.0;
    final calories = currentParticipant?.calories ?? 0;
    final finishOrder = currentParticipant?.finishOrder;

    // Check if this is a solo race
    final isSoloRace = widget.race.raceTypeId == 1;

    // Get rank emoji and badge text (hide for solo races)
    String rankBadge = '#$finalRank';
    String rankEmoji = '';
    if (!isSoloRace) {
      // Only show rank badges for competitive races
      if (finishOrder == 1 || finalRank == 1) {
        rankEmoji = '🥇';
        rankBadge = '1st Place';
      } else if (finishOrder == 2 || finalRank == 2) {
        rankEmoji = '🥈';
        rankBadge = '2nd Place';
      } else if (finishOrder == 3 || finalRank == 3) {
        rankEmoji = '🥉';
        rankBadge = '3rd Place';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.appColor.withValues(alpha: 0.05),
            Colors.white,
          ],
        ),
      ),
      child: Column(
        children: [
          // Completion badge
          if (rankEmoji.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.appColor.withValues(alpha: 0.2),
                    AppColors.primary.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.appColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rankEmoji,
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(width: 6),
                  Text(
                    rankBadge,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

          // Metrics
          Row(
            children: [
              // Left column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      icon: Icons.emoji_events,
                      label: 'Final Rank',
                      value: finalRank > 0 ? '#$finalRank' : 'N/A',
                      isIcon: true,
                    ),
                    SizedBox(height: 8),
                    _buildInfoRow(
                      icon: Icons.speed,
                      label: 'Avg Speed',
                      value: '${avgSpeed.toStringAsFixed(1)} km/h',
                      isIcon: true,
                    ),
                  ],
                ),
              ),

              // Right column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      icon: Icons.straighten,
                      label: 'Distance',
                      value: '${distanceCovered.toStringAsFixed(2)} km',
                      isIcon: true,
                    ),
                    SizedBox(height: 8),
                    _buildInfoRow(
                      icon: Icons.local_fire_department,
                      label: 'Calories',
                      value: '$calories kcal',
                      isIcon: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    final isMarathon = widget.race.raceTypeId == 4;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Left column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  icon: IconPaths.friendsIcon,
                  label: 'Participants',
                  value:
                      '${widget.race.joinedParticipants ?? 0}/${widget.race.maxParticipants ?? 0}',
                ),
                SizedBox(height: 8),
                _buildInfoRow(
                  icon: isMarathon ? Icons.all_inclusive : IconPaths.timerIcon,
                  label: isMarathon ? 'Duration' : 'Duration',
                  value: isMarathon ? 'No limit' : '${widget.race.durationHrs ?? 24} hours',
                  isIcon: isMarathon,
                ),
              ],
            ),
          ),

          // Right column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isMarathon) ...[
                  // For Marathon: Show Type and Status instead of schedule
                  _buildInfoRow(
                    icon: Icons.emoji_events,
                    label: 'Type',
                    value: 'Endurance',
                    isIcon: true,
                  ),
                  SizedBox(height: 8),
                  _buildInfoRow(
                    icon: Icons.timeline,
                    label: 'Schedule',
                    value: 'Open-ended',
                    isIcon: true,
                  ),
                ] else ...[
                  // For other races: Show normal schedule
                  _buildInfoRow(
                    icon: Icons.calendar_today,
                    label: 'Start Date',
                    value: _formatDate(widget.race.raceScheduleTime ?? ''),
                    isIcon: true,
                  ),
                  SizedBox(height: 8),
                  _buildInfoRow(
                    icon: Icons.access_time,
                    label: 'Start Time',
                    value: _formatTime(widget.race.raceScheduleTime ?? ''),
                    isIcon: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required dynamic icon,
    required String label,
    required String value,
    bool isIcon = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isIcon)
          Icon(
            icon as IconData,
            size: 14,
            color: AppColors.appColor.withValues(alpha: 0.7),
          )
        else
          SvgPicture.asset(
            icon as String,
            width: 14,
            height: 14,
            colorFilter: ColorFilter.mode(
              AppColors.appColor.withValues(alpha: 0.7),
              BlendMode.srcIn,
            ),
          ),
        SizedBox(width: 8),
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

  Widget _buildActionButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Obx(() {
        // Find the current race from the controller's races list for real-time updates
        final currentRace =
            controller.races.firstWhereOrNull((r) => r.id == widget.race.id) ??
            widget.race;
        final isJoined = controller.isUserInRace(currentRace);
        final canJoin = controller.canJoinRace(currentRace);
        final hasPending = controller.hasPendingJoinRequest(currentRace.id);
        final isButtonLoading = controller.isRaceButtonLoading(
          currentRace.id ?? '',
        );

        // Check if current user has completed the race
        final currentUserId = controller.auth.currentUser?.uid;
        final userParticipant = currentRace.participants?.firstWhereOrNull(
          (p) => p.userId == currentUserId,
        );
        final userCompleted = userParticipant?.isCompleted ?? false;

        String buttonText;
        bool isEnabled;
        bool isGuestLocked = false;

        if (isJoined) {
          // User is in the race - check completion status
          if (userCompleted && (currentRace.statusId == 3 || currentRace.statusId == 6)) {
            // User finished but race still ongoing
            buttonText = 'Completed';
            isEnabled = true;
          } else if (currentRace.statusId == 4) {
            // Race fully completed
            buttonText = 'View Final Results';
            isEnabled = true;
          } else {
            // Race active, user still racing
            buttonText = 'View Race';
            isEnabled = true;
          }
        } else if (isButtonLoading) {
          buttonText = 'Loading...';
          isEnabled = false;
        } else if (hasPending) {
          buttonText = 'Request Pending';
          isEnabled = false;
        } else if (canJoin) {
          // Check if guest user trying to join race
          if (GuestUtils.isGuest()) {
            buttonText = 'Join Race';
            isEnabled = false;
            isGuestLocked = true;
          } else {
            if (currentRace.isPrivate == true) {
              buttonText = 'Request to Join';
            } else {
              buttonText = 'Join Race';
            }
            isEnabled = true;
          }
        } else {
          if ((currentRace.joinedParticipants ?? 0) >=
              (currentRace.maxParticipants ?? 0)) {
            buttonText = 'Race Full';
          } else if (currentRace.statusId == 4) {
            buttonText = 'Completed';
          } else if (currentRace.statusId == 5) {
            buttonText = 'Cancelled';
          } else {
            buttonText = 'Unavailable';
          }
          isEnabled = false;
        }

        return SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: isEnabled
                ? () => _handleButtonPress(currentRace)
                : isGuestLocked
                    ? () => GuestUpgradeDialog.show(featureName: 'Join Race')
                    : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isJoined
                  ? Color(
                      0xFF059669,
                    ) // Professional green for joined - improved visibility
                  : isEnabled || isGuestLocked
                  ? AppColors.appColor
                  : Color(0xFF9CA3AF),
              // Better disabled color - softer grey
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: isEnabled || isGuestLocked ? 3 : 0,
              // Slightly more elevation for better depth
              shadowColor: isJoined
                  ? Color(0xFF059669).withValues(alpha: 0.3)
                  : AppColors.appColor.withValues(alpha: 0.3),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isButtonLoading) ...[
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 8),
                ] else if (isJoined) ...[
                  Icon(Icons.check_circle, size: 18),
                  SizedBox(width: 8),
                ] else if (currentRace.raceTypeId == 4) ...[
                  // Marathon type - show first priority
                  Icon(Icons.emoji_events, size: 18),
                  SizedBox(width: 8),
                ] else if (currentRace.isPrivate == true) ...[
                  Icon(Icons.lock, size: 16),
                  SizedBox(width: 8),
                ] else if (currentRace.isPrivate == false &&
                    currentRace.raceTypeId != 1) ...[
                  // Public type
                  Icon(Icons.public, size: 16),
                  SizedBox(width: 8),
                ],
                Text(
                  buttonText,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Color _getRaceTypeColor() {
    if (widget.race.raceTypeId == 1) {
      return Color(0xFF0EA5E9); // Solo - Professional blue
    } else if (widget.race.raceTypeId == 4) {
      return Color(0xFFDC2626); // Marathon - Bold red/orange for endurance
    } else if (widget.race.isPrivate == true) {
      return Color(0xFFEA580C); // Private - Warmer orange
    } else {
      return Color(0xFF059669); // Public - Professional green
    }
  }

  String _formatDate(String scheduleTime) {
    try {
      // First try to parse as ISO format
      final DateTime dateTime = DateTime.parse(scheduleTime);
      return DateFormat('MMM dd, yyyy').format(dateTime);
    } catch (e) {
      try {
        // Try to parse the format "dd/MM/yyyy at hh:mm a"
        if (scheduleTime.contains(' at ')) {
          final datePart = scheduleTime.split(' at ')[0];
          final DateTime dateTime = DateFormat('dd/MM/yyyy').parse(datePart);
          return DateFormat('MMM dd, yyyy').format(dateTime);
        }
        return scheduleTime.split(' ').first;
      } catch (e2) {
        return scheduleTime.split(' ').first;
      }
    }
  }

  String _formatTime(String scheduleTime) {
    try {
      // First try to parse as ISO format
      final DateTime dateTime = DateTime.parse(scheduleTime);
      return DateFormat('HH:mm').format(dateTime);
    } catch (e) {
      try {
        // Try to parse the format "dd/MM/yyyy at hh:mm a"
        if (scheduleTime.contains(' at ')) {
          final parts = scheduleTime.split(' at ');
          if (parts.length >= 2) {
            final datePart = parts[0];
            final timePart = parts[1];

            // Parse both date and time to get full DateTime
            final dateTime = DateFormat('dd/MM/yyyy').parse(datePart);
            final timeFormat = DateFormat('hh:mm a');
            final timeOnly = timeFormat.parse(timePart);

            // Combine date and time
            final fullDateTime = DateTime(
              dateTime.year,
              dateTime.month,
              dateTime.day,
              timeOnly.hour,
              timeOnly.minute,
            );

            return DateFormat('HH:mm').format(fullDateTime);
          }
        }

        // Fallback: try to extract just the time part
        final timePart = scheduleTime
            .split(' ')
            .where(
              (part) =>
                  part.contains(':') ||
                  part.toLowerCase().contains('am') ||
                  part.toLowerCase().contains('pm'),
            )
            .join(' ');

        if (timePart.isNotEmpty) {
          final timeOnly = DateFormat('hh:mm a').parse(timePart);
          return DateFormat('HH:mm').format(timeOnly);
        }

        return scheduleTime.split(' ').last;
      } catch (e2) {
        return scheduleTime.split(' ').last;
      }
    }
  }

  void _handleButtonPress(RaceData race) {
    final isJoined = controller.isUserInRace(race);
    final canJoin = controller.canJoinRace(race);
    final currentUserId = controller.auth.currentUser?.uid;

    // Check if user completed but race still ongoing
    final userParticipant = race.participants?.firstWhereOrNull(
      (p) => p.userId == currentUserId,
    );
    final userCompleted = userParticipant?.isCompleted ?? false;

    if (isJoined) {
      // Navigate to race map screen for joined races
      // (including when user completed but race still ongoing)
      Get.to(
        RaceMapScreen(
          role: race.organizerUserId == currentUserId
              ? UserRole.organizer
              : UserRole.participant,
          raceModel: race,
        ),
      );
    } else if (canJoin) {
      // Handle race join functionality
      if (race.isPrivate == true) {
        // For private races, show invite dialog or request to join
        _handlePrivateRaceJoin(race);
      } else {
        // For public races, join directly
        _handlePublicRaceJoin(race);
      }
    } else {
      // Navigate to race details for races that can't be joined
      Get.toNamed('/race-details/${race.id}');
    }
  }

  Future<void> _handlePublicRaceJoin(RaceData race) async {
    // Use the controller's race button press handler for public races too
    controller.handleRaceButtonPress(race);
  }

  void _handlePrivateRaceJoin(RaceData race) {
    // Use the controller's race button press handler for private races
    controller.handleRaceButtonPress(race);
  }

  void _onCardTap() {
    final currentUserId = controller.auth.currentUser?.uid;
    final isJoined = controller.isUserInRace(widget.race);

    if (isJoined) {
      // Navigate to race map screen if user has joined
      Get.to(
        () => RaceMapScreen(
          raceModel: widget.race,
          role: widget.race.organizerUserId == currentUserId
              ? UserRole.organizer
              : UserRole.participant,
        ),
      );
    } else {
      // Navigate to race details for non-joined races
      Get.toNamed('/race-details/${widget.race.id}');
    }
  }
}
