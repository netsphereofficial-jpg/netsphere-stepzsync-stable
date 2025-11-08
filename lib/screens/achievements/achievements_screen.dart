import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../core/constants/text_styles.dart';
import '../../controllers/achievements_controller.dart';
import '../../models/achievement_models.dart';
import '../hall_of_fame/widgets/spotlight_painter.dart';
import 'widgets/celebration_overlay.dart';
import 'widgets/stats_summary_card.dart';
import 'widgets/achievement_card.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final AchievementsController controller = Get.put(AchievementsController());

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
          'My Achievements',
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

          // Main content
          SafeArea(
            child: Obx(() {
              if (controller.isLoading.value) {
                return _buildLoadingState();
              }

              if (controller.hasError.value) {
                return _buildErrorState();
              }

              return Column(
                children: [
                  const SizedBox(height: 20),

                  // Stats summary
                  StatsSummaryCard(
                    unlockedCount: controller.unlockedCount.value,
                    totalCount: controller.totalCount.value,
                    completionPercentage: controller.completionPercentage.value,
                    latestUnlocked: controller.latestUnlocked,
                  ),

                  const SizedBox(height: 8),

                  // Category tabs
                  _buildCategoryTabs(),

                  const SizedBox(height: 16),

                  // Achievement grid
                  Expanded(
                    child: _buildAchievementGrid(),
                  ),
                ],
              );
            }),
          ),

          // Celebration overlay (first visit only)
          Obx(() {
            if (controller.isFirstVisit.value && !controller.isLoading.value) {
              return CelebrationOverlay(
                unlockedCount: controller.unlockedCount.value,
                onDismiss: () {
                  controller.markCelebrationShown();
                },
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 80,
      child: Obx(() {
        final selectedIndex = controller.selectedCategoryIndex.value;
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: AchievementCategory.values.length,
          itemBuilder: (context, index) {
            final category = AchievementCategory.values[index];
            final isSelected = selectedIndex == index;

            return GestureDetector(
              onTap: () => controller.selectCategory(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFFFD700).withOpacity(0.3),
                            const Color(0xFFFFD700).withOpacity(0.1),
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
                        ? const Color(0xFFFFD700).withOpacity(0.5)
                        : Colors.white.withOpacity(0.1),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.3),
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
                    Text(
                      category.icon,
                      style: TextStyle(
                        fontSize: 22,
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      category.displayName,
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
                      controller.categoryCount,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 8.5,
                        color: isSelected
                            ? const Color(0xFFFFD700).withOpacity(0.8)
                            : Colors.white.withOpacity(0.4),
                        height: 1.0,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ).animate(target: isSelected ? 1 : 0).scale(
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

  Widget _buildAchievementGrid() {
    return Obx(() {
      final achievements = controller.filteredAchievements;

      if (achievements.isEmpty) {
        return _buildEmptyState();
      }

      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: achievements.length,
        itemBuilder: (context, index) {
          final achievement = achievements[index];
          final isUnlocked = controller.unlockedAchievements.contains(achievement);
          final progress = controller.getAchievementProgress(achievement);

          return AchievementCard(
            achievement: achievement,
            isUnlocked: isUnlocked,
            progress: progress,
            index: index,
          );
        },
      );
    });
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
            'Loading Achievements...',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ).animate(onPlay: (controller) => controller.repeat()).shimmer(
          duration: 2000.ms, color: const Color(0xFFFFD700).withOpacity(0.3)),
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

  Widget _buildEmptyState() {
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
              'No Achievements Yet',
              style: AppTextStyles.heroHeading.copyWith(
                fontSize: 22,
                color: Colors.white.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Start racing to unlock achievements!',
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
