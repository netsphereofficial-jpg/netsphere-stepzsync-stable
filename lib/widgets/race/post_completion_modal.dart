import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import '../../config/app_colors.dart';
import '../../core/models/race_data_model.dart';

/// Post-Completion Modal
/// Shown after celebration dialog dismisses
/// Gives user option to:
/// 1. Watch Others Racing (navigate to live race map)
/// 2. View Current Leaderboard (show partial leaderboard with finished users)
/// Enhanced with animations and confetti
class PostCompletionModal extends StatefulWidget {
  final RaceData race;
  final int userFinishPosition;
  final VoidCallback onWatchOthersRacing;
  final VoidCallback onViewLeaderboard;

  const PostCompletionModal({
    Key? key,
    required this.race,
    required this.userFinishPosition,
    required this.onWatchOthersRacing,
    required this.onViewLeaderboard,
  }) : super(key: key);

  @override
  State<PostCompletionModal> createState() => _PostCompletionModalState();

  /// Show the post-completion modal
  static void show({
    required RaceData race,
    required int userFinishPosition,
    required VoidCallback onWatchOthersRacing,
    required VoidCallback onViewLeaderboard,
  }) {
    Get.dialog(
      PostCompletionModal(
        race: race,
        userFinishPosition: userFinishPosition,
        onWatchOthersRacing: onWatchOthersRacing,
        onViewLeaderboard: onViewLeaderboard,
      ),
      barrierDismissible: true,
    );
  }
}

class _PostCompletionModalState extends State<PostCompletionModal>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize confetti
    _confettiController = ConfettiController(
      duration: Duration(milliseconds: 3000),
    );

    // Initialize scale animation for dialog entrance
    _scaleController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    // Initialize pulse animation for trophy
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize slide animation for buttons
    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Start animations
    _scaleController.forward();
    _confettiController.play();

    Future.delayed(Duration(milliseconds: 300), () {
      if (mounted) {
        _slideController.forward();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Confetti overlay
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.05,
            numberOfParticles: 15,
            gravity: 0.15,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple,
              Colors.yellow,
            ],
          ),
        ),

        // Dialog
        ScaleTransition(
          scale: _scaleAnimation,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
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
                    color: AppColors.appColor.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Enhanced Trophy icon with animation
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.appColor.withOpacity(0.2),
                            AppColors.appColor.withOpacity(0.05),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.appColor.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.emoji_events_rounded,
                          size: 50,
                          color: AppColors.appColor,
                        ),
                      ),
                    ),
                  ),

            SizedBox(height: 24),

            // Title with gradient effect
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        AppColors.appColor,
                        AppColors.appColor.withOpacity(0.7),
                      ],
                    ).createShader(bounds),
                    child: Text(
                      "Hurray! You've Completed!",
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

            SizedBox(height: 10),

            // Position badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.appColor,
                          AppColors.appColor.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.appColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.military_tech_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6),
                        Text(
                          "Finished #${widget.userFinishPosition}",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

            SizedBox(height: 24),

            // Info text with icon
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.appColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.appColor.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: AppColors.appColor,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "The race continues for others. What would you like to do?",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

            SizedBox(height: 28),

            // Animated buttons
                  SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        // Watch Others Racing button
                        _buildAnimatedButton(
                          onPressed: () {
                            Get.back();
                            widget.onWatchOthersRacing();
                          },
                          icon: Icons.remove_red_eye_rounded,
                          label: 'Watch Others Racing',
                          isPrimary: true,
                        ),

                        SizedBox(height: 14),

                        // View Leaderboard button
                        _buildAnimatedButton(
                          onPressed: () {
                            Get.back();
                            widget.onViewLeaderboard();
                          },
                          icon: Icons.leaderboard_rounded,
                          label: 'View Current Leaderboard',
                          isPrimary: false,
                        ),

                        SizedBox(height: 18),

                        // Close button
                        TextButton(
                          onPressed: () => Get.back(),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Colors.black45,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Close',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
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
      ],
    );
  }

  Widget _buildAnimatedButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required bool isPrimary,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Opacity(
            opacity: value,
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: isPrimary
                  ? ElevatedButton.icon(
                      onPressed: onPressed,
                      icon: Icon(icon, size: 22),
                      label: Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.appColor,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: AppColors.appColor.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: onPressed,
                      icon: Icon(icon, size: 22),
                      label: Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.appColor,
                        side: BorderSide(
                          color: AppColors.appColor,
                          width: 2.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
