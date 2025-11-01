import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../config/assets/icons.dart';
import '../controllers/race/race_map_controller.dart';
import '../core/models/race_data_model.dart';
import '../services/admob_service.dart';
import '../services/firebase_subscription_service.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/custom_widgets.dart';
import '../widgets/common/vertical_dash_divider.dart';

class WinnerWidget extends StatelessWidget {
  const WinnerWidget({
    super.key,
    required this.size,
    required this.raceModel,
    required this.mapController,
  });

  final Size size;
  final RaceData? raceModel;
  final MapController mapController;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size.height,
      width: size.width,
      color: Colors.white,
      child: Column(
        children: [
          // Custom App Bar
          CustomAppBar(
            title: "Race Completed",
            isBack: false,
            circularBackButton: false,
            backgroundColor: Colors.white,
            titleColor: AppColors.appColor,
            showGradient: false,
            titleStyle: GoogleFonts.roboto(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.appColor,
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    SizedBox(height: 20),

                    // Trophy Icon with Gradient
                    Container(
                      padding: EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.appColor.withValues(alpha: 0.1),
                            AppColors.neonYellow.withValues(alpha: 0.1),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: SvgPicture.asset(
                        IconPaths.winnerCup,
                        width: 100,
                        height: 100,
                      ),
                    ),

                    SizedBox(height: 24),

                    // Hurray Text
                    Text(
                      "Hurray!",
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.buttonBlack,
                      ),
                    ),

                    SizedBox(height: 8),

                    Text(
                      "You've completed the race!",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.iconGrey,
                      ),
                    ),

                    SizedBox(height: 32),

                    // Race Route Card
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                IconPaths.radioIcon,
                                color: AppColors.appColor,
                                width: 20,
                                height: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: VerticalDashedDivider(
                                  isHorizontal: true,
                                  dashHeight: 5,
                                  dashSpacing: 2,
                                  color: AppColors.iconGrey,
                                  width: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              SvgPicture.asset(
                                IconPaths.locationIcon,
                                color: AppColors.neonYellow,
                                width: 20,
                                height: 20,
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  "${raceModel?.startAddress}",
                                  style: GoogleFonts.poppins(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.left,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  "${raceModel?.endAddress}",
                                  style: GoogleFonts.poppins(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.right,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32),

                    // Info Text - conditional based on participant count
                    if (mapController.participantsList.length > 1)
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.appColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppColors.appColor,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Watch others racing and see live updates!",
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.buttonBlack,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: 24),

                    // Check if there's only one participant (solo race)
                    // If solo, skip "View Race Map" and go straight to leaderboard
                    if (mapController.participantsList.length == 1)
                      CustomButton(
                        btnTitle: "View Leaderboard",
                        onPress: () {
                          // Navigate to RaceWinnersScreen to show leaderboard
                          Get.off(() => RaceWinnersScreen(
                            raceData: raceModel,
                            participants: mapController.participantsList.toList(),
                          ));
                        },
                      )
                    else
                      // View Results Button - Show for multi-participant races
                      CustomButton(
                        btnTitle: "View Race Map",
                        onPress: () async {
                          await _handleViewResults(
                            context,
                            raceModel!,
                            mapController.participantsList,
                          );
                        },
                      ),

                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ AD-GATED VIEW RACE MAP ============

  /// Handle viewing race map with ad gate for free users
  /// Dismisses WinnerWidget and activates view-only mode
  Future<void> _handleViewResults(
      BuildContext context,
      RaceData raceData,
      List<Participant> participants,
      ) async {
    try {
      // Check if user is premium
      bool isPremium = false;
      try {
        if (Get.isRegistered<FirebaseSubscriptionService>()) {
          final subscriptionService = Get.find<FirebaseSubscriptionService>();
          isPremium = subscriptionService.currentSubscription.value.isPremium;
        }
      } catch (e) {
        print('⚠️ Could not check subscription status: $e');
      }

      if (isPremium) {
        // Premium users get direct access
        print('✅ Premium user - direct access to view-only mode');
        _activateViewOnlyMode();
        return;
      }

      // Free users must watch ad
      print('📺 Free user - showing rewarded ad');
      final adService = AdMobService();

      // Show loading dialog
      _showAdLoadingDialog(context);

      // Load ad if not ready
      if (!adService.isAdReady) {
        await adService.loadRewardedAd();

        // Wait for ad to load (max 10 seconds)
        int attempts = 0;
        while (!adService.isAdReady && attempts < 20) {
          await Future.delayed(const Duration(milliseconds: 500));
          attempts++;
        }
      }

      // Close loading dialog
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (!adService.isAdReady) {
        // Ad failed to load - show error but allow access anyway (better UX)
        if (context.mounted) {
          _showSnackbar(
            context,
            'Ad failed to load. Showing race map anyway...',
            isError: false,
          );
        }
        _activateViewOnlyMode();
        return;
      }

      // Show the ad
      final watchedAd = await adService.showRewardedAd();

      if (watchedAd) {
        // User watched the ad - grant access
        print('✅ User watched ad - activating view-only mode');
        _activateViewOnlyMode();
      } else {
        // User closed ad without watching
        if (context.mounted) {
          _showSnackbar(
            context,
            'Please watch the ad to view race map',
            isError: true,
          );
        }
      }
    } catch (e) {
      print('❌ Error handling view results: $e');
      // On error, allow access (fail gracefully)
      _activateViewOnlyMode();
    }
  }

  /// Activate view-only mode - dismiss WinnerWidget and show race map with banner
  void _activateViewOnlyMode() {
    print('🔄 Activating view-only mode');
    mapController.isViewOnlyMode.value = true;
  }

  /// Show loading dialog while ad loads
  void _showAdLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.appColor),
              SizedBox(height: 16),
              Text(
                'Loading ad...',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show snackbar message
  void _showSnackbar(BuildContext context, String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }
}

void showRankingBottomSheet(
    BuildContext context,
    RxList<Participant> dataList,
    ) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        bottom: true,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    '🏆 Participant Rankings',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Obx(() {
                    final sortedList = [...dataList];
                    sortedList.sort((a, b) => a.rank.compareTo(b.rank));

                    return ListView.builder(
                      controller: controller,
                      itemCount: sortedList.length,
                      itemBuilder: (_, index) {
                        final item = sortedList[index];
                        // Ensure participant name is never blank - use fallback if empty
                        final displayName = (item.userName == null || item.userName!.isEmpty)
                            ? 'User ${item.userId.substring(0, 6)}'
                            : item.userName!;

                        return ListTile(
                          leading: Text('${item.rank}'),
                          title: Text(
                            displayName,
                            style: GoogleFonts.poppins(),
                          ),
                          subtitle: Text(
                            'Distance covered: ${item.distance.toStringAsFixed(2)} km',
                            style: GoogleFonts.poppins(),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

class RaceWinnersScreen extends StatelessWidget {
  final RaceData? raceData;
  final List<Participant> participants;

  const RaceWinnersScreen({
    super.key,
    required this.raceData,
    required this.participants,
  });

  @override
  Widget build(BuildContext context) {
    // Sort participants by rank
    final sortedParticipants = [...participants];
    sortedParticipants.sort((a, b) => a.rank.compareTo(b.rank));

    // Get top 3 finishers
    final topFinishers = sortedParticipants.take(3).toList();

    // Check if this is a solo race
    final isSoloRace = raceData?.raceTypeId == 1;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: CustomAppBar(
        title: "Race Winners",
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
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Hero Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.appColor,
                      AppColors.appColor.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.appColor.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      size: 48,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      raceData?.title ?? 'Race',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Race Complete!',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Quick Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildHeaderStat(
                          Icons.group,
                          '${participants.length}',
                          'Racers',
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        _buildHeaderStat(
                          Icons.straighten,
                          '${raceData?.totalDistance?.toStringAsFixed(1) ?? '0'} km',
                          'Distance',
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        _buildHeaderStat(
                          Icons.check_circle,
                          '${participants.where((p) => p.isCompleted).length}',
                          'Finished',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Top 3 Finishers Section (hide for solo races)
              if (!isSoloRace && topFinishers.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.appColor,
                              AppColors.appColor.withValues(alpha: 0.85),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              'Top 3 Finishers',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...topFinishers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final participant = entry.value;
                  final medals = ['🥇', '🥈', '🥉'];
                  final medalColors = [
                    [const Color(0xFF1E88E5), const Color(0xFF1565C0)], // Blue gradient for 1st
                    [const Color(0xFFC0C0C0), const Color(0xFF999999)],
                    [const Color(0xFFCD7F32), const Color(0xFF8B4513)],
                  ];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          medalColors[index][0].withValues(alpha: 0.05),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: medalColors[index][0].withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: medalColors[index][0].withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Medal Badge
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: medalColors[index],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: medalColors[index][1].withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                medals[index],
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Participant Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        participant.userName.isNotEmpty
                                            ? participant.userName
                                            : "Participant ${participant.rank}",
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.buttonBlack,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: medalColors[index][0].withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '#${participant.rank}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: medalColors[index][1],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _buildCompactStat(
                                      Icons.straighten,
                                      '${min(participant.distance, raceData?.totalDistance ?? double.infinity).toStringAsFixed(2)} km',
                                    ),
                                    if (participant.avgSpeed > 0) ...[
                                      const SizedBox(width: 12),
                                      _buildCompactStat(
                                        Icons.speed,
                                        '${participant.avgSpeed.toStringAsFixed(1)} km/h',
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ] else if (!isSoloRace) ...[
                // Non-solo race with no finishers yet
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "No participants completed the race yet.",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: AppColors.iconGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ] else if (isSoloRace && sortedParticipants.isNotEmpty) ...[
                // Solo race - show personal stats
                Text(
                  "📊 Your Performance",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.buttonBlack,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "🏅",
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sortedParticipants[0].userName.isNotEmpty
                                      ? sortedParticipants[0].userName
                                      : "You",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.buttonBlack,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Distance: ${sortedParticipants[0].distance.toStringAsFixed(2)} km",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: AppColors.iconGrey,
                                  ),
                                ),
                                if (sortedParticipants[0].avgSpeed > 0)
                                  Text(
                                    "Avg Speed: ${sortedParticipants[0].avgSpeed.toStringAsFixed(2)} km/h",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: AppColors.iconGrey,
                                    ),
                                  ),
                                Text(
                                  "Steps: ${sortedParticipants[0].steps}",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: AppColors.iconGrey,
                                  ),
                                ),
                                if (sortedParticipants[0].calories > 0)
                                  Text(
                                    "Calories: ${sortedParticipants[0].calories}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: AppColors.iconGrey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // All Participants Section
              if (sortedParticipants.length > 3) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.blue.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.group, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              'All Participants',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${sortedParticipants.length}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Non-scrollable list - all items visible
                ...sortedParticipants.map((participant) {
                  final isTopThree = participant.rank <= 3;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isTopThree
                          ? AppColors.appColor.withValues(alpha: 0.05)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isTopThree
                            ? AppColors.appColor.withValues(alpha: 0.2)
                            : Colors.grey.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          // Rank Badge
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: isTopThree
                                  ? LinearGradient(
                                colors: [
                                  AppColors.appColor.withValues(alpha: 0.9),
                                  AppColors.appColor,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                                  : LinearGradient(
                                colors: [
                                  Colors.grey.shade200,
                                  Colors.grey.shade300,
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: isTopThree
                                  ? [
                                BoxShadow(
                                  color: AppColors.appColor.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                "${participant.rank}",
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isTopThree
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Participant Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  participant.userName.isNotEmpty
                                      ? participant.userName
                                      : "Participant ${participant.rank}",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.buttonBlack,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    _buildCompactStat(
                                      Icons.straighten,
                                      '${min(participant.distance, raceData?.totalDistance ?? double.infinity).toStringAsFixed(2)} km',
                                    ),
                                    if (participant.avgSpeed > 0) ...[
                                      const SizedBox(width: 10),
                                      _buildCompactStat(
                                        Icons.speed,
                                        '${participant.avgSpeed.toStringAsFixed(1)} km/h',
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Completion Indicator
                          if (participant.isCompleted)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.green,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 80), // Bottom padding for better scroll experience
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Helper method to build compact stat displays
  static Widget _buildCompactStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.iconGrey),
        const SizedBox(width: 3),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.iconGrey,
          ),
        ),
      ],
    );
  }

  /// Helper method to build header stat displays
  static Widget _buildHeaderStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.white),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
