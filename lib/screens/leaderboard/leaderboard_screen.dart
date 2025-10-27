import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';
import '../../config/app_colors.dart';
import '../../controllers/leaderboard_controller.dart';
import '../../utils/init_season_data.dart';
import '../../widgets/common/custom_app_bar.dart';
import 'widgets/premium_podium_display.dart';
import 'widgets/leaderboard_entry_card.dart';
import 'widgets/xp_badge.dart';
import 'widgets/filter_toggle.dart';
import 'widgets/season_dropdown.dart';

class LeaderboardScreen extends StatefulWidget {
  LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    // Play confetti when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playConfettiIfDataReady();
    });

    // Also listen to controller in case data is still loading
    final controller = Get.find<LeaderboardController>();
    ever(controller.isLoading, (isLoading) {
      if (!isLoading &&
          controller.leaderboardEntries.isNotEmpty &&
          mounted) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            _confettiController.play();
          }
        });
      }
    });
  }

  void _playConfettiIfDataReady() {
    final controller = Get.find<LeaderboardController>();
    if (!controller.isLoading.value &&
        controller.leaderboardEntries.isNotEmpty &&
        mounted) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          _confettiController.play();
        }
      });
    }
  }


  @override
  void dispose() {
    _tabController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(LeaderboardController());
    final screenHeight = MediaQuery.of(context).size.height;
    final topSectionHeight = screenHeight * 0.38;

    return Scaffold(
      appBar: CustomAppBar(
        title: "🏆 Leaderboard",
        showMenuIcon: false,
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
      backgroundColor: AppColors.orangeYellow,
      body: SafeArea(
        child: Stack(
          children: [
            // Top 40% - Orangish-yellow gradient background with sparkle effect
            Container(
              height: topSectionHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.orangeYellow,
                    AppColors.orangeYellow.withValues(alpha: 0.85),
                  ],
                ),
              ),
              child: CustomPaint(
                painter: SparklePainter(),
                child: Container(),
              ),
            ),

            // Content
            Obx(() {
              // Show shimmer skeleton while data is loading
              if (controller.isLoading.value && controller.leaderboardEntries.isEmpty) {
                return Column(
                  children: [
                    // Top section with shimmer
                    SizedBox(
                      height: topSectionHeight,
                      child: Column(
                        children: [
                          // Header placeholder
                          _buildHeaderWithSeasonSelector(controller),

                          // Shimmer Podium
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(child: _buildShimmerPodiumCard(false)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildShimmerPodiumCard(true)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildShimmerPodiumCard(false)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom section with shimmer list
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(32),
                          topRight: Radius.circular(32),
                        ),
                        child: Container(
                          color: AppColors.lightBackground,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(top: 16, bottom: 20),
                            itemCount: 5,
                            itemBuilder: (context, index) => _buildShimmerListCard(),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  // Top section content (Blue background)
                  SizedBox(
                    height: topSectionHeight,
                    child: Column(
                      children: [
                        // Header with tabs and season selector
                        _buildHeaderWithSeasonSelector(controller),

                        // Podium Display
                        Expanded(
                          child: controller.topThree.isEmpty
                              ? const SizedBox.shrink()
                              : Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: PremiumPodiumDisplay(
                                    topThree: controller.topThree,
                                  ),
                              ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom section with rounded corners (White background)
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                      child: Container(
                        color: AppColors.lightBackground,
                        child: controller.remainingEntries.isEmpty
                            ? const SizedBox.shrink()
                            : ListView.builder(
                                padding: const EdgeInsets.only(top: 16, bottom: 20),
                                itemCount: controller.remainingEntries.length,
                                itemBuilder: (context, index) {
                                  final entry = controller.remainingEntries[index];
                                  final isCurrentUser = entry.userId == controller.currentUserId;

                                  return LeaderboardEntryCard(
                                    entry: entry,
                                    isCurrentUser: isCurrentUser,
                                  )
                                      .animate()
                                      .fadeIn(duration: 400.ms, delay: (50 * index).ms)
                                      .slideX(
                                        begin: 0.2,
                                        end: 0,
                                        duration: 400.ms,
                                        delay: (50 * index).ms,
                                        curve: Curves.easeOutCubic,
                                      );
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              );
            }),

            // Confetti widgets - on top of everything
            Align(
              alignment: Alignment.topLeft,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: pi / 4, // Blast from top-left
                emissionFrequency: 0.03,
                numberOfParticles: 8,
                gravity: 0.25,
                minimumSize: const Size(5, 5),
                maximumSize: const Size(10, 10),
                colors: const [
                  Color(0xFFFFD700), // Gold
                  Color(0xFFC0C0C0), // Silver
                  Color(0xFFCD7F32), // Bronze
                  Color(0xFF2759FF), // Blue
                ],
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: 3 * pi / 4, // Blast from top-right
                emissionFrequency: 0.03,
                numberOfParticles: 8,
                gravity: 0.25,
                minimumSize: const Size(5, 5),
                maximumSize: const Size(10, 10),
                colors: const [
                  Color(0xFFFFD700), // Gold
                  Color(0xFFC0C0C0), // Silver
                  Color(0xFFCD7F32), // Bronze
                  Color(0xFF2759FF), // Blue
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderWithSeasonSelector(LeaderboardController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Tab Bar - takes most of the space
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: AppColors.neonYellow,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonYellow.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey[600],
                labelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                tabs: [
                  Tab(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Friends'),
                    ),
                  ),
                  Tab(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Global'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Season Dropdown Button
          Obx(() => GestureDetector(
            onTap: () => _showSeasonDropdown(context, controller),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [

                  Text(
                    controller.selectedSeason.value?.name ?? 'Season',
                    style: GoogleFonts.poppins(
                      color: AppColors.appColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.appColor,
                    size: 24,
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildShimmerPodiumCard(bool isWinner) {
    return Transform.translate(
      offset: isWinner ? const Offset(0, -20) : Offset.zero,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            margin: EdgeInsets.only(top: isWinner ? 35 : 30),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 80,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 60,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              width: isWinner ? 80 : 70,
              height: isWinner ? 80 : 70,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerListCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 60,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }

  void _showSeasonDropdown(BuildContext context, LeaderboardController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
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

            // Title
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Select Season',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),

            // Season list
            Obx(() => ListView.builder(
              shrinkWrap: true,
              itemCount: controller.seasons.length,
              itemBuilder: (context, index) {
                final season = controller.seasons[index];
                final isSelected = controller.selectedSeason.value?.id == season.id;

                return InkWell(
                  onTap: () {
                    controller.changeSeason(season);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.neonYellow.withValues(alpha: 0.2)
                          : Colors.transparent,
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (season.isCurrent) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.neonYellow,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'CURRENT',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            season.name,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.black : Colors.black87,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: AppColors.neonYellow,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                );
              },
            )),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// Custom painter for sparkle effect background
class SparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final random = Random(42); // Fixed seed for consistent sparkles

    // Draw sparkles
    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final sparkleSize = 2 + random.nextDouble() * 3;

      // Draw a cross/star shape for sparkle
      canvas.drawLine(
        Offset(x - sparkleSize, y),
        Offset(x + sparkleSize, y),
        paint,
      );
      canvas.drawLine(
        Offset(x, y - sparkleSize),
        Offset(x, y + sparkleSize),
        paint,
      );

      // Optional diagonal lines for more sparkle effect
      if (i % 3 == 0) {
        canvas.drawLine(
          Offset(x - sparkleSize * 0.7, y - sparkleSize * 0.7),
          Offset(x + sparkleSize * 0.7, y + sparkleSize * 0.7),
          paint,
        );
        canvas.drawLine(
          Offset(x - sparkleSize * 0.7, y + sparkleSize * 0.7),
          Offset(x + sparkleSize * 0.7, y - sparkleSize * 0.7),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


