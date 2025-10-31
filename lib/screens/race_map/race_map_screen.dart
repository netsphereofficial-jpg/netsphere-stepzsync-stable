import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../config/app_colors.dart';
import '../../controllers/notification_controller.dart';
import '../../controllers/race/race_map_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/subscription_controller.dart';
import '../../core/models/race_data_model.dart';
import '../../core/utils/common_methods.dart';
import '../../services/race_repository.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/custom_widgets.dart' hide showSnackbar;
import '../../widgets/race_chat/race_chat_bottom_sheet.dart';
import '../../utils/guest_utils.dart';
import '../../widgets/guest_upgrade_dialog.dart';
import '../../screens/subscription/subscription_screen.dart';
import '../race_winner_screens_widgets.dart';
import '../race_dnf_screen_widget.dart';
import 'widgets/race_start_countdown.dart';

enum UserRole { participant, organizer }

class RaceMapScreen extends StatelessWidget {
  final RaceData? raceModel;
  final UserRole role;
  final mapController = Get.put(MapController());
  final chatController = Get.put(ChatController());
  final GlobalKey _mapKey = GlobalKey();

  RaceMapScreen({super.key, this.raceModel, required this.role});

  @override
  Widget build(BuildContext context) {
    mapController.setRaceData(raceModel!);

    var size = MediaQuery.of(context).size;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (Get.isRegistered<MapController>()) {
          Get.delete<MapController>();
        }
      },
      child: Obx(() {
        // ✅ IMPROVED: Centralized completion check logic (no duplication)
        final completionState = _getCompletionState(mapController);

        // Hide app bar when showing winner or DNF screen
        final shouldShowAppBar = !completionState.showDNFScreen && !completionState.showWinnerScreen;

        return Scaffold(
          appBar: shouldShowAppBar ? CustomAppBar(
            title: raceModel?.title ?? "",
            isBack: true,
            circularBackButton: true,
            backButtonCircleColor: AppColors.neonYellow,
            backButtonIconColor: Colors.black,
            backgroundColor: Colors.white,
            titleColor: AppColors.appColor,
            showGradient: false,
            titleStyle: GoogleFonts.roboto(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.appColor,
            ),
            onBackClick: () {
              if (Get.isRegistered<MapController>()) {
                Get.delete<MapController>();
              }
              Get.back();
            },
            actions: [
              // Race type and status badges
              Obx(() {
                final raceTypeId = raceModel?.raceTypeId ?? 3;
                String typeText = '';
                Color badgeColor = AppColors.appColor;

                if (raceTypeId == 1) {
                  typeText = 'Solo';
                  badgeColor = Color(0xFF0EA5E9);
                } else if (raceTypeId == 4) {
                  typeText = 'Marathon';
                  badgeColor = Color(0xFFDC2626);
                } else if (raceModel?.isPrivate == true) {
                  typeText = 'Private';
                  badgeColor = Color(0xFFEA580C);
                } else {
                  typeText = 'Public';
                  badgeColor = Color(0xFF059669);
                }

                return Row(
                  children: [
                    // Race type badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: badgeColor.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        typeText,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    // Status indicator
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getStatusColor(mapController.raceStatus.value),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _getStatusText(mapController.raceStatus.value),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                  ],
                );
              }),

              // Race chat icon with unread badge - hide for solo races
              if (raceModel?.raceTypeId != 1) ...[
                Stack(
                  children: [
                    IconButton(
                      onPressed: () => _openRaceChat(context),
                      icon: Icon(Icons.chat_bubble_outline, color: AppColors.appColor, size: 22),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.neonYellow.withValues(alpha: 0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Obx(() {
                        final unreadCount = chatController
                            .getUnreadRaceMessageCount(raceModel?.id ?? '');
                        if (unreadCount == 0) return SizedBox.shrink();

                        return Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
                SizedBox(width: 4),
              ],

              // Leaderboard icon - hide for solo races
              if (_shouldShowLeaderboard())
                IconButton(
                  onPressed: () {
                    if (mapController.participantsList.isEmpty) {
                      mapController.participantsList.value =
                          raceModel?.participants ?? [];
                    }
                    showRankingBottomSheet(context, mapController.participantsList);
                  },
                  icon: Icon(Icons.leaderboard, color: AppColors.appColor, size: 22),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.neonYellow.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ) : null,

          body: SafeArea(
            child: Obx(() {
            // ✅ IMPROVED: Use centralized completion state (prevents duplicate code and race conditions)
            final completionState = _getCompletionState(mapController);

            if (completionState.showDNFScreen) {
              return DNFWidget(
                size: size,
                raceModel: raceModel,
                mapController: mapController,
              );
            } else if (completionState.showWinnerScreen) {
              return WinnerWidget(
                size: size,
                raceModel: raceModel,
                mapController: mapController,
              ); // or your fallback UI
            } else {
              return Stack(
                children: [
                  RepaintBoundary(
                    key: _mapKey,
                    child: GoogleMap(
                      mapType: MapType.normal,
                      initialCameraPosition: CameraPosition(
                        target: mapController.start,
                        zoom: 14.0,
                      ),

                      // Performance optimizations
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      compassEnabled: false,
                      mapToolbarEnabled: false,
                      buildingsEnabled: false,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      trafficEnabled: false,
                      // Allow free zoom - no restrictions
                      zoomGesturesEnabled: true,
                      zoomControlsEnabled: true,

                      onMapCreated: (controller) {
                        mapController.onMapCreated(controller);
                        mapController.setMapKey(_mapKey);
                      },
                      markers: mapController.markers.toSet(),
                      onTap: mapController.onMarkerTap,
                      polylines: mapController.polylines.toSet(),
                    ),
                  ),

                  // Top stats bar - show before race starts
                  Obx(() {
                    // Only show for status 0, 1, 2 (before race starts)
                    if (mapController.raceStatus.value != 0 &&
                        mapController.raceStatus.value != 1 &&
                        mapController.raceStatus.value != 2) {
                      return SizedBox.shrink();
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: _buildStats(mapController),
                          ),
                        ),
                      ),
                    );
                  }),

                  // View-Only Mode Banner (for completed users watching others)
                  Obx(() {
                    if (!mapController.isViewOnlyMode.value) {
                      return SizedBox.shrink();
                    }

                    return Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.appColor,
                              AppColors.appColor.withValues(alpha: 0.8),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.visibility,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "You've finished! Watching others race...",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Race countdown timer - hide in view-only mode
                  Obx(() {
                    // Hide countdown for completed users in view-only mode
                    if (mapController.isViewOnlyMode.value) {
                      return SizedBox.shrink();
                    }

                    return mapController.formattedTime.value != "00:00:00"
                        ? countDownTimer(
                            mapController.raceStatus.value,
                            mapController.formattedTime.value,
                          )
                        : SizedBox();
                  }),

                  // Milestone Tracker for Marathon (top-right floating)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _buildMilestoneTracker(mapController),
                  ),

                  Positioned(
                    left: 10,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _buildCompactGapIndicator(context, mapController),
                    ),
                  ),

                  // Motivation Messages (top-center floating)
                  Positioned(
                    top: 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _buildMotivationMessage(mapController),
                    ),
                  ),

                  // Race Start Countdown (below top stats) - for status 0 or 1
                  Obx(() {
                    if ((mapController.raceStatus.value == 0 || mapController.raceStatus.value == 1) &&
                        raceModel?.raceScheduleTime != null) {
                      try {
                        DateTime scheduleTime;
                        final scheduleStr = raceModel!.raceScheduleTime!;

                        // Try to parse the schedule time
                        // First try ISO8601 format
                        try {
                          scheduleTime = DateTime.parse(scheduleStr);
                        } catch (_) {
                          // If that fails, try custom format: "dd-MM-yyyy hh:mm a"
                          final formatter = DateFormat('dd-MM-yyyy hh:mm a');
                          scheduleTime = formatter.parse(scheduleStr);
                        }

                        final now = DateTime.now();

                        // Only show if schedule time is in the future
                        if (scheduleTime.isAfter(now)) {
                          return Positioned(
                            top: 80, // Position just below the top stats bar
                            left: 0,
                            right: 0,
                            child: RaceStartCountdown(
                              scheduleTime: scheduleTime,
                              isOrganizer: role == UserRole.organizer,
                            ),
                          );
                        }
                      } catch (e) {
                        print('Error parsing race schedule time: $e');
                      }
                    }
                    return const SizedBox.shrink();
                  }),

                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: getWidgetForType(
                        mapController.raceStatus.value,
                        role == UserRole.organizer,
                      ),
                    ),
                  ),
                ],
              );
            }
          }),
        ),
          // floatingActionButton: FloatingActionButton.extended(
          //   onPressed: () => mapController.moveUserMarker(10), // move 50 meters
          //   label: const Text('Move 10m', style: TextStyle(color: Colors.black)),
          //   icon: const Icon(Icons.directions_walk, color: Colors.black),
          // ),
        );
      }),
    );
  }

  void _openRaceChat(BuildContext context) {
    if (raceModel == null) return;

    // Check if guest user trying to access chat
    if (GuestUtils.isGuest()) {
      GuestUpgradeDialog.show(featureName: 'Race Chat');
      return;
    }

    // Check if user has premium access
    // Use Get.isRegistered to safely check if controller exists
    if (Get.isRegistered<SubscriptionController>()) {
      final subscriptionController = Get.find<SubscriptionController>();
      if (!subscriptionController.hasPremiumAccess) {
        // Show premium dialog for non-premium users
        _showPremiumRequiredDialog(context);
        return;
      }
    } else {
      // If subscription controller is not registered, show premium dialog
      // (Cannot verify premium status, so restrict access by default)
      debugPrint('⚠️ SubscriptionController not registered, restricting chat access');
      _showPremiumRequiredDialog(context);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      enableDrag: true,
      builder: (context) => RaceChatBottomSheet(raceModel: raceModel!),
    );
  }

  /// Build countdown timer for scheduled race start time
  Widget _buildScheduleCountdown(DateTime scheduleTime, bool isOrganizer) {
    return StreamBuilder(
      stream: Stream.periodic(Duration(seconds: 1)),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final timeLeft = scheduleTime.difference(now);

        if (timeLeft.isNegative) {
          // Schedule time has passed - this shouldn't happen as parent widget checks,
          // but handle it gracefully
          return SizedBox.shrink();
        }

        final hours = timeLeft.inHours;
        final minutes = timeLeft.inMinutes % 60;
        final seconds = timeLeft.inSeconds % 60;

        String timeLeftStr;
        if (hours > 0) {
          timeLeftStr = '${hours}h ${minutes}m ${seconds}s';
        } else if (minutes > 0) {
          timeLeftStr = '${minutes}m ${seconds}s';
        } else {
          timeLeftStr = '${seconds}s';
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.appColor.withValues(alpha: 0.15),
                    AppColors.appColor.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.appColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isOrganizer ? "Race starts in:" : "Waiting for race to start",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.appColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      timeLeftStr,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (isOrganizer) ...[
                    SizedBox(height: 12),
                    Text(
                      "You can start the race once the timer reaches zero",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget countDownTimer(int status, String time) {
    // Don't show countdown for marathon races (no time limit)
    if (raceModel?.raceTypeId == 4 && status == 6) {
      return SizedBox.shrink();
    }

    switch (status) {
      case 6:
        // Show race ending countdown banner with duration info
        final isSolo = raceModel?.raceTypeId == 1;
        final durationMins = raceModel?.durationMins ??
                            ((raceModel?.durationHrs ?? 1) * 60);
        final durationText = durationMins < 60
            ? '$durationMins mins'
            : durationMins == 60
                ? '1 hour'
                : '${(durationMins / 60).ceil()} hours';

        return Positioned(
          top: 80,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timer,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            isSolo ? "Time Running Out!" : "Race Ending Soon!",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        time,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        isSolo
                          ? "Complete the race! ($durationText limit)"
                          : "Time left (out of $durationText)",
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

      default:
        return SizedBox();
    }
  }

  Widget getWidgetForType(int status, bool isOrganizer) {
    switch (status) {
      case 0:
      case 1:
        // Organizer can start race anytime, participants wait
        if (isOrganizer) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.appColor,
                    AppColors.appColor.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.appColor.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Builder(
                  builder: (BuildContext context) {
                    return InkWell(
                      onTap: () async {
                        final minPart = mapController.raceModel.value?.minParticipants ?? 3;
                        final currentPart = mapController.joinedParticipants.value;

                        if (currentPart < minPart) {
                          // Show error dialog
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: Row(
                              children: [
                                Icon(Icons.people_outline, color: Colors.orange, size: 28),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Not Enough Participants',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You need at least $minPart participants to start the race.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.orange.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Current',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          Text(
                                            '$currentPart',
                                            style: GoogleFonts.poppins(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Icon(Icons.arrow_forward, color: Colors.grey),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Required',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          Text(
                                            '$minPart',
                                            style: GoogleFonts.poppins(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'OK',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.appColor,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                      return;
                    }

                    if (!await isNetworkAvailable()) {
                      showSnackbar('', TranslationKeys.internetError);
                      return;
                    }

                    // Show countdown animation (3, 2, 1, GO!)
                    if (context.mounted) {
                      await _showCountdownAnimation(context);
                    }

                    // Start the race after countdown
                    var response = await RaceRepository().startRaceApiCall(
                      raceModel?.id,
                    );

                    // Check if race start was successful
                    if (response != null && response['status'] == 200) {
                      // Race started successfully
                    } else {
                      showSnackbar(
                        'Error',
                        response?['message'] ?? 'Failed to start race',
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_circle_filled,
                          color: Colors.white,
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Text(
                          "Start Race",
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                  },
                ),
              ),
            ),
          );
        } else {
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  "Waiting for organizer to start the race!",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
      case 2:
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),

              child: Text(
                "Race starting in ${mapController.formattedTime.value} seconds",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      case 3:
        // Bottom stats only - Gap and ETA moved to floating widgets
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.all(10),
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: _buildStatsBelow(mapController),
            ),
          ),
        );

      case 6:
        // Race ending - show stats with motivational message (Gap and ETA moved to floating widgets)
        // Marathon: Show motivational message without deadline pressure
        final isMarathon = raceModel?.raceTypeId == 4;
        final isSolo = raceModel?.raceTypeId == 1;

        // Get the first finisher's name and position
        String motivationalMessage;
        if (isMarathon) {
          motivationalMessage = "Keep Racing! No time limit";
        } else if (isSolo) {
          motivationalMessage = "Time is running out! Finish strong!";
        } else {
          // Find the first person who completed the race
          final completedParticipants = mapController.participantsList
              .where((p) => p.isCompleted == true)
              .toList()
            ..sort((a, b) => (a.rank ?? 999).compareTo(b.rank ?? 999));

          if (completedParticipants.isNotEmpty) {
            final firstFinisher = completedParticipants.first;
            final finisherName = firstFinisher.userName ?? 'Someone';
            final position = _getRankSuffix(firstFinisher.rank ?? 1);
            motivationalMessage = "🏆 $finisherName took $position place! Keep racing!";
          } else {
            motivationalMessage = "Keep Racing! Time is running!";
          }
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isMarathon
                    ? AppColors.appColor.withValues(alpha: 0.5)
                    : Colors.orange.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isMarathon ? Icons.emoji_events : Icons.running_with_errors,
                        color: isMarathon ? AppColors.appColor : Colors.orange,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          motivationalMessage,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isMarathon
                              ? AppColors.appColor
                              : Colors.orange.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  _buildStatsBelow(mapController),
                ],
              ),
            ),
          ),
        );

      case 4:
        return CustomButton(
          btnTitle: "Race completed. Check winner list.",
          onPress: () async {
            // Navigate to winner screen with race data and participants
            Get.to(() => RaceWinnersScreen(
              raceData: raceModel,
              participants: mapController.participantsList.toList(),
            ));
          },
        );

      case 5:
        return const CircularProgressIndicator();

      default:
        return const SizedBox();
    }
  }

  Widget _buildStats(MapController controller) {
    return Obx(
      () {
        // Check if race data is available
        if (controller.raceModel.value == null) {
          return SizedBox.shrink();
        }

        final raceTypeId = raceModel?.raceTypeId ?? 3;
        final badge = _getRaceTypeBadge();

        List<Widget> stats = [];

        // Distance - show for all races
        stats.add(_overallStatItem(
          title: "Distance",
          value: "${controller.raceModel.value!.totalDistance} km",
        ));

        // Solo race: Show duration
        if (raceTypeId == 1) {
          stats.add(_overallStatItem(
            title: "Duration",
            value: "${controller.raceModel.value!.durationMins ?? 5} mins",
          ));
        }
        // Marathon: Show type and participants
        else if (raceTypeId == 4) {
          stats.add(_overallStatItem(
            title: "Type",
            value: "Endurance",
          ));
          stats.add(_overallStatItem(
            title: "Participants",
            value: "${controller.joinedParticipants}/${controller.raceModel.value!.maxParticipants}",
          ));
        }
        // Public/Private: Show schedule and participants
        else {
          stats.add(_overallStatItem(
            title: "Starts on",
            value: getFormattedDate(
              controller.raceModel.value!.raceScheduleTime.toString(),
            ),
          ));
          stats.add(_overallStatItem(
            title: "Starts at",
            value: getFormattedTime(
              controller.raceModel.value!.raceScheduleTime.toString(),
            ),
          ));
          stats.add(_overallStatItem(
            title: "Participants",
            value: "${controller.joinedParticipants}/${controller.raceModel.value!.maxParticipants}",
          ));
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: stats,
          ),
        );
      },
    );
  }

  Widget _buildStatsBelow(MapController controller) {
    return Obx(
      () {
        final raceTypeId = raceModel?.raceTypeId ?? 3;
        final isSolo = raceTypeId == 1;

        List<Widget> stats = [
          _overallStatItem(
            title: "Avg\nSpeed",
            value: "${_getCurrentUserAvgSpeed(mapController).toStringAsFixed(2)} km/h",
          ),
          _overallStatItem(
            title: "Distance\ncovered",
            value: "${_getCurrentUserDistance(mapController).toFixed2OrDash()} km",
          ),
          _overallStatItem(
            title: "Distance\nremaining",
            value: "${_getCurrentUserRemainingDistance(mapController).toFixed2OrDash()} km",
          ),
        ];

        // Add position only for non-solo races
        if (!isSolo) {
          stats.add(_overallStatItem(
            title: "My\nPosition",
            value: "#${_getCurrentUserRank(mapController)}",
          ));
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: stats,
          ),
        );
      },
    );
  }

  double _getCurrentUserDistance(MapController mapController) {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null || mapController.participantsList.isEmpty) {
        return 0.0;
      }

      // Get distance covered from participant data (most up-to-date)
      final currentUserParticipant = mapController.participantsList.firstWhere(
        (participant) => participant.userId == currentUserId,
        orElse: () => Participant(
          userId: '',
          userName: '',
          distance: 0.0,
          remainingDistance: 0.0,
          rank: 0,
          steps: 0,
        ),
      );

      if (currentUserParticipant.userId == currentUserId) {
        return currentUserParticipant.distance;
      }

      return 0.0;
    } catch (e) {
      print('Error getting current user distance: $e');
      return 0.0;
    }
  }

  int _getCurrentUserRank(MapController mapController) {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        return 0;
      }

      // ✅ OPTIMIZED: Use cached rank method from controller
      // This prevents 480+ redundant log entries per minute
      return mapController.getCurrentUserRank();
    } catch (e) {
      print('❌ Error getting current user rank: $e');
      return 1;
    }
  }

  double _getCurrentUserRemainingDistance(MapController mapController) {
    try {
      final totalDistance = mapController.raceModel.value?.totalDistance ?? 0.0;
      final distanceCovered = _getCurrentUserDistance(mapController);

      final remaining = totalDistance - distanceCovered;
      return remaining > 0 ? remaining : 0.0;
    } catch (e) {
      print('Error calculating remaining distance: $e');
      return 0.0;
    }
  }

  double _getCurrentUserAvgSpeed(MapController mapController) {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null || mapController.participantsList.isEmpty) {
        // Return 0.0 if no participant data is loaded yet to avoid showing stale data
        return 0.0;
      }

      final currentUserParticipant = mapController.participantsList.firstWhere(
        (participant) => participant.userId == currentUserId,
        orElse: () => Participant(
          userId: currentUserId,
          userName: 'Unknown',
          distance: 0.0,
          remainingDistance: 0.0,
          rank: 0,
          steps: 0,
          avgSpeed: 0.0,
        ),
      );

      final avgSpeed = currentUserParticipant.avgSpeed;

      // Additional validation: For walking, avg speed should be reasonable (0-10 km/h)
      // Return 0.0 if speed seems unrealistic or if distance is 0 (no movement yet)
      if (avgSpeed < 0 ||
          avgSpeed > 10 ||
          currentUserParticipant.distance <= 0) {
        return 0.0;
      }

      return avgSpeed;
    } catch (e) {
      print('Error getting current user avg speed: $e');
      return 0.0;
    }
  }

  RichText _overallStatItem({required String title, required String value}) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        text: title,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.mediumGrey,
        ),

        children: <TextSpan>[
          TextSpan(
            text: '\n$value',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // ============ HELPER METHODS FOR RACE TYPE CUSTOMIZATION ============

  /// Check if leaderboard should be shown (hide for solo races)
  bool _shouldShowLeaderboard() {
    return raceModel?.raceTypeId != 1; // Hide for solo
  }

  /// Check if countdown timer should be shown (hide for marathon)
  bool _shouldShowCountdown() {
    return raceModel?.raceTypeId != 4; // Hide for marathon
  }

  /// Check if gap analysis should be shown (hide for solo)
  bool _shouldShowGapAnalysis() {
    return raceModel?.raceTypeId != 1; // Hide for solo
  }

  /// Get race type badge
  Widget? _getRaceTypeBadge() {
    final raceTypeId = raceModel?.raceTypeId;

    if (raceTypeId == 1) return _buildBadge('Solo', Color(0xFF0EA5E9));
    if (raceTypeId == 4) return _buildBadge('Marathon', Color(0xFFDC2626));
    if (raceModel?.isPrivate == true) return _buildBadge('🔒 Private', Color(0xFFEA580C));
    if (raceModel?.isPrivate == false) return _buildBadge('🌐 Public', Color(0xFF059669));
    return null;
  }

  /// Build race type badge widget
  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  /// Format gap distance in meters or kilometers
  String _formatGap(int meters) {
    if (meters >= 1000) {
      return "${(meters / 1000).toStringAsFixed(2)} km";
    } else {
      return "$meters m";
    }
  }

  /// Get rank suffix (1st, 2nd, 3rd, etc.)
  String _getRankSuffix(int rank) {
    if (rank == 1) return "1st";
    if (rank == 2) return "2nd";
    if (rank == 3) return "3rd";
    return "${rank}th";
  }

  /// Get status text for app bar
  String _getStatusText(int status) {
    switch (status) {
      case 0:
        return "CREATED";
      case 1:
        return "SCHEDULED";
      case 2:
        return "STARTING";
      case 3:
        return "ACTIVE";
      case 4:
        return "COMPLETED";
      case 6:
        return "ENDING";
      case 7:
        return "CANCELLED";
      default:
        return "UNKNOWN";
    }
  }

  /// Get status color for app bar
  Color _getStatusColor(int status) {
    switch (status) {
      case 0:
      case 1:
        return Colors.blue.shade400;
      case 2:
        return Colors.orange.shade400;
      case 3:
        return Colors.green.shade500;
      case 4:
        return Colors.purple.shade400;
      case 6:
        return Colors.red.shade400;
      case 7:
        return Colors.grey.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  // ============ GAP ANALYSIS WIDGET ============
  // NOTE: Gap analysis is now handled by compact gap indicator + bottom sheet

  Widget _buildGapAnalysis(MapController controller) {
    // Replaced with compact gap indicator - no longer showing full widget here
    return SizedBox.shrink();
  }

  // ============ MOTIVATION MESSAGES ============

  Widget _buildMotivationMessage(MapController controller) {
    // Hide motivation messages in view-only mode (completed users watching)
    if (controller.isViewOnlyMode.value) {
      return SizedBox.shrink();
    }

    if (controller.raceStatus.value != 3 && controller.raceStatus.value != 6) {
      return SizedBox.shrink();
    }

    final remainingDistance = _getCurrentUserRemainingDistance(controller);
    final distance = _getCurrentUserDistance(controller);
    final totalDistance = raceModel?.totalDistance ?? 0;
    final rank = _getCurrentUserRank(controller);

    if (distance <= 0) return SizedBox.shrink();

    String? message;
    IconData? icon;
    Color? bgColor;

    // Check various conditions
    if (remainingDistance < 0.5 && remainingDistance > 0) {
      message = "Just ${(remainingDistance * 1000).toInt()}m to go! You got this!";
      icon = Icons.celebration;
      bgColor = Colors.green;
    } else if (distance >= totalDistance / 2 && distance < (totalDistance / 2 + 0.1)) {
      message = "🎯 Halfway there! Keep up the pace!";
      icon = Icons.stars;
      bgColor = Colors.blue;
    } else if (rank == 1 && raceModel?.raceTypeId != 1) {
      message = "🔥 You're leading! Don't slow down!";
      icon = Icons.emoji_events;
      bgColor = Colors.amber.shade700;
    }

    if (message == null) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor?.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, color: Colors.white, size: 18),
          if (icon != null) SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ COMPACT ETA WIDGET ============


  // ============ COMPACT GAP INDICATOR ============

  Widget _buildCompactGapIndicator(BuildContext context, MapController controller) {
    // Hide in view-only mode (completed users watching)
    if (controller.isViewOnlyMode.value) {
      return SizedBox.shrink();
    }

    // Hide for solo races
    if (!_shouldShowGapAnalysis()) return SizedBox.shrink();

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || controller.participantsList.isEmpty) {
      return SizedBox.shrink();
    }

    // Only show during active race (status 3 or 6)
    if (controller.raceStatus.value != 3 && controller.raceStatus.value != 6) {
      return SizedBox.shrink();
    }

    final sortedParticipants = controller.participantsList.toList()
      ..sort((a, b) => b.distance.compareTo(a.distance));

    final myIndex = sortedParticipants.indexWhere((p) => p.userId == currentUserId);
    if (myIndex == -1) return SizedBox.shrink();

    final myDistance = sortedParticipants[myIndex].distance;

    // Don't show if no one has started moving yet
    if (myDistance <= 0 && sortedParticipants.first.distance <= 0) {
      return SizedBox.shrink();
    }

    // Determine which gap to show
    String gapText = "";
    IconData icon = Icons.insights;
    Color color = AppColors.appColor;

    if (myIndex == 0) {
      // Leading - show gap to player behind
      if (sortedParticipants.length > 1) {
        final playerBehind = sortedParticipants[1];
        final gapBehind = ((myDistance - playerBehind.distance) * 1000).toInt();
        if (gapBehind > 0) {
          gapText = "+${_formatGap(gapBehind)}";
          icon = Icons.star;
          color = Colors.amber.shade700;
        }
      } else {
        return SizedBox.shrink();
      }
    } else {
      // Not leading - show gap to player ahead
      final playerAhead = sortedParticipants[myIndex - 1];
      final gapAhead = ((playerAhead.distance - myDistance) * 1000).toInt();
      if (gapAhead > 0) {
        gapText = "-${_formatGap(gapAhead)}";
        icon = Icons.arrow_upward;
        color = Colors.orange.shade700;
      }
    }

    if (gapText.isEmpty) return SizedBox.shrink();

    return GestureDetector(
      onTap: () => _showFullGapsBottomSheet(context, controller),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            SizedBox(height: 2),
            Text(
              gapText,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ FULL GAPS BOTTOM SHEET ============

  void _showFullGapsBottomSheet(BuildContext context, MapController controller) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || controller.participantsList.isEmpty) return;

    final sortedParticipants = controller.participantsList.toList()
      ..sort((a, b) => b.distance.compareTo(a.distance));

    final myIndex = sortedParticipants.indexWhere((p) => p.userId == currentUserId);
    if (myIndex == -1) return;

    final myDistance = sortedParticipants[myIndex].distance;

    // Player ahead
    final playerAhead = myIndex > 0 ? sortedParticipants[myIndex - 1] : null;
    final gapAhead = playerAhead != null
        ? ((playerAhead.distance - myDistance) * 1000).toInt()
        : null;

    // Player behind
    final playerBehind = myIndex < sortedParticipants.length - 1
        ? sortedParticipants[myIndex + 1]
        : null;
    final gapBehind = playerBehind != null
        ? ((myDistance - playerBehind.distance) * 1000).toInt()
        : null;

    // Leader gap
    final leader = sortedParticipants.first;
    final leaderGap = ((leader.distance - myDistance) * 1000).toInt();

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.insights, color: AppColors.appColor),
                  SizedBox(width: 8),
                  Text(
                    "Race Gaps",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // If in first place
              if (myIndex == 0) ...[
                _buildFullGapItem(
                  icon: Icons.star,
                  color: Colors.amber.shade700,
                  label: "You're leading!",
                  value: gapBehind != null && gapBehind > 0
                      ? "by ${_formatGap(gapBehind)}"
                      : "",
                  isPositive: true,
                ),
              ] else ...[
                // Gap to leader
                if (leaderGap > 0)
                  _buildFullGapItem(
                    icon: Icons.emoji_events,
                    color: Colors.amber.shade700,
                    label: "Gap to leader",
                    value: _formatGap(leaderGap),
                    isPositive: false,
                  ),

                // Gap to player ahead
                if (gapAhead != null && gapAhead > 0)
                  _buildFullGapItem(
                    icon: Icons.arrow_upward,
                    color: Colors.orange.shade700,
                    label: "${playerAhead!.userName} ahead",
                    value: _formatGap(gapAhead),
                    isPositive: false,
                  ),
              ],

              // Gap to player behind (if exists)
              if (gapBehind != null && gapBehind > 0)
                _buildFullGapItem(
                  icon: Icons.arrow_downward,
                  color: Colors.green.shade700,
                  label: "${playerBehind!.userName} behind",
                  value: _formatGap(gapBehind),
                  isPositive: true,
                ),

              SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFullGapItem({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required bool isPositive,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============ MILESTONE TRACKER FOR MARATHON ============

  Widget _buildMilestoneTracker(MapController controller) {
    // Hide in view-only mode (completed users watching)
    if (controller.isViewOnlyMode.value) {
      return SizedBox.shrink();
    }

    if (raceModel?.raceTypeId != 4) return SizedBox.shrink(); // Marathon only
    if (controller.raceStatus.value != 3 && controller.raceStatus.value != 6) {
      return SizedBox.shrink();
    }

    final distance = _getCurrentUserDistance(controller);
    if (distance <= 0) return SizedBox.shrink();

    final milestones = [5.0, 10.0, 15.0, 21.0, 30.0, 42.195]; // Marathon milestones

    // Find next milestone
    final nextMilestone = milestones.firstWhere(
      (m) => m > distance,
      orElse: () => milestones.last,
    );

    final distanceToNext = nextMilestone - distance;
    final completedMilestones = milestones.where((m) => m <= distance).toList();

    return Container(
      padding: EdgeInsets.all(12),
      constraints: BoxConstraints(maxWidth: 160),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade50,
            Colors.orange.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.flag, size: 16, color: Colors.amber.shade700),
              SizedBox(width: 6),
              Text(
                "Milestones",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),

          // Completed milestones
          if (completedMilestones.isNotEmpty)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: completedMilestones.map((m) => Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Text(
                  "✓ ${m}km",
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              )).toList(),
            ),

          if (completedMilestones.isNotEmpty) SizedBox(height: 8),

          // Next milestone
          if (distance < milestones.last)
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade400, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.my_location, size: 14, color: Colors.amber.shade900),
                      SizedBox(width: 4),
                      Text(
                        "Next: ${nextMilestone}km",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                  if (distanceToNext > 0) ...[
                    SizedBox(height: 4),
                    Text(
                      "${distanceToNext.toStringAsFixed(2)}km away",
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            // All milestones completed
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade400, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.emoji_events, size: 16, color: Colors.green.shade700),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "All done! 🎉",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ============ COUNTDOWN ANIMATION FOR RACE START ============

  /// Show beautiful countdown animation (3, 2, 1, GO!)
  Future<void> _showCountdownAnimation(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (BuildContext context) {
        return _CountdownDialog();
      },
    );
  }

  // ============ PREMIUM FEATURE DIALOG ============

  /// Show premium required dialog for race chat
  void _showPremiumRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.appColor, AppColors.neonYellow],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Premium Feature',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Race Chat is a premium feature. Upgrade to premium to:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 16),
              _buildPremiumBenefit('💬 Chat with race participants'),
              _buildPremiumBenefit('🏆 Access exclusive races'),
              _buildPremiumBenefit('📊 Advanced statistics'),
              _buildPremiumBenefit('🎯 Priority support'),
              _buildPremiumBenefit('🚫 Ad-free experience'),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.appColor.withValues(alpha: 0.1),
                      AppColors.neonYellow.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.appColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: AppColors.appColor,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Unlock all premium features now!',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.appColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Maybe Later',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Navigate to subscription screen
                Get.to(() => SubscriptionScreen());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.appColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Upgrade Now',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPremiumBenefit(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 18,
            color: Colors.green,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Countdown Dialog with animated numbers
class _CountdownDialog extends StatefulWidget {
  @override
  _CountdownDialogState createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  int _currentNumber = 3;
  bool _showGo = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _startCountdown();
  }

  void _startCountdown() async {
    // Count down: 3, 2, 1
    for (int i = 3; i >= 1; i--) {
      setState(() {
        _currentNumber = i;
        _showGo = false;
      });

      _controller.reset();
      _controller.forward();

      await Future.delayed(const Duration(milliseconds: 1000));
    }

    // Show "GO!"
    setState(() {
      _showGo = true;
    });

    _controller.reset();
    _controller.forward();

    await Future.delayed(const Duration(milliseconds: 800));

    // Close dialog
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _showGo
                        ? [
                            Colors.green.shade400,
                            Colors.green.shade600,
                          ]
                        : [
                            AppColors.appColor,
                            AppColors.appColor.withValues(alpha: 0.8),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_showGo ? Colors.green : AppColors.appColor)
                          .withValues(alpha: 0.5),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: _showGo
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_circle_filled,
                              size: 60,
                              color: Colors.white,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'GO!',
                              style: GoogleFonts.poppins(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          '$_currentNumber',
                          style: GoogleFonts.poppins(
                            fontSize: 100,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// ✅ IMPROVED: Centralized completion state logic to prevent DNF/Winner screen flicker
  /// This method checks completion state in ONE place, eliminating race conditions
  _CompletionState _getCompletionState(MapController mapController) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    bool currentUserCompleted = false;

    // Check if current user has completed from participant data
    if (currentUserId != null && mapController.participantsList.isNotEmpty) {
      final currentUserParticipant = mapController.participantsList.firstWhere(
        (p) => p.userId == currentUserId,
        orElse: () => Participant(
          userId: '',
          userName: '',
          distance: 0,
          remainingDistance: mapController.raceModel.value?.totalDistance ?? 0,
          rank: 0,
          steps: 0,
          isCompleted: false,
        ),
      );
      currentUserCompleted = currentUserParticipant.isCompleted;
    }

    // Also check remainingDistance for backward compatibility
    final remainingDistanceZero = mapController.raceModel.value != null &&
        mapController.raceModel.value!.remainingDistance! <= 0;

    // ✅ FIX: Prioritize isCompleted flag over remainingDistance
    // The optimistic update in controller sets isCompleted=true immediately
    // This ensures Winner screen shows instantly without DNF flicker
    final currentUserFinished = currentUserCompleted || remainingDistanceZero;

    // Use raceEnded flag instead of status to prevent flickering
    final raceCompleted = mapController.raceEnded.value;

    // Show DNF screen if race ended but user didn't finish
    final showDNFScreen = raceCompleted &&
        !currentUserFinished &&
        !mapController.isViewOnlyMode.value;

    // Show WinnerWidget ONLY if user finished
    final showWinnerScreen = currentUserFinished &&
        raceCompleted &&
        !mapController.isViewOnlyMode.value;

    return _CompletionState(
      showDNFScreen: showDNFScreen,
      showWinnerScreen: showWinnerScreen,
      currentUserFinished: currentUserFinished,
    );
  }
}

/// Helper class to hold completion state
class _CompletionState {
  final bool showDNFScreen;
  final bool showWinnerScreen;
  final bool currentUserFinished;

  _CompletionState({
    required this.showDNFScreen,
    required this.showWinnerScreen,
    required this.currentUserFinished,
  });
}

