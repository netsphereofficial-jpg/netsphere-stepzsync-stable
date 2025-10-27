import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../models/xp_models.dart';
import '../../../config/app_colors.dart';

/// Premium podium widget with elegant card design
class PremiumPodiumDisplay extends StatelessWidget {
  final List<LeaderboardEntry> topThree;
  final VoidCallback? onFirstPlaceTap;
  final VoidCallback? onSecondPlaceTap;
  final VoidCallback? onThirdPlaceTap;

  const PremiumPodiumDisplay({
    super.key,
    required this.topThree,
    this.onFirstPlaceTap,
    this.onSecondPlaceTap,
    this.onThirdPlaceTap,
  });

  @override
  Widget build(BuildContext context) {
    if (topThree.isEmpty) {
      return const SizedBox.shrink();
    }

    final first = topThree.isNotEmpty ? topThree[0] : null;
    final second = topThree.length > 1 ? topThree[1] : null;
    final third = topThree.length > 2 ? topThree[2] : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place
          if (second != null)
            Expanded(
              child: _buildPodiumCard(
                entry: second,
                rank: 2,
                color: const Color(0xFFC0C0C0), // Silver
                medalIcon: Icons.emoji_events_rounded,
                onTap: onSecondPlaceTap,
              )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 100.ms)
                  .slideY(begin: 0.3, end: 0, duration: 500.ms, delay: 100.ms, curve: Curves.easeOutBack)
                  .scale(begin: const Offset(0.8, 0.8), delay: 100.ms, duration: 500.ms, curve: Curves.easeOutBack),
            ),
          const SizedBox(width: 12),

          // 1st Place (Taller)
          if (first != null)
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: _buildPodiumCard(
                  entry: first,
                  rank: 1,
                  color: const Color(0xFFFFD700), // Gold
                  medalIcon: Icons.emoji_events_rounded,
                  onTap: onFirstPlaceTap,
                  isWinner: true,
                ),
              )
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 200.ms)
                  .slideY(begin: 0.3, end: 0, duration: 600.ms, delay: 200.ms, curve: Curves.easeOutBack)
                  .scale(begin: const Offset(0.8, 0.8), delay: 200.ms, duration: 600.ms, curve: Curves.easeOutBack)
                  .shimmer(delay: 800.ms, duration: 1000.ms, color: Colors.white.withOpacity(0.3)),
            ),
          const SizedBox(width: 12),

          // 3rd Place
          if (third != null)
            Expanded(
              child: _buildPodiumCard(
                entry: third,
                rank: 3,
                color: const Color(0xFFCD7F32), // Bronze
                medalIcon: Icons.emoji_events_rounded,
                onTap: onThirdPlaceTap,
              )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 300.ms)
                  .slideY(begin: 0.3, end: 0, duration: 500.ms, delay: 300.ms, curve: Curves.easeOutBack)
                  .scale(begin: const Offset(0.8, 0.8), delay: 300.ms, duration: 500.ms, curve: Curves.easeOutBack),
            ),
        ],
      ),
    );
  }

  Widget _buildPodiumCard({
    required LeaderboardEntry entry,
    required int rank,
    required Color color,
    required IconData medalIcon,
    VoidCallback? onTap,
    bool isWinner = false,
  }) {
    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Main Card
          Container(
            margin: EdgeInsets.only(top: isWinner ? 28 : 23),
            padding: const EdgeInsets.only(
              top: 45,
              bottom: 16,
              left: 12,
              right: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // Medal with XP
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color,
                        color.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        medalIcon,
                        size: isWinner ? 18 : 16,
                        color: Colors.white,
                      ),
                      Text(
                        '${entry.totalXP}',
                        style: GoogleFonts.poppins(
                          fontSize: isWinner ? 14 : 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // First Name
                Text(
                  _getFirstName(entry.userName),
                  style: GoogleFonts.poppins(
                    fontSize: isWinner ? 15 : 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 4),

                // Rank Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    rank == 1 ? '1st' : rank == 2 ? '2nd' : '3rd',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color.withValues(alpha: 1.0),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // User Image - Half inside, half outside at top
          Positioned(
            top: -15,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.red,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: isWinner ? 40 : 35,
                backgroundColor: Colors.grey[300],
                backgroundImage: entry.profilePicture != null
                    ? NetworkImage(entry.profilePicture!)
                    : null,
                child: entry.profilePicture == null
                    ? Icon(
                        Icons.person,
                        size: isWinner ? 40 : 35,
                        color: Colors.grey[600],
                      )
                    : null,
              ),
            ),
          ),

          // Crown for winner
          if (isWinner)
            Positioned(
              top: -30,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFFD700),
                      const Color(0xFFFFA500),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.red,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),

          // Rank number badge at bottom
          Positioned(
            bottom: -12,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color,
                    color.withValues(alpha: 0.85),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.red,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  String _getFirstName(String fullName) {
    final parts = fullName.trim().split(' ');
    return parts.isNotEmpty ? parts[0] : fullName;
  }
}