import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../models/achievement_models.dart';
import '../../../core/constants/text_styles.dart';

/// Achievement card with locked/unlocked states
class AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final bool isUnlocked;
  final double progress; // 0.0 to 1.0
  final int index;

  const AchievementCard({
    super.key,
    required this.achievement,
    required this.isUnlocked,
    required this.progress,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final tierColor = _getTierColor();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main card container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isUnlocked
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        tierColor.withOpacity(0.15),
                        tierColor.withOpacity(0.05),
                      ],
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.03),
                        Colors.white.withOpacity(0.01),
                      ],
                    ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUnlocked
                    ? tierColor.withOpacity(0.4)
                    : Colors.white.withOpacity(0.1),
                width: isUnlocked ? 2 : 1,
              ),
              boxShadow: isUnlocked
                  ? [
                      BoxShadow(
                        color: tierColor.withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: isUnlocked
                        ? LinearGradient(
                            colors: [
                              tierColor.withOpacity(0.3),
                              tierColor.withOpacity(0.1),
                            ],
                          )
                        : null,
                    color: isUnlocked ? null : Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      achievement.iconEmoji,
                      style: TextStyle(
                        fontSize: 28,
                        color: isUnlocked
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Title
                Text(
                  achievement.title,
                  style: AppTextStyles.sectionHeading.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isUnlocked ? tierColor : Colors.white.withOpacity(0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                // Description
                Text(
                  achievement.description,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 12,
                    color: isUnlocked
                        ? Colors.white.withOpacity(0.7)
                        : Colors.white.withOpacity(0.4),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 12),

                // Progress bar (for locked achievements)
                if (!isUnlocked && progress > 0) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        tierColor.withOpacity(0.5),
                      ),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}% complete',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],

                // Unlocked status
                if (isUnlocked)
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: tierColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Unlocked',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: tierColor,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Tier badge (top right)
          Positioned(
            top: -8,
            right: -8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: isUnlocked
                    ? LinearGradient(
                        colors: [
                          tierColor,
                          tierColor.withOpacity(0.7),
                        ],
                      )
                    : null,
                color: isUnlocked ? null : Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF0A0A0A),
                  width: 2,
                ),
                boxShadow: isUnlocked
                    ? [
                        BoxShadow(
                          color: tierColor.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: Text(
                achievement.tier.emoji,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),

          // Lock icon (for locked achievements)
          if (!isUnlocked)
            Positioned(
              top: 12,
              right: 12,
              child: Icon(
                Icons.lock,
                color: Colors.white.withOpacity(0.3),
                size: 20,
              ),
            ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: (index * 50).ms)
        .slideY(
          begin: 0.2,
          end: 0,
          duration: 500.ms,
          delay: (index * 50).ms,
          curve: Curves.easeOutCubic,
        );
  }

  Color _getTierColor() {
    switch (achievement.tier) {
      case AchievementTier.bronze:
        return const Color(0xFFCD7F32);
      case AchievementTier.silver:
        return const Color(0xFFC0C0C0);
      case AchievementTier.gold:
        return const Color(0xFFFFD700);
      case AchievementTier.platinum:
        return const Color(0xFF2759FF);
    }
  }
}
