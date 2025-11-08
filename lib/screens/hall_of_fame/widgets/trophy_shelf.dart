import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../models/xp_models.dart';
import '../../../core/constants/text_styles.dart';

/// Trophy Shelf - Compact display for positions 4-10
class TrophyShelf extends StatelessWidget {
  final List<LeaderboardEntry> entries; // Positions 4-10
  final String statLabel; // e.g., "Wins", "Podiums", "XP"
  final Function(LeaderboardEntry) getStatValue;

  const TrophyShelf({
    super.key,
    required this.entries,
    required this.statLabel,
    required this.getStatValue,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.withOpacity(0.3),
                      Colors.amber.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.emoji_events_outlined,
                  color: Colors.amber[300],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Hall of Excellence',
                style: AppTextStyles.sectionHeading.copyWith(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),

        // Trophy shelf entries
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final rank = index + 4; // Starts from 4th position
            return _buildShelfEntry(entry, rank, index);
          },
        ),
      ],
    );
  }

  Widget _buildShelfEntry(LeaderboardEntry entry, int rank, int index) {
    final statValue = getStatValue(entry);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.amber.withOpacity(0.4),
                  Colors.amber.withOpacity(0.2),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.amber.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.amber.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: entry.profilePicture != null && entry.profilePicture!.isNotEmpty
                  ? Image.network(
                      entry.profilePicture!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.amber.withOpacity(0.1),
                        child: Icon(
                          Icons.person,
                          size: 25,
                          color: Colors.amber.withOpacity(0.5),
                        ),
                      ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.amber.withOpacity(0.1),
                          child: Icon(
                            Icons.person,
                            size: 25,
                            color: Colors.amber.withOpacity(0.5),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.amber.withOpacity(0.1),
                      child: Icon(
                        Icons.person,
                        size: 25,
                        color: Colors.amber.withOpacity(0.5),
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 16),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.userName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (entry.country != null) ...[
                      Icon(
                        Icons.location_on,
                        size: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          entry.city != null
                              ? '${entry.city}, ${entry.country}'
                              : entry.country!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else ...[
                      Icon(
                        Icons.military_tech,
                        size: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Level ${entry.level}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Stat value
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatStatValue(statValue),
                style: AppTextStyles.heroHeading.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[300],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                statLabel,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 400.ms, delay: (300 + index * 80).ms)
      .slideX(
        begin: 0.2,
        end: 0,
        duration: 500.ms,
        delay: (300 + index * 80).ms,
        curve: Curves.easeOutCubic,
      );
  }

  String _formatStatValue(dynamic value) {
    int intValue = 0;

    if (value is int) {
      intValue = value;
    } else if (value is double) {
      intValue = value.toInt();
    } else if (value is String) {
      return value;
    }

    if (intValue >= 1000000) {
      return '${(intValue / 1000000).toStringAsFixed(1)}M';
    } else if (intValue >= 1000) {
      return '${(intValue / 1000).toStringAsFixed(1)}K';
    }
    return intValue.toString();
  }
}
