import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:confetti/confetti.dart';
import '../../core/constants/text_styles.dart';
import '../../controllers/hall_of_fame_controller.dart';
import '../../models/xp_models.dart';
import '../../services/hall_of_fame_service.dart';
import 'widgets/champion_display_case.dart';
import 'widgets/trophy_shelf.dart';
import 'widgets/seasonal_champions_timeline.dart';
import 'widgets/spotlight_painter.dart';

class HallOfFameScreen extends StatefulWidget {
  const HallOfFameScreen({super.key});

  @override
  State<HallOfFameScreen> createState() => _HallOfFameScreenState();
}

class _HallOfFameScreenState extends State<HallOfFameScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late ConfettiController _confettiController;
  final HallOfFameController controller = Get.put(HallOfFameController());

  final List<Map<String, dynamic>> categories = [
    {
      'title': 'XP Titans',
      'subtitle': 'Top XP',
      'icon': Icons.bolt,
      'color': Color(0xFFFFD700), // Gold
    },
    {
      'title': 'Most Active',
      'subtitle': 'Races',
      'icon': Icons.directions_run,
      'color': Color(0xFF2759FF), // Blue
    },
    {
      'title': 'Podium Club',
      'subtitle': 'Top 3s',
      'icon': Icons.military_tech,
      'color': Color(0xFFC0C0C0), // Silver
    },
    {
      'title': 'Champions',
      'subtitle': 'Winners',
      'icon': Icons.emoji_events,
      'color': Color(0xFFCD7F32), // Bronze
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // Trigger confetti on screen load
    Future.delayed(const Duration(milliseconds: 500), () {
      _confettiController.play();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Hall of Fame',
          style: AppTextStyles.heroHeading.copyWith(
            color: const Color(0xFFFFD700),
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Animated museum background
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return CustomPaint(
                painter: MuseumBackgroundPainter(
                  animationValue: _animationController.value,
                ),
                size: Size.infinite,
              );
            },
          ),

          // Spotlight effects
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return CustomPaint(
                painter: SpotlightPainter(
                  animationValue: _animationController.value,
                  spotlightCount: 3,
                ),
                size: Size.infinite,
              );
            },
          ),

          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 3.14 / 2, // Down
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.3,
              colors: const [
                Color(0xFFFFD700),
                Color(0xFFC0C0C0),
                Color(0xFFCD7F32),
                Color(0xFF2759FF),
              ],
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Category tabs
                _buildCategoryTabs(),

                const SizedBox(height: 16),

                // Content area
                Expanded(
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return _buildLoadingState();
                    }

                    if (controller.hasError.value) {
                      return _buildErrorState();
                    }

                    return _buildCategoryContent();
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 80,
      child: Obx(() {
        final selectedIndex = controller.selectedCategoryIndex.value; // Read observable here
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final isSelected = selectedIndex == index;

            return GestureDetector(
              onTap: () => controller.selectCategory(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            category['color'].withOpacity(0.3),
                            category['color'].withOpacity(0.1),
                          ],
                        )
                      : LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.05),
                            Colors.white.withOpacity(0.02),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? category['color'].withOpacity(0.5)
                        : Colors.white.withOpacity(0.1),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: category['color'].withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      category['icon'],
                      color: isSelected ? category['color'] : Colors.white.withOpacity(0.5),
                      size: 24,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      category['title'],
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 10.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                        height: 1.0,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      category['subtitle'],
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 8.5,
                        color: isSelected
                            ? category['color'].withOpacity(0.8)
                            : Colors.white.withOpacity(0.4),
                        height: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ).animate(target: isSelected ? 1 : 0)
                .scale(
                  begin: const Offset(1.0, 1.0),
                  end: const Offset(1.05, 1.05),
                  duration: 200.ms,
                ),
            );
          },
        );
      }),
    );
  }

  Widget _buildCategoryContent() {
    return Obx(() {
      final selectedIndex = controller.selectedCategoryIndex.value;

      if (controller.isCurrentCategoryLoading) {
        return _buildLoadingState();
      }

      final data = controller.currentCategoryData;

      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Render content based on category (reordered to match new category order)
            if (selectedIndex == 0) _buildXPContent(data),        // XP Titans
            if (selectedIndex == 1) _buildWinnersContent(data),    // Most Active (by races completed)
            if (selectedIndex == 2) _buildPodiumContent(data),     // Podium Club
            if (selectedIndex == 3) _buildWinnersContent(data),    // Champions (actual winners)

            const SizedBox(height: 40),
          ],
        ),
      );
    });
  }

  Widget _buildWinnersContent(List data) {
    if (data.isEmpty) return _buildEmptyState('No winners yet');

    final entries = List<LeaderboardEntry>.from(data);
    final top3 = entries.take(3).toList();
    final rest = entries.length > 3 ? entries.skip(3).toList() : <LeaderboardEntry>[];

    return Column(
      children: [
        // Top 3 champions
        ...top3.asMap().entries.map((entry) {
          final index = entry.key;
          final winner = entry.value;
          return ChampionDisplayCase(
            entry: winner,
            rank: index + 1,
            statLabel: 'Wins',
            statValue: winner.racesWon,
            secondaryStatLabel: 'Win Rate',
            secondaryStatValue: '${controller.getWinRate(winner).toStringAsFixed(1)}%',
          );
        }),

        const SizedBox(height: 20),

        // Rest of the winners
        if (rest.isNotEmpty)
          TrophyShelf(
            entries: rest,
            statLabel: 'Wins',
            getStatValue: (entry) => entry.racesWon,
          ),
      ],
    );
  }

  Widget _buildPodiumContent(List data) {
    if (data.isEmpty) return _buildEmptyState('No podium finishers yet');

    final entries = List<LeaderboardEntry>.from(data);
    final top3 = entries.take(3).toList();
    final rest = entries.length > 3 ? entries.skip(3).toList() : <LeaderboardEntry>[];

    return Column(
      children: [
        ...top3.asMap().entries.map((entry) {
          final index = entry.key;
          final finisher = entry.value;
          return ChampionDisplayCase(
            entry: finisher,
            rank: index + 1,
            statLabel: 'Podiums',
            statValue: finisher.podiumFinishes,
            secondaryStatLabel: 'Wins',
            secondaryStatValue: '${finisher.racesWon}',
          );
        }),

        const SizedBox(height: 20),

        if (rest.isNotEmpty)
          TrophyShelf(
            entries: rest,
            statLabel: 'Podiums',
            getStatValue: (entry) => entry.podiumFinishes,
          ),
      ],
    );
  }

  Widget _buildXPContent(List data) {
    if (data.isEmpty) return _buildEmptyState('No XP earners yet');

    final entries = List<LeaderboardEntry>.from(data);
    final top3 = entries.take(3).toList();
    final rest = entries.length > 3 ? entries.skip(3).toList() : <LeaderboardEntry>[];

    return Column(
      children: [
        ...top3.asMap().entries.map((entry) {
          final index = entry.key;
          final earner = entry.value;
          return ChampionDisplayCase(
            entry: earner,
            rank: index + 1,
            statLabel: 'Total XP',
            statValue: earner.totalXP,
            secondaryStatLabel: 'Avg XP',
            secondaryStatValue: controller.getAverageXPPerRace(earner).toStringAsFixed(0),
          );
        }),

        const SizedBox(height: 20),

        if (rest.isNotEmpty)
          TrophyShelf(
            entries: rest,
            statLabel: 'XP',
            getStatValue: (entry) => entry.totalXP,
          ),
      ],
    );
  }

  Widget _buildChampionsContent(List data) {
    if (data.isEmpty) {
      return _buildEmptyState('No seasonal champions yet');
    }

    final champions = List<SeasonChampion>.from(data);
    return SeasonalChampionsTimeline(champions: champions);
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading Hall of Fame...',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ).animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 2000.ms, color: const Color(0xFFFFD700).withOpacity(0.3)),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red.withOpacity(0.6),
            ),
            const SizedBox(height: 24),
            Text(
              'Failed to Load',
              style: AppTextStyles.heroHeading.copyWith(
                fontSize: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              controller.errorMessage.value,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => controller.retry(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: AppTextStyles.heroHeading.copyWith(
                fontSize: 22,
                color: Colors.white.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Be the first to achieve greatness!',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
