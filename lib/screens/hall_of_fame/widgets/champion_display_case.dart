import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../models/xp_models.dart';
import '../../../core/constants/text_styles.dart';

/// Champion Display Case - Premium glass case for top 3 winners
class ChampionDisplayCase extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank; // 1, 2, or 3
  final String statLabel; // e.g., "Wins", "Podiums", "XP"
  final int statValue;
  final String? secondaryStatLabel;
  final String? secondaryStatValue;

  const ChampionDisplayCase({
    super.key,
    required this.entry,
    required this.rank,
    required this.statLabel,
    required this.statValue,
    this.secondaryStatLabel,
    this.secondaryStatValue,
  });

  @override
  Widget build(BuildContext context) {
    final medalColor = _getMedalColor();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Glass case container
          Container(
            padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: medalColor.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                // Medal glow
                BoxShadow(
                  color: medalColor.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
                // Black shadow for depth
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),

                // User name
                Text(
                  entry.userName,
                  style: AppTextStyles.heroHeading.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                // Location
                if (entry.country != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.white.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        entry.city != null
                            ? '${entry.city}, ${entry.country}'
                            : entry.country!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 20),

                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn(
                      label: statLabel,
                      value: _formatStatValue(statValue),
                      icon: Icons.emoji_events,
                      color: medalColor,
                    ),
                    if (secondaryStatLabel != null && secondaryStatValue != null)
                      _buildStatColumn(
                        label: secondaryStatLabel!,
                        value: secondaryStatValue!,
                        icon: Icons.bar_chart,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    _buildStatColumn(
                      label: 'Level',
                      value: '${entry.level}',
                      icon: Icons.military_tech,
                      color: const Color(0xFF2759FF),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Elevated avatar with medal border
          Positioned(
            top: -40,
            left: 0,
            right: 0,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Avatar container with glow
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          medalColor.withOpacity(0.4),
                          medalColor.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),

                  // Avatar with medal border
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: medalColor,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: medalColor.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: entry.profilePicture != null && entry.profilePicture!.isNotEmpty
                          ? Image.network(
                              entry.profilePicture!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: medalColor.withOpacity(0.2),
                                child: Icon(
                                  Icons.person,
                                  size: 50,
                                  color: medalColor,
                                ),
                              ),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: medalColor.withOpacity(0.2),
                                  child: Icon(
                                    Icons.person,
                                    size: 50,
                                    color: medalColor,
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: medalColor.withOpacity(0.2),
                              child: Icon(
                                Icons.person,
                                size: 50,
                                color: medalColor,
                              ),
                            ),
                    ),
                  ),

                  // Crown for 1st place
                  if (rank == 1)
                    Positioned(
                      top: -12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withOpacity(0.5),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.emoji_events,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ).animate(onPlay: (controller) => controller.repeat())
                        .scale(
                          begin: const Offset(1.0, 1.0),
                          end: const Offset(1.15, 1.15),
                          duration: 1500.ms,
                          curve: Curves.easeInOut,
                        )
                        .then()
                        .scale(
                          begin: const Offset(1.15, 1.15),
                          end: const Offset(1.0, 1.0),
                          duration: 1500.ms,
                          curve: Curves.easeInOut,
                        ),
                    ),

                  // Rank badge
                  Positioned(
                    bottom: -5,
                    right: -5,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            medalColor,
                            medalColor.withOpacity(0.7),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF0A0A0A),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: medalColor.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 500.ms, delay: (rank * 150).ms)
      .slideY(
        begin: 0.3,
        end: 0,
        duration: 600.ms,
        delay: (rank * 150).ms,
        curve: Curves.easeOutBack,
      );
  }

  Widget _buildStatColumn({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTextStyles.heroHeading.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.white.withOpacity(0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Color _getMedalColor() {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.grey;
    }
  }

  String _getMedalName() {
    switch (rank) {
      case 1:
        return 'Gold';
      case 2:
        return 'Silver';
      case 3:
        return 'Bronze';
      default:
        return '';
    }
  }

  String _formatStatValue(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }
}
