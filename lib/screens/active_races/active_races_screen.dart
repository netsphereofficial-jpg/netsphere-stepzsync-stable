import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stepzsync/controllers/race/races_list_controller.dart';
import 'package:stepzsync/widgets/race/race_card_widget.dart';

import '../../config/app_colors.dart';
import '../../config/assets/icons.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/race_data_model.dart';
import '../../widgets/common/custom_app_bar.dart';

class ActiveRacesScreen extends StatefulWidget {
  const ActiveRacesScreen({super.key});

  @override
  State<ActiveRacesScreen> createState() => _ActiveRacesScreenState();
}

class _ActiveRacesScreenState extends State<ActiveRacesScreen>
    with TickerProviderStateMixin {
  final RacesListController controller = Get.put(RacesListController());
  late AnimationController _cardAnimationController;
  late AnimationController _statsAnimationController;

  @override
  void initState() {
    super.initState();

    _cardAnimationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    _statsAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    // Start animations with delays
    Future.delayed(Duration(milliseconds: 200), () {
      _statsAnimationController.forward();
    });

    Future.delayed(Duration(milliseconds: 600), () {
      _cardAnimationController.forward();
    });

    // Set up real-time updates every 30 seconds to refresh race status
    Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        controller.refreshRaces();
      } else {
        timer.cancel();
      }
    });

    // Start monitoring participant changes for user's races
    Future.delayed(Duration(milliseconds: 1000), () {
      controller.startMonitoringUserRaces();
    });
  }

  @override
  void dispose() {
    _cardAnimationController.dispose();
    _statsAnimationController.dispose();
    // Stop monitoring participant changes when screen is disposed
    controller.stopMonitoringAllRaces();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xffE8E8F8),
      appBar: CustomAppBar(
        title: "My Races",
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
              child: RefreshIndicator(
                onRefresh: controller.refreshRaces,
                color: AppColors.neonYellow,
                child: Obx(() {
                  if (controller.isLoading.value && controller.races.isEmpty) {
                    return _buildLoadingState();
                  }

                  final currentUserId = controller.auth.currentUser?.uid;

                  // Get all races that user has joined (including as organizer)
                  // Filter to show ONLY active races where user hasn't completed yet
                  final joinedRaces = controller.races.where((race) {
                    if (currentUserId == null) return false;

                    // Check if user is the organizer
                    final isOrganizer = race.organizerUserId == currentUserId;

                    // Check if user is a participant using the proper method
                    final isParticipant = controller.isUserInRace(race);

                    // Check if user has completed this race
                    final userParticipant = race.participants?.firstWhere(
                      (p) => p.userId == currentUserId,
                      orElse: () => Participant(
                        userId: '', userName: '', distance: 0, remainingDistance: 0,
                        rank: 0, steps: 0, calories: 0, avgSpeed: 0.0, isCompleted: false
                      ),
                    );
                    final userHasCompleted = userParticipant?.isCompleted ?? false;

                    // Check if race is active for this user:
                    // - Status 0, 1 (Created, Scheduled - waiting to start)
                    // - Status 3 (Active - currently racing)
                    // - Status 6 (Ending - deadline countdown, show for all users including those who finished)
                    // - Exclude status 4 (fully completed) and 7 (cancelled)
                    final isActiveForUser = (race.statusId == 0 || // Created/Ready
                                            race.statusId == 1 || // Scheduled
                                            race.statusId == 3 || // Active
                                            race.statusId == 6);  // Ending (show for all - users can watch others)

                    return (isOrganizer || isParticipant) && isActiveForUser;
                  }).toList();

                  // If no joined races, show empty state
                  if (joinedRaces.isEmpty) {
                    return _buildEmptyState();
                  }

                  return Column(
                    children: [
                      // Stats header

                      // Race sections
                      Expanded(
                        child: ListView(
                          physics: BouncingScrollPhysics(),
                          padding: EdgeInsets.only(
                            bottom: AppConstants.defaultPadding,
                          ),
                          children: [
                            // Joined races section
                            // _buildSectionHeader("My Races", joinedRaces.length),
                            SizedBox(height: 24),

                            ...joinedRaces.asMap().entries.map(
                              (entry) => _buildAnimatedRaceCard(
                                entry.value,
                                entry.key,
                              ),
                            ),
                            SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    return AnimatedBuilder(
      animation: _statsAnimationController,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * _statsAnimationController.value),
          child: Opacity(
            opacity: _statsAnimationController.value.clamp(0.0, 1.0),
            child: Container(
              margin: EdgeInsets.all(AppConstants.defaultPadding),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.neonYellow.withValues(alpha: 0.12),
                    AppColors.neonYellow.withValues(alpha: 0.08),
                    AppColors.neonYellow.withValues(alpha: 0.04),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.neonYellow.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonYellow.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: Offset(0, 6),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.8),
                    blurRadius: 16,
                    offset: Offset(0, -2),
                    spreadRadius: -1,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedStatItem({
    required String icon,
    required String title,
    required String value,
    required int delay,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.elasticOut,
      builder: (context, animationValue, child) {
        return Transform.scale(
          scale: animationValue.clamp(0.1, 1.0),
          child: Opacity(
            opacity: animationValue.clamp(0.0, 1.0),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.neonYellow.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SvgPicture.asset(
                    icon,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      AppColors.neonYellow,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: int.tryParse(value) ?? 0),
                  duration: Duration(milliseconds: 1000 + delay),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedValue, child) {
                    return Text(
                      animatedValue.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neonYellow,
                      ),
                    );
                  },
                ),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        _buildStatsHeader(),
        Expanded(
          child: ListView.builder(
            itemCount: 5,
            padding: EdgeInsets.symmetric(
              horizontal: AppConstants.defaultPadding,
            ),
            itemBuilder: (context, index) => _buildShimmerCard(),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 100,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Spacer(),
              Container(
                width: 60,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 150,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Spacer(),
              Container(
                width: 80,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.neonYellow.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_run,
                    size: 50,
                    color: AppColors.buttonBlack,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'No Joined Races',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'You haven\'t joined any races yet. Browse available races and join one to see it here!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Get.toNamed('/race'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonYellow,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    'Browse Races',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600,

                      color: AppColors.buttonBlack,

                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedRaceCard(race, int index) {
    return AnimatedBuilder(
      animation: _cardAnimationController,
      builder: (context, child) {
        final animationDelay = index * 0.1;
        final rawAnimationValue =
            (_cardAnimationController.value - animationDelay).clamp(0.0, 1.0);
        final animationValue = Curves.easeOutBack
            .transform(rawAnimationValue)
            .clamp(0.0, 1.0);

        return Transform.translate(
          offset: Offset(0, 50 * (1 - animationValue)),
          child: Opacity(
            opacity: animationValue.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: (0.95 + (0.05 * animationValue)).clamp(0.1, 1.0),
              child: RaceCardWidget(race: race),
            ),
          ),
        );
      },
    );
  }
}
