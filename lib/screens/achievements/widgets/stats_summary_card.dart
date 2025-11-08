import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../models/achievement_models.dart';
import '../../../core/constants/text_styles.dart';

/// Stats summary card showing total achievements unlocked
class StatsSummaryCard extends StatelessWidget {
  final int unlockedCount;
  final int totalCount;
  final double completionPercentage;
  final Achievement? latestUnlocked;

  const StatsSummaryCard({
    super.key,
    required this.unlockedCount,
    required this.totalCount,
    required this.completionPercentage,
    this.latestUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFD700).withOpacity(0.15),
            const Color(0xFFFFD700).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFD700).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular progress indicator
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              children: [
                // Background circle
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.1),
                  ),
                ),

                // Progress circle
                CircularProgressIndicator(
                  value: completionPercentage / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFFFD700),
                  ),
                )
                    .animate()
                    .custom(
                      duration: 1500.ms,
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return CircularProgressIndicator(
                          value: (completionPercentage / 100) * value,
                          strokeWidth: 8,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFFFD700),
                          ),
                        );
                      },
                    ),

                // Center percentage
                Center(
                  child: Text(
                    '${completionPercentage.toInt()}%',
                    style: AppTextStyles.heroHeading.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFFD700),
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 500.ms),
                ),
              ],
            ),
          ),

          const SizedBox(width: 20),

          // Stats text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Unlocked count
                Text(
                  '$unlockedCount/$totalCount Unlocked',
                  style: AppTextStyles.sectionHeading.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 4),

                // Latest unlocked
                if (latestUnlocked != null) ...[
                  Row(
                    children: [
                      Text(
                        latestUnlocked!.tier.emoji,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Latest: ${latestUnlocked!.title}',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 12,
                            color: const Color(0xFFFFD700).withOpacity(0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    'Start unlocking achievements!',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: completionPercentage / 100,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFFFD700),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: -0.3, end: 0, duration: 600.ms, curve: Curves.easeOutBack);
  }
}
