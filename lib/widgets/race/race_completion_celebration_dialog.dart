import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import '../../config/app_colors.dart';

/// Race Completion Celebration Dialog
/// Shows when a user finishes a race with:
/// - Confetti animation for top 3 finishers (5 seconds)
/// - Simple celebration for 4th+ finishers (3 seconds)
/// - Finish position badge and congratulations message
/// - Enhanced animations and participant statistics
/// - Special handling for solo races (no rank display)
class RaceCompletionCelebrationDialog extends StatefulWidget {
  final int finishPosition;
  final int finalRank;
  final String raceName;
  final VoidCallback onDismiss;
  final double? distance;
  final double? calories;
  final double? avgSpeed;
  final bool isSoloRace;

  const RaceCompletionCelebrationDialog({
    Key? key,
    required this.finishPosition,
    required this.finalRank,
    required this.raceName,
    required this.onDismiss,
    this.distance,
    this.calories,
    this.avgSpeed,
    this.isSoloRace = false,
  }) : super(key: key);

  @override
  State<RaceCompletionCelebrationDialog> createState() =>
      _RaceCompletionCelebrationDialogState();

  /// Show celebration dialog
  static void show({
    required int finishPosition,
    required int finalRank,
    required String raceName,
    required VoidCallback onComplete,
    double? distance,
    double? calories,
    double? avgSpeed,
    bool isSoloRace = false,
  }) {
    Get.dialog(
      RaceCompletionCelebrationDialog(
        finishPosition: finishPosition,
        finalRank: finalRank,
        raceName: raceName,
        onDismiss: onComplete,
        distance: distance,
        calories: calories,
        avgSpeed: avgSpeed,
        isSoloRace: isSoloRace,
      ),
      barrierDismissible: false,
    );
  }
}

class _RaceCompletionCelebrationDialogState
    extends State<RaceCompletionCelebrationDialog>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late ConfettiController _centerConfettiController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<Offset> _slideAnimation;
  late bool _isTopThree;
  late int _animationDuration;

  @override
  void initState() {
    super.initState();

    _isTopThree = widget.finishPosition <= 3;
    _animationDuration = _isTopThree ? 5000 : 3000; // 5s for top 3, 3s for others

    // Initialize confetti controllers
    _confettiController = ConfettiController(
      duration: Duration(milliseconds: _animationDuration),
    );

    _centerConfettiController = ConfettiController(
      duration: Duration(milliseconds: _animationDuration),
    );

    // Initialize pulse animation for icon
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize rotation animation for icon
    _rotateController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _rotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    // Initialize slide animation for stats
    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    // Start animations
    if (_isTopThree) {
      _confettiController.play();
      _centerConfettiController.play();
    }

    // Delay stats animation
    Future.delayed(Duration(milliseconds: 600), () {
      if (mounted) {
        _slideController.forward();
      }
    });

    // Auto-dismiss after animation duration + 5 seconds wait
    Future.delayed(Duration(milliseconds: _animationDuration + 5000), () {
      if (mounted) {
        Get.back(); // Close celebration dialog
        widget.onDismiss(); // Callback to navigate home
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _centerConfettiController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.88),
      child: Stack(
        children: [
          // Enhanced confetti overlay for top 3
          if (_isTopThree) ...[
            // Left confetti cannon
            Align(
              alignment: Alignment.topLeft,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: 0.7, // Slightly angled right
                emissionFrequency: 0.03,
                numberOfParticles: 25,
                gravity: 0.25,
                shouldLoop: false,
                maximumSize: Size(15, 15),
                minimumSize: Size(8, 8),
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                  Colors.red,
                  Colors.yellow,
                  Colors.teal,
                  Colors.amber,
                ],
              ),
            ),
            // Right confetti cannon
            Align(
              alignment: Alignment.topRight,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: 2.44, // Slightly angled left (180 - 0.7)
                emissionFrequency: 0.03,
                numberOfParticles: 25,
                gravity: 0.25,
                shouldLoop: false,
                maximumSize: Size(15, 15),
                minimumSize: Size(8, 8),
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                  Colors.red,
                  Colors.yellow,
                  Colors.teal,
                  Colors.amber,
                ],
              ),
            ),
            // Center confetti cannon (burst effect)
            Align(
              alignment: Alignment.center,
              child: ConfettiWidget(
                confettiController: _centerConfettiController,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.02,
                numberOfParticles: 30,
                gravity: 0.2,
                shouldLoop: false,
                maximumSize: Size(12, 12),
                minimumSize: Size(6, 6),
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                  Colors.red,
                  Colors.yellow,
                  Colors.teal,
                  Colors.amber,
                ],
              ),
            ),
          ],

          // Celebration content
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 32),
                padding: EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.white.withOpacity(0.97),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: _getPositionColor().withOpacity(0.4),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Enhanced Medal/Trophy icon based on position
                    _buildPositionIcon(),

                    SizedBox(height: 20),

                    // Congratulations text with gradient
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          _getPositionColor(),
                          _getPositionColor().withOpacity(0.7),
                        ],
                      ).createShader(bounds),
                      child: Text(
                        _getCongratulationsText(),
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    SizedBox(height: 12),

                    // Finish position text with enhanced styling for 1st place
                    _buildPositionText(),

                    SizedBox(height: 6),

                    // Race name with icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flag_rounded,
                          size: 18,
                          color: Colors.black45,
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            widget.raceName,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Stats section (if available)
                    if (widget.distance != null ||
                        widget.calories != null ||
                        widget.avgSpeed != null) ...[
                      SizedBox(height: 20),
                      SlideTransition(
                        position: _slideAnimation,
                        child: _buildStatsSection(),
                      ),
                    ],

                    SizedBox(height: 24),

                    // Animated loading indicator
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getPositionColor(),
                          ),
                          strokeWidth: 4,
                        ),
                      ),
                    ),

                    SizedBox(height: 14),

                    Text(
                      'Returning to home...',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionIcon() {
    String emoji;
    Color backgroundColor;

    switch (widget.finishPosition) {
      case 1:
        emoji = '🥇';
        backgroundColor = Color(0xFFFFD700); // Gold
        break;
      case 2:
        emoji = '🥈';
        backgroundColor = Color(0xFFC0C0C0); // Silver
        break;
      case 3:
        emoji = '🥉';
        backgroundColor = Color(0xFFCD7F32); // Bronze
        break;
      default:
        emoji = '🎉';
        backgroundColor = AppColors.appColor;
    }

    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: backgroundColor.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(
            color: backgroundColor,
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            emoji,
            style: TextStyle(fontSize: 56),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getPositionColor().withOpacity(0.08),
            _getPositionColor().withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getPositionColor().withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Your Performance',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (widget.distance != null)
                _buildStatItem(
                  icon: Icons.directions_run_rounded,
                  label: 'Distance',
                  value: '${widget.distance!.toStringAsFixed(2)} km',
                  color: Colors.blue,
                ),
              if (widget.calories != null)
                _buildStatItem(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Calories',
                  value: '${widget.calories!.toStringAsFixed(0)} kcal',
                  color: Colors.orange,
                ),
              if (widget.avgSpeed != null)
                _buildStatItem(
                  icon: Icons.speed_rounded,
                  label: 'Avg Speed',
                  value: '${widget.avgSpeed!.toStringAsFixed(1)} km/h',
                  color: Colors.green,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, animValue, child) {
        return Opacity(
          opacity: animValue,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: color,
                ),
              ),
              SizedBox(height: 6),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black45,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPositionText() {
    // For solo races, show completion message instead of rank
    if (widget.isSoloRace) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1E88E5), // Vibrant blue
              Color(0xFF1565C0), // Darker blue
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF1E88E5).withOpacity(0.5),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              'RACE COMPLETED!',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      );
    }

    // For 1st place in competitive races, make it extra prominent with enhanced styling
    if (widget.finishPosition == 1) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1E88E5), // Vibrant blue
              Color(0xFF1565C0), // Darker blue
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF1E88E5).withOpacity(0.5),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events,
              color: Colors.white,
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              'YOU FINISHED 1ST PLACE!',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      );
    }

    // For other positions, use simpler styling
    return Text(
      _getPositionText(),
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      textAlign: TextAlign.center,
    );
  }

  String _getCongratulationsText() {
    // For solo races, show achievement-focused message
    if (widget.isSoloRace) {
      return 'WELL DONE!';
    }

    // For competitive races, show position-based message
    switch (widget.finishPosition) {
      case 1:
        return 'WINNER!';
      case 2:
        return 'AMAZING!';
      case 3:
        return 'EXCELLENT!';
      default:
        return 'CONGRATULATIONS!';
    }
  }

  String _getPositionText() {
    switch (widget.finishPosition) {
      case 1:
        return 'You finished 1st!';
      case 2:
        return 'You finished 2nd!';
      case 3:
        return 'You finished 3rd!';
      default:
        return 'You finished ${_getOrdinal(widget.finishPosition)}!';
    }
  }

  String _getOrdinal(int number) {
    if (number % 100 >= 11 && number % 100 <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  Color _getPositionColor() {
    switch (widget.finishPosition) {
      case 1:
        return Color(0xFFFFD700); // Gold
      case 2:
        return Color(0xFF808080); // Silver (darker)
      case 3:
        return Color(0xFFCD7F32); // Bronze
      default:
        return AppColors.appColor;
    }
  }
}
