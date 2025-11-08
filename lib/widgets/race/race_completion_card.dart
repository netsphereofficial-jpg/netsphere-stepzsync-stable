import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';

/// Beautiful celebration card shown to winners when race status becomes 4
/// Replaces the ugly "Race completed. Check winner list." button
class RaceCompletionCard extends StatelessWidget {
  final int? userRank;
  final String? userName;
  final VoidCallback onViewLeaderboard;

  const RaceCompletionCard({
    super.key,
    this.userRank,
    this.userName,
    required this.onViewLeaderboard,
  });

  String _getRankSuffix(int rank) {
    if (rank % 100 >= 11 && rank % 100 <= 13) {
      return 'th';
    }
    switch (rank % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  IconData _getRankIcon(int? rank) {
    if (rank == null) return Icons.emoji_events;
    switch (rank) {
      case 1:
        return Icons.emoji_events; // Trophy for 1st
      case 2:
        return Icons.military_tech; // Medal for 2nd
      case 3:
        return Icons.workspace_premium; // Badge for 3rd
      default:
        return Icons.emoji_events; // Trophy for others
    }
  }

  Color _getRankColor(int? rank) {
    if (rank == null) return AppColors.appColor;
    switch (rank) {
      case 1:
        return Color(0xFFFFD700); // Gold
      case 2:
        return Color(0xFFC0C0C0); // Silver
      case 3:
        return Color(0xFFCD7F32); // Bronze
      default:
        return AppColors.appColor;
    }
  }

  String _getCelebrationMessage(int? rank) {
    if (rank == null) return 'Race Finished!';
    switch (rank) {
      case 1:
        return 'Champion! 🎉';
      case 2:
        return 'Amazing! 🌟';
      case 3:
        return 'Excellent! 🎊';
      default:
        return 'Well Done! 🎉';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppColors.appColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.appColor.withOpacity(0.15),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.appColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Trophy/Medal Icon
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getRankColor(userRank).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getRankIcon(userRank),
              size: 40,
              color: _getRankColor(userRank),
            ),
          ),

          SizedBox(height: 16),

          // Celebration Message
          Text(
            _getCelebrationMessage(userRank),
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.appColor,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 8),

          // Rank Display
          if (userRank != null) ...[
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'You finished ',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  TextSpan(
                    text: '$userRank${_getRankSuffix(userRank!)}',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _getRankColor(userRank),
                    ),
                  ),
                  TextSpan(
                    text: ' place!',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
          ] else ...[
            Text(
              'The race has ended',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
          ],

          // View Leaderboard Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onViewLeaderboard,
              icon: Icon(Icons.emoji_events, size: 20),
              label: Text(
                'View Final Results',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.appColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
