import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import '../../../core/constants/text_styles.dart';

/// Celebration overlay shown on first visit
class CelebrationOverlay extends StatefulWidget {
  final int unlockedCount;
  final VoidCallback onDismiss;

  const CelebrationOverlay({
    super.key,
    required this.unlockedCount,
    required this.onDismiss,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // Trigger confetti after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      _confettiController.play();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDismiss,
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: Stack(
          children: [
            // Confetti from top
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: 3.14 / 2, // Down
                emissionFrequency: 0.05,
                numberOfParticles: 30,
                gravity: 0.3,
                colors: const [
                  Color(0xFFFFD700), // Gold
                  Color(0xFFC0C0C0), // Silver
                  Color(0xFFCD7F32), // Bronze
                  Color(0xFF2759FF), // Blue
                  Color(0xFF39FF14), // Neon green
                ],
              ),
            ),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Trophy icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFD700),
                          Color(0xFFFFA500),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withOpacity(0.5),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.emoji_events,
                      size: 70,
                      color: Colors.white,
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat())
                      .scale(
                        begin: const Offset(1.0, 1.0),
                        end: const Offset(1.1, 1.1),
                        duration: 1000.ms,
                        curve: Curves.easeInOut,
                      )
                      .then()
                      .scale(
                        begin: const Offset(1.1, 1.1),
                        end: const Offset(1.0, 1.0),
                        duration: 1000.ms,
                        curve: Curves.easeInOut,
                      ),

                  const SizedBox(height: 40),

                  // Congratulations text
                  Text(
                    'Congratulations!',
                    style: AppTextStyles.heroHeading.copyWith(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFFD700),
                    ),
                    textAlign: TextAlign.center,
                  )
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 300.ms)
                      .slideY(
                        begin: 0.3,
                        end: 0,
                        duration: 600.ms,
                        delay: 300.ms,
                        curve: Curves.easeOutBack,
                      ),

                  const SizedBox(height: 20),

                  // Achievement count
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: AppTextStyles.heroHeading.copyWith(
                        fontSize: 24,
                        color: Colors.white,
                      ),
                      children: [
                        const TextSpan(text: 'You\'ve unlocked '),
                        TextSpan(
                          text: '${widget.unlockedCount}',
                          style: AppTextStyles.heroHeading.copyWith(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFFD700),
                          ),
                        ),
                        TextSpan(
                          text: widget.unlockedCount == 1
                              ? ' achievement!'
                              : ' achievements!',
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 500.ms, delay: 600.ms)
                      .slideY(
                        begin: 0.3,
                        end: 0,
                        duration: 600.ms,
                        delay: 600.ms,
                        curve: Curves.easeOutBack,
                      ),

                  const SizedBox(height: 60),

                  // Tap to continue hint
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app,
                          color: Colors.white.withOpacity(0.8),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tap anywhere to continue',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat())
                      .fadeIn(duration: 800.ms, delay: 900.ms)
                      .then()
                      .fadeOut(duration: 800.ms)
                      .then()
                      .fadeIn(duration: 800.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
