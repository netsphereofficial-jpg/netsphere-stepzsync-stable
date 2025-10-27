import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Reusable sync animation widget with phases
///
/// Shows a beautiful animated sync indicator with multiple phases
class SyncAnimationWidget extends StatelessWidget {
  final SyncAnimationPhase phase;
  final Color primaryColor;
  final Color accentColor;

  const SyncAnimationWidget({
    super.key,
    required this.phase,
    this.primaryColor = const Color(0xFF2759FF),
    this.accentColor = const Color(0xFFCDFF49),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _buildPhaseAnimation(),
    );
  }

  Widget _buildPhaseAnimation() {
    switch (phase) {
      case SyncAnimationPhase.connecting:
        return _buildConnectingAnimation();
      case SyncAnimationPhase.syncing:
        return _buildSyncingAnimation();
      case SyncAnimationPhase.updating:
        return _buildUpdatingAnimation();
      case SyncAnimationPhase.completed:
        return _buildCompletedAnimation();
    }
  }

  /// Phase 1: Connecting animation - Pulsing health icon
  Widget _buildConnectingAnimation() {
    return Column(
      key: const ValueKey('connecting'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsing health icon
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor.withOpacity(0.1),
          ),
          child: Center(
            child: Icon(
              Icons.favorite,
              size: 60,
              color: primaryColor,
            ),
          ),
        )
            .animate(onPlay: (controller) => controller.repeat())
            .scale(
              duration: 1500.ms,
              begin: const Offset(0.9, 0.9),
              end: const Offset(1.1, 1.1),
              curve: Curves.easeInOut,
            )
            .then()
            .scale(
              duration: 1500.ms,
              begin: const Offset(1.1, 1.1),
              end: const Offset(0.9, 0.9),
              curve: Curves.easeInOut,
            ),
        const SizedBox(height: 24),
        // Pulsing dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPulsingDot(delay: 0),
            const SizedBox(width: 8),
            _buildPulsingDot(delay: 200),
            const SizedBox(width: 8),
            _buildPulsingDot(delay: 400),
          ],
        ),
      ],
    );
  }

  /// Phase 2: Syncing animation - Rotating circular progress with shimmer
  Widget _buildSyncingAnimation() {
    return Column(
      key: const ValueKey('syncing'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Rotating circular progress
        Stack(
          alignment: Alignment.center,
          children: [
            // Outer rotating ring
            SizedBox(
              width: 120,
              height: 120,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat())
                .rotate(duration: 2000.ms),

            // Inner icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor,
              ),
              child: Icon(
                Icons.sync,
                size: 40,
                color: Colors.white,
              ),
            )
                .animate(onPlay: (controller) => controller.repeat())
                .rotate(duration: 3000.ms, begin: 1, end: 0),
          ],
        ),
        const SizedBox(height: 24),
        // Shimmer progress bar
        Container(
          width: 200,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(2),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 200,
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.3),
                    primaryColor,
                    accentColor,
                    primaryColor,
                    primaryColor.withOpacity(0.3),
                  ],
                  stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat())
                .shimmer(
                  duration: 2000.ms,
                  color: accentColor,
                ),
          ),
        ),
      ],
    );
  }

  /// Phase 3: Updating animation - Data transfer animation
  Widget _buildUpdatingAnimation() {
    return Column(
      key: const ValueKey('updating'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stacked layers animation
        Stack(
          alignment: Alignment.center,
          children: [
            // Background circle
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.1),
              ),
            ),

            // Middle circle
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.2),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat())
                .scale(
                  duration: 1000.ms,
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                  curve: Curves.easeOut,
                )
                .then()
                .fadeOut(duration: 500.ms),

            // Center icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor,
              ),
              child: Icon(
                Icons.cloud_upload,
                size: 30,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Animated checkmarks
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAnimatedCheckmark(delay: 0),
            const SizedBox(width: 12),
            _buildAnimatedCheckmark(delay: 300),
            const SizedBox(width: 12),
            _buildAnimatedCheckmark(delay: 600),
          ],
        ),
      ],
    );
  }

  /// Phase 4: Completed animation - Success checkmark
  Widget _buildCompletedAnimation() {
    return Column(
      key: const ValueKey('completed'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Success checkmark with scale animation
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green,
          ),
          child: Icon(
            Icons.check_rounded,
            size: 70,
            color: Colors.white,
          ),
        )
            .animate()
            .scale(
              duration: 500.ms,
              begin: const Offset(0, 0),
              end: const Offset(1.0, 1.0),
              curve: Curves.elasticOut,
            )
            .then()
            .shimmer(duration: 800.ms, color: Colors.white.withOpacity(0.5)),
        const SizedBox(height: 24),
        // Success wave
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(2),
          ),
        ).animate().scaleX(duration: 600.ms, curve: Curves.easeOut),
      ],
    );
  }

  /// Helper: Build pulsing dot
  Widget _buildPulsingDot({required int delay}) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primaryColor,
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .fadeOut(duration: 800.ms, delay: delay.ms)
        .then()
        .fadeIn(duration: 800.ms);
  }

  /// Helper: Build animated checkmark
  Widget _buildAnimatedCheckmark({required int delay}) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.green.withOpacity(0.2),
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: Icon(
        Icons.check,
        size: 14,
        color: Colors.green,
      ),
    )
        .animate()
        .scale(
          duration: 400.ms,
          delay: delay.ms,
          begin: const Offset(0, 0),
          end: const Offset(1.0, 1.0),
          curve: Curves.elasticOut,
        );
  }
}

/// Animation phases for sync process
enum SyncAnimationPhase {
  connecting,
  syncing,
  updating,
  completed,
}
