import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../models/xp_models.dart';
import '../../../config/app_colors.dart';

/// Clean and minimal leaderboard entry card for positions 4+
class LeaderboardEntryCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isCurrentUser;
  final VoidCallback? onTap;

  const LeaderboardEntryCard({
    super.key,
    required this.entry,
    this.isCurrentUser = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.appColor.withValues(alpha: 0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCurrentUser
            ? Border.all(
                color: AppColors.appColor.withValues(alpha: 0.3),
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Rank number
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _getRankColor().withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${entry.rank}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _getRankColor(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Profile picture
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _getRankColor().withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: entry.profilePicture != null
                        ? NetworkImage(entry.profilePicture!)
                        : null,
                    child: entry.profilePicture == null
                        ? Icon(
                            Icons.person,
                            color: Colors.grey[500],
                            size: 28,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),

                // Full name
                Expanded(
                  child: Text(
                    entry.userName,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(width: 12),

                // Medal icon + XP
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getRankColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.emoji_events_rounded,
                        size: 16,
                        color: _getRankColor(),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${entry.totalXP}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _getRankColor(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getRankColor() {
    if (isCurrentUser) {
      return AppColors.appColor;
    }
    if (entry.rank <= 10) {
      return AppColors.appColor;
    }
    return Colors.grey[700]!;
  }
}