import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../services/hall_of_fame_service.dart';
import '../../../core/constants/text_styles.dart';

/// Seasonal Champions Timeline - Chronological display of season winners
class SeasonalChampionsTimeline extends StatelessWidget {
  final List<SeasonChampion> champions;

  const SeasonalChampionsTimeline({
    super.key,
    required this.champions,
  });

  @override
  Widget build(BuildContext context) {
    if (champions.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: champions.length,
      itemBuilder: (context, index) {
        final champion = champions[index];
        final isLastItem = index == champions.length - 1;
        return _buildTimelineEntry(champion, index, isLastItem);
      },
    );
  }

  Widget _buildTimelineEntry(SeasonChampion champion, int index, bool isLastItem) {
    final season = champion.season;
    final isCurrentSeason = season.isCurrent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline marker column
        SizedBox(
          width: 60,
          child: Column(
            children: [
              // Trophy icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isCurrentSeason
                        ? [
                            const Color(0xFFFFD700),
                            const Color(0xFFFFA500),
                          ]
                        : [
                            Colors.amber.withOpacity(0.4),
                            Colors.amber.withOpacity(0.2),
                          ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCurrentSeason
                        ? const Color(0xFFFFD700)
                        : Colors.amber.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: isCurrentSeason
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  isCurrentSeason ? Icons.emoji_events : Icons.emoji_events_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),

              // Timeline line
              if (!isLastItem)
                Container(
                  width: 2,
                  height: 100,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.amber.withOpacity(0.3),
                        Colors.amber.withOpacity(0.1),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        // Champion card
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isCurrentSeason
                    ? [
                        const Color(0xFFFFD700).withOpacity(0.15),
                        const Color(0xFFFFD700).withOpacity(0.05),
                      ]
                    : [
                        Colors.white.withOpacity(0.06),
                        Colors.white.withOpacity(0.02),
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCurrentSeason
                    ? const Color(0xFFFFD700).withOpacity(0.4)
                    : Colors.white.withOpacity(0.1),
                width: isCurrentSeason ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isCurrentSeason
                      ? const Color(0xFFFFD700).withOpacity(0.2)
                      : Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Season header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                season.name,
                                style: AppTextStyles.sectionHeading.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrentSeason
                                      ? const Color(0xFFFFD700)
                                      : Colors.white,
                                ),
                              ),
                              if (isCurrentSeason) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD700),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ).animate(onPlay: (controller) => controller.repeat())
                                  .fadeIn(duration: 800.ms)
                                  .then()
                                  .fadeOut(duration: 800.ms),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatSeasonDates(season.startDate, season.endDate),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Champion info
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFFD700),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: champion.profilePicture != null &&
                                champion.profilePicture!.isNotEmpty
                            ? Image.network(
                                champion.profilePicture!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: const Color(0xFFFFD700).withOpacity(0.2),
                                  child: const Icon(
                                    Icons.person,
                                    size: 30,
                                    color: Color(0xFFFFD700),
                                  ),
                                ),
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: const Color(0xFFFFD700).withOpacity(0.2),
                                    child: const Icon(
                                      Icons.person,
                                      size: 30,
                                      color: Color(0xFFFFD700),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: const Color(0xFFFFD700).withOpacity(0.2),
                                child: const Icon(
                                  Icons.person,
                                  size: 30,
                                  color: Color(0xFFFFD700),
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Champion details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.emoji_events,
                                color: Color(0xFFFFD700),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Champion',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: const Color(0xFFFFD700),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            champion.userName,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (champion.country != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 12,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    champion.city != null
                                        ? '${champion.city}, ${champion.country}'
                                        : champion.country!,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      icon: Icons.bolt,
                      label: 'Season XP',
                      value: _formatXP(champion.seasonXP.seasonXP),
                      color: const Color(0xFF2759FF),
                    ),
                    _buildStatItem(
                      icon: Icons.emoji_events,
                      label: 'Wins',
                      value: '${champion.seasonXP.racesWon}',
                      color: const Color(0xFFFFD700),
                    ),
                    _buildStatItem(
                      icon: Icons.military_tech,
                      label: 'Podiums',
                      value: '${champion.seasonXP.podiumFinishes}',
                      color: const Color(0xFFCD7F32),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate()
          .fadeIn(duration: 500.ms, delay: (index * 100).ms)
          .slideX(
            begin: 0.3,
            end: 0,
            duration: 600.ms,
            delay: (index * 100).ms,
            curve: Curves.easeOutBack,
          ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
          ),
        ),
      ],
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
            const SizedBox(height: 20),
            Text(
              'No Champions Yet',
              style: AppTextStyles.heroHeading.copyWith(
                fontSize: 22,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Seasonal champions will appear here\nonce seasons are completed',
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

  String _formatSeasonDates(DateTime start, DateTime end) {
    final startFormatted = DateFormat('MMM d, yyyy').format(start);
    final endFormatted = DateFormat('MMM d, yyyy').format(end);
    return '$startFormatted - $endFormatted';
  }

  String _formatXP(int xp) {
    if (xp >= 1000000) {
      return '${(xp / 1000000).toStringAsFixed(1)}M';
    } else if (xp >= 1000) {
      return '${(xp / 1000).toStringAsFixed(1)}K';
    }
    return xp.toString();
  }
}
