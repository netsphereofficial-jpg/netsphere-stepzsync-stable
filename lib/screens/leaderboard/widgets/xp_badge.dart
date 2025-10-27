import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/xp_models.dart';

/// Widget to display user's XP badge with level and progress
class XPBadge extends StatelessWidget {
  final UserXP userXP;
  final bool compact;
  final double size;

  const XPBadge({
    super.key,
    required this.userXP,
    this.compact = false,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactBadge(context);
    }
    return _buildFullBadge(context);
  }

  Widget _buildCompactBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getLevelColor().withOpacity(0.8),
            _getLevelColor(),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getLevelColor().withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.stars_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            'Lvl ${userXP.level}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${userXP.totalXP} XP',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullBadge(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getLevelColor().withOpacity(0.8),
            _getLevelColor(),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _getLevelColor().withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Level number
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  userXP.level.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: size * 0.35,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                Text(
                  'LEVEL',
                  style: GoogleFonts.poppins(
                    fontSize: size * 0.15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.8),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          // Progress ring
          Positioned.fill(
            child: CircularProgressIndicator(
              value: userXP.levelProgress,
              strokeWidth: size * 0.08,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getLevelColor() {
    // Color gradient based on level
    if (userXP.level >= 50) {
      return Colors.purple; // Legendary
    } else if (userXP.level >= 30) {
      return Colors.deepOrange; // Epic
    } else if (userXP.level >= 20) {
      return Colors.blue; // Rare
    } else if (userXP.level >= 10) {
      return Colors.green; // Uncommon
    } else {
      return Colors.grey; // Common
    }
  }
}

/// Widget to display XP progress bar
class XPProgressBar extends StatelessWidget {
  final UserXP userXP;
  final bool showDetails;

  const XPProgressBar({
    super.key,
    required this.userXP,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDetails) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Level ${userXP.level}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '${userXP.totalXP % 1000} / 1000 XP',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: userXP.levelProgress,
            minHeight: 12,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              _getLevelColor(),
            ),
          ),
        ),
        if (showDetails) ...[
          const SizedBox(height: 6),
          Text(
            '${userXP.xpToNextLevel} XP to Level ${userXP.level + 1}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ],
    );
  }

  Color _getLevelColor() {
    if (userXP.level >= 50) {
      return Colors.purple;
    } else if (userXP.level >= 30) {
      return Colors.deepOrange;
    } else if (userXP.level >= 20) {
      return Colors.blue;
    } else if (userXP.level >= 10) {
      return Colors.green;
    } else {
      return Colors.grey;
    }
  }
}